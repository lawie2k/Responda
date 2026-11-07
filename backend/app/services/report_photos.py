"""Private, bounded photo storage. No public attachment URLs or original EXIF."""

import hashlib
import io
import os
import uuid
import warnings
from datetime import UTC, datetime, timedelta
from pathlib import Path

from PIL import Image, ImageOps, UnidentifiedImageError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.concurrency import run_in_threadpool

from app.core.config import Settings
from app.core.exceptions import ApplicationError
from app.models import AuditLog, Report, ReportAttachment

MAX_PHOTO_BYTES = 5 * 1024 * 1024


def normalize_photo(raw: bytes) -> bytes:
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("error", Image.DecompressionBombWarning)
            with Image.open(io.BytesIO(raw), formats=["JPEG", "PNG"]) as image:
                if image.width * image.height > 20_000_000 or getattr(image, "n_frames", 1) != 1:
                    raise ValueError("Photo dimensions too large")
                image.load()
                clean = ImageOps.exif_transpose(image).convert("RGB")
                clean.info.clear()
                clean.thumbnail((2400, 2400))
                output = io.BytesIO()
                clean.save(output, format="JPEG", quality=85)
                return output.getvalue()
    except (
        UnidentifiedImageError,
        OSError,
        ValueError,
        Image.DecompressionBombError,
        Image.DecompressionBombWarning,
    ) as error:
        raise ApplicationError(
            "Use a valid JPEG or PNG photo up to 20 megapixels.",
            code="invalid_photo",
            status_code=422,
        ) from error


def private_path(settings: Settings, key: str) -> Path:
    # Keys are server-generated UUIDs only; reject legacy external/untrusted paths.
    try:
        parsed = uuid.UUID(key)
    except ValueError:
        raise ApplicationError(
            "Photo unavailable.", code="photo_not_found", status_code=404
        ) from None
    return Path(settings.attachment_storage_dir).resolve() / f"{parsed}.jpg"


async def save_photo(
    db: AsyncSession, settings: Settings, report_id: uuid.UUID, reporter_id: uuid.UUID, raw: bytes
) -> dict[str, str]:
    report = await db.scalar(
        select(Report)
        .where(
            Report.report_id == report_id,
            Report.reporter_id == reporter_id,
            Report.deleted_at.is_(None),
        )
        .with_for_update()
    )
    if report is None:
        raise ApplicationError("Report not found.", code="report_not_found", status_code=404)
    if report.status == "closed":
        raise ApplicationError("This report is closed.", code="closed_report", status_code=409)
    clean = await run_in_threadpool(normalize_photo, raw)
    digest = hashlib.sha256(clean).hexdigest()
    existing = (
        await db.scalars(
            select(ReportAttachment).where(
                ReportAttachment.report_id == report_id, ReportAttachment.deleted_at.is_(None)
            )
        )
    ).all()
    for item in existing:
        if item.checksum_sha256 == digest:
            return {"attachment_id": str(item.attachment_id)}
    if len(existing) >= 3:
        raise ApplicationError(
            "A report can have up to three photos.", code="photo_limit", status_code=409
        )
    key = str(uuid.uuid4())
    path = private_path(settings, key)

    def write() -> None:
        path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, "wb") as file:
            file.write(clean)

    await run_in_threadpool(write)
    attachment_id = uuid.uuid4()
    try:
        db.add_all(
            [
                ReportAttachment(
                    attachment_id=attachment_id,
                    report_id=report_id,
                    media_type="image",
                    storage_key=key,
                    content_type="image/jpeg",
                    size_bytes=len(clean),
                    checksum_sha256=digest,
                ),
                AuditLog(
                    actor_user_id=reporter_id,
                    action="report.photo.uploaded",
                    entity_type="report",
                    entity_id=report_id,
                    details=None,
                ),
            ]
        )
        await db.commit()
    except Exception:
        await run_in_threadpool(path.unlink, missing_ok=True)
        raise
    return {"attachment_id": str(attachment_id)}


async def read_photo(
    db: AsyncSession, settings: Settings, report_id: uuid.UUID, attachment_id: uuid.UUID
) -> bytes:
    attachment = await db.scalar(
        select(ReportAttachment)
        .join(Report)
        .where(
            ReportAttachment.attachment_id == attachment_id,
            ReportAttachment.report_id == report_id,
            ReportAttachment.deleted_at.is_(None),
            Report.deleted_at.is_(None),
            ReportAttachment.created_at
            >= datetime.now(UTC) - timedelta(days=settings.attachment_retention_days),
        )
    )
    if attachment is None:
        raise ApplicationError(
            "Photo unavailable or expired.", code="photo_not_found", status_code=404
        )
    try:
        return await run_in_threadpool(private_path(settings, attachment.storage_key).read_bytes)
    except OSError:
        raise ApplicationError(
            "Photo unavailable.", code="photo_not_found", status_code=404
        ) from None
