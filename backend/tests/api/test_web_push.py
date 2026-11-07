import asyncio
import base64
import json
import uuid
from datetime import UTC, datetime
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from pydantic import ValidationError

from app.api.v1.admin.push import SubscriptionRequest
from app.core.config import Settings
from app.models.entities import WebPushSubscription
from app.services.web_push import deliver, send_pending, valid_endpoint


def key(size: int) -> str:
    return base64.urlsafe_b64encode(bytes(size)).rstrip(b"=").decode()


@pytest.mark.parametrize(
    "endpoint",
    [
        "http://fcm.googleapis.com/wp/test",
        "https://127.0.0.1/private",
        "https://fcm.googleapis.com.attacker.test/wp/test",
        "https://user:secret@fcm.googleapis.com/wp/test",
        "https://fcm.googleapis.com:8443/wp/test",
    ],
)
def test_subscription_rejects_untrusted_endpoints(endpoint: str) -> None:
    assert not valid_endpoint(endpoint)
    with pytest.raises(ValidationError):
        SubscriptionRequest(endpoint=endpoint, p256dh=key(65), auth=key(16))


def test_subscription_requires_separate_key_sizes() -> None:
    with pytest.raises(ValidationError):
        SubscriptionRequest(
            endpoint="https://fcm.googleapis.com/wp/test", p256dh=key(16), auth=key(65)
        )


def test_delivery_sends_only_generic_encrypted_payload_and_uses_timeout() -> None:
    subscription = WebPushSubscription(
        endpoint="https://fcm.googleapis.com/wp/test", p256dh=key(65), auth=key(16)
    )
    with patch("app.services.web_push.webpush") as send:
        assert deliver(subscription, uuid.uuid4(), Settings(_env_file=None))
    payload = json.loads(send.call_args.kwargs["data"])
    assert set(payload) == {"title", "body", "reportId"}
    assert send.call_args.kwargs["timeout"] == 10
    assert send.call_args.kwargs["ttl"] == 300


def test_push_cursor_advances_only_on_success_and_failed_delivery_retries() -> None:
    for success in [True, False]:
        now = datetime.now(UTC)
        subscription = WebPushSubscription(cursor_at=now, cursor_id=uuid.UUID(int=0))
        result = MagicMock()
        report_id = uuid.uuid4()
        result.all.return_value = [(report_id, now)]
        db = MagicMock(
            scalar=AsyncMock(return_value=subscription),
            execute=AsyncMock(return_value=result),
            commit=AsyncMock(),
            delete=AsyncMock(),
        )
        with patch(
            "app.services.web_push.deliver",
            return_value=True,
            side_effect=None if success else RuntimeError("private endpoint"),
        ):
            asyncio.run(send_pending(db, Settings(_env_file=None)))
        assert subscription.cursor_id == (report_id if success else uuid.UUID(int=0))
        db.commit.assert_awaited_once()
        sql = str(db.scalar.call_args.args[0])
        assert "auth_sessions.revoked_at IS NULL" in sql and "users.is_active IS true" in sql
