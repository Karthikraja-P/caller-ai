import logging
import re
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
import httpx
from pydantic import BaseModel

from app.core.config import settings
from app.core.database import get_admin_db
from app.core.security import get_current_user
from app.core.twilio_client import build_voicemail_twiml, validate_twilio_signature

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/voicemail", tags=["Voicemail"])

CALL_SID_PATTERN = re.compile(r"^CA[a-zA-Z0-9]{16,48}$")
RECORDING_SID_PATTERN = re.compile(r"^RE[a-zA-Z0-9]{16,48}$")
MAX_AUDIO_BYTES = 10 * 1024 * 1024  # 10 MB maximum audio buffer for voicemail


def _ensure_twilio_configured() -> None:
    """
    Fail closed if Twilio account or auth token configuration is missing.
    """
    if not (settings.TWILIO_ACCOUNT_SID and settings.TWILIO_AUTH_TOKEN):
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Telephony service configuration missing",
        )


def _get_public_https_base_url() -> str:
    """
    Retrieve required configured public HTTPS base URL.
    Never trusts request Host or scheme.
    Fails closed if unset or not using https://.
    """
    base = (settings.TWILIO_WEBHOOK_BASE_URL or settings.PUBLIC_BASE_URL or "").strip().rstrip("/")
    if not base or not base.startswith("https://"):
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Public HTTPS webhook base URL is not configured",
        )
    return base


def _verify_account_sid(form_dict: dict) -> str:
    """
    Validate that the incoming webhook's AccountSid matches configured TWILIO_ACCOUNT_SID.
    """
    account_sid = form_dict.get("AccountSid", "")
    if not account_sid or account_sid != settings.TWILIO_ACCOUNT_SID:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="AccountSid mismatch or missing",
        )
    return account_sid


# ── Inbound Call Webhook (Twilio Voice) ─────────────────────────

@router.post("/handle")
async def handle_voicemail_call(request: Request):
    """
    Inbound Twilio Voice webhook for Caller AI v1 Voicemail.
    Validates Twilio signature against canonical public URL and AccountSid, ensures To number is provisioned for an account,
    greets caller with short consent/recording prompt, records bounded message,
    and hangs up to prevent looping.
    """
    _ensure_twilio_configured()
    base_url = _get_public_https_base_url()
    form = await request.form()
    signature = request.headers.get("X-Twilio-Signature", "")
    canonical_url = f"{base_url}/api/v1/voicemail/handle"
    form_dict = {k: str(v) for k, v in form.items()}

    if not validate_twilio_signature(canonical_url, form_dict, signature):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid Twilio signature")

    _verify_account_sid(form_dict)

    call_sid = form_dict.get("CallSid", "")
    if not call_sid or not CALL_SID_PATTERN.match(call_sid):
        return Response(content="<Response><Reject/></Response>", media_type="application/xml")

    from_number = form_dict.get("From", "")
    to_number = form_dict.get("To", "")

    # Look up account assigned to this Twilio destination number
    admin = get_admin_db()
    route_number = admin.table("ai_routing_numbers").select("user_id").eq(
        "phone_number", to_number
    ).eq("is_active", True).maybe_single().execute()

    if not route_number.data:
        return Response(content="<Response><Reject/></Response>", media_type="application/xml")

    user_id = route_number.data["user_id"]

    # Optional greeting lookup from user agent config
    greeting = "Please leave your message after the tone. When you have finished recording, you may hang up."
    config_resp = admin.table("ai_agent_configs").select("greeting_template, agent_name").eq(
        "user_id", user_id
    ).maybe_single().execute()
    if config_resp.data and config_resp.data.get("greeting_template"):
        agent_name = config_resp.data.get("agent_name") or "Assistant"
        greeting = config_resp.data["greeting_template"].replace("{{agent_name}}", agent_name)

    # Track call route for callback verification
    admin.table("ai_call_routes").upsert({
        "call_sid": call_sid,
        "user_id": user_id,
        "caller_number": from_number or "unknown",
        "destination_number": to_number,
        "call_type": "busy",
        "agent_name": "Voicemail",
        "route_token_hash": "",
    }, on_conflict="call_sid").execute()

    action_url = f"{base_url}/api/v1/voicemail/action"
    callback_url = f"{base_url}/api/v1/voicemail/callback"

    twiml = build_voicemail_twiml(
        greeting_text=greeting,
        action_url=action_url,
        status_callback_url=callback_url,
        max_length=120,
    )
    return Response(content=twiml, media_type="application/xml")


