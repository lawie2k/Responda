import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/connectivity/connectivity_controller.dart';
import 'core/connectivity/connectivity_gate.dart';
import 'core/connectivity/connectivity_scope.dart';
import 'core/localization/app_language_controller.dart';
import 'core/localization/app_language_scope.dart';
import 'core/location/gps_preference_controller.dart';
import 'core/location/gps_preference_scope.dart';
import 'core/navigation/app_routes.dart';
import 'core/settings/app_settings_controller.dart';
import 'core/settings/app_settings_scope.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/keyboard_dismiss_on_tap.dart';
import 'core/widgets/responda_bottom_navigation.dart';
import 'features/onboarding/presentation/screens/language_selection_screen.dart';
import 'features/onboarding/data/account_controller.dart';
import 'features/onboarding/presentation/account_scope.dart';
import 'features/onboarding/presentation/screens/identity_verification_screen.dart';
import 'features/splash/presentation/screens/splash_screen.dart';
import 'features/testing/data/testing_mode_controller.dart';
import 'features/testing/presentation/testing_mode_scope.dart';

class RespondaApp extends StatefulWidget {
  const RespondaApp({
    this.languageController,
    this.gpsPreferenceController,
    this.connectivityController,
    this.accountController,
    this.settingsController,
    this.testingModeController,
    super.key,
  });

  final AppLanguageController? languageController;
  final GpsPreferenceController? gpsPreferenceController;
  final ConnectivityController? connectivityController;
  final AccountController? accountController;
  final AppSettingsController? settingsController;
  final TestingModeController? testingModeController;

  @override
  State<RespondaApp> createState() => _RespondaAppState();
}

class _RespondaAppState extends State<RespondaApp> with WidgetsBindingObserver {
  late final AppLanguageController _languageController;
  late final GpsPreferenceController _gpsPreferenceController;
  late final ConnectivityController _connectivityController;
  late final AccountController _accountController;
  late final AppSettingsController _settingsController;
  late final TestingModeController _testingModeController;
  late final Future<void> _preferencesLoad;
  late final bool _ownsLanguageController;
  late final bool _ownsGpsPreferenceController;
  late final bool _ownsConnectivityController;
  late final bool _ownsAccountController;
  late final bool _ownsSettingsController;
  late final bool _ownsTestingModeController;

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
    _ownsSettingsController = widget.settingsController == null;
    _settingsController = widget.settingsController ?? AppSettingsController();
    _ownsTestingModeController = widget.testingModeController == null;
    _testingModeController =
        widget.testingModeController ?? TestingModeController();
    _preferencesLoad = Future.wait([
      _languageController.load(),
      _gpsPreferenceController.load(),
      _connectivityController.initialize(),
      _accountController.load(),
      _settingsController.load(),
      _testingModeController.load(),
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
    if (_ownsSettingsController) {
      _settingsController.dispose();
    }
    if (_ownsTestingModeController) {
      _testingModeController.dispose();
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
          child: TestingModeScope(
            controller: _testingModeController,
            child: AppSettingsScope(
              controller: _settingsController,
              child: AccountScope(
                controller: _accountController,
                child: ConnectivityScope(
                  controller: _connectivityController,
                  child: MaterialApp(
                    title: 'RESPONDA',
                    locale: _languageController.language.frameworkLocale,
                    localizationsDelegates:
                        GlobalMaterialLocalizations.delegates,
                    supportedLocales: const [Locale('en'), Locale('fil')],
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

                        final destination =
                            !_languageController.hasSelectedLanguage
                            ? const LanguageSelectionScreen()
                            : !_accountController.hasAccount
                            ? const IdentityVerificationScreen()
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
        ),
      ),
    );
  }
}
