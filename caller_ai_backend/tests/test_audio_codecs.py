import io
import struct
import wave
import pytest

from app.services.audio_codecs import mulaw_to_wav, extract_raw_mulaw_from_wav


def _build_google_mulaw_wav(raw_data: bytes, sample_rate: int = 8000, audio_format: int = 7, channels: int = 1) -> bytes:
    """Helper to synthesize a RIFF WAV container mimicking Google Cloud TTS MULAW output."""
    fmt_chunk = struct.pack(
        "<HHIIHH",
        audio_format,
        channels,
        sample_rate,
        sample_rate * channels,
        channels,
        8,  # 8 bits per sample
    )
    riff_size = 4 + (8 + len(fmt_chunk)) + (8 + len(raw_data))
    header = (
        b"RIFF" +
        struct.pack("<I", riff_size) +
        b"WAVE" +
        b"fmt " +
        struct.pack("<I", len(fmt_chunk)) +
        fmt_chunk +
        b"data" +
        struct.pack("<I", len(raw_data))
    )
    return header + raw_data


def test_mulaw_to_wav_valid_pcm_container():
    """Verify raw 8-kHz mu-law bytes are converted to a valid mono 16-bit 8000Hz PCM WAV file."""
    raw_mulaw = b"\xff\x00\x55\xaa" * 40  # 160 bytes
    wav_bytes = mulaw_to_wav(raw_mulaw, sample_rate=8000)

    assert wav_bytes.startswith(b"RIFF")
    with wave.open(io.BytesIO(wav_bytes), "rb") as r:
        assert r.getnchannels() == 1
        assert r.getsampwidth() == 2  # 16-bit PCM
        assert r.getframerate() == 8000
        assert r.getnframes() == len(raw_mulaw)
        frames = r.readframes(r.getnframes())
        assert len(frames) == len(raw_mulaw) * 2


def test_mulaw_to_wav_empty_raises_value_error():
    """Verify empty input raises ValueError."""
    with pytest.raises(ValueError, match="empty audio buffer"):
        mulaw_to_wav(b"")


def test_mulaw_to_wav_invalid_type_raises_type_error():
    """Verify non-bytes input raises TypeError."""
    with pytest.raises(TypeError, match="must be bytes"):
        mulaw_to_wav("invalid-string")  # type: ignore


def test_extract_raw_mulaw_from_wav_success():
    """Verify raw mu-law bytes are cleanly extracted from a valid Google TTS WAV container."""
    expected_raw = b"\x7f\x80\xaa\x55" * 100
    wav_bytes = _build_google_mulaw_wav(expected_raw, sample_rate=8000, audio_format=7)

    extracted = extract_raw_mulaw_from_wav(wav_bytes)
    assert extracted == expected_raw
    assert not extracted.startswith(b"RIFF")


def test_extract_raw_mulaw_invalid_header_raises():
    """Verify non-WAV buffer raises ValueError."""
    with pytest.raises(ValueError, match="missing RIFF/WAVE signature"):
        extract_raw_mulaw_from_wav(b"NOT_A_WAV_HEADER" + b"\x00" * 40)


def test_extract_raw_mulaw_too_short_raises():
    """Verify buffer shorter than 44 bytes raises ValueError."""
    with pytest.raises(ValueError, match="too short"):
        extract_raw_mulaw_from_wav(b"RIFF\x10\x00\x00\x00WAVE")


def test_extract_raw_mulaw_non_mulaw_format_raises():
    """Verify non-format-7 audio raises ValueError."""
    pcm_wav = _build_google_mulaw_wav(b"\x00" * 80, sample_rate=8000, audio_format=1)
    with pytest.raises(ValueError, match="Expected G.711 mu-law"):
        extract_raw_mulaw_from_wav(pcm_wav)


def test_extract_raw_mulaw_non_8khz_raises():
    """Verify non-8000Hz audio raises ValueError."""
    wav_16k = _build_google_mulaw_wav(b"\x00" * 80, sample_rate=16000, audio_format=7)
    with pytest.raises(ValueError, match="Expected sample rate 8000 Hz"):
        extract_raw_mulaw_from_wav(wav_16k)


def test_extract_raw_mulaw_truncated_chunk_raises():
    """Verify truncated WAV chunk raises ValueError."""
    raw = _build_google_mulaw_wav(b"\x00" * 80, sample_rate=8000, audio_format=7)
    truncated = raw[: len(raw) - 10]
    with pytest.raises(ValueError, match="Truncated WAV chunk"):
        extract_raw_mulaw_from_wav(truncated)
