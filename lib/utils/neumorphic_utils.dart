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
    
    if (isPressed) {
      return [
        BoxShadow(
          color: AppColors.neumorphicDark.withOpacity(0.5),
          offset: Offset(depth * 0.25, depth * 0.25),
          blurRadius: depth,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: AppColors.neumorphicLight.withOpacity(0.8),
          offset: Offset(-depth * 0.25, -depth * 0.25),
          blurRadius: depth,
          spreadRadius: 0,
        ),
      ];
    }
    
    return [
      BoxShadow(
        color: AppColors.neumorphicDark.withOpacity(0.3),
        offset: Offset(depth, depth),
        blurRadius: depth * 2,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: AppColors.neumorphicLight.withOpacity(0.9),
        offset: Offset(-depth * 0.5, -depth * 0.5),
        blurRadius: depth * 1.5,
        spreadRadius: 0,
      ),
    ];
  }

  // Neumorphic inner shadow (for pressed states)
  static List<BoxShadow> getInnerShadow({
    double depth = 4.0,
  }) {
    return [
      BoxShadow(
        color: AppColors.neumorphicDark.withOpacity(0.4),
        offset: Offset(depth, depth),
        blurRadius: depth * 2,
        spreadRadius: -depth,
      ),
      BoxShadow(
        color: AppColors.neumorphicLight.withOpacity(0.6),
        offset: Offset(-depth * 0.5, -depth * 0.5),
        blurRadius: depth * 1.5,
        spreadRadius: -depth * 0.5,
      ),
    ];
  }

  // Elevated neumorphic shadow (for floating elements)
  static List<BoxShadow> getElevatedShadow({
    double elevation = 12.0,
  }) {
    return [
      BoxShadow(
        color: AppColors.neumorphicDark.withOpacity(0.4),
        offset: Offset(elevation * 0.8, elevation),
        blurRadius: elevation * 3,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        offset: Offset(0, elevation * 0.5),
        blurRadius: elevation * 2,
        spreadRadius: 0,
      ),
      BoxShadow(
        color: AppColors.neumorphicLight.withOpacity(0.8),
        offset: Offset(-elevation * 0.3, -elevation * 0.5),
        blurRadius: elevation * 1.5,
        spreadRadius: 0,
      ),
    ];
  }

  // Neumorphic gradient background
  static BoxDecoration getNeumorphicBackground({
    Color? baseColor,
    double borderRadius = 16.0,
    bool isPressed = false,
  }) {
    final base = baseColor ?? AppColors.neumorphicBase;
    
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          base.withOpacity(0.95),
          base,
          base.withOpacity(0.98),
        ],
        stops: const [0.0, 0.5, 1.0],
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: getNeumorphicShadow(
        isPressed: isPressed,
        baseColor: base,
      ),
    );
  }

  // Glassmorphic effect (modern twist on neumorphic)
  static BoxDecoration getGlassmorphicDecoration({
    double borderRadius = 16.0,
    Color? tintColor,
    double opacity = 0.1,
    double blur = 10.0,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          (tintColor ?? Colors.white).withOpacity(opacity + 0.05),
          (tintColor ?? Colors.white).withOpacity(opacity),
        ],
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: Colors.white.withOpacity(0.2),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: blur * 2,
          offset: Offset(0, blur),
        ),
      ],
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
    final radius = maxRadius * animationValue;
    final opacity = 0.6 * (1.0 - animationValue);
    
    return [
      BoxShadow(
        color: color.withOpacity(opacity),
        blurRadius: radius,
        spreadRadius: radius * 0.5,
      ),
    ];
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
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: color.withOpacity(0.3),
        width: 2,
      ),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(glowIntensity * 0.3),
          blurRadius: 12,
          spreadRadius: 2,
        ),
      ],
    );
  }

  // Card elevation levels
  static List<BoxShadow> getCardElevation(int level) {
    switch (level) {
      case 1:
        return [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ];
      case 2:
        return [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ];
      case 3:
        return [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ];
      case 4:
        return [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ];
      default:
        return [];
    }
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

