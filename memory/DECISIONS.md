---
tags:
  - responda/memory
  - responda/decisions
updated: 2026-10-15
---

# Decisions

## Active decisions

### 2026-10-16 — Use two administrator tiers for dashboard operations

- Keep the existing `admin` database value and display it as **Super Admin**.
- Add `operations_admin` as the database value for normal administrators.
- Super Admin and Administrator use the same staff dashboard and may assign
  response teams; dispatcher accounts do not receive their own dashboard or
  assignment authority.
- A responder means a response unit/team, not an individual responder account.
- Begin assignment from the relevant verified report in the UI, but persist the
  assignment against its incident so multiple reports of one emergency do not
  cause duplicate deployments.
- Super Admin retains staff-account and system-configuration authority; normal
  administrators handle operational reports, incidents, teams, and assignments.

### 2026-10-16 — Use a restrained civic dashboard hierarchy

- Maroon is the single brand accent over warm neutral surfaces throughout the
  authenticated staff workspace.
- Priority, availability, verification, and health colors remain available only
  where they communicate real operational meaning.
- Avoid decorative gradients, equal-weight colored icon tiles, and default card
  shadows; reserve shadows for floating menus and overlays.
- Shared UI components establish the hierarchy across every dashboard tab so
  new pages inherit the same visual language.

### 2026-10-15 — Use a hybrid project-memory system

- Obsidian notes store concise human-readable state, decisions, architecture,
  next steps, and work outcomes.
- Graphify stores generated relationships between code symbols and files.
- Future agents should read the small memory index first and query the graph
  before performing broad source searches.
- Raw prompts and full chat transcripts are not copied into project memory.

### Mobile framework — Flutter

The mobile application at `/Users/lawie/develop/responda/mobile` is the active
implementation. Older documentation that recommends React Native is
superseded and should not drive new implementation work.

### 2026-10-15 — Use a three-application monorepo

The GitHub repository uses `mobile/`, `backend/`, and `web/` as top-level
application folders. Shared project memory and maintenance scripts remain at
the repository root.

### 2026-10-15 — Treat `save` as an explicit memory checkpoint

When the user types `save`, update all relevant project-memory notes with the
material context since the previous checkpoint and refresh Graphify when code
changed. Exclude raw transcripts and sensitive data. Saving does not imply a
Git commit or push.

### Backend and database — Python/FastAPI with PostgreSQL

The backend uses Python 3.13, FastAPI, async SQLAlchemy, Alembic, and PostgreSQL.
Mobile and web share the backend while keeping separate API namespaces.

### 2026-10-15 — Use revocable opaque sessions for the staff dashboard

- Staff passwords use Argon2id.
- Staff passwords require at least 8 characters.
- The browser receives a random session token only in an `HttpOnly`,
  `SameSite=Lax` cookie; PostgreSQL stores only the token hash.
- Staff login is limited per IP address and normalized email, with generic
  invalid-credential responses and authentication audit records.
- The current in-process limiter is approved only for a single API process and
  must move to a shared store before multi-worker or multi-instance deployment.
- `backend/docs/security-rules.md` is the required baseline for future major
  endpoint groups.

### 2026-10-15 — Guard authenticated dashboard history

- The web application cannot disable the browser Back control, so it uses
  replace-state navigation plus an authenticated history guard.
- Repeated Back actions stay on the dashboard while a session is active.
- After logout, the backend session is revoked and history navigation cannot
  reveal protected dashboard content.
- Session-scoped storage and RESPONDA Cache Storage entries are cleared when a
  user logs in or out; organization settings in persistent local storage are
  not erased as part of session handling.

### Separate reports from confirmed incidents

Each submission is a report. Staff may connect several reports to one confirmed
incident. Dispatch assignments point to the incident to prevent duplicate
dispatches.

### 2026-10-16 — Minimize data in staff report reads

- Report-list responses contain operational report data but no reporter contact
  details.
- Reporter identity and contact details are available only through the protected
  single-report detail endpoint.
- Attachment records do not expose internal storage keys or checksums; a future
  authorized download mechanism must provide safe access separately.
- Report reads use no-store browser responses and capped server pagination.

### 2026-10-16 — Soft-delete mutable operational records

- Users, incident types, incidents, reports, report locations, report
  attachments, SMS gateways/messages, response units/assignments, and
  notifications use nullable `deleted_at` timestamps and remain recoverable.
- Normal authentication and API queries exclude soft-deleted rows. Historical
  inclusion or restoration must be explicit and authorized.
