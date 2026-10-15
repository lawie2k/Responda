import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:responda/features/testing/data/testing_mode_controller.dart';
import 'package:responda/features/testing/presentation/testing_mode_scope.dart';
import 'package:responda/screens/online/main_shell.dart';

void main() {
  testWidgets('testing mode blocks reports and can return to normal', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final store = _MemoryTestingModeStore(true);
    final controller = TestingModeController(store: store);
    await controller.load();

    await tester.pumpWidget(
      TestingModeScope(
        controller: controller,
        child: const MaterialApp(home: MainShell()),
      ),
    );
    await tester.pump();

    expect(find.text('Outside Pantukan'), findsOneWidget);
    expect(find.text('REPORT AN EMERGENCY'), findsNothing);
    expect(find.textContaining('dial 911'), findsNothing);

    await tester.tap(
      find.byKey(const Key('outside_pantukan_open_settings_button')),
    );
    await tester.pump();

    final toggle = find.byKey(const Key('toggle_outside_pantukan_tile'));
    await tester.ensureVisible(toggle);
    expect(find.text('Return to normal mode'), findsOneWidget);
    await tester.tap(toggle);
    await tester.pump();
    await tester.pump();

    expect(controller.outsidePantukan, isFalse);
    expect(store.outsidePantukan, isFalse);
    expect(find.text('Need Emergency\nAssistance?'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class _MemoryTestingModeStore implements TestingModeStore {
  _MemoryTestingModeStore(this.outsidePantukan);

  bool? outsidePantukan;

  @override
  Future<bool?> readOutsidePantukan() async => outsidePantukan;

  @override
  Future<void> writeOutsidePantukan(bool value) async {
    outsidePantukan = value;
  }
}
