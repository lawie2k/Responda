import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/core/navigation/app_routes.dart';
import 'package:responda/core/widgets/responda_button.dart';
import 'package:responda/features/onboarding/data/identity_otp_service.dart';
import 'package:responda/features/onboarding/presentation/account_scope.dart';
import 'package:responda/core/network/responda_api_client.dart';
import 'package:responda/features/onboarding/presentation/widgets/identity_verification_widgets.dart';
import 'package:responda/features/onboarding/presentation/widgets/onboarding_step_scaffold.dart';

import 'otp_verification_screen.dart';

class IdentityVerificationScreen extends StatefulWidget {
  const IdentityVerificationScreen({
    required this.privacyNoticeAcceptedAt,
    this.otpService,
    super.key,
  });

  final DateTime privacyNoticeAcceptedAt;
  final IdentityOtpService? otpService;

  @override
  State<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends State<IdentityVerificationScreen> {
  final _phoneController = TextEditingController();
  bool _sending = false;

  bool get _validPhone =>
      _phoneController.text.length == 10 &&
      _phoneController.text.startsWith('9');

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_sending) return;
    if (!_validPhone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LocalizedText(
            'Enter a 10-digit mobile number starting with 9.',
          ),
        ),
      );
      return;
    }
    setState(() => _sending = true);
    final phoneNumber = '+63${_phoneController.text}';
    try {
      final service = widget.otpService ?? AccountScope.maybeOf(context);
      if (service == null) {
        throw const RespondaApiException('Account storage is not available.');
      }
      await service.sendCode(phoneNumber);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => OtpVerificationScreen(
            phoneNumber: phoneNumber,
            otpService: service,
            privacyNoticeAcceptedAt: widget.privacyNoticeAcceptedAt,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is RespondaApiException
                  ? error.message
                  : 'The verification code could not be sent.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      step: 3,
      onBack: _goBack,
      title: 'Verify your mobile number',
      subtitle: 'Enter your number to receive an OTP for account access and recovery.',
      children: [
        const IdentityInfoCard(
          icon: Icons.phone_iphone_rounded,
          title: 'One account per phone number',
          message: 'Already registered? Use the same phone number and OTP to recover your account.',
        ),
        const LocalizedText(
          'Mobile number',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextField(
          key: const Key('identity_phone_field'),
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
            _PhilippineMobileNumberFormatter(),
          ],
          onChanged: (_) => setState(() {}),
          decoration: identityInputDecoration(
            hintText: '9XX XXX XXXX',
            prefixText: '+63  ',
          ),
        ),
        RespondaButton(
          key: const Key('send_identity_otp_button'),
          label: _sending ? 'Sending…' : 'Send OTP',
          onPressed: _sending ? null : _sendCode,
        ),
      ],
    );
  }

  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushReplacementNamed(AppRoutes.language);
  }
}

class _PhilippineMobileNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty || newValue.text.startsWith('9')) {
      return newValue;
    }
    return oldValue;
  }
}
