import logging
from typing import Literal

from fastapi import Request
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from app.db.session import get_database_engine

logger = logging.getLogger(__name__)

DatabaseStatus = Literal["ok", "unavailable"]


async def get_database_status(request: Request) -> DatabaseStatus:
    engine = get_database_engine(request)
    try:
        async with engine.connect() as connection:
            await connection.execute(text("SELECT 1"))
    except SQLAlchemyError as error:
        logger.warning("Database health check failed: %s", type(error).__name__)
        return "unavailable"
    return "ok"
