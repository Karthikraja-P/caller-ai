import importlib.util
import sys
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock, patch
import httpx
import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient

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

from app.api.v1.endpoints import voicemail
from app.core.config import settings
from app.core.security import get_current_user


USER_A = "11111111-1111-4111-8111-111111111111"
USER_B = "22222222-2222-4222-8222-222222222222"
ACCOUNT_SID = "AC" + ("0" * 32)
AUTH_TOKEN = "authtoken0123456789abcdef01234567"
CALL_SID = "CA0123456789abcdef0123456789abcdef"
RECORDING_SID = "RE0123456789abcdef0123456789abcdef"
CANONICAL_RECORDING_URL = f"https://api.twilio.com/2010-04-01/Accounts/{ACCOUNT_SID}/Recordings/{RECORDING_SID}"


class FakeQuery:
    def __init__(self, db, table_name: str):
        self.db = db
        self.table_name = table_name
        self.filters = {}
        self.select_cols = None
        self.order_by = None
        self.range_val = None
        self._upsert_data = None
        self._insert_data = None
        self._update_data = None
        self._delete_active = False

    def select(self, cols="*"):
        if cols and cols != "*":
            self.select_cols = [c.strip() for c in cols.split(",")]
        return self

    def eq(self, key, value):
        self.filters[key] = value
        return self

    def order(self, column, desc=False):
        self.order_by = (column, desc)
        return self

    def range(self, start, end):
        self.range_val = (start, end)
        return self

    def maybe_single(self):
        return self

    def single(self):
        return self

    def upsert(self, data, **_):
        self._upsert_data = data
        return self

    def insert(self, data):
        self._insert_data = data
        return self

    def update(self, data):
        self._update_data = data
        return self

    def delete(self):
        self._delete_active = True
        return self

    def _filter_cols(self, item):
        if not item or not self.select_cols:
            return item
        return {k: v for k, v in item.items() if k in self.select_cols}

    def execute(self):
        # Writes
        if self._upsert_data is not None:
            if self.table_name == "voicemails":
                rec_sid = self._upsert_data.get("recording_sid")
                existing = next((r for r in self.db.voicemails if r.get("recording_sid") == rec_sid), None)
                if existing:
                    existing.update(self._upsert_data)
                else:
                    item = {"id": f"vm-{len(self.db.voicemails)+1}", **self._upsert_data}
                    self.db.voicemails.append(item)
            elif self.table_name == "ai_call_routes":
                call_sid = self._upsert_data.get("call_sid")
                self.db.call_routes[call_sid] = self._upsert_data
            return SimpleNamespace(data=self._upsert_data)

        if self._update_data is not None:
            updated = []
            if self.table_name == "voicemails":
                for vm in self.db.voicemails:
                    match = True
                    for k, v in self.filters.items():
                        if str(vm.get(k)) != str(v):
                            match = False
                            break
                    if match:
                        vm.update(self._update_data)
                        updated.append(self._filter_cols(dict(vm)))
            return SimpleNamespace(data=updated)

        if self._delete_active:
            deleted = []
            if self.table_name == "voicemails":
                to_keep = []
                for vm in self.db.voicemails:
                    match = True
                    for k, v in self.filters.items():
                        if str(vm.get(k)) != str(v):
                            match = False
                            break
                    if match:
                        deleted.append(self._filter_cols(dict(vm)))
                    else:
                        to_keep.append(vm)
                self.db.voicemails = to_keep
            return SimpleNamespace(data=deleted)

        # Reads
        if self.table_name == "ai_routing_numbers":
            phone = self.filters.get("phone_number")
            active = self.filters.get("is_active", True)
            if phone == "+15551234567" and active:
                return SimpleNamespace(data={"user_id": USER_A})
            return SimpleNamespace(data=None)

        if self.table_name == "ai_agent_configs":
            return SimpleNamespace(data={"agent_name": "Assistant", "greeting_template": "Hello, please leave a message for {{agent_name}}."})

        if self.table_name == "ai_call_routes":
            call_sid = self.filters.get("call_sid")
            return SimpleNamespace(data=self.db.call_routes.get(call_sid))

        if self.table_name == "voicemails":
            results = []
            for vm in self.db.voicemails:
                match = True
                for k, v in self.filters.items():
                    if str(vm.get(k)) != str(v):
                        match = False
                        break
                if match:
                    results.append(self._filter_cols(dict(vm)))
            if self.range_val:
                s, e = self.range_val
                results = results[s : e + 1]
            if len(self.filters) > 0 and ("id" in self.filters or "recording_sid" in self.filters):
                data = results[0] if results else None
                return SimpleNamespace(data=data)
            return SimpleNamespace(data=results)

        raise NotImplementedError(f"Table {self.table_name} not mocked in FakeQuery")


