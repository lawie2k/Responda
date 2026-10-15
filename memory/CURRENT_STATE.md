---
tags:
  - responda/memory
  - responda/status
updated: 2026-10-15
---

# Current state

## Backend

- The FastAPI project structure, configuration, exception handling, CORS, async
  database session setup, and `/api/v1` router separation exist.
- PostgreSQL is configured locally through a private `.env` file.
- The initial Alembic migration and 18 SQLAlchemy tables exist.
- The shared health endpoint checks application and database availability.
- Admin staff authentication now provides login, current-session, and logout
  endpoints under `/api/v1/admin/auth`. It uses Argon2id password hashes,
  an 8-character minimum, revocable hashed opaque sessions in `HttpOnly`
  cookies, login throttling, origin checks, active-account and staff-role
  checks, session limits, and audit records.
- Reporting, review, dispatch, gateway ingestion, and notification APIs are not
  implemented yet.
- The strict app-only SMS acceptance policy is documented and represented in
  the schema; gateway ingestion and signature verification are not implemented.

## Web dashboard

- The React/Vite dashboard has a responsive staff login page wired to the real
  admin login, session, and logout endpoints. Its left hero panel uses the
  supplied MDRRMO Operation Center photo with a responsive maroon treatment.
- It restores valid `HttpOnly` cookie sessions on reload, clears session-scoped
  client caches on login/logout, displays the authenticated staff identity, and
  guards browser history so repeated Back actions do not show the login page
  while signed in or reveal the dashboard after logout.
- The bottom-left staff profile is an interactive account menu showing the real
  authenticated name, email, and role, with a clear server-backed sign-out
  action plus outside-click and Escape-key dismissal.
- The dashboard also calls the backend health endpoint and displays
  `Backend connected` when FastAPI and PostgreSQL are available.
- Report cards, statistics, and operational dashboard content still use
  demonstration data until protected admin APIs are implemented.

## Mobile app

- The active mobile codebase is Flutter, not React Native.
- It has a backend health client and environment-aware base URLs, including the
  Android emulator host address.
- The application contains onboarding, connectivity handling, reporting flows,
  localization, offline-related behavior, and tests.
- The complete report-submission API and signed SMS gateway protocol are not yet
  wired end to end.

## Verification history

- The latest staff-authentication backend phase passed Ruff, strict mypy, and
  all 30
  tests.
- The web connection change passed lint and production build, and the running
  page displayed `Backend connected`. The later login-page phase also passed
  web lint and production build and was verified in a real browser.
- Treat these as historical results; rerun component checks after new changes.

## Repository and project-memory setup

- The GitHub repository is organized as a monorepo with `mobile/`, `backend/`,
  and `web/` application folders.
- The repository root is an Obsidian vault.
- Human-written project memory is in `memory/`.
- Graphify indexes code from backend, web, mobile, and the monorepo root into one
  combined graph.
- The monorepo graph contains 2,010 code nodes, 3,179 relationships, and 161
  detected communities. Generated graph artifacts remain local and ignored.
- `AGENTS.md` directs future coding sessions to read memory and query Graphify
  before broad filesystem searches.
