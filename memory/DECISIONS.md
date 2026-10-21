---
tags:
  - responda/memory
  - responda/decisions
updated: 2026-10-21
---

# Decisions

## Active decisions

### 2026-10-21 — Track citizen reports from protected server state

- List/detail reads use the existing mobile bearer session and reporter ownership
  on every query. Missing, deleted and other-account IDs share a generic 404;
  collections are capped, paginated and no-store. Internal reviews, staff
  identities, unit contacts and raw event metadata are excluded.
- My Reports polls every five seconds only while visible and resumed, retains
  the open report and bottom navigation, and discloses stale results on failure.
  Online history comes from the account, not device-local receipts. Saved offline
  reports keep their existing local behavior.
- Completed contains resolved and closed reports. The journey uses real review
  and response timestamps and Team responding rather than claiming arrival on
  site, since the current staff lifecycle records no arrival state.

### 2026-10-20 — Poll Live Reports without resetting the staff workspace

- Use existing authenticated report reads every five seconds on the visible
  Live Reports page, including summary counts. Pause while hidden; resume on
  focus, visibility and network reconnection. Fetch serially with abort cleanup
  instead of adding a push transport for this stage.
- Keep applied filters, pagination and selected detail stable. Retain loaded
  rows on transient failures and disclose stale results while retrying.

### 2026-10-20 — Allow skipping OTP entry with the server's development code

- Only the OTP screen offers “Continue with test code,” and only when the
  development backend returns its test OTP. The app submits that server-issued
  code through the ordinary OTP verification endpoint, then continues to
  optional profile setup. Phone-number entry still requires requesting a code;
  there is no client-created verified identity or account.
- Production has no development code, so the shortcut is not displayed and
  users must enter the OTP they receive. Online/Offline shell selection depends
  on network access and backend health, independently of authentication.

### 2026-10-20 — Offer an opt-in local beta profile without an OTP sender

- A beta build may bypass the phone-number step using
  `RESPONDA_BETA_SKIP_MOBILE_VERIFICATION=true`, then save optional name and
  barangay locally and enter the app. With backend
  `RESPONDA_MOBILE_BETA_ACCOUNTS_ENABLED=true`, its first report may register a
  fresh beta reporter and session without OTP. This account remains phone-
  unverified; it cannot claim an existing account. The server rejects beta mode
  in staging/production and refuses beta sessions when the flag is disabled.
  Report validation, rate limits, receipt/idempotency and staff review still
  apply. Beta reporters stay outside the phone-verified Mobile Accounts roster.

### 2026-10-20 — Use the wired iPhone link when local Wi-Fi blocks the API

- The current iPhone can reach the development backend over its direct wired
  link. Read the Mac-side interface address dynamically (`ipconfig getifaddr
  en8`) and pass it as `RESPONDA_API_BASE_URL`; do not hardcode the temporary
  link-local address. Online status means API/DB health, not account verification.

### 2026-10-20 — Build mobile from the user's Documents copy and retain Git source

- Use `/Users/lawie/local Documents/Responda/mobile` as the user's local Flutter
  build location while retaining `/Users/lawie/develop/responda/mobile` in the
  Responda monorepo for version control. The build copy has no Git metadata.
- Keep application sources synchronized between the two locations before Git
  commits; do not copy path-specific generated Flutter/Xcode environment files.

### 2026-10-20 — Submit online mobile reports through verified accounts

- Online API submissions require the existing verified, active reporter session;
  each report has a client UUID for idempotent retries and is created as `app_api`
  with location, safety answers, event, and minimal audit in one transaction.
- Do not silently drop selected photos. Online photo submission stays blocked
  until secure storage and retention are decided. Offline/SMS remains separate.
- The API provides creation and server receipt only; live reporter status/history
  still needs a protected read API. No database migration was required.

### 2026-10-19 — Keep breathing room below the Mobile Accounts panels

- Desktop roster and account details fill the remaining viewport with a 20px
  bottom gutter. Keep pagination at the roster's bottom and natural stacked
  heights below the desktop breakpoint.

### 2026-10-19 — Connect dashboard citizen monitoring and Super Admin suspension

- Both administrator tiers may monitor registered mobile citizens. Only Super
  Admins suspend/restore; this follows the existing account-management authority.
  Registration requires phone verification plus privacy acknowledgement, keeping
  staff and manually encoded callers out of the Mobile Accounts roster.
