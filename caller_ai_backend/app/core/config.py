from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    # App
    APP_ENV: str = "development"
    APP_VERSION: str = "2.0.0"
    DEBUG: bool = True
    SECRET_KEY: str = "change-me-in-production"
    ALLOWED_ORIGINS: str = "http://localhost:3000"

    # Supabase
    SUPABASE_URL: Optional[str] = None
    SUPABASE_ANON_KEY: Optional[str] = None
    SUPABASE_SERVICE_KEY: Optional[str] = None

    # Twilio
    TWILIO_ACCOUNT_SID: Optional[str] = None
    TWILIO_AUTH_TOKEN: Optional[str] = None
    TWILIO_VERIFY_SID: Optional[str] = None
    TWILIO_PHONE_NUMBER: Optional[str] = None
    TWILIO_WEBHOOK_BASE_URL: Optional[str] = None
    PUBLIC_BASE_URL: Optional[str] = None

    # OpenAI
    OPENAI_API_KEY: Optional[str] = None

    # Google Cloud TTS
    GOOGLE_TTS_API_KEY: Optional[str] = None
    GOOGLE_CREDENTIALS_JSON: Optional[str] = None

    # WhatsApp Business API
    WHATSAPP_BUSINESS_ACCOUNT_ID: Optional[str] = None
    WHATSAPP_ACCESS_TOKEN: Optional[str] = None
    WHATSAPP_PHONE_NUMBER_ID: Optional[str] = None

    # Caller ID Providers
    TELNYX_API_KEY: Optional[str] = None
    TRESTLEIQ_API_KEY: Optional[str] = None
    APIFY_API_TOKEN: Optional[str] = None

    # AdMob
    ADMOB_APP_ID: Optional[str] = None
    ADMOB_AD_UNIT_ID: Optional[str] = None

    # Firebase
    FIREBASE_SERVER_KEY: Optional[str] = None

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"

    # RevenueCat
    REVENUECAT_API_KEY: Optional[str] = None

    # Mixpanel
    MIXPANEL_TOKEN: Optional[str] = None

    # Meilisearch
    MEILISEARCH_URL: str = "http://localhost:7700"
    MEILISEARCH_API_KEY: Optional[str] = None

    @property
    def allowed_origins_list(self) -> list[str]:
        return [o.strip() for o in self.ALLOWED_ORIGINS.split(",")]

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
