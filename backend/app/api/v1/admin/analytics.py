import uuid
from datetime import date, datetime, timedelta
from typing import Annotated
from zoneinfo import ZoneInfo

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import select

from app.api.dependencies import AdminAnalyticsServiceDependency, CurrentAdmin, DatabaseSession
from app.core.exceptions import ApplicationError
from app.models import IncidentType
from app.models.enums import ADMINISTRATOR_ROLES
from app.schemas.admin_analytics import AdminAnalytics
from app.schemas.admin_reports import AdminIncidentTypeListResponse, IncidentTypeSummary
from app.services.admin_analytics import AnalyticsFilters
from app.services.admin_auth import AuthenticatedAdmin

router = APIRouter(prefix="/analytics")


def analytics_filters(
    date_from: Annotated[date | None, Query(ge=date(1900, 1, 1), lt=date.max)] = None,
    date_to: Annotated[date | None, Query(ge=date(1900, 1, 1), lt=date.max)] = None,
    incident_type_id: uuid.UUID | None = None,
) -> AnalyticsFilters:
    end = date_to or datetime.now(ZoneInfo("Asia/Manila")).date()
    start = date_from or max(date(1900, 1, 1), end - timedelta(days=29))
    if start > end or (end - start).days >= 366:
        raise ApplicationError(
            "Choose a start date on or before the end date, within a 366-day range.",
            code="invalid_analytics_date_range",
            status_code=422,
        )
    return AnalyticsFilters(date_from=start, date_to=end, incident_type_id=incident_type_id)


def _prepare(response: Response, current: AuthenticatedAdmin) -> None:
    response.headers["Cache-Control"] = "no-store, max-age=0"
    response.headers["Pragma"] = "no-cache"
    if current.user.role not in ADMINISTRATOR_ROLES:
        raise ApplicationError(
            "This staff account cannot read analytics.",
            code="analytics_access_forbidden",
            status_code=403,
        )


@router.get("", response_model=AdminAnalytics)
async def get_analytics(
    response: Response,
    current: CurrentAdmin,
    service: AdminAnalyticsServiceDependency,
    filters: Annotated[AnalyticsFilters, Depends(analytics_filters)],
) -> AdminAnalytics:
    _prepare(response, current)
    return await service.get_analytics(filters)


@router.get("/export", response_class=Response)
async def export_analytics(
    current: CurrentAdmin,
    service: AdminAnalyticsServiceDependency,
    filters: Annotated[AnalyticsFilters, Depends(analytics_filters)],
) -> Response:
    response = Response(media_type="text/csv; charset=utf-8")
    _prepare(response, current)
    contents = await service.export_analytics(filters, staff_id=current.user.user_id)
    response.body = contents.encode("utf-8")
    response.headers["Content-Length"] = str(len(response.body))
    response.headers["Content-Disposition"] = 'attachment; filename="responda-analytics.csv"'
    response.headers["X-Content-Type-Options"] = "nosniff"
    return response


@router.get("/incident-types", response_model=AdminIncidentTypeListResponse)
async def analytics_types(
    response: Response,
    current: CurrentAdmin,
    database: DatabaseSession,
) -> AdminIncidentTypeListResponse:
    _prepare(response, current)
    kinds = (
        await database.scalars(
            select(IncidentType)
            .where(IncidentType.deleted_at.is_(None))
            .order_by(IncidentType.name)
        )
    ).all()
    return AdminIncidentTypeListResponse(
        items=[
            IncidentTypeSummary(
                incident_type_id=kind.incident_type_id, code=kind.code, name=kind.name
            )
            for kind in kinds
        ]
    )
