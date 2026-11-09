import 'package:flutter/material.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/responda_button.dart';
import '../../../../core/widgets/responda_glass.dart';
import 'verification/privacy_notice_screen.dart';

class AccountAccessScreen extends StatelessWidget {
  const AccountAccessScreen({super.key});

  void _back(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacementNamed(AppRoutes.language);
    }
  }

  void _continue(BuildContext context, {required bool signIn}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PrivacyNoticeScreen(isSigningIn: signIn),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.surface,
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: RespondaIosBackButton(
                    onPressed: () => _back(context),
                    fallback: IconButton(
                      tooltip: MaterialLocalizations.of(context)
                          .backButtonTooltip,
                      onPressed: () => _back(context),
                      icon: const Icon(
                        Icons.chevron_left_rounded,
                        color: AppColors.brand,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: const BoxDecoration(
                      color: AppColors.brandSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      'assets/images/responda_logo.png',
                      width: 108,
                      height: 108,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const LocalizedText(
                  'Welcome to RESPONDA',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.brand,
                    fontSize: 30,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                const LocalizedText(
                  'Sign in or create an account to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.phonelink_lock_rounded,
                      color: AppColors.brand,
                      size: 26,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LocalizedText(
                            'Secure access with your mobile number',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 6),
                          LocalizedText(
                            'Use a one-time verification code to access your account.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                RespondaButton(
                  key: const Key('account_sign_in_button'),
                  label: 'Sign in',
                  onPressed: () => _continue(context, signIn: true),
                ),
                const SizedBox(height: 12),
                RespondaButton(
                  key: const Key('account_create_button'),
                  label: 'Create an account',
                  style: RespondaButtonStyle.secondary,
                  onPressed: () => _continue(context, signIn: false),
                ),
                const SizedBox(height: 20),
                const LocalizedText(
                  'Already registered? Sign in with the same mobile number to restore your account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
