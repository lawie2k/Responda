import uuid
from datetime import date, datetime

from pydantic import BaseModel, Field


class AnalyticsCount(BaseModel):
    key: str
    label: str
    count: int = Field(ge=0)


class AnalyticsDay(BaseModel):
    date: date
    reports: int = Field(default=0, ge=0)
    verified_reports: int = Field(default=0, ge=0)
    incidents: int = Field(default=0, ge=0)


class AnalyticsType(BaseModel):
    incident_type_id: uuid.UUID
    name: str
    reports: int = Field(default=0, ge=0)
    incidents: int = Field(default=0, ge=0)


class AnalyticsSummary(BaseModel):
    reports: int = Field(ge=0)
    verified_reports: int = Field(ge=0)
    incidents: int = Field(ge=0)
    critical_incidents: int = Field(ge=0)
    completed_incidents: int = Field(ge=0)
    average_dispatch_minutes: float | None = Field(ge=0)
    dispatch_samples: int = Field(ge=0)


class AdminAnalytics(BaseModel):
    date_from: date
    date_to: date
    timezone: str = "Asia/Manila"
    generated_at: datetime
    summary: AnalyticsSummary
    daily: list[AnalyticsDay]
    incident_types: list[AnalyticsType]
    sources: list[AnalyticsCount]
    priorities: list[AnalyticsCount]
    statuses: list[AnalyticsCount]
