import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:responda/app.dart';
import 'package:responda/features/onboarding/data/account_controller.dart';
import 'package:responda/features/onboarding/data/mobile_account_api.dart';
import 'package:responda/features/onboarding/domain/account_profile.dart';
import 'package:responda/features/onboarding/presentation/screens/account_suspended_screen.dart';
import 'package:responda/features/reporting/data/signed_sms.dart';

import 'support/mobile_account_fakes.dart';

class _Profiles implements AccountStore {
  AccountProfile? value = AccountProfile(
    phoneNumber: '+639000000001',
    status: AccountVerificationStatus.verified,
    submittedAt: DateTime.now(),
    privacyNoticeAcceptedAt: DateTime.now(),
    sessionExpiresAt: DateTime.now().add(const Duration(days: 1)),
    fullName: 'Synthetic Tester',
    barangay: 'Kingking',
  );
  @override
  Future<AccountProfile?> read() async => value;
  @override
  Future<void> write(AccountProfile profile) async => value = profile;
  @override
  Future<void> clear() async => value = null;
}

class _Keys implements SmsKeyStore {
  bool cleared = false;
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String value) async {}
  @override
  Future<void> clear() async => cleared = true;
}

void main() {
  late _Profiles profiles;
  late _Keys keys;
  late MemoryTokenStore tokens;
  late MobileAccountApi api;
  late String serverState;

  setUp(() {
    profiles = _Profiles();
    keys = _Keys();
    tokens = MemoryTokenStore()..token = 'mobile_synthetic';
    serverState = 'active';
    api = MobileAccountApi(
      client: MockClient((request) async {
        if (serverState == 'offline') throw Exception('No network');
        if (serverState != 'active') {
          return http.Response(
            jsonEncode({
              'error': {
                'code': serverState == 'suspended'
                    ? 'account_suspended'
                    : 'mobile_session_invalid',
                'message': 'Account access restricted.',
              },
            }),
            serverState == 'suspended' ? 403 : 401,
          );
        }
        return http.Response(
          jsonEncode({
            'expires_at': profiles.value!.sessionExpiresAt!.toIso8601String(),
            'user': {
              'phone_number': profiles.value!.phoneNumber,
              'full_name': profiles.value!.fullName,
              'barangay': profiles.value!.barangay,
              'phone_verified_at': DateTime.now().toIso8601String(),
              'privacy_notice_accepted_at': DateTime.now().toIso8601String(),
            },
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);
  });

  AccountController controller() => AccountController(
    store: profiles,
    api: api,
    tokenStore: tokens,
    smsKeyStore: keys,
  );

  test(
    'suspension survives offline restart and restoration requires fresh login',
    () async {
      final account = controller();
      addTearDown(account.dispose);
      await account.load();
      expect(account.hasAccount, isTrue);
      serverState = 'suspended';
      expect(await account.refreshSession(), isTrue);
      expect(account.isSuspended, isTrue);
      expect(account.hasAccount, isFalse);
      expect(profiles.value?.isSuspended, isTrue);
      expect(keys.cleared, isTrue);
      expect(account.offlineSmsReady, isFalse);

      serverState = 'offline';
      final restarted = controller();
      addTearDown(restarted.dispose);
      await restarted.load();
      expect(restarted.isSuspended, isTrue);
      expect(await restarted.refreshSession(), isFalse);
      serverState = 'restored';
      await restarted.refreshSession();
      expect(restarted.isSuspended, isFalse);
      expect(restarted.hasAccount, isFalse);
      expect(tokens.token, isNull);
      expect(profiles.value, isNull);
    },
  );

  testWidgets(
    'app replaces all routes with suspension UI and status check is usable',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final account = controller();
      addTearDown(account.dispose);
      await account.load();
      await tester.pumpWidget(RespondaApp(accountController: account));
      await tester.pump();
      serverState = 'suspended';
      await account.refreshSession();
      await tester.pumpAndSettle();
      expect(find.byType(AccountSuspendedScreen), findsOneWidget);
      expect(find.text('Account suspended'), findsOneWidget);
      final check = find.byKey(const Key('check_suspended_account'));
      await tester.ensureVisible(check);
      await tester.tap(check);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Your account is still suspended. Contact MDRRMO for assistance.',
        ),
        findsOneWidget,
      );
      serverState = 'restored';
      await tester.tap(check);
      await tester.pumpAndSettle();
      expect(find.byType(AccountSuspendedScreen), findsNothing);
      expect(account.hasAccount, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
