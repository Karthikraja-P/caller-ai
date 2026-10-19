import logging
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, HTTPException, status
import httpx

from app.core.config import settings
from app.core.database import get_admin_db
from app.core.rate_limiter import otp_limiter
from app.schemas.auth import (
    RegisterRequest, RegisterResponse,
    VerifyOTPRequest, VerifyOTPResponse,
    RefreshTokenRequest, RefreshTokenResponse,
    UserData,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth", tags=["Authentication"])


def _ensure_supabase_configured() -> None:
    """Fail closed if Supabase configuration is missing."""
    if not settings.SUPABASE_URL or not settings.SUPABASE_ANON_KEY:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Authentication provider configuration missing",
        )


@router.post("/register", response_model=RegisterResponse, status_code=201)
async def register(req: RegisterRequest):
    """
    Send SMS OTP to phone number via Supabase Auth.
    - Validates configuration (requires SUPABASE_ANON_KEY; fails closed if missing)
    - Rate limits by phone number
    - Requests phone SMS OTP from Supabase Auth
    - Binds unexpired server session to phone number
    - Returns session_id and expiry
    """
    _ensure_supabase_configured()
    await otp_limiter.check(req.phone_number)

    headers = {
        "apikey": settings.SUPABASE_ANON_KEY,
        "Content-Type": "application/json",
    }
    payload = {
        "phone": req.phone_number,
        "create_user": True,
    }
    url = f"{settings.SUPABASE_URL}/auth/v1/otp"

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(url, headers=headers, json=payload)
    except httpx.RequestError as err:
        logger.error("Supabase OTP request failed: %s", type(err).__name__)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to connect to authentication provider",
        )

    if resp.status_code != 200:
        logger.error("Supabase OTP send failed with status=%d", resp.status_code)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to send OTP via authentication provider",
        )

    # Store server session bound to exact phone number and expiry
    session_id = f"sess_{secrets.token_urlsafe(24)}"
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=5)

    admin = get_admin_db()
    admin.table("otp_sessions").insert({
        "session_id": session_id,
        "phone_number": req.phone_number,
        "hashed_otp": "supabase_managed",
        "device_uuid": req.device_uuid,
        "device_type": req.device_type,
        "country_code": req.country_code,
        "expires_at": expires_at.isoformat(),
        "verified": False,
    }).execute()

    return RegisterResponse(
        status="success",
        message=f"OTP sent to {req.phone_number}",
        session_id=session_id,
        expires_in=300,
    )


