import uuid
from datetime import date
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Query, Response

from app.api.dependencies import AdminHistoryServiceDependency, CurrentAdmin
from app.core.exceptions import ApplicationError
from app.models.enums import ADMINISTRATOR_ROLES
from app.schemas.admin_history import (
    HistoricalIncidentDetail,
    HistoricalIncidentList,
    HistoricalStatus,
)
from app.schemas.admin_reports import AdminIncidentTypeListResponse, PriorityValue
from app.services.admin_auth import AuthenticatedAdmin
from app.services.admin_history import HistoryFilters

router = APIRouter(prefix="/history")


def history_filters(
    search: Annotated[str | None, Query(min_length=1, max_length=100)] = None,
    status: HistoricalStatus | None = None,
    priority: PriorityValue | None = None,
    incident_type_id: uuid.UUID | None = None,
    date_from: Annotated[date | None, Query(ge=date(1900, 1, 1), lt=date.max)] = None,
    date_to: Annotated[date | None, Query(ge=date(1900, 1, 1), lt=date.max)] = None,
    sort: Literal["newest", "oldest"] = "newest",
) -> HistoryFilters:
    if date_from and date_to and date_from > date_to:
        raise ApplicationError(
            "The start date must be on or before the end date.",
            code="invalid_history_date_range",
            status_code=422,
        )
    return HistoryFilters(
        search=search,
        status=status,
        priority=priority,
        incident_type_id=incident_type_id,
        date_from=date_from,
        date_to=date_to,
        sort=sort,
    )


def _prepare(response: Response, current: AuthenticatedAdmin) -> None:
    response.headers["Cache-Control"] = "no-store, max-age=0"
    response.headers["Pragma"] = "no-cache"
    if current.user.role not in ADMINISTRATOR_ROLES:
        raise ApplicationError(
            "This staff account cannot read historical incidents.",
            code="history_access_forbidden",
            status_code=403,
        )


@router.get("", response_model=HistoricalIncidentList)
async def list_history(
    response: Response,
    current: CurrentAdmin,
    service: AdminHistoryServiceDependency,
    filters: Annotated[HistoryFilters, Depends(history_filters)],
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 10,
) -> HistoricalIncidentList:
    _prepare(response, current)
    return await service.list_records(filters, page=page, page_size=page_size)


@router.get("/export", response_class=Response)
async def export_history(
    current: CurrentAdmin,
    service: AdminHistoryServiceDependency,
    filters: Annotated[HistoryFilters, Depends(history_filters)],
) -> Response:
    response = Response(media_type="text/csv; charset=utf-8")
    _prepare(response, current)
    contents = await service.export_records(filters, staff_id=current.user.user_id)
    response.body = contents.encode("utf-8")
    response.headers["Content-Length"] = str(len(response.body))
    response.headers["Content-Disposition"] = 'attachment; filename="responda-history.csv"'
    response.headers["X-Content-Type-Options"] = "nosniff"
    return response


@router.get("/incident-types", response_model=AdminIncidentTypeListResponse)
async def history_incident_types(
    response: Response,
    current: CurrentAdmin,
    service: AdminHistoryServiceDependency,
) -> AdminIncidentTypeListResponse:
    _prepare(response, current)
    return await service.list_incident_types()


@router.get("/{incident_id}", response_model=HistoricalIncidentDetail)
async def get_history(
    incident_id: uuid.UUID,
    response: Response,
    current: CurrentAdmin,
    service: AdminHistoryServiceDependency,
    report_page: Annotated[int, Query(ge=1)] = 1,
    assignment_page: Annotated[int, Query(ge=1)] = 1,
    event_page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 10,
) -> HistoricalIncidentDetail:
    _prepare(response, current)
    return await service.get_record(
        incident_id,
        report_page=report_page,
        assignment_page=assignment_page,
        event_page=event_page,
        page_size=page_size,
    )
