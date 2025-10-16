import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../utils/neumorphic_utils.dart';

/// Modern gradient button with neumorphic design and animations
class ModernGradientButton extends StatefulWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? startColor;
  final Color? endColor;
  final double height;
  final double? width;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final TextStyle? textStyle;
  final bool enableHaptic;
  final Widget? leadingIcon;
  final Widget? trailingIcon;

  const ModernGradientButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.startColor,
    this.endColor,
    this.height = 56.0,
    this.width,
    this.borderRadius = 16.0,
    this.padding,
    this.textStyle,
    this.enableHaptic = true,
    this.leadingIcon,
    this.trailingIcon,
  });

  @override
  State<ModernGradientButton> createState() => _ModernGradientButtonState();
}

class _ModernGradientButtonState extends State<ModernGradientButton>
    with TickerProviderStateMixin {
  late AnimationController _pressController;
  late AnimationController _shimmerController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shimmerAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(
      parent: _pressController,
      curve: Curves.easeInOut,
    ));
    
    _shimmerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_shimmerController);
  }

  @override
  void dispose() {
    _pressController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = true);
      _pressController.forward();
      if (widget.enableHaptic) {
        HapticFeedback.mediumImpact();
      }
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = false);
      _pressController.reverse();
      widget.onPressed?.call();
    }
  }

  void _handleTapCancel() {
    if (widget.onPressed != null && !widget.isLoading) {
      setState(() => _isPressed = false);
      _pressController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;
    
    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _shimmerAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                gradient: isDisabled
                    ? LinearGradient(
                        colors: [
                          AppColors.mediumGray.withOpacity(0.5),
                          AppColors.darkGray.withOpacity(0.5),
                        ],
                      )
                    : NeumorphicUtils.getModernGradient(
                        startColor: widget.startColor ?? AppColors.gradientStart,
                        endColor: widget.endColor ?? AppColors.gradientEnd,
                      ),
                borderRadius: BorderRadius.circular(widget.borderRadius),
                boxShadow: _isPressed || isDisabled
                    ? NeumorphicUtils.getInnerShadow(depth: 2)
                    : [
                        BoxShadow(
                          color: (widget.startColor ?? AppColors.primaryRed)
                              .withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  onTap: isDisabled ? null : widget.onPressed,
                  child: Container(
                    padding: widget.padding ??
                        const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.leadingIcon != null) ...[
                          widget.leadingIcon!,
                          const SizedBox(width: 12),
                        ],
                        if (widget.icon != null && !widget.isLoading) ...[
                          Icon(
                            widget.icon,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (widget.isLoading)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        else
                          Flexible(
                            child: Text(
                              widget.text,
                              style: widget.textStyle ??
                                  const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (widget.trailingIcon != null) ...[
                          const SizedBox(width: 12),
                          widget.trailingIcon!,
                        ],
                      ],
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
}

/// Neumorphic outlined button
class ModernOutlinedButton extends StatefulWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? borderColor;
  final Color? textColor;
  final double height;
  final double? width;
  final double borderRadius;

  const ModernOutlinedButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.borderColor,
    this.textColor,
    this.height = 56.0,
    this.width,
    this.borderRadius = 16.0,
  });

  @override
  State<ModernOutlinedButton> createState() => _ModernOutlinedButtonState();
}

class _ModernOutlinedButtonState extends State<ModernOutlinedButton>
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
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
    final borderColor = widget.borderColor ?? AppColors.primaryRed;
    final textColor = widget.textColor ?? AppColors.primaryRed;
    final isDisabled = widget.onPressed == null || widget.isLoading;

    return GestureDetector(
      onTapDown: (_) {
        if (!isDisabled) {
          setState(() => _isPressed = true);
          _controller.forward();
          HapticFeedback.lightImpact();
        }
      },
      onTapUp: (_) {
        if (!isDisabled) {
          setState(() => _isPressed = false);
          _controller.reverse();
          widget.onPressed?.call();
        }
      },
      onTapCancel: () {
        if (!isDisabled) {
          setState(() => _isPressed = false);
          _controller.reverse();
        }
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: _isPressed
                    ? borderColor.withOpacity(0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border.all(
                  color: isDisabled
                      ? AppColors.mediumGray.withOpacity(0.3)
                      : borderColor,
                  width: 2,
                ),
                boxShadow: _isPressed
                    ? NeumorphicUtils.getInnerShadow(depth: 2)
                    : NeumorphicUtils.getCardElevation(1),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  onTap: isDisabled ? null : widget.onPressed,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null && !widget.isLoading) ...[
                          Icon(
                            widget.icon,
                            color: isDisabled
                                ? AppColors.mediumGray
                                : textColor,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (widget.isLoading)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                textColor,
                              ),
                            ),
                          )
                        else
                          Text(
                            widget.text,
                            style: TextStyle(
                              color: isDisabled
                                  ? AppColors.mediumGray
                                  : textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                      ],
                    ),
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

/// Icon button with neumorphic design
class ModernIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? backgroundColor;
  final double size;
  final double iconSize;
  final String? tooltip;

  const ModernIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.backgroundColor,
    this.size = 48.0,
    this.iconSize = 24.0,
    this.tooltip,
  });

  @override
  State<ModernIconButton> createState() => _ModernIconButtonState();
}

class _ModernIconButtonState extends State<ModernIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
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
    final button = GestureDetector(
      onTapDown: (_) {
        if (widget.onPressed != null) {
          setState(() => _isPressed = true);
          _controller.forward();
          HapticFeedback.lightImpact();
        }
      },
      onTapUp: (_) {
        if (widget.onPressed != null) {
          setState(() => _isPressed = false);
          _controller.reverse();
          widget.onPressed?.call();
        }
      },
      onTapCancel: () {
        if (widget.onPressed != null) {
          setState(() => _isPressed = false);
          _controller.reverse();
        }
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.backgroundColor ?? AppColors.white,
                shape: BoxShape.circle,
                boxShadow: _isPressed
                    ? NeumorphicUtils.getInnerShadow(depth: 2)
                    : NeumorphicUtils.getNeumorphicShadow(depth: 4),
              ),
              child: Center(
                child: Icon(
                  widget.icon,
                  size: widget.iconSize,
                  color: widget.color ?? AppColors.primaryRed,
                ),
              ),
            ),
          );
        },
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        child: button,
      );
    }

    return button;
  }
}

