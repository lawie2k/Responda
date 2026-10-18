import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from app.schemas.admin_assignments import AssignmentStatusValue
from app.schemas.admin_reports import PriorityValue, ReportSourceValue, VerificationStatusValue

HistoricalStatus = Literal["resolved", "closed"]


class HistoryPage[Item](BaseModel):
    items: list[Item]
    total: int = Field(ge=0)
    page: int = Field(ge=1)
    page_size: int = Field(ge=1, le=100)
    total_pages: int = Field(ge=0)


class HistoricalIncident(BaseModel):
    incident_id: uuid.UUID
    reference: str
    incident_type_id: uuid.UUID
    incident_type_name: str
    summary: str
    priority: PriorityValue
    status: HistoricalStatus
    location: str | None
    report_count: int
    team_count: int
    first_team: str | None
    completed_assignments: int
    opened_at: datetime
    resolved_at: datetime | None
    closed_at: datetime | None
    recorded_at: datetime


class HistoricalCounts(BaseModel):
    resolved: int = 0
    closed: int = 0


class HistoricalIncidentList(HistoryPage[HistoricalIncident]):
    counts: HistoricalCounts


class HistoricalReport(BaseModel):
    report_id: uuid.UUID
    reference: str
    description: str
    source: ReportSourceValue
    verification_status: VerificationStatusValue
    location: str | None
    received_at: datetime


class HistoricalAssignment(BaseModel):
    assignment_id: uuid.UUID
    unit_name: str
    unit_type: str
    status: AssignmentStatusValue
    assigned_at: datetime
    acknowledged_at: datetime | None
    responding_at: datetime | None
    completed_at: datetime | None
    cancelled_at: datetime | None


class HistoricalEvent(BaseModel):
    event_id: uuid.UUID
    report_reference: str
    event_type: str
    created_at: datetime


class HistoricalIncidentDetail(BaseModel):
    incident: HistoricalIncident
    reports: HistoryPage[HistoricalReport]
    assignments: HistoryPage[HistoricalAssignment]
    events: HistoryPage[HistoricalEvent]
