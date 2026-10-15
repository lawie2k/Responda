---
tags:
  - responda/memory
  - responda/architecture
updated: 2026-10-15
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
  -> status/notification returned to the reporter
```

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
- a valid digital signature;
- a payload that passes validation; and
- a gateway message identifier that has not already been processed.

Ordinary SMS messages, malformed payloads, duplicate messages, and invalid
signatures must not create dashboard emergencies. They may be retained in the
gateway log with a rejected, duplicate, or error status for auditing.

Phone-number filtering alone is not sufficient because numbers may be spoofed.
The exact key-provisioning and signing protocol still needs a security design
before the SMS path is implemented.

## Machine learning boundary

The schema separates machine output from staff decisions:

- `report_translations` preserves translated text while the report keeps the
  reporter's original description.
- `priority_assessments` stores an ML recommendation, model version, and
  confidence.
- staff confirm the final priority on the report.
- the reporter selects the incident type and staff may verify it; ML does not
  silently replace that choice.

The exact production ML model is not recorded in this workspace yet. It must be
added to [[DECISIONS]] after it is confirmed from the approved design.

## Data model scope

The initial backend models contain 18 tables covering users and sessions,
reports and incidents, locations and attachments, translation and priority
assessment, staff review, SMS gateways and messages, response units and
assignments, events, notifications, and audit logs.
