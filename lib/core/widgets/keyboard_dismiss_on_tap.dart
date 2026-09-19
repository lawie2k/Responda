import 'package:flutter/material.dart';

/// Dismisses the software keyboard when the user taps outside the focused
/// input. Place this above the app navigator so it also covers future screens.
class KeyboardDismissOnTap extends StatelessWidget {
  const KeyboardDismissOnTap({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _dismissIfOutsideFocusedInput,
      child: child,
    );
  }

  void _dismissIfOutsideFocusedInput(PointerDownEvent event) {
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null || !focus.hasFocus) {
      return;
    }

    final renderObject = focus.context?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final inputBounds =
          renderObject.localToGlobal(Offset.zero) & renderObject.size;
      if (inputBounds.contains(event.position)) {
        return;
      }
    }

    focus.unfocus();
  }
}
