import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field, model_validator

from app.schemas.admin_reports import IncidentStatusValue, PriorityValue, ReportStatusValue


class AdminIncidentListItem(BaseModel):
    incident_id: uuid.UUID
    incident_type_id: uuid.UUID
    incident_type_name: str
    summary: str
    priority: PriorityValue
    status: IncidentStatusValue
    opened_at: datetime
    updated_at: datetime


class AdminIncidentListResponse(BaseModel):
    items: list[AdminIncidentListItem]
    total: int = Field(ge=0)
    page: int = Field(ge=1)
    page_size: int = Field(ge=1, le=100)
    total_pages: int = Field(ge=0)


class AdminIncidentCreateRequest(BaseModel):
    report_id: uuid.UUID
    expected_report_updated_at: datetime
    summary: str = Field(min_length=1, max_length=2000)

    @model_validator(mode="after")
    def normalize_summary(self) -> "AdminIncidentCreateRequest":
        self.summary = self.summary.strip()
        if not self.summary:
            raise ValueError("Incident summary cannot be empty")
        return self


class AdminIncidentReportLinkRequest(BaseModel):
    report_id: uuid.UUID
    expected_report_updated_at: datetime


class AdminIncidentLinkResult(BaseModel):
    incident_id: uuid.UUID
    incident_updated_at: datetime
    linked_report_id: uuid.UUID
    incident_type_id: uuid.UUID
    priority: PriorityValue
    incident_status: IncidentStatusValue
    summary: str
    report_status: ReportStatusValue
    operation: Literal["created", "linked"]
    linked_at: datetime