# ── Record Action Webhook ───────────────────────────────────────

@router.post("/action")
async def handle_voicemail_action(request: Request):
    """
    Called by Twilio when caller finishes recording (hangup, silence, or #).
    """
    _ensure_twilio_configured()
    base_url = _get_public_https_base_url()
    form = await request.form()
    signature = request.headers.get("X-Twilio-Signature", "")
    canonical_url = f"{base_url}/api/v1/voicemail/action"
    form_dict = {k: str(v) for k, v in form.items()}

    if not validate_twilio_signature(canonical_url, form_dict, signature):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid Twilio signature")

    _verify_account_sid(form_dict)

    call_sid = form_dict.get("CallSid", "")
    if call_sid and not CALL_SID_PATTERN.match(call_sid):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid CallSid format")

    twiml = (
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        "<Response>\n"
        "  <Say>Thank you. Your message has been saved.</Say>\n"
        "  <Hangup/>\n"
        "</Response>"
    )
    return Response(content=twiml, media_type="application/xml")


# ── Recording Status Callback ───────────────────────────────────

@router.post("/callback")
async def handle_recording_callback(request: Request):
    """
    Signed callback called by Twilio when recording is processed.
    Validates AccountSid, CallSid, and RecordingSid against call route.
    Ignores external RecordingUrl; derives canonical Twilio URL.
    Idempotently persists completed recordings and blocks reassignment.
    """
    _ensure_twilio_configured()
    base_url = _get_public_https_base_url()
    form = await request.form()
    signature = request.headers.get("X-Twilio-Signature", "")
    canonical_url = f"{base_url}/api/v1/voicemail/callback"
    form_dict = {k: str(v) for k, v in form.items()}

    if not validate_twilio_signature(canonical_url, form_dict, signature):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Invalid Twilio signature")

    _verify_account_sid(form_dict)

    recording_status = form_dict.get("RecordingStatus", "")
    if recording_status != "completed":
        # Discard absent, failed, or incomplete recordings
        return {"status": "ignored", "recording_status": recording_status}

    call_sid = form_dict.get("CallSid", "")
    recording_sid = form_dict.get("RecordingSid", "")
    duration_str = form_dict.get("RecordingDuration", "0")

    if not call_sid or not recording_sid:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Missing required recording parameters")

    if not CALL_SID_PATTERN.match(call_sid) or not RECORDING_SID_PATTERN.match(recording_sid):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid CallSid or RecordingSid format")

    admin = get_admin_db()
    route_resp = admin.table("ai_call_routes").select("*").eq("call_sid", call_sid).maybe_single().execute()
    route = route_resp.data

    if not route:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Matching call route not found")

    # Guard against duplicate/forged callbacks reassigning an existing recording to a different user/call
    existing_rec = admin.table("voicemails").select("user_id, call_sid").eq("recording_sid", recording_sid).maybe_single().execute()
    if existing_rec.data:
        if str(existing_rec.data.get("user_id")) != str(route["user_id"]) or str(existing_rec.data.get("call_sid")) != str(call_sid):
            logger.warning(
                "Duplicate callback attempted to reassign recording_sid=%s to different user/call",
                recording_sid,
            )
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="RecordingSid already bound to another call or user",
            )

    try:
        duration = int(float(duration_str))
    except (ValueError, TypeError):
        duration = 0

    # Never store or trust provider-supplied RecordingUrl from callback payload.
    # Derive canonical URL strictly from configured AccountSid and validated RecordingSid.
    canonical_recording_url = (
        f"https://api.twilio.com/2010-04-01/Accounts/{settings.TWILIO_ACCOUNT_SID}/Recordings/{recording_sid}"
    )

    admin.table("voicemails").upsert({
        "user_id": route["user_id"],
        "call_sid": call_sid,
        "recording_sid": recording_sid,
        "recording_url": canonical_recording_url,
        "caller_number": route["caller_number"],
        "destination_number": route["destination_number"],
        "duration_seconds": duration,
        "status": "completed",
        "transcription": None,  # optional and disabled in v1
        "is_read": False,
    }, on_conflict="recording_sid").execute()

    return {"status": "saved", "recording_sid": recording_sid}


