import asyncio

from pytest import raises

from app.core.rate_limit import LoginRateLimiter
from app.core.security import (
    generate_session_token,
    hash_password,
    hash_session_token,
    normalize_email,
    verify_password,
)


def test_passwords_are_argon2_hashed_and_verifiable() -> None:
    password_hash = hash_password("a-long-and-unique-password")

    assert password_hash.startswith("$argon2id$")
    assert verify_password("a-long-and-unique-password", password_hash) is True
    assert verify_password("the-wrong-password", password_hash) is False
    assert "a-long-and-unique-password" not in password_hash


def test_short_passwords_cannot_be_created() -> None:
    with raises(ValueError):
        hash_password("short7")


def test_eight_character_passwords_can_be_created() -> None:
    password_hash = hash_password("eight888")

    assert verify_password("eight888", password_hash) is True


def test_session_tokens_are_random_and_only_hashes_need_storage() -> None:
    first_token = generate_session_token()
    second_token = generate_session_token()

    assert first_token != second_token
    assert len(hash_session_token(first_token)) == 64
    assert first_token not in hash_session_token(first_token)


def test_email_normalization_is_stable() -> None:
    assert normalize_email("  Staff@Example.COM ") == "staff@example.com"


def test_login_limiter_blocks_ip_and_identity_buckets() -> None:
    now = [100.0]
    limiter = LoginRateLimiter(
        max_attempts=2,
        window_seconds=60,
        secret_key="test-secret",
        clock=lambda: now[0],
    )

    assert asyncio.run(limiter.consume(ip_address="127.0.0.1", identity="a@example.com")) is None
    assert asyncio.run(limiter.consume(ip_address="127.0.0.1", identity="b@example.com")) is None
    assert asyncio.run(limiter.consume(ip_address="127.0.0.1", identity="c@example.com")) == 60

    now[0] = 161.0
    assert asyncio.run(limiter.consume(ip_address="127.0.0.1", identity="c@example.com")) is None


def test_login_limiter_fails_closed_when_bucket_capacity_is_exhausted() -> None:
    limiter = LoginRateLimiter(
        max_attempts=2,
        window_seconds=60,
        secret_key="test-secret",
        max_buckets=2,
    )

    assert asyncio.run(limiter.consume(ip_address="127.0.0.1", identity="a@example.com")) is None
    assert asyncio.run(limiter.consume(ip_address="127.0.0.2", identity="b@example.com")) == 60
