"""Record responder arrival while keeping the incident operationally responding."""

import sqlalchemy as sa
from alembic import op

revision = "f710b9c82e11"
down_revision = "d5f08c72a931"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("response_assignments", sa.Column("on_site_at", sa.DateTime(timezone=True)))
    op.drop_constraint(
        op.f("ck_response_assignments_status_valid"), "response_assignments", type_="check"
    )
    op.create_check_constraint(
        "status_valid",
        "response_assignments",
        "status IN ('assigned','acknowledged','responding','on_site','completed','cancelled')",
    )
    op.drop_index("uq_response_assignments_unit_active", table_name="response_assignments")
    op.create_index(
        "uq_response_assignments_unit_active",
        "response_assignments",
        ["unit_id"],
        unique=True,
        postgresql_where=sa.text(
            "deleted_at IS NULL AND status IN ('assigned','acknowledged','responding','on_site')"
        ),
    )


def downgrade() -> None:
    op.execute("UPDATE response_assignments SET status='responding' WHERE status='on_site'")
    op.drop_index("uq_response_assignments_unit_active", table_name="response_assignments")
    op.create_index(
        "uq_response_assignments_unit_active",
        "response_assignments",
        ["unit_id"],
        unique=True,
        postgresql_where=sa.text(
            "deleted_at IS NULL AND status IN ('assigned','acknowledged','responding')"
        ),
    )
    op.drop_constraint(
        op.f("ck_response_assignments_status_valid"), "response_assignments", type_="check"
    )
    op.create_check_constraint(
        "status_valid",
        "response_assignments",
        "status IN ('assigned','acknowledged','responding','completed','cancelled')",
    )
    op.drop_column("response_assignments", "on_site_at")
