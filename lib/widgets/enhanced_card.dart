import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../constants/app_spacing.dart';

class EnhancedCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final CardVariant variant;
  final CardSize size;
  final CardState state;
  final bool isElevated;
  final bool isInteractive;
  final VoidCallback? onTap;
  final Color? accentColor;
  final String? title;
  final String? subtitle;
  final Widget? header;
  final Widget? footer;
  final bool isLoading;
  final bool enableHoverEffects;
  final bool enablePressEffects;
  final Duration animationDuration;

  const EnhancedCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.variant = CardVariant.elevated,
    this.size = CardSize.medium,
    this.state = CardState.normal,
    this.isElevated = true,
    this.isInteractive = false,
    this.onTap,
    this.accentColor,
    this.title,
    this.subtitle,
    this.header,
    this.footer,
    this.isLoading = false,
    this.enableHoverEffects = true,
    this.enablePressEffects = true,
    this.animationDuration = const Duration(milliseconds: 200),
  });

  @override
  State<EnhancedCard> createState() => _EnhancedCardState();
}

class _EnhancedCardState extends State<EnhancedCard> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  late Animation<double> _hoverAnimation;

  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _elevationAnimation = Tween<double>(
      begin: 8.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _hoverAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _hoverController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.enablePressEffects && widget.onTap != null && widget.state != CardState.disabled) {
      setState(() => _isPressed = true);
      _animationController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.enablePressEffects && widget.onTap != null && widget.state != CardState.disabled) {
      setState(() => _isPressed = false);
      _animationController.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.enablePressEffects && widget.state != CardState.disabled) {
      setState(() => _isPressed = false);
      _animationController.reverse();
    }
  }

  void _handleHoverEnter(PointerEvent event) {
    if (widget.enableHoverEffects && widget.state != CardState.disabled) {
      setState(() => _isHovered = true);
      _hoverController.forward();
    }
  }

  void _handleHoverExit(PointerEvent event) {
    if (widget.enableHoverEffects) {
      setState(() => _isHovered = false);
      _hoverController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardStyle = _getCardStyle();

    return AnimatedBuilder(
      animation: Listenable.merge([_animationController, _hoverController]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value * (1.0 + (_hoverAnimation.value * 0.02)),
          child: MouseRegion(
            onEnter: _handleHoverEnter,
            onExit: _handleHoverExit,
            child: GestureDetector(
              onTapDown: _handleTapDown,
              onTapUp: _handleTapUp,
              onTapCancel: _handleTapCancel,
              onTap: widget.state != CardState.disabled ? widget.onTap : null,
              child: Opacity(
                opacity: widget.state == CardState.disabled ? 0.6 : 1.0,
                child: Container(
                  margin: widget.margin ?? EdgeInsets.zero,
                  decoration: BoxDecoration(
                    gradient: cardStyle.gradient,
                    color: cardStyle.backgroundColor,
                    borderRadius: BorderRadius.circular(cardStyle.borderRadius),
                    border: cardStyle.border,
                    boxShadow: widget.isElevated ? _getDynamicShadows(cardStyle.shadows) : [],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: widget.padding ?? _getPadding(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          if (widget.header != null || widget.title != null) ...[
                            _buildHeader(),
                            const SizedBox(height: AppSpacing.md),
                          ],

                          // Content
                          if (widget.isLoading)
                            _buildLoadingContent()
                          else
                            widget.child,

                          // Footer
                          if (widget.footer != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            widget.footer!,
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    if (widget.header != null) return widget.header!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null)
          Text(
            widget.title!,
            style: AppTypography.headlineSmall.copyWith(
              color: widget.state == CardState.disabled
                ? AppColors.textSecondary
                : AppColors.textPrimary,
            ),
          ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.subtitle!,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoadingContent() {
    return SizedBox(
      height: _getLoadingHeight(),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  widget.accentColor ?? AppColors.primaryRed,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Loading...',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _getLoadingHeight() {
    switch (widget.size) {
      case CardSize.small:
        return 80;
      case CardSize.medium:
        return 120;
      case CardSize.large:
        return 160;
    }
  }

  List<BoxShadow> _getDynamicShadows(List<BoxShadow> baseShadows) {
    if (widget.state == CardState.disabled) {
      return [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];
    }

    if (_isPressed) {
      return [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];
    }

    if (_isHovered) {
      return baseShadows.map((shadow) {
        return BoxShadow(
          color: shadow.color,
          blurRadius: (shadow.blurRadius * 1.3).clamp(0.0, 40.0),
          offset: Offset(
            shadow.offset.dx,
            (shadow.offset.dy * 1.2).clamp(-10.0, 20.0),
          ),
          spreadRadius: (shadow.spreadRadius ?? 0) + 2,
        );
      }).toList();
    }

    return baseShadows;
  }

  _CardStyle _getCardStyle() {
    switch (widget.variant) {
      case CardVariant.elevated:
        return _CardStyle(
          backgroundColor: AppColors.cardGlassGradient,
          border: Border.all(
            color: AppColors.glassBorder,
            width: 1,
          ),
          borderRadius: AppSpacing.radiusXl,
          shadows: [
            const BoxShadow(
              color: AppColors.redShadow,
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
            BoxShadow(
              color: AppColors.neumorphicHighlight.withOpacity(0.8),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        );

      case CardVariant.outlined:
        return _CardStyle(
          gradient: null,
          backgroundColor: AppColors.white,
          border: Border.all(
            color: AppColors.borderColor,
            width: 1.5,
          ),
          borderRadius: AppSpacing.radiusLg,
          shadows: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        );

      case CardVariant.filled:
        return _CardStyle(
          gradient: null,
          backgroundColor: widget.accentColor ?? AppColors.primaryRed.withOpacity(0.05),
          border: Border.all(
            color: (widget.accentColor ?? AppColors.primaryRed).withOpacity(0.2),
            width: 1,
          ),
          borderRadius: AppSpacing.radiusXl,
          shadows: [
            BoxShadow(
              color: (widget.accentColor ?? AppColors.primaryRed).withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        );

      // Removed gradient case - no gradients allowed
        return _CardStyle(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (widget.accentColor ?? AppColors.primaryRed).withOpacity(0.8),
              (widget.accentColor ?? AppColors.primaryRed).withOpacity(0.4),
              (widget.accentColor ?? AppColors.primaryRed).withOpacity(0.9),
            ],
          ),
          backgroundColor: null,
          border: Border.all(
            color: (widget.accentColor ?? AppColors.primaryRed).withOpacity(0.3),
            width: 1,
          ),
          borderRadius: AppSpacing.radiusXxl,
          shadows: [
            BoxShadow(
              color: (widget.accentColor ?? AppColors.primaryRed).withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        );

      case CardVariant.neumorphic:
        return _CardStyle(
          gradient: null,
          backgroundColor: AppColors.white,
          border: null,
          borderRadius: AppSpacing.radiusXxl,
          shadows: [
            BoxShadow(
              color: AppColors.neumorphicShadow,
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: AppColors.neumorphicHighlight,
              blurRadius: 20,
              offset: const Offset(0, -10),
            ),
          ],
        );

      case CardVariant.emergency:
        return _CardStyle(
          gradient: null,
          backgroundColor: AppColors.criticalBackground,
          border: Border.all(
            color: AppColors.emergencyRed,
            width: 2,
          ),
          borderRadius: AppSpacing.radiusLg,
          shadows: [
            BoxShadow(
              color: AppColors.emergencyRed.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        );

      case CardVariant.status:
        return _CardStyle(
          gradient: null,
          backgroundColor: AppColors.emergencyBackground,
          border: Border.all(
            color: AppColors.borderColor,
            width: 1,
          ),
          borderRadius: AppSpacing.radiusMd,
          shadows: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        );

      case CardVariant.alert:
        return _CardStyle(
          gradient: null,
          backgroundColor: AppColors.warningBackground,
          border: Border.all(
            color: AppColors.warningOrange,
            width: 1.5,
          ),
          borderRadius: AppSpacing.radiusLg,
          shadows: [
            BoxShadow(
              color: AppColors.warningOrange.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        );

      case CardVariant.network:
        return _CardStyle(
          gradient: null,
          backgroundColor: AppColors.successBackground,
          border: Border.all(
            color: AppColors.successGreen,
            width: 1,
          ),
          borderRadius: AppSpacing.radiusMd,
          shadows: [
            BoxShadow(
              color: AppColors.successGreen.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        );
    }
  }

  EdgeInsets _getPadding() {
    switch (widget.size) {
      case CardSize.small:
        return const EdgeInsets.all(AppSpacing.md);
      case CardSize.medium:
        return const EdgeInsets.all(AppSpacing.lg);
      case CardSize.large:
        return const EdgeInsets.all(AppSpacing.xl);
    }
  }
}

enum CardVariant {
  elevated,    // Default elevated card with neumorphism
  outlined,    // Clean outlined card
  filled,      // Subtle filled card with accent color
  neumorphic,  // Premium neumorphic card
  emergency,   // Emergency alert card with high contrast
  status,      // Status indicator card
  alert,       // Alert/notification card
  network,     // Network status card
}

enum CardSize {
  small,       // Compact card for lists
  medium,      // Standard card size
  large,       // Large card for hero sections
}

enum CardState {
  normal,      // Default interactive state
  hovered,     // Mouse hover state (desktop)
  pressed,     // Touch press state (mobile)
  disabled,    // Non-interactive state
  loading,     // Loading state
}

class _CardStyle {
  final LinearGradient? gradient;
  final Color? backgroundColor;
  final Border? border;
  final double borderRadius;
  final List<BoxShadow> shadows;

  _CardStyle({
    this.gradient,
    this.backgroundColor,
    this.border,
    required this.borderRadius,
    required this.shadows,
  });
}
