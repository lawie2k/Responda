# Backend security rules

These rules apply to every major Responda backend feature. They adapt the useful safeguards from
VA101 to FastAPI and PostgreSQL; VA101's Next.js code is a reference, not code to copy.

## Authentication and sessions

- Hash passwords with Argon2id. Never store, log, return, or place passwords in URLs.
- Give browsers only a random opaque session token in an `HttpOnly`, `SameSite=Lax` cookie. Store
  only its SHA-256 hash in PostgreSQL and make sessions revocable and time-limited.
- Use generic invalid-credential errors so login does not reveal whether an email exists.
- Rate-limit login by both client IP and normalized email. The current limiter is appropriate for a
  single API process; replace it with a shared store before using multiple workers or instances.
- Do not trust `X-Forwarded-For` unless the API is behind a trusted proxy that removes incoming
  forwarding headers.
- Require a valid active staff session and an explicit allowed role on every admin operation. A
  hidden button in the web interface is not authorization.
- Allow only `admin` (Super Admin) and `operations_admin` (Administrator) accounts to create or
  retain a web-dashboard session. Dispatcher, verifier, viewer, and reporter roles do not receive
  dashboard access.
- Record successful and failed login decisions, logouts, and privileged changes in `audit_logs`.
  Never include a password or session token in an audit entry.
- Staff management is Super Admin-only and creates only normal Administrators. Reject role
  overrides and extra write fields. All Super Admin accounts are protected from editing,
  deactivation, and session revocation here, preventing self-lockout and last-admin removal.
- Staff writes lock and recheck the acting Super Admin/session, then lock and version-check
  the target. Login locks the same user row to serialize new sessions with management changes.
  Email or activation changes revoke sessions in the same transaction; explicit revocation
  also advances the account version. Keep normalized emails reserved across deleted accounts.
- Hash initial staff passwords with Argon2id. Staff responses and validation errors must never
  echo passwords, hashes, or tokens. Audit actor/target IDs, operation, and field names only.
  Staff lists are capped, searchable, no-store, and exclude deleted and citizen accounts.
- Settings exposes only non-secret current session/login limits. Operational rules are read-only
  in this release; browser-only switches are not operational configuration.

## API and data handling

- Citizen login uses `/api/v1/mobile/auth` with Philippine E.164 phone numbers,
  explicit privacy acknowledgement, random six-digit OTPs valid for five minutes,
  five guesses per challenge, a sixty-second resend cooldown, and invalidation of
  earlier codes. Code hashes use HMAC with the server secret and challenge ID.
  PostgreSQL advisory locks serialize phone registration/resend/verification;
  challenge rows are locked and consumed atomically with login.
- OTP send/verify limits also apply per IP and phone in the process-local limiter
  (five sends / ten verification attempts per ten minutes); a shared limiter is
  required before multiple API workers. Development codes are returned only when
  explicitly enabled in a local environment. Staging/production reject that flag;
  delivery and verification fail closed until a real SMS provider is implemented.
- Citizen sessions are random opaque `mobile_` bearer tokens stored only as hashes
  in PostgreSQL and in Flutter secure storage on the device, with a thirty-day
  expiry and five-session cap. Require active, undeleted, phone-verified reporter
  accounts for every mobile account operation; staff cookies do not authenticate
  them. Logout revokes the server session before clearing local state. Account
  suspension immediately rejects further API access; Flutter rechecks on resume.
  Cached unexpired identity supports offline UI only and grants no API authority.
- Mobile account endpoints use no-store responses and safe validation errors
  that do not echo phone numbers or OTPs. Profile fields are optional, bounded,
  and barangay values come from the Pantukan list. Audits contain account IDs and
  action names only, never codes, bearer tokens, or contact/profile values.
- Mobile report list/detail reads require the existing citizen bearer session
  and scope every query to that reporter's account. Return the same generic 404
  for missing, deleted, and other-account report IDs. Cap collection pagination,
  exclude soft-deleted reports/types/locations/incidents, and use no-store responses.
  Citizen tracking exposes only their report reference, incident type, description,
  landmark, current response status, and recorded milestone timestamps. Staff
  review notes, identities, unit contacts, and raw event metadata remain private.
- Local beta builds may register without OTP through `/mobile/auth/beta/register`
  only when `RESPONDA_MOBILE_BETA_ACCOUNTS_ENABLED` is explicitly enabled in
  development/testing. Staging/production reject that setting. Registration
  creates a new reporter with no phone or phone-verification timestamp, a
  reserved non-deliverable `.invalid` email identity, consent and a hashed opaque
  `mobile_beta_` session. It cannot claim an existing account or phone. These
  sessions retain expiry, revocation, active-account checks and report limits;
  they stop working when beta mode is disabled. Phone-verified dashboard account
  lists continue to exclude them. Normal mobile sessions still require OTP.
- Dashboard Mobile Accounts reads allow both administrator tiers and include only
  undeleted, phone-verified reporter accounts with privacy acknowledgement.
  Exclude manual-intake callers and staff. Mask contacts in all returned account
  rows; permit exact full-phone lookup and escaped name/barangay or UUID search.
  Cap pagination and aggregate app-report counts without multiplying session rows.
  Last sign-in is the latest session creation time, not a claimed live activity time.
- Only Super Admins may suspend/restore citizens. Recheck and lock the actor and
  target, verify the current actor session and target version, reject unsupported
  targets, unchanged state and invalid reasons, then update activation, revoke all
  sessions and audit the categorical reason atomically. Restoration does not revive
  old sessions. Mobile authentication locks the user row so OTP/profile/logout and
  account suspension serialize without locking joined session rows first. No
  arbitrary personal notes, full phone contacts, or tokens enter management audits.

