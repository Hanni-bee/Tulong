import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Neumorphic design utilities for creating modern, depth-based UI elements
class NeumorphicUtils {
  // Neumorphic shadow configurations
  static List<BoxShadow> getNeumorphicShadow({
    bool isPressed = false,
    double depth = 8.0,
    Color? baseColor,
  }) {
    
    // Solid design: no outer shadows
    return [];
  }

  // Neumorphic inner shadow (for pressed states)
  static List<BoxShadow> getInnerShadow({
    double depth = 4.0,
  }) {
    // Solid design: no inner shadows
    return [];
  }

  // Elevated neumorphic shadow (for floating elements)
  static List<BoxShadow> getElevatedShadow({
    double elevation = 12.0,
  }) {
    // Solid design: no elevated shadows
    return [];
  }

  // Neumorphic gradient background
  static BoxDecoration getNeumorphicBackground({
    Color? baseColor,
    double borderRadius = 16.0,
    bool isPressed = false,
  }) {
    final base = baseColor ?? AppColors.neumorphicBase;
    
    // Solid design: plain color, no gradient/shadow
    return BoxDecoration(
      color: base,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: const [],
    );
  }

  // Glassmorphic effect (modern twist on neumorphic)
  static BoxDecoration getGlassmorphicDecoration({
    double borderRadius = 16.0,
    Color? tintColor,
    double opacity = 0.1,
    double blur = 10.0,
  }) {
    // Solid design: single tint color, no shadow
    return BoxDecoration(
      color: (tintColor ?? Colors.white).withOpacity(opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: Colors.white.withOpacity(0.2),
        width: 1.5,
      ),
    );
  }

  // Animated gradient for modern buttons
  static LinearGradient getModernGradient({
    Color? startColor,
    Color? endColor,
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: [
        startColor ?? AppColors.gradientStart,
        endColor ?? AppColors.gradientEnd,
      ],
    );
  }

  // Shimmer gradient for loading states
  static LinearGradient getShimmerGradient({
    double animationValue = 0.0,
  }) {
    return LinearGradient(
      begin: Alignment(-1.0 - animationValue, 0.0),
      end: Alignment(1.0 + animationValue, 0.0),
      colors: [
        AppColors.lightGray.withOpacity(0.3),
        AppColors.white.withOpacity(0.5),
        AppColors.lightGray.withOpacity(0.3),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
  }

  // Pulsing glow effect
  static List<BoxShadow> getPulsingGlow({
    required Color color,
    required double animationValue,
    double maxRadius = 20.0,
  }) {
    // Solid design: no glow
    return [];
  }

  // Text shadow for better readability
  static List<Shadow> getTextShadow({
    bool isLight = true,
    double strength = 1.0,
  }) {
    if (isLight) {
      return [
        Shadow(
          color: Colors.white.withOpacity(0.8 * strength),
          offset: const Offset(0, 1),
          blurRadius: 2 * strength,
        ),
      ];
    }
    
    return [
      Shadow(
        color: Colors.black.withOpacity(0.3 * strength),
        offset: const Offset(0, 2),
        blurRadius: 4 * strength,
      ),
    ];
  }

  // Border glow effect
  static BoxDecoration getBorderGlow({
    required Color color,
    double borderRadius = 16.0,
    double glowIntensity = 0.5,
  }) {
    // Solid design: border only, no glow
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: color.withOpacity(0.3),
        width: 2,
      ),
    );
  }

  // Card elevation levels
  static List<BoxShadow> getCardElevation(int level) {
    // Solid design: no elevations
    return [];
  }
}

/// Advanced neumorphic button with multiple states
class NeumorphicButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? color;
  final double width;
  final double height;
  final bool isLoading;

  const NeumorphicButton({
    super.key,
    required this.child,
    this.onPressed,
    this.padding,
    this.borderRadius = 16.0,
    this.color,
    this.width = double.infinity,
    this.height = 56.0,
    this.isLoading = false,
  });

  @override
  State<NeumorphicButton> createState() => _NeumorphicButtonState();
}

class _NeumorphicButtonState extends State<NeumorphicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onPressed != null
          ? (_) {
              setState(() => _isPressed = true);
              _controller.forward();
            }
          : null,
      onTapUp: widget.onPressed != null
          ? (_) {
              setState(() => _isPressed = false);
              _controller.reverse();
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: widget.onPressed != null
          ? () {
              setState(() => _isPressed = false);
              _controller.reverse();
            }
          : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: NeumorphicUtils.getNeumorphicBackground(
                baseColor: widget.color ?? AppColors.neumorphicBase,
                borderRadius: widget.borderRadius,
                isPressed: _isPressed,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  onTap: widget.isLoading ? null : widget.onPressed,
                  child: Container(
                    padding: widget.padding ??
                        const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                    child: widget.isLoading
                        ? const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primaryRed,
                                ),
                              ),
                            ),
                          )
                        : widget.child,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Neumorphic card with elevation
class NeumorphicCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? color;
  final VoidCallback? onTap;

  const NeumorphicCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16.0,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: NeumorphicUtils.getNeumorphicBackground(
        baseColor: color ?? AppColors.neumorphicBase,
        borderRadius: borderRadius,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16.0),
            child: child,
          ),
        ),
      ),
    );
  }
}

