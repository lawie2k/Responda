import 'package:flutter/material.dart';

import 'package:responda/core/navigation/app_routes.dart';
import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/core/widgets/responda_button.dart';
import 'package:responda/features/onboarding/presentation/widgets/identity_verification_widgets.dart';
import 'package:responda/features/onboarding/presentation/widgets/onboarding_step_scaffold.dart';

import 'phone_verification_screen.dart';

class PrivacyNoticeScreen extends StatefulWidget {
  const PrivacyNoticeScreen({super.key});

  @override
  State<PrivacyNoticeScreen> createState() => _PrivacyNoticeScreenState();
}

class _PrivacyNoticeScreenState extends State<PrivacyNoticeScreen> {
  bool _noticeAccepted = false;

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      step: 2,
      onBack: _goBack,
      title: 'Your privacy matters',
      subtitle: 'Read how RESPONDA uses your information before setting up your account.',
      children: [
        const IdentityInfoCard(
          icon: Icons.phone_iphone_rounded,
          title: 'Only your phone number is required',
          message: 'Your number is used for OTP account access and emergency follow-up. RESPONDA does not require a valid ID or face photo.',
        ),
        const IdentityInfoCard(
          icon: Icons.person_outline_rounded,
          title: 'Basic details are optional',
          message: 'You may add your name and barangay, but you can skip them and still report an emergency.',
        ),
        const IdentityInfoCard(
          icon: Icons.emergency_outlined,
          title: 'Information included in reports',
          message: 'Reports can include incident details, GPS coordinates, timestamps, and photos you choose to attach.',
        ),
        InkWell(
          onTap: () => setState(() => _noticeAccepted = !_noticeAccepted),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  key: const Key('privacy_notice_checkbox'),
                  value: _noticeAccepted,
                  activeColor: AppColors.brand,
                  onChanged: (value) =>
                      setState(() => _noticeAccepted = value ?? false),
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: LocalizedText(
                      'I have read and understand this privacy notice.',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        height: 17 / 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        RespondaButton(
          key: const Key('continue_privacy_notice_button'),
          label: 'Continue',
          onPressed: _noticeAccepted ? _continue : null,
        ),
      ],
    );
  }

  void _continue() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            IdentityVerificationScreen(privacyNoticeAcceptedAt: DateTime.now()),
      ),
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