class FakeDB:
    def __init__(self):
        self.call_routes = {}
        self.voicemails = []

    def table(self, name: str):
        return FakeQuery(self, name)


@pytest.fixture
def fake_db():
    db = FakeDB()
    # Route for USER_A
    db.call_routes[CALL_SID] = {
        "call_sid": CALL_SID,
        "user_id": USER_A,
        "caller_number": "+15559876543",
        "destination_number": "+15551234567",
    }
    # Route for USER_B
    call_sid_b = "CA99999999999999999999999999999999"
    db.call_routes[call_sid_b] = {
        "call_sid": call_sid_b,
        "user_id": USER_B,
        "caller_number": "+15551112233",
        "destination_number": "+15559998877",
    }
    # Existing voicemail owned by USER_A
    db.voicemails.append({
        "id": "vm-existing-1",
        "user_id": USER_A,
        "call_sid": CALL_SID,
        "recording_sid": RECORDING_SID,
        "recording_url": CANONICAL_RECORDING_URL,
        "caller_number": "+15559876543",
        "destination_number": "+15551234567",
        "duration_seconds": 15,
        "status": "completed",
        "transcription": None,
        "is_read": False,
        "created_at": "2026-10-09T12:00:00Z",
    })
    return db


@pytest.fixture
def app(fake_db):
    app = FastAPI()
    app.include_router(voicemail.router, prefix="/api/v1")
    with patch("app.api.v1.endpoints.voicemail.get_admin_db", return_value=fake_db), \
         patch.object(settings, "TWILIO_ACCOUNT_SID", ACCOUNT_SID), \
         patch.object(settings, "TWILIO_AUTH_TOKEN", AUTH_TOKEN), \
         patch.object(settings, "TWILIO_WEBHOOK_BASE_URL", "https://api.callerai.app"), \
         patch.object(settings, "PUBLIC_BASE_URL", "https://api.callerai.app"):
        yield app


# ── 1. Configuration Fail-Closed Tests ───────────────────────────

def test_handle_fails_closed_when_twilio_account_sid_missing(app):
    client = TestClient(app)
    with patch.object(settings, "TWILIO_ACCOUNT_SID", ""):
        resp = client.post("/api/v1/voicemail/handle", data={"CallSid": CALL_SID})
        assert resp.status_code == 503
        assert resp.json()["detail"] == "Telephony service configuration missing"


def test_handle_fails_closed_when_twilio_auth_token_missing(app):
    client = TestClient(app)
    with patch.object(settings, "TWILIO_AUTH_TOKEN", ""):
        resp = client.post("/api/v1/voicemail/handle", data={"CallSid": CALL_SID})
        assert resp.status_code == 503
        assert resp.json()["detail"] == "Telephony service configuration missing"


def test_action_fails_closed_when_twilio_account_sid_missing(app):
    client = TestClient(app)
    with patch.object(settings, "TWILIO_ACCOUNT_SID", ""):
        resp = client.post("/api/v1/voicemail/action", data={"CallSid": CALL_SID})
        assert resp.status_code == 503


def test_callback_fails_closed_when_twilio_account_sid_missing(app):
    client = TestClient(app)
    with patch.object(settings, "TWILIO_ACCOUNT_SID", ""):
        resp = client.post("/api/v1/voicemail/callback", data={"CallSid": CALL_SID})
        assert resp.status_code == 503


def test_playback_fails_closed_when_twilio_config_missing(app):
    app.dependency_overrides[get_current_user] = lambda: USER_A
    client = TestClient(app)
    with patch.object(settings, "TWILIO_ACCOUNT_SID", ""):
        resp = client.get("/api/v1/voicemail/messages/vm-existing-1/audio")
        assert resp.status_code == 503


def test_webhooks_fail_closed_when_base_url_missing(app):
    client = TestClient(app)
    with patch.object(settings, "TWILIO_WEBHOOK_BASE_URL", None), \
         patch.object(settings, "PUBLIC_BASE_URL", None):
        resp_h = client.post("/api/v1/voicemail/handle", data={"CallSid": CALL_SID})
        assert resp_h.status_code == 503
        assert resp_h.json()["detail"] == "Public HTTPS webhook base URL is not configured"

        resp_a = client.post("/api/v1/voicemail/action", data={"CallSid": CALL_SID})
        assert resp_a.status_code == 503
        assert resp_a.json()["detail"] == "Public HTTPS webhook base URL is not configured"

        resp_c = client.post("/api/v1/voicemail/callback", data={"CallSid": CALL_SID})
        assert resp_c.status_code == 503
        assert resp_c.json()["detail"] == "Public HTTPS webhook base URL is not configured"


