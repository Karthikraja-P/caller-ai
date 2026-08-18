import httpx
from app.core.config import settings

WHATSAPP_API_BASE = "https://graph.facebook.com/v18.0"


async def send_whatsapp_message(to_number: str, message_text: str) -> dict:
    """
    Send a WhatsApp text message via Meta Business API.
    to_number: E.164 format e.g. +919876543210
    """
    url = f"{WHATSAPP_API_BASE}/{settings.WHATSAPP_PHONE_NUMBER_ID}/messages"
    headers = {
        "Authorization": f"Bearer {settings.WHATSAPP_ACCESS_TOKEN}",
        "Content-Type": "application/json",
    }
    payload = {
        "messaging_product": "whatsapp",
        "recipient_type": "individual",
        "to": to_number,
        "type": "text",
        "text": {"preview_url": False, "body": message_text},
    }
    async with httpx.AsyncClient(timeout=15.0) as client:
        resp = await client.post(url, json=payload, headers=headers)
        resp.raise_for_status()
        return resp.json()


async def get_whatsapp_connection_status() -> dict:
    """Check if WhatsApp Business API is reachable and number is registered."""
    url = f"{WHATSAPP_API_BASE}/{settings.WHATSAPP_PHONE_NUMBER_ID}"
    headers = {"Authorization": f"Bearer {settings.WHATSAPP_ACCESS_TOKEN}"}
    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.get(url, headers=headers)
        if resp.status_code == 200:
            data = resp.json()
            return {
                "connected": True,
                "phone_number": data.get("display_phone_number"),
                "verified_name": data.get("verified_name"),
                "quality_rating": data.get("quality_rating"),
            }
        return {"connected": False, "error": resp.text}
