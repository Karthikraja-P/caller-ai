import asyncio
import sys
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch
import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from fastapi.security import HTTPAuthorizationCredentials

for _mod in ("supabase", "supabase.lib", "supabase.lib.client_options", "redis", "redis.asyncio"):
    if _mod not in sys.modules:
        sys.modules[_mod] = MagicMock()
if "jose" not in sys.modules:
    sys.modules["jose"] = MagicMock()
if "phonenumbers" not in sys.modules:
    mock_pn = MagicMock()
    mock_pn.is_valid_number.return_value = True
    mock_pn.format_number.side_effect = lambda parsed, fmt: str(parsed)
    mock_pn.parse.side_effect = lambda v, *a: v
    mock_pn.PhoneNumberFormat = MagicMock(E164=1)
    sys.modules["phonenumbers"] = mock_pn

mock_redis_client = AsyncMock()
sys.modules["redis.asyncio"].from_url = AsyncMock(return_value=mock_redis_client)

from app.api.v1.endpoints import auth
from app.core.config import settings
from app.core.security import verify_jwt, get_current_user


USER_ID = "00000000-0000-4000-8000-000000000123"
PHONE = "+15551234567"
SUPABASE_URL = "https://mockproject.supabase.co"
ANON_KEY = "mock-anon-key"
SERVICE_KEY = "mock-service-key"


class FakeQuery:
    def __init__(self, db, table_name: str):
        self.db = db
        self.table_name = table_name
        self.filters = {}
        self._insert_data = None
        self._update_data = None
        self._upsert_data = None
        self._delete_active = False

    def select(self, *_):
        return self

    def eq(self, key, value):
        self.filters[key] = value
        return self

    def maybe_single(self):
        return self

    def single(self):
        return self

    def insert(self, data):
        self._insert_data = data
        return self

    def update(self, data):
        self._update_data = data
        return self

    def upsert(self, data, **_):
        self._upsert_data = data
        return self

    def delete(self):
        self._delete_active = True
        return self

    def execute(self):
        if self._insert_data is not None:
            if self.table_name == "otp_sessions":
                self.db.otp_sessions.append(dict(self._insert_data))
            return SimpleNamespace(data=self._insert_data)

        if self._update_data is not None:
            updated = []
            if self.table_name == "otp_sessions":
                for s in self.db.otp_sessions:
                    match = True
                    for k, v in self.filters.items():
                        if str(s.get(k)) != str(v):
                            match = False
                            break
                    if match:
                        s.update(self._update_data)
                        updated.append(dict(s))
            return SimpleNamespace(data=updated if updated else None)

        if self._upsert_data is not None:
            if self.table_name == "profiles":
                p_id = self._upsert_data.get("id")
                existing = next((p for p in self.db.profiles if p.get("id") == p_id), None)
                if existing:
                    existing.update(self._upsert_data)
                else:
                    self.db.profiles.append(dict(self._upsert_data))
            return SimpleNamespace(data=self._upsert_data)

        if self._delete_active:
            if self.table_name == "otp_sessions":
                to_keep = []
                for s in self.db.otp_sessions:
                    match = True
                    for k, v in self.filters.items():
                        if str(s.get(k)) != str(v):
                            match = False
                            break
                    if not match:
                        to_keep.append(s)
                self.db.otp_sessions = to_keep
            return SimpleNamespace(data=None)

        if self.table_name == "otp_sessions":
            results = []
            for s in self.db.otp_sessions:
                match = True
                for k, v in self.filters.items():
                    if str(s.get(k)) != str(v):
                        match = False
                        break
                if match:
                    results.append(s)
            data = results[0] if results else None
            return SimpleNamespace(data=data)

        if self.table_name == "profiles":
            results = []
            for p in self.db.profiles:
                match = True
                for k, v in self.filters.items():
                    if str(p.get(k)) != str(v):
                        match = False
                        break
                if match:
                    results.append(p)
            data = results[0] if results else None
            return SimpleNamespace(data=data)

        raise NotImplementedError(self.table_name)


class FakeDB:
    def __init__(self):
        self.otp_sessions = []
        self.profiles = []

    def table(self, name: str):
        return FakeQuery(self, name)


@pytest.fixture
def fake_db():
    return FakeDB()


@pytest.fixture
def app(fake_db):
    app = FastAPI()
    app.include_router(auth.router, prefix="/api/v1")
    with patch("app.api.v1.endpoints.auth.get_admin_db", return_value=fake_db), \
         patch.object(settings, "SUPABASE_URL", SUPABASE_URL), \
         patch.object(settings, "SUPABASE_ANON_KEY", ANON_KEY), \
         patch.object(settings, "SUPABASE_SERVICE_KEY", SERVICE_KEY):
        yield app


