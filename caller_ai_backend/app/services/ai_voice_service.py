import asyncio
import base64
import io
from typing import AsyncGenerator

import httpx
from google.cloud import texttospeech
from openai import AsyncOpenAI

from app.core.config import settings

openai_client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)


async def transcribe_audio(audio_bytes: bytes, language: str = "en") -> str:
    """
    Transcribe audio bytes using OpenAI Whisper API.
    Returns transcript string.
    """
    audio_file = io.BytesIO(audio_bytes)
    audio_file.name = "audio.wav"

    transcript = await openai_client.audio.transcriptions.create(
        model="whisper-1",
        file=audio_file,
        language=language,
        response_format="text",
    )
    return transcript


async def synthesize_speech(text: str, voice_id: str = "en-US-Neural2-A") -> bytes:
    """
    Convert text to speech using Google Cloud TTS.
    Returns MP3 audio bytes.
    """
    client = texttospeech.TextToSpeechAsyncClient()

    synthesis_input = texttospeech.SynthesisInput(text=text)
    voice = texttospeech.VoiceSelectionParams(
        language_code=voice_id[:5],  # e.g., "en-US"
        name=voice_id,
    )
    audio_config = texttospeech.AudioConfig(
        audio_encoding=texttospeech.AudioEncoding.MP3,
        speaking_rate=1.0,
        pitch=0.0,
    )

    response = await client.synthesize_speech(
        input=synthesis_input,
        voice=voice,
        audio_config=audio_config,
    )
    return response.audio_content


async def synthesize_speech_rest(text: str, voice_id: str = "en-US-Neural2-A") -> bytes:
    """
    Fallback: Google TTS via REST API (uses API key instead of service account).
    """
    url = f"https://texttospeech.googleapis.com/v1/text:synthesize?key={settings.GOOGLE_TTS_API_KEY}"
    payload = {
        "input": {"text": text},
        "voice": {
            "languageCode": voice_id[:5],
            "name": voice_id,
        },
        "audioConfig": {
            "audioEncoding": "MP3",
            "speakingRate": 1.0,
        },
    }
    async with httpx.AsyncClient(timeout=15.0) as client:
        resp = await client.post(url, json=payload)
        resp.raise_for_status()
        audio_b64 = resp.json().get("audioContent", "")
        return base64.b64decode(audio_b64)


SPAM_INTENTS = {
    "loan": ["loan", "emi", "interest", "principal", "credit", "finance"],
    "trading": ["trading", "stock", "investment", "returns", "portfolio", "market"],
    "shopping": ["offer", "discount", "sale", "deal", "shopping", "product"],
    "insurance": ["insurance", "premium", "coverage", "claim", "policy"],
    "survey": ["survey", "question", "research", "opinion", "feedback"],
    "fraud": ["urgent", "verify", "account", "suspicious", "fraud", "block"],
}


def classify_intent(text: str) -> tuple[str, list[str]]:
    """Simple keyword-based intent classifier. Returns (intent, matched_keywords)."""
    text_lower = text.lower()
    for intent, keywords in SPAM_INTENTS.items():
        matched = [kw for kw in keywords if kw in text_lower]
        if matched:
            return intent, matched
    return "general", []


def extract_entities(text: str, intent: str) -> list[dict]:
    """Extract structured entities from transcript text based on intent."""
    import re
    entities = []

    # Extract money amounts
    money_matches = re.findall(r'\$[\d,]+(?:\.\d{2})?|\d+(?:,\d+)*(?:\.\d+)?\s*(?:dollars?|rupees?|lakhs?|crores?)', text, re.IGNORECASE)
    for m in money_matches:
        entities.append({"type": "amount", "value": m.strip()})

    # Extract percentages
    pct_matches = re.findall(r'\d+(?:\.\d+)?\s*%', text)
    for m in pct_matches:
        entities.append({"type": "percentage", "value": m.strip()})

    # Extract time durations
    duration_matches = re.findall(r'\d+\s*(?:months?|years?|days?|weeks?)', text, re.IGNORECASE)
    for m in duration_matches:
        entities.append({"type": "duration", "value": m.strip()})

    # Extract company names (simple: capitalized words after "from" / "by")
    company_matches = re.findall(r'(?:from|by|at)\s+([A-Z][a-zA-Z\s]{2,30})', text)
    for m in company_matches:
        entities.append({"type": "company", "value": m.strip()})

    return entities


async def generate_ai_response(
    transcript_so_far: list[dict],
    intent: str,
    personality: str = "friendly",
    agent_name: str = "Assistant",
) -> str:
    """
    Generate AI response using GPT-4 mini based on conversation so far.
    Falls back to template responses for common spam intents.
    """
    TEMPLATES = {
        "loan": [
            "Could you tell me more about the interest rate and loan tenure?",
            "What is the processing fee for this loan?",
            "What documents are required to apply?",
        ],
        "trading": [
            "What are the expected returns on this investment?",
            "Is this SEBI registered? Can you share the registration number?",
            "What is the minimum investment amount?",
        ],
        "general": [
            "I see, could you provide more details?",
            "That's interesting. Could you elaborate further?",
            "Thank you for the information. Is there anything else?",
        ],
    }

    templates = TEMPLATES.get(intent, TEMPLATES["general"])
    # Rotate through templates based on conversation length
    idx = len(transcript_so_far) % len(templates)
    return templates[idx]
