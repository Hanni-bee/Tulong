import 'package:flutter/material.dart';

/// Global configuration for uniform page transitions
/// Optimized for performance: slide + fade only (no scale for better performance)
class PageTransitionConfig {
  /// Default transition duration for all pages (optimized: 300ms for snappier feel)
  static const Duration defaultDuration = Duration(milliseconds: 300);

  /// Exit transition duration (optimized: 250ms)
  static const Duration exitDuration = Duration(milliseconds: 250);

  /// Default transition curve (enhanced: easeOutCubic for smoother motion)
  static const Curve defaultCurve = Curves.easeOutCubic;

  /// Exit transition curve (enhanced: easeInCubic for faster exit)
  static const Curve exitCurve = Curves.easeInCubic;

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
    // Performance optimization: Use only Slide + Fade (no Scale)
    // Scale transitions are expensive as they trigger layout recalculations
    // Slide and Fade are GPU-accelerated and much smoother
    
    // Entry transition: slide from right + fade in
    // This is applied to the incoming page
    return SlideTransition(
      position: animation.drive(
        Tween<Offset>(
          begin: const Offset(0.3, 0.0), // Slide from right (30% of screen)
          end: Offset.zero,
        ).chain(CurveTween(curve: PageTransitionConfig.defaultCurve)),
      ),
      child: FadeTransition(
        opacity: animation.drive(
          CurveTween(curve: PageTransitionConfig.defaultCurve),
        ),
        child: RepaintBoundary(child: child),
      ),
    );
    
    // Note: Flutter automatically handles the exit transition via secondaryAnimation
    // The outgoing page will use the same transition builder with secondaryAnimation
    // We don't need to manually handle it here - Flutter's PageRoute handles stacking
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
        reverseTransitionDuration: PageTransitionConfig.exitDuration, // 250ms
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
        reverseTransitionDuration: PageTransitionConfig.exitDuration, // 250ms
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
        reverseTransitionDuration: PageTransitionConfig.exitDuration, // 250ms
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
    super.settings,
  });

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