def test_webhooks_fail_closed_when_base_url_not_https(app):
    client = TestClient(app)
    with patch.object(settings, "TWILIO_WEBHOOK_BASE_URL", "http://insecure.example.com"), \
         patch.object(settings, "PUBLIC_BASE_URL", None):
        resp_h = client.post("/api/v1/voicemail/handle", data={"CallSid": CALL_SID})
        assert resp_h.status_code == 503
        assert resp_h.json()["detail"] == "Public HTTPS webhook base URL is not configured"


def test_webhooks_validate_signature_against_canonical_url_ignoring_host_and_scheme(app):
    client = TestClient(app)
    with patch("app.api.v1.endpoints.voicemail.validate_twilio_signature", return_value=True) as mock_val:
        resp = client.post(
            "/api/v1/voicemail/handle?fake_query=1",
            headers={"Host": "attacker.fakehost.com:9999", "X-Forwarded-Proto": "http"},
            data={
                "AccountSid": ACCOUNT_SID,
                "CallSid": CALL_SID,
                "From": "+15559876543",
                "To": "+15551234567",
            },
        )
        assert resp.status_code == 200
        assert mock_val.called
        call_url, call_params, _ = mock_val.call_args[0]
        assert call_url == "https://api.callerai.app/api/v1/voicemail/handle"
        assert "attacker.fakehost.com" not in call_url
        assert call_params["CallSid"] == CALL_SID
        assert call_params["AccountSid"] == ACCOUNT_SID
        # Verify action and callback URLs in generated TwiML use canonical base URL
        assert 'action="https://api.callerai.app/api/v1/voicemail/action"' in resp.text
        assert 'recordingStatusCallback="https://api.callerai.app/api/v1/voicemail/callback"' in resp.text


def test_action_and_callback_validate_signatures_against_canonical_urls(app):
    client = TestClient(app)
    with patch("app.api.v1.endpoints.voicemail.validate_twilio_signature", return_value=True) as mock_val:
        client.post(
            "/api/v1/voicemail/action",
            headers={"Host": "forged.host.org"},
            data={"AccountSid": ACCOUNT_SID, "CallSid": CALL_SID},
        )
        call_url, call_params, _ = mock_val.call_args[0]
        assert call_url == "https://api.callerai.app/api/v1/voicemail/action"

        client.post(
            "/api/v1/voicemail/callback",
            headers={"Host": "forged.host.org"},
            data={"AccountSid": ACCOUNT_SID, "CallSid": CALL_SID, "RecordingStatus": "in-progress"},
        )
        call_url, call_params, _ = mock_val.call_args[0]
        assert call_url == "https://api.callerai.app/api/v1/voicemail/callback"


# ── 2. Signature & AccountSid Rejection Tests ────────────────────

def test_handle_call_rejects_invalid_signature(app):
    client = TestClient(app)
    with patch("app.api.v1.endpoints.voicemail.validate_twilio_signature", return_value=False):
        resp = client.post(
            "/api/v1/voicemail/handle",
            data={"AccountSid": ACCOUNT_SID, "CallSid": CALL_SID},
        )
        assert resp.status_code == 403
        assert resp.json()["detail"] == "Invalid Twilio signature"


def test_handle_call_rejects_missing_or_mismatched_account_sid(app):
    client = TestClient(app)
    with patch("app.api.v1.endpoints.voicemail.validate_twilio_signature", return_value=True):
        # Missing AccountSid
        resp1 = client.post("/api/v1/voicemail/handle", data={"CallSid": CALL_SID})
        assert resp1.status_code == 403
        assert resp1.json()["detail"] == "AccountSid mismatch or missing"

        # Mismatched AccountSid
        resp2 = client.post(
            "/api/v1/voicemail/handle",
            data={"AccountSid": "AC_WRONG_ACCOUNT_SID", "CallSid": CALL_SID},
        )
        assert resp2.status_code == 403
        assert resp2.json()["detail"] == "AccountSid mismatch or missing"


