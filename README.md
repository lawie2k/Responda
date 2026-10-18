# Responda

Responda is an emergency-reporting platform for Pantukan. This repository is a
monorepo containing the citizen mobile application, shared backend, and MDRRMO
web dashboard.

## Repository structure

```text
Responda/
├── mobile/   Flutter citizen application
├── backend/  Python/FastAPI API and PostgreSQL database layer
├── web/      React/Vite MDRRMO dashboard
├── memory/   Obsidian project memory
└── scripts/  Project-memory and Graphify maintenance
```

## Run locally

Start the backend:

```bash
cd backend
cp .env.example .env
make install-dev
make migrate
make run
```

Start the web dashboard in another terminal:

```bash
cd web
npm install
npm run dev
```

Run the Flutter app from another terminal:

```bash
cd mobile
flutter pub get
flutter run
```

The backend API documentation is available at `http://127.0.0.1:8000/docs` and
the web dashboard uses `http://localhost:5173` by default.

## Mobile account development

Run `make migrate` inside `backend/` before using phone accounts. For local OTP
testing, set `RESPONDA_MOBILE_DEV_OTP_ENABLED=true` in the private backend `.env`
and restart the API if it is already running. Complete the privacy notice in
Flutter, enter a Philippine mobile number, and use the random development code
shown on the OTP screen. No SMS is sent in this mode. Codes expire after five
minutes, allow five guesses, and can be resent after sixty seconds.

Verification creates or recovers the same phone account. Name and barangay are
optional. Tokens use device secure storage; cached profiles alone cannot sign
in. Account Management provides server-backed sign-out. Old prototype accounts
must verify again. Staging/production reject development OTP; a real delivery
provider is still required before enabling production phone login.

## Project memory and code graph

Start with [memory/INDEX.md](memory/INDEX.md). This repository root can also be
opened as an Obsidian vault.

Build or refresh the local Graphify code graph with:

```bash
./scripts/update-project-graph.sh all
```

Generated Graphify outputs and all private `.env` files are ignored by Git.
