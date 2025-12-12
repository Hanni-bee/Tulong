import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:async';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

/// Enhanced button with scale + ripple + glow effects
class EnhancedInteractiveButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? glowColor;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;
  final bool enableHaptic;
  final HapticFeedbackType hapticType;
  final Duration animationDuration;
  final double scaleAmount;

  const EnhancedInteractiveButton({
    super.key,
    required this.child,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.glowColor,
    this.padding,
    this.borderRadius,
    this.width,
    this.height,
    this.enableHaptic = true,
    this.hapticType = HapticFeedbackType.medium,
    this.animationDuration = const Duration(milliseconds: 150),
    this.scaleAmount = 0.95,
  });

  @override
  State<EnhancedInteractiveButton> createState() => _EnhancedInteractiveButtonState();
}

enum HapticFeedbackType {
  light,
  medium,
  heavy,
  selection,
}

class _EnhancedInteractiveButtonState extends State<EnhancedInteractiveButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleAmount,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
    
    if (widget.enableHaptic && widget.onPressed != null) {
      switch (widget.hapticType) {
        case HapticFeedbackType.light:
          HapticFeedback.lightImpact();
          break;
        case HapticFeedbackType.medium:
          HapticFeedback.mediumImpact();
          break;
        case HapticFeedbackType.heavy:
          HapticFeedback.heavyImpact();
          break;
        case HapticFeedbackType.selection:
          HapticFeedback.selectionClick();
          break;
      }
    }
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onPressed?.call();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final glowColor = widget.glowColor ?? widget.backgroundColor ?? AppColors.primaryRed;
    
    return GestureDetector(
      onTapDown: widget.onPressed != null ? _handleTapDown : null,
      onTapUp: widget.onPressed != null ? _handleTapUp : null,
      onTapCancel: widget.onPressed != null ? _handleTapCancel : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.width,
              height: widget.height,
              padding: widget.padding ?? const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              decoration: BoxDecoration(
                color: widget.backgroundColor ?? AppColors.primaryRed,
                borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
                boxShadow: [
                  // Glow effect
                  BoxShadow(
                    color: glowColor.withOpacity(_glowAnimation.value * 0.5),
                    blurRadius: 20 * _glowAnimation.value,
                    spreadRadius: 5 * _glowAnimation.value,
                  ),
                  // Standard shadow
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: DefaultTextStyle(
                style: TextStyle(
                  color: widget.foregroundColor ?? Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                child: widget.child,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Success animation widget (checkmark)
class SuccessAnimation extends StatefulWidget {
  final VoidCallback? onComplete;
  final double size;
  final Color color;

  const SuccessAnimation({
    super.key,
    this.onComplete,
    this.size = 80,
    this.color = AppColors.success,
  });

  @override
  State<SuccessAnimation> createState() => _SuccessAnimationState();
}

class _SuccessAnimationState extends State<SuccessAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkmarkAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: 1.2), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _checkmarkAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: CustomPaint(
              painter: CheckmarkPainter(
                progress: _checkmarkAnimation.value,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}

class CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;

  CheckmarkPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(size.width * 0.25, size.height * 0.5);
    path.lineTo(size.width * 0.45, size.height * 0.7);
    path.lineTo(size.width * 0.75, size.height * 0.3);

    final pathMetrics = path.computeMetrics().first;
    final pathLength = pathMetrics.length;
    final drawnLength = pathLength * progress;

    final pathToDraw = pathMetrics.extractPath(0, drawnLength);
    canvas.drawPath(pathToDraw, paint);
  }

  @override
  bool shouldRepaint(CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Confetti animation
class ConfettiAnimation extends StatefulWidget {
  final VoidCallback? onComplete;
  final int particleCount;
  final List<Color> colors;

  const ConfettiAnimation({
    super.key,
    this.onComplete,
    this.particleCount = 50,
    this.colors = const [
      AppColors.primaryRed,
      AppColors.success,
      AppColors.warning,
      AppColors.info,
    ],
  });

  @override
  State<ConfettiAnimation> createState() => _ConfettiAnimationState();
}

class _ConfettiAnimationState extends State<ConfettiAnimation>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.particleCount,
      (index) => AnimationController(
        duration: Duration(milliseconds: 1000 + _random.nextInt(500)),
        vsync: this,
      ),
    );

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeOut,
        ),
      );
    }).toList();

    // Start all animations
    for (var controller in _controllers) {
      controller.forward();
    }

    // Call onComplete after all animations
    Future.delayed(const Duration(milliseconds: 1500), () {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(widget.particleCount, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            final angle = _random.nextDouble() * 2 * math.pi;
            final distance = 200 * _animations[index].value;
            final x = math.cos(angle) * distance;
            final y = math.sin(angle) * distance + 100 * _animations[index].value;

            return Positioned(
              left: MediaQuery.of(context).size.width / 2 + x,
              top: MediaQuery.of(context).size.height / 2 + y,
              child: Transform.rotate(
                angle: _animations[index].value * 2 * math.pi,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.colors[_random.nextInt(widget.colors.length)],
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

/// Swipeable list item with delete/archive actions
class SwipeableListItem extends StatefulWidget {
  final Widget child;
  final VoidCallback? onDelete;
  final VoidCallback? onArchive;
  final Color? backgroundColor;
  final bool enableSwipe;

  const SwipeableListItem({
    super.key,
    required this.child,
    this.onDelete,
    this.onArchive,
    this.backgroundColor,
    this.enableSwipe = true,
  });

  @override
  State<SwipeableListItem> createState() => _SwipeableListItemState();
}

class _SwipeableListItemState extends State<SwipeableListItem>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0.0;

  @override
  Widget build(BuildContext context) {
    if (!widget.enableSwipe) {
      return widget.child;
    }

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx < 0) {
          // Swiping left (reveal delete)
          setState(() {
            _dragOffset = (_dragOffset + details.delta.dx).clamp(-120.0, 0.0);
          });
        } else {
          // Swiping right (reveal archive)
          setState(() {
            _dragOffset = (_dragOffset + details.delta.dx).clamp(0.0, 120.0);
          });
        }
      },
      onHorizontalDragEnd: (details) {
        if (_dragOffset.abs() > 60) {
          // Trigger action
          if (_dragOffset < -60 && widget.onDelete != null) {
            HapticFeedback.mediumImpact();
            widget.onDelete!();
          } else if (_dragOffset > 60 && widget.onArchive != null) {
            HapticFeedback.lightImpact();
            widget.onArchive!();
          }
        }
        // Reset position
        setState(() {
          _dragOffset = 0.0;
        });
      },
      child: Stack(
        children: [
          // Background actions
          if (_dragOffset < 0)
            Positioned.fill(
              child: Container(
                alignment: Alignment.centerRight,
                color: AppColors.error,
                child: const Padding(
                  padding: EdgeInsets.only(right: 20),
                  child: Icon(Icons.delete, color: Colors.white),
                ),
              ),
            )
          else if (_dragOffset > 0)
            Positioned.fill(
              child: Container(
                alignment: Alignment.centerLeft,
                color: AppColors.info,
                child: const Padding(
                  padding: EdgeInsets.only(left: 20),
                  child: Icon(Icons.archive, color: Colors.white),
                ),
              ),
            ),
          // Main content
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

/// Long-press tooltip widget
class LongPressTooltip extends StatefulWidget {
  final Widget child;
  final String tooltip;
  final Duration longPressDuration;
  final Color? tooltipColor;
  final TextStyle? tooltipTextStyle;

  const LongPressTooltip({
    super.key,
    required this.child,
    required this.tooltip,
    this.longPressDuration = const Duration(milliseconds: 500),
    this.tooltipColor,
    this.tooltipTextStyle,
  });

  @override
  State<LongPressTooltip> createState() => _LongPressTooltipState();
}

class _LongPressTooltipState extends State<LongPressTooltip>
    with SingleTickerProviderStateMixin {
  Timer? _longPressTimer;
  OverlayEntry? _overlayEntry;
  bool _isShowingTooltip = false;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _hideTooltip();
    super.dispose();
  }

  void _showTooltip(TapDownDetails details) {
    if (_isShowingTooltip) return;

    _longPressTimer = Timer(widget.longPressDuration, () {
      if (!mounted) return;

      final overlay = Overlay.of(context);
      final renderBox = context.findRenderObject() as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero);

      _overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          left: position.dx + renderBox.size.width / 2 - 60,
          top: position.dy - 50,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: widget.tooltipColor ?? AppColors.darkGray,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                widget.tooltip,
                style: widget.tooltipTextStyle ??
                    AppTypography.bodySmall.copyWith(
                      color: Colors.white,
                    ),
              ),
            ),
          ),
        ),
      );

      overlay.insert(_overlayEntry!);
      setState(() => _isShowingTooltip = true);
      HapticFeedback.selectionClick();
    });
  }

  void _hideTooltip() {
    _longPressTimer?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _isShowingTooltip = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) => _showTooltip(details),
      onTapUp: (_) => _hideTooltip(),
      onTapCancel: () => _hideTooltip(),
      onLongPress: () {
        _hideTooltip();
      },
      child: widget.child,
    );
  }
}


