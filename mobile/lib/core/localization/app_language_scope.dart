import 'package:flutter/widgets.dart';

import 'app_language_controller.dart';

class AppLanguageScope extends InheritedNotifier<AppLanguageController> {
  const AppLanguageScope({
    required AppLanguageController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static AppLanguageController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'No AppLanguageScope found in this context.');
    return controller!;
  }

  static AppLanguageController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppLanguageScope>()
        ?.notifier;
  }
}
