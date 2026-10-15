import 'package:flutter/material.dart';

import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/core/widgets/responda_button.dart';

class OutsidePantukanScreen extends StatelessWidget {
  const OutsidePantukanScreen({required this.onOpenSettings, super.key});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 350),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Image.asset(
                    'assets/images/responda_logo.png',
                    width: 42,
                    height: 42,
                  ),
                ),
                const SizedBox(height: 48),
                Container(
                  width: 116,
                  height: 116,
                  decoration: const BoxDecoration(
                    color: AppColors.brandSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_off_rounded,
                    color: AppColors.brand,
                    size: 58,
                  ),
                ),
                const SizedBox(height: 22),
                const LocalizedText(
                  'Outside Pantukan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const LocalizedText(
                  'Reporting is unavailable here',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.brand,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                const LocalizedText(
                  'RESPONDA reports can only be submitted while you are within Pantukan. You cannot create a report from this location.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 21 / 14,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warningSoft,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.phone_outlined,
                        color: AppColors.brand,
                        size: 23,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: LocalizedText(
                          'If there is an emergency, use the Call button below to contact MDRRMO.',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            height: 19 / 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                RespondaButton(
                  key: const Key('outside_pantukan_open_settings_button'),
                  label: 'Open Settings',
                  style: RespondaButtonStyle.secondary,
                  onPressed: onOpenSettings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
