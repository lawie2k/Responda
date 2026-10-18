---
tags:
  - responda/memory
  - responda/planning
updated: 2026-10-19
---

# Next steps

Mobile account integration has resumed with local development OTP:

The next major implementation is authenticated online mobile report submission
to the existing dashboard workflow, after checking the account flow below.

1. Try the connected Flutter phone/OTP/profile flow on the user's target device.
   Select and integrate a real SMS provider before production phone login.
2. Try a newly registered mobile account in Mobile Accounts; Super Admins
   can suspend/restore real citizens and both administrator tiers can monitor.
3. Implement authenticated online mobile reports, then the signed app-only SMS
   gateway, then the approved advisory ML service.
4. Confirm any additional web Settings scope: staff password recovery/change,
   editable organization details, notification delivery, and retention controls.

Before the later account/report phases, confirm anonymous-report policy,
attachment retention, SMS signing/key
provisioning, and the exact ML model.
