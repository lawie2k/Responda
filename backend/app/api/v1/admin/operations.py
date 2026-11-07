"""Authenticated spatial analysis, report corrections and staff alert receipts."""

import json
import uuid
from datetime import UTC, date, datetime, time, timedelta
from decimal import Decimal
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, Response
from pydantic import BaseModel, ConfigDict, Field, model_validator
from sqlalchemy import and_, func, select

from app.api.dependencies import CurrentAdmin, DatabaseSession, require_trusted_origin
from app.api.v1.mobile.auth import PrivateRoute
from app.core.exceptions import ApplicationError
from app.models import (
    AuditLog,
    Incident,
    IncidentType,
    Notification,
    Report,
    ReportEvent,
    ReportLocation,
    User,
)

router = APIRouter(tags=["operations"], route_class=PrivateRoute)


class Correction(BaseModel):
    model_config = ConfigDict(extra="forbid")
    expected_updated_at: datetime
    incident_type_id: uuid.UUID
    latitude: float | None = Field(default=None, ge=-90, le=90, allow_inf_nan=False)
    longitude: float | None = Field(default=None, ge=-180, le=180, allow_inf_nan=False)
    landmark: str = Field(max_length=255)
    reason: str = Field(min_length=3, max_length=1000)

    @model_validator(mode="after")
    def validate_pair(self) -> "Correction":
        if (self.latitude is None) != (self.longitude is None):
            raise ValueError("Both coordinates are required together")
        self.landmark = self.landmark.strip()
        if self.latitude is None and not self.landmark:
            raise ValueError("Provide coordinates or a location description")
        self.reason = self.reason.strip()
        if len(self.reason) < 3:
            raise ValueError("Explain the correction")
        return self


@router.patch("/reports/{report_id}/correction", dependencies=[Depends(require_trusted_origin)])
async def correct_report(
    report_id: uuid.UUID,
    payload: Correction,
    current: CurrentAdmin,
    db: DatabaseSession,
    response: Response,
) -> dict[str, str]:
    response.headers["Cache-Control"] = "no-store"
    report = await db.scalar(
        select(Report)
        .where(Report.report_id == report_id, Report.deleted_at.is_(None))
        .with_for_update()
    )
    if report is None:
        raise ApplicationError("Report not found.", code="report_not_found", status_code=404)
    if report.updated_at != payload.expected_updated_at:
        raise ApplicationError(
            "Report changed. Reload before correcting.", code="conflict", status_code=409
        )
    if report.status == "closed":
        raise ApplicationError(
            "Closed reports cannot be corrected.", code="closed_report", status_code=409
        )
    if report.incident_id and report.incident_type_id != payload.incident_type_id:
        raise ApplicationError(
            "A linked report must retain its incident category. Correct it before dispatch.",
            code="linked_category",
            status_code=409,
        )
    category = await db.scalar(
        select(IncidentType).where(
            IncidentType.incident_type_id == payload.incident_type_id,
            IncidentType.active.is_(True),
            IncidentType.deleted_at.is_(None),
        )
    )
    if category is None:
        raise ApplicationError(
            "Select an active category.", code="invalid_category", status_code=422
        )
    location = await db.scalar(
        select(ReportLocation).where(ReportLocation.report_id == report_id).with_for_update()
    )
    before = {
        "incident_type_id": str(report.incident_type_id),
        "latitude": str(location.latitude) if location else None,
        "longitude": str(location.longitude) if location else None,
    }
    if location is None:
        location = ReportLocation(
            report_id=report_id, source="manual", captured_at=datetime.now(UTC)
        )
        db.add(location)
    # Preserve original GPS evidence in protected history.
    before["captured_at"] = str(location.captured_at)
    before["deleted"] = str(location.deleted_at is not None)
    before["source"] = location.source
    before["accuracy_meters"] = str(location.accuracy_meters)
    before["landmark"] = location.landmark
    location.latitude = Decimal(str(payload.latitude)) if payload.latitude is not None else None
    location.longitude = Decimal(str(payload.longitude)) if payload.longitude is not None else None
    location.landmark = payload.landmark.strip() or None
    location.deleted_at = None
    location.captured_at = datetime.now(UTC)
    location.source = "manual"
    location.accuracy_meters = None
    report.incident_type_id = payload.incident_type_id
    report.updated_at = datetime.now(UTC)
    db.add_all(
        [
            ReportEvent(
                report_id=report_id,
                actor_user_id=current.user.user_id,
                event_type="report.corrected",
                event_data=json.dumps({"before": before, "reason": payload.reason}),
            ),
            AuditLog(
                actor_user_id=current.user.user_id,
                action="report.corrected",
                entity_type="report",
                entity_id=report_id,
                details=json.dumps({"fields": ["category", "location"]}),
            ),
        ]
    )
    await db.commit()
    return {"updated_at": report.updated_at.isoformat()}


