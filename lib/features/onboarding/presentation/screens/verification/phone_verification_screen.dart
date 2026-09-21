import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/core/widgets/responda_button.dart';
import 'package:responda/features/onboarding/data/identity_otp_service.dart';
import 'package:responda/features/onboarding/presentation/models/identity_media_picker.dart';
import 'package:responda/features/onboarding/presentation/widgets/identity_verification_widgets.dart';
import 'package:responda/features/onboarding/presentation/widgets/onboarding_step_scaffold.dart';

import 'otp_verification_screen.dart';

class IdentityVerificationScreen extends StatefulWidget {
  const IdentityVerificationScreen({
    this.otpService = const PrototypeIdentityOtpService(),
    this.mediaPicker,
    super.key,
  });

  final IdentityOtpService otpService;
  final IdentityMediaPicker? mediaPicker;

  @override
  State<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends State<IdentityVerificationScreen> {
  final _phoneController = TextEditingController();
  bool _consented = false;
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
    if (!_consented) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LocalizedText(
            'Please accept the identity verification consent.',
          ),
        ),
      );
      return;
    }
    setState(() => _sending = true);
    final phoneNumber = '+63${_phoneController.text}';
    try {
      await widget.otpService.sendCode(phoneNumber);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => OtpVerificationScreen(
            phoneNumber: phoneNumber,
            otpService: widget.otpService,
            mediaPicker: widget.mediaPicker,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: LocalizedText('The verification code could not be sent.'),
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
      step: 2,
      title: 'Verify your identity',
      subtitle:
          'Create or recover your RESPONDA account using your mobile number.',
      children: [
        const IdentityInfoCard(
          icon: Icons.phone_iphone_rounded,
          title: 'One account per phone number',
          message: 'Already registered? Use the same phone number and OTP to recover your verified account.',
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
          ],
          onChanged: (_) => setState(() {}),
          decoration: identityInputDecoration(
            hintText: '9XX XXX XXXX',
            prefixText: '+63  ',
          ),
        ),
        InkWell(
          onTap: () => setState(() => _consented = !_consented),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  key: const Key('identity_consent_checkbox'),
                  value: _consented,
                  activeColor: AppColors.brand,
                  onChanged: (value) =>
                      setState(() => _consented = value ?? false),
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: LocalizedText(
                      'I consent to using my phone number, valid ID, and face photo for identity verification.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 17 / 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        RespondaButton(
          key: const Key('send_identity_otp_button'),
          label: _sending ? 'Sending…' : 'Send OTP',
          onPressed: _sending ? null : _sendCode,
        ),
        const IdentityPrototypeNotice(),
      ],
    );
  }
}
