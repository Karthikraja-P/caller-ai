from twilio.rest import Client
from twilio.twiml.voice_response import VoiceResponse, Connect, Stream
from twilio.request_validator import RequestValidator
from app.core.config import settings

_twilio_client = None


def get_twilio_client() -> Client:
    global _twilio_client
    if _twilio_client is None:
        _twilio_client = Client(settings.TWILIO_ACCOUNT_SID, settings.TWILIO_AUTH_TOKEN)
    return _twilio_client


def validate_twilio_signature(url: str, params: dict, signature: str) -> bool:
    """Validate that a request came from Twilio (webhook security)."""
    validator = RequestValidator(settings.TWILIO_AUTH_TOKEN)
    return validator.validate(url, params, signature)


def send_otp_via_twilio(phone_number: str) -> str:
    """Send OTP via Twilio Verify. Returns verification SID."""
    client = get_twilio_client()
    verification = client.verify.v2.services(
        settings.TWILIO_VERIFY_SID
    ).verifications.create(to=phone_number, channel="sms")
    return verification.sid


def check_otp_via_twilio(phone_number: str, otp_code: str) -> bool:
    """Verify OTP code via Twilio Verify. Returns True if approved."""
    client = get_twilio_client()
    result = client.verify.v2.services(
        settings.TWILIO_VERIFY_SID
    ).verification_checks.create(to=phone_number, code=otp_code)
    return result.status == "approved"


def build_ai_call_twiml(websocket_url: str, agent_name: str) -> str:
    """Generate TwiML to connect incoming call to AI WebSocket stream."""
    response = VoiceResponse()
    response.say(f"Please hold. {agent_name} will be with you shortly.")
    connect = Connect()
    stream = Stream(url=websocket_url)
    stream.parameter(name="agent_name", value=agent_name)
    connect.append(stream)
    response.append(connect)
    return str(response)
