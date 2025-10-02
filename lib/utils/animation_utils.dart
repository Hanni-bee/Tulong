import 'package:flutter/material.dart';

class AnimationUtils {
  // Staggered animation for lists
  static Widget staggeredList({
    required List<Widget> children,
    Duration delay = const Duration(milliseconds: 100),
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOutCubic,
  }) {
    return Column(
      children: children.asMap().entries.map((entry) {
        int index = entry.key;
        Widget child = entry.value;
        
        return TweenAnimationBuilder<double>(
          duration: Duration(milliseconds: duration.inMilliseconds + (index * delay.inMilliseconds)),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: curve,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(
                opacity: value,
                child: child,
              ),
            );
          },
          child: child,
        );
      }).toList(),
    );
  }

  // Pulse animation
  static Widget pulse({
    required Widget child,
    Duration duration = const Duration(milliseconds: 1000),
    double minScale = 0.95,
    double maxScale = 1.05,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      tween: Tween(begin: minScale, end: maxScale),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      onEnd: () {
        // This will be handled by the parent widget
      },
      child: child,
    );
  }

  // Shimmer effect
  static Widget shimmer({
    required Widget child,
    Color baseColor = const Color(0xFFE0E0E0),
    Color highlightColor = const Color(0xFFF5F5F5),
    Duration duration = const Duration(milliseconds: 1500),
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      tween: Tween(begin: -1.0, end: 1.0),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                value - 0.3,
                value,
                value + 0.3,
              ].map((stop) => stop.clamp(0.0, 1.0)).toList(),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: child,
    );
  }

  // Typewriter effect
  static Widget typewriter({
    required String text,
    Duration duration = const Duration(milliseconds: 50),
    TextStyle? style,
  }) {
    return TweenAnimationBuilder<int>(
      duration: Duration(milliseconds: duration.inMilliseconds * text.length),
      tween: IntTween(begin: 0, end: text.length),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Text(
          text.substring(0, value),
          style: style,
        );
      },
    );
  }

  // Floating animation
  static Widget floating({
    required Widget child,
    Duration duration = const Duration(milliseconds: 2000),
    double offset = 10.0,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, offset * (value - 0.5).abs() * 2),
          child: child,
        );
      },
      onEnd: () {
        // This will be handled by the parent widget
      },
      child: child,
    );
  }

  // Bounce animation
  static Widget bounce({
    required Widget child,
    Duration duration = const Duration(milliseconds: 600),
    double intensity = 0.3,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 1.0 + (intensity * (1 - value)),
          child: child,
        );
      },
      child: child,
    );
  }

  // Slide in animation
  static Widget slideIn({
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
    Offset begin = const Offset(1.0, 0.0),
    Offset end = Offset.zero,
    Curve curve = Curves.easeOutCubic,
  }) {
    return TweenAnimationBuilder<Offset>(
      duration: duration,
      tween: Tween(begin: begin, end: end),
      curve: curve,
      builder: (context, value, child) {
        return Transform.translate(
          offset: value,
          child: child,
        );
      },
      child: child,
    );
  }

  // Fade in animation
  static Widget fadeIn({
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOut,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      tween: Tween(begin: 0.0, end: 1.0),
      curve: curve,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: child,
        );
      },
      child: child,
    );
  }

  // Scale in animation
  static Widget scaleIn({
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
    double begin = 0.0,
    double end = 1.0,
    Curve curve = Curves.easeOutCubic,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      tween: Tween(begin: begin, end: end),
      curve: curve,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: child,
    );
  }

  // Rotation animation
  static Widget rotate({
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
    double begin = 0.0,
    double end = 1.0,
    Curve curve = Curves.easeOutCubic,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      tween: Tween(begin: begin, end: end),
      curve: curve,
      builder: (context, value, child) {
        return Transform.rotate(
          angle: value * 2 * 3.14159,
          child: child,
        );
      },
      child: child,
    );
  }

  // Combined animation
  static Widget combined({
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
    double beginScale = 0.0,
    double endScale = 1.0,
    double beginOpacity = 0.0,
    double endOpacity = 1.0,
    Offset beginOffset = const Offset(0.0, 20.0),
    Offset endOffset = Offset.zero,
    Curve curve = Curves.easeOutCubic,
  }) {
    return TweenAnimationBuilder<Map<String, double>>(
      duration: duration,
      tween: Tween(begin: {
        'scale': beginScale,
        'opacity': beginOpacity,
        'offsetX': beginOffset.dx,
        'offsetY': beginOffset.dy,
      }, end: {
        'scale': endScale,
        'opacity': endOpacity,
        'offsetX': endOffset.dx,
        'offsetY': endOffset.dy,
      }),
      curve: curve,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value['scale']!,
          child: Transform.translate(
            offset: Offset(value['offsetX']!, value['offsetY']!),
            child: Opacity(
              opacity: value['opacity']!,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}
