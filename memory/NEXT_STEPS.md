---
tags:
  - responda/memory
  - responda/planning
updated: 2026-10-21
---

# Next steps

Mobile OTP and authenticated online report creation are connected locally. The
no-sender beta build now obtains an unverified beta session automatically for
online report testing when the backend beta flag is enabled. Select/configure a
real OTP provider before production. My Reports/status now uses protected
reporter reads; a physical-device walkthrough of tracking remains pending.

1. Rebuild/install the updated mobile app and test a real report through staff
   validation, assignment, response and resolution while My Reports is open.
   Start the backend and use the working wired link. To configure it,
   get the current USB-side host address with `ipconfig getifaddr en8` and use
   it for `RESPONDA_API_BASE_URL`. Keep the backend beta flag enabled for the
   current no-OTP report test; confirm the received report appears automatically
   in Live Reports within its five-second refresh cycle.
   Synchronize app source changes back to the monorepo before Git commits.
2. Try a newly registered mobile account in Mobile Accounts; Super Admins
   can suspend/restore real citizens and both administrator tiers can monitor.
3. Implement the signed app-only SMS gateway, reporter notifications, and the
   approved advisory ML service.
4. Confirm any additional web Settings scope: staff password recovery/change,
   editable organization details, notification delivery, and retention controls.

Before later phases, confirm attachment retention, SMS signing/key provisioning,
and the exact ML model. Online submission currently blocks reports with photos
until attachment storage/retention is agreed.
