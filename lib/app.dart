import 'package:flutter/material.dart';

import 'core/connectivity/connectivity_controller.dart';
import 'core/connectivity/connectivity_gate.dart';
import 'core/connectivity/connectivity_scope.dart';
import 'core/localization/app_language_controller.dart';
import 'core/localization/app_language_scope.dart';
import 'core/location/gps_preference_controller.dart';
import 'core/location/gps_preference_scope.dart';
import 'core/navigation/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/keyboard_dismiss_on_tap.dart';
import 'core/widgets/responda_bottom_navigation.dart';
import 'features/onboarding/presentation/screens/language_selection_screen.dart';
import 'features/identity/data/account_controller.dart';
import 'features/identity/presentation/account_scope.dart';
import 'features/identity/presentation/screens/identity_onboarding_screen.dart';
import 'features/splash/presentation/screens/splash_screen.dart';

class RespondaApp extends StatefulWidget {
  const RespondaApp({
    this.languageController,
    this.gpsPreferenceController,
    this.connectivityController,
    this.accountController,
    super.key,
  });

  final AppLanguageController? languageController;
  final GpsPreferenceController? gpsPreferenceController;
  final ConnectivityController? connectivityController;
  final AccountController? accountController;

  @override
  State<RespondaApp> createState() => _RespondaAppState();
}

class _RespondaAppState extends State<RespondaApp> with WidgetsBindingObserver {
  late final AppLanguageController _languageController;
  late final GpsPreferenceController _gpsPreferenceController;
  late final ConnectivityController _connectivityController;
  late final AccountController _accountController;
  late final Future<void> _preferencesLoad;
  late final bool _ownsLanguageController;
  late final bool _ownsGpsPreferenceController;
  late final bool _ownsConnectivityController;
  late final bool _ownsAccountController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsLanguageController = widget.languageController == null;
    _ownsGpsPreferenceController = widget.gpsPreferenceController == null;
    _languageController = widget.languageController ?? AppLanguageController();
    _gpsPreferenceController =
        widget.gpsPreferenceController ?? GpsPreferenceController();
    _ownsConnectivityController = widget.connectivityController == null;
    _connectivityController =
        widget.connectivityController ?? ConnectivityController();
    _ownsAccountController = widget.accountController == null;
    _accountController = widget.accountController ?? AccountController();
    _preferencesLoad = Future.wait([
      _languageController.load(),
      _gpsPreferenceController.load(),
      _connectivityController.initialize(),
      _accountController.load(),
    ]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _connectivityController.refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsLanguageController) {
      _languageController.dispose();
    }
    if (_ownsGpsPreferenceController) {
      _gpsPreferenceController.dispose();
    }
    if (_ownsConnectivityController) {
      _connectivityController.dispose();
    }
    if (_ownsAccountController) {
      _accountController.dispose();
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
          child: AccountScope(
            controller: _accountController,
            child: ConnectivityScope(
              controller: _connectivityController,
              child: MaterialApp(
                title: 'RESPONDA',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light,
                builder: (context, child) => KeyboardDismissOnTap(
                  child: child ?? const SizedBox.shrink(),
                ),
                home: FutureBuilder<void>(
                  future: _preferencesLoad,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const SplashScreen(autoNavigate: false);
                    }

                    final destination = !_languageController.hasSelectedLanguage
                        ? const LanguageSelectionScreen()
                        : !_accountController.hasAccount
                        ? const IdentityOnboardingScreen()
                        : const ConnectivityGate();
                    return SplashScreen(destination: destination);
                  },
                ),
                routes: {
                  AppRoutes.home: (_) => const ConnectivityGate(),
                  AppRoutes.reports: (_) => const ConnectivityGate(
                    initialItem: RespondaNavItem.reports,
                  ),
                  AppRoutes.emergencyInfo: (_) => const ConnectivityGate(
                    initialItem: RespondaNavItem.information,
                  ),
                  AppRoutes.settings: (_) => const ConnectivityGate(
                    initialItem: RespondaNavItem.settings,
                  ),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
