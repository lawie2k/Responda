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
- Mobile and admin router namespaces exist, but the actual reporting,
  authentication, review, dispatch, and notification APIs are not implemented.
- The strict app-only SMS acceptance policy is documented and represented in
  the schema; gateway ingestion and signature verification are not implemented.

## Web dashboard

- The React/Vite dashboard can call the backend health endpoint and display
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

- In the preceding backend phase, the backend suite reported 14 passing tests.
- The web connection change passed lint and production build, and the running
  page displayed `Backend connected`.
- Treat these as historical results; rerun component checks after new changes.

## Repository and project-memory setup

- The GitHub repository is organized as a monorepo with `mobile/`, `backend/`,
  and `web/` application folders.
- The repository root is an Obsidian vault.
- Human-written project memory is in `memory/`.
- Graphify indexes code from backend, web, mobile, and the monorepo root into one
  combined graph.
- The monorepo graph contains 1,894 code nodes, 2,864 relationships, and 155
  detected communities. Generated graph artifacts remain local and ignored.
- `AGENTS.md` directs future coding sessions to read memory and query Graphify
  before broad filesystem searches.
