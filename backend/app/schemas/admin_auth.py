import uuid
from datetime import datetime
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, SecretStr, StringConstraints, model_validator

from app.core.security import PASSWORD_MAX_LENGTH, PASSWORD_MIN_LENGTH

EmailInput = Annotated[
    str,
    StringConstraints(
        strip_whitespace=True,
        min_length=3,
        max_length=255,
        pattern=r"^[^\s@]+@[^\s@]+\.[^\s@]+$",
    ),
]


class AdminLoginRequest(BaseModel):
    email: EmailInput
    password: SecretStr = Field(min_length=1, max_length=PASSWORD_MAX_LENGTH)


class AdminPasswordChangeRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    current_password: SecretStr = Field(min_length=1, max_length=PASSWORD_MAX_LENGTH)
    new_password: SecretStr = Field(min_length=PASSWORD_MIN_LENGTH, max_length=PASSWORD_MAX_LENGTH)
    confirmation: SecretStr = Field(min_length=PASSWORD_MIN_LENGTH, max_length=PASSWORD_MAX_LENGTH)

    @model_validator(mode="after")
    def matching_passwords(self) -> "AdminPasswordChangeRequest":
        if self.new_password.get_secret_value() != self.confirmation.get_secret_value():
            raise ValueError("New passwords must match")
        return self


class AdminUserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    user_id: uuid.UUID
    full_name: str
    email: str
    role: Literal["admin", "operations_admin"]


class AdminSessionResponse(BaseModel):
    user: AdminUserResponse
    expires_at: datetime
