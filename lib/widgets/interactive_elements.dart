import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import '../constants/app_colors.dart';

class InteractiveCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? backgroundColor;
  final Color? shadowColor;
  final double? elevation;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool enableHaptic;
  final bool enableGlow;

  const InteractiveCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.backgroundColor,
    this.shadowColor,
    this.elevation,
    this.borderRadius,
    this.padding,
    this.enableHaptic = true,
    this.enableGlow = false,
  });

  @override
  State<InteractiveCard> createState() => _InteractiveCardState();
}

class _InteractiveCardState extends State<InteractiveCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {});
        _controller.forward();
        if (widget.enableHaptic) {
          HapticFeedback.lightImpact();
        }
      },
      onTapUp: (_) {
        setState(() {});
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () {
        setState(() {});
        _controller.reverse();
      },
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                color: widget.backgroundColor ?? Colors.white,
                borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: widget.shadowColor ?? Colors.black.withOpacity(0.1),
                    blurRadius: widget.elevation ?? 8.0,
                    offset: const Offset(0, 4),
                  ),
                  if (widget.enableGlow)
                    BoxShadow(
                      color: AppColors.primaryRed.withOpacity(_glowAnimation.value * 0.3),
                      blurRadius: 20.0,
                      spreadRadius: 2.0,
                    ),
                ],
              ),
              child: Padding(
                padding: widget.padding ?? const EdgeInsets.all(16.0),
                child: widget.child,
              ),
            ),
          );
        },
      ),
    );
  }
}

class AnimatedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final Duration duration;
  final AnimatedTextType type;

  const AnimatedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.duration = const Duration(milliseconds: 2000),
    this.type = AnimatedTextType.typewriter,
  });

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case AnimatedTextType.typewriter:
        return AnimatedTextKit(
          animatedTexts: [
            TypewriterAnimatedText(
              text,
              textStyle: style,
              textAlign: textAlign ?? TextAlign.start,
              speed: const Duration(milliseconds: 100),
            ),
          ],
          totalRepeatCount: 1,
        );
      case AnimatedTextType.fade:
        return AnimatedTextKit(
          animatedTexts: [
            FadeAnimatedText(
              text,
              textStyle: style,
              textAlign: textAlign ?? TextAlign.start,
              duration: duration,
            ),
          ],
          totalRepeatCount: 1,
        );
      case AnimatedTextType.slide:
        return AnimatedTextKit(
          animatedTexts: [
            FadeAnimatedText(
              text,
              textStyle: style,
              textAlign: textAlign ?? TextAlign.start,
              duration: duration,
            ),
          ],
          totalRepeatCount: 1,
        );
      case AnimatedTextType.scale:
        return AnimatedTextKit(
          animatedTexts: [
            FadeAnimatedText(
              text,
              textStyle: style,
              textAlign: textAlign ?? TextAlign.start,
              duration: duration,
            ),
          ],
          totalRepeatCount: 1,
        );
      case AnimatedTextType.rotate:
        return AnimatedTextKit(
          animatedTexts: [
            FadeAnimatedText(
              text,
              textStyle: style,
              textAlign: textAlign ?? TextAlign.start,
              duration: duration,
            ),
          ],
          totalRepeatCount: 1,
        );
    }
  }
}

enum AnimatedTextType { typewriter, fade, slide, scale, rotate }

class InteractiveButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final bool isLoading;
  final bool enableHaptic;
  final ButtonStyle? style;

  const InteractiveButton({
    super.key,
    required this.text,
    this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.isLoading = false,
    this.enableHaptic = true,
    this.style,
  });

  @override
  State<InteractiveButton> createState() => _InteractiveButtonState();
}

class _InteractiveButtonState extends State<InteractiveButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.1,
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _controller.forward();
        if (widget.enableHaptic) {
          HapticFeedback.mediumImpact();
        }
      },
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () {
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Transform.rotate(
              angle: _rotationAnimation.value,
              child: ElevatedButton(
                onPressed: widget.isLoading ? null : widget.onPressed,
                style: widget.style ??
                    ElevatedButton.styleFrom(
                      backgroundColor: widget.backgroundColor ?? AppColors.primaryRed,
                      foregroundColor: widget.textColor ?? Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                child: widget.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, size: 18),
                            const SizedBox(width: 8),
                          ],
                          Text(widget.text),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class InteractiveFloatingActionButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final bool enableHaptic;
  final bool enablePulse;

  const InteractiveFloatingActionButton({
    super.key,
    required this.child,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.enableHaptic = true,
    this.enablePulse = false,
  });

  @override
  State<InteractiveFloatingActionButton> createState() =>
      _InteractiveFloatingActionButtonState();
}

class _InteractiveFloatingActionButtonState
    extends State<InteractiveFloatingActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (widget.enablePulse) {
      _controller.repeat(reverse: true);
    }
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
        _controller.forward();
        if (widget.enableHaptic) {
          HapticFeedback.mediumImpact();
        }
      },
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () {
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.enablePulse ? _pulseAnimation.value : _scaleAnimation.value,
            child: FloatingActionButton(
              onPressed: widget.onPressed,
              backgroundColor: widget.backgroundColor ?? AppColors.primaryRed,
              foregroundColor: widget.foregroundColor ?? Colors.white,
              elevation: widget.elevation ?? 6.0,
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

class InteractiveSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;
  final Color? inactiveColor;
  final bool enableHaptic;

  const InteractiveSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.activeColor,
    this.inactiveColor,
    this.enableHaptic = true,
  });

  @override
  State<InteractiveSwitch> createState() => _InteractiveSwitchState();
}

class _InteractiveSwitchState extends State<InteractiveSwitch>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (widget.value) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(InteractiveSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      if (widget.value) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.enableHaptic) {
          HapticFeedback.lightImpact();
        }
        widget.onChanged?.call(!widget.value);
      },
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Container(
            width: 50,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: Color.lerp(
                widget.inactiveColor ?? Colors.grey,
                widget.activeColor ?? AppColors.primaryRed,
                _animation.value,
              ),
            ),
            child: Transform.translate(
              offset: Offset(_animation.value * 20, 0),
              child: Container(
                width: 26,
                height: 26,
                margin: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