- Expose masked phone data and exact full-phone lookup; name/barangay and full
  account UUID are searchable. Show real last sign-in and app-report totals,
  with active/suspended states only. Do not invent live activity or attention flags.
- Require explicit confirmation, a last-seen account version and a categorical
  reason (misuse/security for suspension, completed review for restoration).
  Recheck the Super Admin/session, serialize on user rows, revoke sessions and
  save minimal reason audits atomically. Restoring never revives old tokens;
  citizen OTP sign-in is required again. No free-text personal notes are stored.

### 2026-10-19 — Build local OTP before choosing real SMS delivery

- User selected development OTP first; real SMS provider selection remains open.
  Return random codes only with the explicit local development flag; reject that
  flag in staging/production and fail closed without a delivery provider.
- OTP uses five-minute expiry, five guesses, one-minute resend cooldown, old-code
  invalidation, IP/phone limits, HMAC storage, and serialized phone registration.
  Acknowledge privacy using server time during verification. Reuse existing
  reporter accounts; reject staff, inactive, and deleted identities.
- Mobile uses hashed opaque bearer sessions (thirty days, maximum five), device
  secure storage for tokens, and cached unexpired profile data for offline UI.
  Legacy preference-only profiles are not authenticated. Server logout must
  succeed, or confirm the session already invalid, before local state is cleared.
  Recheck account/session on resume; optional name/barangay persist in PostgreSQL.
  ID/face capture has been removed from the source flow.

### 2026-10-19 — Use Ponytail guidance by default across Codex chats

- Adopt the smallest complete solution, reuse existing patterns, keep responses
  concise, and preserve validation, security, accessibility, and required checks.
- Persistent instruction-file guidance is in `/Users/lawie/.codex/AGENTS.md`
  for future local Codex sessions; Responda's root and coordination instructions
  also capture the preference. The reviewed upstream revision is
  `09c434ab73ca43761c5d8b0c5d341926c2fba710` from DietrichGebert/ponytail.
- This is the supported rules-file adaptation, not installed plugin commands
  or lifecycle hooks. Do not re-download upstream each prompt. Preserve the
  existing per-action model recommendation and confirmation requirement.

### 2026-10-19 — Protect Super Admins in the first staff-management release

- Super Admins manage only normal Administrators through Settings. All Super
  Admins are protected from editing, deactivation, and session revocation here.
  Role promotion and citizen management are outside this API.
- Creation accepts name, email, and initial password. Edits accept identity and
  activation with a concurrency timestamp. Password recovery and editable
  organization/notification/retention policies need separate product choices.
- Email or activation changes revoke sessions. Explicit sign-out revokes
  sessions while allowing later login if active. Account, session, and minimal
  audit changes commit together; login shares user locking.
- Show current operational rules and non-secret session/login limits read-only.
  Remove controls that only simulate backend behavior.

### 2026-10-19 — Define Analytics cohorts and dispatch timing explicitly

- Reports belong to a period by received date; incidents belong by opened date,
  with dates and daily buckets in Asia/Manila and a maximum 366-day range.
- Verification and incident priority/status show the current state of those
  cohorts; several reports linked to an incident never multiply incident counts.
- Average dispatch time is incident opening to its earliest qualifying team
  assignment, one sample per incident. Exclude cancelled/deleted assignments,
  deleted units, and pre-opening timestamps. Display missing timings as unknown.
- Export only dates and numeric daily aggregates, with minimal staff/day-count
  auditing. Do not invent response targets or on-scene metrics.

### 2026-10-18 — Recommend the lowest sufficient model before each new task

- Before substantive work on a new task, state the recommended model and
  reasoning level, then wait for the user to switch or confirm.
- Use Luna for scoped edits and routine work, GPT-6.1 Sol for normal complex
  implementation and debugging, and Astra only for unusually demanding,
  security/privacy-critical, or release-critical work.
- Keep one chat focused on one feature through verification. At a meaningful
  milestone or component change, save project memory and begin a fresh chat
  that reads `AGENTS.md` and memory instead of replaying the full transcript.
- Do not claim the active model changed automatically; model selection remains
  under the user's control.
- Repeat the recommendation before every separate user-requested action,
  including follow-ups within the same feature, then wait for confirmation.

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

### 2026-10-18 — Map only verified operational reports with real coordinates

