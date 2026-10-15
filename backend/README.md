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
