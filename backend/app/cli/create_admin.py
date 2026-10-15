import argparse
import asyncio
import getpass
import uuid

from pydantic import TypeAdapter, ValidationError
from sqlalchemy import func, select

from app.core.config import get_settings
from app.core.security import PASSWORD_MIN_LENGTH, hash_password, normalize_email
from app.db.session import create_database_engine, create_session_factory
from app.models import AuditLog, User
from app.models.enums import UserRole
from app.schemas.admin_auth import EmailInput

STAFF_ROLES = (
    UserRole.ADMIN.value,
    UserRole.DISPATCHER.value,
    UserRole.VERIFIER.value,
    UserRole.VIEWER.value,
)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Create a Responda staff account")
    parser.add_argument("--email", required=True)
    parser.add_argument("--full-name", required=True)
    parser.add_argument("--role", choices=STAFF_ROLES, default=UserRole.ADMIN.value)
    return parser.parse_args()


def read_password() -> str:
    password = getpass.getpass(f"Password ({PASSWORD_MIN_LENGTH}+ characters): ")
    confirmation = getpass.getpass("Confirm password: ")
    if password != confirmation:
        raise ValueError("Passwords do not match")
    return password


async def create_staff_user(*, email: str, full_name: str, role: str, password: str) -> uuid.UUID:
    normalized_email = normalize_email(TypeAdapter(EmailInput).validate_python(email))
    normalized_name = full_name.strip()
    if not normalized_name:
        raise ValueError("Full name cannot be empty")

    settings = get_settings()
    engine = create_database_engine(settings)
    session_factory = create_session_factory(engine)
    try:
        async with session_factory() as database:
            existing = await database.scalar(
                select(User).where(func.lower(User.email) == normalized_email)
            )
            if existing is not None:
                raise ValueError("A user with this email already exists")

            user = User(
                full_name=normalized_name,
                email=normalized_email,
                password_hash=hash_password(password),
                role=role,
                is_active=True,
            )
            database.add(user)
            await database.flush()
            database.add(
                AuditLog(
                    action="user.created.by_cli",
                    entity_type="user",
                    entity_id=user.user_id,
                    details='{"source": "create_admin_cli"}',
                )
            )
            await database.commit()
            return user.user_id
    finally:
        await engine.dispose()


def main() -> None:
    arguments = parse_arguments()
    try:
        password = read_password()
        user_id = asyncio.run(
            create_staff_user(
                email=arguments.email,
                full_name=arguments.full_name,
                role=arguments.role,
                password=password,
            )
        )
    except (ValueError, ValidationError) as error:
        raise SystemExit(f"Could not create staff user: {error}") from error
    print(f"Created staff user {user_id}")


if __name__ == "__main__":
    main()
