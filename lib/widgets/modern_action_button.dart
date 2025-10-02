import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

class ModernActionButton extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isEnabled;
  final bool isLoading;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final String? subtitle;
  final bool isPrimary;

  const ModernActionButton({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    this.onTap,
    this.isEnabled = true,
    this.isLoading = false,
    this.width,
    this.height,
    this.padding,
    this.subtitle,
    this.isPrimary = false,
  });

  @override
  State<ModernActionButton> createState() => _ModernActionButtonState();
}

class _ModernActionButtonState extends State<ModernActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap != null && widget.isEnabled && !widget.isLoading) {
      setState(() => _isPressed = true);
      _animationController.forward();
      HapticFeedback.lightImpact();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap != null && widget.isEnabled && !widget.isLoading) {
      setState(() => _isPressed = false);
      _animationController.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.onTap != null && widget.isEnabled && !widget.isLoading) {
      setState(() => _isPressed = false);
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Choose foreground colors based on background brightness to ensure contrast
    final bool isLightBackground = ThemeData.estimateBrightnessForColor(widget.color) == Brightness.light;
    final Color effectiveFg = widget.isEnabled
        ? (isLightBackground ? AppColors.textPrimary : AppColors.white)
        : AppColors.mediumGray;
    final Color effectiveIconContainer = widget.isEnabled
        ? (isLightBackground ? AppColors.mediumGray.withOpacity(0.12) : AppColors.white.withOpacity(0.2))
        : AppColors.mediumGray.withOpacity(0.2);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: GestureDetector(
              onTapDown: _handleTapDown,
              onTapUp: _handleTapUp,
              onTapCancel: _handleTapCancel,
              onTap: widget.isEnabled && !widget.isLoading ? widget.onTap : null,
              child: Container(
                width: widget.width ?? (widget.isPrimary ? double.infinity : 140),
                height: widget.height ?? (widget.isPrimary ? 80 : 100),
                padding: widget.padding ?? EdgeInsets.all(widget.isPrimary ? 20 : 16),
                decoration: BoxDecoration(
                  color: widget.isEnabled 
                      ? (_isPressed ? widget.color.withOpacity(0.9) : widget.color)
                      : AppColors.mediumGray.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: isLightBackground
                      ? Border.all(color: AppColors.borderColor)
                      : null,
                  boxShadow: _isPressed
                      ? [
                          // Pressed state - reduced shadow
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 3,
                            offset: const Offset(1, 1),
                          ),
                        ]
                      : [
                          // Normal state - raised shadow
                          BoxShadow(
                            color: widget.color.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.8),
                            blurRadius: 8,
                            offset: const Offset(0, -4),
                          ),
                        ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.isLoading)
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            effectiveFg,
                          ),
                        ),
                      )
                    else
                      Container(
                        width: widget.isPrimary ? 48 : 40,
                        height: widget.isPrimary ? 48 : 40,
                        decoration: BoxDecoration(
                          color: effectiveIconContainer,
                          borderRadius: BorderRadius.circular(widget.isPrimary ? 16 : 12),
                        ),
                        child: Icon(
                          widget.icon,
                          color: effectiveFg,
                          size: widget.isPrimary ? 24 : 20,
                        ),
                      ),
                    SizedBox(height: widget.isPrimary ? 12 : 8),
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: widget.isPrimary ? 16 : 12,
                        fontWeight: widget.isPrimary ? FontWeight.w700 : FontWeight.w600,
                        color: effectiveFg,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.subtitle != null) ...[
                      SizedBox(height: widget.isPrimary ? 4 : 2),
                      Text(
                        widget.subtitle!,
                        style: TextStyle(
                          fontSize: widget.isPrimary ? 12 : 10,
                          fontWeight: widget.isPrimary ? FontWeight.w600 : FontWeight.w500,
                          color: effectiveFg.withOpacity(0.8),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

