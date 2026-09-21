import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/core/widgets/responda_button.dart';
import 'package:responda/features/onboarding/data/identity_otp_service.dart';
import 'package:responda/features/onboarding/presentation/models/identity_media_picker.dart';
import 'package:responda/features/onboarding/presentation/widgets/identity_verification_widgets.dart';
import 'package:responda/features/onboarding/presentation/widgets/onboarding_step_scaffold.dart';

import 'valid_id_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    required this.phoneNumber,
    required this.otpService,
    required this.mediaPicker,
    super.key,
  });

  final String phoneNumber;
  final IdentityOtpService otpService;
  final IdentityMediaPicker? mediaPicker;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _codeController = TextEditingController();
  bool _verifying = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_codeController.text.length != 6 || _verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    final valid = await widget.otpService.verifyCode(
      widget.phoneNumber,
      _codeController.text,
    );
    if (!mounted) return;
    setState(() => _verifying = false);
    if (!valid) {
      setState(() => _error = 'That code is incorrect. Please try again.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ValidIdScreen(
          phoneNumber: widget.phoneNumber,
          mediaPicker: widget.mediaPicker,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      step: 3,
      title: 'Enter your OTP',
      subtitle: context.tr(
        'Enter the 6-digit code sent to {phone}.',
        values: {'phone': widget.phoneNumber},
      ),
      children: [
        TextField(
          key: const Key('identity_otp_field'),
          controller: _codeController,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: 8,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onChanged: (_) => setState(() => _error = null),
          decoration: identityInputDecoration(
            hintText: '000000',
            errorText: _error == null ? null : context.tr(_error!),
          ),
        ),
        RespondaButton(
          key: const Key('verify_identity_otp_button'),
          label: _verifying ? 'Verifying…' : 'Verify OTP',
          onPressed: _codeController.text.length == 6 && !_verifying
              ? _verify
              : null,
        ),
        TextButton(
          onPressed: () => widget.otpService.sendCode(widget.phoneNumber),
          child: const LocalizedText(
            'Resend code',
            style: TextStyle(color: AppColors.brand),
          ),
        ),
        const IdentityPrototypeNotice(),
      ],
    );
  }
}
