import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responda/core/localization/app_language.dart';
import 'package:responda/core/localization/app_language_controller.dart';
import 'package:responda/core/localization/app_language_scope.dart';
import 'package:responda/core/navigation/app_routes.dart';
import 'package:responda/features/onboarding/presentation/screens/language_selection_screen.dart';
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
  });

  testWidgets('first-launch choice is persisted', (tester) async {
    final store = _MemoryLanguageStore();
    final controller = AppLanguageController(store: store);
    await controller.load();

    await tester.pumpWidget(
      AppLanguageScope(
        controller: controller,
        child: MaterialApp(
          home: const LanguageSelectionScreen(),
          routes: {AppRoutes.home: (_) => const _HomeMarker()},
        ),
      ),
    );

    await tester.tap(find.text('Filipino/Tagalog'));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(store.code, AppLanguage.filipino.code);
    expect(controller.language, AppLanguage.filipino);
    expect(find.byType(_HomeMarker), findsOneWidget);
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
    expect(controller.language, AppLanguage.cebuano);
    expect(store.code, AppLanguage.cebuano.code);
  });
}

class _MemoryLanguageStore implements AppLanguageStore {
  _MemoryLanguageStore([this.code]);

  String? code;

  @override
  Future<String?> readLanguageCode() async => code;

  @override
  Future<void> writeLanguageCode(String code) async {
    this.code = code;
  }
}

class _HomeMarker extends StatelessWidget {
  const _HomeMarker();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Text('Home marker'));
  }
}
