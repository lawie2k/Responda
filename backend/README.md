# Responda Backend

Backend service for the Responda emergency reporting platform.

## Requirements

- Python 3.13
- PostgreSQL 18

## Local setup

Create the local virtual environment and install the development dependencies:

```bash
make install-dev
```

Activate the environment when running commands manually:

```bash
source .venv/bin/activate
```

Copy the example environment file before changing local settings:

```bash
cp .env.example .env
```

The committed defaults are suitable only for local development. Replace the secret key and disable
debug mode before using a staging or production environment. Keep the real `.env` file private.

The PostgreSQL URL uses this format:

```text
postgresql+psycopg://USERNAME:PASSWORD@HOST:PORT/DATABASE
```

## Start the development server

```bash
make run
```

When testing from a physical phone on the same Wi-Fi network, expose the development server to the
local network instead:

```bash
make run-mobile
```

The interactive API documentation will be available at `http://127.0.0.1:8000/docs`.

Check that the API is running:

```bash
curl http://127.0.0.1:8000/api/v1/shared/health
```

The health response reports `database: ok` when PostgreSQL is reachable. It returns HTTP 503 with
`database: unavailable` when the configured database cannot be reached.

## Staff dashboard authentication

Create the first staff account interactively after applying the migrations. The password is entered
through a hidden prompt, must contain at least 8 characters, and is never passed as a command-line
argument:

```bash
make create-admin ARGS='--email admin@example.com --full-name "Responda Admin" --role admin'
make create-admin ARGS='--email operator@example.com --full-name "Operations Admin" --role operations_admin'
```

The `admin` database role is displayed as **Super Admin**. The
`operations_admin` role is displayed as **Administrator**. These are the only
roles allowed to create a staff-dashboard session; legacy dispatcher, verifier,
and viewer values do not receive dashboard access.

The admin API exposes:

- `POST /api/v1/admin/auth/login`
- `GET /api/v1/admin/auth/me`
- `POST /api/v1/admin/auth/logout`
- `GET /api/v1/admin/reports`
- `GET /api/v1/admin/reports/{report_id}`
- `POST /api/v1/admin/reports/{report_id}/reviews`
- `GET /api/v1/admin/incidents`
- `POST /api/v1/admin/incidents`
- `POST /api/v1/admin/incidents/{incident_id}/reports`
- `GET /api/v1/admin/incidents/{incident_id}/assignments`
- `POST /api/v1/admin/incidents/{incident_id}/assignments`
- `POST /api/v1/admin/assignments/{assignment_id}/transitions`
- `GET /api/v1/admin/response-units`
- `POST /api/v1/admin/response-units`
- `PATCH /api/v1/admin/response-units/{unit_id}`

The login response sets an opaque `HttpOnly` session cookie. Browser requests from the web app must
include credentials. Security requirements for this and future endpoint groups are documented in
[`docs/security-rules.md`](docs/security-rules.md).

## Database migrations

Apply the current database schema:

```bash
make migrate
```

After intentionally changing the SQLAlchemy models, create the next migration with a short name:

```bash
make migration m="describe the change"
```

The first schema contains the reporting, incident verification, ML result, SMS gateway, dispatch,
notification, authentication, and audit tables. The SMS policy and table responsibilities are
documented in [`docs/database-design.md`](docs/database-design.md).

## Development commands

```bash
make test       # Run automated tests
make lint       # Check code quality
make format     # Format Python files
make typecheck  # Run static type checking
make check      # Run linting, type checking, and tests
```
