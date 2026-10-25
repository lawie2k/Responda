import 'package:flutter/material.dart';

import 'package:responda/core/navigation/app_routes.dart';
import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/core/widgets/responda_button.dart';

class VerificationSubmittedScreen extends StatelessWidget {
  const VerificationSubmittedScreen({
    required this.phoneNumber,
    this.isBetaLocalSetup = false,
    super.key,
  });

  final String? phoneNumber;
  final bool isBetaLocalSetup;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 350),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: const BoxDecoration(
                      color: AppColors.brandSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isBetaLocalSetup
                          ? Icons.account_circle_outlined
                          : Icons.verified_user_rounded,
                      color: isBetaLocalSetup
                          ? AppColors.warning
                          : AppColors.success,
                      size: 46,
                    ),
                  ),
                  const SizedBox(height: 20),
                  LocalizedText(
                    isBetaLocalSetup
                        ? 'Beta account setup complete'
                        : 'Phone verified',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LocalizedText(
                    context.tr(
                      isBetaLocalSetup
                          ? 'Your beta profile is ready. You can send reports when connected to the beta server.'
                          : 'Your number {phone} is verified. You can now use RESPONDA and report emergencies.',
                      values: {'phone': phoneNumber ?? ''},
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 20 / 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (isBetaLocalSetup) ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.warningSoft,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const LocalizedText(
                        'Phone verification is paused during beta testing.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12,
                          height: 17 / 12,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  RespondaButton(
                    key: const Key('open_responda_after_identity_button'),
                    label: 'Open RESPONDA',
                    onPressed: () => Navigator.of(context)
                        .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
