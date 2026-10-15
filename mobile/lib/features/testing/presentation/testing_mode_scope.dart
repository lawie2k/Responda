import 'package:flutter/widgets.dart';

import '../data/testing_mode_controller.dart';

class TestingModeScope extends InheritedNotifier<TestingModeController> {
  const TestingModeScope({
    required TestingModeController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static TestingModeController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'No TestingModeScope found in this context.');
    return controller!;
  }

  static TestingModeController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TestingModeScope>()
        ?.notifier;
  }
}
