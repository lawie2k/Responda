from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import AwareDatetime, BaseModel, ConfigDict, Field


class SmsDeviceRegistration(BaseModel):
    model_config = ConfigDict(extra="forbid")
    device_id: UUID


class SmsDeviceInfo(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    device_id: UUID
    expires_at: datetime


class SmsDeviceCredential(SmsDeviceInfo):
    signing_key: str
    gateway_number: str | None = None
    protocol: Literal["RSP1"] = "RSP1"


class GatewayCreate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    name: str = Field(min_length=1, max_length=100)
    phone_number: str = Field(pattern=r"^\+639[0-9]{9}$")
    device_identifier: str = Field(min_length=1, max_length=150)


class GatewayCredential(BaseModel):
    gateway_id: UUID
    access_token: str


class GatewaySmsRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    provider_message_id: str = Field(min_length=1, max_length=150)
    sender_number: str = Field(pattern=r"^\+639[0-9]{9}$")
    body: str = Field(min_length=1, max_length=2048)
    received_at: AwareDatetime


class GatewaySmsResult(BaseModel):
    status: Literal["accepted", "duplicate", "rejected"]
    report_id: UUID | None = None
