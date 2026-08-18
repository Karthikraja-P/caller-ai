from pydantic import BaseModel, EmailStr
from typing import Optional


class UpdateProfileRequest(BaseModel):
    display_name: Optional[str] = None
    email: Optional[str] = None
    avatar_url: Optional[str] = None
    onboarding_complete: Optional[bool] = None


class UserProfileResponse(BaseModel):
    id: str
    phone_number: str
    display_name: Optional[str] = None
    email: Optional[str] = None
    avatar_url: Optional[str] = None
    plan: str = "free"
    onboarding_complete: bool = False
    ai_calls_used: int = 0
    ai_calls_limit: int = 10
    created_at: str
    updated_at: str


class RegisterDeviceRequest(BaseModel):
    device_uuid: str
    fcm_token: str
    platform: str  # android | ios


class SubscriptionResponse(BaseModel):
    plan: str
    expires_at: Optional[str] = None
    features: dict
