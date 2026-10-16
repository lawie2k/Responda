import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from app.schemas.admin_reports import IncidentStatusValue
from app.schemas.admin_response_units import ResponseUnitStatusValue

AssignmentStatusValue = Literal[
    "assigned",
    "acknowledged",
    "responding",
    "completed",
    "cancelled",
]
AssignmentTransitionValue = Literal[
    "acknowledged",
    "responding",
    "completed",
    "cancelled",
]


class AdminAssignmentUnitSummary(BaseModel):
    unit_id: uuid.UUID
    name: str
    unit_type: str
    contact: str
    status: ResponseUnitStatusValue


class AdminAssignmentListItem(BaseModel):
    assignment_id: uuid.UUID
    incident_id: uuid.UUID
    unit: AdminAssignmentUnitSummary
    assigned_by_staff_id: uuid.UUID
    status: AssignmentStatusValue
    assigned_at: datetime
    acknowledged_at: datetime | None
    responding_at: datetime | None
    completed_at: datetime | None
    cancelled_at: datetime | None
    updated_at: datetime


class AdminAssignmentListResponse(BaseModel):
    items: list[AdminAssignmentListItem]
    total: int = Field(ge=0)
    page: int = Field(ge=1)
    page_size: int = Field(ge=1, le=100)
    total_pages: int = Field(ge=0)


class AdminAssignmentCreateRequest(BaseModel):
    unit_id: uuid.UUID
    expected_incident_updated_at: datetime


class AdminAssignmentTransitionRequest(BaseModel):
    expected_updated_at: datetime
    status: AssignmentTransitionValue


class AdminAssignmentMutationResult(BaseModel):
    assignment: AdminAssignmentListItem
    incident_status: IncidentStatusValue
    incident_updated_at: datetime
