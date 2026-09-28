import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum RespondaButtonStyle { primary, secondary, ghost, selected, danger }

class RespondaButton extends StatelessWidget {
  const RespondaButton({
    required this.label,
    required this.onPressed,
    this.style = RespondaButtonStyle.primary,
    this.height = 52,
    this.controlKey,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final RespondaButtonStyle style;
  final double height;
  final Key? controlKey;

  @override
  Widget build(BuildContext context) {
    final background = switch (style) {
      RespondaButtonStyle.primary => AppColors.brand,
      RespondaButtonStyle.secondary => AppColors.surface,
      RespondaButtonStyle.ghost => AppColors.surface,
      RespondaButtonStyle.selected => AppColors.brandSoft,
      RespondaButtonStyle.danger => AppColors.danger,
    };
    final foreground =
        style == RespondaButtonStyle.primary ||
            style == RespondaButtonStyle.danger
        ? AppColors.surface
        : AppColors.brand;
    final border =
        style == RespondaButtonStyle.primary ||
            style == RespondaButtonStyle.danger
        ? Colors.transparent
        : AppColors.brand;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: FilledButton(
        key: controlKey,
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textSecondary,
          side: BorderSide(color: border, width: 1.5),
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 21 / 15,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: LocalizedText(label, maxLines: 1, softWrap: false),
        ),
      ),
    );
  }
}
