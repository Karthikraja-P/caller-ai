import io
import struct
import wave

# Precomputed 256-element table converting G.711 mu-law bytes to signed 16-bit linear PCM samples
_MULAW_DECODE_TABLE = []
for _b in range(256):
    _b_inv = ~_b & 0xFF
    _sign = _b_inv & 0x80
    _exponent = (_b_inv >> 4) & 0x07
    _mantissa = _b_inv & 0x0F
    _sample = ((_mantissa << 3) + 0x84) << _exponent
    _sample -= 0x84
    _MULAW_DECODE_TABLE.append(-_sample if _sign else _sample)

_MULAW_TO_PCM16_BYTES = tuple(struct.pack("<h", _s) for _s in _MULAW_DECODE_TABLE)


def mulaw_to_wav(mulaw_bytes: bytes, sample_rate: int = 8000) -> bytes:
    """
    Convert raw 8-kHz G.711 mu-law bytes to a valid 16-bit linear PCM WAV container.
    Safe for OpenAI Whisper and standard audio decoders.
    """
    if not isinstance(mulaw_bytes, (bytes, bytearray)):
        raise TypeError("mulaw_bytes must be bytes or bytearray")
    if len(mulaw_bytes) == 0:
        raise ValueError("Cannot create WAV from empty audio buffer")

    # Fast lookup conversion to 16-bit PCM
    pcm_bytes = b"".join(_MULAW_TO_PCM16_BYTES[b] for b in mulaw_bytes)

    buf = io.BytesIO()
    with wave.open(buf, "wb") as wav_file:
        wav_file.setnchannels(1)       # Mono
        wav_file.setsampwidth(2)       # 16-bit PCM
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(pcm_bytes)
    return buf.getvalue()


def extract_raw_mulaw_from_wav(wav_bytes: bytes) -> bytes:
    """
    Validate RIFF WAVE container returned by Google Cloud TTS MULAW and
    extract headerless 8-kHz raw G.711 mu-law audio bytes for Twilio.
    """
    if not isinstance(wav_bytes, (bytes, bytearray)):
        raise TypeError("wav_bytes must be bytes or bytearray")
    if len(wav_bytes) < 44:
        raise ValueError("Audio buffer too short to contain a valid WAV header")
    if not wav_bytes.startswith(b"RIFF") or wav_bytes[8:12] != b"WAVE":
        raise ValueError("Invalid WAV container: missing RIFF/WAVE signature")

    offset = 12
    length = len(wav_bytes)
    audio_format = None
    channels = None
    sample_rate = None
    data_bytes = None

    while offset + 8 <= length:
        chunk_id = wav_bytes[offset:offset+4]
        chunk_size = struct.unpack("<I", wav_bytes[offset+4:offset+8])[0]
        chunk_start = offset + 8
        chunk_end = chunk_start + chunk_size

        if chunk_end > length:
            raise ValueError(f"Truncated WAV chunk '{chunk_id.decode('latin1', errors='replace')}'")

        if chunk_id == b"fmt ":
            if chunk_size < 14:
                raise ValueError("Malformed fmt chunk in WAV container")
            audio_format, channels, sample_rate = struct.unpack("<HHI", wav_bytes[chunk_start:chunk_start+8])
        elif chunk_id == b"data":
            data_bytes = wav_bytes[chunk_start:chunk_end]
            break

        # RIFF chunks are padded to 2-byte boundaries
        offset = chunk_end + (chunk_size % 2)

    if audio_format != 7:
        raise ValueError(f"Expected G.711 mu-law (audio_format 7), got format {audio_format}")
    if sample_rate != 8000:
        raise ValueError(f"Expected sample rate 8000 Hz, got {sample_rate} Hz")
    if channels != 1:
        raise ValueError(f"Expected mono channel (1), got {channels} channels")
    if data_bytes is None:
        raise ValueError("No data chunk found in WAV container")

    return data_bytes
