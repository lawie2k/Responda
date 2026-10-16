"""add response assignment lifecycle

Revision ID: e61f0a9c3b42
Revises: c821741a4d27
Create Date: 2026-10-16 00:00:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "e61f0a9c3b42"
down_revision: str | None = "c821741a4d27"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column(
        "response_assignments",
        sa.Column("responding_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "response_assignments",
        sa.Column("cancelled_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "response_assignments",
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
    )
    op.create_index(
        "uq_response_assignments_unit_active",
        "response_assignments",
        ["unit_id"],
        unique=True,
        postgresql_where=sa.text(
            "deleted_at IS NULL AND status IN ('assigned','acknowledged','responding')"
        ),
    )


def downgrade() -> None:
    op.drop_index(
        "uq_response_assignments_unit_active",
        table_name="response_assignments",
        postgresql_where=sa.text(
            "deleted_at IS NULL AND status IN ('assigned','acknowledged','responding')"
        ),
    )
    op.drop_column("response_assignments", "updated_at")
    op.drop_column("response_assignments", "cancelled_at")
    op.drop_column("response_assignments", "responding_at")
