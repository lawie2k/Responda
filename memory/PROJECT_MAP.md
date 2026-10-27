---
tags:
  - responda/memory
  - responda/code-map
updated: 2026-10-27
---

# Project map

## Monorepo root

Path: `/Users/lawie/develop/responda`

Contains the three applications, Obsidian memory, maintenance scripts, and the
local combined Graphify output.

## Backend

Path: `/Users/lawie/develop/responda/backend`

- Framework: FastAPI with SQLAlchemy async and Alembic.
- Database: PostgreSQL.
- Application entry: `app/main.py`.
- API router: `app/api/v1/router.py`.
- Models: `app/models/entities.py`.
- Migrations: `migrations/versions/`.
- Database rules: `docs/database-design.md`.

Common commands:

```bash
cd "/Users/lawie/develop/responda/backend"
make run
make run-mobile
make migrate
make check
```

Health URL: `http://127.0.0.1:8000/api/v1/shared/health`

## Web dashboard

Path: `/Users/lawie/develop/responda/web`

- Framework: React 19, TypeScript, Vite, and Tailwind CSS.
- Entry: `src/main.tsx`.
- Main application: `src/App.tsx`.
- Backend client: `src/api/respondaApi.ts`.
- Backend indicator: `src/components/BackendStatus.tsx`.

Common commands:

```bash
cd "/Users/lawie/develop/responda/web"
npm run dev
npm run lint
npm run build
```

Local URL: `http://localhost:5173`

## Mobile app

Path: `/Users/lawie/develop/responda/mobile`

- Framework: Flutter/Dart; Android is the first deployment target.
- The user-selected iPhone build copy is
  `/Users/lawie/local Documents/Responda/mobile`. It currently mirrors this
  tracked source but is outside Git; synchronize application changes back to
  the monorepo before committing or pushing. Keep generated Flutter/Xcode
  environment files local to each path.
- Entry: `lib/main.dart`.
- Application root: `lib/app.dart`.
- API configuration: `lib/core/network/api_config.dart`.
- API client: `lib/core/network/responda_api_client.dart`.
- Features: `lib/features/`.
- Signed SMS codec/store: `lib/features/reporting/data/signed_sms.dart`.
- Gateway utility APK: `android/gateway/`, package `com.responda.gateway`.
- Private setup/device walkthrough: `docs/sms-testing.md`; backend provisioning
  command: `.venv/bin/python -m app.cli.configure_sms_gateway` from backend/.
- Android artifacts in the Documents mobile build copy: `build/gateway/outputs/
  apk/debug/gateway-debug.apk` and `build/app/outputs/flutter-apk/app-debug.apk`.

Common commands:

```bash
cd "/Users/lawie/develop/responda/mobile"
flutter analyze
flutter test
flutter run
```

The Android emulator uses `http://10.0.2.2:8000` for a backend running on the
development laptop. Physical phones need a reachable laptop origin and
`make run-mobile` on the backend. For the paired iPhone, Bonjour avoids changing
USB interface IPs:

```bash
flutter build ios --release --dart-define="RESPONDA_API_BASE_URL=http://$(scutil --get LocalHostName).local:8000"
```

For the connected Android gateway's local USB test, its `localhost:8000`
configuration reaches the laptop only while this tunnel is active:

```bash
adb reverse tcp:8000 tcp:8000
```

The current Mac automatically restores this mapping every ten seconds through
the user LaunchAgent `com.responda.gateway-usb`. Reinstall from the monorepo root
with `python3 scripts/gateway-usb-forwarding.py install --device GATEWAY_ADB_SERIAL`.
The device selection stays in the local LaunchAgent plist, not project memory.
Untethered operation needs a reachable LAN/deployed origin; preserve pending
queues when changing configuration.

## Graph maintenance

From the monorepo root:

```bash
./scripts/update-project-graph.sh all
```

Component snapshots are kept under `.graphify-components/`; the combined graph
and reports are in `graphify-out/`; Obsidian-compatible generated node notes are
in `graphify-notes/`.
