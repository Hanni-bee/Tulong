import 'package:flutter/material.dart';

/// Global configuration for uniform page transitions
/// Enhanced with scale + slide + fade for smoother, more polished transitions
class PageTransitionConfig {
  /// Default transition duration for all pages (enhanced: 400ms)
  static const Duration defaultDuration = Duration(milliseconds: 400);

  /// Exit transition duration (enhanced: 280ms)
  static const Duration exitDuration = Duration(milliseconds: 280);

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
    // Enhanced entry animation: slide up + fade + scale (for incoming page)
    final entrySlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.06), // Slide up from 6% below
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: PageTransitionConfig.defaultCurve, // easeOutCubic
      ),
    );

    final entryFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: PageTransitionConfig.defaultCurve, // easeOutCubic
      ),
    );

    final entryScaleAnimation = Tween<double>(
      begin: 0.96, // Start slightly scaled down
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: PageTransitionConfig.defaultCurve, // easeOutCubic
      ),
    );

    // Enhanced exit animation: fade out + slide up + scale down (for outgoing page when going back)
    final exitFadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: PageTransitionConfig.exitCurve, // easeInCubic
      ),
    );

    final exitSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.0, -0.04), // Slide up on exit
    ).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: PageTransitionConfig.exitCurve, // easeInCubic
      ),
    );

    final exitScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.96, // Slight scale down on exit
    ).animate(
      CurvedAnimation(
        parent: secondaryAnimation,
        curve: PageTransitionConfig.exitCurve, // easeInCubic
      ),
    );

    // Combine entry animations for incoming page
    return SlideTransition(
      position: entrySlideAnimation,
      child: FadeTransition(
        opacity: entryFadeAnimation,
        child: ScaleTransition(
          scale: entryScaleAnimation,
          // Apply exit animations only when going back (secondaryAnimation is active)
          child: FadeTransition(
            opacity: exitFadeAnimation,
            child: SlideTransition(
              position: exitSlideAnimation,
              child: ScaleTransition(
                scale: exitScaleAnimation,
                child: child,
              ),
            ),
          ),
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
        transitionDuration: PageTransitionConfig.defaultDuration, // 400ms
        reverseTransitionDuration: PageTransitionConfig.exitDuration, // 280ms
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
        transitionDuration: PageTransitionConfig.defaultDuration, // 400ms
        reverseTransitionDuration: PageTransitionConfig.exitDuration, // 280ms
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
        transitionDuration: PageTransitionConfig.defaultDuration, // 400ms
        reverseTransitionDuration: PageTransitionConfig.exitDuration, // 280ms
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

