from jose import jwt, JWTError
from fastapi import HTTPException, Security, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from app.core.config import settings
import httpx

security = HTTPBearer()


async def verify_jwt(credentials: HTTPAuthorizationCredentials = Security(security)) -> dict:
    """
    Validate Supabase-issued JWT.
    Fetches JWKS from Supabase project and verifies signature.
    """
    token = credentials.credentials
    try:
        # Fetch Supabase JWKS
        jwks_url = f"{settings.SUPABASE_URL}/auth/v1/.well-known/jwks.json"
        async with httpx.AsyncClient() as client:
            resp = await client.get(jwks_url)
            jwks = resp.json()

        # Decode header to find key id
        unverified_header = jwt.get_unverified_header(token)
        key = None
        for k in jwks.get("keys", []):
            if k.get("kid") == unverified_header.get("kid"):
                key = k
                break

        if not key:
            # Fallback: use anon key as HS256 secret for dev
            payload = jwt.decode(
                token,
                settings.SUPABASE_SERVICE_KEY,
                algorithms=["HS256"],
                options={"verify_aud": False},
            )
        else:
            payload = jwt.decode(
                token,
                key,
                algorithms=["RS256"],
                options={"verify_aud": False},
            )

        user_id = payload.get("sub")
        if not user_id:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token: no subject")

        return {"user_id": user_id, "payload": payload}

    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid or expired token: {str(e)}",
        )


def get_current_user(token_data: dict = Security(verify_jwt)) -> str:
    """Returns user_id string from validated JWT."""
    return token_data["user_id"]
