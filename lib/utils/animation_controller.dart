import 'package:flutter/material.dart';

class AppAnimationController {
  static const Duration fastAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration slowAnimation = Duration(milliseconds: 600);
  static const Duration verySlowAnimation = Duration(milliseconds: 800);

  // Animation curves
  static const Curve bounceCurve = Curves.elasticOut;
  static const Curve smoothCurve = Curves.easeInOutCubic;
  static const Curve quickCurve = Curves.easeOut;
  static const Curve slowCurve = Curves.easeInOut;

  // Page transition animations
  static Widget slideFromRight(Widget child) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: kAlwaysCompleteAnimation,
        curve: smoothCurve,
      )),
      child: child,
    );
  }

  static Widget slideFromBottom(Widget child) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.0, 1.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: kAlwaysCompleteAnimation,
        curve: smoothCurve,
      )),
      child: child,
    );
  }

  static Widget fadeIn(Widget child) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: kAlwaysCompleteAnimation,
        curve: smoothCurve,
      )),
      child: child,
    );
  }

  static Widget scaleIn(Widget child) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: kAlwaysCompleteAnimation,
        curve: bounceCurve,
      )),
      child: child,
    );
  }

  // Staggered list animations
  static Widget staggeredList({
    required List<Widget> children,
    Duration delay = const Duration(milliseconds: 100),
  }) {
    return Column(
      children: children.asMap().entries.map((entry) {
        final index = entry.key;
        final child = entry.value;
        
        return TweenAnimationBuilder<double>(
          duration: mediumAnimation + (delay * index),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 50 * (1 - value)),
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

  // Pulse animation for status indicators
  static Widget pulse({
    required Widget child,
    bool isActive = true,
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!isActive) return child;
    
    return TweenAnimationBuilder<double>(
      duration: duration,
      tween: Tween(begin: 1.0, end: 1.1),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      onEnd: () {
        // Restart animation
      },
      child: child,
    );
  }

  // Shimmer loading animation
  static Widget shimmer({
    required Widget child,
    Color? baseColor,
    Color? highlightColor,
  }) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(seconds: 1),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseColor ?? Colors.grey[300]!,
                highlightColor ?? Colors.grey[100]!,
                baseColor ?? Colors.grey[300]!,
              ],
              stops: [
                (value - 0.3).clamp(0.0, 1.0),
                value,
                (value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      onEnd: () {
        // Restart animation
      },
      child: child,
    );
  }

  // Bounce animation for buttons
  static Widget bounce({
    required Widget child,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        duration: fastAnimation,
        tween: Tween(begin: 1.0, end: 0.95),
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: child,
          );
        },
        onEnd: () {
          // Reset to normal size
        },
        child: child,
      ),
    );
  }

  // Floating animation for emergency buttons
  static Widget floating({
    required Widget child,
    Duration duration = const Duration(seconds: 3),
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 5 * (value - 0.5).abs()),
          child: child,
        );
      },
      onEnd: () {
        // Restart animation
      },
      child: child,
    );
  }

  // Typewriter effect for text
  static Widget typewriter({
    required String text,
    Duration duration = const Duration(milliseconds: 100),
    TextStyle? style,
  }) {
    return TweenAnimationBuilder<int>(
      duration: Duration(milliseconds: duration.inMilliseconds * text.length),
      tween: Tween(begin: 0, end: text.length),
      builder: (context, value, child) {
        return Text(
          text.substring(0, value),
          style: style,
        );
      },
    );
  }

  // Progress bar animation
  static Widget progressBar({
    required double progress,
    Duration duration = const Duration(milliseconds: 500),
    Color? color,
    Color? backgroundColor,
  }) {
    return TweenAnimationBuilder<double>(
      duration: duration,
      tween: Tween(begin: 0.0, end: progress),
      builder: (context, value, child) {
        return LinearProgressIndicator(
          value: value,
          backgroundColor: backgroundColor,
          valueColor: AlwaysStoppedAnimation<Color>(
            color ?? Colors.blue,
          ),
        );
      },
    );
  }
}
