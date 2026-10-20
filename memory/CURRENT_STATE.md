---
tags:
  - responda/memory
  - responda/status
updated: 2026-10-20
---

# Current state

## Backend

- The FastAPI project structure, configuration, exception handling, CORS, async
  database session setup, and `/api/v1` router separation exist.
- PostgreSQL is configured locally through a private `.env` file.
- Six Alembic migrations and 18 SQLAlchemy tables exist. PostgreSQL is at
  `a19e7215d104`, adding optional citizen barangay and privacy acknowledgement.
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
- Super Admin-only `/api/v1/admin/staff` endpoints now list/search/filter staff,
  create normal Administrators, edit name/email/activation, revoke sessions,
  and expose non-secret server policy. Super Admin accounts are protected from
  dashboard mutation. Writes recheck the actor/session, lock and version-check
  targets, reserve normalized emails, hash initial passwords, revoke sessions
  on email/activation changes, and commit minimal audits together. Login locks
  the same user row to serialize session issuance with staff changes. Invalid
  staff requests never echo passwords. No migration was required.
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
- Protected Historical Records endpoints now provide resolved/closed incident
  lists, matching incident-type options, paginated reports/assignments/events,
  and filtered CSV exports under `/api/v1/admin/history`. Both administrator
  tiers can read them. Queries exclude deleted operational rows, validate and
  cap pagination, escape search wildcards, and interpret date filters in
  Asia/Manila. Exports reject more than 5,000 matching incidents, neutralize
  spreadsheet formulas, omit report text, exact locations, and contacts, and
  audit only the exporting staff identity and record count. No migration was
  required.
- Authenticated `POST /api/v1/mobile/reports` now creates app-origin reports with
  GPS/manual landmark location, safety answers, a report event, and a minimal
  audit in one transaction. It validates payloads, limits submissions by
  account/IP, and uses the client UUID for retry-safe creation. The existing
  dashboard Live Reports API already includes these `app_api` rows; no migration
  was required. Gateway ingestion and reporter notifications remain unimplemented.
- Local report testing can now use `/api/v1/mobile/auth/beta/register` without
  OTP when `RESPONDA_MOBILE_BETA_ACCOUNTS_ENABLED` is explicitly enabled.
  Registration creates a fresh unverified reporter/session; it cannot claim an
  existing account. Beta tokens retain expiry/revocation and account checks and
  stop working when the flag is disabled. Staging/production reject the flag.
  No schema migration was required; a reserved `.invalid` email identity meets
  the existing contact constraint without claiming a phone number.
- Mobile account endpoints now request/verify OTP, restore sessions, update
  optional name/barangay, and revoke logout under `/api/v1/mobile/auth`. Local
  development OTP is explicitly enabled in the private local configuration;
  random codes expire after five minutes, allow five guesses, invalidate earlier
  challenges, and enforce resend plus IP/phone limits. Codes are HMAC-protected,
  phone registration is serialized in PostgreSQL, and login/profile/audits commit
  atomically. Reporter-only bearer sessions expire after thirty days, cap at five,
  and reject suspended/deleted/unverified accounts. Production OTP delivery is
  unavailable until a provider is selected; deployment rejects the development
  flag. A real SMS provider is still pending.
- Protected `/api/v1/admin/mobile-accounts` now lists real registered citizens
  with search, status filters, capped pagination, global counts, masked phones,
  actual last sign-in, and undeleted app-report totals. Manual callers, staff,
  deleted and unverified records are excluded. Both administrator tiers read;
  only Super Admins may suspend/restore. Writes recheck the actor/session, lock
  and version-check the citizen, revoke sessions, and commit a categorical-reason
  audit atomically. Restoration leaves old sessions revoked. No migration needed.
- Protected `/api/v1/admin/analytics` endpoints now provide date/type-filtered
  aggregate metrics, daily CSV export, and incident-type options to both
  administrator tiers. SQL queries group reports by received date and incidents
  by opened date in Asia/Manila, cap date ranges at 366 days, exclude deleted
  records, and keep inactive types available. Exports contain daily dates/counts
  and audit staff identity plus day count. No migration was required.
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
- Settings now reads real staff accounts and provides Administrator creation,
  identity/activation edits, confirmed deactivation and session sign-out,
  search/status filters, pagination, loading/error states, and guarded writes.
  System rules shows live session/login limits and current operational policy.
  Fake staff, localStorage saves, simulated notification tests, and nonfunctional
  settings switches were removed. Organization editing, password recovery,
  notification configuration, and retention controls remain future decisions.
