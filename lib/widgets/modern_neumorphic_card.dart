import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

class ModernNeumorphicCard extends StatefulWidget {
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

  const ModernNeumorphicCard({
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
  });

  @override
  State<ModernNeumorphicCard> createState() => _ModernNeumorphicCardState();
}

class _ModernNeumorphicCardState extends State<ModernNeumorphicCard>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  late Animation<double> _hoverAnimation;
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
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
    if (widget.onTap != null) {
      setState(() => _isPressed = true);
      _animationController.forward();
      if (widget.enableHapticFeedback) {
        HapticFeedback.lightImpact();
      }
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      setState(() => _isPressed = false);
      _animationController.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.onTap != null) {
      setState(() => _isPressed = false);
      _animationController.reverse();
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
              onTap: widget.onTap,
              child: Container(
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
                          // Normal state - raised shadow with hover enhancement
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08 + (_hoverAnimation.value * 0.04)),
                            blurRadius: _elevationAnimation.value + (_hoverAnimation.value * 2),
                            offset: Offset(0, (_elevationAnimation.value / 2) + (_hoverAnimation.value * 1)),
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.9 + (_hoverAnimation.value * 0.05)),
                            blurRadius: _elevationAnimation.value + (_hoverAnimation.value * 2),
                            offset: Offset(0, -(_elevationAnimation.value / 2) - (_hoverAnimation.value * 1)),
                          ),
                          // Hover glow effect
                          if (_isHovered)
                            BoxShadow(
                              color: AppColors.primaryRed.withOpacity(0.1 * _hoverAnimation.value),
                              blurRadius: 20 * _hoverAnimation.value,
                              spreadRadius: 2 * _hoverAnimation.value,
                            ),
                        ],
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
    );
  }
}

