---
tags:
  - responda/memory
  - responda/product
updated: 2026-10-15
---

# Project overview

Responda is an emergency-reporting platform for Pantukan. Residents use an
Android-first Flutter app to prepare and submit reports. Reports use the API
when data connectivity is available and may use an app-generated SMS fallback
when mobile data is unavailable. MDRRMO staff use a separate web dashboard to
verify reports, group duplicate reports into incidents, dispatch response
units, and record status changes.

The system must not imply that submitting a report guarantees dispatch or
replaces official emergency numbers and instructions.

## Products

- [[PROJECT_MAP#Backend]] — shared FastAPI service and PostgreSQL database.
- [[PROJECT_MAP#Mobile app]] — Flutter citizen application.
- [[PROJECT_MAP#Web dashboard]] — React/Vite MDRRMO staff interface.
- [[ARCHITECTURE#SMS fallback]] — gateway path for app-created offline reports.
- [[ARCHITECTURE#Machine learning boundary]] — advisory ML results with staff
  confirmation.

## Current MVP boundary

- Citizen report creation with location and optional supporting information.
- Online API delivery and user-confirmed SMS fallback.
- Staff verification and incident management in the web dashboard.
- Report status history and notifications.
- Offline emergency information in the mobile application.

Live responder tracking, public social feeds, and autonomous ML decision-making
are outside the current MVP.