def test_action_rejects_invalid_signature_or_account_sid(app):
    client = TestClient(app)
    with patch("app.api.v1.endpoints.voicemail.validate_twilio_signature", return_value=False):
        resp1 = client.post(
            "/api/v1/voicemail/action",
            data={"AccountSid": ACCOUNT_SID, "CallSid": CALL_SID},
        )
        assert resp1.status_code == 403

    with patch("app.api.v1.endpoints.voicemail.validate_twilio_signature", return_value=True):
        resp2 = client.post(
            "/api/v1/voicemail/action",
            data={"AccountSid": "AC_WRONG", "CallSid": CALL_SID},
        )
        assert resp2.status_code == 403


def test_callback_rejects_invalid_signature_or_account_sid(app):
    client = TestClient(app)
    with patch("app.api.v1.endpoints.voicemail.validate_twilio_signature", return_value=False):
        resp1 = client.post(
            "/api/v1/voicemail/callback",
            data={
                "AccountSid": ACCOUNT_SID,
                "CallSid": CALL_SID,
                "RecordingSid": RECORDING_SID,
                "RecordingStatus": "completed",
            },
        )
        assert resp1.status_code == 403

    with patch("app.api.v1.endpoints.voicemail.validate_twilio_signature", return_value=True):
        resp2 = client.post(
            "/api/v1/voicemail/callback",
            data={
                "AccountSid": "AC_WRONG_ACCOUNT",
                "CallSid": CALL_SID,
                "RecordingSid": RECORDING_SID,
                "RecordingStatus": "completed",
            },
        )
        assert resp2.status_code == 403


# ── 3. CallSid and RecordingSid Shape Validation Tests ───────────

def test_handle_call_malformed_call_sid_returns_reject(app):
    client = TestClient(app)
    with patch("app.api.v1.endpoints.voicemail.validate_twilio_signature", return_value=True):
        # Malformed CallSid (missing CA prefix / traversal attempt)
        resp = client.post(
            "/api/v1/voicemail/handle",
            data={
                "AccountSid": ACCOUNT_SID,
                "CallSid": "../evil_call_sid",
                "To": "+15551234567",
                "From": "+15559876543",
            },
        )
        assert resp.status_code == 200
        assert "<Reject/>" in resp.text


def test_action_malformed_call_sid_returns_400(app):
    client = TestClient(app)
    with patch("app.api.v1.endpoints.voicemail.validate_twilio_signature", return_value=True):
        resp = client.post(
            "/api/v1/voicemail/action",
            data={"AccountSid": ACCOUNT_SID, "CallSid": "INVALID_SID"},
        )
        assert resp.status_code == 400
        assert resp.json()["detail"] == "Invalid CallSid format"


def test_callback_rejects_malformed_sids(app, fake_db):
    client = TestClient(app)
    initial_count = len(fake_db.voicemails)

    with patch("app.api.v1.endpoints.voicemail.validate_twilio_signature", return_value=True):
        # Malformed CallSid
        resp1 = client.post(
            "/api/v1/voicemail/callback",
            data={
                "AccountSid": ACCOUNT_SID,
                "CallSid": "malformed_call_sid",
                "RecordingSid": RECORDING_SID,
                "RecordingStatus": "completed",
            },
        )
        assert resp1.status_code == 400
        assert resp1.json()["detail"] == "Invalid CallSid or RecordingSid format"

        # Malformed RecordingSid (e.g. traversal attempt)
        resp2 = client.post(
            "/api/v1/voicemail/callback",
            data={
                "AccountSid": ACCOUNT_SID,
                "CallSid": CALL_SID,
                "RecordingSid": "RE../../traversal",
                "RecordingStatus": "completed",
            },
        )
        assert resp2.status_code == 400
        assert resp2.json()["detail"] == "Invalid CallSid or RecordingSid format"

        assert len(fake_db.voicemails) == initial_count


# ── 4. Account Routing, TwiML & Absent Recording ─────────────────

def test_handle_call_unassigned_number_rejects(app):
    client = TestClient(app)
    with patch("app.api.v1.endpoints.voicemail.validate_twilio_signature", return_value=True):
        resp = client.post(
            "/api/v1/voicemail/handle",
            data={
                "AccountSid": ACCOUNT_SID,
                "CallSid": CALL_SID,
                "To": "+15550000000",
                "From": "+15559876543",
            },
        )
        assert resp.status_code == 200
        assert "<Reject/>" in resp.text