# ── 1. Provider Configuration Fail-Closed Tests ─────────────────

def test_register_fails_closed_when_supabase_unconfigured(app):
    client = TestClient(app)
    with patch.object(settings, "SUPABASE_URL", None):
        resp = client.post(
            "/api/v1/auth/register",
            json={
                "phone_number": PHONE,
                "device_uuid": "dev-123",
                "device_type": "android",
                "country_code": "US",
            },
        )
        assert resp.status_code == 503
        assert resp.json()["detail"] == "Authentication provider configuration missing"


def test_register_fails_closed_when_supabase_anon_key_missing(app):
    client = TestClient(app)
    # Even if SUPABASE_SERVICE_KEY is set, SUPABASE_ANON_KEY must be required!
    with patch.object(settings, "SUPABASE_ANON_KEY", None):
        resp = client.post(
            "/api/v1/auth/register",
            json={
                "phone_number": PHONE,
                "device_uuid": "dev-123",
                "device_type": "android",
                "country_code": "US",
            },
        )
        assert resp.status_code == 503
        assert resp.json()["detail"] == "Authentication provider configuration missing"


def test_verify_otp_fails_closed_when_supabase_unconfigured(app):
    client = TestClient(app)
    with patch.object(settings, "SUPABASE_URL", None):
        resp = client.post(
            "/api/v1/auth/verify-otp",
            json={"session_id": "sess_abc", "otp_code": "123456", "phone_number": PHONE},
        )
        assert resp.status_code == 503


def test_verify_otp_fails_closed_when_supabase_anon_key_missing(app):
    client = TestClient(app)
    with patch.object(settings, "SUPABASE_ANON_KEY", None):
        resp = client.post(
            "/api/v1/auth/verify-otp",
            json={"session_id": "sess_abc", "otp_code": "123456", "phone_number": PHONE},
        )
        assert resp.status_code == 503


def test_refresh_token_fails_closed_when_supabase_unconfigured(app):
    client = TestClient(app)
    with patch.object(settings, "SUPABASE_URL", None):
        resp = client.post("/api/v1/auth/refresh-token", json={"refresh_token": "rt_123"})
        assert resp.status_code == 503


def test_verify_jwt_fails_closed_when_supabase_unconfigured():
    async def _test():
        with patch.object(settings, "SUPABASE_URL", None):
            with pytest.raises(HTTPException) as exc_info:
                await verify_jwt(HTTPAuthorizationCredentials(scheme="Bearer", credentials="token"))
            assert exc_info.value.status_code == 503
    asyncio.run(_test())


def test_verify_jwt_fails_closed_when_supabase_anon_key_missing():
    async def _test():
        with patch.object(settings, "SUPABASE_URL", SUPABASE_URL), \
             patch.object(settings, "SUPABASE_ANON_KEY", None):
            with pytest.raises(HTTPException) as exc_info:
                await verify_jwt(HTTPAuthorizationCredentials(scheme="Bearer", credentials="token"))
            assert exc_info.value.status_code == 503
    asyncio.run(_test())


# ── 2. Register (SMS OTP Request & Session Binding) Tests ───────

def test_register_success_requests_supabase_otp_and_creates_session(app, fake_db):
    client = TestClient(app)
    mock_response = MagicMock(status_code=200, json=lambda: {"message_id": "msg-123"})

    with patch("httpx.AsyncClient.post", new_callable=AsyncMock, return_value=mock_response) as mock_post, \
         patch("app.core.rate_limiter.otp_limiter.check", new_callable=AsyncMock):
        resp = client.post(
            "/api/v1/auth/register",
            json={
                "phone_number": PHONE,
                "device_uuid": "uuid-123",
                "device_type": "android",
                "country_code": "US",
            },
        )
        assert resp.status_code == 201
        data = resp.json()
        assert data["status"] == "success"
        assert data["session_id"].startswith("sess_")
        assert data["expires_in"] == 300

        # Verify Supabase OTP API was called with strict ANON_KEY
        mock_post.assert_called_once()
        call_url = mock_post.call_args[0][0]
        call_headers = mock_post.call_args[1]["headers"]
        call_json = mock_post.call_args[1]["json"]
        assert call_url == f"{SUPABASE_URL}/auth/v1/otp"
        assert call_headers["apikey"] == ANON_KEY
        assert call_json == {"phone": PHONE, "create_user": True}

        # Verify server session created in DB bound to exact phone
        assert len(fake_db.otp_sessions) == 1
        sess = fake_db.otp_sessions[0]
        assert sess["session_id"] == data["session_id"]
        assert sess["phone_number"] == PHONE
        assert sess["verified"] is False


