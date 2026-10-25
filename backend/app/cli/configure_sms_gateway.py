"""Interactive local provisioning. Never put credentials in command arguments."""

import argparse
import asyncio
import getpass
import uuid

from sqlalchemy.exc import SQLAlchemyError

from app.core.config import get_settings
from app.core.exceptions import ApplicationError
from app.db.session import create_database_engine, create_session_factory
from app.schemas.sms import GatewayCreate
from app.services.admin_auth import AdminAuthService, AuthenticatedAdmin
from app.services.sms import SmsService


async def configure(rotate: uuid.UUID | None) -> None:
    email = input("Super Admin email: ").strip()
    password = getpass.getpass("Super Admin password: ")
    settings = get_settings()
    engine = create_database_engine(settings)
    try:
        async with create_session_factory(engine)() as database:
            auth = AdminAuthService(database, settings)
            login = await auth.login(
                email=email,
                password=password,
                ip_address="127.0.0.1",
                device_name="Local SMS gateway setup",
            )
            actor = AuthenticatedAdmin(login.user, login.session)
            try:
                service = SmsService(database, settings)
                if rotate:
                    credential = await service.rotate_gateway(actor, rotate)
                else:
                    payload = GatewayCreate(
                        name=input("Gateway name: ").strip(),
                        phone_number=input("Gateway SIM number (+639...): ").strip(),
                        device_identifier=str(uuid.uuid4()),
                    )
                    credential = await service.create_gateway(actor, payload)
                print(f"Gateway ID: {credential.gateway_id}")
                print(
                    "Paste this token only into the gateway app. Do not share it in chat or logs:"
                )
                print(credential.access_token)
            finally:
                await database.rollback()
                try:
                    current = await auth.authenticate(login.token)
                    await auth.logout(current, ip_address="127.0.0.1")
                except ApplicationError:
                    pass  # The temporary session is already invalid.
    finally:
        await engine.dispose()


def main() -> None:
    parser = argparse.ArgumentParser(description="Provision an Android SIM gateway privately")
    parser.add_argument(
        "--rotate", type=uuid.UUID, help="Rotate credentials for an existing gateway"
    )
    args = parser.parse_args()
    try:
        asyncio.run(configure(args.rotate))
    except ApplicationError as error:
        raise SystemExit(error.message) from None
    except SQLAlchemyError:
        raise SystemExit("Storage is unavailable. Retry setup later.") from None
    except (ValueError, KeyboardInterrupt):
        raise SystemExit(
            "Setup cancelled or invalid input. No credential values are printed in errors."
        ) from None


if __name__ == "__main__":
    main()
