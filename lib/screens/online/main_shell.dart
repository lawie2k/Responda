import 'package:flutter/material.dart';

import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/core/widgets/responda_bottom_navigation.dart';
import 'package:responda/features/onboarding/presentation/account_scope.dart';
import 'package:responda/features/testing/presentation/testing_mode_scope.dart';
import 'package:responda/features/tutorial/data/home_tutorial_store.dart';
import 'package:responda/features/tutorial/presentation/home_tutorial_controller.dart';
import 'package:responda/features/tutorial/presentation/home_tutorial_overlay.dart';
import 'package:responda/screens/outside_pantukan/outside_pantukan_screen.dart';

import 'emergency_info_screen.dart';
import 'home_screen.dart';
import 'my_reports_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    this.initialItem = RespondaNavItem.home,
    this.tutorialStore = const SharedPreferencesHomeTutorialStore(),
    super.key,
  });

  final RespondaNavItem initialItem;
  final HomeTutorialProgressStore tutorialStore;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late RespondaNavItem _activeItem;
  late final HomeTutorialController _tutorialController;
  final _reportButtonKey = GlobalKey();
  final _quickIncidentKey = GlobalKey();
  final _gpsCardKey = GlobalKey();
  final _callButtonKey = GlobalKey();
  final _tutorialSurfaceKey = GlobalKey();
  bool _tutorialLoadRequested = false;

  @override
  void initState() {
    super.initState();
    _activeItem = widget.initialItem;
    _tutorialController = HomeTutorialController(store: widget.tutorialStore)
      ..addListener(_tutorialChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final hasAccount = AccountScope.maybeOf(context)?.hasAccount ?? false;
    final outsidePantukan =
        TestingModeScope.maybeOf(context)?.outsidePantukan ?? false;
    if (!_tutorialLoadRequested &&
        hasAccount &&
        !outsidePantukan &&
        widget.initialItem == RespondaNavItem.home) {
      _tutorialLoadRequested = true;
      _tutorialController.load();
    }
  }

  @override
  void dispose() {
    _tutorialController
      ..removeListener(_tutorialChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outsidePantukan =
        TestingModeScope.maybeOf(context)?.outsidePantukan ?? false;
    final screens = <Widget>[
      outsidePantukan
          ? OutsidePantukanScreen(
              onOpenSettings: () => _selectItem(RespondaNavItem.settings),
            )
          : HomeScreen(
              onOpenSettings: () => _selectItem(RespondaNavItem.settings),
              tutorialReportButtonKey: _reportButtonKey,
              tutorialQuickIncidentKey: _quickIncidentKey,
              tutorialGpsCardKey: _gpsCardKey,
            ),
      const MyReportsScreen(),
      const EmergencyInfoScreen(),
      SettingsScreen(
        homeTutorialStore: widget.tutorialStore,
        onOutsidePantukanChanged: (_) => _selectItem(RespondaNavItem.home),
      ),
    ];
    return Stack(
      key: _tutorialSurfaceKey,
      children: [
        Scaffold(
          body: Material(
            color: AppColors.background,
            child: IndexedStack(index: _activeItem.index, children: screens),
          ),
          bottomNavigationBar: Material(
            color: AppColors.surface,
            child: SafeArea(
              top: false,
              child: RespondaBottomNavigation(
                activeItem: _activeItem,
                callButtonKey: _callButtonKey,
                onSelected: _selectItem,
              ),
            ),
          ),
        ),
        if (_tutorialController.visible &&
            _activeItem == RespondaNavItem.home &&
            !outsidePantukan)
          HomeTutorialOverlay(
            key: ValueKey(_tutorialController.step),
            step: _tutorialController.step,
            targetKey: _tutorialTargets[_tutorialController.step],
            coordinateSpaceKey: _tutorialSurfaceKey,
            onNext: () => _tutorialController.next(),
            onSkip: () => _tutorialController.complete(),
          ),
      ],
    );
  }

  List<GlobalKey> get _tutorialTargets => [
    _reportButtonKey,
    _quickIncidentKey,
    _gpsCardKey,
    _callButtonKey,
  ];

  void _tutorialChanged() {
    if (mounted) setState(() {});
  }

  void _selectItem(RespondaNavItem item) {
    if (item == _activeItem) {
      return;
    }

    setState(() => _activeItem = item);
  }
}
