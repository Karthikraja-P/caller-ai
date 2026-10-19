import logging
from typing import Dict, Any

from fastapi import HTTPException, Security, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)

security = HTTPBearer(auto_error=True)


def _ensure_supabase_configured() -> None:
    """Fail closed if Supabase configuration is missing."""
    if not settings.SUPABASE_URL or not settings.SUPABASE_ANON_KEY:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Authentication provider configuration missing",
        )


async def verify_jwt(credentials: HTTPAuthorizationCredentials = Security(security)) -> Dict[str, Any]:
    """
    Validate Supabase-issued Bearer JWT against Supabase Auth (/auth/v1/user).
    Requires authenticated role, audience, and subject.
    Requires SUPABASE_ANON_KEY; no service-key fallback or local bypass. Fails closed on provider errors.
    """
    _ensure_supabase_configured()

    token = credentials.credentials if credentials else ""
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing authentication credentials",
        )

    headers = {
        "apikey": settings.SUPABASE_ANON_KEY,
        "Authorization": f"Bearer {token}",
    }
    url = f"{settings.SUPABASE_URL}/auth/v1/user"

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(url, headers=headers)
    except httpx.RequestError as err:
        logger.error("Supabase auth verification request error: %s", type(err).__name__)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Authentication provider unreachable",
        )

    if resp.status_code in (status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired authentication token",
        )

    if resp.status_code != 200:
        logger.error("Supabase auth verification failed with status: %d", resp.status_code)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Authentication provider returned an error",
        )

    try:
        user_data = resp.json()
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Malformed authentication provider response",
        )

    user_id = user_data.get("id")
    aud = user_data.get("aud")
    role = user_data.get("role")

    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token: no subject claim",
        )

    # Require authenticated role and audience; reject service_role or other roles
    if aud != "authenticated" or role != "authenticated":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token: unauthorized role or audience",
        )

    return {"user_id": user_id, "payload": user_data}


def get_current_user(token_data: Dict[str, Any] = Security(verify_jwt)) -> str:
    """Returns user_id string from validated JWT."""
    return token_data["user_id"]
