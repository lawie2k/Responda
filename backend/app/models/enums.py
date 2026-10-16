from enum import StrEnum


class UserRole(StrEnum):
    REPORTER = "reporter"
    ADMIN = "admin"
    OPERATIONS_ADMIN = "operations_admin"
    DISPATCHER = "dispatcher"
    VERIFIER = "verifier"
    VIEWER = "viewer"


ADMINISTRATOR_ROLES = frozenset(
    {
        UserRole.ADMIN.value,
        UserRole.OPERATIONS_ADMIN.value,
    }
)


class Priority(StrEnum):
    CRITICAL = "critical"
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"


class ReportSource(StrEnum):
    APP_API = "app_api"
    APP_SMS = "app_sms"
    MANUAL = "manual"


class VerificationStatus(StrEnum):
    PENDING = "pending"
    VERIFIED = "verified"
    UNVERIFIED = "unverified"
    INVALID = "invalid"


class ReportStatus(StrEnum):
    NEW = "new"
    UNDER_REVIEW = "under_review"
    LINKED = "linked"
    CLOSED = "closed"


class IncidentStatus(StrEnum):
    OPEN = "open"
    DISPATCHED = "dispatched"
    RESPONDING = "responding"
    RESOLVED = "resolved"
    CLOSED = "closed"


class SmsParseStatus(StrEnum):
    RECEIVED = "received"
    ACCEPTED = "accepted"
    REJECTED = "rejected"
    DUPLICATE = "duplicate"
    ERROR = "error"


class AssignmentStatus(StrEnum):
    ASSIGNED = "assigned"
    ACKNOWLEDGED = "acknowledged"
    RESPONDING = "responding"
    COMPLETED = "completed"
    CANCELLED = "cancelled"
