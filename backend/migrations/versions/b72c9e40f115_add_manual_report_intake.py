"""add manual report intake

Revision ID: b72c9e40f115
Revises: e61f0a9c3b42
Create Date: 2026-10-16 00:00:00.000000
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "b72c9e40f115"
down_revision: str | None = "e61f0a9c3b42"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("reports", sa.Column("manual_intake_channel", sa.String(30), nullable=True))
    op.add_column(
        "reports",
        sa.Column(
            "additional_assistance",
            sa.Boolean(),
            server_default=sa.text("false"),
            nullable=False,
        ),
    )
    op.create_check_constraint(
        "manual_intake_channel_valid",
        "reports",
        "manual_intake_channel IS NULL OR manual_intake_channel IN "
        "('phone_call','walk_in','radio_communication','other_offline')",
    )
    op.create_check_constraint(
        "manual_intake_channel_source_valid",
        "reports",
        "source = 'manual' OR manual_intake_channel IS NULL",
    )
    op.alter_column("report_locations", "latitude", existing_type=sa.Numeric(9, 6), nullable=True)
    op.alter_column("report_locations", "longitude", existing_type=sa.Numeric(9, 6), nullable=True)
    op.create_check_constraint(
        "coordinates_pair_valid",
        "report_locations",
        "(latitude IS NULL AND longitude IS NULL) OR "
        "(latitude IS NOT NULL AND longitude IS NOT NULL)",
    )
    op.create_check_constraint(
        "location_details_present",
        "report_locations",
        "latitude IS NOT NULL OR landmark IS NOT NULL",
    )

    incident_types = sa.table(
        "incident_types",
        sa.column("code", sa.String),
        sa.column("name", sa.String),
        sa.column("description", sa.Text),
        sa.column("default_priority", sa.String),
        sa.column("active", sa.Boolean),
        sa.column("icon_key", sa.String),
    )
    op.bulk_insert(
        incident_types,
        [
            {
                "code": "road_accident",
                "name": "Road Accident",
                "description": "Road crashes and transport-related emergencies.",
                "default_priority": "high",
                "active": True,
                "icon_key": "road-accident",
            },
            {
                "code": "flood",
                "name": "Flood",
                "description": "Flooding, rising water, and water-rescue emergencies.",
                "default_priority": "high",
                "active": True,
                "icon_key": "flood",
            },
            {
                "code": "fire",
                "name": "Fire",
                "description": "Structural, vehicle, and outdoor fire emergencies.",
                "default_priority": "critical",
                "active": True,
                "icon_key": "fire",
            },
            {
                "code": "drowning",
                "name": "Drowning",
                "description": "Drowning and water-related rescue emergencies.",
                "default_priority": "critical",
                "active": True,
                "icon_key": "drowning",
            },
            {
                "code": "medical_emergency",
                "name": "Medical Emergency",
                "description": "Urgent illness, injury, and medical assistance requests.",
                "default_priority": "critical",
                "active": True,
                "icon_key": "medical",
            },
            {
                "code": "other",
                "name": "Other Disaster-Related Incident",
                "description": "Other emergencies requiring MDRRMO assessment.",
                "default_priority": "medium",
                "active": True,
                "icon_key": "other",
            },
        ],
    )


def downgrade() -> None:
    op.execute(
        sa.text(
            "DELETE FROM incident_types WHERE code IN "
            "('road_accident','flood','fire','drowning','medical_emergency','other')"
        )
    )
    op.drop_constraint(
        "ck_report_locations_location_details_present", "report_locations", type_="check"
    )
    op.drop_constraint(
        "ck_report_locations_coordinates_pair_valid", "report_locations", type_="check"
    )
    op.alter_column("report_locations", "longitude", existing_type=sa.Numeric(9, 6), nullable=False)
    op.alter_column("report_locations", "latitude", existing_type=sa.Numeric(9, 6), nullable=False)
    op.drop_constraint("ck_reports_manual_intake_channel_source_valid", "reports", type_="check")
    op.drop_constraint("ck_reports_manual_intake_channel_valid", "reports", type_="check")
    op.drop_column("reports", "additional_assistance")
    op.drop_column("reports", "manual_intake_channel")
