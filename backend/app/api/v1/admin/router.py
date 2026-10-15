from fastapi import APIRouter

from app.api.v1.admin.auth import router as auth_router
from app.api.v1.admin.incidents import router as incidents_router
from app.api.v1.admin.reports import router as reports_router

router = APIRouter(prefix="/admin", tags=["admin"])
router.include_router(auth_router)
router.include_router(incidents_router)
router.include_router(reports_router)