- Validate and length-limit every request at the API boundary. Paginate collection endpoints and
  cap page sizes.
- Use SQLAlchemy parameters; never build SQL by concatenating user input.
- Use transactions for multi-table writes, status transitions, dispatch operations, and audit
  records that belong to the same operation.
- For staff report review, lock the pending report and require the caller's last-seen `updated_at`
  value. Reject stale or repeated decisions instead of overwriting a newer review. Reviewer notes
  and a final priority remain required for verified decisions; checklist indicators are advisory
  and may be left unchecked.
- Allow only Super Admin and Administrator accounts to review reports, create incidents, or link
  reports. Lock the report,
  require its last-seen `updated_at`, and accept only verified reports with a final priority that
  have not already been linked.
- Existing incident links must target a non-deleted open, dispatched, or responding incident with
  the same incident type. Insert a newly created incident before linking its source report, and
  commit the incident, report state, event, and audit record in one transaction.
- Staff incident lists must be authenticated, paginated, capped, non-cacheable, and exclude
  soft-deleted incidents and incident types.
- Historical reads are restricted to the two administrator tiers and resolved/closed incidents;
  list, detail, search, and export exclude soft-deleted incidents and related operational rows.
  Detail reports, assignments, and events are independently paginated. Historical responses omit
  reporter identities, contacts, attachment storage keys, and raw event metadata.
- Historical CSV exports apply the same server filters, reject more than 5,000 matching incidents,
  neutralize spreadsheet formula cells, and include only references, incident type, lifecycle dates,
  priority/status, and operational counts. Audit only the exporting staff ID and row count, never
  search text or raw report content. Date filters use inclusive calendar dates in Asia/Manila.
- Analytics reads and daily CSV exports require either administrator role and return no-store
  responses. Bound date ranges to 366 Philippine calendar days, group counts in SQL, and exclude
  deleted operational rows and incident types. Count reports by received date and distinct
  incidents by opened date; status and verification breakdowns represent their current state.
  Dispatch timing uses one earliest qualifying assignment per incident, excluding cancelled or
  deleted assignments, deleted units, and timestamps before incident opening. Analytics exports
  contain only dates and numeric aggregates; audit the staff identity and exported day count.
- Staff response-unit lists must be authenticated, paginated, capped, non-cacheable, and exclude
  soft-deleted units. Roster visibility does not grant assignment or status-transition authority.
- Only Super Admin and Administrator accounts may create or edit response-unit roster identity
  fields. Require a trusted browser origin, preserve unit status during edits, reject stale
  updates, and commit each unit write with a minimal audit record that excludes contact details.
- Only Super Admin and Administrator accounts may create or transition response assignments.
  Assignment creation must lock the incident and unit, require the incident's last-seen
  `updated_at`, accept only active incidents and available non-deleted units, and enforce at most
  one active assignment per unit in PostgreSQL.
- Assignment transitions must lock the incident, unit, and assignment, require the assignment's
  last-seen `updated_at`, and follow `assigned -> acknowledged -> responding -> completed`, with
  cancellation permitted from any active state. Administrators record radio or phone updates;
  response units do not receive dashboard accounts.
- Assignment, unit, and incident status changes, linked-report events, and minimal audit records
  must commit atomically. Completing the final active assignment resolves the incident; cancelling
  the final active assignment reopens it. Never place unit contact details in events or audits.
- Return stable public error codes and safe messages. Log internal exceptions server-side without
  exposing stack traces, SQL, secrets, or report contents to clients.
- Allow only explicit CORS origins when cookies are enabled. Reject unsafe browser requests from
  untrusted origins.
- Treat emergency reports, phone numbers, locations, attachments, and gateway payloads as sensitive
  data. Store only what the workflow needs and never copy raw values into project memory or graphs.
- Make externally retried report and SMS ingestion operations idempotent and enforce uniqueness in
  PostgreSQL, not only in application code.
- Allow only Super Admin and Administrator accounts to encode manual reports. Require a trusted
  browser origin, an active database incident type, normalized phone contact, bounded written
  location and description fields, and all safety indicators. Create the caller record when needed,
  report, written location, report event, and minimal audit entry in one transaction; do not copy
  caller contact, location text, or incident details into audit metadata.

## Deletion and retention

SMS ingestion uses the [RSP1 contract](sms-gateway.md). Keep gateway bearer secrets
separate from citizen installation keys. Registration requires a verified consenting
reporter; gateway creation/rotation/revocation requires a rechecked Super Admin
session. Recheck gateway, account and installation state on delivery. Suspension
revokes installation keys atomically with sessions. Never accept a prefix, sender
number, or beta profile as SMS authentication. Verify the exact HMAC envelope before
parsing; enforce expiry, sender binding, input bounds and replay constraints. Commit
accepted reports and receipts together; never retain rejected bodies or log SMS/key
material. HMAC proves a registered credential, not an attested app binary.

- Mutable operational records use nullable `deleted_at` timestamps. Normal authentication and API
  queries must exclude rows whose `deleted_at` is set unless an explicitly authorized historical
  or restoration workflow requests them.
- Use the model `soft_delete()` and `restore()` methods for operational records; do not issue hard
  deletes from ordinary product endpoints.
- Authentication sessions and OTP challenges use revoke, consume, and expiry lifecycle fields
  instead of soft deletion. Audit logs, report events, reviews, translations, and priority
  assessments are immutable history and must not be silently deleted.
- Soft deletion is not anonymization. Any privacy-driven erasure or attachment-retention workflow
  needs separate, explicit rules and audit coverage.

## Change requirements

- Add success, rejection, authorization, and validation tests for each endpoint group.
- Run `make check` before considering backend work complete.
- Review authentication, authorization, audit, and transaction behavior whenever a schema or role
  changes.
