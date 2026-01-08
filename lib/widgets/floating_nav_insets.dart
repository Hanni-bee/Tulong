import 'package:flutter/widgets.dart';

/// Exposes how much vertical space the floating bottom navigation occupies,
/// so child screens can position bottom UI (e.g., chat composer) above it
/// without hard-coded magic numbers.
class FloatingNavInsets extends InheritedWidget {
  final double reservedBottom;
  final double navHeight;
  final double bottomMargin;

  const FloatingNavInsets({
    super.key,
    required this.reservedBottom,
    this.navHeight = 0.0,
    this.bottomMargin = 0.0,
    required super.child,
  });

  static FloatingNavInsets? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<FloatingNavInsets>();
  }

  @override
  bool updateShouldNotify(FloatingNavInsets oldWidget) {
    return (oldWidget.reservedBottom - reservedBottom).abs() > 0.5 ||
        (oldWidget.navHeight - navHeight).abs() > 0.5 ||
        (oldWidget.bottomMargin - bottomMargin).abs() > 0.5;
  }
}


