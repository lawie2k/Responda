import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import 'responda_button.dart';

enum RespondaNavItem { home, reports, information, settings }

typedef PhoneLauncher = Future<bool> Function(Uri uri);

class RespondaBottomNavigation extends StatelessWidget {
  const RespondaBottomNavigation({
    required this.activeItem,
    this.onSelected,
    this.onCallPressed,
    this.phoneLauncher,
    super.key,
  });

  final RespondaNavItem activeItem;
  final ValueChanged<RespondaNavItem>? onSelected;
  final VoidCallback? onCallPressed;
  final PhoneLauncher? phoneLauncher;

  static const emergencyNumber = '09476236516';

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
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _buildNavigationItem(_items[0]),
          _buildNavigationItem(_items[1]),
          Expanded(child: _CallAction(onTap: () => _handleCall(context))),
          _buildNavigationItem(_items[2]),
          _buildNavigationItem(_items[3]),
        ],
      ),
    );
  }

  Widget _buildNavigationItem((RespondaNavItem, String, String) item) {
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
            height: 62,
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.$2,
                      maxLines: 1,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w500,
                        height: 16 / 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleCall(BuildContext context) {
    if (onCallPressed case final callback?) {
      callback();
      return;
    }
    _showEmergencyCallSheet(context, phoneLauncher: phoneLauncher);
  }
}

class _CallAction extends StatelessWidget {
  const _CallAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: -20,
            child: Semantics(
              button: true,
              label: 'Call MDRRMO',
              child: Material(
                key: const Key('emergency_call_nav_button'),
                color: AppColors.brand,
                elevation: 7,
                shadowColor: AppColors.brand.withValues(alpha: 0.35),
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: onTap,
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 64,
                    height: 64,
                    child: Icon(
                      Icons.phone_rounded,
                      color: AppColors.surface,
                      size: 29,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Positioned(
            bottom: 8,
            child: Text(
              'Call',
              style: TextStyle(
                color: AppColors.brand,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 16 / 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showEmergencyCallSheet(
  BuildContext context, {
  PhoneLauncher? phoneLauncher,
}) async {
  final shouldOpenPhone = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => const _EmergencyCallSheet(),
  );

  if (shouldOpenPhone != true || !context.mounted) {
    return;
  }

  final phoneUri = Uri(
    scheme: 'tel',
    path: RespondaBottomNavigation.emergencyNumber,
  );

  var opened = false;
  try {
    opened = await (phoneLauncher?.call(phoneUri) ?? launchUrl(phoneUri));
  } catch (_) {
    opened = false;
  }

  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Could not open the phone app. Dial 09476236516 manually.',
        ),
      ),
    );
  }
}

class _EmergencyCallSheet extends StatelessWidget {
  const _EmergencyCallSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          2,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: AppColors.brandSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phone_in_talk_rounded,
                color: AppColors.brand,
                size: 29,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Call MDRRMO?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Calling will not send your accurate GPS location or report details to MDRRMO. Be ready to tell the dispatcher where you are.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 19 / 13,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.dialpad_rounded, color: AppColors.brand, size: 20),
                  SizedBox(width: 8),
                  Text(
                    RespondaBottomNavigation.emergencyNumber,
                    style: TextStyle(
                      color: AppColors.brand,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            RespondaButton(
              key: const Key('open_phone_app_button'),
              label: 'Open Phone App',
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 8),
            RespondaButton(
              key: const Key('cancel_emergency_call_button'),
              label: 'Cancel',
              style: RespondaButtonStyle.ghost,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
