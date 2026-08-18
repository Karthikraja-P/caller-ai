import asyncio
import base64
import json
import uuid
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request, WebSocket, WebSocketDisconnect
from pydantic import BaseModel

from app.core.database import get_admin_db
from app.core.security import get_current_user
from app.core.config import settings
from app.core.twilio_client import build_ai_call_twiml, validate_twilio_signature
from app.services.ai_voice_service import (
    transcribe_audio, synthesize_speech_rest,
    classify_intent, extract_entities, generate_ai_response,
)

router = APIRouter(prefix="/ai", tags=["AI Agent"])


# ── Agent Config ──────────────────────────────────────────────

class AgentConfigRequest(BaseModel):
    agent_name: str
    voice_id: str = "en-US-Neural2-A"
    personality: str = "friendly"
    language: str = "en-US"
    spam_handling_enabled: bool = True
    busy_mode_enabled: bool = False
    busy_start_time: Optional[str] = None
    busy_end_time: Optional[str] = None
    busy_days: list[str] = []
    whatsapp_diversion_enabled: bool = False
    greeting_template: str = "Hello, I am {{agent_name}}. How can I help?"


@router.post("/agent/config")
async def save_agent_config(req: AgentConfigRequest, user_id: str = Depends(get_current_user)):
    admin = get_admin_db()
    data = req.model_dump()
    data["user_id"] = user_id
    admin.table("ai_agent_configs").upsert(data, on_conflict="user_id").execute()
    resp = admin.table("ai_agent_configs").select("*").eq("user_id", user_id).single().execute()
    return resp.data


@router.get("/agent/config")
async def get_agent_config(user_id: str = Depends(get_current_user)):
    admin = get_admin_db()
    resp = admin.table("ai_agent_configs").select("*").eq("user_id", user_id).maybe_single().execute()
    if not resp.data:
        raise HTTPException(status_code=404, detail={"error": "NOT_FOUND", "message": "No agent config found."})
    return resp.data


# ── Voice Preview (TTS) ───────────────────────────────────────

class SpeakTextRequest(BaseModel):
    text: str
    voice_id: str = "en-US-Neural2-A"


@router.post("/call/speak-text")
async def speak_text(req: SpeakTextRequest, user_id: str = Depends(get_current_user)):
    """Convert text to speech and return audio URL."""
    audio_bytes = await synthesize_speech_rest(req.text, req.voice_id)

    # Upload to Supabase Storage
    admin = get_admin_db()
    file_name = f"previews/{user_id}/{uuid.uuid4()}.mp3"
    admin.storage.from_("audio").upload(
        path=file_name,
        file=audio_bytes,
        file_options={"content-type": "audio/mpeg"},
    )
    audio_url = admin.storage.from_("audio").get_public_url(file_name)

    return {"audio_url": audio_url, "duration_seconds": len(audio_bytes) / 16000}


# ── Twilio Webhook: Handle AI Call ───────────────────────────

@router.post("/call/handle")
async def handle_ai_call(request: Request):
    """
    Twilio webhook — called when an incoming call is routed to AI.
    Validates Twilio signature, fetches agent config, returns TwiML to connect WebSocket.
    """
    form = await request.form()
    call_sid = form.get("CallSid", "")
    from_number = form.get("From", "")
    to_number = form.get("To", "")
    call_type = form.get("call_type", "spam")  # injected by app

    # Validate Twilio signature
    signature = request.headers.get("X-Twilio-Signature", "")
    url = str(request.url)
    if not validate_twilio_signature(url, dict(form), signature):
        raise HTTPException(status_code=403, detail="Invalid Twilio signature")

    # Find user by their Twilio number
    admin = get_admin_db()
    config_resp = admin.table("ai_agent_configs").select("*").eq(
        "spam_handling_enabled", True
    ).limit(1).execute()
    config = config_resp.data[0] if config_resp.data else {}
    agent_name = config.get("agent_name", "Assistant")

    ws_url = f"wss://{request.headers.get('host', 'api.callerai.app')}/api/v1/ai/call/stream/{call_sid}"
    twiml = build_ai_call_twiml(ws_url, agent_name)

    from fastapi.responses import Response
    return Response(content=twiml, media_type="application/xml")


