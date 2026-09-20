import 'package:flutter/material.dart';

export '../localization/localized_text.dart';
export '../localization/app_strings.dart';

abstract final class AppColors {
  static const brand = Color(0xFF7A1F2B);
  static const brandDark = Color(0xFF54131D);
  static const brandSoft = Color(0xFFF8ECEE);
  static const surface = Color(0xFFFFFFFF);
  static const background = Color(0xFFF7F7F8);
  static const textPrimary = Color(0xFF1C1C1E);
  static const textSecondary = Color(0xFF6B6B70);
  static const border = Color(0xFFE6E6E8);
  static const danger = Color(0xFFD92D20);
  static const dangerSoft = Color(0xFFFEE4E2);
  static const success = Color(0xFF1F8A4C);
  static const successSoft = Color(0xFFDDF6E8);
  static const warning = Color(0xFFC47C00);
  static const warningSoft = Color(0xFFFFF2C8);
  static const info = Color(0xFF2563A8);
  static const infoSoft = Color(0xFFE2F0FF);
  static const neutralSoft = Color(0xFFF2F2F4);
  static const heroText = Color(0xFFF7DDE1);
}
