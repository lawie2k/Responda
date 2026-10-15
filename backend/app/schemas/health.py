from typing import Literal

from pydantic import BaseModel

from app.core.config import Environment


class HealthResponse(BaseModel):
    status: Literal["ok", "degraded"]
    service: str
    environment: Environment
    api_version: str
    database: Literal["ok", "unavailable"]
