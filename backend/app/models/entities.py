import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    Uuid,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, SoftDeleteMixin


def uuid_primary_key() -> Mapped[uuid.UUID]:
    return mapped_column(Uuid, primary_key=True, server_default=text("gen_random_uuid()"))


def created_at_column() -> Mapped[datetime]:
    return mapped_column(
        DateTime(timezone=True), nullable=False, server_default=text("CURRENT_TIMESTAMP")
    )


class User(SoftDeleteMixin, Base):
    __tablename__ = "users"
    __table_args__ = (
        CheckConstraint(
            "role IN ('reporter','admin','operations_admin','dispatcher','verifier','viewer')",
            name="role_valid",
        ),
        CheckConstraint("phone_number IS NOT NULL OR email IS NOT NULL", name="contact_present"),
    )

    user_id: Mapped[uuid.UUID] = uuid_primary_key()
    full_name: Mapped[str] = mapped_column(String(150), nullable=False)
    phone_number: Mapped[str | None] = mapped_column(String(30), unique=True)
    email: Mapped[str | None] = mapped_column(String(255), unique=True)
    password_hash: Mapped[str | None] = mapped_column(String(255))
    role: Mapped[str] = mapped_column(String(20), nullable=False, server_default=text("'reporter'"))
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    phone_verified_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    barangay: Mapped[str | None] = mapped_column(String(100))
    privacy_notice_accepted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = created_at_column()
    updated_at: Mapped[datetime] = created_at_column()


class AuthSession(Base):
    __tablename__ = "auth_sessions"

    session_id: Mapped[uuid.UUID] = uuid_primary_key()
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False, index=True
    )
    refresh_token_hash: Mapped[str] = mapped_column(String(255), nullable=False, unique=True)
    device_name: Mapped[str | None] = mapped_column(String(150))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = created_at_column()


class OtpChallenge(Base):
    __tablename__ = "otp_challenges"
    __table_args__ = (CheckConstraint("attempt_count >= 0", name="attempt_count_nonnegative"),)

    challenge_id: Mapped[uuid.UUID] = uuid_primary_key()
    phone_number: Mapped[str] = mapped_column(String(30), nullable=False, index=True)
    purpose: Mapped[str] = mapped_column(String(40), nullable=False)
    code_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    attempt_count: Mapped[int] = mapped_column(Integer, nullable=False, server_default=text("0"))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    consumed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = created_at_column()


class IncidentType(SoftDeleteMixin, Base):
    __tablename__ = "incident_types"
    __table_args__ = (
        CheckConstraint(
            "default_priority IN ('critical','high','medium','low')",
            name="default_priority_valid",
        ),
    )

    incident_type_id: Mapped[uuid.UUID] = uuid_primary_key()
    code: Mapped[str] = mapped_column(String(50), nullable=False, unique=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False, unique=True)
    description: Mapped[str | None] = mapped_column(Text)
    default_priority: Mapped[str] = mapped_column(String(10), nullable=False)
    active: Mapped[bool] = mapped_column(Boolean, nullable=False, server_default=text("true"))
    icon_key: Mapped[str | None] = mapped_column(String(100))
    created_at: Mapped[datetime] = created_at_column()
    updated_at: Mapped[datetime] = created_at_column()


class Incident(SoftDeleteMixin, Base):
    __tablename__ = "incidents"
    __table_args__ = (
        CheckConstraint("priority IN ('critical','high','medium','low')", name="priority_valid"),
        CheckConstraint(
            "status IN ('open','dispatched','responding','resolved','closed')",
            name="status_valid",
        ),
    )

    incident_id: Mapped[uuid.UUID] = uuid_primary_key()
    incident_type_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("incident_types.incident_type_id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    created_by_staff_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.user_id", ondelete="SET NULL"), index=True
    )
    summary: Mapped[str] = mapped_column(Text, nullable=False)
    priority: Mapped[str] = mapped_column(String(10), nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False, server_default=text("'open'"))
    opened_at: Mapped[datetime] = created_at_column()
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    closed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = created_at_column()


