import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator, model_validator

PriorityValue = Literal["critical", "high", "medium", "low"]
ReportSourceValue = Literal["app_api", "app_sms", "manual"]
VerificationStatusValue = Literal["pending", "verified", "unverified", "invalid"]
ReportStatusValue = Literal["new", "under_review", "linked", "closed"]
IncidentStatusValue = Literal["open", "dispatched", "responding", "resolved", "closed"]
ManualIntakeChannelValue = Literal["phone_call", "walk_in", "radio_communication", "other_offline"]


class IncidentTypeSummary(BaseModel):
    incident_type_id: uuid.UUID
    code: str
    name: str


class AdminIncidentTypeListResponse(BaseModel):
    items: list[IncidentTypeSummary]


class IncidentSummary(BaseModel):
    incident_id: uuid.UUID
    priority: PriorityValue
    status: IncidentStatusValue
    summary: str


class ReportLocationResponse(BaseModel):
    latitude: float | None
    longitude: float | None
    accuracy_meters: float | None
    landmark: str | None
    source: Literal["gps", "manual"]
    captured_at: datetime


class AdminReportListItem(BaseModel):
    report_id: uuid.UUID
    client_report_id: uuid.UUID | None
    incident_type: IncidentTypeSummary
    incident: IncidentSummary | None
    source: ReportSourceValue
    manual_intake_channel: ManualIntakeChannelValue | None
    description_original: str
    original_language: str | None
    people_need_help: bool
    additional_assistance: bool
    immediate_danger: bool
    suggested_priority: PriorityValue | None
    final_priority: PriorityValue | None
    effective_priority: PriorityValue
    verification_status: VerificationStatusValue
    status: ReportStatusValue
    location: ReportLocationResponse | None
    received_at: datetime
    updated_at: datetime
    closed_at: datetime | None


class AdminReportListResponse(BaseModel):
    items: list[AdminReportListItem]
    total: int = Field(ge=0)
    page: int = Field(ge=1)
    page_size: int = Field(ge=1, le=100)
    total_pages: int = Field(ge=0)


class ReporterSummary(BaseModel):
    user_id: uuid.UUID
    full_name: str
    phone_number: str | None
    email: str | None


class ReportAttachmentResponse(BaseModel):
    attachment_id: uuid.UUID
    media_type: Literal["image", "video"]
    content_type: str
    size_bytes: int
    created_at: datetime


class ReportTranslationResponse(BaseModel):
    translation_id: uuid.UUID
    source_language: str
    target_language: str
    translated_text: str
    model_name: str
    model_version: str
    confidence: float | None
    created_at: datetime


class PriorityAssessmentResponse(BaseModel):
    assessment_id: uuid.UUID
    suggested_priority: PriorityValue
    confidence: float
    model_name: str
    model_version: str
    explanation: str | None
    created_at: datetime


class ReportReviewResponse(BaseModel):
    review_id: uuid.UUID
    reviewed_by_staff_id: uuid.UUID
    priority_conflict: bool
    location_accurate: bool | None
    possible_duplicate: bool
    callback_needed: bool
    decision: str
    notes: str | None
    reviewed_at: datetime


class AdminReportDetailResponse(AdminReportListItem):
    reporter: ReporterSummary
    attachments: list[ReportAttachmentResponse]
    translations: list[ReportTranslationResponse]
    priority_assessments: list[PriorityAssessmentResponse]
    reviews: list[ReportReviewResponse]


class AdminReportReviewRequest(BaseModel):
    expected_updated_at: datetime
    decision: Literal["verified", "unverified", "invalid"]
    final_priority: PriorityValue | None = None
    location_accurate: bool | None = None
    possible_duplicate: bool = False
    callback_needed: bool = False
    notes: str = Field(min_length=1, max_length=2000)

    @model_validator(mode="after")
    def require_verified_fields(self) -> "AdminReportReviewRequest":
        self.notes = self.notes.strip()
        if not self.notes:
            raise ValueError("Reviewer notes cannot be empty")
        if self.decision == "verified" and self.final_priority is None:
            raise ValueError("A final priority is required for verified reports")
        return self


class AdminReportReviewResult(BaseModel):
    report_id: uuid.UUID
    decision: Literal["verified", "unverified", "invalid"]
    verification_status: VerificationStatusValue
    report_status: ReportStatusValue
    final_priority: PriorityValue | None
    reviewed_at: datetime


class AdminManualReportCreateRequest(BaseModel):
    incident_type_id: uuid.UUID
    location: str = Field(min_length=1, max_length=255)
    reporter_contact: str = Field(min_length=10, max_length=30)
    intake_channel: ManualIntakeChannelValue
    description: str = Field(min_length=10, max_length=5000)
    people_need_help: bool
    additional_assistance: bool
    immediate_danger: bool

    @field_validator("location", "description")
    @classmethod
    def normalize_required_text(cls, value: str) -> str:
        normalized = " ".join(value.split())
        if not normalized:
            raise ValueError("Manual report fields cannot be empty")
        return normalized

    @field_validator("reporter_contact")
    @classmethod
    def normalize_reporter_contact(cls, value: str) -> str:
        compact = "".join(character for character in value.strip() if character not in " -()")
        digits = compact[1:] if compact.startswith("+") else compact
        if not digits.isdigit():
            raise ValueError("Enter a valid Philippine mobile number")
        if digits.startswith("09"):
            local_number = digits[1:]
        elif digits.startswith("63"):
            local_number = digits[2:]
        else:
            local_number = digits
        if len(local_number) != 10 or not local_number.startswith("9"):
            raise ValueError("Enter a valid Philippine mobile number")
        return f"+63{local_number}"


class AdminManualReportCreateResult(BaseModel):
    report_id: uuid.UUID
    verification_status: VerificationStatusValue
    report_status: ReportStatusValue
    received_at: datetime