def test_handle_call_returns_twiml_with_greeting_record_hangup(app):
    client = TestClient(app)
    with patch("app.api.v1.endpoints.voicemail.validate_twilio_signature", return_value=True):
        resp = client.post(
            "/api/v1/voicemail/handle",
            data={
                "AccountSid": ACCOUNT_SID,
                "CallSid": CALL_SID,
                "To": "+15551234567",
                "From": "+15559876543",
            },
        )
        assert resp.status_code == 200
        xml = resp.text
        assert "<Response>" in xml
        assert "<Say>Hello, please leave a message for Assistant.</Say>" in xml
        assert "<Record" in xml
        assert 'maxLength="120"' in xml
        assert '/api/v1/voicemail/action' in xml
        assert '/api/v1/voicemail/callback' in xml
        assert "<Hangup" in xml


def test_action_webhook_returns_hangup_twiml(app):
    client = TestClient(app)
    with patch("app.api.v1.endpoints.voicemail.validate_twilio_signature", return_value=True):
        resp = client.post(
            "/api/v1/voicemail/action",
            data={"AccountSid": ACCOUNT_SID, "CallSid": CALL_SID},
        )
        assert resp.status_code == 200
        xml = resp.text
        assert "<Response>" in xml
        assert "<Say>Thank you. Your message has been saved.</Say>" in xml
        assert "<Hangup/>" in xml


def test_callback_recording_absent_or_not_completed_ignored(app, fake_db):
    client = TestClient(app)
    initial_count = len(fake_db.voicemails)
    with patch("app.api.v1.endpoints.voicemail.validate_twilio_signature", return_value=True):
        resp = client.post(
            "/api/v1/voicemail/callback",
            data={
                "AccountSid": ACCOUNT_SID,
                "CallSid": CALL_SID,
                "RecordingSid": "RE00000000000000000000000000absent",
                "RecordingStatus": "absent",
            },
        )
        assert resp.status_code == 200
        assert resp.json()["status"] == "ignored"
        assert resp.json()["recording_status"] == "absent"
        assert len(fake_db.voicemails) == initial_count


def test_callback_unknown_call_sid_returns_404(app):
    client = TestClient(app)
    with patch("app.api.v1.endpoints.voicemail.validate_twilio_signature", return_value=True):
        resp = client.post(
            "/api/v1/voicemail/callback",
            data={
                "AccountSid": ACCOUNT_SID,
                "CallSid": "CA000000000000000000000nonexistent",
                "RecordingSid": "RE00000000000000000000000000000001",
                "RecordingStatus": "completed",
                "RecordingDuration": "20",
            },
        )
        assert resp.status_code == 404
        assert resp.json()["detail"] == "Matching call route not found"


# ── 5. Duplicate Callback Idempotency & Reassignment Defense ─────

def test_duplicate_callback_is_idempotent(app, fake_db):
    client = TestClient(app)
    initial_count = len(fake_db.voicemails)
    new_rec_sid = "RE0000000000000000000000idempotent"

    with patch("app.api.v1.endpoints.voicemail.validate_twilio_signature", return_value=True):
        payload = {
            "AccountSid": ACCOUNT_SID,
            "CallSid": CALL_SID,
            "RecordingSid": new_rec_sid,
            "RecordingStatus": "completed",
            "RecordingDuration": "32",
        }
        # First delivery
        resp1 = client.post("/api/v1/voicemail/callback", data=payload)
        assert resp1.status_code == 200
        assert resp1.json()["status"] == "saved"
        assert len(fake_db.voicemails) == initial_count + 1

        # Second delivery (duplicate)
        resp2 = client.post("/api/v1/voicemail/callback", data=payload)
        assert resp2.status_code == 200
        assert resp2.json()["status"] == "saved"
        assert len(fake_db.voicemails) == initial_count + 1


def test_duplicate_callback_cannot_reassign_recording_to_another_user(app, fake_db):
    client = TestClient(app)
    # Existing recording RECORDING_SID belongs to USER_A on CALL_SID.
    # Attacker attempts to forge a callback with same RECORDING_SID bound to call_sid_b (USER_B).
    call_sid_b = "CA99999999999999999999999999999999"

    with patch("app.api.v1.endpoints.voicemail.validate_twilio_signature", return_value=True):
        resp = client.post(
            "/api/v1/voicemail/callback",
            data={
                "AccountSid": ACCOUNT_SID,
                "CallSid": call_sid_b,
                "RecordingSid": RECORDING_SID,
                "RecordingStatus": "completed",
                "RecordingDuration": "10",
            },
        )
        assert resp.status_code == 409
        assert resp.json()["detail"] == "RecordingSid already bound to another call or user"

        # Verify existing record is still owned by USER_A
        existing_vm = next(r for r in fake_db.voicemails if r["recording_sid"] == RECORDING_SID)
        assert existing_vm["user_id"] == USER_A


# ── 6. SSRF & Forged RecordingUrl Immunity ───────────────────────