class Report(SoftDeleteMixin, Base):
    __tablename__ = "reports"
    __table_args__ = (
        CheckConstraint("source IN ('app_api','app_sms','manual')", name="source_valid"),
        CheckConstraint(
            "manual_intake_channel IS NULL OR manual_intake_channel IN "
            "('phone_call','walk_in','radio_communication','other_offline')",
            name="manual_intake_channel_valid",
        ),
        CheckConstraint(
            "source = 'manual' OR manual_intake_channel IS NULL",
            name="manual_intake_channel_source_valid",
        ),
        CheckConstraint(
            "verification_status IN ('pending','verified','unverified','invalid')",
            name="verification_status_valid",
        ),
        CheckConstraint(
            "status IN ('new','under_review','linked','closed')",
            name="status_valid",
        ),
        CheckConstraint(
            "suggested_priority IS NULL OR "
            "suggested_priority IN ('critical','high','medium','low')",
            name="suggested_priority_valid",
        ),
        CheckConstraint(
            "final_priority IS NULL OR final_priority IN ('critical','high','medium','low')",
            name="final_priority_valid",
        ),
        CheckConstraint(
            "source = 'manual' OR client_report_id IS NOT NULL",
            name="app_client_report_id_present",
        ),
        Index("ix_reports_received_at", "received_at"),
    )

    report_id: Mapped[uuid.UUID] = uuid_primary_key()
    client_report_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, unique=True)
    reporter_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.user_id", ondelete="RESTRICT"), nullable=False, index=True
    )
    incident_type_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("incident_types.incident_type_id", ondelete="RESTRICT"),
        nullable=False,
        index=True,
    )
    incident_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("incidents.incident_id", ondelete="SET NULL"), index=True
    )
    source: Mapped[str] = mapped_column(String(20), nullable=False)
    manual_intake_channel: Mapped[str | None] = mapped_column(String(30))
    description_original: Mapped[str] = mapped_column(Text, nullable=False)
    original_language: Mapped[str | None] = mapped_column(String(20))
    people_need_help: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    additional_assistance: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    immediate_danger: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    suggested_priority: Mapped[str | None] = mapped_column(String(10))
    final_priority: Mapped[str | None] = mapped_column(String(10))
    verification_status: Mapped[str] = mapped_column(
        String(20), nullable=False, server_default=text("'pending'")
    )
    status: Mapped[str] = mapped_column(String(20), nullable=False, server_default=text("'new'"))
    received_at: Mapped[datetime] = created_at_column()
    closed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = created_at_column()


class ReportLocation(SoftDeleteMixin, Base):
    __tablename__ = "report_locations"
    __table_args__ = (
        CheckConstraint("latitude BETWEEN -90 AND 90", name="latitude_valid"),
        CheckConstraint("longitude BETWEEN -180 AND 180", name="longitude_valid"),
        CheckConstraint(
            "(latitude IS NULL AND longitude IS NULL) OR "
            "(latitude IS NOT NULL AND longitude IS NOT NULL)",
            name="coordinates_pair_valid",
        ),
        CheckConstraint(
            "latitude IS NOT NULL OR landmark IS NOT NULL",
            name="location_details_present",
        ),
        CheckConstraint(
            "accuracy_meters IS NULL OR accuracy_meters >= 0", name="accuracy_nonnegative"
        ),
        CheckConstraint("source IN ('gps','manual')", name="source_valid"),
    )

    location_id: Mapped[uuid.UUID] = uuid_primary_key()
    report_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("reports.report_id", ondelete="CASCADE"), nullable=False, unique=True
    )
    latitude: Mapped[Decimal | None] = mapped_column(Numeric(9, 6))
    longitude: Mapped[Decimal | None] = mapped_column(Numeric(9, 6))
    accuracy_meters: Mapped[Decimal | None] = mapped_column(Numeric(10, 2))
    landmark: Mapped[str | None] = mapped_column(String(255))
    source: Mapped[str] = mapped_column(String(10), nullable=False)
    captured_at: Mapped[datetime] = created_at_column()


class ReportAttachment(SoftDeleteMixin, Base):
    __tablename__ = "report_attachments"
    __table_args__ = (CheckConstraint("media_type IN ('image','video')", name="media_type_valid"),)

    attachment_id: Mapped[uuid.UUID] = uuid_primary_key()
    report_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("reports.report_id", ondelete="CASCADE"), nullable=False, index=True
    )
    media_type: Mapped[str] = mapped_column(String(10), nullable=False)
    storage_key: Mapped[str] = mapped_column(String(500), nullable=False, unique=True)
    content_type: Mapped[str] = mapped_column(String(100), nullable=False)
    size_bytes: Mapped[int] = mapped_column(Integer, nullable=False)
    checksum_sha256: Mapped[str] = mapped_column(String(64), nullable=False)
    created_at: Mapped[datetime] = created_at_column()


