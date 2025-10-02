import 'package:flutter/material.dart';

class CustomSlideTransition extends PageRouteBuilder {
  final Widget child;
  final SlideDirection direction;
  final Duration duration;
  final Curve curve;

  CustomSlideTransition({
    required this.child,
    this.direction = SlideDirection.right,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final Offset begin = _getOffset(direction);
            const Offset end = Offset.zero;

            final Tween<Offset> tween = Tween(begin: begin, end: end);
            final Animation<Offset> offsetAnimation = animation.drive(
              tween.chain(CurveTween(curve: curve)),
            );

            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
        );

  static Offset _getOffset(SlideDirection direction) {
    switch (direction) {
      case SlideDirection.right:
        return const Offset(-1.0, 0.0);
      case SlideDirection.left:
        return const Offset(1.0, 0.0);
      case SlideDirection.up:
        return const Offset(0.0, 1.0);
      case SlideDirection.down:
        return const Offset(0.0, -1.0);
    }
  }
}

enum SlideDirection { right, left, up, down }

class CustomFadeTransition extends PageRouteBuilder {
  final Widget child;
  final Duration duration;
  final Curve curve;

  CustomFadeTransition({
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation.drive(CurveTween(curve: curve)),
              child: child,
            );
          },
        );
}

class CustomScaleTransition extends PageRouteBuilder {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final double scale;

  CustomScaleTransition({
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
    this.scale = 0.8,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return ScaleTransition(
              scale: Tween<double>(
                begin: scale,
                end: 1.0,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: curve,
              )),
              child: child,
            );
          },
        );
}

class CustomRotationTransition extends PageRouteBuilder {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final double rotation;

  CustomRotationTransition({
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
    this.rotation = 0.5,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return RotationTransition(
              turns: Tween<double>(
                begin: rotation,
                end: 0.0,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: curve,
              )),
              child: child,
            );
          },
        );
}

class CustomSlideUpTransition extends PageRouteBuilder {
  final Widget child;
  final Duration duration;
  final Curve curve;

  CustomSlideUpTransition({
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const Offset begin = Offset(0.0, 1.0);
            const Offset end = Offset.zero;

            final Tween<Offset> tween = Tween(begin: begin, end: end);
            final Animation<Offset> offsetAnimation = animation.drive(
              tween.chain(CurveTween(curve: curve)),
            );

            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
        );
}

class CustomSlideDownTransition extends PageRouteBuilder {
  final Widget child;
  final Duration duration;
  final Curve curve;

  CustomSlideDownTransition({
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const Offset begin = Offset(0.0, -1.0);
            const Offset end = Offset.zero;

            final Tween<Offset> tween = Tween(begin: begin, end: end);
            final Animation<Offset> offsetAnimation = animation.drive(
              tween.chain(CurveTween(curve: curve)),
            );

            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
        );
}

class CustomZoomTransition extends PageRouteBuilder {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final double zoom;

  CustomZoomTransition({
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
    this.zoom = 0.0,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return Transform.scale(
              scale: Tween<double>(
                begin: zoom,
                end: 1.0,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: curve,
              )).value,
              child: child,
            );
          },
        );
}

class CustomFlipTransition extends PageRouteBuilder {
  final Widget child;
  final Duration duration;
  final Curve curve;
  final Axis axis;

  CustomFlipTransition({
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
    this.axis = Axis.horizontal,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateX(axis == Axis.horizontal ? 0 : animation.value * 3.14159)
                ..rotateY(axis == Axis.vertical ? 0 : animation.value * 3.14159),
              child: child,
            );
          },
        );
}

class CustomElasticTransition extends PageRouteBuilder {
  final Widget child;
  final Duration duration;
  final Curve curve;

  CustomElasticTransition({
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.elasticOut,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return Transform.scale(
              scale: Tween<double>(
                begin: 0.0,
                end: 1.0,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: curve,
              )).value,
              child: child,
            );
          },
        );
}

class CustomBounceTransition extends PageRouteBuilder {
  final Widget child;
  final Duration duration;
  final Curve curve;

  CustomBounceTransition({
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.bounceOut,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return Transform.scale(
              scale: Tween<double>(
                begin: 0.0,
                end: 1.0,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: curve,
              )).value,
              child: child,
            );
          },
        );
}