# ── Authenticated Voicemail Messages API ───────────────────────

@router.get("/messages")
async def list_voicemail_messages(
    user_id: str = Depends(get_current_user),
    page: int = Query(1, ge=1),
    per_page: int = Query(20, ge=1, le=100),
    unread_only: bool = Query(False),
):
    """
    List user's voicemails with pagination.
    Does NOT expose raw Twilio recording URLs or credentials.
    """
    admin = get_admin_db()
    query = admin.table("voicemails").select(
        "id, caller_number, destination_number, duration_seconds, status, transcription, is_read, created_at"
    ).eq("user_id", user_id)

    if unread_only:
        query = query.eq("is_read", False)

    start_idx = (page - 1) * per_page
    end_idx = start_idx + per_page - 1

    resp = query.order("created_at", desc=True).range(start_idx, end_idx).execute()
    messages = resp.data or []

    return {
        "messages": messages,
        "page": page,
        "per_page": per_page,
    }


@router.get("/messages/{voicemail_id}")
async def get_voicemail_detail(
    voicemail_id: str,
    user_id: str = Depends(get_current_user),
):
    """
    Retrieve single voicemail metadata verifying account ownership.
    """
    admin = get_admin_db()
    resp = admin.table("voicemails").select(
        "id, caller_number, destination_number, duration_seconds, status, transcription, is_read, created_at"
    ).eq("id", voicemail_id).eq("user_id", user_id).maybe_single().execute()

    if not resp.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Voicemail not found")

    return resp.data


class MarkReadRequest(BaseModel):
    is_read: bool = True


@router.patch("/messages/{voicemail_id}/read")
async def update_voicemail_read_status(
    voicemail_id: str,
    req: MarkReadRequest = MarkReadRequest(is_read=True),
    user_id: str = Depends(get_current_user),
):
    """
    Update read status of a voicemail message.
    """
    admin = get_admin_db()
    check = admin.table("voicemails").select("id").eq("id", voicemail_id).eq("user_id", user_id).maybe_single().execute()
    if not check.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Voicemail not found")

    admin.table("voicemails").update({"is_read": req.is_read}).eq("id", voicemail_id).eq("user_id", user_id).execute()
    return {"id": voicemail_id, "is_read": req.is_read}


@router.delete("/messages/{voicemail_id}")
async def delete_voicemail(
    voicemail_id: str,
    user_id: str = Depends(get_current_user),
):
    """
    Delete a voicemail message verifying account ownership.
    Deletes Twilio recording media before local metadata.
    Keeps metadata on provider failure (non-204/404 response or network error).
    """
    _ensure_twilio_configured()

    admin = get_admin_db()
    rec_resp = admin.table("voicemails").select("id, recording_sid").eq(
        "id", voicemail_id
    ).eq("user_id", user_id).maybe_single().execute()

    if not rec_resp.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Voicemail not found")

    rec_sid = rec_resp.data.get("recording_sid")
    if not rec_sid or not RECORDING_SID_PATTERN.match(rec_sid):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid stored recording identifier",
        )

    delete_url = (
        f"https://api.twilio.com/2010-04-01/Accounts/{settings.TWILIO_ACCOUNT_SID}/Recordings/{rec_sid}.json"
    )
    auth = (settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)

    try:
        async with httpx.AsyncClient(timeout=20.0, follow_redirects=False) as client:
            resp = await client.delete(delete_url, auth=auth)
            # Twilio returns 204 No Content when deleted; 404 if already absent.
            # Provider failure (5xx, 401, etc.) must fail closed and preserve local metadata.
            if resp.status_code not in (204, 404):
                logger.error(
                    "Twilio recording deletion failed status=%d for rec_sid=%s",
                    resp.status_code,
                    rec_sid,
                )
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail="Failed to delete recording media from telephony provider",
                )
    except httpx.RequestError as err:
        logger.error("Twilio delete request error: %s", type(err).__name__)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Error connecting to telephony provider during recording deletion",
        )

    admin.table("voicemails").delete().eq("id", voicemail_id).eq("user_id", user_id).execute()
    return {"deleted": True, "id": voicemail_id}



