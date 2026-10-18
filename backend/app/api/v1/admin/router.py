from fastapi import APIRouter

from app.api.v1.admin.analytics import router as analytics_router
from app.api.v1.admin.assignments import router as assignments_router
from app.api.v1.admin.auth import router as auth_router
from app.api.v1.admin.history import router as history_router
from app.api.v1.admin.incidents import router as incidents_router
from app.api.v1.admin.mobile_accounts import router as mobile_accounts_router
from app.api.v1.admin.reports import router as reports_router
from app.api.v1.admin.response_units import router as response_units_router
from app.api.v1.admin.staff import router as staff_router

router = APIRouter(prefix="/admin", tags=["admin"])
router.include_router(analytics_router)
router.include_router(assignments_router)
router.include_router(auth_router)
router.include_router(history_router)
router.include_router(incidents_router)
router.include_router(mobile_accounts_router)
router.include_router(reports_router)
router.include_router(response_units_router)
router.include_router(staff_router)
