---
tags:
  - responda/memory
  - responda/planning
updated: 2026-10-20
---

# Next steps

Mobile OTP and authenticated online report creation are connected locally. The
no-sender beta build now obtains an unverified beta session automatically for
online report testing when the backend beta flag is enabled. Select/configure a
real OTP provider before production and connect My Reports/status to protected
reporter read APIs.

1. The beta iPhone build now reports Online over the wired link. To relaunch it,
   get the current USB-side host address with `ipconfig getifaddr en8` and use
   it for `RESPONDA_API_BASE_URL`. Keep the backend beta flag enabled for the
   current no-OTP report test; confirm the received report appears automatically
   in Live Reports within its five-second refresh cycle.
   Synchronize app source changes back to the monorepo before Git commits.
2. Try a newly registered mobile account in Mobile Accounts; Super Admins
   can suspend/restore real citizens and both administrator tiers can monitor.
3. Connect the reporter's online report history/status to the backend, then
   implement the signed app-only SMS gateway and the approved advisory ML service.
4. Confirm any additional web Settings scope: staff password recovery/change,
   editable organization details, notification delivery, and retention controls.

Before later phases, confirm attachment retention, SMS signing/key provisioning,
and the exact ML model. Online submission currently blocks reports with photos
until attachment storage/retention is agreed.
