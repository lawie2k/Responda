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
- Return stable public error codes and safe messages. Log internal exceptions server-side without
  exposing stack traces, SQL, secrets, or report contents to clients.
- Allow only explicit CORS origins when cookies are enabled. Reject unsafe browser requests from
  untrusted origins.
- Treat emergency reports, phone numbers, locations, attachments, and gateway payloads as sensitive
  data. Store only what the workflow needs and never copy raw values into project memory or graphs.
- Make externally retried report and SMS ingestion operations idempotent and enforce uniqueness in
  PostgreSQL, not only in application code.

## Change requirements

- Add success, rejection, authorization, and validation tests for each endpoint group.
- Run `make check` before considering backend work complete.
- Review authentication, authorization, audit, and transaction behavior whenever a schema or role
  changes.
