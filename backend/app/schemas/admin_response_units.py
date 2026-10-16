import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator, model_validator

ResponseUnitStatusValue = Literal["available", "assigned", "responding", "offline"]


class AdminResponseUnitCounts(BaseModel):
    total: int = Field(ge=0)
    available: int = Field(ge=0)
    assigned: int = Field(ge=0)
    responding: int = Field(ge=0)
    offline: int = Field(ge=0)


class AdminResponseUnitListItem(BaseModel):
    unit_id: uuid.UUID
    name: str
    unit_type: str
    contact: str
    status: ResponseUnitStatusValue
    current_latitude: float | None
    current_longitude: float | None
    location_updated_at: datetime | None
    created_at: datetime
    updated_at: datetime


class AdminResponseUnitListResponse(BaseModel):
    items: list[AdminResponseUnitListItem]
    counts: AdminResponseUnitCounts
    total: int = Field(ge=0)
    page: int = Field(ge=1)
    page_size: int = Field(ge=1, le=100)
    total_pages: int = Field(ge=0)


class AdminResponseUnitCreateRequest(BaseModel):
    name: str = Field(min_length=1, max_length=150)
    unit_type: str = Field(min_length=1, max_length=80)
    contact: str = Field(min_length=1, max_length=100)

    @field_validator("name", "unit_type", "contact")
    @classmethod
    def normalize_required_text(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("Response-unit fields cannot be empty")
        return normalized


class AdminResponseUnitUpdateRequest(BaseModel):
    expected_updated_at: datetime
    name: str | None = Field(default=None, min_length=1, max_length=150)
    unit_type: str | None = Field(default=None, min_length=1, max_length=80)
    contact: str | None = Field(default=None, min_length=1, max_length=100)

    @field_validator("name", "unit_type", "contact")
    @classmethod
    def normalize_optional_text(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = value.strip()
        if not normalized:
            raise ValueError("Response-unit fields cannot be empty")
        return normalized

    @model_validator(mode="after")
    def require_change(self) -> "AdminResponseUnitUpdateRequest":
        if self.name is None and self.unit_type is None and self.contact is None:
            raise ValueError("At least one response-unit field must be provided")
        return self
