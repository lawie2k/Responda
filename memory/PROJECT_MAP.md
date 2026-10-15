---
tags:
  - responda/memory
  - responda/code-map
updated: 2026-10-15
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
- Entry: `lib/main.dart`.
- Application root: `lib/app.dart`.
- API configuration: `lib/core/network/api_config.dart`.
- API client: `lib/core/network/responda_api_client.dart`.
- Features: `lib/features/`.

Common commands:

```bash
cd "/Users/lawie/develop/responda/mobile"
flutter analyze
flutter test
flutter run
```

The Android emulator uses `http://10.0.2.2:8000` for a backend running on the
development laptop. A physical phone needs the laptop's LAN address and
`make run-mobile` on the backend.

## Graph maintenance

From the monorepo root:

```bash
./scripts/update-project-graph.sh all
```

Component snapshots are kept under `.graphify-components/`; the combined graph
and reports are in `graphify-out/`; Obsidian-compatible generated node notes are
in `graphify-notes/`.