- Mobile Accounts now uses the protected citizen APIs with live counts, search,
  filters, pagination, refresh, details, and loading/error/empty states. Super
  Admins confirm a reason to suspend or restore; normal Administrators have read
  access. Removed the mock records, browser-only status edits, fictional Needs
  attention state, fake last-active times, and free-text note control. Shared
  buttons now explicitly default to button type, with form submits marked, so
  Refresh/Reset cannot submit a search or account edit unexpectedly. WebStorm's
  mirror has the updated sources and no longer has the old mock data module.
  On desktop, the account roster and detail panels fill the remaining viewport
  height with pagination at the roster's bottom and a 20px bottom gutter.
  Stacked layouts retain natural height; the WebStorm mirror matches.
- Live Reports now quietly polls its queue and dashboard summary every five
  seconds while visible, refreshes on focus/reconnection and pauses polling
  while hidden. Requests do not overlap and are cancelled on query changes or
  unmount. Applied filters, page and the open report are retained, including
  when a new arrival pushes that report beyond the current page. Failed updates
  retain the loaded queue with a retry notice. Both tracked web and the running
  WebStorm copy contain this change. The report detail map spans both columns
  in the responsive detail panel at a fixed 120px minimum height and cannot
  flex-shrink when resolved-report controls expand the content. The Report
  details card scrolls internally when it exceeds the viewport space.
- The Overview report metrics, priority queue, map markers, recent-report table,
  global report search, and Live Reports queue now read from the protected
  report APIs. Overview and Incident Map share the rule that only verified
  reports with coordinates, unlinked or linked to open/dispatched/responding
  incidents, are mapped; resolved
  reports disappear from both. Resolved status badges are green. Live Reports
  supports server-side search, filters, capped
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
  team with optimistic-concurrency protection. Response Teams resolves each
  active unit assignment and displays its next lifecycle action directly on the
  left-side operational-unit card, without opening unit details. Administrators
  can record acknowledgment, responding, and completion there; confirmed
  cancellation remains in unit details. Successful changes refresh the roster,
  assignments, and shared report summaries.
  Incident Map now uses protected PostgreSQL report and assignment data instead
  of seeded markers. It maps verified reports whose incidents are unlinked,
  open, dispatched, or responding when real coordinates exist; reports without
  coordinates remain counted but are not placed at invented locations. Staff
  can filter by time, priority, incident type, and operational status, refresh
  report/team data, inspect marker details and assigned teams, toggle official
  boundary and hazard layers, and use the full-screen map.
- Historical Records now reads completed incidents from PostgreSQL, with
  server-side reference/type/location/team search, priority/type/status/date
  filters, sorting, matching counts, and pagination. Its detail panel shows the
  incident summary, lifecycle dates, linked reports, response assignments, and
  report-event timeline in independently paginated tabs. It supports refresh,
  loading/error/empty states, and audited CSV download using applied filters.
  The desktop records and detail panels stretch to the same row height for a
  balanced comparison layout, with records pagination pinned to the bottom of
  its card. The matching/resolved/closed summary cards appear above the
  filters; the Apply filters control is disabled until at least one filter
  value is entered; the responsive stacked layout is unchanged.
  The former sample records, invented outcomes, evidence downloads, export
  counters, and retention claims were removed.
- Analytics now uses protected PostgreSQL aggregates for reports received,
  verified reports, incidents opened, critical/completed incidents, daily
  volume, types, sources, priorities, and current incident statuses. Staff can
  apply 7/30/90-day presets or custom dates and incident-type filters, refresh,
  inspect an accessible daily table, and export daily aggregate CSV. Loading,
  retry, empty results, and disabled controls are implemented. Average dispatch
  time measures incident opening to the first qualifying team assignment,
  with one sample per incident and missing samples shown as an em dash. Sample
  response targets and on-scene claims have been removed.

## Mobile app

- The active mobile codebase is Flutter, not React Native.
- The user-selected iPhone build copy is `/Users/lawie/local Documents/Responda/mobile`;
  the tracked Git source remains `/Users/lawie/develop/responda/mobile`. They now
  match for application code; the Documents copy has no Git metadata and its
  generated Flutter/Xcode environment files remain path-specific.
- Normal builds still require phone OTP; when the development backend returns
  a test code, the OTP screen can submit that server-issued code through normal
  verification. Beta builds may opt in with
  `RESPONDA_BETA_SKIP_MOBILE_VERIFICATION=true`, which bypasses the phone screen
  and saves a device-local profile marked pending. With server beta mode enabled,
  its first online report obtains a beta bearer session automatically and saves
  it in secure storage for later reports/session restoration. Phone verification
  remains pending. Online/Offline
  shell selection is determined independently by device connectivity and backend
  health.
- The citizen-account flow now connects privacy acknowledgement, phone OTP,
  optional name/barangay, session restoration, and sign-out to the backend.
  Local development shows the backend-generated test code; it sends no SMS.
  The separate beta registration is explicitly opt-in on both app and backend.
  Tokens use `flutter_secure_storage` with native platform configuration;
  preferences retain only profile/expiry for offline UI, never tokens. Resume
  rechecks the session. Old local profiles without a real token must verify again.
  Retired ID/face screens, media-picker reference, and prototype code were removed
  (recoverable from Git). The optional profile form preserves recovered details.
