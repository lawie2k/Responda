from typing import Annotated, cast

from fastapi import Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings
from app.core.exceptions import ApplicationError
from app.core.rate_limit import LoginRateLimiter
from app.db.session import get_database_session
from app.services.admin_auth import AdminAuthService, AuthenticatedAdmin
from app.services.admin_incidents import AdminIncidentService
from app.services.admin_reports import AdminReportService
from app.services.admin_response_units import AdminResponseUnitService

DatabaseSession = Annotated[AsyncSession, Depends(get_database_session)]


def get_settings_from_request(request: Request) -> Settings:
    return cast(Settings, request.app.state.settings)


def get_admin_login_rate_limiter(request: Request) -> LoginRateLimiter:
    return cast(LoginRateLimiter, request.app.state.admin_login_rate_limiter)


def get_admin_auth_service(
    database: DatabaseSession,
    settings: Annotated[Settings, Depends(get_settings_from_request)],
) -> AdminAuthService:
    return AdminAuthService(database, settings)


def get_admin_report_service(database: DatabaseSession) -> AdminReportService:
    return AdminReportService(database)


def get_admin_incident_service(database: DatabaseSession) -> AdminIncidentService:
    return AdminIncidentService(database)


def get_admin_response_unit_service(database: DatabaseSession) -> AdminResponseUnitService:
    return AdminResponseUnitService(database)


async def get_current_admin(
    request: Request,
    service: Annotated[AdminAuthService, Depends(get_admin_auth_service)],
    settings: Annotated[Settings, Depends(get_settings_from_request)],
) -> AuthenticatedAdmin:
    token = request.cookies.get(settings.admin_session_cookie_name)
    return await service.authenticate(token)


def require_trusted_origin(
    request: Request,
    settings: Annotated[Settings, Depends(get_settings_from_request)],
) -> None:
    origin = request.headers.get("origin")
    if origin is not None and origin not in settings.allowed_origins:
        raise ApplicationError(
            "The request origin is not allowed.",
            code="origin_not_allowed",
            status_code=403,
        )


AdminAuthServiceDependency = Annotated[AdminAuthService, Depends(get_admin_auth_service)]
AdminIncidentServiceDependency = Annotated[
    AdminIncidentService, Depends(get_admin_incident_service)
]
AdminReportServiceDependency = Annotated[AdminReportService, Depends(get_admin_report_service)]
AdminResponseUnitServiceDependency = Annotated[
    AdminResponseUnitService, Depends(get_admin_response_unit_service)
]
CurrentAdmin = Annotated[AuthenticatedAdmin, Depends(get_current_admin)]
SettingsDependency = Annotated[Settings, Depends(get_settings_from_request)]
LoginRateLimiterDependency = Annotated[LoginRateLimiter, Depends(get_admin_login_rate_limiter)]
TrustedOrigin = Annotated[None, Depends(require_trusted_origin)]
