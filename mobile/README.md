# Responda Mobile

Flutter mobile application for the Responda emergency reporting platform.

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

## Verification

```bash
flutter analyze
flutter test
```