class ReportTranslation(Base):
    __tablename__ = "report_translations"
    __table_args__ = (
        UniqueConstraint("report_id", "target_language", "model_version"),
        CheckConstraint(
            "confidence IS NULL OR confidence BETWEEN 0 AND 1", name="confidence_valid"
        ),
    )

    translation_id: Mapped[uuid.UUID] = uuid_primary_key()
    report_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("reports.report_id", ondelete="CASCADE"), nullable=False, index=True
    )
    source_language: Mapped[str] = mapped_column(String(20), nullable=False)
    target_language: Mapped[str] = mapped_column(
        String(20), nullable=False, server_default=text("'en'")
    )
    translated_text: Mapped[str] = mapped_column(Text, nullable=False)
    model_name: Mapped[str] = mapped_column(String(150), nullable=False)
    model_version: Mapped[str] = mapped_column(String(100), nullable=False)
    confidence: Mapped[Decimal | None] = mapped_column(Numeric(5, 4))
    created_at: Mapped[datetime] = created_at_column()


class PriorityAssessment(Base):
    __tablename__ = "priority_assessments"
    __table_args__ = (
        CheckConstraint(
            "suggested_priority IN ('critical','high','medium','low')", name="priority_valid"
        ),
        CheckConstraint("confidence BETWEEN 0 AND 1", name="confidence_valid"),
    )

    assessment_id: Mapped[uuid.UUID] = uuid_primary_key()
    report_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("reports.report_id", ondelete="CASCADE"), nullable=False, index=True
    )
    suggested_priority: Mapped[str] = mapped_column(String(10), nullable=False)
    confidence: Mapped[Decimal] = mapped_column(Numeric(5, 4), nullable=False)
    model_name: Mapped[str] = mapped_column(String(150), nullable=False)
    model_version: Mapped[str] = mapped_column(String(100), nullable=False)
    explanation: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = created_at_column()


class ReportReview(Base):
    __tablename__ = "report_reviews"

    review_id: Mapped[uuid.UUID] = uuid_primary_key()
    report_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("reports.report_id", ondelete="CASCADE"), nullable=False, index=True
    )
    reviewed_by_staff_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.user_id", ondelete="RESTRICT"), nullable=False, index=True
    )
    priority_conflict: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    location_accurate: Mapped[bool | None] = mapped_column(Boolean)
    possible_duplicate: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    callback_needed: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    decision: Mapped[str] = mapped_column(String(20), nullable=False)
    notes: Mapped[str | None] = mapped_column(Text)
    reviewed_at: Mapped[datetime] = created_at_column()


class SmsGateway(SoftDeleteMixin, Base):
    __tablename__ = "sms_gateways"
    __table_args__ = (
        CheckConstraint("status IN ('active','inactive','offline')", name="status_valid"),
    )

    gateway_id: Mapped[uuid.UUID] = uuid_primary_key()
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    phone_number: Mapped[str] = mapped_column(String(30), nullable=False, unique=True)
    device_identifier: Mapped[str] = mapped_column(String(150), nullable=False, unique=True)
    api_key_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False, server_default=text("'active'"))
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = created_at_column()
    updated_at: Mapped[datetime] = created_at_column()


