---
tags:
  - responda/memory
  - responda/status
updated: 2026-10-18
---

# Current state

## Backend

- The FastAPI project structure, configuration, exception handling, CORS, async
  database session setup, and `/api/v1` router separation exist.
- PostgreSQL is configured locally through a private `.env` file.
- Five Alembic migrations and 18 SQLAlchemy tables exist. The database is at
  the manual-report intake migration head.
- Mutable operational records use indexed nullable `deleted_at` timestamps:
  users, incident types, incidents, reports, report locations, report
  attachments, SMS gateways/messages, response units/assignments, and
  notifications. Current authentication and report reads exclude deleted rows.
  Sessions/OTP use revoke/consume/expiry fields, while audit and processing
  history remain immutable.
- The shared health endpoint checks application and database availability.
- Admin staff authentication now provides login, current-session, and logout
  endpoints under `/api/v1/admin/auth`. It uses Argon2id password hashes,
  an 8-character minimum, revocable hashed opaque sessions in `HttpOnly`
  cookies, login throttling, origin checks, active-account and staff-role
  checks, session limits, and audit records.
- One active staff account with the `admin` role exists in PostgreSQL. Its
  identity and credentials are not stored in project memory.
- The administrator role model is implemented end to end. The existing `admin`
  database value is presented as Super Admin, and `operations_admin` represents
  a normal Administrator. Only these two roles may create or retain a dashboard
  session; dispatcher, verifier, viewer, and reporter roles are rejected.
- Protected staff report-list and report-detail endpoints now exist under
  `/api/v1/admin/reports`. They use the existing revocable staff session,
  validated and capped pagination, search and enum-backed filters, stable safe
  errors, and no-store responses. List responses exclude reporter contact data;
  protected detail responses include it but do not expose attachment storage
  keys or checksums.
- Super Admin and Administrator accounts can now encode manual reports through
  a protected endpoint. It loads active database incident types, normalizes the
  reporter phone to the Philippine `+639XXXXXXXXX` form, records the offline
  intake channel and three safety answers, supports a written location without
  invented GPS coordinates, and commits the caller, report, location, event,
  and privacy-minimized audit record together.
  Six canonical incident types are seeded for the current web and Flutter flows.
- A protected report-review endpoint allows Super Admin and Administrator
  accounts to decide pending reports. Each decision locks and version-checks
  the report, updates verification/final-priority state, and creates a review,
  report event, and audit entry in one transaction. Verified and unverified
  reports move to `under_review`; invalid reports are closed. Reviewer notes
  and a final priority remain required for verified decisions, while all review
  checklist indicators are optional evidence and may remain unchecked.
- Protected incident write endpoints allow Super Admin and Administrator
  accounts to create an incident from a verified report or link a verified report to an
  existing active incident of the same type. Both operations lock and
  version-check the report and atomically update the report plus its event and
  audit history. A protected, paginated incident-list endpoint supplies active
  matching incidents to staff clients.
- A protected response-unit list endpoint supplies the staff dashboard with a
  paginated, searchable, status-filtered roster plus global readiness counts.
  It excludes soft-deleted units and returns non-cacheable responses to either
  authenticated administrator tier. Create and edit endpoints now
  validate and normalize roster fields, require trusted origins, reject name
  conflicts and stale edits, preserve operational status during edits, and
  write minimal audit records atomically.
- Protected assignment endpoints now list an incident's assignments, assign an
  available unit, and transition assignments through acknowledged, responding,
  completed, or cancelled states. Writes lock and version-check the involved
  records, atomically synchronize assignment, unit, and incident status, create
  linked-report events and audit records, and enforce one active assignment per
  unit with a PostgreSQL partial unique index. Completing the final active
  assignment resolves the incident; cancelling the final active assignment
  reopens it.
- Mobile report creation, gateway ingestion, and notification APIs are not
  implemented yet.
- The strict app-only SMS acceptance policy is documented and represented in
  the schema; gateway ingestion and signature verification are not implemented.

## Web dashboard

