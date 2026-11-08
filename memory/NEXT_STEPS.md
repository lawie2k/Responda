---
tags:
  - responda/memory
  - responda/planning
updated: 2026-11-08
---

# Next steps

User narrowed Liquid Glass to iOS navigation and back controls. Centered Call
and UIKit stock selection are installed; the former custom indicator was removed.
Review the stock tab indicator, larger call icon, native back actions, call-warning sheets, and tutorial call highlighting
during the remaining device walkthrough; regular buttons/cards are restored.
The dark native back-button appearance is reported and remains unfixed; inspect
the native appearance before choosing its light-theme adjustment.

2026-11-05 non-ML web scope is implemented; deployment is explicitly skipped.
Next: run web/docs/non-ml-acceptance.md with MDRRMO and the physical citizen phone.
The current release is installed with backend OTP restored; opt in to background browser
alerts and test actual delivery/notification clicks, logout expiry, correction
conflicts, photo upload/retry/viewing, and On Site through final completion.
Keep the API running for push delivery. Confirm photo retention and schedule the
purge CLI before any later deployment. ML remains outside this implementation.

The gateway SIM phone and citizen SMS installation are configured. The first
real SMS reached the backend and Live Reports after enabling the Android USB
reverse tunnel. Continue untethered and failure/retry testing in step 3.

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

1. On the updated iPhone release, test a real report through staff validation,
   assignment, response and resolution while My Reports is open. Use the Mac's
   reachable Bonjour `.local` backend origin for the local iPhone build. Keep the backend
   running via `make run-mobile` for phone access. Complete development OTP
   sign-in, then confirm Live Reports receives the submission. Synchronize app source changes back to the monorepo
   before Git commits.
2. Try a newly registered mobile account in Mobile Accounts; Super Admins
   can suspend/restore real citizens and both administrator tiers can monitor.
   Confirm the updated iPhone shows the suspension screen within 15 seconds
   online or on resume, keeps the restriction after an offline restart, and
   requires a fresh OTP sign-in after restoration.
3. The installed Mac LaunchAgent automatically restores the Android gateway's
   localhost USB route every ten seconds. Verify a physical unplug/reconnect
   during the next device walkthrough; simulated mapping loss already recovered.
   An untethered gateway still needs a reachable LAN/deployed origin and
   controlled reconfiguration with no pending queue. The first real SMS was accepted and appears as
   new/pending in Live Reports. Continue multipart, internet loss/restart,
   duplicate retry and token-revocation tests using mobile/docs/sms-testing.md.
   Reporter notifications and the approved advisory ML service remain pending.
4. Confirm any additional web Settings scope: staff password recovery,
   editable organization details, notification delivery, and retention controls.

Before later phases, confirm attachment retention, the Android forwarding app
deployment/distribution approach, and the exact ML model. Online photo uploads
now use the private bounded storage flow; institutional retention still needs confirmation.
