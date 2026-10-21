import uuid
from datetime import UTC, datetime, timedelta
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class MobileReportCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    client_report_id: uuid.UUID
    incident_type_code: Literal["road_accident", "flood", "fire", "drowning", "other"]
    description: str = Field(min_length=10, max_length=5000)
    people_need_help: bool = False
    additional_assistance: bool = False
    immediate_danger: bool = False
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    accuracy_meters: float | None = Field(default=None, ge=0, le=100000)
    landmark: str | None = Field(default=None, max_length=255)
    location_captured_at: datetime | None = None

    @field_validator("description")
    @classmethod
    def normalize_description(cls, value: str) -> str:
        normalized = " ".join(value.split())
        if len(normalized) < 10:
            raise ValueError("Description is too short")
        return normalized

    @field_validator("landmark")
    @classmethod
    def normalize_landmark(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = " ".join(value.split())
        return normalized or None

    @model_validator(mode="after")
    def validate_location(self) -> "MobileReportCreateRequest":
        if (self.latitude is None) != (self.longitude is None):
            raise ValueError("Coordinates must include latitude and longitude")
        if self.latitude is None and self.landmark is None:
            raise ValueError("A GPS location or landmark is required")
        if self.location_captured_at is not None:
            captured = self.location_captured_at
            if captured.tzinfo is None:
                captured = captured.replace(tzinfo=UTC)
            if captured > datetime.now(UTC) + timedelta(minutes=5):
                raise ValueError("Location capture time cannot be in the future")
        return self


class MobileReportCreateResponse(BaseModel):
    report_id: uuid.UUID
    client_report_id: uuid.UUID
    verification_status: Literal["pending"]
    report_status: Literal["new"]
    received_at: datetime


TrackingStatus = Literal[
    "for_verification",
    "needs_review",
    "for_dispatch",
    "team_assigned",
    "responding",
    "resolved",
    "closed",
]


class MobileReportTrackingResponse(BaseModel):
    report_id: uuid.UUID
    incident_type_code: str
    description: str
    landmark: str | None
    received_at: datetime
    updated_at: datetime
    tracking_status: TrackingStatus
    milestones: dict[str, datetime]


class MobileReportListResponse(BaseModel):
    items: list[MobileReportTrackingResponse]
    total: int
    page: int
    page_size: int
    total_pages: int
    active_count: int
