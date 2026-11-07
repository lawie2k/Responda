"""Create a local private VAPID key without printing it or replacing existing keys."""

import os
from pathlib import Path

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec

from app.core.config import get_settings


def main() -> None:
    path = Path(get_settings().web_push_key_file)
    if path.exists():
        print("Existing browser push key preserved.")
        return
    key = ec.generate_private_key(ec.SECP256R1())
    raw = key.private_bytes(
        serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()
    )
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "wb") as file:
        file.write(raw)
    print("Private browser push key created.")


if __name__ == "__main__":
    main()
