---
tags:
  - responda/memory
  - responda/planning
updated: 2026-10-16
---

# Next steps

The next backend-focused sequence is:

1. Add the `operations_admin` role, present the existing `admin` role as Super
   Admin, and restrict dashboard authentication and permissions to the approved
   administrator tiers.
2. Define and implement response-unit assignment and dispatch lifecycle
   transitions with role checks, concurrency protection, and audit history.
3. Connect response-team assignment and lifecycle actions to those real web
   dashboard endpoints.
4. Freeze the mobile report request/response contract and report status values.
5. Implement the minimum authentication or reporter-identity boundary needed by
   report submission.
6. Implement incident-type listing and online mobile report submission with
   idempotency through `client_report_id`.
7. Wire the Flutter report flow to the online submission endpoint.
8. Finalize the signed SMS protocol and then implement gateway ingestion.
9. Confirm the approved ML model and implement translation/priority inference
   behind a replaceable service interface.

Before database or API implementation continues, confirm product rules that
would change the schema: required reporter identity, anonymous-report policy,
status transitions, staff roles, attachment retention, and SMS signing/key
provisioning.
