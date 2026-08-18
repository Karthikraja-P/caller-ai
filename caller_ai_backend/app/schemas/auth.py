from pydantic import BaseModel, field_validator
from typing import Optional
import phonenumbers


class RegisterRequest(BaseModel):
    phone_number: str
    device_uuid: str
    device_type: str  # android | ios
    country_code: str
    app_version: str = "2.0.0"

    @field_validator("phone_number")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        try:
            parsed = phonenumbers.parse(v)
            if not phonenumbers.is_valid_number(parsed):
                raise ValueError("Invalid phone number")
            return phonenumbers.format_number(parsed, phonenumbers.PhoneNumberFormat.E164)
        except Exception:
            raise ValueError("Invalid phone number format. Use E.164 format e.g. +919876543210")


class RegisterResponse(BaseModel):
    status: str
    message: str
    session_id: Optional[str] = None
    expires_in: Optional[int] = None


class VerifyOTPRequest(BaseModel):
    session_id: str
    otp_code: str
    phone_number: str  # Required for Twilio Verify check


class UserData(BaseModel):
    id: str
    phone_number: str
    created_at: str


class VerifyOTPResponse(BaseModel):
    access_token: str
    refresh_token: str
    expires_in: int
    user: UserData


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class RefreshTokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    expires_in: int
