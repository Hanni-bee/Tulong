import 'package:flutter/material.dart';

/// Modern page transition animations
class ModernPageTransitions {
  /// Slide transition from right
  static Route slideFromRight(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  /// Slide transition from bottom
  static Route slideFromBottom(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  /// Fade transition
  static Route fade(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  /// Scale transition
  static Route scale(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeInOutCubic;

        var scaleTween = Tween<double>(begin: 0.8, end: 1.0).chain(
          CurveTween(curve: curve),
        );

        var fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(
          CurveTween(curve: curve),
        );

        return ScaleTransition(
          scale: animation.drive(scaleTween),
          child: FadeTransition(
            opacity: animation.drive(fadeTween),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  /// Rotation and fade transition
  static Route rotation(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeInOutCubic;

        var rotationTween = Tween<double>(begin: 0.0, end: 1.0).chain(
          CurveTween(curve: curve),
        );

        var scaleTween = Tween<double>(begin: 0.8, end: 1.0).chain(
          CurveTween(curve: curve),
        );

        return RotationTransition(
          turns: animation.drive(rotationTween),
          child: ScaleTransition(
            scale: animation.drive(scaleTween),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 600),
    );
  }

  /// Shared axis transition
  static Route sharedAxis(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeInOutCubic;

        var slideInTween = Tween<Offset>(
          begin: const Offset(0.3, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: curve));

        var fadeInTween = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: curve));

        var slideOutTween = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(-0.3, 0.0),
        ).chain(CurveTween(curve: curve));

        var fadeOutTween = Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(slideInTween),
          child: FadeTransition(
            opacity: animation.drive(fadeInTween),
            child: SlideTransition(
              position: secondaryAnimation.drive(slideOutTween),
              child: FadeTransition(
                opacity: secondaryAnimation.drive(fadeOutTween),
                child: child,
              ),
            ),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  /// Custom neumorphic transition (scale + fade)
  static Route neumorphic(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeInOutCubic;

        var scaleTween = Tween<double>(begin: 0.9, end: 1.0).chain(
          CurveTween(curve: curve),
        );

        var fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(
          CurveTween(curve: curve),
        );

        return ScaleTransition(
          scale: animation.drive(scaleTween),
          child: FadeTransition(
            opacity: animation.drive(fadeTween),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }

  /// Slide and fade (combined)
  static Route slideFade(Widget page, {AxisDirection direction = AxisDirection.right}) {
    Offset begin;
    switch (direction) {
      case AxisDirection.up:
        begin = const Offset(0.0, 1.0);
        break;
      case AxisDirection.down:
        begin = const Offset(0.0, -1.0);
        break;
      case AxisDirection.left:
        begin = const Offset(-1.0, 0.0);
        break;
      case AxisDirection.right:
        begin = const Offset(1.0, 0.0);
        break;
    }

    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const curve = Curves.easeInOutCubic;

        var slideTween = Tween(begin: begin, end: Offset.zero).chain(
          CurveTween(curve: curve),
        );

        var fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(
          CurveTween(curve: curve),
        );

        return SlideTransition(
          position: animation.drive(slideTween),
          child: FadeTransition(
            opacity: animation.drive(fadeTween),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }
}

/// Extension for easier navigation with custom transitions
extension ModernNavigationExtension on BuildContext {
  /// Navigate with slide from right transition
  Future<T?> pushWithSlide<T>(Widget page) {
    return Navigator.of(this).push<T>(
      ModernPageTransitions.slideFromRight(page),
    );
  }

  /// Navigate with fade transition
  Future<T?> pushWithFade<T>(Widget page) {
    return Navigator.of(this).push<T>(
      ModernPageTransitions.fade(page),
    );
  }

  /// Navigate with scale transition
  Future<T?> pushWithScale<T>(Widget page) {
    return Navigator.of(this).push<T>(
      ModernPageTransitions.scale(page),
    );
  }

  /// Navigate with neumorphic transition
  Future<T?> pushWithNeumorphic<T>(Widget page) {
    return Navigator.of(this).push<T>(
      ModernPageTransitions.neumorphic(page),
    );
  }

  /// Replace with slide transition
  Future<T?> replaceWithSlide<T, TO>(Widget page) {
    return Navigator.of(this).pushReplacement<T, TO>(
      ModernPageTransitions.slideFromRight(page),
    );
  }

  /// Replace with fade transition
  Future<T?> replaceWithFade<T, TO>(Widget page) {
    return Navigator.of(this).pushReplacement<T, TO>(
      ModernPageTransitions.fade(page),
    );
  }
}

/// Hero transition utilities
class ModernHeroTransition {
  /// Create a hero widget with custom transition
  static Widget create({
    required String tag,
    required Widget child,
    Duration? duration,
  }) {
    return Hero(
      tag: tag,
      transitionOnUserGestures: true,
      flightShuttleBuilder: (
        BuildContext flightContext,
        Animation<double> animation,
        HeroFlightDirection flightDirection,
        BuildContext fromHeroContext,
        BuildContext toHeroContext,
      ) {
        return DefaultTextStyle(
          style: DefaultTextStyle.of(toHeroContext).style,
          child: toHeroContext.widget,
        );
      },
      child: child,
    );
  }
}

/// Page route with custom transition builder
class CustomPageRoute<T> extends PageRoute<T> {
  final Widget child;
  @override
  final Duration transitionDuration;
  final RouteTransitionsBuilder transitionsBuilder;

  CustomPageRoute({
    required this.child,
    this.transitionDuration = const Duration(milliseconds: 400),
    required this.transitionsBuilder,
    super.settings,
  });

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return child;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return transitionsBuilder(context, animation, secondaryAnimation, child);
  }

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => this.transitionDuration;
}

