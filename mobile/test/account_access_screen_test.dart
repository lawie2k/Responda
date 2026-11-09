import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responda/features/onboarding/presentation/screens/account_access_screen.dart';
import 'package:responda/features/onboarding/presentation/screens/verification/phone_verification_screen.dart';
import 'package:responda/features/onboarding/presentation/screens/verification/privacy_notice_screen.dart';

void main() {
  for (final signIn in [true, false]) {
    testWidgets(
      'account choice signIn=$signIn retains consent and reaches phone verification',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(const MaterialApp(home: AccountAccessScreen()));
        final choice = find.byKey(
          Key(signIn ? 'account_sign_in_button' : 'account_create_button'),
        );
        await tester.ensureVisible(choice);
        await tester.tap(choice);
        await tester.pumpAndSettle();
        expect(find.byType(PrivacyNoticeScreen), findsOneWidget);
        expect(
          tester
              .widget<PrivacyNoticeScreen>(find.byType(PrivacyNoticeScreen))
              .isSigningIn,
          signIn,
        );
        expect(
          find.byType(LinearProgressIndicator),
          signIn ? findsNothing : findsOneWidget,
        );
        expect(find.text('1 of 4'), signIn ? findsNothing : findsOneWidget);
        final consent = find.byKey(const Key('privacy_notice_checkbox'));
        await tester.ensureVisible(consent);
        await tester.tap(consent);
        await tester.pumpAndSettle();
        final next = find.byKey(const Key('continue_privacy_notice_button'));
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(
          find.byType(LinearProgressIndicator),
          signIn ? findsNothing : findsOneWidget,
        );
        expect(find.text('2 of 4'), signIn ? findsNothing : findsOneWidget);
        final phone = find.byType(IdentityVerificationScreen);
        expect(phone, findsOneWidget);
        expect(
          tester.widget<IdentityVerificationScreen>(phone).isSigningIn,
          signIn,
        );
        expect(
          find.text(
            signIn ? 'Sign in with your number' : 'Verify your mobile number',
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('send_identity_otp_button')),
          findsOneWidget,
        );
        await tester.ensureVisible(find.byIcon(Icons.chevron_left_rounded));
        await tester.tap(find.byIcon(Icons.chevron_left_rounded));
        await tester.pumpAndSettle();
        expect(find.byType(PrivacyNoticeScreen), findsOneWidget);
        await tester.ensureVisible(find.byIcon(Icons.chevron_left_rounded));
        await tester.tap(find.byIcon(Icons.chevron_left_rounded));
        await tester.pumpAndSettle();
        expect(find.byType(AccountAccessScreen), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
