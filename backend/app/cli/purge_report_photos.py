"""Delete expired private photos. Run daily with the same configuration as the API."""

import asyncio
from datetime import UTC, datetime, timedelta

from sqlalchemy import select
from starlette.concurrency import run_in_threadpool

from app.core.config import get_settings
from app.core.exceptions import ApplicationError
from app.db.session import create_database_engine, create_session_factory
from app.models import ReportAttachment
from app.services.report_photos import private_path


async def purge() -> None:
    settings = get_settings()
    engine = create_database_engine(settings)
    removed = 0
    try:
        async with create_session_factory(engine)() as db:
            records = (
                await db.scalars(
                    select(ReportAttachment)
                    .where(
                        ReportAttachment.created_at
                        < datetime.now(UTC) - timedelta(days=settings.attachment_retention_days),
                        ReportAttachment.deleted_at.is_(None),
                    )
                    .with_for_update()
                )
            ).all()
            for record in records:
                try:
                    path = private_path(settings, record.storage_key)
                except ApplicationError:
                    continue
                await run_in_threadpool(path.unlink, missing_ok=True)
                record.deleted_at = datetime.now(UTC)
                removed += 1
            await db.commit()
    finally:
        await engine.dispose()
    print(f"Expired photos removed: {removed}")


if __name__ == "__main__":
    asyncio.run(purge())
