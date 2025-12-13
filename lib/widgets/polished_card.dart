import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

/// Polished Card Widget
/// 
/// Enhanced card with:
/// - Consistent elevation/shadow
/// - Better hover/press states
/// - Entrance animations
/// - Improved content layout
class PolishedCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double? borderRadius;
  final double elevation;
  final VoidCallback? onTap;
  final bool enableAnimation;
  final bool enableHover;
  final bool enablePress;
  final Duration? entranceDelay;
  final Curve entranceCurve;

  const PolishedCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderRadius,
    this.elevation = 4.0,
    this.onTap,
    this.enableAnimation = true,
    this.enableHover = true,
    this.enablePress = true,
    this.entranceDelay,
    this.entranceCurve = Curves.easeOutCubic,
  });

  @override
  State<PolishedCard> createState() => _PolishedCardState();
}

class _PolishedCardState extends State<PolishedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _interactionController;
  late Animation<double> _entranceAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    
    // Entrance animation controller
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    // Interaction animation controller
    _interactionController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    // Entrance animations (fade + scale)
    _entranceAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: widget.entranceCurve,
    );
    
    // Press animations
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(
      parent: _interactionController,
      curve: Curves.easeInOut,
    ));
    
    _elevationAnimation = Tween<double>(
      begin: widget.elevation,
      end: widget.elevation * 0.3,
    ).animate(CurvedAnimation(
      parent: _interactionController,
      curve: Curves.easeInOut,
    ));
    
    // Start entrance animation
    if (widget.enableAnimation) {
      final delay = widget.entranceDelay ?? Duration.zero;
      Future.delayed(delay, () {
        if (mounted) {
          _entranceController.forward();
        }
      });
    } else {
      _entranceController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _interactionController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.enablePress && widget.onTap != null) {
      _interactionController.forward();
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.enablePress && widget.onTap != null) {
      _interactionController.reverse();
      widget.onTap?.call();
    }
  }

  void _handleTapCancel() {
    if (widget.enablePress && widget.onTap != null) {
      _interactionController.reverse();
    }
  }

  void _handleHoverEnter(PointerEnterEvent event) {
    if (widget.enableHover) {
      setState(() => _isHovered = true);
    }
  }

  void _handleHoverExit(PointerExitEvent event) {
    if (widget.enableHover) {
      setState(() => _isHovered = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.borderRadius ?? 16.0;
    final backgroundColor = widget.backgroundColor ?? Colors.white;
    final currentElevation = _elevationAnimation.value;
    final hoverElevation = _isHovered ? 2.0 : 0.0;
    final totalElevation = currentElevation + hoverElevation;
    
    Widget card = AnimatedBuilder(
      animation: Listenable.merge([
        _entranceController,
        _interactionController,
      ]),
      builder: (context, child) {
        return FadeTransition(
          opacity: _entranceAnimation,
          child: ScaleTransition(
            scale: Tween<double>(
              begin: 0.96,
              end: 1.0,
            ).animate(_entranceAnimation),
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                margin: widget.margin ?? const EdgeInsets.all(8),
                padding: widget.padding ?? const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(
                    color: AppColors.lightGray.withOpacity(0.15),
                    width: 1.0,
                  ),
                  boxShadow: _buildShadows(totalElevation),
                ),
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
    
    if (widget.onTap != null) {
      card = MouseRegion(
        onEnter: _handleHoverEnter,
        onExit: _handleHoverExit,
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          behavior: HitTestBehavior.opaque,
          child: card,
        ),
      );
    }
    
    return card;
  }
  
  List<BoxShadow> _buildShadows(double elevation) {
    final hoverGlow = _isHovered ? 0.1 : 0.0;
    
    return [
      // Main shadow
      BoxShadow(
        color: Colors.black.withOpacity(0.08 * (elevation / widget.elevation)),
        blurRadius: elevation * 2,
        offset: Offset(0, elevation * 0.5),
        spreadRadius: elevation * 0.1,
      ),
      // Ambient shadow
      BoxShadow(
        color: Colors.black.withOpacity(0.04 * (elevation / widget.elevation)),
        blurRadius: elevation * 3,
        offset: Offset(0, elevation * 0.75),
        spreadRadius: elevation * 0.2,
      ),
      // Hover glow
      if (_isHovered && widget.enableHover)
        BoxShadow(
          color: AppColors.primaryRed.withOpacity(hoverGlow),
          blurRadius: 20,
          spreadRadius: 2,
        ),
      // Light shadow for depth
      BoxShadow(
        color: Colors.white.withOpacity(0.8),
        blurRadius: elevation,
        offset: Offset(0, -elevation * 0.25),
        spreadRadius: 0,
      ),
    ];
  }
}

/// Card with standardized spacing and layout
class PolishedContentCard extends StatelessWidget {
  final Widget? title;
  final Widget? subtitle;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double elevation;

  const PolishedContentCard({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.trailing,
    this.padding,
    this.margin,
    this.onTap,
    this.elevation = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    return PolishedCard(
      onTap: onTap,
      elevation: elevation,
      margin: margin,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null || subtitle != null || trailing != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title != null) ...[
                        DefaultTextStyle(
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkGray,
                          ),
                          child: title!,
                        ),
                        if (subtitle != null) const SizedBox(height: 4),
                      ],
                      if (subtitle != null)
                        DefaultTextStyle(
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.mediumGray,
                          ),
                          child: subtitle!,
                        ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          if (title != null || subtitle != null) const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

