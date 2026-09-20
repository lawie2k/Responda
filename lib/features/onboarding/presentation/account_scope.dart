import 'package:flutter/widgets.dart';

import '../data/account_controller.dart';

class AccountScope extends InheritedNotifier<AccountController> {
  const AccountScope({
    required AccountController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static AccountController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'No AccountScope found in this context.');
    return controller!;
  }

  static AccountController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AccountScope>()?.notifier;
  }
}
