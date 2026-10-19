import asyncio
import hashlib
import importlib.util
import json
import sys
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
from unittest.mock import MagicMock

for _mod in ("supabase", "supabase.lib", "supabase.lib.client_options"):
    if _mod not in sys.modules:
        sys.modules[_mod] = MagicMock()
if "jose" not in sys.modules:
    sys.modules["jose"] = MagicMock()

from app.api.v1.endpoints import ai_agent


USER_ID = "00000000-0000-4000-8000-000000000123"
CALL_SID = "CA-test-123"


class Query:
    def __init__(self, db, table):
        self.db = db
        self.name = table
        self.filters = {}
        self.payload = None

    def select(self, *_):
        return self

    def eq(self, key, value):
        self.filters[key] = value
        return self

    def maybe_single(self):
        return self

    def single(self):
        return self

    def update(self, payload):
        self.payload = payload
        return self

    def insert(self, payload):
        self.payload = payload
        return self

    def upsert(self, payload, **_):
        self.payload = payload
        return self

    def execute(self):
        if self.payload is not None:
            self.db.writes.append((self.name, self.payload))
            if self.name == "ai_call_routes":
                self.db.route = self.payload
            return SimpleNamespace(data=self.payload)
        if self.name == "ai_routing_numbers":
            data = {"user_id": USER_ID} if self.filters.get("phone_number") == "+15551234567" else None
        elif self.name == "ai_agent_configs":
            data = {"agent_name": "Ada", "spam_handling_enabled": True, "busy_mode_enabled": False}
        elif self.name == "profiles":
            data = {"plan": "premium", "ai_calls_this_month": 0, "ai_calls_limit": 0}
        elif self.name == "ai_call_routes":
            data = self.db.route if self.filters.get("call_sid") == CALL_SID else None
        else:
            raise AssertionError(self.name)
        return SimpleNamespace(data=data)


class DB:
    def __init__(self):
        self.writes = []
        self.route = None

    def table(self, name):
        return Query(self, name)


class Request:
    url = "https://example.test/api/v1/ai/call/handle"
    headers = {"X-Twilio-Signature": "valid", "host": "example.test"}

    def __init__(self, to_number="+15551234567"):
        self.to_number = to_number

    async def form(self):
        return {"CallSid": CALL_SID, "From": "+15557654321", "To": self.to_number,
                "call_type": "spam"}


class WebSocket:
    def __init__(self, messages):
        self.messages = iter(messages)
        self.closed = None

    async def accept(self):
        pass

    async def receive_text(self):
        return json.dumps(next(self.messages))

    async def close(self, code):
        self.closed = code


def test_webhook_routes_only_provisioned_number(monkeypatch):
    db = DB()
    monkeypatch.setattr(ai_agent, "get_admin_db", lambda: db)
    monkeypatch.setattr(ai_agent, "validate_twilio_signature", lambda *_: True)

    response = asyncio.run(ai_agent.handle_ai_call(Request()))
    assert response.status_code == 200
    assert b"route_token" in response.body
    assert db.route["user_id"] == USER_ID
    assert db.route["caller_number"] == "+15557654321"
    assert db.route["route_token_hash"] not in response.body.decode()

    other = asyncio.run(ai_agent.handle_ai_call(Request("+15559999999")))
    assert b"<Reject/>" in other.body
    assert len([name for name, _ in db.writes if name == "ai_call_routes"]) == 1


def test_stream_persists_verified_owner_and_rejects_wrong_token(monkeypatch):
    db = DB()
    db.route = {
        "call_sid": CALL_SID, "user_id": USER_ID, "caller_number": "+15557654321",
        "call_type": "spam", "agent_name": "Ada",
        "route_token_hash": hashlib.sha256(b"secret-token").hexdigest(),
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    monkeypatch.setattr(ai_agent, "get_admin_db", lambda: db)
    start = lambda token: {"event": "start", "streamSid": "MZ-test", "start": {
        "callSid": CALL_SID, "customParameters": {"route_token": token}}}

    existing_session = {"existing": True}
    ai_agent.active_sessions[CALL_SID] = existing_session
    bad = WebSocket([start("wrong-token")])
    asyncio.run(ai_agent.ai_call_stream(bad, CALL_SID))
    assert bad.closed == 1008
    assert ai_agent.active_sessions[CALL_SID] is existing_session
    assert db.writes == []

    duplicate = WebSocket([start("secret-token")])
    asyncio.run(ai_agent.ai_call_stream(duplicate, CALL_SID))
    assert duplicate.closed == 1008
    assert ai_agent.active_sessions[CALL_SID] is existing_session
    ai_agent.active_sessions.pop(CALL_SID)

    good = WebSocket([start("secret-token"), {"event": "stop"}])
    asyncio.run(ai_agent.ai_call_stream(good, CALL_SID))
    assert good.closed is None
    assert CALL_SID not in ai_agent.active_sessions
    name, row = db.writes[-1]
    assert name == "ai_call_transcripts"
    assert row["user_id"] == USER_ID
    assert row["caller_number"] == "+15557654321"
    assert row["agent_name"] == "Ada"


def test_stream_rejects_expired_route_token(monkeypatch):
    db = DB()
    db.route = {
        "call_sid": CALL_SID,
        "route_token_hash": hashlib.sha256(b"secret-token").hexdigest(),
        "created_at": (datetime.now(timezone.utc) - timedelta(minutes=6)).isoformat(),
    }
    monkeypatch.setattr(ai_agent, "get_admin_db", lambda: db)
    ws = WebSocket([{"event": "start", "start": {
        "callSid": CALL_SID, "customParameters": {"route_token": "secret-token"}}}])
    asyncio.run(ai_agent.ai_call_stream(ws, CALL_SID))
    assert ws.closed == 1008
    assert CALL_SID not in ai_agent.active_sessions
    assert db.writes == []