def test_register_fails_closed_on_provider_error(app, fake_db):
    client = TestClient(app)
    mock_error_resp = MagicMock(status_code=500, text="SMS Gateway Failure")

    with patch("httpx.AsyncClient.post", new_callable=AsyncMock, return_value=mock_error_resp), \
         patch("app.core.rate_limiter.otp_limiter.check", new_callable=AsyncMock):
        resp = client.post(
            "/api/v1/auth/register",
            json={
                "phone_number": PHONE,
                "device_uuid": "uuid-123",
                "device_type": "android",
                "country_code": "US",
            },
        )
        assert resp.status_code == 502
        assert resp.json()["detail"] == "Failed to send OTP via authentication provider"
        assert len(fake_db.otp_sessions) == 0


# ── 3. Verify OTP & Token Issuance Tests ─────────────────────────

def test_verify_otp_rejects_unknown_session(app):
    client = TestClient(app)
    resp = client.post(
        "/api/v1/auth/verify-otp",
        json={"session_id": "sess_non_existent", "otp_code": "654321", "phone_number": PHONE},
    )
    assert resp.status_code == 404
    assert resp.json()["detail"]["error"] == "SESSION_NOT_FOUND"


def test_verify_otp_rejects_mismatched_phone(app, fake_db):
    client = TestClient(app)
    fake_db.otp_sessions.append({
        "session_id": "sess_test",
        "phone_number": PHONE,
        "expires_at": (datetime.now(timezone.utc) + timedelta(minutes=5)).isoformat(),
        "verified": False,
    })

    resp = client.post(
        "/api/v1/auth/verify-otp",
        json={"session_id": "sess_test", "otp_code": "123456", "phone_number": "+15559998888"},
    )
    assert resp.status_code == 400
    assert resp.json()["detail"]["error"] == "PHONE_MISMATCH"


def test_verify_otp_rejects_expired_session(app, fake_db):
    client = TestClient(app)
    fake_db.otp_sessions.append({
        "session_id": "sess_expired",
        "phone_number": PHONE,
        "expires_at": (datetime.now(timezone.utc) - timedelta(minutes=1)).isoformat(),
        "verified": False,
    })

    resp = client.post(
        "/api/v1/auth/verify-otp",
        json={"session_id": "sess_expired", "otp_code": "123456", "phone_number": PHONE},
    )
    assert resp.status_code == 410
    assert resp.json()["detail"]["error"] == "OTP_EXPIRED"
    assert len(fake_db.otp_sessions) == 0


def test_verify_otp_rejects_invalid_otp_from_provider(app, fake_db):
    client = TestClient(app)
    fake_db.otp_sessions.append({
        "session_id": "sess_valid",
        "phone_number": PHONE,
        "expires_at": (datetime.now(timezone.utc) + timedelta(minutes=5)).isoformat(),
        "verified": False,
    })

    mock_error_resp = MagicMock(status_code=400, text="Token has expired or is invalid")
    with patch("httpx.AsyncClient.post", new_callable=AsyncMock, return_value=mock_error_resp):
        resp = client.post(
            "/api/v1/auth/verify-otp",
            json={"session_id": "sess_valid", "otp_code": "999999", "phone_number": PHONE},
        )
        assert resp.status_code == 401
        assert resp.json()["detail"]["error"] == "INVALID_OTP"
        assert len(fake_db.otp_sessions) == 1


def test_verify_otp_rejects_provider_user_phone_mismatch(app, fake_db):
    client = TestClient(app)
    fake_db.otp_sessions.append({
        "session_id": "sess_mismatch",
        "phone_number": PHONE,
        "expires_at": (datetime.now(timezone.utc) + timedelta(minutes=5)).isoformat(),
        "verified": False,
    })

    # Provider returns 200, but with a different phone number than session
    supabase_auth_payload = {
        "access_token": "token-xyz",
        "refresh_token": "rt-xyz",
        "expires_in": 3600,
        "user": {
            "id": USER_ID,
            "phone": "+15559990000",  # Mismatched phone!
            "aud": "authenticated",
            "role": "authenticated",
        },
    }
    mock_resp = MagicMock(status_code=200, json=lambda: supabase_auth_payload)

    with patch("httpx.AsyncClient.post", new_callable=AsyncMock, return_value=mock_resp):
        resp = client.post(
            "/api/v1/auth/verify-otp",
            json={"session_id": "sess_mismatch", "otp_code": "123456", "phone_number": PHONE},
        )
        assert resp.status_code == 401
        assert resp.json()["detail"]["error"] == "PHONE_MISMATCH"
        # Session not consumed and profile not created
        assert len(fake_db.profiles) == 0