- Existing uniqueness and idempotency constraints remain reserved after soft
  deletion to prevent identity, device, and report-identifier reuse; restoration
  updates the original row instead of creating a conflicting replacement.
- Sessions and OTP challenges retain their revoke, consume, and expiry lifecycle
  fields. Audit logs, report events/reviews, translations, and priority
  assessments remain immutable history rather than using soft deletion.
- Soft deletion does not anonymize personal data; privacy erasure and file
  retention require a separate approved workflow.

### 2026-10-16 — Make report review an atomic, role-restricted decision

- Only `admin` and `operations_admin` may submit report-review decisions.
  Legacy dispatcher, verifier, and viewer roles cannot authenticate to the
  dashboard.
- Reviews accept only pending, non-deleted reports. The write locks the report
  and compares the detail response's `updated_at` value to prevent stale staff
  screens from overwriting newer decisions.
- Verified decisions require a final priority and confirmed location. Verified
  and unverified reports move to `under_review`; invalid reports are closed and
  do not retain a final emergency priority.
- The report update, `report_reviews` row, `report_events` row, and `audit_logs`
  row commit together. Audit/event metadata excludes reviewer notes and raw
  report content.

### 2026-10-16 — Restrict incident creation and report linking

- Only `admin` and `operations_admin` may create incidents or link reports.
- Either authenticated administrator tier may read the capped incident list.
- A report must be verified, have a final priority, remain under review, and be
  unlinked. The caller must provide its last-seen `updated_at` value.
- New incidents inherit the verified report's incident type and final priority.
  Existing links require the same incident type and an incident whose status is
  `open`, `dispatched`, or `responding`.
- Incident/report updates, report events, and audit records commit atomically.
  Audit metadata excludes the incident summary and raw report content.

### 2026-10-16 — Keep response-unit roster reads separate from dispatch writes

- Either authenticated administrator tier may read the capped response-unit
  roster and global readiness counts for operational visibility.
- Roster reads exclude soft-deleted units and use non-cacheable responses.
- The web dashboard must show database truth, including a genuine empty state,
  instead of inventing local response teams or simulated activity.
- Super Admin and Administrator accounts may create units or edit roster
  identity fields. New units start as `available`; edits use the last-seen
  `updated_at`, preserve operational status, and commit with a minimal audit
  record that excludes contact values.
- Incident assignment and unit-status transitions use dedicated endpoints with
  their own role, transaction, concurrency, and audit rules.

### 2026-10-16 — Use an administrator-recorded assignment lifecycle

- Assignments belong to incidents, even when initiated from a linked report, so
  duplicate reports do not dispatch duplicate response teams.
- Only Super Admin and Administrator accounts manage assignments. Response
  teams do not receive dashboard accounts; administrators record confirmations
  received through radio or phone.
- The required sequence is `assigned -> acknowledged -> responding ->
  completed`. Cancellation is allowed from any active state, but other skipped
  or backward transitions are rejected.
- Assignment creation locks the incident and unit, uses the incident's
  last-seen `updated_at`, and accepts only available units and active incidents.
  A PostgreSQL partial unique index prevents one unit from holding two active
  assignments.
- Every transition locks the assignment, unit, and incident and uses the
  assignment's last-seen `updated_at`. Changes to all three records plus linked
  report events and a minimal audit entry commit in one transaction.
- Completing the final active assignment resolves the incident and releases the
  unit. Cancelling the final active assignment reopens the incident and releases
  the unit. Other active teams keep the incident dispatched or responding.
- The dashboard starts dispatch from a report that is already linked to an
  active incident, while acknowledgment, responding, completion, and
  cancellation are recorded from the assigned unit's Response Teams detail.
  Both surfaces read and refresh server state; neither derives lifecycle state
  only in the browser.

### Use strict app-only SMS ingestion

Only a valid, structured, signed SMS generated by the Responda app may create a
report. Ordinary messages received by the gateway phone must not appear as
dashboard emergencies. Sender number alone is not accepted as proof of origin.

### ML remains advisory

Translation and priority assessment outputs are stored separately from the
original report and final staff-confirmed priority. The exact model remains to
be recorded after the approved design is confirmed.

### Never put secrets in project memory

The workspace may record environment-variable names and setup instructions, but
never actual passwords, signing keys, database URLs containing credentials,
tokens, private identity data, or real emergency content.

## Proposed but not final

- Exact SMS cryptographic signing and device-key provisioning design.
- Remaining incident, dispatch, reopening, and report-status transition rules.
- Exact ML model, deployment format, and acceptance thresholds.
- Production hosting and deployment topology.