- The React/Vite dashboard has a responsive staff login page wired to the real
  admin login, session, and logout endpoints. Its restrained civic layout uses
  one flat maroon accent, the supplied MDRRMO Operation Center photo, clear
  form-first hierarchy, and Pantukan-specific operational copy without
  decorative gradients or unnecessary card shadows.
- It restores valid `HttpOnly` cookie sessions on reload, clears session-scoped
  client caches on login/logout, displays the authenticated staff identity, and
  guards browser history so repeated Back actions do not show the login page
  while signed in or reveal the dashboard after logout.
- The bottom-left staff profile is an interactive account menu showing the real
  authenticated name, email, and role, with a clear server-backed sign-out
  action plus outside-click and Escape-key dismissal.
- The dashboard also calls the backend health endpoint and displays
  `Backend connected` when FastAPI and PostgreSQL are available.
- All nine authenticated dashboard tabs now share a restrained civic operations
  design system: warm neutral flat surfaces, one maroon brand accent, semantic
  colors only for operational states, stronger content hierarchy, flat
  navigation/tabs/tables/controls, and shadows reserved for floating overlays.
- The Encode a Report modal is connected to PostgreSQL. It loads real incident
  types, submits validated manual reports with loading/error states, prevents
  duplicate clicks, confirms success, opens Live Reports, and refreshes both
  dashboard and queue data. Its phone input fixes `+63 9` as the beginning,
  accepts digits only, and limits the local number to 10 digits. Written manual
  locations remain visible even when no coordinates were provided.
- Normal Administrators receive the operational workspace but cannot navigate
  to or discover the system Settings page; that configuration surface remains
  Super Admin-only.
- The Overview report metrics, priority queue, map markers, recent-report table,
  global report search, and Live Reports queue now read from the protected
  report APIs. Live Reports supports server-side search, filters, capped
  pagination, real protected details, and explicit loading, error, and empty
  states. The desktop Live Reports queue and detail panels fit within the
  available viewport and scroll internally, with seven reports per page;
  stacked responsive layouts retain natural height. Report Validation now loads
  pending reports and protected details from the backend, submits real
  verified/unverified/invalid decisions, treats every checklist item as
  optional, respects reviewer roles, and handles validation and concurrency
  failures. Zero-count
  validation alerts, summary cards, and queue badges are hidden while the clear
  queue empty state remains visible. In Live Reports, Super Admin and
  Administrator accounts select an available response team directly from an
  unlinked verified report. The dashboard automatically creates the incident
  and then assigns that team, using the new incident's returned concurrency
  timestamp; staff no longer see incident creation as a separate primary step.
  Existing-incident linking remains a secondary option only for duplicate
  reports. All report and incident views refresh after success. Response Teams now reads
  the real PostgreSQL response-unit roster with search, status filters,
  pagination, refresh, unit details, and explicit loading, error, and empty
  states. Administrators can register available response units and edit their
  name, type, and contact through a validated dashboard modal. Its responsive
  workspace places search controls first, a dominant operational-unit roster on
  the left, and roster totals plus readiness summaries in a stacked right rail.
  Linked active incidents in Live Reports now load their current assignments
  and available response teams, and administrators can assign another available
  team with optimistic-concurrency protection. Response Teams now resolves the
  active assignment for each in-service unit and lets administrators record
  acknowledgment, responding, completion, or confirmed cancellation while
  refreshing the roster, assignment state, and shared report summaries after
  each change so Live Reports counters cannot retain a stale dispatch status.
  Analytics, historical, and incident-map views still contain demonstration data.

## Mobile app

- The active mobile codebase is Flutter, not React Native.
- The approved citizen-account flow is phone number plus OTP verification,
  followed by optional name and barangay fields. Government-ID upload, face
  capture, and identity-review approval are no longer part of the product flow;
  their existing Flutter screens are legacy UI to remove during account
  integration.
- It has a backend health client and environment-aware base URLs, including the
  Android emulator host address.
- The application contains onboarding, connectivity handling, reporting flows,
  localization, offline-related behavior, and tests.
- The complete report-submission API and signed SMS gateway protocol are not yet
  wired end to end.

## Verification history