@router.post("/verify-otp", response_model=VerifyOTPResponse)
async def verify_otp(req: VerifyOTPRequest):
    """
    Verify OTP with Supabase Auth and issue genuine session tokens.
    - Validates configuration (requires SUPABASE_ANON_KEY; fails closed if missing)
    - Validates session exists and has not expired
    - Enforces exact phone number match on request
    - Verifies OTP via Supabase Auth GoTrue API
    - Validates provider user.phone matches request/session phone
    - Atomically consumes session (concurrency safe, cannot be replayed)
    - Returns genuine access and refresh tokens
    """
    _ensure_supabase_configured()
    admin = get_admin_db()

    # 1. Fetch server session
    session_resp = admin.table("otp_sessions").select("*").eq(
        "session_id", req.session_id
    ).maybe_single().execute()

    if not session_resp.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": "SESSION_NOT_FOUND", "message": "Invalid session ID."},
        )

    session = session_resp.data

    # 2. Check if already consumed / replay attack
    if session.get("verified") is True:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": "SESSION_ALREADY_USED", "message": "OTP session has already been used."},
        )

    # 3. Check expiration
    expires_at_str = session.get("expires_at", "")
    try:
        expires_at = datetime.fromisoformat(expires_at_str.replace("Z", "+00:00"))
    except Exception:
        expires_at = datetime.min.replace(tzinfo=timezone.utc)

    if datetime.now(timezone.utc) > expires_at:
        admin.table("otp_sessions").delete().eq("session_id", req.session_id).execute()
        raise HTTPException(
            status_code=status.HTTP_410_GONE,
            detail={"error": "OTP_EXPIRED", "message": "OTP expired. Please request a new one."},
        )

    # 4. Enforce exact phone number match with session
    if session.get("phone_number") != req.phone_number:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": "PHONE_MISMATCH", "message": "Phone number does not match session."},
        )

    # 5. Verify OTP via Supabase Auth
    headers = {
        "apikey": settings.SUPABASE_ANON_KEY,
        "Content-Type": "application/json",
    }
    payload = {
        "type": "sms",
        "phone": req.phone_number,
        "token": req.otp_code,
    }
    url = f"{settings.SUPABASE_URL}/auth/v1/verify"

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(url, headers=headers, json=payload)
    except httpx.RequestError as err:
        logger.error("Supabase OTP verify request failed: %s", type(err).__name__)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to connect to authentication provider",
        )

    if resp.status_code != 200:
        logger.warning("Supabase OTP verify rejected with status=%d", resp.status_code)
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": "INVALID_OTP", "message": "Incorrect or expired OTP. Please try again."},
        )

    token_data = resp.json()
    access_token = token_data.get("access_token")
    refresh_token = token_data.get("refresh_token")
    user_info = token_data.get("user") or {}
    user_id = user_info.get("id")
    provider_phone = user_info.get("phone")

    if not access_token or not refresh_token or not user_id:
        logger.error("Supabase OTP verify returned 200 but missing required token attributes")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Authentication provider returned incomplete session",
        )

    # Security check: require provider response user.phone exactly equal to server session and request phone
    if not provider_phone or provider_phone != req.phone_number or provider_phone != session.get("phone_number"):
        logger.warning("Supabase verified user phone mismatch with request/session phone")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": "PHONE_MISMATCH", "message": "Verified phone does not match session."},
        )

    # 6. Concurrency-safe atomic consumption:
    # Conditionally update verified to True where verified == False
    consume_resp = admin.table("otp_sessions").update(
        {"verified": True}
    ).eq("session_id", req.session_id).eq("verified", False).execute()

    if not consume_resp.data:
        logger.warning("OTP session %s already consumed or concurrent race", req.session_id)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": "SESSION_ALREADY_USED", "message": "OTP session has already been used."},
        )

    # Clean up the consumed session
    admin.table("otp_sessions").delete().eq("session_id", req.session_id).execute()

    # 7. Ensure profile row exists
    user_created_at = user_info.get("created_at") or datetime.now(timezone.utc).isoformat()
    admin.table("profiles").upsert({
        "id": user_id,
        "phone_number": req.phone_number,
    }, on_conflict="id").execute()

    return VerifyOTPResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=token_data.get("expires_in", 3600),
        user=UserData(
            id=user_id,
            phone_number=req.phone_number,
            created_at=user_created_at,
        ),
    )


@router.post("/refresh-token", response_model=RefreshTokenResponse)
async def refresh_token(req: RefreshTokenRequest):
    """Refresh JWT access token using refresh token via Supabase Auth."""
    _ensure_supabase_configured()

    headers = {
        "apikey": settings.SUPABASE_ANON_KEY,
        "Content-Type": "application/json",
    }
    url = f"{settings.SUPABASE_URL}/auth/v1/token?grant_type=refresh_token"

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(url, headers=headers, json={"refresh_token": req.refresh_token})
    except httpx.RequestError as err:
        logger.error("Supabase refresh token request failed: %s", type(err).__name__)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to connect to authentication provider",
        )

    if resp.status_code != 200:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": "REFRESH_FAILED", "message": "Refresh token invalid or expired."},
        )

    data = resp.json()
    return RefreshTokenResponse(
        access_token=data["access_token"],
        refresh_token=data["refresh_token"],
        expires_in=data.get("expires_in", 3600),
    )