def test_verify_otp_success_yields_genuine_tokens_and_consumes_session(app, fake_db):
    client = TestClient(app)
    fake_db.otp_sessions.append({
        "session_id": "sess_success",
        "phone_number": PHONE,
        "expires_at": (datetime.now(timezone.utc) + timedelta(minutes=5)).isoformat(),
        "verified": False,
    })

    supabase_auth_payload = {
        "access_token": "genuine-supabase-access-token",
        "refresh_token": "genuine-supabase-refresh-token",
        "expires_in": 3600,
        "user": {
            "id": USER_ID,
            "phone": PHONE,
            "created_at": "2026-10-09T12:00:00Z",
            "aud": "authenticated",
            "role": "authenticated",
        },
    }
    mock_resp = MagicMock(status_code=200, json=lambda: supabase_auth_payload)

    with patch("httpx.AsyncClient.post", new_callable=AsyncMock, return_value=mock_resp) as mock_post:
        resp = client.post(
            "/api/v1/auth/verify-otp",
            json={"session_id": "sess_success", "otp_code": "654321", "phone_number": PHONE},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["access_token"] == "genuine-supabase-access-token"
        assert data["refresh_token"] == "genuine-supabase-refresh-token"
        assert data["user"]["id"] == USER_ID
        assert data["user"]["phone_number"] == PHONE

        # Verify Supabase verify call strictly used ANON_KEY
        mock_post.assert_called_once()
        assert mock_post.call_args[0][0] == f"{SUPABASE_URL}/auth/v1/verify"
        assert mock_post.call_args[1]["headers"]["apikey"] == ANON_KEY
        assert mock_post.call_args[1]["json"] == {
            "type": "sms",
            "phone": PHONE,
            "token": "654321",
        }

        # Verify session consumed immediately
        assert len(fake_db.otp_sessions) == 0

        # Verify profile record created
        assert len(fake_db.profiles) == 1
        assert fake_db.profiles[0]["id"] == USER_ID


def test_verify_otp_replay_and_concurrent_consumption_rejected(app, fake_db):
    client = TestClient(app)
    fake_db.otp_sessions.append({
        "session_id": "sess_replay",
        "phone_number": PHONE,
        "expires_at": (datetime.now(timezone.utc) + timedelta(minutes=5)).isoformat(),
        "verified": False,
    })

    supabase_auth_payload = {
        "access_token": "token-1",
        "refresh_token": "token-rt",
        "expires_in": 3600,
        "user": {"id": USER_ID, "phone": PHONE},
    }
    mock_resp = MagicMock(status_code=200, json=lambda: supabase_auth_payload)

    with patch("httpx.AsyncClient.post", new_callable=AsyncMock, return_value=mock_resp):
        # First verification succeeds and consumes session
        resp1 = client.post(
            "/api/v1/auth/verify-otp",
            json={"session_id": "sess_replay", "otp_code": "111222", "phone_number": PHONE},
        )
        assert resp1.status_code == 200

        # Second verification (replay) fails immediately with 404
        resp2 = client.post(
            "/api/v1/auth/verify-otp",
            json={"session_id": "sess_replay", "otp_code": "111222", "phone_number": PHONE},
        )
        assert resp2.status_code == 404
        assert resp2.json()["detail"]["error"] == "SESSION_NOT_FOUND"


def test_verify_otp_concurrent_race_atomic_rejection(app, fake_db):
    client = TestClient(app)
    # Session already marked verified by a concurrent request
    fake_db.otp_sessions.append({
        "session_id": "sess_concurrent",
        "phone_number": PHONE,
        "expires_at": (datetime.now(timezone.utc) + timedelta(minutes=5)).isoformat(),
        "verified": True,
    })

    resp = client.post(
        "/api/v1/auth/verify-otp",
        json={"session_id": "sess_concurrent", "otp_code": "111222", "phone_number": PHONE},
    )
    assert resp.status_code == 400
    assert resp.json()["detail"]["error"] == "SESSION_ALREADY_USED"


# ── 4. Refresh Token Tests ───────────────────────────────────────

def test_refresh_token_success(app):
    client = TestClient(app)
    mock_resp = MagicMock(
        status_code=200,
        json=lambda: {"access_token": "new-access", "refresh_token": "new-refresh", "expires_in": 3600},
    )
    with patch("httpx.AsyncClient.post", new_callable=AsyncMock, return_value=mock_resp) as mock_post:
        resp = client.post("/api/v1/auth/refresh-token", json={"refresh_token": "old-refresh"})
        assert resp.status_code == 200
        assert resp.json()["access_token"] == "new-access"
        assert resp.json()["refresh_token"] == "new-refresh"
        # Strict ANON_KEY check
        assert mock_post.call_args[1]["headers"]["apikey"] == ANON_KEY


def test_refresh_token_rejected_on_invalid_token(app):
    client = TestClient(app)
    mock_error = MagicMock(status_code=400, text="Invalid refresh token")
    with patch("httpx.AsyncClient.post", new_callable=AsyncMock, return_value=mock_error):
        resp = client.post("/api/v1/auth/refresh-token", json={"refresh_token": "bad-refresh"})
        assert resp.status_code == 401
        assert resp.json()["detail"]["error"] == "REFRESH_FAILED"


# ── 5. Bearer Token Verification (verify_jwt & get_current_user) ─

def test_verify_jwt_success_with_genuine_authenticated_claims():
    async def _test():
        mock_user_resp = MagicMock(
            status_code=200,
            json=lambda: {
                "id": USER_ID,
                "aud": "authenticated",
                "role": "authenticated",
                "phone": PHONE,
            },
        )
        with patch.object(settings, "SUPABASE_URL", SUPABASE_URL), \
             patch.object(settings, "SUPABASE_ANON_KEY", ANON_KEY), \
             patch("httpx.AsyncClient.get", new_callable=AsyncMock, return_value=mock_user_resp) as mock_get:
            creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials="valid.jwt.token")
            result = await verify_jwt(creds)
            assert result["user_id"] == USER_ID
            assert result["payload"]["role"] == "authenticated"

            # Verify outgoing check to /auth/v1/user uses ANON_KEY
            mock_get.assert_called_once()
            assert mock_get.call_args[0][0] == f"{SUPABASE_URL}/auth/v1/user"
            assert mock_get.call_args[1]["headers"]["apikey"] == ANON_KEY
            assert mock_get.call_args[1]["headers"]["Authorization"] == "Bearer valid.jwt.token"
    asyncio.run(_test())


