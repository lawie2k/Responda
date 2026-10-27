import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:responda/core/network/responda_api_client.dart';
import 'package:responda/features/onboarding/data/account_controller.dart';
import 'package:responda/features/onboarding/data/mobile_account_api.dart';
import 'package:responda/features/onboarding/domain/account_profile.dart';

import 'support/mobile_account_fakes.dart';

class MemoryProfileStore implements AccountStore {
  AccountProfile? profile;
  @override
  Future<AccountProfile?> read() async => profile;
  @override
  Future<void> write(AccountProfile profile) async {
    this.profile = profile;
  }

  @override
  Future<void> clear() async {
    profile = null;
  }
}

void main() {
  test('OTP verifies through API, secures token, updates profile, and revokes logout', () async {
    final paths = <String>[];
    final store = MemoryProfileStore();
    final tokens = MemoryTokenStore();
    final api = MobileAccountApi(
      baseUrl: 'http://localhost:8000',
      client: MockClient((request) async {
        final path = request.url.path.replaceFirst('/api/v1/mobile/auth/', '');
        paths.add(path);
        final body = request.body.isEmpty
            ? <String, dynamic>{}
            : jsonDecode(request.body) as Map;
        if (path == 'otp/request') {
          expect(body['phone_number'], '+639000000001');
          return http.Response(
            jsonEncode({
              'challenge_id': 'challenge',
              'development_code': '654321',
              'resend_after_seconds': 60,
            }),
            200,
          );
        }
        if (path == 'otp/verify') {
          expect(body['challenge_id'], 'challenge');
          expect(body['code'], '654321');
          expect(body['privacy_notice_accepted'], true);
        } else {
          expect(request.headers['Authorization'], 'Bearer mobile_test');
        }
        if (path == 'logout') return http.Response('', 204);
        return http.Response(
          jsonEncode({
            'access_token': 'mobile_test',
            'expires_at': DateTime.now()
                .add(const Duration(days: 30))
                .toUtc()
                .toIso8601String(),
            'user': {
              'phone_number': '+639000000001',
              'full_name': body['full_name'] ?? '',
              'barangay': body['barangay'],
              'phone_verified_at': '2026-10-19T00:00:00Z',
              'privacy_notice_accepted_at': '2026-10-19T00:00:00Z',
            },
          }),
          200,
        );
      }),
    );
    final controller = AccountController(
      store: store,
      tokenStore: tokens,
      api: api,
    );
    await controller.load();
    await controller.sendCode('+639000000001');
    expect(controller.hasAccount, false);
    await controller.verifyCode('+639000000001', '654321');
    expect(tokens.token, 'mobile_test');
    expect(controller.hasAccount, true);
    expect(store.profile!.toJson().toString(), isNot(contains('mobile_test')));
    await controller.completePhoneVerification(
      phoneNumber: '+639000000001',
      privacyNoticeAcceptedAt: DateTime.now(),
      fullName: 'Synthetic',
      barangay: 'Kingking',
    );
    expect(controller.profile!.barangay, 'Kingking');
    await controller.clearLocalSession();
    expect(tokens.token, isNull);
    expect(store.profile, isNull);
    expect(paths, ['otp/request', 'otp/verify', 'profile', 'logout']);
    controller.dispose();
  });

  test(
    'legacy locally verified profile cannot authenticate without token',
    () async {
      final store = MemoryProfileStore()
        ..profile = AccountProfile(
          phoneNumber: '+639000000001',
          status: AccountVerificationStatus.verified,
          submittedAt: DateTime.now(),
          privacyNoticeAcceptedAt: DateTime.now(),
        );
      final controller = AccountController(
        store: store,
        tokenStore: MemoryTokenStore(),
        api: FakeMobileAccountApi(),
      );
      await controller.load();
      expect(controller.hasAccount, false);
      expect(store.profile, isNull);
      await expectLater(
        controller.completePhoneVerification(
          phoneNumber: '+639000000001',
          privacyNoticeAcceptedAt: DateTime.now(),
          fullName: 'Synthetic',
          barangay: 'Kingking',
        ),
        throwsA(isA<RespondaApiException>()),
      );
      controller.dispose();
    },
  );

  test('revoked restored session clears token and cache', () async {
    final store = MemoryProfileStore();
    final tokens = MemoryTokenStore()..token = 'mobile_revoked';
    final controller = AccountController(
      store: store,
      tokenStore: tokens,
      api: MobileAccountApi(
        client: MockClient(
          (_) async =>
              http.Response('{"error":{"message":"Sign in again."}}', 401),
        ),
      ),
    );
    await controller.load();
    expect(controller.hasAccount, false);
    expect(tokens.token, isNull);
    controller.dispose();
  });

  test('offline restoration keeps unexpired cached account but not expired session', () async {
    for (final expired in [false, true]) {
      final store = MemoryProfileStore()
        ..profile = AccountProfile(
          phoneNumber: '+639000000001',
          status: AccountVerificationStatus.verified,
          submittedAt: DateTime.now(),
          privacyNoticeAcceptedAt: DateTime.now(),
          sessionExpiresAt: DateTime.now().add(
            Duration(days: expired ? -1 : 1),
          ),
        );
      final controller = AccountController(
        store: store,
        tokenStore: MemoryTokenStore()..token = 'mobile_offline',
        api: MobileAccountApi(
          client: MockClient(
            (_) async => throw http.ClientException('Offline'),
          ),
        ),
      );
      await controller.load();
      expect(controller.hasAccount, !expired);
      controller.dispose();
    }
  });
}
