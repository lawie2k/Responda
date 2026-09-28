import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:responda/features/onboarding/data/account_controller.dart';
import 'package:responda/features/onboarding/domain/account_profile.dart';
import 'package:responda/features/onboarding/presentation/account_scope.dart';
import 'package:responda/features/tutorial/data/home_tutorial_store.dart';
import 'package:responda/screens/online/main_shell.dart';

void main() {
  Future<AccountController> accountController() async {
    final controller = AccountController(store: _MemoryAccountStore());
    await controller.load();
    await controller.submitIdentity(phoneNumber: '+639171234567');
    return controller;
  }

  Future<void> pumpTutorial(
    WidgetTester tester,
    HomeTutorialProgressStore tutorialStore,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final account = await accountController();
    await tester.pumpWidget(
      AccountScope(
        controller: account,
        child: MaterialApp(home: MainShell(tutorialStore: tutorialStore)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('newly verified account receives the one-time Home tutorial', (
    tester,
  ) async {
    final store = _MemoryTutorialStore(false);
    await pumpTutorial(tester, store);

    expect(find.text('Report an emergency'), findsOneWidget);
    expect(find.byKey(const Key('home_tutorial_sprite')), findsOneWidget);

    await tester.tap(find.byKey(const Key('next_home_tutorial')));
    await tester.pump();
    expect(find.text('Use a quick incident type'), findsOneWidget);

    await tester.tap(find.byKey(const Key('next_home_tutorial')));
    await tester.pump();
    expect(find.text('Check your GPS location'), findsOneWidget);
    final gpsSprite = tester.widget<Image>(
      find.byKey(const Key('home_tutorial_sprite')),
    );
    expect(
      (gpsSprite.image as AssetImage).assetName,
      'assets/images/tutorial-point-up.gif',
    );

    await tester.tap(find.byKey(const Key('next_home_tutorial')));
    await tester.pump();
    expect(find.text('Call MDRRMO'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);
    final finalSprite = tester.widget<Image>(
      find.byKey(const Key('home_tutorial_sprite')),
    );
    expect(finalSprite.height, 145);

    await tester.tap(find.byKey(const Key('next_home_tutorial')));
    await tester.pump();
    expect(find.byKey(const Key('home_tutorial_sprite')), findsNothing);
    expect(store.completed, isTrue);
  });

  testWidgets('completed Home tutorial does not appear again', (tester) async {
    await pumpTutorial(tester, _MemoryTutorialStore(true));

    expect(find.byKey(const Key('home_tutorial_sprite')), findsNothing);
    expect(find.text('REPORT AN EMERGENCY'), findsOneWidget);
  });
}

class _MemoryTutorialStore implements HomeTutorialProgressStore {
  _MemoryTutorialStore(this.completed);

  bool completed;

  @override
  Future<bool> readCompleted() async => completed;

  @override
  Future<void> reset() async => completed = false;

  @override
  Future<void> writeCompleted(bool value) async => completed = value;
}

class _MemoryAccountStore implements AccountStore {
  @override
  Future<void> clear() async {}

  @override
  Future<AccountProfile?> read() async => null;

  @override
  Future<void> write(AccountProfile profile) async {}
}
