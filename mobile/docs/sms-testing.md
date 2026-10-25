# Signed SMS setup and device test

There are two separate apps: the normal Flutter citizen app and a small native
Android **Responda Gateway** utility (`com.responda.gateway`). Only the gateway
requests incoming-SMS permission. It is intended for the dedicated MDRRMO phone,
not every citizen phone. No real gateway credential is bundled in either APK.

## Build

From the user's mobile build folder, `/Users/lawie/local Documents/Responda/mobile`:

```sh
flutter pub get
flutter build apk --debug
cd android
./gradlew :gateway:assembleDebug :gateway:testDebugUnitTest
```

Citizen APK: `build/app/outputs/flutter-apk/app-debug.apk`.
Gateway APK: `build/gateway/outputs/apk/debug/gateway-debug.apk`.
These debug builds support local development. Release gateway builds require
HTTPS, an operator-managed release signing key and distribution review. Existing
citizen Android/iOS signing settings are not changed by the gateway module.

The default citizen Android API address is for an emulator. For a physical
reporting phone, add `--dart-define=RESPONDA_API_BASE_URL=<reachable-backend-origin>`
when rebuilding; use the LAN/USB address appropriate to that phone. Do not enable
the beta verification bypass for the SMS walkthrough.

## Prepare the dedicated Android phone

1. Install only the Gateway APK on the Android phone with the gateway SIM. It
   receives SMS; internet (Wi-Fi or mobile data) forwards them to the backend.
2. In a private local terminal, run from the backend folder:

   ```sh
   .venv/bin/python -m app.cli.configure_sms_gateway
   ```

   Enter the existing Super Admin email/password in that terminal, then a gateway
   name and the gateway SIM number in `+639XXXXXXXXX` format. The temporary admin
   session is signed out afterwards. The command shows a gateway ID and one-time
   token: paste it only into the gateway app, never into chat, Git or logs. A
   normal Administrator cannot provision a gateway. If that phone was registered
   earlier, use `--rotate <gateway-id>` to replace its token instead.
3. Open Responda Gateway. Enter the backend **origin**, such as a reachable LAN
   origin with port 8000; it must not contain `/api/v1`. `localhost` on the phone
   means the phone itself. Use HTTPS for deployment; local HTTP is debug-only.
4. Paste the issued gateway token and press **Enable / update gateway**. Grant
   SMS permission when Android asks. The token and queued message bodies use
   Android Keystore-backed AES-GCM storage; backup is disabled. Saved tokens are
   never prefilled or displayed. Permission denial leaves receiving disabled.
5. Keep the phone powered, initially unlocked after reboot, and enabled. Android
   can delay background work; a force-stopped app needs to be opened again.
   Check its queue/status regularly. A displayed reception/storage error needs
   operator attention; clearing app storage would destroy pending messages.

The app ignores ordinary texts locally, concatenates multipart bodies delivered
by Android, and queues only complete RSP1 envelopes. Each item keeps a stable UUID.
Network/429/5xx failures retry with exponential backoff and honor `Retry-After`.
401/403 pauses all uploads until credentials are updated. Other 4xx/redirects
keep that item blocked for review; after fixing configuration, **Enable / update**
resumes the retained queue. Recovery work scans for unscheduled items after
process restarts. Moving a nonempty queue to a different backend is blocked.
Only a recognized accepted/duplicate/rejected server acknowledgement removes an
item; malformed successful responses do not discard reports. Counters contain no
sender numbers, report text or credentials.

## Prepare the citizen app

1. Install/rebuild the updated Flutter app on the reporting phone. Verify the
   actual sending SIM number online. Beta profiles without phone verification
   cannot enable SMS. Local development may use the API's development OTP code;
   actual production verification still requires an SMS delivery provider.
2. Open **Account Management → Set up Offline SMS** while online. The backend
   supplies a per-installation key plus the oldest active registered gateway's
   SIM number. Without a configured gateway, setup reports that it is not ready;
   retrying reuses the same installation ID. On a different backend, repeat setup.
3. Turn off internet on the reporting phone, keeping cellular SMS service active.
   Create the report, review it, and choose **Save report & open SMS**. Details
   must fit 10–300 characters and landmarks 100 characters; no photos. Overlong
   encoded messages are rejected rather than truncated. Carriers may charge for
   several concatenated SMS parts.
4. In Messages, send the prepared body **unchanged**, using the verified SIM.
   Opening Messages does not prove sending or delivery. A local copy remains
   labelled delivery-unconfirmed. **Open SMS draft** in saved reports can resend
   the same signed bytes and UUID. An unsigned saved report can be prepared once
   SMS setup is available. Reports saved before the feature remain readable.
5. The gateway should show a terminal acknowledgement and the report should
   appear once in Live Reports as an SMS submission. After reconnecting, the
   citizen's server-backed My Reports should include it and track staff updates.
   Retrying over SMS/online must not create a second emergency report.

Signing keys are account/backend-bound in secure storage, expire after 180 days,
and are revoked on sign-out. Account suspension revokes them server-side too.
Expired/revoked keys require online setup again; messages older than seven days
must be replaced by a fresh report. HMAC authenticates a provisioned credential,
not an attested binary; SMS is not encrypted over the carrier network.

## Verification and limits

The shared synthetic protocol fixture in `test/fixtures/rsp1.json` is validated
by Dart and Python. Gateway JVM tests cover filtering, origin checks and delivery
decisions. Test artifacts use synthetic data and are not real credentials.
No physical SIM delivery is verified by a successful APK build. Test with both
phones after provisioning, including internet loss, multipart delivery, duplicate
SMS, app restart, permission denial, and a revoked token. Do not issue a real
dispatch during development testing.

API details: [backend SMS contract](../../backend/docs/sms-gateway.md).
Platform references: [Android SMS intents](https://developer.android.com/reference/android/provider/Telephony.Sms.Intents),
[WorkManager](https://developer.android.com/jetpack/androidx/releases/work).
