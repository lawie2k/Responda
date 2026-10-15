import asyncio
import hashlib
import hmac
import math
import time
from collections import defaultdict, deque
from collections.abc import Callable


class LoginRateLimiter:
    """A bounded, process-local limiter for the single-instance deployment.

    The public API is intentionally storage-agnostic so a shared Redis-backed
    implementation can replace it before the API is deployed on multiple workers.
    """

    def __init__(
        self,
        *,
        max_attempts: int,
        window_seconds: int,
        secret_key: str,
        max_buckets: int = 10_000,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._max_attempts = max_attempts
        self._window_seconds = window_seconds
        self._secret_key = secret_key.encode()
        self._max_buckets = max_buckets
        self._clock = clock
        self._attempts: dict[str, deque[float]] = defaultdict(deque)
        self._lock = asyncio.Lock()

    async def consume(self, *, ip_address: str, identity: str) -> int | None:
        """Record an attempt and return retry seconds when either bucket is full."""

        now = self._clock()
        keys = (
            self._key("ip", ip_address),
            self._key("identity", identity.casefold()),
        )
        async with self._lock:
            if (
                len(self._attempts) + sum(key not in self._attempts for key in keys)
                > self._max_buckets
            ):
                self._remove_empty_buckets(now)
            if (
                len(self._attempts) + sum(key not in self._attempts for key in keys)
                > self._max_buckets
            ):
                return self._window_seconds

            for key in keys:
                self._discard_expired(self._attempts[key], now)

            blocked_until = max(
                (
                    attempts[0] + self._window_seconds
                    for key in keys
                    if len(attempts := self._attempts[key]) >= self._max_attempts
                ),
                default=None,
            )
            if blocked_until is not None:
                return max(1, math.ceil(blocked_until - now))

            for key in keys:
                self._attempts[key].append(now)
            return None

    def _key(self, bucket: str, value: str) -> str:
        digest = hmac.new(self._secret_key, value.encode(), hashlib.sha256).hexdigest()
        return f"{bucket}:{digest}"

    def _discard_expired(self, attempts: deque[float], now: float) -> None:
        cutoff = now - self._window_seconds
        while attempts and attempts[0] <= cutoff:
            attempts.popleft()

    def _remove_empty_buckets(self, now: float) -> None:
        for key, attempts in tuple(self._attempts.items()):
            self._discard_expired(attempts, now)
            if not attempts:
                del self._attempts[key]
