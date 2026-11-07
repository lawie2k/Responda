import 'package:flutter/foundation.dart';
import 'package:responda/features/onboarding/data/account_controller.dart';
import 'package:responda/features/onboarding/domain/account_profile.dart';
import 'package:responda/features/onboarding/presentation/account_scope.dart';

import 'support/mobile_account_fakes.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responda/features/onboarding/data/identity_otp_service.dart';
import 'package:responda/features/onboarding/presentation/screens/verification/otp_verification_screen.dart';

class _Otp implements IdentityOtpService {
  String? submitted;
  @override
  Future<void> sendCode(String phoneNumber) async {}
  @override
  Future<bool> verifyCode(String phoneNumber, String code) async {
    submitted = code;
    return false;
  }
}

class _Profiles implements AccountStore {
  AccountProfile? value;
  @override
  Future<AccountProfile?> read() async => value;
  @override
  Future<void> write(AccountProfile profile) async {
    value = profile;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

void main() {
  for (final complete in [true, false]) {
    testWidgets(
      'verified account complete=$complete chooses the correct destination',
      (tester) async {
        final api = FakeMobileAccountApi()
          ..fullName = 'Synthetic tester'
          ..barangay = complete ? 'Kingking' : '';
        final account = AccountController(
          store: _Profiles(),
          api: api,
          tokenStore: MemoryTokenStore(),
        );
        addTearDown(account.dispose);
        await account.load();
        await account.sendCode('+639000000001');
        await tester.pumpWidget(
          AccountScope(
            controller: account,
            child: MaterialApp(
              routes: {
                '/home': (_) => const Scaffold(body: Text('Restored home')),
              },
              home: OtpVerificationScreen(
                phoneNumber: '+639000000001',
                otpService: account,
                privacyNoticeAcceptedAt: DateTime(2026),
              ),
            ),
          ),
        );
        await tester.enterText(
          find.byKey(const Key('identity_otp_field')),
          '123456',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(
          find.text('Restored home'),
          complete ? findsOneWidget : findsNothing,
        );
        expect(
          find.text('Account details'),
          complete ? findsNothing : findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      '$platform accepts a full autofilled code and verifies on Done',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final service = _Otp();
        await tester.pumpWidget(
          MaterialApp(
            home: OtpVerificationScreen(
              phoneNumber: '+639000000001',
              otpService: service,
              privacyNoticeAcceptedAt: DateTime(2026),
            ),
          ),
        );
        await tester.pump();
        final field = find.byKey(const Key('identity_otp_field'));
        for (var i = 0; i < 6; i++) {
          expect(find.byKey(Key('otp_digit_box_$i')), findsOneWidget);
        }
        expect(find.byKey(const Key('otp_digit_box_6')), findsNothing);
        expect(
          tester.widget<TextField>(field).autofillHints,
          contains(AutofillHints.oneTimeCode),
        );
        await tester.tap(field);
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '012345',
            selection: TextSelection.collapsed(offset: 6),
          ),
        );
        await tester.pump();
        expect(tester.widget<TextField>(field).controller!.text, '012345');
        expect(service.submitted, isNull);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(service.submitted, '012345');
        expect(
          find.text('That code is incorrect. Please try again.'),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }
}
