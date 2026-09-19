import 'package:flutter/material.dart';

import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/core/widgets/responda_bottom_navigation.dart';

import 'emergency_info_screen.dart';
import 'home_screen.dart';
import 'my_reports_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({this.initialItem = RespondaNavItem.home, super.key});

  final RespondaNavItem initialItem;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const _screens = <Widget>[
    HomeScreen(),
    MyReportsScreen(),
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
            onSelected: _selectItem,
          ),
        ),
      ),
    );
  }

  void _selectItem(RespondaNavItem item) {
    if (item == _activeItem) {
      return;
    }

    setState(() => _activeItem = item);
  }
}
