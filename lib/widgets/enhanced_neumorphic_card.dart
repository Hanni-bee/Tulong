import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../utils/neumorphic_utils.dart';

/// Enhanced neumorphic card with advanced features
class EnhancedNeumorphicCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final double borderRadius;
  final Color? backgroundColor;
  final bool enableHaptic;
  final bool enableAnimation;
  final double depth;
  final Widget? leading;
  final Widget? trailing;
  final String? title;
  final String? subtitle;
  final bool showGlow;
  final Color? glowColor;

  const EnhancedNeumorphicCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius = 20.0,
    this.backgroundColor,
    this.enableHaptic = true,
    this.enableAnimation = true,
    this.depth = 8.0,
    this.leading,
    this.trailing,
    this.title,
    this.subtitle,
    this.showGlow = false,
    this.glowColor,
  });

  @override
  State<EnhancedNeumorphicCard> createState() => _EnhancedNeumorphicCardState();
}

class _EnhancedNeumorphicCardState extends State<EnhancedNeumorphicCard>
    with TickerProviderStateMixin {
  late AnimationController _pressController;
  late AnimationController _hoverController;
  late AnimationController _glowController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  late Animation<double> _hoverAnimation;
  late Animation<double> _glowAnimation;
  
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    if (widget.showGlow) {
      _glowController.repeat(reverse: true);
    }
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _pressController,
      curve: Curves.easeInOut,
    ));

    _elevationAnimation = Tween<double>(
      begin: widget.depth,
      end: widget.depth * 0.3,
    ).animate(CurvedAnimation(
      parent: _pressController,
      curve: Curves.easeInOut,
    ));

    _hoverAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOutCubic,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _pressController.dispose();
    _hoverController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap != null && widget.enableAnimation) {
      setState(() => _isPressed = true);
      _pressController.forward();
      if (widget.enableHaptic) {
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

  void _handleHoverEnter(PointerEnterEvent event) {
    setState(() => _isHovered = true);
    _hoverController.forward();
  }

  void _handleHoverExit(PointerExitEvent event) {
    setState(() => _isHovered = false);
    _hoverController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.backgroundColor ?? AppColors.white;
    
    return AnimatedBuilder(
      animation: Listenable.merge([
        _scaleAnimation,
        _hoverAnimation,
        _glowAnimation,
      ]),
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
              onTap: widget.onTap,
              onLongPress: widget.onLongPress != null
                  ? () {
                      if (widget.enableHaptic) {
                        HapticFeedback.mediumImpact();
                      }
                      widget.onLongPress?.call();
                    }
                  : null,
              child: Container(
                width: widget.width,
                height: widget.height,
                margin: widget.margin ?? const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      baseColor,
                      baseColor.withOpacity(0.98),
                      baseColor.withOpacity(0.95),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  boxShadow: [
                    ..._isPressed
                        ? NeumorphicUtils.getInnerShadow(
                            depth: widget.depth * 0.5,
                          )
                        : NeumorphicUtils.getNeumorphicShadow(
                            depth: _elevationAnimation.value +
                                (_hoverAnimation.value * 2),
                          ),
                    if (widget.showGlow)
                      ...NeumorphicUtils.getPulsingGlow(
                        color: widget.glowColor ?? AppColors.primaryRed,
                        animationValue: _glowAnimation.value,
                        maxRadius: 20,
                      ),
                    if (_isHovered)
                      BoxShadow(
                        color: AppColors.primaryRed
                            .withOpacity(0.15 * _hoverAnimation.value),
                        blurRadius: 20 * _hoverAnimation.value,
                        spreadRadius: 2 * _hoverAnimation.value,
                      ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                      onTap: widget.onTap,
                      child: Padding(
                        padding: widget.padding ?? const EdgeInsets.all(16.0),
                        child: _buildCardContent(),
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

  Widget _buildCardContent() {
    if (widget.title != null || widget.leading != null || widget.trailing != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.leading != null || widget.title != null || widget.trailing != null)
            Row(
              children: [
                if (widget.leading != null) ...[
                  widget.leading!,
                  const SizedBox(width: 12),
                ],
                if (widget.title != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title!,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.2,
                          ),
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.subtitle!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 12),
                  widget.trailing!,
                ],
              ],
            ),
          if (widget.title != null || widget.leading != null || widget.trailing != null)
            const SizedBox(height: 12),
          widget.child,
        ],
      );
    }
    
    return widget.child;
  }
}

/// Glassmorphic card with modern design
class GlassmorphicCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? tintColor;
  final double opacity;
  final double blur;
  final VoidCallback? onTap;

  const GlassmorphicCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20.0,
    this.tintColor,
    this.opacity = 0.15,
    this.blur = 10.0,
    this.onTap,
  });

  @override
  State<GlassmorphicCard> createState() => _GlassmorphicCardState();
}

class _GlassmorphicCardState extends State<GlassmorphicCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
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
      onTapDown: (_) {
        if (widget.onTap != null) {
          _controller.forward();
          HapticFeedback.lightImpact();
        }
      },
      onTapUp: (_) {
        if (widget.onTap != null) {
          _controller.reverse();
          widget.onTap?.call();
        }
      },
      onTapCancel: () {
        if (widget.onTap != null) {
          _controller.reverse();
        }
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              margin: widget.margin ?? const EdgeInsets.all(8),
              decoration: NeumorphicUtils.getGlassmorphicDecoration(
                borderRadius: widget.borderRadius,
                tintColor: widget.tintColor,
                opacity: widget.opacity,
                blur: widget.blur,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                child: BackdropFilter(
                  filter: ColorFilter.mode(
                    Colors.white.withOpacity(0.1),
                    BlendMode.overlay,
                  ),
                  child: Padding(
                    padding: widget.padding ?? const EdgeInsets.all(16.0),
                    child: widget.child,
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

/// Stat card with neumorphic design
class NeumorphicStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final String? subtitle;
  final Widget? trailing;

  const NeumorphicStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor = AppColors.primaryRed,
    this.backgroundColor,
    this.onTap,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return EnhancedNeumorphicCard(
      onTap: onTap,
      backgroundColor: backgroundColor,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  iconColor.withOpacity(0.2),
                  iconColor.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary.withOpacity(0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

