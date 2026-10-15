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
- Record successful and failed login decisions, logouts, and privileged changes in `audit_logs`.
  Never include a password or session token in an audit entry.

## API and data handling

- Validate and length-limit every request at the API boundary. Paginate collection endpoints and
  cap page sizes.
- Use SQLAlchemy parameters; never build SQL by concatenating user input.
- Use transactions for multi-table writes, status transitions, dispatch operations, and audit
  records that belong to the same operation.
- For staff report review, lock the pending report and require the caller's last-seen `updated_at`
  value. Reject stale or repeated decisions instead of overwriting a newer review.
- Allow only administrators and dispatchers to create incidents or link reports. Lock the report,
  require its last-seen `updated_at`, and accept only verified reports with a final priority that
  have not already been linked.
- Existing incident links must target a non-deleted open, dispatched, or responding incident with
  the same incident type. Insert a newly created incident before linking its source report, and
  commit the incident, report state, event, and audit record in one transaction.
- Staff incident lists must be authenticated, paginated, capped, non-cacheable, and exclude
  soft-deleted incidents and incident types.
- Return stable public error codes and safe messages. Log internal exceptions server-side without
  exposing stack traces, SQL, secrets, or report contents to clients.
- Allow only explicit CORS origins when cookies are enabled. Reject unsafe browser requests from
  untrusted origins.
- Treat emergency reports, phone numbers, locations, attachments, and gateway payloads as sensitive
  data. Store only what the workflow needs and never copy raw values into project memory or graphs.
- Make externally retried report and SMS ingestion operations idempotent and enforce uniqueness in
  PostgreSQL, not only in application code.

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