def test_callback_ignores_forged_recording_url_and_persists_canonical_url(app, fake_db):
    client = TestClient(app)
    new_rec_sid = "RE00000000000000000000000000000099"

    with patch("app.api.v1.endpoints.voicemail.validate_twilio_signature", return_value=True):
        resp = client.post(
            "/api/v1/voicemail/callback",
            data={
                "AccountSid": ACCOUNT_SID,
                "CallSid": CALL_SID,
                "RecordingSid": new_rec_sid,
                "RecordingStatus": "completed",
                "RecordingDuration": "12",
                "RecordingUrl": "http://attacker.example.com/exfiltrate-creds",
            },
        )
        assert resp.status_code == 200
        assert resp.json()["status"] == "saved"

        # Verify saved record does NOT contain attacker URL; contains canonical Twilio URL
        saved = next(r for r in fake_db.voicemails if r["recording_sid"] == new_rec_sid)
        assert "attacker.example.com" not in saved["recording_url"]
        assert saved["recording_url"] == f"https://api.twilio.com/2010-04-01/Accounts/{ACCOUNT_SID}/Recordings/{new_rec_sid}"


# ── 7. Playback Proxy Hardening (Redirects, Size Cap, Non-Audio) ─

class MockStreamResponse:
    def __init__(self, status_code=200, headers=None, chunks=None):
        self.status_code = status_code
        self.headers = headers or {"content-type": "audio/mpeg"}
        self._chunks = chunks or [b"\xff\xfb\x90\x44" + b"\x00" * 100]

    async def __aenter__(self):
        return self

    async def __aexit__(self, *args):
        pass

    async def aiter_bytes(self):
        for c in self._chunks:
            yield c


class MockStreamClient:
    def __init__(self, stream_response, recorded_calls=None):
        self.stream_response = stream_response
        self.recorded_calls = recorded_calls if recorded_calls is not None else []

    async def __aenter__(self):
        return self

    async def __aexit__(self, *args):
        pass

    def stream(self, method, url, **kwargs):
        self.recorded_calls.append((method, url, kwargs))
        return self.stream_response


def test_authorized_playback_proxies_audio_without_exposing_creds(app):
    app.dependency_overrides[get_current_user] = lambda: USER_A
    client = TestClient(app)

    audio_data = b"\xff\xfb\x90\x44" + b"\x00" * 200
    mock_resp = MockStreamResponse(status_code=200, headers={"content-type": "audio/mpeg"}, chunks=[audio_data])
    recorded_calls = []

    with patch("httpx.AsyncClient", return_value=MockStreamClient(mock_resp, recorded_calls)):
        resp = client.get("/api/v1/voicemail/messages/vm-existing-1/audio")
        assert resp.status_code == 200
        assert resp.content == audio_data
        assert resp.headers["content-type"] == "audio/mpeg"

        # Verify proxy targeted canonical URL with Basic Auth
        assert len(recorded_calls) == 1
        method, url, kwargs = recorded_calls[0]
        assert method == "GET"
        assert url == f"{CANONICAL_RECORDING_URL}.mp3"
        assert kwargs["auth"] == (ACCOUNT_SID, AUTH_TOKEN)


def test_audio_proxy_never_contacts_forged_url_even_if_db_row_tampered(app, fake_db):
    app.dependency_overrides[get_current_user] = lambda: USER_A
    client = TestClient(app)

    # Tamper with the stored recording_url in the DB row to point to an attacker host
    tampered_vm = next(r for r in fake_db.voicemails if r["id"] == "vm-existing-1")
    tampered_vm["recording_url"] = "http://malicious-server.example.org/steal-auth"

    mock_resp = MockStreamResponse(status_code=200, headers={"content-type": "audio/mpeg"})
    recorded_calls = []

    with patch("httpx.AsyncClient", return_value=MockStreamClient(mock_resp, recorded_calls)):
        resp = client.get("/api/v1/voicemail/messages/vm-existing-1/audio")
        assert resp.status_code == 200

        # Verify outgoing HTTP call went ONLY to canonical api.twilio.com, NEVER to malicious-server
        assert len(recorded_calls) == 1
        _, url, kwargs = recorded_calls[0]
        assert "malicious-server.example.org" not in url
        assert url.startswith("https://api.twilio.com/")
        assert kwargs["auth"] == (ACCOUNT_SID, AUTH_TOKEN)


