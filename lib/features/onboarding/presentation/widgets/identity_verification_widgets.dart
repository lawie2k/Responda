import 'dart:io';

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

class IdentityPrototypeNotice extends StatelessWidget {
  const IdentityPrototypeNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return const LocalizedText(
      'Prototype mode: SMS delivery will be connected with the authentication backend. For testing, use OTP 123456.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 11,
        height: 16 / 11,
      ),
    );
  }
}

class IdentityMediaPreview extends StatelessWidget {
  const IdentityMediaPreview({
    required this.path,
    required this.icon,
    required this.emptyTitle,
    super.key,
  });

  final String? path;
  final IconData icon;
  final String emptyTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.neutralSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: path == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppColors.brand, size: 48),
                const SizedBox(height: 10),
                LocalizedText(
                  emptyTitle,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          : Image.file(File(path!), fit: BoxFit.cover),
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
