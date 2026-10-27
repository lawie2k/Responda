import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:responda/core/constants/pantukan_barangays.dart';
import 'package:responda/core/navigation/app_routes.dart';
import 'package:responda/features/onboarding/data/account_controller.dart';
import 'package:responda/features/onboarding/domain/account_profile.dart';
import 'package:responda/features/onboarding/presentation/account_scope.dart';
import 'package:responda/features/onboarding/presentation/screens/identity_verification_screen.dart';
import 'package:responda/features/onboarding/presentation/screens/verification/privacy_notice_screen.dart';
import 'package:responda/features/onboarding/presentation/screens/verification/otp_verification_screen.dart';
import 'package:responda/screens/online/account_management_screen.dart';
import 'package:responda/screens/online/settings_screen.dart';

import 'support/mobile_account_fakes.dart';

void main() {
  Future<void> setPhoneSize(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  final privacyAcceptedAt = DateTime(2026, 10, 8, 9, 30);

  testWidgets('beta OTP setup requires both name and barangay', (tester) async {
    await setPhoneSize(tester);
    final tokens = MemoryTokenStore();
    final api = FakeMobileAccountApi();
    final controller = AccountController(
      store: _MemoryAccountStore(),
      api: api,
      tokenStore: tokens,
    );
    addTearDown(controller.dispose);
    await controller.load();
    await controller.sendCode('+639171234567');
    await tester.pumpWidget(
      AccountScope(
        controller: controller,
        child: MaterialApp(
          home: OtpVerificationScreen(
            phoneNumber: '+639171234567',
            otpService: controller,
            privacyNoticeAcceptedAt: privacyAcceptedAt,
          ),
          routes: {AppRoutes.home: (_) => const _HomeMarker()},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('skip_otp_verification')));
    await tester.pumpAndSettle();

    expect(find.text('Account details'), findsOneWidget);
    expect(find.byType(_HomeMarker), findsNothing);
    expect(api.verifiedCode, '123456');
    expect(controller.hasAccount, isTrue);
    expect(controller.profile?.status, AccountVerificationStatus.verified);
    expect(await tokens.read(), isNotNull);

    await tester.enterText(
      find.byKey(const Key('optional_profile_name_field')),
      'Beta Tester',
    );
    final finish = find.byKey(const Key('finish_account_setup_button'));
    await tester.ensureVisible(finish);
    await tester.tap(finish);
    await tester.pumpAndSettle();
    expect(find.text('Select your barangay.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('optional_profile_barangay_field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kingking').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(finish);
    await tester.tap(finish);
    await tester.pumpAndSettle();

    expect(find.text('Phone verified'), findsOneWidget);
    expect(api.fullName, 'Beta Tester');
  });

  testWidgets('phone entry keeps verification required', (tester) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: IdentityVerificationScreen(
          privacyNoticeAcceptedAt: privacyAcceptedAt,
        ),
      ),
    );

    expect(find.byKey(const Key('skip_phone_verification')), findsNothing);
  });

  test(
    'account profile persists phone verification and required details',
    () async {
      final store = _MemoryAccountStore();
      final api = FakeMobileAccountApi();
      final tokens = MemoryTokenStore();
      final controller = AccountController(
        store: store,
        api: api,
        tokenStore: tokens,
      );
      await controller.load();
      expect(controller.hasAccount, isFalse);
      await controller.sendCode('+639171234567');
      await controller.verifyCode('+639171234567', '123456');

      await controller.completePhoneVerification(
        phoneNumber: '+639171234567',
        privacyNoticeAcceptedAt: privacyAcceptedAt,
        fullName: 'Juan Dela Cruz',
        barangay: 'Kingking',
      );
      expect(controller.profile?.status, AccountVerificationStatus.verified);

      final restarted = AccountController(
        store: store,
        api: api,
        tokenStore: tokens,
      );
      await restarted.load();
      expect(restarted.profile?.phoneNumber, '+639171234567');
      expect(restarted.profile?.fullName, 'Juan Dela Cruz');
      expect(restarted.profile?.barangay, 'Kingking');
      expect(restarted.profile?.privacyNoticeAcceptedAt, privacyAcceptedAt);
    },
  );

  testWidgets('privacy-first onboarding completes with phone OTP', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final controller = AccountController(
      store: _MemoryAccountStore(),
      api: FakeMobileAccountApi(),
      tokenStore: MemoryTokenStore(),
    );
    await controller.load();

    await tester.pumpWidget(
      AccountScope(
        controller: controller,
        child: MaterialApp(
          home: const PrivacyNoticeScreen(),
          routes: {AppRoutes.home: (_) => const _HomeMarker()},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your privacy matters'), findsOneWidget);
    expect(find.text('No ID or face photo required'), findsNothing);
    await tester.tap(find.byKey(const Key('privacy_notice_checkbox')));
    await tester.pump();
    final continueButton = find.byKey(
      const Key('continue_privacy_notice_button'),
    );
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(find.text('Verify your mobile number'), findsOneWidget);
    expect(find.text('No ID or face photo required'), findsNothing);
    await tester.enterText(
      find.byKey(const Key('identity_phone_field')),
      '9171234567',
    );
    await tester.tap(find.byKey(const Key('send_identity_otp_button')));
    await tester.pumpAndSettle();

    expect(find.text('Enter your OTP'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('identity_otp_field')),
      '123456',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('verify_identity_otp_button')));
    await tester.pumpAndSettle();

    expect(find.text('Account details'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Barangay'), findsOneWidget);
    expect(find.text('Upload a valid ID'), findsNothing);
    expect(find.text('Take a face photo'), findsNothing);
    final finish = find.byKey(const Key('finish_account_setup_button'));
    await tester.ensureVisible(finish);
    await tester.tap(finish);
    await tester.pumpAndSettle();
    expect(find.text('Enter your full name.'), findsOneWidget);
    expect(find.text('Select your barangay.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('optional_profile_name_field')),
      'Juan Dela Cruz',
    );
    await tester.tap(find.byKey(const Key('optional_profile_barangay_field')));
    await tester.pumpAndSettle();
    expect(pantukanBarangays, hasLength(13));
    await tester.tap(find.text('Kingking').last);
    await tester.pumpAndSettle();
    expect(find.text('Save and continue'), findsOneWidget);
    await tester.ensureVisible(finish);
    await tester.tap(finish);
    await tester.pumpAndSettle();

    expect(find.text('Phone verified'), findsOneWidget);
    expect(find.text('No valid ID or face photo was collected.'), findsNothing);
    expect(controller.profile?.phoneNumber, '+639171234567');
    expect(controller.profile?.status, AccountVerificationStatus.verified);
    expect(controller.profile?.fullName, 'Juan Dela Cruz');
    expect(controller.profile?.barangay, 'Kingking');

    await tester.tap(
      find.byKey(const Key('open_responda_after_identity_button')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(_HomeMarker), findsOneWidget);
  });

  testWidgets('phone number only accepts 9 as its first digit', (tester) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: IdentityVerificationScreen(
          privacyNoticeAcceptedAt: privacyAcceptedAt,
        ),
      ),
    );

    final phoneField = find.byKey(const Key('identity_phone_field'));
    await tester.enterText(phoneField, '0');
    expect(tester.widget<TextField>(phoneField).controller!.text, isEmpty);

    await tester.enterText(phoneField, '9');
    expect(tester.widget<TextField>(phoneField).controller!.text, '9');

    await tester.enterText(phoneField, '9171234567');
    expect(tester.widget<TextField>(phoneField).controller!.text, '9171234567');
  });

  testWidgets('returning from OTP shows the remaining one-minute cooldown', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final controller = AccountController(
      store: _MemoryAccountStore(),
      api: FakeMobileAccountApi(),
      tokenStore: MemoryTokenStore(),
    );
    addTearDown(controller.dispose);
    await controller.load();

    await tester.pumpWidget(
      AccountScope(
        controller: controller,
        child: MaterialApp(
          home: IdentityVerificationScreen(
            privacyNoticeAcceptedAt: privacyAcceptedAt,
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
    expect(find.text('Enter your OTP'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('phone_otp_cooldown_label')), findsOneWidget);
    expect(find.textContaining('Request another OTP in'), findsOneWidget);
    final sendButton = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('send_identity_otp_button')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(sendButton.onPressed, isNull);
  });

  testWidgets('send OTP stays clickable and explains missing information', (
    tester,
  ) async {
    await setPhoneSize(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: IdentityVerificationScreen(
          privacyNoticeAcceptedAt: privacyAcceptedAt,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sendButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Send OTP'),
    );
    expect(sendButton.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('send_identity_otp_button')));
    await tester.pump();
    expect(
      find.text('Enter a 10-digit mobile number starting with 9.'),
      findsOneWidget,
    );
  });

  testWidgets('settings shows the saved phone and pending account status', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final controller = AccountController(
      store: _MemoryAccountStore(),
      api: FakeMobileAccountApi(),
      tokenStore: MemoryTokenStore(),
    );
    await controller.load();
    await controller.sendCode('+639171234567');
    await controller.verifyCode('+639171234567', '123456');
    await controller.completePhoneVerification(
      phoneNumber: '+639171234567',
      privacyNoticeAcceptedAt: privacyAcceptedAt,
      fullName: 'Juan Dela Cruz',
      barangay: 'Kingking',
    );

    await tester.pumpWidget(
      AccountScope(
        controller: controller,
        child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Account management'), findsOneWidget);
    expect(find.text('+639171234567'), findsOneWidget);
    await tester.tap(find.text('Account management'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountManagementScreen), findsOneWidget);
    expect(find.text('PHONE VERIFIED'), findsOneWidget);
    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.text('Kingking'), findsOneWidget);
    expect(find.text('Valid ID'), findsNothing);
    expect(find.text('Face photo'), findsNothing);
  });
}

class _MemoryAccountStore implements AccountStore {
  AccountProfile? profile;

  @override
  Future<void> clear() async {
    profile = null;
  }

  @override
  Future<AccountProfile?> read() async => profile;

  @override
  Future<void> write(AccountProfile profile) async {
    this.profile = profile;
  }
}

class _HomeMarker extends StatelessWidget {
  const _HomeMarker();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Text('Home marker'));
  }
}