def test_audio_proxy_rejects_redirect_attempts(app):
    app.dependency_overrides[get_current_user] = lambda: USER_A
    client = TestClient(app)

    # Telephony endpoint attempts 302 redirect
    redirect_resp = MockStreamResponse(status_code=302, headers={"location": "http://evil.com/leak"})
    with patch("httpx.AsyncClient", return_value=MockStreamClient(redirect_resp)):
        resp = client.get("/api/v1/voicemail/messages/vm-existing-1/audio")
        assert resp.status_code == 502
        assert resp.json()["detail"] == "Failed to retrieve recording from telephony provider"


def test_audio_proxy_rejects_non_audio_content(app):
    app.dependency_overrides[get_current_user] = lambda: USER_A
    client = TestClient(app)

    # Telephony provider returns text/html or application/json
    html_resp = MockStreamResponse(status_code=200, headers={"content-type": "text/html"}, chunks=[b"<html>Error</html>"])
    with patch("httpx.AsyncClient", return_value=MockStreamClient(html_resp)):
        resp = client.get("/api/v1/voicemail/messages/vm-existing-1/audio")
        assert resp.status_code == 502
        assert resp.json()["detail"] == "Telephony provider returned non-audio content"


def test_audio_proxy_caps_oversized_audio_stream(app):
    app.dependency_overrides[get_current_user] = lambda: USER_A
    client = TestClient(app)

    # 11 MB audio payload exceeding 10 MB MAX_AUDIO_BYTES
    large_chunks = [b"A" * (1024 * 1024) for _ in range(11)]
    oversized_resp = MockStreamResponse(
        status_code=200,
        headers={"content-type": "audio/mpeg", "content-length": str(11 * 1024 * 1024)},
        chunks=large_chunks,
    )
    with patch("httpx.AsyncClient", return_value=MockStreamClient(oversized_resp)):
        resp = client.get("/api/v1/voicemail/messages/vm-existing-1/audio")
        assert resp.status_code == 502
        assert resp.json()["detail"] == "Audio recording exceeds maximum allowed size"


# ── 8. Messages API Account Isolation (List, Detail, Audio, Delete) ──

def test_messages_list_and_detail_account_isolation(app, fake_db):
    app.dependency_overrides[get_current_user] = lambda: USER_A
    client = TestClient(app)

    # USER_A lists their messages
    resp = client.get("/api/v1/voicemail/messages")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["messages"]) == 1
    msg = data["messages"][0]
    assert msg["id"] == "vm-existing-1"
    assert "recording_url" not in msg
    assert "auth" not in msg

    # USER_A gets their message detail
    detail = client.get("/api/v1/voicemail/messages/vm-existing-1")
    assert detail.status_code == 200
    assert "recording_url" not in detail.json()

    # Switch user to USER_B
    app.dependency_overrides[get_current_user] = lambda: USER_B
    client_b = TestClient(app)

    # USER_B listing sees 0 messages
    resp_b = client_b.get("/api/v1/voicemail/messages")
    assert resp_b.status_code == 200
    assert len(resp_b.json()["messages"]) == 0

    # USER_B accessing USER_A's message receives 404
    detail_b = client_b.get("/api/v1/voicemail/messages/vm-existing-1")
    assert detail_b.status_code == 404


def test_unauthorized_playback_rejected(app):
    app.dependency_overrides[get_current_user] = lambda: USER_B
    client = TestClient(app)

    resp = client.get("/api/v1/voicemail/messages/vm-existing-1/audio")
    assert resp.status_code == 404
    assert resp.json()["detail"] == "Voicemail recording not found"


def test_message_read_and_delete_account_isolation(app, fake_db):
    # USER_B cannot mark read or delete USER_A's voicemail
    app.dependency_overrides[get_current_user] = lambda: USER_B
    client_b = TestClient(app)

    resp_patch_b = client_b.patch("/api/v1/voicemail/messages/vm-existing-1/read", json={"is_read": True})
    assert resp_patch_b.status_code == 404

    resp_del_b = client_b.delete("/api/v1/voicemail/messages/vm-existing-1")
    assert resp_del_b.status_code == 404

    # USER_A can mark read and delete
    app.dependency_overrides[get_current_user] = lambda: USER_A
    client_a = TestClient(app)

    resp_patch_a = client_a.patch("/api/v1/voicemail/messages/vm-existing-1/read", json={"is_read": True})
    assert resp_patch_a.status_code == 200
    assert resp_patch_a.json()["is_read"] is True

    mock_resp = SimpleNamespace(status_code=204)
    with patch("httpx.AsyncClient.delete", new_callable=AsyncMock, return_value=mock_resp):
        resp_del_a = client_a.delete("/api/v1/voicemail/messages/vm-existing-1")
        assert resp_del_a.status_code == 200
        assert resp_del_a.json()["deleted"] is True

    # After deletion, detail returns 404
    assert client_a.get("/api/v1/voicemail/messages/vm-existing-1").status_code == 404


