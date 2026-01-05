import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/soft_ui_design.dart';
import '../utils/haptic_helper.dart';

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
      HapticHelper.light();
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
    final baseDecoration = BoxDecoration(
      color: widget.backgroundColor ?? Colors.white,
      borderRadius: BorderRadius.circular(widget.borderRadius ?? 16),
      border: widget.showBorder
          ? Border.all(
              color: widget.borderColor ?? AppColors.primaryRed.withOpacity(0.2),
              width: widget.borderWidth ?? 1.5,
            )
          : null,
      boxShadow: widget.showShadow
          ? SoftUIDesign.getCardShadow(elevation: 4.0)
          : null,
    );
    
    final card = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          margin: widget.margin ?? const EdgeInsets.all(8),
          padding: widget.padding ?? const EdgeInsets.all(16),
          decoration: baseDecoration,
          child: Stack(
            children: [
              // Depth overlay for elevated cards
              if (widget.showShadow && (widget.borderRadius ?? 16) >= 12)
                SoftUIDesign.buildDepthOverlay(
                  accentColor: AppColors.primaryRed,
                  elevation: 4.0,
                ) ?? const SizedBox.shrink(),
              // Content
              widget.child,
            ],
          ),
        );
      },
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
      padding: padding ?? const EdgeInsets.all(SoftUIDesign.cardPadding),
      margin: margin ?? const EdgeInsets.all(SoftUIDesign.cardMargin),
      backgroundColor: AppColors.white,
      borderRadius: SoftUIDesign.cardBorderRadius,
      showShadow: true, // Soft UI shadow
      showBorder: true,
      borderColor: AppColors.lightGray.withOpacity(0.3),
      borderWidth: 1.0,
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
      padding: padding ?? const EdgeInsets.all(SoftUIDesign.cardPadding),
      margin: margin ?? const EdgeInsets.all(SoftUIDesign.cardMargin),
      backgroundColor: AppColors.white,
      borderRadius: SoftUIDesign.cardBorderRadius,
      showShadow: true, // Soft UI shadow for elevation
      showBorder: true,
      borderColor: accentColor,
      borderWidth: 2.0,
      onTap: onTap,
      interactive: onTap != null,
      child: child,
    );
  }
}