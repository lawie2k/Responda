"""add operations admin role

Revision ID: c821741a4d27
Revises: 9f4d1c2b7a10
Create Date: 2026-10-16 00:00:00.000000
"""

from collections.abc import Sequence

from alembic import op

revision: str = "c821741a4d27"
down_revision: str | None = "9f4d1c2b7a10"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.drop_constraint(op.f("ck_users_role_valid"), "users", type_="check")
    op.create_check_constraint(
        op.f("ck_users_role_valid"),
        "users",
        "role IN ('reporter','admin','operations_admin','dispatcher','verifier','viewer')",
    )


def downgrade() -> None:
    op.execute("UPDATE users SET role = 'admin' WHERE role = 'operations_admin'")
    op.drop_constraint(op.f("ck_users_role_valid"), "users", type_="check")
    op.create_check_constraint(
        op.f("ck_users_role_valid"),
        "users",
        "role IN ('reporter','admin','dispatcher','verifier','viewer')",
    )