- A real-browser development workflow created a manual report, validated it
  with every optional checklist item unchecked, selected a response team first,
  automatically created the incident, assigned the team, recorded
  acknowledgment and responding, completed the response, resolved the report,
  and returned the unit to Available. The browser console had no errors. Web
  lint and production build passed after fixing shared report-summary refreshes
  from Response Teams.

- Optional validation checks and the compact Live Reports workspace passed
  backend Ruff, strict mypy, and all 108 tests plus web lint and production
  build. Browser accessibility inspection confirmed the live queue, linked
  incident, and response-team assignment controls render from the running app.

- Manual report intake passed backend Ruff, strict mypy, and all 107 tests plus
  web lint and production build. PostgreSQL is at the new migration head with
  no schema drift and six active incident types. A rolled-back database
  rehearsal created exactly one caller, report, written location, event, and
  audit row, then confirmed no verification rows remained.

- A repository cleanup removed unused Vite/React template artwork, four
  unreferenced Flutter SVGs, one dead shared web component, five unused web
  build dependencies, the unused Flutter Cupertino-icons dependency, redundant
  `.gitkeep` files, and generated component caches/build output. Installed
  runtime dependencies, IDE configuration, platform folders, and intentional
  backend/ML scaffolds were preserved. Backend Ruff, strict mypy, and all 99
  tests passed; web lint, production build, and Knip passed; Flutter analysis
  and all 71 tests passed.
- The web assignment integration passed lint and production build. The client
  validates assignment API responses, uses non-cacheable authenticated calls,
  handles loading/error/empty states, and surfaces backend concurrency or
  lifecycle failures without inventing local assignment state.
- The assignment-lifecycle backend passed Ruff, strict mypy, and all 99 tests.
  PostgreSQL is at the new migration head with no schema drift, OpenAPI exposes
  the assignment list/create/transition operations, and a rolled-back database
  rehearsal verified assigned, acknowledged, responding, and completed states,
  incident resolution, unit release, four audit records, and no temporary rows.
- The two-tier administrator phase passed backend Ruff, strict mypy, and all 81
  tests plus web lint and production build. PostgreSQL is at the new role
  migration head, and Alembic reports no schema drift.
- Response-unit roster management passed backend Ruff, strict mypy, and all 75
  tests plus web lint and production build. Alembic reports no schema drift,
  OpenAPI exposes GET/POST/PATCH response-unit operations, and a rolled-back
  PostgreSQL verification confirmed create, edit, status preservation, and two
  audit records.

- The response-unit roster phase passed backend Ruff, strict mypy, and all 65
  tests; web lint and production build passed. OpenAPI exposes the protected
  response-unit GET operation, Alembic reports no schema drift, and the
  configured PostgreSQL roster query completed successfully with the current
  empty roster.
- The Live Reports incident integration passed all 61 backend tests, backend
  Ruff and strict mypy, web lint and production build. Alembic reports no schema
  drift, OpenAPI exposes GET/POST on the incident collection, and the configured
  PostgreSQL incident-list query completed successfully.
- The incident creation/linking phase passed backend Ruff, strict mypy, and all
  58 tests. PostgreSQL accepted one temporary incident with two linked reports,
  two events, and two audits in transactional verification; the outer rollback
  left zero temporary reports or incidents. Alembic reports no schema drift.
- The report-review phase passed backend Ruff, strict mypy, and all 46 tests;
  the web dashboard passed lint and production build. A rolled-back PostgreSQL
  test confirmed atomic report/review/event/audit writes, stale-review conflict
  handling, and zero temporary rows remaining.
- Treat these as historical results; rerun component checks after new changes.

## Repository and project-memory setup

- The GitHub repository is organized as a monorepo with `mobile/`, `backend/`,
  and `web/` application folders.
- The repository root is an Obsidian vault.
- Human-written project memory is in `memory/`.
- Graphify indexes code from backend, web, mobile, and the monorepo root into one
  combined graph.
- The combined graph currently contains 2,539 code nodes, 4,754 relationships,
  and 218 detected communities. Generated graph artifacts remain local and
  ignored.
- `AGENTS.md` directs future coding sessions to read memory and query Graphify
  before broad filesystem searches.
