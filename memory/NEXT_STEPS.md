---
tags:
  - responda/memory
  - responda/planning
updated: 2026-10-16
---

# Next steps

The next backend-focused sequence is:

1. Define the phone-number OTP request, verification, session, and optional
   name/barangay contracts for citizen accounts.
2. Remove the obsolete ID, face-capture, and identity-review route from the
   Flutter onboarding flow and connect phone OTP accounts to PostgreSQL.
3. Connect the dashboard Mobile Accounts view to real citizen accounts with
   appropriately masked phone data and account-status controls.
4. Freeze the mobile report request/response contract and report status values.
5. Implement incident-type listing and online mobile report submission with
   idempotency through `client_report_id`.
6. Wire the Flutter report flow to the online submission endpoint.
7. Finalize the signed SMS protocol and then implement gateway ingestion.
8. Confirm the approved ML model and implement translation/priority inference
   behind a replaceable service interface.

Before database or API implementation continues, confirm remaining product
rules that would change the schema: anonymous-report policy, mobile-account
suspension/restoration, report status transitions, attachment retention, and
SMS signing/key provisioning.