- Incident Map uses protected report and active-assignment data; seeded
  incidents are not mixed with operational records. Overview shares the same
  map eligibility predicate, so resolved/closed incidents leave both maps.
- A verified, unlinked report and a report linked to an `open`, `dispatched`, or
  `responding` incident are eligible for the live map.
- Every mapped point represents a report location. Several reports linked to
  the same incident may therefore remain visible while the coverage summary
  counts the incident once.
- Reports without paired latitude and longitude remain visible in operational
  counts and Live Reports but are never assigned an invented map location.
- Marker color communicates final/effective priority; the popup provides the
  report reference, location, barangay, status, source, received time, and any
  active response-team assignment.

### 2026-10-19 — Keep historical incidents factual and exports minimal

- Historical Records contains one row per non-deleted resolved or closed
  incident. Active incidents and unlinked reports remain in operational views.
- The two administrator tiers can inspect historical linked reports,
  assignments, and events, with separate capped pagination for each collection.
  Historical responses omit reporter contacts, identities, attachment storage
  keys, and raw event metadata.
- Date filters use inclusive Philippine calendar dates based on the closed
  timestamp, then resolved timestamp; legacy rows without either use their
  last update. Incident types remain filterable after becoming inactive.
- Display actual status, summary, lifecycle dates, and assignment completion;
  do not invent outcome narratives or downloadable evidence.
- CSV includes references, incident type, priority/status, UTC lifecycle dates,
  and report/team/completed-assignment counts. It omits report text, exact
  locations, and contacts, escapes spreadsheet formulas, rejects exports over
  5,000 incidents, and records the exporting staff identity and row count in
  the audit log without search text.

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
- Verified decisions require reviewer notes and a final priority. The location,
  duplicate, callback, and classification checklist indicators are advisory;
  staff may leave any or all of them unchecked without blocking the decision.
  Verified and unverified reports move to `under_review`; invalid reports are
  closed and do not retain a final emergency priority.
- The report update, `report_reviews` row, `report_events` row, and `audit_logs`
  row commit together. Audit/event metadata excludes reviewer notes and raw
  report content.

### 2026-10-16 — Treat staff-encoded reports as pending manual intake

- Only Super Admin and Administrator accounts may encode a manual report.
- Manual reporter phone numbers must be Philippine mobile numbers and are stored
  canonically as `+639XXXXXXXXX`; local `9XXXXXXXXX`, `09XXXXXXXXX`, and
  country-code input normalize to the same value.
- The selected incident type must be an active database record; the dashboard
  does not use hard-coded type identifiers.
- Phone call, walk-in, radio communication, and other offline intake channels
  are stored separately from the report's `manual` technical source.
- A manual report may store a written landmark without pretending that staff
  received GPS coordinates. Coordinates remain paired when they are present.
- Newly encoded reports enter the normal `pending`/`new` validation queue. The
  incident type's default priority is used for queue display until advisory ML
  scoring exists; staff verification remains authoritative.
- Caller contact and raw emergency/location text are excluded from audit
  metadata. Report, location, event, audit, and any new caller commit together.

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
- For an unlinked verified report, the dashboard presents response-team
  selection first. Saving that assignment creates the incident automatically
  and then assigns the selected team; incident creation remains an internal
  persistence boundary instead of a separate staff-facing step. Linking to an
  existing incident is only for duplicate reports about the same emergency.
  Acknowledgment, responding, and completion actions appear on the assigned
  unit's operational roster card so staff can update status without opening
  details. Confirmed cancellation remains in unit details. Both surfaces read
  and refresh server state; neither derives lifecycle state only in the browser.

### Use strict app-only SMS ingestion

Only a valid, structured, signed SMS generated by the Responda app may create a
report. Ordinary messages received by the gateway phone must not appear as
dashboard emergencies. Sender number alone is not accepted as proof of origin.

### 2026-10-16 — Use phone OTP for citizen accounts

- A citizen account is established by verifying a phone number with a one-time
  password.
- Name and barangay are optional profile fields. Government-ID submission, face
  capture, and staff identity approval are not part of registration.
- The verified account/session becomes the reporter-identity boundary for
  online reports. Phone numbers remain protected personal data and should be
  masked in ordinary administrative lists.
- Existing Flutter ID and face-verification screens are legacy UI and should be
  removed when the mobile-account flow is connected to the backend.

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