# ── WebSocket: Live AI Conversation ──────────────────────────

active_sessions: dict = {}


@router.websocket("/call/stream/{call_sid}")
async def ai_call_stream(websocket: WebSocket, call_sid: str):
    """
    WebSocket endpoint for live Twilio Media Streams.
    Receives µlaw audio chunks → Whisper STT → NLP → TTS → sends back audio.
    """
    await websocket.accept()
    session = {
        "call_sid": call_sid,
        "transcript": [],
        "entities": [],
        "audio_buffer": bytearray(),
        "intent": "general",
    }
    active_sessions[call_sid] = session

    try:
        while True:
            raw = await websocket.receive_text()
            msg = json.loads(raw)
            event = msg.get("event")

            if event == "start":
                session["stream_sid"] = msg.get("streamSid")

            elif event == "media":
                # Accumulate audio payload (base64 µlaw)
                payload = base64.b64decode(msg["media"]["payload"])
                session["audio_buffer"].extend(payload)

                # Process every 2 seconds of audio (~16KB at 8kHz µlaw)
                if len(session["audio_buffer"]) >= 16000:
                    audio_chunk = bytes(session["audio_buffer"])
                    session["audio_buffer"] = bytearray()

                    # Transcribe
                    try:
                        text = await transcribe_audio(audio_chunk)
                        if text.strip():
                            session["transcript"].append({"speaker": "caller", "text": text})

                            # Classify intent + extract entities
                            intent, _ = classify_intent(text)
                            session["intent"] = intent
                            entities = extract_entities(text, intent)
                            session["entities"].extend(entities)

                            # Generate AI response
                            response_text = await generate_ai_response(
                                session["transcript"], intent
                            )
                            session["transcript"].append({"speaker": "ai", "text": response_text})

                            # Synthesize and stream back
                            audio_bytes = await synthesize_speech_rest(response_text)
                            audio_b64 = base64.b64encode(audio_bytes).decode()

                            await websocket.send_json({
                                "event": "media",
                                "streamSid": session.get("stream_sid"),
                                "media": {"payload": audio_b64},
                            })
                    except Exception:
                        pass

            elif event == "stop":
                # Save transcript to Supabase
                admin = get_admin_db()
                admin.table("ai_call_transcripts").insert({
                    "user_id": "system",  # Looked up from call routing in prod
                    "call_sid": call_sid,
                    "caller_number": "unknown",
                    "call_type": "spam",
                    "agent_name": "Assistant",
                    "full_transcript": session["transcript"],
                    "extracted_entities": session["entities"],
                    "summary": session["transcript"][-1]["text"] if session["transcript"] else "",
                }).execute()
                break

    except WebSocketDisconnect:
        pass
    finally:
        active_sessions.pop(call_sid, None)


# ── Transcript History ────────────────────────────────────────

@router.get("/call/history")
async def call_history(
    user_id: str = Depends(get_current_user),
    page: int = 1,
    per_page: int = 20,
    call_type: str = "all",
):
    admin = get_admin_db()
    query = admin.table("ai_call_transcripts").select("*").eq("user_id", user_id)
    if call_type != "all":
        query = query.eq("call_type", call_type)
    resp = query.order("created_at", desc=True).range(
        (page - 1) * per_page, page * per_page - 1
    ).execute()
    return {"calls": resp.data or [], "page": page, "per_page": per_page}


@router.get("/call/transcript/{call_id}")
async def get_transcript(call_id: str, user_id: str = Depends(get_current_user)):
    admin = get_admin_db()
    resp = admin.table("ai_call_transcripts").select("*").eq("id", call_id).eq(
        "user_id", user_id
    ).single().execute()
    if not resp.data:
        raise HTTPException(status_code=404, detail="Transcript not found")
    return resp.data
