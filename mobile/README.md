# Responda Mobile

Flutter mobile application for the Responda emergency reporting platform.

Offline signing, the separate Android SIM gateway APK and the private setup
walkthrough are documented in [docs/sms-testing.md](docs/sms-testing.md).

## Backend connection

The app verifies that both the FastAPI service and PostgreSQL database are healthy before entering
online mode. Without a reachable backend, the app uses its offline reporting flow.

Start the backend before starting Flutter:

```bash
cd ../backend
make run
```

The defaults work automatically for simulators and emulators:

- iOS Simulator: `http://127.0.0.1:8000`
- Android Emulator: `http://10.0.2.2:8000`

For a physical phone, keep the phone and Mac on the same Wi-Fi network, start the backend with
`make run-mobile`, and provide the Mac's current local IP address:

```bash
flutter run \
  --dart-define=RESPONDA_API_BASE_URL=http://192.168.1.6:8000
```

The IP address can change when the Mac reconnects to Wi-Fi. Check it with:

```bash
ipconfig getifaddr en0
```

For a beta build with no OTP sender, pass
`--dart-define=RESPONDA_BETA_SKIP_MOBILE_VERIFICATION=true`. Onboarding then saves a local-only
beta profile and skips the phone-number screen. With the local backend setting
`RESPONDA_MOBILE_BETA_ACCOUNTS_ENABLED=true`, the first online report obtains an unverified beta
session automatically. No OTP is required. The session is stored securely and reused; photo
uploads remain unavailable. Omit the mobile define to restore normal OTP setup.

When the development backend returns its test OTP, the OTP screen offers “Continue with test code.”
It verifies that server-issued code and continues to optional profile setup. Production builds do
not show this development-only shortcut.

## Verification

```bash
flutter analyze
flutter test
```
