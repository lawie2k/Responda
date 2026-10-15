import 'package:flutter/widgets.dart';

import 'connectivity_controller.dart';

class ConnectivityScope extends InheritedNotifier<ConnectivityController> {
  const ConnectivityScope({
    required ConnectivityController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static ConnectivityController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ConnectivityScope>();
    assert(
      scope != null,
      'ConnectivityScope was not found in the widget tree.',
    );
    return scope!.notifier!;
  }
}
