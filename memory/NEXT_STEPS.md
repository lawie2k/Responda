---
tags:
  - responda/memory
  - responda/planning
updated: 2026-10-26
---

# Next steps

SMS gateway work is checkpointed while the user obtains an Android SIM phone.
Resume provisioning and real delivery testing with step 3 when it is available.

Mobile OTP and authenticated online report creation are connected locally. The
no-sender beta build now obtains an unverified beta session automatically for
online report testing when the backend beta flag is enabled. Select/configure a
real OTP provider before production. My Reports/status now uses protected
reporter reads; a physical-device walkthrough of tracking remains pending.

Web dashboard checkpoint: password changes, role-specific overview, expanded
account search, and all-active Incident Map filtering are implemented. Confirm
the user's older Responding report now appears on Incident Map after reload;
the filter correction passed lint/build but that specific record has not been
verified in the browser.

1. On the updated iPhone build, test a real report through staff validation,
   assignment, response and resolution while My Reports is open. Use the active
   wired backend address; it may change after reconnecting. Keep the backend
   beta flag enabled for the current no-OTP report test and confirm Live Reports
   receives the submission. Synchronize app source changes back to the monorepo
   before Git commits.
2. Try a newly registered mobile account in Mobile Accounts; Super Admins
   can suspend/restore real citizens and both administrator tiers can monitor.
3. Install/configure the built Responda Gateway APK when the dedicated Android
   SIM phone is connected. Use the private Super Admin provisioning CLI and
   mobile/docs/sms-testing.md, rebuild the citizen phone for a reachable API,
   verify its sending SIM and enable Offline SMS in Account Management. Test
   multipart delivery, internet loss/restarts, duplicate retry, token revocation
   and dashboard receipt. No real gateway credential or SIM delivery is configured
   yet. Reporter notifications and the approved advisory ML service remain pending.
4. Confirm any additional web Settings scope: staff password recovery,
   editable organization details, notification delivery, and retention controls.

Before later phases, confirm attachment retention, the Android forwarding app
deployment/distribution approach, and the exact ML model. Online submission blocks reports with photos
until attachment storage/retention is agreed.
