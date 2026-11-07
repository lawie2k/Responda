import asyncio
import io
import uuid
from datetime import UTC, date, datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi import Response
from PIL import Image
from pydantic import ValidationError
from sqlalchemy.dialects import postgresql

from app.api.v1.admin.operations import Correction, correct_report, heatmap
from app.core.config import Settings
from app.core.exceptions import ApplicationError
from app.models import AuditLog, IncidentType, Report, ReportEvent, ReportLocation
from app.services.report_photos import normalize_photo, private_path, save_photo


def record() -> Report:
    return Report(
        report_id=uuid.uuid4(),
        incident_type_id=uuid.uuid4(),
        status="under_review",
        verification_status="verified",
        updated_at=datetime.now(UTC),
    )


def actor() -> SimpleNamespace:
    return SimpleNamespace(user=SimpleNamespace(user_id=uuid.uuid4()))


def payload(report: Report, **changes: object) -> Correction:
    return Correction.model_validate(
        {
            "expected_updated_at": report.updated_at,
            "incident_type_id": report.incident_type_id,
            "latitude": 7.1,
            "longitude": 125.9,
            "landmark": "Test location",
            "reason": "Confirmed with reporter",
            **changes,
        }
    )


def test_correction_is_atomic_and_preserves_original_evidence() -> None:
    report = record()
    location = ReportLocation(latitude=7, longitude=125, landmark="Old", source="gps")
    db = MagicMock(
        scalar=AsyncMock(side_effect=[report, IncidentType(), location]), commit=AsyncMock()
    )
    asyncio.run(correct_report(report.report_id, payload(report), actor(), db, Response()))
    assert float(location.latitude) == 7.1
    assert location.source == "manual"
    rows = db.add_all.call_args.args[0]
    event = next(row for row in rows if isinstance(row, ReportEvent))
    audit = next(row for row in rows if isinstance(row, AuditLog))
    assert '"latitude": "7"' in event.event_data
    assert "Confirmed with reporter" in event.event_data
    assert "Confirmed with reporter" not in audit.details
    db.commit.assert_awaited_once()


@pytest.mark.parametrize("mode", ["missing", "stale", "linked"])
def test_correction_rejects_missing_stale_or_inconsistent_linked_category(mode: str) -> None:
    report = record()
    correction = payload(report)
    if mode == "linked":
        report.incident_id = uuid.uuid4()
        correction.incident_type_id = uuid.uuid4()
    if mode == "stale":
        report.updated_at = datetime(2020, 1, 1, tzinfo=UTC)
    db = MagicMock(
        scalar=AsyncMock(return_value=None if mode == "missing" else report), commit=AsyncMock()
    )
    with pytest.raises(ApplicationError):
        asyncio.run(correct_report(report.report_id, correction, actor(), db, Response()))
    db.commit.assert_not_awaited()


def test_correction_requires_pair_of_finite_coordinates_and_reason() -> None:
    with pytest.raises(ValidationError):
        payload(record(), longitude=None)
    with pytest.raises(ValidationError):
        payload(record(), latitude=float("nan"))
    with pytest.raises(ValidationError):
        payload(record(), reason="   ")
    with pytest.raises(ValidationError):
        payload(record(), latitude=None, longitude=None, landmark="   ")
    with pytest.raises(ValidationError):
        payload(record(), landmark="a" * 256)


def test_heatmap_counts_sql_ranked_incidents_and_bounds_date_range() -> None:
    result = MagicMock()
    result.all.return_value = [(7.1, 125.9, 4)]
    db = MagicMock(execute=AsyncMock(return_value=result))
    data = asyncio.run(heatmap(actor(), db, Response(), date(2026, 1, 1), date(2026, 1, 31)))
    assert data["total"] == 4
    sql = str(db.execute.call_args.args[0].compile(dialect=postgresql.dialect()))
    assert "row_number() OVER" in sql and "coalesce(reports.incident_id, reports.report_id)" in sql
    assert "description_original" not in sql
    with pytest.raises(ApplicationError):
        asyncio.run(heatmap(actor(), db, Response(), date(2020, 1, 1), date(2026, 1, 31)))


def test_photo_is_decoded_reencoded_and_has_no_exif() -> None:
    image = Image.new("RGB", (30, 30), "red")
    exif = image.getexif()
    exif[270] = "private metadata"
    stream = io.BytesIO()
    image.save(stream, format="JPEG", exif=exif)
    clean = normalize_photo(stream.getvalue())
    with Image.open(io.BytesIO(clean)) as saved:
        assert saved.format == "JPEG"
        assert not saved.getexif()
    with pytest.raises(ApplicationError):
        normalize_photo(b"<svg>not an image</svg>")
    with pytest.raises(ApplicationError):
        private_path(Settings(_env_file=None), "../../secret")


def test_photo_requires_report_ownership_before_decoding() -> None:
    db = MagicMock(scalar=AsyncMock(return_value=None), commit=AsyncMock())
    with pytest.raises(ApplicationError) as error:
        asyncio.run(
            save_photo(db, Settings(_env_file=None), uuid.uuid4(), uuid.uuid4(), b"invalid")
        )
    assert error.value.status_code == 404
    db.commit.assert_not_awaited()


def test_operations_reject_unauthenticated_requests() -> None:
    from fastapi.testclient import TestClient

    from app.api.dependencies import get_admin_auth_service
    from app.core.config import Environment
    from app.main import create_app

    class RejectAuth:
        async def authenticate(self, token: str | None) -> None:
            raise ApplicationError("Sign in required", code="invalid_session", status_code=401)

    app = create_app(Settings(environment=Environment.TESTING, debug=False, _env_file=None))
    app.dependency_overrides[get_admin_auth_service] = lambda: RejectAuth()
    with TestClient(app) as client:
        for url in [
            "/api/v1/admin/alerts",
            "/api/v1/admin/spatial/heatmap?date_from=2026-01-01&date_to=2026-01-31",
            f"/api/v1/admin/reports/{uuid.uuid4()}/attachments/{uuid.uuid4()}",
        ]:
            assert client.get(url).status_code == 401


def test_alert_receipts_are_per_account_and_skip_unknown_reports() -> None:
    from app.api.v1.admin.operations import ReadAlerts, read_alerts
    from app.models import Notification

    report_id = uuid.uuid4()
    current = actor()
    known = MagicMock()
    known.all.return_value = [report_id]
    db = MagicMock(
        scalar=AsyncMock(side_effect=[object(), None]),
        scalars=AsyncMock(return_value=known),
        commit=AsyncMock(),
    )
    asyncio.run(read_alerts(ReadAlerts(report_ids=[report_id, uuid.uuid4()]), current, db))
    receipt = db.add.call_args.args[0]
    assert isinstance(receipt, Notification)
    assert receipt.user_id == current.user.user_id
    assert receipt.report_id == report_id and receipt.read_at is not None
    db.commit.assert_awaited_once()
