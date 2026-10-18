import uuid
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict


class MobileAccountItem(BaseModel):
    user_id: uuid.UUID
    full_name: str
    masked_phone: str
    barangay: str | None
    is_active: bool
    created_at: datetime
    updated_at: datetime
    phone_verified_at: datetime
    privacy_notice_accepted_at: datetime
    last_sign_in_at: datetime | None
    reports_submitted: int


class MobileAccountCounts(BaseModel):
    total: int
    active: int
    suspended: int


class MobileAccountList(BaseModel):
    items: list[MobileAccountItem]
    total: int
    page: int
    page_size: int
    total_pages: int
    counts: MobileAccountCounts


class MobileAccountStatusUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    expected_updated_at: datetime
    is_active: bool
    reason: Literal["suspected_misuse", "account_security", "review_completed"]