def test_verify_jwt_rejects_unauthorized_token():
    async def _test():
        mock_user_resp = MagicMock(status_code=401, text="Invalid token signature")
        with patch.object(settings, "SUPABASE_URL", SUPABASE_URL), \
             patch.object(settings, "SUPABASE_ANON_KEY", ANON_KEY), \
             patch("httpx.AsyncClient.get", new_callable=AsyncMock, return_value=mock_user_resp):
            creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials="bad.jwt.token")
            with pytest.raises(HTTPException) as exc:
                await verify_jwt(creds)
            assert exc.value.status_code == 401
            assert exc.value.detail == "Invalid or expired authentication token"
    asyncio.run(_test())


def test_verify_jwt_rejects_service_role_or_unauthenticated_role():
    async def _test():
        # Token issued for service_role instead of authenticated user
        mock_user_resp = MagicMock(
            status_code=200,
            json=lambda: {
                "id": "service-role-id",
                "aud": "authenticated",
                "role": "service_role",
            },
        )
        with patch.object(settings, "SUPABASE_URL", SUPABASE_URL), \
             patch.object(settings, "SUPABASE_ANON_KEY", ANON_KEY), \
             patch("httpx.AsyncClient.get", new_callable=AsyncMock, return_value=mock_user_resp):
            creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials="service.role.token")
            with pytest.raises(HTTPException) as exc:
                await verify_jwt(creds)
            assert exc.value.status_code == 401
            assert exc.value.detail == "Invalid token: unauthorized role or audience"
    asyncio.run(_test())


def test_verify_jwt_fails_closed_on_provider_error():
    async def _test():
        mock_user_resp = MagicMock(status_code=500, text="Internal Server Error")
        with patch.object(settings, "SUPABASE_URL", SUPABASE_URL), \
             patch.object(settings, "SUPABASE_ANON_KEY", ANON_KEY), \
             patch("httpx.AsyncClient.get", new_callable=AsyncMock, return_value=mock_user_resp):
            creds = HTTPAuthorizationCredentials(scheme="Bearer", credentials="token")
            with pytest.raises(HTTPException) as exc:
                await verify_jwt(creds)
            assert exc.value.status_code == 502
            assert exc.value.detail == "Authentication provider returned an error"
    asyncio.run(_test())


def test_get_current_user_helper():
    token_data = {"user_id": USER_ID, "payload": {}}
    assert get_current_user(token_data) == USER_ID
