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

## API and data handling

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
