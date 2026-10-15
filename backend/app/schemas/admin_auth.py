import uuid
from datetime import datetime
from typing import Annotated

from pydantic import BaseModel, ConfigDict, Field, SecretStr, StringConstraints

from app.core.security import PASSWORD_MAX_LENGTH

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


class AdminUserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    user_id: uuid.UUID
    full_name: str
    email: str
    role: str


class AdminSessionResponse(BaseModel):
    user: AdminUserResponse
    expires_at: datetime
