import asyncio
import base64
import hashlib
import hmac
import json
import secrets
import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request, WebSocket, WebSocketDisconnect
from pydantic import BaseModel

import logging

from app.core.database import get_admin_db
from app.core.security import get_current_user
from app.core.twilio_client import build_ai_call_twiml, validate_twilio_signature
from app.services.ai_voice_service import (
    transcribe_audio, synthesize_speech_rest, synthesize_speech_mulaw,
    classify_intent, extract_entities, generate_ai_response,
)

logger = logging.getLogger(__name__)

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

    # Each Twilio destination must be provisioned for exactly one account.
    # Never route an unmatched number to an arbitrary customer's agent.
    admin = get_admin_db()
    route_number = admin.table("ai_routing_numbers").select("user_id").eq(
        "phone_number", to_number
    ).eq("is_active", True).maybe_single().execute()
    if not route_number.data or not call_sid or call_type not in ("spam", "busy"):
        from fastapi.responses import Response
        return Response(content="<Response><Reject/></Response>", media_type="application/xml")

    user_id = route_number.data["user_id"]
    config_resp = admin.table("ai_agent_configs").select(
        "user_id, agent_name, spam_handling_enabled, busy_mode_enabled"
    ).eq("user_id", user_id).maybe_single().execute()
    config = config_resp.data
    if not config or not config[f"{'spam_handling' if call_type == 'spam' else 'busy_mode'}_enabled"]:
        from fastapi.responses import Response
        return Response(content="<Response><Reject/></Response>", media_type="application/xml")

    agent_name = config.get("agent_name", "Assistant")

    # Quota check
    profile_resp = admin.table("profiles").select("ai_calls_this_month, ai_calls_limit, plan").eq("id", user_id).single().execute()
    if profile_resp.data:
        p = profile_resp.data
        if p["plan"] != "premium" and p["ai_calls_this_month"] >= p["ai_calls_limit"]:
            # Quota exceeded: reject call without routing to AI to save costs
            reject_twiml = (
                "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                "<Response>\n"
                "  <Say>The person you are calling is currently unavailable.</Say>\n"
                "  <Hangup/>\n"
                "</Response>"
            )
            from fastapi.responses import Response
            return Response(content=reject_twiml, media_type="application/xml")
            
        # Increment usage
        admin.table("profiles").update({"ai_calls_this_month": p["ai_calls_this_month"] + 1}).eq("id", user_id).execute()

    # A random stream parameter binds the WebSocket to this verified webhook.
    # Store only its hash; stream metadata is loaded from the server-side route.
    route_token = secrets.token_urlsafe(32)
    admin.table("ai_call_routes").upsert({
        "call_sid": call_sid,
        "user_id": user_id,
        "caller_number": from_number or "unknown",
        "destination_number": to_number,
        "call_type": call_type,
        "agent_name": agent_name,
        "route_token_hash": hashlib.sha256(route_token.encode()).hexdigest(),
    }, on_conflict="call_sid").execute()

    ws_url = f"wss://{request.headers.get('host', 'api.callerai.app')}/api/v1/ai/call/stream/{call_sid}"
    twiml = build_ai_call_twiml(ws_url, agent_name, route_token)

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
        "route": None,
        "transcript": [],
        "entities": [],
        "audio_buffer": bytearray(),
        "intent": "general",
    }
    try:
        while True:
            raw = await websocket.receive_text()
            msg = json.loads(raw)
            event = msg.get("event")

            if event == "start":
                start = msg.get("start") or {}
                token = (start.get("customParameters") or {}).get("route_token", "")
                route_resp = get_admin_db().table("ai_call_routes").select("*").eq(
                    "call_sid", call_sid
                ).maybe_single().execute()
                route = route_resp.data
                # The stream credential must expire shortly after the signed
                # webhook; a leaked TwiML response cannot authorize a later call.
                created_at = route.get("created_at") if route else None
                issued_at = (datetime.fromisoformat(created_at.replace("Z", "+00:00"))
                             if isinstance(created_at, str) else None)
                now = datetime.now(timezone.utc)
                if (not route or not issued_at or not issued_at.tzinfo or
                        not now - timedelta(minutes=5) <= issued_at <= now + timedelta(seconds=30) or
                        start.get("callSid") != call_sid or
                        not hmac.compare_digest(
                            hashlib.sha256(token.encode()).hexdigest(),
                            route["route_token_hash"],
                        )):
                    await websocket.close(code=1008)
                    break
                if call_sid in active_sessions:
                    await websocket.close(code=1008)
                    break
                session["route"] = route
                session["stream_sid"] = msg.get("streamSid")
                active_sessions[call_sid] = session

            elif event == "media":
                if session["route"] is None:
                    await websocket.close(code=1008)
                    break
                media_obj = msg.get("media")
                if not isinstance(media_obj, dict) or "payload" not in media_obj:
                    logger.warning("Rejecting malformed media event: missing payload (call_sid=%s)", call_sid)
                    await websocket.close(code=1008)
                    break
                try:
                    payload = base64.b64decode(media_obj["payload"], validate=True)
                except Exception:
                    logger.warning("Rejecting malformed media event: invalid base64 (call_sid=%s)", call_sid)
                    await websocket.close(code=1008)
                    break

                if not payload:
                    continue

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

                            # Synthesize and stream back as raw headerless G.711 mu-law at 8 kHz
                            audio_bytes = await synthesize_speech_mulaw(response_text)
                            audio_b64 = base64.b64encode(audio_bytes).decode()

                            await websocket.send_json({
                                "event": "media",
                                "streamSid": session.get("stream_sid"),
                                "media": {"payload": audio_b64},
                            })
                    except Exception as err:
                        logger.error("Provider error during audio processing for call %s: %s", call_sid, type(err).__name__)
                        await websocket.close(code=1011)
                        break

            elif event == "stop":
                if session["route"] is None:
                    await websocket.close(code=1008)
                    break
                # Save transcript to Supabase
                admin = get_admin_db()
                route = session["route"]
                admin.table("ai_call_transcripts").insert({
                    "user_id": route["user_id"],
                    "call_sid": call_sid,
                    "caller_number": route["caller_number"],
                    "call_type": route["call_type"],
                    "agent_name": route["agent_name"],
                    "full_transcript": session["transcript"],
                    "extracted_entities": session["entities"],
                    "summary": session["transcript"][-1]["text"] if session["transcript"] else "",
                }).execute()
                break

    except WebSocketDisconnect:
        pass
    finally:
        if active_sessions.get(call_sid) is session:
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
