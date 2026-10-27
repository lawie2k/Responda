import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/core/widgets/responda_bottom_navigation.dart';
import 'package:responda/core/widgets/responda_button.dart';
import 'package:responda/features/onboarding/presentation/account_scope.dart';

class AccountSuspendedScreen extends StatefulWidget {
  const AccountSuspendedScreen({super.key});

  @override
  State<AccountSuspendedScreen> createState() => _AccountSuspendedScreenState();
}

class _AccountSuspendedScreenState extends State<AccountSuspendedScreen> {
  bool _checking = false;

  Future<void> _checkStatus() async {
    if (_checking) return;
    setState(() => _checking = true);
    final account = AccountScope.of(context);
    final reachedServer = await account.refreshSession();
    if (!mounted) return;
    setState(() => _checking = false);
    if (account.isSuspended) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LocalizedText(
            reachedServer
                ? 'Your account is still suspended. Contact MDRRMO for assistance.'
                : 'Could not check your account. Connect to the internet and try again.',
          ),
        ),
      );
    }
  }

  Future<void> _openPhone() async {
    try {
      final opened = await launchUrl(
        Uri(scheme: 'tel', path: RespondaBottomNavigation.emergencyNumber),
        mode: LaunchMode.externalApplication,
      );
      if (opened) return;
    } catch (_) {
      // Keep the number visible if this device cannot open the phone app.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: LocalizedText(
          'Could not open the phone app. Dial 09476236516 manually.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = AccountScope.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/images/responda_logo.png',
                      height: 64,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.person_off_outlined,
                          size: 58,
                          color: Colors.white,
                        ),
                        SizedBox(height: 20),
                        LocalizedText(
                          'Account suspended',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 12),
                        LocalizedText(
                          'MDRRMO has suspended access to this account. You cannot submit reports while it is suspended.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const LocalizedText(
                    'Need help with your account?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const LocalizedText(
                    'Contact MDRRMO to ask about your account. After it is restored, sign in again using your phone number and OTP.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (account.profile != null) ...[
                    RespondaButton(
                      key: const Key('check_suspended_account'),
                      label: _checking ? 'Checking…' : 'Check account status',
                      onPressed: _checking ? null : _checkStatus,
                    ),
                    const SizedBox(height: 12),
                  ],
                  OutlinedButton.icon(
                    onPressed: _openPhone,
                    icon: const Icon(Icons.phone_outlined),
                    label: const LocalizedText('Call MDRRMO'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    RespondaBottomNavigation.emergencyNumber,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const LocalizedText(
                    'Calls do not share your GPS location. Tell MDRRMO where you are.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _checking
                        ? null
                        : () async {
                            await account.clearLocalSession();
                          },
                    child: const LocalizedText('Return to sign in'),
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
