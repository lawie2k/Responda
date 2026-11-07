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

import 'package:responda/core/navigation/app_routes.dart';
import 'package:responda/core/constants/pantukan_barangays.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    required this.phoneNumber,
    required this.otpService,
    required this.privacyNoticeAcceptedAt,
    this.previewOnly = false,
    super.key,
  });

  final String phoneNumber;
  final IdentityOtpService otpService;
  final DateTime privacyNoticeAcceptedAt;
  final bool previewOnly;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _codeController = TextEditingController();
  final _codeFocus = FocusNode();
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
    _codeFocus.dispose();
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
        setState(
          () => _error = widget.previewOnly
              ? 'OTP preview only. Verification is disabled.'
              : 'That code is incorrect. Please try again.',
        );
        return;
      }
      TextInput.finishAutofillContext(shouldSave: false);
      final account = _account;
      final profile = account?.profile;
      if (account?.hasAccount == true &&
          profile != null &&
          profile.fullName.trim().isNotEmpty &&
          pantukanBarangays.contains(profile.barangay)) {
        Navigator.of(context)
            .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
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

  Future<void> _continueWithDevelopmentCode() async {
    final code = _account?.developmentCode;
    if (code == null || _verifying || _resending) return;
    _codeController.text = code;
    setState(() => _error = null);
    await _verify();
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
      _codeFocus.requestFocus();
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
        if (widget.previewOnly)
          const IdentityInfoCard(
            icon: Icons.science_outlined,
            title: 'OTP UI preview',
            message: 'Enter any digits to preview the screen. No code is sent and verification is disabled.',
          ),
        if (_account?.developmentCode != null)
          IdentityInfoCard(
            icon: Icons.science_outlined,
            title: 'Development verification',
            message:
                'Test code: ${_account!.developmentCode}. SMS delivery is not configured yet.',
          ),
        const LocalizedText(
          'Verification code',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        AutofillGroup(
          onDisposeAction: AutofillContextAction.cancel,
          child: AnimatedBuilder(
            animation: Listenable.merge([_codeController, _codeFocus]),
            builder: (context, _) => SizedBox(
              height: 60,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // One native input preserves full-code SMS autofill and paste.
                  Opacity(
                    opacity: 0,
                    alwaysIncludeSemantics: true,
                    child: TextField(
                      key: const Key('identity_otp_field'),
                      controller: _codeController,
                      focusNode: _codeFocus,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      autofocus: true,
                      enabled: !_verifying && !_resending,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      maxLines: 1,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      onChanged: (_) => setState(() => _error = null),
                      onSubmitted: (_) => _verify(),
                      decoration: InputDecoration(
                        labelText: context.tr('Verification code'),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: ExcludeSemantics(
                      child: Row(
                        spacing: 8,
                        children: List.generate(6, (index) {
                          final code = _codeController.text;
                          final active =
                              _codeFocus.hasFocus &&
                              index ==
                                  (_codeController.selection.extentOffset < 0
                                      ? code.length.clamp(0, 5)
                                      : _codeController.selection.extentOffset
                                            .clamp(0, 5));
                          return Expanded(
                            child: Container(
                              key: Key('otp_digit_box_$index'),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _verifying || _resending
                                    ? AppColors.neutralSoft
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _error != null
                                      ? AppColors.danger
                                      : active
                                      ? AppColors.brand
                                      : AppColors.border,
                                  width: active ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                index < code.length
                                    ? code[index]
                                    : active
                                    ? '│'
                                    : '',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_error != null)
          Semantics(
            liveRegion: true,
            child: LocalizedText(
              _error!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
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
                ? context.tr('Sending…')
                : _remaining > 0
                ? context.tr(
                    'Resend code in {seconds}s',
                    values: {'seconds': _remaining},
                  )
                : context.tr('Resend code'),
            style: const TextStyle(color: AppColors.brand),
          ),
        ),
        if (_account?.developmentCode != null)
          TextButton(
            key: const Key('skip_otp_verification'),
            onPressed: _verifying || _resending
                ? null
                : _continueWithDevelopmentCode,
            child: const LocalizedText('Continue with test code'),
          ),
      ],
    );
  }
}
