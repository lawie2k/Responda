from sqlalchemy import CheckConstraint

from app.db.base import Base
from app.models import SmsMessage

EXPECTED_TABLES = {
    "audit_logs",
    "auth_sessions",
    "incident_types",
    "incidents",
    "notifications",
    "otp_challenges",
    "priority_assessments",
    "report_attachments",
    "report_events",
    "report_locations",
    "report_reviews",
    "report_translations",
    "reports",
    "response_assignments",
    "response_units",
    "sms_gateways",
    "sms_messages",
    "users",
}


def test_initial_schema_contains_expected_tables() -> None:
    assert SmsMessage.__tablename__ == "sms_messages"
    assert set(Base.metadata.tables) == EXPECTED_TABLES


def test_sms_schema_requires_a_valid_app_signature_before_acceptance() -> None:
    constraints = {
        constraint.name: str(constraint.sqltext)
        for constraint in Base.metadata.tables["sms_messages"].constraints
        if isinstance(constraint, CheckConstraint)
    }

    acceptance_rule = constraints["ck_sms_messages_accepted_message_is_valid_app_message"]
    report_rule = constraints["ck_sms_messages_report_requires_accepted_signature"]

    assert "signature_valid = true" in acceptance_rule
    assert "protocol_version IS NOT NULL" in acceptance_rule
    assert "client_report_id IS NOT NULL" in acceptance_rule
    assert "signature_valid = true" in report_rule


def test_app_reports_require_a_client_generated_identifier() -> None:
    constraints = {
        constraint.name: str(constraint.sqltext)
        for constraint in Base.metadata.tables["reports"].constraints
        if isinstance(constraint, CheckConstraint)
    }

    assert constraints["ck_reports_app_client_report_id_present"] == (
        "source = 'manual' OR client_report_id IS NOT NULL"
    )
