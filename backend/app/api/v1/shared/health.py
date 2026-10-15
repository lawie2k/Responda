from typing import Annotated, Literal, cast

from fastapi import APIRouter, Depends, Request, Response, status

from app.core.config import Settings
from app.db.health import DatabaseStatus, get_database_status
from app.schemas.health import HealthResponse

router = APIRouter()


@router.get(
    "/health",
    response_model=HealthResponse,
    status_code=status.HTTP_200_OK,
    summary="Check API health",
)
async def get_health(
    request: Request,
    response: Response,
    database_status: Annotated[DatabaseStatus, Depends(get_database_status)],
) -> HealthResponse:
    settings = cast(Settings, request.app.state.settings)
    application_status: Literal["ok", "degraded"] = "ok" if database_status == "ok" else "degraded"
    if database_status == "unavailable":
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    return HealthResponse(
        status=application_status,
        service=settings.app_name,
        environment=settings.environment,
        api_version=settings.api_version,
        database=database_status,
    )
