import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/core/widgets/responda_button.dart';
import 'package:responda/features/onboarding/data/identity_otp_service.dart';
import 'package:responda/features/onboarding/data/account_controller.dart';
import 'package:responda/core/network/responda_api_client.dart';
import 'package:responda/features/onboarding/presentation/widgets/identity_verification_widgets.dart';
import 'package:responda/features/onboarding/presentation/widgets/onboarding_step_scaffold.dart';

import 'optional_profile_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    required this.phoneNumber,
    required this.otpService,
    required this.privacyNoticeAcceptedAt,
    super.key,
  });

  final String phoneNumber;
  final IdentityOtpService otpService;
  final DateTime privacyNoticeAcceptedAt;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _codeController = TextEditingController();
  bool _verifying = false;
  String? _error;
  bool _resending = false;
  Timer? _timer;
  AccountController? get _account => widget.otpService is AccountController
      ? widget.otpService as AccountController
      : null;
  int get _remaining =>
      (_account?.resendAt?.difference(DateTime.now()).inSeconds ?? 0).clamp(
        0,
        60,
      );

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_codeController.text.length != 6 || _verifying || _resending) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
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
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => OptionalProfileScreen(
            phoneNumber: widget.phoneNumber,
            privacyNoticeAcceptedAt: widget.privacyNoticeAcceptedAt,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is RespondaApiException
              ? error.message
              : 'Unable to verify. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    if (_resending || _verifying || _remaining > 0) return;
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      await widget.otpService.sendCode(widget.phoneNumber);
      _codeController.clear();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is RespondaApiException
              ? error.message
              : 'The verification code could not be sent.',
        );
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      step: 4,
      title: 'Enter your OTP',
      subtitle: context.tr(
        'Enter the 6-digit code sent to {phone}.',
        values: {'phone': widget.phoneNumber},
      ),
      children: [
        if (_account?.developmentCode != null)
          IdentityInfoCard(
            icon: Icons.science_outlined,
            title: 'Development verification',
            message:
                'Test code: ${_account!.developmentCode}. SMS delivery is not configured yet.',
          ),
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
          onPressed:
              _codeController.text.length == 6 && !_verifying && !_resending
              ? _verify
              : null,
        ),
        TextButton(
          onPressed: _remaining > 0 || _resending || _verifying
              ? null
              : _resend,
          child: Text(
            _resending
                ? 'Sending…'
                : _remaining > 0
                ? 'Resend in ${_remaining}s'
                : 'Resend code',
            style: const TextStyle(color: AppColors.brand),
          ),
        ),
      ],
    );
  }
}
