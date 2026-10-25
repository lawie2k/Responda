"""RSP1 authenticates the exact ASCII envelope before interpreting its payload."""

import base64
import binascii
import hmac
import json
import re
import uuid
from datetime import UTC, datetime, timedelta

from pydantic import BaseModel, ConfigDict, Field, ValidationError

from app.schemas.mobile_reports import MobileReportCreateRequest

ENVELOPE = re.compile(r"RSP1\.([0-9a-f]{32})\.([A-Za-z0-9_-]+)\.([A-Za-z0-9_-]{43})")
MAX_MESSAGE_AGE = timedelta(days=7)
CLOCK_SKEW = timedelta(minutes=5)


class SmsContent(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True, allow_inf_nan=False)

    c: str = Field(pattern=r"^[0-9a-f]{32}$")
    t: int = Field(gt=0, le=253402300799)
    k: int | None = Field(default=None, gt=0, le=253402300799)
    i: str
    d: str = Field(min_length=10, max_length=300)
    landmark: str | None = Field(default=None, max_length=100, alias="l")
    x: float | None = Field(default=None, ge=-90, le=90)
    y: float | None = Field(default=None, ge=-180, le=180)
    m: float | None = Field(default=None, ge=0, le=100000)
    p: bool
    a: bool
    g: bool

    def report(self) -> MobileReportCreateRequest:
        return MobileReportCreateRequest.model_validate(
            {
                "client_report_id": self.c,
                "incident_type_code": self.i,
                "description": self.d,
                "landmark": self.landmark,
                "latitude": self.x,
                "longitude": self.y,
                "accuracy_meters": self.m,
                "people_need_help": self.p,
                "additional_assistance": self.a,
                "immediate_danger": self.g,
                "location_captured_at": datetime.fromtimestamp(
                    self.k if self.k is not None else self.t, UTC
                ),
            }
        )


def device_key(secret: str, device_id: uuid.UUID) -> bytes:
    return hmac.digest(secret.encode(), b"responda:sms-device:RSP1:" + device_id.bytes, "sha256")


def encode64(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).decode("ascii").rstrip("=")


def encode_message(device_id: uuid.UUID, key: bytes, content: SmsContent) -> str:
    """Reference encoder; clients must keep the same bytes when retrying SMS."""
    payload = encode64(content.model_dump_json(exclude_none=True, by_alias=True).encode("utf-8"))
    unsigned = f"RSP1.{device_id.hex}.{payload}"
    body = f"{unsigned}.{encode64(hmac.digest(key, unsigned.encode('ascii'), 'sha256'))}"
    if len(body) > 2048:
        raise ValueError(
            "SMS payload is too long; shorten details without truncating the signature"
        )
    return body


def decode_message(body: str, secret: str) -> tuple[uuid.UUID, SmsContent] | None:
    if len(body) > 2048 or (match := ENVELOPE.fullmatch(body)) is None:
        return None
    device_id = uuid.UUID(hex=match[1])
    unsigned = body.rsplit(".", 1)[0]
    expected = encode64(hmac.digest(device_key(secret, device_id), unsigned.encode(), "sha256"))
    if not hmac.compare_digest(expected, match[3]):
        return None
    try:
        encoded = match[2]
        data = base64.b64decode(encoded + "=" * (-len(encoded) % 4), altchars=b"-_", validate=True)
        if encode64(data) != encoded:
            return None

        # Reject duplicate JSON fields rather than letting the last field win.
        def unique_fields(pairs: list[tuple[str, object]]) -> dict[str, object]:
            result = dict(pairs)
            if len(result) != len(pairs):
                raise ValueError("Duplicate fields")
            return result

        content = SmsContent.model_validate(json.loads(data, object_pairs_hook=unique_fields))
        content.report()
        return device_id, content
    except (ValueError, ValidationError, binascii.Error, OverflowError, RecursionError):
        return None
