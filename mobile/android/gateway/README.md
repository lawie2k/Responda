# Responda Gateway

Separate native utility APK for the dedicated Android SIM phone. See the mobile
[setup and test guide](../../docs/sms-testing.md). Build with
`./gradlew :gateway:assembleDebug :gateway:testDebugUnitTest` from `mobile/android`.
It uses WorkManager for persisted, network-aware retries and Android Keystore AES-GCM
for credentials and SMS bodies. The normal Flutter citizen package does not inherit
its `RECEIVE_SMS` permission. Gateway credentials are configured privately after install.