@router.get("/spatial/heatmap")
async def heatmap(
    current: CurrentAdmin,
    db: DatabaseSession,
    response: Response,
    date_from: date,
    date_to: date,
    incident_type_id: uuid.UUID | None = None,
) -> dict[str, object]:
    del current
    response.headers["Cache-Control"] = "no-store"
    if not 0 <= (date_to - date_from).days < 366:
        raise ApplicationError("Choose at most 366 days.", code="invalid_dates", status_code=422)
    zone = ZoneInfo("Asia/Manila")
    conditions = [
        Report.deleted_at.is_(None),
        Report.verification_status == "verified",
        (
            Report.incident_id.is_(None)
            | (Incident.incident_id.is_not(None) & Incident.deleted_at.is_(None))
        ),
        IncidentType.deleted_at.is_(None),
        ReportLocation.deleted_at.is_(None),
        ReportLocation.latitude.is_not(None),
        ReportLocation.longitude.is_not(None),
        Report.received_at >= datetime.combine(date_from, time.min, zone),
        Report.received_at < datetime.combine(date_to + timedelta(days=1), time.min, zone),
    ]
    if incident_type_id:
        conditions.append(Report.incident_type_id == incident_type_id)
    # Count linked duplicate callers as one incident.
    ranked = (
        select(
            ReportLocation.latitude.label("lat"),
            ReportLocation.longitude.label("lng"),
            func.row_number()
            .over(
                partition_by=func.coalesce(Report.incident_id, Report.report_id),
                order_by=(Report.received_at, Report.report_id),
            )
            .label("rank"),
        )
        .select_from(Report)
        .join(ReportLocation, ReportLocation.report_id == Report.report_id)
        .join(IncidentType, IncidentType.incident_type_id == Report.incident_type_id)
        .outerjoin(Incident, Incident.incident_id == Report.incident_id)
        .where(*conditions)
        .subquery()
    )
    lat = func.floor(ranked.c.lat * 200) / 200
    lng = func.floor(ranked.c.lng * 200) / 200
    rows = (
        await db.execute(
            select(lat, lng, func.count())
            .where(ranked.c.rank == 1)
            .group_by(lat, lng)
            .order_by(func.count().desc())
            .limit(5001)
        )
    ).all()
    if len(rows) > 5000:
        raise ApplicationError(
            "Narrow the period or category.", code="heatmap_too_large", status_code=422
        )
    cells = [
        {
            "latitude": float(row[0]) + 0.0025,
            "longitude": float(row[1]) + 0.0025,
            "count": int(row[2]),
        }
        for row in rows
    ]
    return {"cells": cells, "total": sum(cell["count"] for cell in cells), "cell_degrees": 0.005}


class ReadAlerts(BaseModel):
    report_ids: list[uuid.UUID] = Field(min_length=1, max_length=50)


@router.get("/alerts")
async def alerts(
    current: CurrentAdmin, db: DatabaseSession, response: Response
) -> list[dict[str, object]]:
    response.headers["Cache-Control"] = "no-store"
    rows = (
        await db.execute(
            select(Report.report_id, Report.source, Report.received_at, Notification.read_at)
            .outerjoin(
                Notification,
                and_(
                    Notification.report_id == Report.report_id,
                    Notification.user_id == current.user.user_id,
                    Notification.channel == "in_app",
                    Notification.deleted_at.is_(None),
                ),
            )
            .where(
                Report.deleted_at.is_(None),
                Report.received_at >= datetime.now(UTC) - timedelta(days=7),
            )
            .order_by(Report.received_at.desc(), Report.report_id)
            .limit(50)
        )
    ).all()
    return [
        {
            "id": str(report_id),
            "title": "New emergency report",
            "detail": f"RSP-{str(report_id)[:8].upper()} · {source}",
            "time": received_at.isoformat(),
            "read": read_at is not None,
        }
        for report_id, source, received_at, read_at in rows
    ]


@router.post("/alerts/read", dependencies=[Depends(require_trusted_origin)])
async def read_alerts(
    payload: ReadAlerts, current: CurrentAdmin, db: DatabaseSession
) -> dict[str, bool]:
    # Serialize receipt inserts per staff member; a read receipt is private to that account.
    await db.scalar(select(User).where(User.user_id == current.user.user_id).with_for_update())
    reports = (
        await db.scalars(
            select(Report.report_id).where(
                Report.report_id.in_(payload.report_ids), Report.deleted_at.is_(None)
            )
        )
    ).all()
    for report_id in reports:
        receipt = await db.scalar(
            select(Notification).where(
                Notification.user_id == current.user.user_id,
                Notification.report_id == report_id,
                Notification.channel == "in_app",
                Notification.deleted_at.is_(None),
            )
        )
        if receipt is None:
            db.add(
                Notification(
                    user_id=current.user.user_id,
                    report_id=report_id,
                    channel="in_app",
                    title="Report received",
                    body="Report alert read",
                    read_at=datetime.now(UTC),
                )
            )
        else:
            receipt.read_at = datetime.now(UTC)
    await db.commit()
    return {"ok": True}
