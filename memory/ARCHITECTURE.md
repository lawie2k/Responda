---
tags:
  - responda/memory
  - responda/architecture
updated: 2026-11-05
---

# Architecture

## Main online flow

```text
Flutter mobile app
  -> FastAPI mobile API
  -> PostgreSQL reports and locations
  -> staff verification in the web dashboard
  -> confirmed incident
  -> response-unit assignment and report events
  -> status returned through protected reporter reads and foreground polling
```

Staff browser Web Push is implemented with session-bound subscriptions and a
backend retry worker; actual browser delivery remains to be tested. Citizen push
notifications remain pending. Status polling is implemented for mobile report
history and the web Live Reports workspace.

The web and mobile applications share one backend, but use separate route
namespaces under `/api/v1`. Shared endpoints, such as health checks, live under
`/api/v1/shared`.

## Report versus incident

A report is one citizen or staff submission. An incident is the confirmed
emergency managed by staff. Several reports may point to one incident so that
duplicate reports do not create duplicate dispatches. Response assignments
belong to incidents, not individual reports.

## SMS fallback

Offline reports created by the Responda app use a structured, versioned SMS
payload. The gateway must accept a message as a report only when it includes:

- a supported protocol version;
- an app-generated `client_report_id`;
- a valid HMAC-SHA256 authentication tag from a registered installation;
- a payload that passes validation; and
- a gateway message identifier that has not already been processed.

Ordinary or invalid messages do not create reports; valid duplicates reuse the
existing report. Invalid bodies are discarded and accepted receipts keep
fingerprints rather than duplicate message text. Phone-number filtering alone
is insufficient: the tag must authenticate an active, account-bound key.

The backend, citizen signing, secure installation provisioning, and separate
Android gateway queue are implemented. Real SIM messages were accepted during
the recorded local USB tests. Untethered operation and further physical failure
tests remain pending. See `backend/docs/sms-gateway.md` and
`mobile/docs/sms-testing.md`. Citizen saved drafts do not yet automatically sync
through the online API when connectivity returns; gateway queue retry is a
separate implemented flow.

## Machine learning boundary

The schema separates machine output from staff decisions:

- `report_translations` preserves translated text while the report keeps the
  reporter's original description.
- `priority_assessments` stores an ML recommendation, model version, and
  confidence.
- staff confirm the final priority on the report.
- the reporter selects the incident type and staff may verify it; ML does not
  silently replace that choice.

The ML packages are currently empty scaffolds; training, preprocessing,
inference, evaluation, and dataset preparation are not implemented in the
inspected project locations. The revised manuscripts propose TF-IDF incident
classification and hybrid priority support, while project decisions keep the
reporter's selected category authoritative. Reconcile the recommendation role
and the conflicting priority-model descriptions before implementation.

## Data model scope

The current backend models contain 19 tables covering users and sessions,
reports and incidents, locations and attachments, translation and priority
assessment, staff review, SMS gateways and messages, response units and
assignments, events, notifications, and audit logs. Notification, translation,
and assessment tables do not establish working delivery or ML services.
Locations currently use validated decimal latitude/longitude columns;
PostGIS spatial columns and cloud RDS deployment remain pending.

## 2026-11-05 non-ML operations expansion

- admin/operations.py supplies authenticated spatial aggregates, versioned report
  corrections and staff-specific alert receipts; no ML inference is involved.
- report_photos.py handles owned mobile uploads and private staff reads. Files
  live outside public web roots, are sanitized and expire by configured retention.
- web_push.py sends encrypted generic alerts to validated browser providers only
  while the owning staff session is active. A service worker opens the report;
  a database cursor/retry time survives API restarts. Keys remain private/local.
- Assignment On Site records on_site_at while incident/unit status stays
  responding. Staff history and reporter status timelines expose the milestone.
