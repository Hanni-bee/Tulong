import 'package:flutter/material.dart';

class ModernPageTransitions {
  static const Duration _defaultDuration = Duration(milliseconds: 300);
  static const Curve _defaultCurve = Curves.easeOutCubic;

  // Slide transition from right
  static Route<T> slideFromRight<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: _defaultDuration,
      reverseTransitionDuration: _defaultDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = _defaultCurve;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  // Slide transition from bottom
  static Route<T> slideFromBottom<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: _defaultDuration,
      reverseTransitionDuration: _defaultDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = _defaultCurve;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  // Fade transition
  static Route<T> fade<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: _defaultDuration,
      reverseTransitionDuration: _defaultDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  // Scale transition
  static Route<T> scale<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: _defaultDuration,
      reverseTransitionDuration: _defaultDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = 0.0;
        const end = 1.0;
        const curve = _defaultCurve;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        return ScaleTransition(
          scale: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  // Combined slide and fade
  static Route<T> slideAndFade<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: _defaultDuration,
      reverseTransitionDuration: _defaultDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const slideBegin = Offset(1.0, 0.0);
        const slideEnd = Offset.zero;
        const curve = _defaultCurve;

        var slideTween = Tween(begin: slideBegin, end: slideEnd).chain(
          CurveTween(curve: curve),
        );

        return SlideTransition(
          position: animation.drive(slideTween),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  // Neumorphic transition with shadow animation
  static Route<T> neumorphic<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const slideBegin = Offset(0.0, 0.1);
        const slideEnd = Offset.zero;
        const curve = Curves.easeOutCubic;

        var slideTween = Tween(begin: slideBegin, end: slideEnd).chain(
          CurveTween(curve: curve),
        );

        var scaleTween = Tween(begin: 0.95, end: 1.0).chain(
          CurveTween(curve: curve),
        );

        return SlideTransition(
          position: animation.drive(slideTween),
          child: ScaleTransition(
            scale: animation.drive(scaleTween),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          ),
        );
      },
    );
  }

  // Custom transition with hero animation
  static Route<T> heroTransition<T>(Widget page, {required String heroTag}) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 500),
      reverseTransitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return Hero(
          tag: heroTag,
          child: child,
        );
      },
    );
  }
}

// Custom page route with modern transitions
class ModernPageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  final String? heroTag;
  final ModernTransitionType transitionType;
  final Duration? duration;

  ModernPageRoute({
    required this.child,
    this.heroTag,
    this.transitionType = ModernTransitionType.slideFromRight,
    this.duration,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: duration ?? const Duration(milliseconds: 300),
          reverseTransitionDuration: duration ?? const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            switch (transitionType) {
              case ModernTransitionType.slideFromRight:
                final tweenRight = Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
                    .chain(CurveTween(curve: Curves.easeOutCubic));
                return SlideTransition(position: animation.drive(tweenRight), child: child);
              case ModernTransitionType.slideFromBottom:
                final tweenBottom = Tween<Offset>(begin: const Offset(0.0, 1.0), end: Offset.zero)
                    .chain(CurveTween(curve: Curves.easeOutCubic));
                return SlideTransition(position: animation.drive(tweenBottom), child: child);
              case ModernTransitionType.fade:
                return FadeTransition(opacity: animation, child: child);
              case ModernTransitionType.scale:
                final tweenScale = Tween<double>(begin: 0.0, end: 1.0)
                    .chain(CurveTween(curve: Curves.easeOutCubic));
                return ScaleTransition(scale: animation.drive(tweenScale), child: child);
              case ModernTransitionType.slideAndFade:
                final tweenSlide = Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
                    .chain(CurveTween(curve: Curves.easeOutCubic));
                return SlideTransition(
                  position: animation.drive(tweenSlide),
                  child: FadeTransition(opacity: animation, child: child),
                );
              case ModernTransitionType.neumorphic:
                final tweenNeu = Tween<Offset>(begin: const Offset(0.0, 0.1), end: Offset.zero)
                    .chain(CurveTween(curve: Curves.easeOutCubic));
                final tweenNeuScale = Tween<double>(begin: 0.95, end: 1.0)
                    .chain(CurveTween(curve: Curves.easeOutCubic));
                return SlideTransition(
                  position: animation.drive(tweenNeu),
                  child: ScaleTransition(
                    scale: animation.drive(tweenNeuScale),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                );
              case ModernTransitionType.hero:
                return child;
            }
          },
        );
}

enum ModernTransitionType {
  slideFromRight,
  slideFromBottom,
  fade,
  scale,
  slideAndFade,
  neumorphic,
  hero,
}
