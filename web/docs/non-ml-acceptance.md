# Non-ML operations acceptance walkthrough

Deployment is excluded at the user's request. Run against the local configured API.
Use synthetic reports and accounts; never place real contacts, photos, or emergency
narratives in test evidence or project memory.

1. Log in as each staff role. Incident Map → Heatmap & recurring hotspots:
   choose dates/category, apply, and compare counts with verified incident records.
   Two callers linked to the same incident should contribute only one count.
   Resolved incidents remain part of historical density. Unverified/invalid/deleted
   reports are excluded. Blue → green → red is relative density, not risk severity.
2. Examine a cell with at least three incidents. Suggested preventive actions must
   be reviewed by MDRRMO; they are deterministic planning suggestions, not ML or
   approved dispatch orders. Change category to inspect relevant suggestions.
3. Open Live Reports or Report Validation → correction form. Plot a new location
   or enter coordinates, choose category and explain the correction. Save and
   reload. Concurrent edits must be rejected; reload before retrying. A linked
   report cannot change category independently of its incident. Original location
   and category evidence is retained in protected report history.
4. Submit a synthetic mobile report with a JPEG/PNG. Confirm its photo can be
   opened by signed-in staff and cannot be read without a staff session. Retry
   the same upload: no duplicate attachment should be created. Reject non-image
   content, oversized files and another citizen's report ID.
5. New reports must appear in the notification dropdown within the polling
   interval. Enable background browser alerts explicitly. Confirm another signed-in staff
   member's read/unread state is independent and survives reload. Background push uses a service worker and requires browser support, permission,
   a running API and an active staff session. Close the dashboard tab and submit
   a new synthetic report; confirm the notification opens the correct report.
   Delivery when the browser application is fully quit depends on the browser/OS. Denying browser notification permission must leave in-app alerts usable.
6. Progress an assignment: assigned → acknowledged → responding → On Site →
   completed. Record arrival, verify its timestamp in history and the citizen's
   status journey, and confirm the unit remains in service. Complete the final
   active team: incident resolves and the team becomes available. Cancellation
   of an on-site assignment must release the unit without losing recorded history.
7. Record MDRRMO observer feedback and actual results separately. Automated tests
   do not replace physical-device checks or formal usability/acceptance evaluation.

## Photo storage and retention

`RESPONDA_ATTACHMENT_STORAGE_DIR` is a private directory, never a static web
mount. Accepted uploads are authenticated, limited to 5 MB and 20 megapixels,
reencoded to metadata-free JPEG, and capped at three per report. The mobile UI
currently attaches one photo. Staff read routes use no-store and nosniff.

Access expires after `RESPONDA_ATTACHMENT_RETENTION_DAYS` (default 30 days).
To remove expired files and mark their metadata deleted, run from backend:

```
.venv/bin/python -m app.cli.purge_report_photos
```

Configure a daily run when deploying; that scheduling is not installed by this
local feature change. Confirm the institutional retention policy before launch.
Back up the private directory together with PostgreSQL if retained photos are needed.

## Background browser push

From backend, run `python -m app.cli.setup_webpush` using the virtual environment,
then enable `RESPONDA_WEB_PUSH_ENABLED=true` and restart the API. The private
VAPID key stays in an ignored mode-600 local file. Keep that key stable across
restarts; rotating it requires browsers to subscribe again. Configure a real
operator contact via `RESPONDA_WEB_PUSH_SUBJECT` before launch.

Staff opt in through the notification dropdown. HTTPS or localhost is required.
Push subscriptions are bound to the staff session and stop delivery after logout,
revocation, expiry or deactivation. Read receipts remain independent of delivery.
The sender retries transient failures and removes subscriptions rejected as expired.
Only known browser-push provider hosts are accepted. No report narratives, phone
numbers or precise locations enter push payloads.
