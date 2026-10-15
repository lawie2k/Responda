import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from typing import cast

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncEngine

from app.api.v1.router import api_router
from app.core.config import Settings, get_settings
from app.core.exceptions import ApplicationError
from app.core.rate_limit import LoginRateLimiter
from app.db.session import create_database_engine, create_session_factory

logger = logging.getLogger(__name__)


def create_app(settings: Settings | None = None) -> FastAPI:
    current_settings = settings or get_settings()
    database_engine = create_database_engine(current_settings)

    @asynccontextmanager
    async def lifespan(application: FastAPI) -> AsyncIterator[None]:
        yield
        engine = cast(AsyncEngine, application.state.database_engine)
        await engine.dispose()

    application = FastAPI(
        title=current_settings.app_name,
        version=current_settings.api_version,
        debug=current_settings.debug,
        lifespan=lifespan,
    )
    application.state.settings = current_settings
    application.state.database_engine = database_engine
    application.state.database_session_factory = create_session_factory(database_engine)
    application.state.admin_login_rate_limiter = LoginRateLimiter(
        max_attempts=current_settings.admin_login_rate_limit_attempts,
        window_seconds=current_settings.admin_login_rate_limit_window_seconds,
        secret_key=current_settings.secret_key.get_secret_value(),
    )
    application.add_middleware(
        CORSMiddleware,
        allow_origins=current_settings.allowed_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    application.include_router(api_router, prefix=current_settings.api_v1_prefix)

    @application.exception_handler(ApplicationError)
    async def handle_application_error(request: Request, error: ApplicationError) -> JSONResponse:
        del request
        payload: dict[str, object] = {
            "error": {
                "code": error.code,
                "message": error.message,
            }
        }
        if error.details is not None:
            error_payload = payload["error"]
            if isinstance(error_payload, dict):
                error_payload["details"] = error.details
        return JSONResponse(
            status_code=error.status_code,
            content=payload,
            headers=error.headers,
        )

    @application.exception_handler(Exception)
    async def handle_unexpected_error(request: Request, error: Exception) -> JSONResponse:
        logger.error(
            "Unhandled error while processing %s %s",
            request.method,
            request.url.path,
            exc_info=(type(error), error, error.__traceback__),
        )
        return JSONResponse(
            status_code=500,
            content={
                "error": {
                    "code": "internal_server_error",
                    "message": "An unexpected error occurred.",
                }
            },
        )

    return application


app = create_app()
