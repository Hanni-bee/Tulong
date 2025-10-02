import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

class AnimatedNeumorphicCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final bool isPressed;
  final Color? backgroundColor;
  final double borderRadius;
  final bool enableHapticFeedback;
  final bool enableAnimation;
  final Duration animationDuration;
  final Curve animationCurve;
  final bool enablePulse;
  final bool enableFloating;
  final bool enableShimmer;

  const AnimatedNeumorphicCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.isPressed = false,
    this.backgroundColor,
    this.borderRadius = 16.0,
    this.enableHapticFeedback = true,
    this.enableAnimation = true,
    this.animationDuration = const Duration(milliseconds: 200),
    this.animationCurve = Curves.easeInOut,
    this.enablePulse = false,
    this.enableFloating = false,
    this.enableShimmer = false,
  });

  @override
  State<AnimatedNeumorphicCard> createState() => _AnimatedNeumorphicCardState();
}

class _AnimatedNeumorphicCardState extends State<AnimatedNeumorphicCard>
    with TickerProviderStateMixin {
  late AnimationController _pressController;
  late AnimationController _pulseController;
  late AnimationController _floatingController;
  late AnimationController _shimmerController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _floatingAnimation;
  late Animation<double> _shimmerAnimation;
  
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    
    _pressController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _pressController,
      curve: widget.animationCurve,
    ));

    _elevationAnimation = Tween<double>(
      begin: 8.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _pressController,
      curve: widget.animationCurve,
    ));

    // Pulse animation
    if (widget.enablePulse) {
      _pulseController = AnimationController(
        duration: const Duration(seconds: 2),
        vsync: this,
      );
      
      _pulseAnimation = Tween<double>(
        begin: 1.0,
        end: 1.05,
      ).animate(CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ));
      
      _pulseController.repeat(reverse: true);
    }

    // Floating animation
    if (widget.enableFloating) {
      _floatingController = AnimationController(
        duration: const Duration(seconds: 3),
        vsync: this,
      );
      
      _floatingAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _floatingController,
        curve: Curves.easeInOut,
      ));
      
      _floatingController.repeat(reverse: true);
    }

    // Shimmer animation
    if (widget.enableShimmer) {
      _shimmerController = AnimationController(
        duration: const Duration(seconds: 1),
        vsync: this,
      );
      
      _shimmerAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _shimmerController,
        curve: Curves.easeInOut,
      ));
      
      _shimmerController.repeat();
    }
  }

  @override
  void dispose() {
    _pressController.dispose();
    if (widget.enablePulse) _pulseController.dispose();
    if (widget.enableFloating) _floatingController.dispose();
    if (widget.enableShimmer) _shimmerController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap != null && widget.enableAnimation) {
      setState(() => _isPressed = true);
      _pressController.forward();
      if (widget.enableHapticFeedback) {
        HapticFeedback.lightImpact();
      }
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap != null && widget.enableAnimation) {
      setState(() => _isPressed = false);
      _pressController.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.onTap != null && widget.enableAnimation) {
      setState(() => _isPressed = false);
      _pressController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? AppColors.white,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: _isPressed || widget.isPressed
            ? [
                // Pressed state - reduced shadow
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ]
            : [
                // Normal state - raised shadow
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: _elevationAnimation.value,
                  offset: Offset(0, _elevationAnimation.value / 2),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.9),
                  blurRadius: _elevationAnimation.value,
                  offset: Offset(0, -_elevationAnimation.value / 2),
                ),
              ],
      ),
      child: Padding(
        padding: widget.padding ?? const EdgeInsets.all(16.0),
        child: widget.child,
      ),
    );

    // Apply animations
    if (widget.enableAnimation) {
      cardContent = AnimatedBuilder(
        animation: _pressController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: cardContent,
      );
    }

    if (widget.enablePulse) {
      cardContent = AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: child,
          );
        },
        child: cardContent,
      );
    }

    if (widget.enableFloating) {
      cardContent = AnimatedBuilder(
        animation: _floatingAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, 3 * (0.5 - _floatingAnimation.value).abs()),
            child: child,
          );
        },
        child: cardContent,
      );
    }

    if (widget.enableShimmer) {
      cardContent = AnimatedBuilder(
        animation: _shimmerAnimation,
        builder: (context, child) {
          return ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.grey[300]!,
                  Colors.grey[100]!,
                  Colors.grey[300]!,
                ],
                stops: [
                  (_shimmerAnimation.value - 0.3).clamp(0.0, 1.0),
                  _shimmerAnimation.value,
                  (_shimmerAnimation.value + 0.3).clamp(0.0, 1.0),
                ],
              ).createShader(bounds);
            },
            child: child,
          );
        },
        child: cardContent,
      );
    }

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      child: cardContent,
    );
  }
}
