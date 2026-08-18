import hashlib
import secrets
import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, HTTPException, status
from app.core.database import get_admin_db
from app.core.twilio_client import send_otp_via_twilio, check_otp_via_twilio
from app.core.rate_limiter import otp_limiter
from app.schemas.auth import (
    RegisterRequest, RegisterResponse,
    VerifyOTPRequest, VerifyOTPResponse,
    RefreshTokenRequest, RefreshTokenResponse,
    UserData,
)

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=RegisterResponse, status_code=201)
async def register(req: RegisterRequest):
    """
    Send OTP to phone number.
    - New user: creates otp_session, sends OTP via Twilio Verify, returns 201
    - Existing user: still sends OTP (for login), returns 409 with USER_EXISTS code
    """
    await otp_limiter.check(req.phone_number)

    admin = get_admin_db()

    # Check if user already exists
    try:
        existing = admin.auth.admin.list_users()
        user_exists = any(
            getattr(u, "phone", None) == req.phone_number
            for u in existing
        )
    except Exception:
        user_exists = False

    # Send OTP via Twilio Verify
    try:
        send_otp_via_twilio(req.phone_number)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail={"error": "OTP_SEND_FAILED", "message": str(e)},
        )

    # Store session in Supabase
    session_id = f"sess_{secrets.token_urlsafe(12)}"
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=5)

    admin.table("otp_sessions").insert({
        "session_id": session_id,
        "phone_number": req.phone_number,
        "hashed_otp": "twilio_managed",  # Twilio manages OTP hash
        "device_uuid": req.device_uuid,
        "device_type": req.device_type,
        "country_code": req.country_code,
        "expires_at": expires_at.isoformat(),
    }).execute()

    if user_exists:
        return RegisterResponse(
            status="error",
            message="Account already exists. Verifying OTP will log you in.",
            session_id=session_id,
            expires_in=300,
        )

    return RegisterResponse(
        status="success",
        message=f"OTP sent to {req.phone_number}",
        session_id=session_id,
        expires_in=300,
    )


@router.post("/verify-otp", response_model=VerifyOTPResponse)
async def verify_otp(req: VerifyOTPRequest):
    """
    Verify OTP and issue JWT tokens.
    - Validates session exists and hasn't expired
    - Checks OTP via Twilio Verify
    - Creates or retrieves Supabase Auth user
    - Creates profile row if new user
    - Returns access + refresh tokens
    """
    admin = get_admin_db()

    # Fetch session
    session_resp = admin.table("otp_sessions").select("*").eq(
        "session_id", req.session_id
    ).single().execute()

    if not session_resp.data:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": "SESSION_NOT_FOUND", "message": "Invalid session ID."},
        )

    session = session_resp.data
    expires_at = datetime.fromisoformat(session["expires_at"].replace("Z", "+00:00"))
    if datetime.now(timezone.utc) > expires_at:
        raise HTTPException(
            status_code=status.HTTP_410_GONE,
            detail={"error": "OTP_EXPIRED", "message": "OTP expired. Please request a new one."},
        )

    # Verify OTP via Twilio Verify
    otp_valid = check_otp_via_twilio(req.phone_number, req.otp_code)
    if not otp_valid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": "INVALID_OTP", "message": "Incorrect OTP. Please try again."},
        )

    # Create or get Supabase Auth user
    try:
        auth_resp = admin.auth.admin.create_user({
            "phone": req.phone_number,
            "phone_confirm": True,
        })
        user_id = auth_resp.user.id
        is_new_user = True
    except Exception as e:
        if "already been registered" in str(e) or "duplicate" in str(e).lower():
            # Existing user — find by phone
            users = admin.auth.admin.list_users()
            user = next(
                (u for u in users if getattr(u, "phone", None) == req.phone_number),
                None
            )
            if not user:
                raise HTTPException(status_code=500, detail="User lookup failed")
            user_id = user.id
            is_new_user = False
        else:
            raise HTTPException(status_code=500, detail=str(e))

    # Create profile if new user
    if is_new_user:
        admin.table("profiles").insert({
            "id": user_id,
            "phone_number": req.phone_number,
        }).execute()

    # Sign in to get JWT tokens
    sign_in = admin.auth.admin.generate_link({
        "type": "magiclink",
        "email": f"{user_id}@callerai.internal",  # Supabase requires email for link gen
    })

    # Generate session tokens via Supabase
    token_resp = admin.auth.sign_in_with_password({
        "phone": req.phone_number,
        "password": user_id,  # Fallback: use service key to create session
    })

    # Use admin sign_in to generate tokens
    session_data = admin.auth.admin.create_user({
        "id": user_id,
    })

    # Direct token generation via Supabase REST
    import httpx
    from app.core.config import settings

    async with httpx.AsyncClient() as client:
        token_response = await client.post(
            f"{settings.SUPABASE_URL}/auth/v1/token?grant_type=password",
            headers={
                "apikey": settings.SUPABASE_SERVICE_KEY,
                "Content-Type": "application/json",
            },
            json={"phone": req.phone_number, "password": user_id},
        )

    if token_response.status_code != 200:
        # Generate tokens via admin endpoint
        import jose.jwt as jwt_lib
        import time
        access_payload = {
            "sub": user_id,
            "aud": "authenticated",
            "role": "authenticated",
            "iat": int(time.time()),
            "exp": int(time.time()) + 1800,
        }
        access_token = jwt_lib.encode(
            access_payload, settings.SUPABASE_SERVICE_KEY, algorithm="HS256"
        )
        refresh_token = secrets.token_urlsafe(64)
    else:
        token_data = token_response.json()
        access_token = token_data.get("access_token", "")
        refresh_token = token_data.get("refresh_token", "")

    # Delete used OTP session
    admin.table("otp_sessions").delete().eq("session_id", req.session_id).execute()

    return VerifyOTPResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=1800,
        user=UserData(
            id=user_id,
            phone_number=req.phone_number,
            created_at=datetime.now(timezone.utc).isoformat(),
        ),
    )


@router.post("/refresh-token", response_model=RefreshTokenResponse)
async def refresh_token(req: RefreshTokenRequest):
    """Refresh JWT access token using refresh token via Supabase."""
    import httpx
    from app.core.config import settings

    async with httpx.AsyncClient() as client:
        resp = await client.post(
            f"{settings.SUPABASE_URL}/auth/v1/token?grant_type=refresh_token",
            headers={
                "apikey": settings.SUPABASE_ANON_KEY,
                "Content-Type": "application/json",
            },
            json={"refresh_token": req.refresh_token},
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
        expires_in=data.get("expires_in", 1800),
    )