- It has a backend health client and environment-aware base URLs, including the
  Android emulator host address. On the current iPhone/Mac pair, Wi-Fi access
  was blocked despite matching subnet/router settings; the app reached the
  backend over the wired device link when built with the Mac-side USB interface
  address. That address is dynamic; check `ipconfig getifaddr en8` before a
  wired build.
- Online report submission now uses the verified mobile bearer session and the
  protected report-creation endpoint. It stores the server report UUID and
  receipt time locally only after success, retains the client idempotency UUID
  across retries/back-to-review, and leaves the offline/SMS handoff unchanged.
  Failed sends do not show success. Photo-attached online reports are blocked
  with an explicit message until secure attachment storage/retention is chosen;
  attachments are never silently discarded or uploaded.
- The application contains onboarding, connectivity handling, reporting flows,
  localization, offline-related behavior, and tests.
- Report status/history still comes from local records rather than a protected
  reporter read API; signed SMS gateway ingestion and notification delivery are
  also not wired end to end.

## Verification history

- The 2026-10-19 save/push checkpoint reran backend Ruff, strict mypy and all
  290 tests, web lint/build, Flutter analysis and all 75 tests, plus memory and
  diff validation. All passed; the existing web bundle-size advisory remains.
  Browser inspection confirmed the Mobile Accounts desktop bottom gutter.

- Citizen management passed backend Ruff, strict mypy and 290 tests plus web
  lint/build. A rolled-back PostgreSQL rehearsal verified masked list results,
  suspension, rejected revoked sessions, restoration without reviving old tokens,
  fresh OTP recovery, and minimal audits, with no temporary users remaining.
  After the user signed in, browser checks verified the real zero-account state,
  status/search filters, reset, disabled empty pagination, and no console errors.
  No credentials were requested in chat or changed. WebStorm is synced.

- Mobile accounts passed backend Ruff, strict mypy and 256 tests, plus Flutter
  analysis and 75 tests. Migration upgrade and Alembic schema comparison passed.
  A PostgreSQL rehearsal covered signup, replay rejection, optional profile,
  suspension, recovery of the same account, logout and minimal audits, then
  rolled back all synthetic data. The iOS debug simulator build passed; the running
  backend health and new mobile routes were checked. Physical-device testing and
  real SMS delivery remain pending.

- Staff management passed Ruff, strict mypy, all 233 backend tests, and web
  lint/build. A rolled-back PostgreSQL rehearsal verified create/login,
  deactivate/reactivate, explicit session revocation, rejected revoked sessions,
  and four management audits, with no temporary staff remaining. Browser checks
  verified the real protected roster, empty creation guard, server policy, and
  no console errors. The WebStorm mirror is synced.

- Analytics passed backend Ruff, strict mypy, and all 187 tests, plus web lint
  and production build. Browser checks against PostgreSQL covered live totals,
  type and date filtering, empty results, daily detail counts, and a filtered
  CSV with 30 daily rows and the expected matching counts. The WebStorm mirror
  has the updated page, API client, and hook.

- Historical Records passed backend Ruff, strict mypy, and all 154 tests plus
  web lint and production build. Authenticated browser checks against local
  PostgreSQL covered linked-report search, priority/type/status/date filters,
  empty results, detail tabs, refresh, and a filtered CSV download. The CSV
  contained the expected operational-only columns and matching row count; a
  read-only database check confirmed independent incident/event pagination and
  the export audit. The browser console contained no errors.

- The database-backed Incident Map passed web lint and production build. Browser
  inspection against the running authenticated dashboard confirmed live
  PostgreSQL counts, the report-without-coordinates state, operational filters,
  layer controls, and the full-screen dialog. Seeded incident markers were
  removed from both the full map and shared map component.

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

- Ponytail working guidance is the default in the global local Codex profile
  (`/Users/lawie/.codex/AGENTS.md`) and Responda instructions. It uses the
  instruction-file adapter, with no plugin hooks/commands. New local Codex
  sessions load global guidance; existing unrelated chats need a new session
  to pick it up. Model-confirmation and memory protocols remain in force.
- The GitHub repository is organized as a monorepo with `mobile/`, `backend/`,
  and `web/` application folders.
- The repository root is an Obsidian vault.
- Human-written project memory is in `memory/`.
- Graphify indexes code from backend, web, mobile, and the monorepo root into one
  combined graph.
- The combined graph currently contains 2,963 code nodes, 6,020 relationships,
  and 235 detected communities. Generated graph artifacts remain local and
  ignored.
- `AGENTS.md` directs future coding sessions to read memory and query Graphify
  before broad filesystem searches.