class SmsMessage(SoftDeleteMixin, Base):
    __tablename__ = "sms_messages"
    __table_args__ = (
        UniqueConstraint("gateway_id", "provider_message_id"),
        CheckConstraint(
            "parse_status IN ('received','accepted','rejected','duplicate','error')",
            name="parse_status_valid",
        ),
        CheckConstraint(
            "parse_status != 'accepted' OR "
            "(signature_valid = true AND protocol_version IS NOT NULL "
            "AND client_report_id IS NOT NULL)",
            name="accepted_message_is_valid_app_message",
        ),
        CheckConstraint(
            "report_id IS NULL OR (parse_status = 'accepted' AND signature_valid = true)",
            name="report_requires_accepted_signature",
        ),
        Index("ix_sms_messages_received_at", "received_at"),
    )

    sms_id: Mapped[uuid.UUID] = uuid_primary_key()
    gateway_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("sms_gateways.gateway_id", ondelete="RESTRICT"), nullable=False, index=True
    )
    provider_message_id: Mapped[str] = mapped_column(String(150), nullable=False)
    sender_number: Mapped[str] = mapped_column(String(30), nullable=False)
    raw_message_body: Mapped[str] = mapped_column(Text, nullable=False)
    protocol_version: Mapped[str | None] = mapped_column(String(20))
    client_report_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, index=True)
    signature: Mapped[str | None] = mapped_column(Text)
    signature_valid: Mapped[bool] = mapped_column(
        Boolean, nullable=False, server_default=text("false")
    )
    parse_status: Mapped[str] = mapped_column(
        String(20), nullable=False, server_default=text("'received'")
    )
    rejection_reason: Mapped[str | None] = mapped_column(String(255))
    report_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("reports.report_id", ondelete="SET NULL"), unique=True
    )
    received_at: Mapped[datetime] = created_at_column()
    processed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class ResponseUnit(SoftDeleteMixin, Base):
    __tablename__ = "response_units"
    __table_args__ = (
        CheckConstraint(
            "status IN ('available','assigned','responding','offline')", name="status_valid"
        ),
        CheckConstraint(
            "current_latitude IS NULL OR current_latitude BETWEEN -90 AND 90", name="latitude_valid"
        ),
        CheckConstraint(
            "current_longitude IS NULL OR current_longitude BETWEEN -180 AND 180",
            name="longitude_valid",
        ),
    )

    unit_id: Mapped[uuid.UUID] = uuid_primary_key()
    name: Mapped[str] = mapped_column(String(150), nullable=False, unique=True)
    unit_type: Mapped[str] = mapped_column(String(80), nullable=False)
    contact: Mapped[str] = mapped_column(String(100), nullable=False)
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, server_default=text("'available'")
    )
    current_latitude: Mapped[Decimal | None] = mapped_column(Numeric(9, 6))
    current_longitude: Mapped[Decimal | None] = mapped_column(Numeric(9, 6))
    location_updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = created_at_column()
    updated_at: Mapped[datetime] = created_at_column()


class ResponseAssignment(SoftDeleteMixin, Base):
    __tablename__ = "response_assignments"
    __table_args__ = (
        CheckConstraint(
            "status IN ('assigned','acknowledged','responding','completed','cancelled')",
            name="status_valid",
        ),
        Index(
            "uq_response_assignments_unit_active",
            "unit_id",
            unique=True,
            postgresql_where=text(
                "deleted_at IS NULL AND status IN ('assigned','acknowledged','responding')"
            ),
        ),
    )

    assignment_id: Mapped[uuid.UUID] = uuid_primary_key()
    incident_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("incidents.incident_id", ondelete="CASCADE"), nullable=False, index=True
    )
    unit_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("response_units.unit_id", ondelete="RESTRICT"), nullable=False, index=True
    )
    assigned_by_staff_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.user_id", ondelete="RESTRICT"), nullable=False, index=True
    )
    status: Mapped[str] = mapped_column(
        String(20), nullable=False, server_default=text("'assigned'")
    )
    assigned_at: Mapped[datetime] = created_at_column()
    acknowledged_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    responding_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = created_at_column()


class ReportEvent(Base):
    __tablename__ = "report_events"

    event_id: Mapped[uuid.UUID] = uuid_primary_key()
    report_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("reports.report_id", ondelete="CASCADE"), nullable=False, index=True
    )
    actor_user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.user_id", ondelete="SET NULL"), index=True
    )
    event_type: Mapped[str] = mapped_column(String(50), nullable=False)
    notes: Mapped[str | None] = mapped_column(Text)
    event_data: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = created_at_column()


class Notification(SoftDeleteMixin, Base):
    __tablename__ = "notifications"
    __table_args__ = (CheckConstraint("channel IN ('push','sms','in_app')", name="channel_valid"),)

    notification_id: Mapped[uuid.UUID] = uuid_primary_key()
    user_id: Mapped[uuid.UUID] = mapped_column(
        ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False, index=True
    )
    report_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("reports.report_id", ondelete="CASCADE"), index=True
    )
    channel: Mapped[str] = mapped_column(String(20), nullable=False)
    title: Mapped[str] = mapped_column(String(150), nullable=False)
    body: Mapped[str] = mapped_column(Text, nullable=False)
    sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    read_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = created_at_column()


class AuditLog(Base):
    __tablename__ = "audit_logs"

    audit_id: Mapped[uuid.UUID] = uuid_primary_key()
    actor_user_id: Mapped[uuid.UUID | None] = mapped_column(
        ForeignKey("users.user_id", ondelete="SET NULL"), index=True
    )
    action: Mapped[str] = mapped_column(String(100), nullable=False)
    entity_type: Mapped[str] = mapped_column(String(80), nullable=False)
    entity_id: Mapped[uuid.UUID | None] = mapped_column(Uuid, index=True)
    details: Mapped[str | None] = mapped_column(Text)
    ip_address: Mapped[str | None] = mapped_column(String(45))
    created_at: Mapped[datetime] = created_at_column()
