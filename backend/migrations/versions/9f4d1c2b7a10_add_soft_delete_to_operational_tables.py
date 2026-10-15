"""add soft delete to operational tables

Revision ID: 9f4d1c2b7a10
Revises: 628589cc232c
Create Date: 2026-10-16 00:00:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "9f4d1c2b7a10"
down_revision: str | None = "628589cc232c"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

SOFT_DELETE_TABLES = (
    "users",
    "incident_types",
    "incidents",
    "reports",
    "report_locations",
    "report_attachments",
    "sms_gateways",
    "sms_messages",
    "response_units",
    "response_assignments",
    "notifications",
)


def upgrade() -> None:
    for table_name in SOFT_DELETE_TABLES:
        op.add_column(
            table_name,
            sa.Column("deleted_at", sa.DateTime(timezone=True), nullable=True),
        )
        op.create_index(
            op.f(f"ix_{table_name}_deleted_at"),
            table_name,
            ["deleted_at"],
            unique=False,
        )


def downgrade() -> None:
    for table_name in reversed(SOFT_DELETE_TABLES):
        op.drop_index(op.f(f"ix_{table_name}_deleted_at"), table_name=table_name)
        op.drop_column(table_name, "deleted_at")
