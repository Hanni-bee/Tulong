import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

class EnhancedCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double? borderRadius;
  final bool showShadow;
  final bool showBorder;
  final Color? borderColor;
  final double? borderWidth;
  final VoidCallback? onTap;
  final bool interactive;

  const EnhancedCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderRadius,
    this.showShadow = true,
    this.showBorder = false,
    this.borderColor,
    this.borderWidth,
    this.onTap,
    this.interactive = false,
  });

  @override
  State<EnhancedCard> createState() => _EnhancedCardState();
}

class _EnhancedCardState extends State<EnhancedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _elevationAnimation = Tween<double>(
      begin: 0,
      end: -2,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.interactive || widget.onTap != null) {
      HapticFeedback.lightImpact();
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.interactive || widget.onTap != null) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.interactive || widget.onTap != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: widget.margin ?? const EdgeInsets.all(8),
      padding: widget.padding ?? const EdgeInsets.all(16),
                  decoration: BoxDecoration(
        color: widget.backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(widget.borderRadius ?? 16),
        border: widget.showBorder
            ? Border.all(
                color: widget.borderColor ?? AppColors.primaryRed.withOpacity(0.2),
                width: widget.borderWidth ?? 1.5,
              )
            : null,
        boxShadow: widget.showShadow
            ? [
                // Primary shadow for depth
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
                // Secondary shadow for softness
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                  spreadRadius: 0,
                ),
                // Highlight for neumorphic effect
                BoxShadow(
                  color: Colors.white.withOpacity(0.9),
                  blurRadius: 12,
                  offset: const Offset(-2, -2),
                  spreadRadius: 0,
                ),
                // Ambient shadow for atmosphere
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                  spreadRadius: 0,
                ),
              ]
            : null,
        gradient: widget.backgroundColor == null
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.grey.shade50,
                ],
                stops: const [0.0, 1.0],
              )
            : null,
      ),
      child: widget.child,
    );

    if (widget.onTap != null || widget.interactive) {
      return GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.translate(
                offset: Offset(0, _elevationAnimation.value),
                child: card,
              ),
            );
          },
        ),
      );
    }

    return card;
  }
}

// Specialized card variants
class PrimaryCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const PrimaryCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return EnhancedCard(
      padding: padding ?? const EdgeInsets.all(20),
      margin: margin ?? const EdgeInsets.all(12),
      backgroundColor: Colors.white,
      borderRadius: 20,
      showShadow: true,
      showBorder: true,
      borderColor: AppColors.primaryRed.withOpacity(0.3),
      borderWidth: 1.5,
      onTap: onTap,
      interactive: onTap != null,
      child: child,
    );
  }
}

class SecondaryCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const SecondaryCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return EnhancedCard(
      padding: padding ?? const EdgeInsets.all(16),
      margin: margin ?? const EdgeInsets.all(8),
      backgroundColor: AppColors.ultraLightGray,
      borderRadius: 16,
      showShadow: false,
      showBorder: true,
      borderColor: AppColors.primaryRed.withOpacity(0.25),
      borderWidth: 1.5,
      onTap: onTap,
      interactive: onTap != null,
      child: child,
    );
  }
}

class AccentCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color accentColor;

  const AccentCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.accentColor = AppColors.primaryRed,
  });

  @override
  Widget build(BuildContext context) {
    return EnhancedCard(
      padding: padding ?? const EdgeInsets.all(18),
      margin: margin ?? const EdgeInsets.all(10),
      backgroundColor: accentColor.withOpacity(0.05),
      borderRadius: 18,
      showShadow: true,
      showBorder: true,
      borderColor: accentColor.withOpacity(0.4),
      borderWidth: 2.0,
      onTap: onTap,
      interactive: onTap != null,
      child: child,
    );
  }
}