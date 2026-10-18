import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class IdentityInfoCard extends StatelessWidget {
  const IdentityInfoCard({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.brand, size: 23),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                LocalizedText(
                  message,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 17 / 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration identityInputDecoration({
  required String hintText,
  String? prefixText,
  String? errorText,
}) {
  return InputDecoration(
    hintText: hintText,
    prefixText: prefixText,
    errorText: errorText,
    filled: true,
    fillColor: AppColors.surface,
    counterText: '',
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.brand, width: 2),
    ),
  );
}
