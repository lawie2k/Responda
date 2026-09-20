import 'package:flutter/material.dart';

import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/features/onboarding/domain/account_profile.dart';
import 'package:responda/features/onboarding/presentation/account_scope.dart';

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
            verified ? 'Identity verified' : 'Identity review in progress',
            style: const TextStyle(
              color: AppColors.surface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          LocalizedText(
            verified ? 'Your RESPONDA identity has been approved.' : 'You can use the app while MDRRMO reviews your submitted identity.',
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
            icon: Icons.badge_outlined,
            label: 'Valid ID',
            value: profile.idSubmitted ? 'Submitted' : 'Not submitted',
          ),
          const Divider(height: 24, color: AppColors.border),
          _DetailRow(
            icon: Icons.face_retouching_natural_rounded,
            label: 'Face photo',
            value: profile.faceCaptured ? 'Captured' : 'Not captured',
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
