import 'package:flutter/widgets.dart';

import 'gps_preference_controller.dart';

class GpsPreferenceScope extends InheritedNotifier<GpsPreferenceController> {
  const GpsPreferenceScope({
    required GpsPreferenceController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static GpsPreferenceController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'No GpsPreferenceScope found in this context.');
    return controller!;
  }

  static GpsPreferenceController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<GpsPreferenceScope>()
        ?.notifier;
  }
}
