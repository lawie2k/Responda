"""Add revocable SMS installation credentials and receipt fingerprints."""

import sqlalchemy as sa
from alembic import op

revision = "d5f08c72a931"
down_revision = "a19e7215d104"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "sms_devices",
        sa.Column(
            "device_id", sa.Uuid(), primary_key=True, server_default=sa.text("gen_random_uuid()")
        ),
        sa.Column(
            "user_id",
            sa.Uuid(),
            sa.ForeignKey("users.user_id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("CURRENT_TIMESTAMP"),
        ),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True)),
    )
    op.create_index("ix_sms_devices_user_id", "sms_devices", ["user_id"])
    op.add_column("sms_messages", sa.Column("device_id", sa.Uuid()))
    op.add_column("sms_messages", sa.Column("payload_sha256", sa.String(64)))
    op.create_foreign_key(
        "fk_sms_messages_device_id_sms_devices",
        "sms_messages",
        "sms_devices",
        ["device_id"],
        ["device_id"],
        ondelete="RESTRICT",
    )
    op.create_index("ix_sms_messages_device_id", "sms_messages", ["device_id"])


def downgrade() -> None:
    op.drop_index("ix_sms_messages_device_id", table_name="sms_messages")
    op.drop_constraint("fk_sms_messages_device_id_sms_devices", "sms_messages", type_="foreignkey")
    op.drop_column("sms_messages", "payload_sha256")
    op.drop_column("sms_messages", "device_id")
    op.drop_index("ix_sms_devices_user_id", table_name="sms_devices")
    op.drop_table("sms_devices")
