from fastapi import APIRouter

from app.api.v1.mobile.auth import router as auth_router
from app.api.v1.mobile.reports import router as reports_router

router = APIRouter(prefix="/mobile", tags=["mobile"])
router.include_router(auth_router)
router.include_router(reports_router)
