#!/usr/bin/env python3
"""Maintain the dedicated Android gateway's local development USB route."""

import argparse
import os
from pathlib import Path
import plistlib
import subprocess
import sys


LABEL = "com.responda.gateway-usb"


def ensure_forwarding(adb: Path, device: str) -> None:
    def run(*arguments: str) -> str:
        result = subprocess.run(
            [str(adb), *arguments], capture_output=True, text=True, timeout=5
        )
        if result.returncode:
            raise RuntimeError("ADB command failed; forwarding will be checked again.")
        return result.stdout

    # Restrict changes to this authorized handset while physically attached.
    connected = False
    for line in run("devices", "-l").splitlines():
        fields = line.split()
        if len(fields) >= 2 and fields[:2] == [device, "device"]:
            connected = any(field.startswith("usb:") for field in fields[2:])
            break
    if not connected:
        return

    mappings = run("-s", device, "reverse", "--list")
    if any(line.split()[-2:] == ["tcp:8000", "tcp:8000"] for line in mappings.splitlines()):
        return
    run("-s", device, "reverse", "tcp:8000", "tcp:8000")
    print("Restored gateway USB forwarding on port 8000.", flush=True)


def install_agent(adb: Path, device: str) -> None:
    agent = Path.home() / "Library/LaunchAgents" / (LABEL + ".plist")
    logs = Path.home() / "Library/Logs/Responda"
    agent.parent.mkdir(parents=True, exist_ok=True)
    logs.mkdir(parents=True, exist_ok=True)
    configuration = {
        "Label": LABEL,
        "ProgramArguments": [
            sys.executable, str(Path(__file__).resolve()), "ensure",
            "--adb", str(adb), "--device", device,
        ],
        "RunAtLoad": True,
        "StartInterval": 10,
        "ProcessType": "Background",
        "StandardOutPath": str(logs / "gateway-usb.log"),
        "StandardErrorPath": str(logs / "gateway-usb-error.log"),
    }
    # Keep this machine's device selection outside Git and project memory.
    agent.write_bytes(plistlib.dumps(configuration))
    agent.chmod(0o600)
    domain = "gui/" + str(os.getuid())
    subprocess.run(
        ["launchctl", "bootout", domain + "/" + LABEL],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    subprocess.run(["launchctl", "enable", domain + "/" + LABEL], check=True)
    subprocess.run(["launchctl", "bootstrap", domain, str(agent)], check=True)
    print("Installed automatic gateway USB forwarding (checks every 10 seconds).")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("ensure", "install"))
    parser.add_argument("--device", required=True, help="Dedicated gateway's ADB serial")
    parser.add_argument(
        "--adb", type=Path,
        default=Path.home() / "Library/Android/sdk/platform-tools/adb",
    )
    args = parser.parse_args()
    adb = args.adb.expanduser().resolve()
    if not adb.is_file() or not os.access(adb, os.X_OK):
        parser.error("Pass the executable Android SDK adb path with --adb.")
    try:
        if args.action == "install":
            install_agent(adb, args.device)
        else:
            ensure_forwarding(adb, args.device)
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
