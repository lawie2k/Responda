import 'package:flutter/material.dart';

import 'core/localization/app_language_controller.dart';
import 'core/localization/app_language_scope.dart';
import 'core/location/gps_preference_controller.dart';
import 'core/location/gps_preference_scope.dart';
import 'core/navigation/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/keyboard_dismiss_on_tap.dart';
import 'core/widgets/responda_bottom_navigation.dart';
import 'features/onboarding/presentation/screens/language_selection_screen.dart';
import 'features/splash/presentation/screens/splash_screen.dart';
import 'screens/online/main_shell.dart';

class RespondaApp extends StatefulWidget {
  const RespondaApp({
    this.languageController,
    this.gpsPreferenceController,
    super.key,
  });

  final AppLanguageController? languageController;
  final GpsPreferenceController? gpsPreferenceController;

  @override
  State<RespondaApp> createState() => _RespondaAppState();
}

class _RespondaAppState extends State<RespondaApp> {
  late final AppLanguageController _languageController;
  late final GpsPreferenceController _gpsPreferenceController;
  late final Future<void> _preferencesLoad;
  late final bool _ownsLanguageController;
  late final bool _ownsGpsPreferenceController;

  @override
  void initState() {
    super.initState();
    _ownsLanguageController = widget.languageController == null;
    _ownsGpsPreferenceController = widget.gpsPreferenceController == null;
    _languageController = widget.languageController ?? AppLanguageController();
    _gpsPreferenceController =
        widget.gpsPreferenceController ?? GpsPreferenceController();
    _preferencesLoad = Future.wait([
      _languageController.load(),
      _gpsPreferenceController.load(),
    ]);
  }

  @override
  void dispose() {
    if (_ownsLanguageController) {
      _languageController.dispose();
    }
    if (_ownsGpsPreferenceController) {
      _gpsPreferenceController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _languageController,
      builder: (context, _) => AppLanguageScope(
        controller: _languageController,
        child: GpsPreferenceScope(
          controller: _gpsPreferenceController,
          child: MaterialApp(
            title: 'RESPONDA',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            builder: (context, child) =>
                KeyboardDismissOnTap(child: child ?? const SizedBox.shrink()),
            home: FutureBuilder<void>(
              future: _preferencesLoad,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SplashScreen(autoNavigate: false);
                }

                return SplashScreen(
                  destination: _languageController.hasSelectedLanguage
                      ? const MainShell()
                      : const LanguageSelectionScreen(),
                );
              },
            ),
            routes: {
              AppRoutes.home: (_) => const MainShell(),
              AppRoutes.reports: (_) =>
                  const MainShell(initialItem: RespondaNavItem.reports),
              AppRoutes.emergencyInfo: (_) =>
                  const MainShell(initialItem: RespondaNavItem.information),
              AppRoutes.settings: (_) =>
                  const MainShell(initialItem: RespondaNavItem.settings),
            },
          ),
        ),
      ),
    );
  }
}
