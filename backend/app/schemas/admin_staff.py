import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, SecretStr, field_validator

from app.core.security import PASSWORD_MAX_LENGTH, PASSWORD_MIN_LENGTH
from app.schemas.admin_auth import EmailInput


class StaffItem(BaseModel):
    user_id: uuid.UUID
    full_name: str
    email: str | None
    role: Literal["admin", "operations_admin"]
    is_active: bool
    created_at: datetime
    updated_at: datetime


class StaffList(BaseModel):
    items: list[StaffItem]
    total: int
    page: int
    page_size: int
    total_pages: int


class StaffIdentity(BaseModel):
    model_config = ConfigDict(extra="forbid")
    full_name: str = Field(min_length=1, max_length=150)
    email: EmailInput

    @field_validator("full_name")
    @classmethod
    def clean_name(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Full name is required")
        return value


class StaffCreate(StaffIdentity):
    password: SecretStr = Field(min_length=PASSWORD_MIN_LENGTH, max_length=PASSWORD_MAX_LENGTH)


class StaffUpdate(StaffIdentity):
    expected_updated_at: datetime
    is_active: bool


class StaffRevoke(BaseModel):
    model_config = ConfigDict(extra="forbid")
    expected_updated_at: datetime


class StaffPolicy(BaseModel):
    password_min_length: int
    password_max_length: int
    session_ttl_seconds: int
    max_sessions_per_user: int
    login_attempts: int
    login_window_seconds: int
    secure_cookies: bool
    timezone: str = "Asia/Manila"
