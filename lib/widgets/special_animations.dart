import 'package:flutter/material.dart';
import '../utils/prototype_animations.dart';

/// Scanning Animation Widget
/// Rotates icon continuously with pulsing glow background
class ScanningAnimation extends StatefulWidget {
  final Widget child;
  final Color glowColor;

  const ScanningAnimation({
    super.key,
    required this.child,
    this.glowColor = const Color(0xFF3B82F6), // Blue
  });

  @override
  State<ScanningAnimation> createState() => _ScanningAnimationState();
}

class _ScanningAnimationState extends State<ScanningAnimation>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _glowController;
  late Animation<double> _rotationAnimation;
  late Animation<double> _glowScaleAnimation;
  late Animation<double> _glowOpacityAnimation;

  @override
  void initState() {
    super.initState();
    // Rotation animation (0 → 360 degrees, infinite)
    _rotationController = AnimationController(
      duration: PrototypeAnimations.scanningRotationDuration, // 2000ms
      vsync: this,
    )..repeat();

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * 3.14159, // 360 degrees in radians
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));

    // Glow pulse animation (scale: [1, 1.3, 1], opacity: [0.3, 0.6, 0.3])
    _glowController = AnimationController(
      duration: PrototypeAnimations.scanningRotationDuration, // 2000ms
      vsync: this,
    )..repeat(reverse: true);

    _glowScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    _glowOpacityAnimation = Tween<double>(
      begin: 0.3,
      end: 0.6,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_rotationAnimation, _glowScaleAnimation, _glowOpacityAnimation]),
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Glow background
            Transform.scale(
              scale: _glowScaleAnimation.value,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      widget.glowColor.withOpacity(_glowOpacityAnimation.value),
                      widget.glowColor.withOpacity(0),
                    ],
                  ),
                ),
              ),
            ),
            // Rotating icon
            Transform.rotate(
              angle: _rotationAnimation.value,
              child: widget.child,
            ),
          ],
        );
      },
    );
  }
}

/// Emergency Button Ripple Effect
/// Creates 3 expanding circles with staggered delays
class EmergencyButtonRipple extends StatefulWidget {
  final Widget child;
  final Color rippleColor;
  final bool isActive;

  const EmergencyButtonRipple({
    super.key,
    required this.child,
    this.rippleColor = const Color(0xFF10B981), // Green
    this.isActive = false,
  });

  @override
  State<EmergencyButtonRipple> createState() => _EmergencyButtonRippleState();
}

class _EmergencyButtonRippleState extends State<EmergencyButtonRipple>
    with TickerProviderStateMixin {
  final List<AnimationController> _rippleControllers = [];
  final List<Animation<double>> _rippleScaleAnimations = [];
  final List<Animation<double>> _rippleOpacityAnimations = [];

  @override
  void initState() {
    super.initState();
    // Create 3 ripple animations with 600ms delays (from prototype)
    for (int i = 0; i < 3; i++) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 2000), // From prototype
        vsync: this,
      );

      final scaleAnimation = Tween<double>(
        begin: 0.0,
        end: 1.5, // scale: [0, 1.5]
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOut,
      ));

      final opacityAnimation = Tween<double>(
        begin: 1.0,
        end: 0.0, // opacity: [1, 0]
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeOut,
      ));

      _rippleControllers.add(controller);
      _rippleScaleAnimations.add(scaleAnimation);
      _rippleOpacityAnimations.add(opacityAnimation);

      // Start with stagger delay (600ms between each)
      Future.delayed(Duration(milliseconds: i * 600), () {
        if (mounted) {
          controller.repeat();
        }
      });
    }
  }

  @override
  void didUpdateWidget(EmergencyButtonRipple oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      // Restart all ripples when activated
      for (final controller in _rippleControllers) {
        controller.repeat();
      }
    } else if (!widget.isActive && oldWidget.isActive) {
      // Stop all ripples when deactivated
      for (final controller in _rippleControllers) {
        controller.stop();
        controller.reset();
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _rippleControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return widget.child;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Ripple circles
        for (int i = 0; i < 3; i++)
          AnimatedBuilder(
            animation: Listenable.merge([
              _rippleScaleAnimations[i],
              _rippleOpacityAnimations[i],
            ]),
            builder: (context, child) {
              return Transform.scale(
                scale: _rippleScaleAnimations[i].value,
                child: Opacity(
                  opacity: _rippleOpacityAnimations[i].value,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.rippleColor,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        // Button content
        widget.child,
      ],
    );
  }
}

/// Empty State Entrance Animation
/// Icon scales from 0 with spring, glow pulses, text staggers
class EmptyStateEntrance extends StatefulWidget {
  final Widget iconWidget;
  final Widget textWidget;
  final Widget? actionWidget;
  final Color accentColor;

  const EmptyStateEntrance({
    super.key,
    required this.iconWidget,
    required this.textWidget,
    this.actionWidget,
    this.accentColor = const Color(0xFF3B82F6), // Blue
  });

  @override
  State<EmptyStateEntrance> createState() => _EmptyStateEntranceState();
}

class _EmptyStateEntranceState extends State<EmptyStateEntrance>
    with TickerProviderStateMixin {
  late AnimationController _iconController;
  late AnimationController _textController;
  late AnimationController _glowController;
  late Animation<double> _iconScaleAnimation;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _glowOpacityAnimation;

  @override
  void initState() {
    super.initState();
    // Icon scale animation (spring effect, delay 200ms)
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _iconScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _iconController,
      curve: Curves.easeOutBack, // Spring-like curve
    ));

    // Text animation (delay: 300ms, opacity + slide)
    _textController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.01), // 10px down
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: PrototypeAnimations.pageEntryCurve,
    ));

    _textFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: PrototypeAnimations.pageEntryCurve,
    ));

    // Glow pulse animation (infinite)
    _glowController = AnimationController(
      duration: PrototypeAnimations.pulseEffectDuration, // 2000ms
      vsync: this,
    )..repeat(reverse: true);

    _glowOpacityAnimation = Tween<double>(
      begin: 0.5,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    // Start animations with delays
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _iconController.forward();
      }
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _textController.forward();
      }
    });
  }

  @override
  void dispose() {
    _iconController.dispose();
    _textController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Icon with glow and scale
        AnimatedBuilder(
          animation: Listenable.merge([_iconScaleAnimation, _glowOpacityAnimation]),
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Glow background
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        widget.accentColor.withOpacity(_glowOpacityAnimation.value),
                        widget.accentColor.withOpacity(0),
                      ],
                    ),
                  ),
                ),
                // Scaled icon
                Transform.scale(
                  scale: _iconScaleAnimation.value,
                  child: widget.iconWidget,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 32),
        // Text with fade and slide
        FadeTransition(
          opacity: _textFadeAnimation,
          child: SlideTransition(
            position: _textSlideAnimation,
            child: widget.textWidget,
          ),
        ),
        if (widget.actionWidget != null) ...[
          const SizedBox(height: 24),
          // Action button (delay: 400ms)
          FadeTransition(
            opacity: _textFadeAnimation,
            child: SlideTransition(
              position: _textSlideAnimation,
              child: widget.actionWidget!,
            ),
          ),
        ],
      ],
    );
  }
}


