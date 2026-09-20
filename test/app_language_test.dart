import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responda/core/localization/app_language.dart';
import 'package:responda/core/localization/app_language_controller.dart';
import 'package:responda/core/localization/app_language_scope.dart';
import 'package:responda/core/localization/app_strings.dart';
import 'package:responda/core/location/gps_preference_controller.dart';
import 'package:responda/core/location/gps_preference_scope.dart';
import 'package:responda/core/widgets/responda_bottom_navigation.dart';
import 'package:responda/features/onboarding/data/account_controller.dart';
import 'package:responda/features/onboarding/domain/account_profile.dart';
import 'package:responda/features/onboarding/presentation/account_scope.dart';
import 'package:responda/features/onboarding/presentation/screens/identity_verification_screen.dart';
import 'package:responda/features/onboarding/presentation/screens/language_selection_screen.dart';
import 'package:responda/screens/online/home_screen.dart';
import 'package:responda/screens/online/settings_screen.dart';

void main() {
  test('loads and saves the selected language', () async {
    final store = _MemoryLanguageStore(AppLanguage.filipino.code);
    final controller = AppLanguageController(store: store);

    await controller.load();
    expect(controller.hasSelectedLanguage, isTrue);
    expect(controller.language, AppLanguage.filipino);

    await controller.selectLanguage(AppLanguage.cebuano);
    expect(store.code, AppLanguage.cebuano.code);

    final restartedController = AppLanguageController(store: store);
    await restartedController.load();
    expect(restartedController.language, AppLanguage.cebuano);

    await restartedController.resetSelection();
    expect(restartedController.hasSelectedLanguage, isFalse);
    expect(store.code, isNull);
  });

  test('translates fixed text and dynamic templates', () {
    const filipino = AppStrings(AppLanguage.filipino);
    const cebuano = AppStrings(AppLanguage.cebuano);

    expect(filipino.text('Report Status'), 'Status ng Ulat');
    expect(cebuano.text('Report Status'), 'Status sa Report');
    expect(
      filipino.text('{stage} OF 7 STAGES', values: {'stage': 2}),
      'YUGTO 2 SA 7',
    );
    expect(
      cebuano.text(
        'Enter the 6-digit code sent to {phone}.',
        values: {'phone': '+639123456789'},
      ),
      'Isulod ang 6-digit nga code nga gipadala sa +639123456789.',
    );
  });

  testWidgets('first-launch choice is persisted', (tester) async {
    final store = _MemoryLanguageStore();
    final controller = AppLanguageController(store: store);
    await controller.load();

    await tester.pumpWidget(
      AppLanguageScope(
        controller: controller,
        child: MaterialApp(home: const LanguageSelectionScreen()),
      ),
    );

    await tester.tap(find.text('Filipino/Tagalog'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(store.code, AppLanguage.filipino.code);
    expect(controller.language, AppLanguage.filipino);
    expect(find.byType(IdentityVerificationScreen), findsOneWidget);
  });

  testWidgets('settings changes and persists the same language', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final store = _MemoryLanguageStore(AppLanguage.english.code);
    final controller = AppLanguageController(store: store);
    await controller.load();

    await tester.pumpWidget(
      AppLanguageScope(
        controller: controller,
        child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
      ),
    );

    expect(find.text('English'), findsOneWidget);
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bisaya/Cebuano'));
    await tester.pumpAndSettle();

    expect(find.text('Bisaya/Cebuano'), findsOneWidget);
    expect(find.text('Pinulongan nga gamiton sa tibuok app'), findsOneWidget);
    expect(find.text('Language used throughout the app'), findsNothing);
    expect(controller.language, AppLanguage.cebuano);
    expect(store.code, AppLanguage.cebuano.code);
  });

  testWidgets('language picker reopens after changing to Tagalog', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final store = _MemoryLanguageStore(AppLanguage.english.code);
    final controller = AppLanguageController(store: store);
    await controller.load();

    await tester.pumpWidget(
      AnimatedBuilder(
        animation: controller,
        builder: (context, _) => AppLanguageScope(
          controller: controller,
          child: MaterialApp(
            locale: controller.language.frameworkLocale,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            supportedLocales: const [Locale('en'), Locale('fil')],
            home: const Scaffold(body: SettingsScreen()),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('language_settings_tile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filipino/Tagalog'));
    await tester.pumpAndSettle();

    expect(controller.language, AppLanguage.filipino);
    expect(find.text('Wika'), findsOneWidget);

    await tester.tap(find.byKey(const Key('language_settings_tile')));
    await tester.pumpAndSettle();
    expect(find.text('Pumili ng wika'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(controller.language, AppLanguage.english);
    expect(find.text('Language'), findsOneWidget);
  });

  testWidgets('localized bottom navigation keeps 12px wrapping labels', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final controller = AppLanguageController(
      store: _MemoryLanguageStore(AppLanguage.filipino.code),
    );
    await controller.load();
    await tester.pumpWidget(
      AppLanguageScope(
        controller: controller,
        child: const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: RespondaBottomNavigation(
              activeItem: RespondaNavItem.information,
            ),
          ),
        ),
      ),
    );

    final information = tester.widget<Text>(
      find.text('Impormasyon\nEmerhensiya'),
    );
    expect(information.style?.fontSize, 12);
    expect(information.maxLines, 2);
    expect(information.textAlign, TextAlign.center);
  });

  testWidgets('Filipino selection translates the home screen', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final controller = AppLanguageController(
      store: _MemoryLanguageStore(AppLanguage.filipino.code),
    );
    await controller.load();

    await tester.pumpWidget(
      AppLanguageScope(
        controller: controller,
        child: const MaterialApp(home: Scaffold(body: HomeScreen())),
      ),
    );
    await tester.pump();

    expect(find.text('Mabilis na uri ng insidente'), findsOneWidget);
    expect(find.text('Kailangan ng Tulong\nsa Emerhensiya?'), findsOneWidget);
    expect(find.text('Quick incident type'), findsNothing);
  });

  testWidgets('testing reset clears onboarding choices and starts over', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final languageStore = _MemoryLanguageStore(AppLanguage.filipino.code);
    final languageController = AppLanguageController(store: languageStore);
    final gpsStore = _MemoryGpsStore(false);
    final gpsController = GpsPreferenceController(store: gpsStore);
    final accountStore = _MemoryAccountStore();
    final accountController = AccountController(store: accountStore);
    await Future.wait([
      languageController.load(),
      gpsController.load(),
      accountController.load(),
    ]);
    await accountController.submitIdentity(phoneNumber: '+639171234567');

    await tester.pumpWidget(
      AppLanguageScope(
        controller: languageController,
        child: GpsPreferenceScope(
          controller: gpsController,
          child: AccountScope(
            controller: accountController,
            child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final resetTile = find.byKey(const Key('reset_test_onboarding_tile'));
    await tester.ensureVisible(resetTile);
    await tester.tap(resetTile);
    await tester.pumpAndSettle();
    expect(find.text('I-reset ang test data?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm_test_reset_button')));
    await tester.pumpAndSettle();

    expect(find.byType(LanguageSelectionScreen), findsOneWidget);
    expect(accountController.hasAccount, isFalse);
    expect(languageController.hasSelectedLanguage, isFalse);
    expect(languageStore.code, isNull);
    expect(gpsController.allowGps, isTrue);
    expect(gpsStore.allowGps, isNull);
  });
}

class _MemoryLanguageStore implements AppLanguageStore {
  _MemoryLanguageStore([this.code]);

  String? code;

  @override
  Future<void> clearLanguageCode() async {
    code = null;
  }

  @override
  Future<String?> readLanguageCode() async => code;

  @override
  Future<void> writeLanguageCode(String code) async {
    this.code = code;
  }
}

class _MemoryGpsStore implements GpsPreferenceStore {
  _MemoryGpsStore(this.allowGps);

  bool? allowGps;

  @override
  Future<void> clearAllowGps() async {
    allowGps = null;
  }

  @override
  Future<bool?> readAllowGps() async => allowGps;

  @override
  Future<void> writeAllowGps(bool value) async {
    allowGps = value;
  }
}

class _MemoryAccountStore implements AccountStore {
  AccountProfile? profile;

  @override
  Future<void> clear() async {
    profile = null;
  }

  @override
  Future<AccountProfile?> read() async => profile;

  @override
  Future<void> write(AccountProfile profile) async {
    this.profile = profile;
  }
}
