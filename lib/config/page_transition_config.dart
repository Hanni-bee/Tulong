import 'package:flutter/material.dart';

/// Global configuration for uniform page transitions
/// Updated to match prototype: slide up + fade, 300ms, easeOut
class PageTransitionConfig {
  /// Default transition duration for all pages (from prototype: 300ms)
  static const Duration defaultDuration = Duration(milliseconds: 300);

  /// Exit transition duration (from prototype: 200ms)
  static const Duration exitDuration = Duration(milliseconds: 200);

  /// Default transition curve (from prototype: easeOut)
  static const Curve defaultCurve = Curves.easeOut;

  /// Exit transition curve (from prototype: easeIn)
  static const Curve exitCurve = Curves.easeIn;

  /// Transition type for the entire app
  static PageTransitionsBuilder get defaultTransition => 
      const CustomPageTransitionsBuilder();
}

/// Custom page transitions builder for uniform animations
class CustomPageTransitionsBuilder extends PageTransitionsBuilder {
  const CustomPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _SharedAxisTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

/// Shared axis transition (Material Design 3)
class _SharedAxisTransition extends StatelessWidget {
  const _SharedAxisTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Entry animation: slide up (y: 20px) + fade
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.0, 0.02), // 20px = ~0.02 in normalized coordinates
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: animation,
          curve: PageTransitionConfig.defaultCurve, // easeOut
        ),
      ),
      child: FadeTransition(
        opacity: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: PageTransitionConfig.defaultCurve, // easeOut
          ),
        ),
        // Exit animation: fade out only (simpler exit)
        child: FadeTransition(
          opacity: Tween<double>(
            begin: 1.0,
            end: 0.0,
          ).animate(
            CurvedAnimation(
              parent: secondaryAnimation,
              curve: PageTransitionConfig.exitCurve, // easeIn
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Extension for easy navigation with uniform transitions
extension UniformNavigationExtension on BuildContext {
  /// Push with uniform transition
  Future<T?> pushPage<T>(Widget page) {
    return Navigator.of(this).push<T>(
      PageRouteBuilder<T>(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: PageTransitionConfig.defaultDuration, // 300ms
        reverseTransitionDuration: PageTransitionConfig.exitDuration, // 200ms
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return _SharedAxisTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            child: child,
          );
        },
      ),
    );
  }

  /// Replace with uniform transition
  Future<T?> replacePage<T, TO>(Widget page) {
    return Navigator.of(this).pushReplacement<T, TO>(
      PageRouteBuilder<T>(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: PageTransitionConfig.defaultDuration, // 300ms
        reverseTransitionDuration: PageTransitionConfig.exitDuration, // 200ms
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return _SharedAxisTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            child: child,
          );
        },
      ),
    );
  }

  /// Push and remove until with uniform transition
  Future<T?> pushAndRemoveUntil<T>(Widget page, RoutePredicate predicate) {
    return Navigator.of(this).pushAndRemoveUntil<T>(
      PageRouteBuilder<T>(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: PageTransitionConfig.defaultDuration, // 300ms
        reverseTransitionDuration: PageTransitionConfig.exitDuration, // 200ms
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return _SharedAxisTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            child: child,
          );
        },
      ),
      predicate,
    );
  }
}

/// Custom route with uniform transition for named routes
class UniformPageRoute<T> extends PageRoute<T> {
  UniformPageRoute({
    required this.builder,
    RouteSettings? settings,
  }) : super(settings: settings);

  final WidgetBuilder builder;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => PageTransitionConfig.defaultDuration;

  @override
  Duration get reverseTransitionDuration => PageTransitionConfig.defaultDuration;

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _SharedAxisTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

