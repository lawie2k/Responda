# Preserve sign-in across app updates

Ordinary updates reuse the saved secure session token and serialized account
profile. App version/build numbers do not determine login state. On launch the
app calls `mobile/auth/me`; a valid cached account can still be restored when
that request fails because of a network outage or temporary server error.

The backend remains authoritative. Logout, revoked/expired sessions, deleted
accounts and suspension must still require sign-in or show the restriction UI.
The current mobile session lifetime is 30 days; app updates do not extend it.

## Release compatibility

- Update the existing store listing and preserve its application identity and
  signing/keychain access. iOS currently uses `com.artlaurence.responda`;
  Android currently uses `com.example.responda`. Finalize the Android identity
  before the first public release, then retain it for updates.
- Retain `responda_mobile_session_v1` in secure storage and
  `responda_account_profile_v1` in preferences. If either key/schema changes,
  migrate existing data before removing the old representation.
- Do not clear preferences, secure storage or sessions because a build number
  changes. Keep compatible secure-storage configuration and review plugin
  migration notes when upgrading storage dependencies.
- Keep the production API/account database and its active session records across
  backend deployments. Moving from the local development backend to production
  is a different account environment and can require a fresh sign-in.
- Install updates over the existing app. Uninstalling, clearing app data, account
  suspension or session expiry is not an ordinary update test.

## Before publishing an update

1. Sign in with the previous published build and record its account/settings.
2. Install the candidate over it using TestFlight/Play testing without deleting
   the prior installation. Relaunch and confirm Home opens for the same account.
3. Repeat with networking unavailable; confirm the cached valid account and
   offline reports remain available. Reconnect and verify server authorization.
4. Verify that logout, expiry, revocation and suspension still take effect.

Automated coverage: `test/account_update_restore_test.dart` freezes the existing
secure-storage key and profile schema and restores a new controller online,
offline and during a 503 response; a server 401 still clears the session. Secure
storage is mocked for these tests. This does not replace real store-update QA.

References: [Apple update testing](https://developer.apple.com/library/archive/technotes/tn2285/),
[Android update requirements](https://developer.android.com/google/play/app-updates).
