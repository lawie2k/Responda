import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:responda/features/onboarding/data/account_controller.dart';
import 'package:responda/features/onboarding/data/mobile_account_api.dart';
import 'package:responda/features/onboarding/domain/account_profile.dart';

import 'support/mobile_account_fakes.dart';

// Serialized app data survives replacing the application binary.
class _PersistedProfile implements AccountStore {
  String? encoded;

  @override
  Future<AccountProfile?> read() async => encoded == null
      ? null
      : AccountProfile.fromJson(
          Map<String, Object?>.from(jsonDecode(encoded!) as Map),
        );

  @override
  Future<void> write(AccountProfile profile) async {
    encoded = jsonEncode(profile.toJson());
  }

  @override
  Future<void> clear() async => encoded = null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final result in ['online', 'offline', 'unavailable', 'revoked']) {
    test('replacement app restores saved login: $result', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final profiles = _PersistedProfile();
      final original = AccountController(
        store: profiles,
        tokenStore: SecureSessionTokenStore(),
        api: FakeMobileAccountApi()
          ..fullName = 'Synthetic account'
          ..barangay = 'Kingking',
      );
      await original.load();
      await original.sendCode('+639000000001');
      await original.verifyCode('+639000000001', '123456');
      final savedToken = await SecureSessionTokenStore().read();
      final savedProfile = await profiles.read();
      expect(savedToken, isNotNull);
      expect(profiles.encoded, isNot(contains(savedToken!)));
      original.dispose();
      // Freeze the storage key/schema shipped before the replacement binary.
      FlutterSecureStorage.setMockInitialValues({
        'responda_mobile_session_v1': savedToken,
      });
      profiles.encoded = jsonEncode({
        'phoneNumber': savedProfile!.phoneNumber,
        'status': 'verified',
        'submittedAt': savedProfile.submittedAt.toIso8601String(),
        'privacyNoticeAcceptedAt': savedProfile.privacyNoticeAcceptedAt
            .toIso8601String(),
        'fullName': savedProfile.fullName,
        'barangay': savedProfile.barangay,
        'sessionExpiresAt': savedProfile.sessionExpiresAt!.toIso8601String(),
        'isBetaLocal': false,
        'isSuspended': false,
      });

      final requests = <String>[];
      final replacement = AccountController(
        store: profiles,
        tokenStore: SecureSessionTokenStore(),
        api: MobileAccountApi(
          client: MockClient((request) async {
            requests.add(request.url.path);
            expect(request.headers['Authorization'], 'Bearer $savedToken');
            if (result == 'offline') throw http.ClientException('Offline');
            if (result == 'unavailable') return http.Response('{}', 503);
            if (result == 'revoked') return http.Response('{}', 401);
            return http.Response(
              jsonEncode({
                'expires_at': savedProfile.sessionExpiresAt!.toIso8601String(),
                'user': {
                  'phone_number': savedProfile.phoneNumber,
                  'full_name': savedProfile.fullName,
                  'barangay': savedProfile.barangay,
                  'phone_verified_at': savedProfile.submittedAt
                      .toIso8601String(),
                  'privacy_notice_accepted_at': savedProfile
                      .privacyNoticeAcceptedAt
                      .toIso8601String(),
                },
              }),
              200,
            );
          }),
        ),
      );
      addTearDown(replacement.dispose);
      await replacement.load();
      expect(requests, ['/api/v1/mobile/auth/me']);
      expect(replacement.hasAccount, result != 'revoked');
      if (result == 'revoked') {
        expect(await SecureSessionTokenStore().read(), isNull);
        expect(await profiles.read(), isNull);
      } else {
        expect(await SecureSessionTokenStore().read(), savedToken);
        expect(replacement.profile!.fullName, savedProfile.fullName);
        expect(replacement.profile!.barangay, savedProfile.barangay);
        expect(
          replacement.profile!.sessionExpiresAt,
          savedProfile.sessionExpiresAt,
        );
        await replacement.refreshSession();
        expect(replacement.hasAccount, isTrue);
      }
    });
  }
}