# ── Secure Playback Proxy ───────────────────────────────────────

@router.get("/messages/{voicemail_id}/audio")
async def stream_voicemail_audio(
    voicemail_id: str,
    user_id: str = Depends(get_current_user),
):
    """
    Secure server-side playback proxy.
    Verifies user ownership, derives playback URL solely from configured account SID
    and validated recording SID on canonical api.twilio.com, uses Basic Auth without following
    redirects, caps response size at 10 MB, and rejects non-audio content.
    Never exposes Twilio recording URLs or credentials.
    """
    _ensure_twilio_configured()

    admin = get_admin_db()
    resp = admin.table("voicemails").select("recording_sid").eq(
        "id", voicemail_id
    ).eq("user_id", user_id).maybe_single().execute()

    if not resp.data or not resp.data.get("recording_sid"):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Voicemail recording not found")

    rec_sid = resp.data["recording_sid"]
    if not RECORDING_SID_PATTERN.match(rec_sid):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid stored recording identifier")

    audio_url = f"https://api.twilio.com/2010-04-01/Accounts/{settings.TWILIO_ACCOUNT_SID}/Recordings/{rec_sid}.mp3"
    auth = (settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)

    try:
        async with httpx.AsyncClient(timeout=20.0, follow_redirects=False) as client:
            async with client.stream("GET", audio_url, auth=auth) as tw_resp:
                if tw_resp.status_code != 200:
                    logger.error("Twilio audio fetch failed status=%d", tw_resp.status_code)
                    raise HTTPException(
                        status_code=status.HTTP_502_BAD_GATEWAY,
                        detail="Failed to retrieve recording from telephony provider",
                    )

                content_type = tw_resp.headers.get("content-type", "").lower()
                if not content_type.startswith("audio/"):
                    logger.error("Twilio audio fetch rejected non-audio content-type=%s", content_type)
                    raise HTTPException(
                        status_code=status.HTTP_502_BAD_GATEWAY,
                        detail="Telephony provider returned non-audio content",
                    )

                cl_header = tw_resp.headers.get("content-length")
                if cl_header:
                    try:
                        if int(cl_header) > MAX_AUDIO_BYTES:
                            raise HTTPException(
                                status_code=status.HTTP_502_BAD_GATEWAY,
                                detail="Audio recording exceeds maximum allowed size",
                            )
                    except ValueError:
                        pass

                audio_buffer = bytearray()
                async for chunk in tw_resp.aiter_bytes():
                    audio_buffer.extend(chunk)
                    if len(audio_buffer) > MAX_AUDIO_BYTES:
                        logger.error("Twilio audio stream exceeded max size %d bytes", MAX_AUDIO_BYTES)
                        raise HTTPException(
                            status_code=status.HTTP_502_BAD_GATEWAY,
                            detail="Audio recording exceeds maximum allowed size",
                        )

                return Response(content=bytes(audio_buffer), media_type=content_type)
    except httpx.RequestError as err:
        logger.error("Twilio audio proxy request error: %s", type(err).__name__)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Error connecting to telephony provider",
        )
