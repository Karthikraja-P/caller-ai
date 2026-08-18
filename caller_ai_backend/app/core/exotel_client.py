"""
Exotel Client (Phase 4 - Ultra-Low Cost Pivot)

This module is designed to replace twilio_client.py. Exotel charges in INR 
and is significantly cheaper for domestic Indian traffic, making the ₹9/month
subscription feasible.

Future Implementation:
- Map Exotel 'Passthru' or 'Gather' webhooks to our WebSocket stream.
- Handle Exotel signature validation (if supported).
- Send SMS via Exotel / Msg91 for fallback OTP.
"""

import logging

logger = logging.getLogger(__name__)

def build_exotel_ai_call_xml(ws_url: str, agent_name: str) -> str:
    """
    Builds the XML for Exotel to connect to our WebSocket.
    NOTE: Exotel streaming documentation must be followed here.
    Typically, they support `<Stream>` similar to Twilio, or Passthru audio.
    """
    logger.info(f"Building Exotel XML to connect {agent_name} to {ws_url}")
    # Example structure (pseudocode, check actual Exotel docs):
    xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Connect>
        <Stream url="{ws_url}" />
    </Connect>
</Response>
"""
    return xml

def send_otp_via_local_provider(phone_number: str):
    """
    Instead of Twilio Verify ($0.05 / ₹4.20), use Fast2SMS or Msg91 (~₹0.15).
    """
    logger.info(f"Sending low-cost OTP to {phone_number} via Msg91/Fast2SMS")
    # TODO: Implement HTTP POST to local SMS provider
    pass
