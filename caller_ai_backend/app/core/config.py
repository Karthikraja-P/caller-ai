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
    SUPABASE_URL: str
    SUPABASE_ANON_KEY: str
    SUPABASE_SERVICE_KEY: str

    # Twilio
    TWILIO_ACCOUNT_SID: str
    TWILIO_AUTH_TOKEN: str
    TWILIO_VERIFY_SID: str
    TWILIO_PHONE_NUMBER: str

    # OpenAI
    OPENAI_API_KEY: str

    # Google Cloud TTS
    GOOGLE_TTS_API_KEY: str
    GOOGLE_CREDENTIALS_JSON: Optional[str] = None

    # WhatsApp Business API
    WHATSAPP_BUSINESS_ACCOUNT_ID: str
    WHATSAPP_ACCESS_TOKEN: str
    WHATSAPP_PHONE_NUMBER_ID: str

    # Caller ID Providers
    TELNYX_API_KEY: str
    TRESTLEIQ_API_KEY: str
    APIFY_API_TOKEN: str

    # AdMob
    ADMOB_APP_ID: Optional[str] = None
    ADMOB_AD_UNIT_ID: Optional[str] = None

    # Firebase
    FIREBASE_SERVER_KEY: str

    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"

    # RevenueCat
    REVENUECAT_API_KEY: str

    # Mixpanel
    MIXPANEL_TOKEN: str

    # Meilisearch
    MEILISEARCH_URL: str = "http://localhost:7700"
    MEILISEARCH_API_KEY: str

    @property
    def allowed_origins_list(self) -> list[str]:
        return [o.strip() for o in self.ALLOWED_ORIGINS.split(",")]

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
