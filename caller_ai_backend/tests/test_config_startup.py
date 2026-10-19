import os
import sys
from unittest.mock import MagicMock, patch
import pytest

# Ensure isolated test execution without external services
if "redis" not in sys.modules:
    sys.modules["redis"] = MagicMock()
if "redis.asyncio" not in sys.modules:
    sys.modules["redis.asyncio"] = MagicMock()
if "openai" not in sys.modules:
    mock_openai = MagicMock()
    sys.modules["openai"] = mock_openai

from app.core.config import Settings
from app.services.ai_voice_service import get_openai_client
import app.services.ai_voice_service as ai_voice_module


def test_settings_default_minimal_startup():
    """Verify Settings initializes with default config when external providers are unconfigured."""
    with patch.dict(os.environ, {}, clear=True):
        config = Settings(_env_file=None)
        assert config.APP_ENV == "development"
        assert config.APP_VERSION == "2.0.0"
        assert config.DEBUG is True
        assert config.REDIS_URL == "redis://localhost:6379/0"
        assert config.SUPABASE_URL is None
        assert config.OPENAI_API_KEY is None
        assert config.TWILIO_ACCOUNT_SID is None
        assert config.TELNYX_API_KEY is None
        assert config.allowed_origins_list == ["http://localhost:3000"]


def test_settings_with_configured_providers():
    """Verify Settings loads specific provider credentials when configured."""
    custom_env = {
        "APP_ENV": "staging",
        "SUPABASE_URL": "https://test-project.supabase.co",
        "TWILIO_ACCOUNT_SID": "AC1234567890abcdef",
        "OPENAI_API_KEY": "sk-test-openai-key",
        "TELNYX_API_KEY": "KEY0123456789",
    }
    with patch.dict(os.environ, custom_env, clear=True):
        config = Settings(_env_file=None)
        assert config.APP_ENV == "staging"
        assert config.SUPABASE_URL == "https://test-project.supabase.co"
        assert config.TWILIO_ACCOUNT_SID == "AC1234567890abcdef"
        assert config.OPENAI_API_KEY == "sk-test-openai-key"
        assert config.TELNYX_API_KEY == "KEY0123456789"
        # Unconfigured provider remains None without crashing
        assert config.TRESTLEIQ_API_KEY is None


def test_settings_env_file_and_string_values(tmp_path):
    env_file = tmp_path / "caller.env"
    env_file.write_text(
        "APP_ENV=staging\nDEBUG=false\nOPENAI_API_KEY=yes\n"
        "ALLOWED_ORIGINS=https://one.example,https://two.example\n"
    )
    with patch.dict(os.environ, {}, clear=True):
        config = Settings(_env_file=env_file)
    assert config.APP_ENV == "staging"
    assert config.DEBUG is False
    assert config.OPENAI_API_KEY == "yes"
    assert config.allowed_origins_list == ["https://one.example", "https://two.example"]


def test_unconfigured_openai_client_raises_value_error():
    """Verify calling get_openai_client when unconfigured raises ValueError explicitly."""
    # Reset singleton
    ai_voice_module._openai_client = None
    with patch("app.services.ai_voice_service.settings.OPENAI_API_KEY", None):
        with pytest.raises(ValueError, match="OPENAI_API_KEY is not configured"):
            get_openai_client()


def test_configured_openai_client_initializes_lazily():
    """Verify get_openai_client instantiates client when OPENAI_API_KEY is set."""
    ai_voice_module._openai_client = None
    with patch("app.services.ai_voice_service.settings.OPENAI_API_KEY", "sk-valid-key"):
        client = get_openai_client()
        assert client is not None
    # Reset singleton after test
    ai_voice_module._openai_client = None
