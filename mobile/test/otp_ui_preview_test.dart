import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responda/core/config/beta_features.dart';
import 'package:responda/features/onboarding/data/account_controller.dart';
import 'package:responda/features/onboarding/data/mobile_account_api.dart';
import 'package:responda/features/onboarding/domain/account_profile.dart';
import 'package:responda/features/onboarding/presentation/account_scope.dart';
import 'package:responda/features/onboarding/presentation/screens/verification/phone_verification_screen.dart';

class _CountingApi extends MobileAccountApi {
  int requests = 0;

  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    String? token,
    Map<String, Object?>? body,
  }) async {
    requests++;
    throw StateError('Preview mode must not contact the backend.');
  }
}

class _TokenStore implements SessionTokenStore {
  @override
  Future<String?> read() async => null;
  @override
  Future<void> write(String token) async {}
  @override
  Future<void> clear() async {}
}

class _AccountStore implements AccountStore {
  @override
  Future<AccountProfile?> read() async => null;
  @override
  Future<void> write(AccountProfile profile) async {}
  @override
  Future<void> clear() async {}
}

void main() {
  testWidgets('debug preview opens OTP without backend requests', (
    tester,
  ) async {
    if (!otpUiPreviewMode) {
      markTestSkipped('Run with --dart-define=RESPONDA_OTP_UI_PREVIEW=true.');
      return;
    }
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _CountingApi();
    final account = AccountController(
      store: _AccountStore(),
      api: api,
      tokenStore: _TokenStore(),
    );
    addTearDown(account.dispose);

    await tester.pumpWidget(
      AccountScope(
        controller: account,
        child: MaterialApp(
          home: IdentityVerificationScreen(
            privacyNoticeAcceptedAt: DateTime(2026),
          ),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('identity_phone_field')),
      '9171234567',
    );
    await tester.tap(find.byKey(const Key('send_identity_otp_button')));
    await tester.pumpAndSettle();

    expect(api.requests, 0);
    expect(find.text('Enter your OTP'), findsOneWidget);
    expect(find.text('OTP UI preview'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('identity_otp_field')),
      '123456',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('verify_identity_otp_button')));
    await tester.pumpAndSettle();
    expect(api.requests, 0);
    expect(
      find.text('OTP preview only. Verification is disabled.'),
      findsOneWidget,
    );
  });
}
