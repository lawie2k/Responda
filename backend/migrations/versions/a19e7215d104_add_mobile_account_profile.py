"""Add optional mobile account details and privacy acknowledgement.

Revision ID: a19e7215d104
Revises: b72c9e40f115
"""

import sqlalchemy as sa
from alembic import op

revision = "a19e7215d104"
down_revision = "b72c9e40f115"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("barangay", sa.String(100), nullable=True))
    op.add_column(
        "users", sa.Column("privacy_notice_accepted_at", sa.DateTime(timezone=True), nullable=True)
    )


def downgrade() -> None:
    op.drop_column("users", "privacy_notice_accepted_at")
    op.drop_column("users", "barangay")