# ── 9. Owner Delete Twilio Media and Local Metadata Tests ────────

def test_delete_voicemail_calls_twilio_and_removes_metadata(app, fake_db):
    app.dependency_overrides[get_current_user] = lambda: USER_A
    client = TestClient(app)

    mock_resp = SimpleNamespace(status_code=204)
    with patch("httpx.AsyncClient.delete", new_callable=AsyncMock, return_value=mock_resp) as mock_delete:
        resp = client.delete("/api/v1/voicemail/messages/vm-existing-1")
        assert resp.status_code == 200
        assert resp.json() == {"deleted": True, "id": "vm-existing-1"}

        # Verify Twilio DELETE call details
        assert mock_delete.called
        del_url = mock_delete.call_args[0][0]
        assert del_url == f"https://api.twilio.com/2010-04-01/Accounts/{ACCOUNT_SID}/Recordings/{RECORDING_SID}.json"
        assert mock_delete.call_args[1]["auth"] == (ACCOUNT_SID, AUTH_TOKEN)

        # Verify local DB row was removed
        assert not any(vm["id"] == "vm-existing-1" for vm in fake_db.voicemails)


def test_delete_voicemail_404_from_twilio_still_removes_metadata(app, fake_db):
    app.dependency_overrides[get_current_user] = lambda: USER_A
    client = TestClient(app)

    # If media was already deleted on Twilio, 404 allows metadata cleanup
    mock_resp = SimpleNamespace(status_code=404)
    with patch("httpx.AsyncClient.delete", new_callable=AsyncMock, return_value=mock_resp):
        resp = client.delete("/api/v1/voicemail/messages/vm-existing-1")
        assert resp.status_code == 200
        assert resp.json() == {"deleted": True, "id": "vm-existing-1"}
        assert not any(vm["id"] == "vm-existing-1" for vm in fake_db.voicemails)


def test_delete_voicemail_provider_failure_keeps_metadata(app, fake_db):
    app.dependency_overrides[get_current_user] = lambda: USER_A
    client = TestClient(app)

    # Provider 500 error
    mock_resp = SimpleNamespace(status_code=500)
    with patch("httpx.AsyncClient.delete", new_callable=AsyncMock, return_value=mock_resp):
        resp = client.delete("/api/v1/voicemail/messages/vm-existing-1")
        assert resp.status_code == 502
        assert resp.json()["detail"] == "Failed to delete recording media from telephony provider"

        # Verify local metadata is kept intact
        assert any(vm["id"] == "vm-existing-1" for vm in fake_db.voicemails)


def test_delete_voicemail_network_error_keeps_metadata(app, fake_db):
    app.dependency_overrides[get_current_user] = lambda: USER_A
    client = TestClient(app)

    # Provider network error
    with patch("httpx.AsyncClient.delete", new_callable=AsyncMock, side_effect=httpx.RequestError("Connection timeout")):
        resp = client.delete("/api/v1/voicemail/messages/vm-existing-1")
        assert resp.status_code == 502
        assert resp.json()["detail"] == "Error connecting to telephony provider during recording deletion"

        # Verify local metadata is kept intact
        assert any(vm["id"] == "vm-existing-1" for vm in fake_db.voicemails)


def test_delete_voicemail_fails_closed_when_twilio_unconfigured(app, fake_db):
    app.dependency_overrides[get_current_user] = lambda: USER_A
    client = TestClient(app)

    with patch.object(settings, "TWILIO_ACCOUNT_SID", ""):
        resp = client.delete("/api/v1/voicemail/messages/vm-existing-1")
        assert resp.status_code == 503
        assert resp.json()["detail"] == "Telephony service configuration missing"

        # Verify local metadata is kept intact
        assert any(vm["id"] == "vm-existing-1" for vm in fake_db.voicemails)


# ── 10. Legacy AI Agent Router Unmounted ─────────────────────────

def test_legacy_ai_agent_routes_unmounted():
    from app.api.v1.api import api_router
    test_app = FastAPI()
    test_app.include_router(api_router)
    client = TestClient(test_app)

    # Ensure /api/v1/ai routes return 404
    resp = client.get("/api/v1/ai/config")
    assert resp.status_code == 404

    resp2 = client.post("/api/v1/ai/handle-call")
    assert resp2.status_code == 404
