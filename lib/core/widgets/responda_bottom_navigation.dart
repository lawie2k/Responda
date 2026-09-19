import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

enum RespondaNavItem { home, reports, information, settings }

class RespondaBottomNavigation extends StatelessWidget {
  const RespondaBottomNavigation({
    required this.activeItem,
    this.onSelected,
    super.key,
  });

  final RespondaNavItem activeItem;
  final ValueChanged<RespondaNavItem>? onSelected;

  static const _items = <(RespondaNavItem, String, String)>[
    (RespondaNavItem.home, 'Home', 'assets/icons/nav_home.svg'),
    (RespondaNavItem.reports, 'My Reports', 'assets/icons/nav_reports.svg'),
    (
      RespondaNavItem.information,
      'Emergency Info',
      'assets/icons/nav_info.svg',
    ),
    (RespondaNavItem.settings, 'Settings', 'assets/icons/nav_settings.svg'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: _items.map((item) {
          final isActive = item.$1 == activeItem;
          final color = isActive ? AppColors.brand : AppColors.textSecondary;
          return Expanded(
            child: Semantics(
              button: true,
              selected: isActive,
              label: item.$2,
              child: InkWell(
                onTap: () => onSelected?.call(item.$1),
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 58,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        item.$3,
                        width: item.$1 == RespondaNavItem.settings ? 24 : 22,
                        height: item.$1 == RespondaNavItem.settings ? 24 : 22,
                        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.$2,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w500,
                          height: 15 / 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
