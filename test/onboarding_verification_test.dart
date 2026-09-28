import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:responda/core/navigation/app_routes.dart';
import 'package:responda/features/onboarding/data/account_controller.dart';
import 'package:responda/features/onboarding/domain/account_profile.dart';
import 'package:responda/features/onboarding/presentation/account_scope.dart';
import 'package:responda/features/onboarding/presentation/screens/identity_verification_screen.dart';
import 'package:responda/screens/online/account_management_screen.dart';
import 'package:responda/screens/online/settings_screen.dart';

void main() {
  Future<void> setPhoneSize(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  test('account profile persists its pending verification state', () async {
    final store = _MemoryAccountStore();
    final controller = AccountController(store: store);
    await controller.load();
    expect(controller.hasAccount, isFalse);

    await controller.submitIdentity(phoneNumber: '+639171234567');
    expect(controller.profile?.status, AccountVerificationStatus.pending);

    final restarted = AccountController(store: store);
    await restarted.load();
    expect(restarted.profile?.phoneNumber, '+639171234567');
    expect(restarted.profile?.idSubmitted, isTrue);
    expect(restarted.profile?.faceCaptured, isTrue);
  });

  testWidgets('identity onboarding completes with the prototype OTP', (
    tester,
  ) async {
    await setPhoneSize(tester);
    final controller = AccountController(store: _MemoryAccountStore());
    await controller.load();

    await tester.pumpWidget(
      AccountScope(
        controller: controller,
        child: MaterialApp(
          home: IdentityVerificationScreen(
            mediaPicker: (_) async => 'assets/images/responda_logo.png',
          ),
          routes: {AppRoutes.home: (_) => const _HomeMarker()},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Verify your identity'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('identity_phone_field')),
      '9171234567',
    );
    await tester.tap(find.byKey(const Key('identity_consent_checkbox')));
    await tester.pump();
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

    expect(find.text('Upload a valid ID'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Gallery'));
    await tester.pumpAndSettle();
    final idContinue = find.byKey(const Key('continue_identity_id_button'));
    await tester.ensureVisible(idContinue);
    await tester.tap(idContinue);
    await tester.pumpAndSettle();

    expect(find.text('Take a face photo'), findsOneWidget);
    expect(find.text('Open Front Camera'), findsNothing);
    await tester.tap(find.byKey(const Key('capture_identity_face_button')));
    await tester.pumpAndSettle();
    final submit = find.byKey(const Key('submit_identity_button'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('Verification pending'), findsOneWidget);
    expect(controller.profile?.phoneNumber, '+639171234567');
    expect(controller.profile?.status, AccountVerificationStatus.pending);

    await tester.tap(
      find.byKey(const Key('open_responda_after_identity_button')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(_HomeMarker), findsOneWidget);
  });

  testWidgets('phone number only accepts 9 as its first digit', (tester) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      const MaterialApp(home: IdentityVerificationScreen()),
    );

    final phoneField = find.byKey(const Key('identity_phone_field'));
    await tester.enterText(phoneField, '0');
    expect(tester.widget<TextField>(phoneField).controller!.text, isEmpty);

    await tester.enterText(phoneField, '9');
    expect(tester.widget<TextField>(phoneField).controller!.text, '9');

    await tester.enterText(phoneField, '9171234567');
    expect(tester.widget<TextField>(phoneField).controller!.text, '9171234567');
  });

  testWidgets('send OTP stays clickable and explains missing information', (
    tester,
  ) async {
    await setPhoneSize(tester);

    await tester.pumpWidget(
      const MaterialApp(home: IdentityVerificationScreen()),
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
    final controller = AccountController(store: _MemoryAccountStore());
    await controller.load();
    await controller.submitIdentity(phoneNumber: '+639171234567');

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
    expect(find.text('PENDING VERIFICATION'), findsOneWidget);
    expect(find.text('Submitted'), findsOneWidget);
    expect(find.text('Captured'), findsOneWidget);
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
