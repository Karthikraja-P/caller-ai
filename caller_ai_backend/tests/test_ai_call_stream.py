import asyncio
import base64
import hashlib
import importlib.util
import json
import sys
from datetime import datetime, timezone
from unittest.mock import AsyncMock, MagicMock, patch

for _mod in ("supabase", "supabase.lib", "supabase.lib.client_options"):
    if _mod not in sys.modules:
        sys.modules[_mod] = MagicMock()

from app.api.v1.endpoints import ai_agent


class MockWebSocket:
    def __init__(self, incoming_messages):
        self.incoming = iter(incoming_messages)
        self.sent_json = []
        self.closed_code = None

    async def accept(self):
        pass

    async def receive_text(self):
        try:
            msg = next(self.incoming)
            return json.dumps(msg)
        except StopIteration:
            raise asyncio.CancelledError()

    async def send_json(self, payload):
        self.sent_json.append(payload)

    async def close(self, code):
        self.closed_code = code


def _setup_valid_session(call_sid: str = "CA-stream-test"):
    token = "test-stream-token"
    token_hash = hashlib.sha256(token.encode()).hexdigest()
    route = {
        "call_sid": call_sid,
        "user_id": "00000000-0000-4000-8000-000000000123",
        "caller_number": "+15557654321",
        "destination_number": "+15551234567",
        "call_type": "spam",
        "agent_name": "Assistant",
        "route_token_hash": token_hash,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }

    class MockQuery:
        def __init__(self, table_name):
            self.table_name = table_name

        def select(self, *_):
            return self

        def eq(self, *_):
            return self

        def maybe_single(self):
            return self

        def insert(self, payload):
            return self

        def execute(self):
            return type("Res", (), {"data": route})()

    class MockDB:
        def table(self, name):
            return MockQuery(name)

    return MockDB(), token, call_sid


def test_ai_call_stream_rejects_malformed_media_payload(monkeypatch):
    """Verify malformed base64 or missing payload closes websocket with 1008."""
    mock_db, token, call_sid = _setup_valid_session()
    monkeypatch.setattr(ai_agent, "get_admin_db", lambda: mock_db)

    start_msg = {
        "event": "start",
        "streamSid": "MZ123",
        "start": {"callSid": call_sid, "customParameters": {"route_token": token}},
    }
    malformed_media_msg = {
        "event": "media",
        "media": {"payload": "NOT_VALID_BASE64!!!"},
    }

    ws = MockWebSocket([start_msg, malformed_media_msg])
    asyncio.run(ai_agent.ai_call_stream(ws, call_sid))
    assert ws.closed_code == 1008


def test_ai_call_stream_provider_error_terminates_controlled(monkeypatch):
    """Verify provider error during transcription/TTS terminates call with code 1011."""
    mock_db, token, call_sid = _setup_valid_session()
    monkeypatch.setattr(ai_agent, "get_admin_db", lambda: mock_db)

    start_msg = {
        "event": "start",
        "streamSid": "MZ123",
        "start": {"callSid": call_sid, "customParameters": {"route_token": token}},
    }
    # 16000 bytes of mu-law triggers chunk processing
    chunk_b64 = base64.b64encode(b"\xff" * 16000).decode()
    media_msg = {
        "event": "media",
        "media": {"payload": chunk_b64},
    }

    # Simulate provider failure in transcription
    monkeypatch.setattr(
        ai_agent,
        "transcribe_audio",
        AsyncMock(side_effect=RuntimeError("Whisper provider timeout")),
    )

    ws = MockWebSocket([start_msg, media_msg])
    asyncio.run(ai_agent.ai_call_stream(ws, call_sid))
    assert ws.closed_code == 1011


def test_ai_call_stream_processes_mulaw_and_sends_raw_mulaw(monkeypatch):
    """Verify inbound mu-law is transcribed and outbound speech is sent as raw 8-kHz mu-law."""
    mock_db, token, call_sid = _setup_valid_session()
    monkeypatch.setattr(ai_agent, "get_admin_db", lambda: mock_db)

    start_msg = {
        "event": "start",
        "streamSid": "MZ123",
        "start": {"callSid": call_sid, "customParameters": {"route_token": token}},
    }
    raw_inbound_mulaw = b"\xff\x00\x55\xaa" * 4000  # 16000 bytes
    chunk_b64 = base64.b64encode(raw_inbound_mulaw).decode()
    media_msg = {
        "event": "media",
        "media": {"payload": chunk_b64},
    }
    stop_msg = {"event": "stop"}

    captured_transcribe_audio = []

    async def mock_transcribe(audio_bytes, language="en"):
        captured_transcribe_audio.append(audio_bytes)
        return "Hello caller"

    raw_outbound_mulaw = b"\x7f\x80" * 800  # 1600 bytes headerless mu-law
    mock_synthesize_mulaw = AsyncMock(return_value=raw_outbound_mulaw)

    monkeypatch.setattr(ai_agent, "transcribe_audio", mock_transcribe)
    monkeypatch.setattr(ai_agent, "synthesize_speech_mulaw", mock_synthesize_mulaw)

    ws = MockWebSocket([start_msg, media_msg, stop_msg])
    asyncio.run(ai_agent.ai_call_stream(ws, call_sid))

    assert ws.closed_code is None
    assert len(captured_transcribe_audio) == 1
    # Check that transcribe received the raw mu-law buffer
    assert captured_transcribe_audio[0] == raw_inbound_mulaw

    # Verify outbound media response was sent with streamSid
    assert len(ws.sent_json) == 1
    outbound_event = ws.sent_json[0]
    assert outbound_event["event"] == "media"
    assert outbound_event["streamSid"] == "MZ123"
    sent_audio = base64.b64decode(outbound_event["media"]["payload"])
    assert sent_audio == raw_outbound_mulaw
    assert not sent_audio.startswith(b"RIFF")
