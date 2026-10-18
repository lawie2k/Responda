import 'package:flutter/material.dart';

import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/features/onboarding/domain/account_profile.dart';
import 'package:responda/features/onboarding/presentation/account_scope.dart';
import 'package:responda/features/onboarding/presentation/screens/verification/privacy_notice_screen.dart';

class AccountManagementScreen extends StatelessWidget {
  const AccountManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = AccountScope.maybeOf(context)?.profile;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(onBack: () => Navigator.of(context).pop()),
                  const SizedBox(height: 22),
                  if (profile == null)
                    const _NoAccountCard()
                  else ...[
                    _StatusCard(profile: profile),
                    const SizedBox(height: 14),
                    _DetailsCard(profile: profile),
                    const SizedBox(height: 14),
                    const _RecoveryCard(),
                    const SizedBox(height: 14),
                    const _SignOutButton(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignOutButton extends StatefulWidget {
  const _SignOutButton();
  @override
  State<_SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends State<_SignOutButton> {
  bool _busy = false;
  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await AccountScope.maybeOf(context)!.clearLocalSession();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const PrivacyNoticeScreen()),
        (_) => false,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not sign out. Check your connection and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: _busy ? null : _signOut,
    icon: const Icon(Icons.logout),
    label: Text(_busy ? 'Signing out…' : 'Sign out'),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: onBack,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AppColors.brand),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.brand,
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: LocalizedText(
            'Account Management',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.profile});

  final AccountProfile profile;

  @override
  Widget build(BuildContext context) {
    final verified = profile.status == AccountVerificationStatus.verified;
    final color = verified ? AppColors.success : AppColors.warning;
    final background = verified ? AppColors.successSoft : AppColors.warningSoft;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: LocalizedText(
              context.tr(profile.status.label).toUpperCase(),
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 13),
          LocalizedText(
            verified ? 'Mobile number verified' : 'Account needs attention',
            style: const TextStyle(
              color: AppColors.surface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          LocalizedText(
            verified
                ? 'Your phone number is verified and your RESPONDA account is active.'
                : 'Check your phone verification before recovering this account.',
            style: const TextStyle(
              color: AppColors.heroText,
              fontSize: 12,
              height: 17 / 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.profile});

  final AccountProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _DetailRow(
            icon: Icons.phone_iphone_rounded,
            label: 'Phone number',
            value: profile.phoneNumber,
          ),
          const Divider(height: 24, color: AppColors.border),
          _DetailRow(
            icon: Icons.person_outline_rounded,
            label: 'Full name',
            value: profile.fullName.isEmpty ? 'Not provided' : profile.fullName,
          ),
          const Divider(height: 24, color: AppColors.border),
          _DetailRow(
            icon: Icons.location_city_outlined,
            label: 'Barangay',
            value: profile.barangay.isEmpty ? 'Not provided' : profile.barangay,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.brandSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.brand, size: 20),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LocalizedText(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              LocalizedText(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecoveryCard extends StatelessWidget {
  const _RecoveryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.infoSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.restore_rounded, color: AppColors.info, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: LocalizedText(
              'When signing in on a new phone or after reinstalling, use this same phone number and complete the OTP.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                height: 17 / 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoAccountCard extends StatelessWidget {
  const _NoAccountCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: const LocalizedText(
        'No account information is available on this device.',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
      ),
    );
  }
}
