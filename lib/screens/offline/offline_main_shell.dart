import 'package:flutter/material.dart';

import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/core/widgets/responda_bottom_navigation.dart';
import 'package:responda/screens/online/emergency_info_screen.dart';
import 'package:responda/screens/online/settings_screen.dart';

import 'offline_home_screen.dart';
import 'offline_reports_screen.dart';

class OfflineMainShell extends StatefulWidget {
  const OfflineMainShell({this.initialItem = RespondaNavItem.home, super.key});

  final RespondaNavItem initialItem;

  @override
  State<OfflineMainShell> createState() => _OfflineMainShellState();
}

class _OfflineMainShellState extends State<OfflineMainShell> {
  static const _screens = <Widget>[
    OfflineHomeScreen(),
    OfflineReportsScreen(),
    EmergencyInfoScreen(),
    SettingsScreen(),
  ];

  late RespondaNavItem _activeItem;

  @override
  void initState() {
    super.initState();
    _activeItem = widget.initialItem;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Material(
        color: AppColors.background,
        child: IndexedStack(index: _activeItem.index, children: _screens),
      ),
      bottomNavigationBar: Material(
        color: AppColors.surface,
        child: SafeArea(
          top: false,
          child: RespondaBottomNavigation(
            activeItem: _activeItem,
            onSelected: (item) => setState(() => _activeItem = item),
          ),
        ),
      ),
    );
  }
}
