import 'package:flutter/material.dart';
import 'package:native_liquid_glass/native_liquid_glass.dart';

/// Uses Flutter navigation controls while tutorial spotlights cover the screen.
class RespondaGlassScope extends InheritedWidget {
  const RespondaGlassScope({
    required this.disabled,
    required super.child,
    super.key,
  });

  final bool disabled;

  @override
  bool updateShouldNotify(RespondaGlassScope oldWidget) =>
      disabled != oldWidget.disabled;
}

abstract final class RespondaGlass {
  static bool get supported => NativeLiquidGlassUtils.supportsLiquidGlass;

  static bool enabled(BuildContext context) =>
      supported &&
      !(context
              .dependOnInheritedWidgetOfExactType<RespondaGlassScope>()
              ?.disabled ??
          false);

  static Color background(BuildContext context, Color color) =>
      enabled(context) ? Colors.transparent : color;
}

/// Native back control on current iOS; original button elsewhere.
class RespondaIosBackButton extends StatelessWidget {
  const RespondaIosBackButton({
    required this.onPressed,
    required this.fallback,
    super.key,
  });

  final VoidCallback onPressed;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    if (!RespondaGlass.enabled(context)) return fallback;
    return Semantics(
      button: true,
      label: MaterialLocalizations.of(context).backButtonTooltip,
      onTap: onPressed,
      excludeSemantics: true,
      child: LiquidGlassButton.icon(
        icon: const NativeLiquidGlassIcon.sfSymbol('chevron.left'),
        onPressed: onPressed,
        size: 44,
        iconSize: 18,
        style: LiquidGlassButtonStyle.glass,
        iconColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
