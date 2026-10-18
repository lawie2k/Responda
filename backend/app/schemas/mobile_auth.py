from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, SecretStr, field_validator

BARANGAYS = frozenset(
    {
        "Bongabong",
        "Bongbong",
        "P. Fuentes",
        "Kingking",
        "Magnaga",
        "Matiao",
        "Napnapan",
        "Tagdangua",
        "Tambongon",
        "Tibagon",
        "Las Arenas",
        "Araibo",
        "Tag-Ugpo",
    }
)


class OtpRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    phone_number: str = Field(pattern=r"^\+639[0-9]{9}$")


class OtpResponse(BaseModel):
    challenge_id: UUID
    expires_at: datetime
    resend_after_seconds: int = 60
    development_code: str | None = None


class OtpVerify(OtpRequest):
    challenge_id: UUID
    code: SecretStr = Field(min_length=6, max_length=6)
    privacy_notice_accepted: bool


class MobileProfileUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    full_name: str = Field(default="", max_length=150)
    barangay: str = Field(default="", max_length=100)

    @field_validator("barangay")
    @classmethod
    def validate_barangay(cls, value: str) -> str:
        if value and value not in BARANGAYS:
            raise ValueError("Select a Pantukan barangay")
        return value


class MobileUser(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    user_id: UUID
    full_name: str
    phone_number: str
    barangay: str | None
    phone_verified_at: datetime
    privacy_notice_accepted_at: datetime


class MobileSession(BaseModel):
    user: MobileUser
    expires_at: datetime


class MobileLogin(MobileSession):
    access_token: str
    token_type: str = "bearer"
