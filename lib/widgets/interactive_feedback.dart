import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

/// Success animation overlay (Improved version)
class SuccessAnimation extends StatefulWidget {
  final VoidCallback? onComplete;
  final double size;
  final bool showRipple;

  const SuccessAnimation({
    super.key,
    this.onComplete,
    this.size = 140,
    this.showRipple = false,
  });

  @override
  State<SuccessAnimation> createState() => _SuccessAnimationState();
}

class _SuccessAnimationState extends State<SuccessAnimation>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController? _rippleController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double>? _rippleAnimation;
  late Animation<double>? _rippleOpacityAnimation;

  @override
  void initState() {
    super.initState();
    
    // Main animation controller
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Ripple controller (if enabled)
    if (widget.showRipple) {
      _rippleController = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      )..repeat();
    }

    // Enhanced scale animation with better bounce
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.95), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _mainController,
      curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
    ));

    // Checkmark animation
    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );

    // Fade out animation
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.75, 1.0, curve: Curves.easeIn),
      ),
    );

    // Ripple animation (if enabled)
    if (widget.showRipple && _rippleController != null) {
      _rippleAnimation = Tween<double>(begin: 0.0, end: 1.5).animate(
        CurvedAnimation(
          parent: _rippleController!,
          curve: Curves.easeOut,
        ),
      );
      
      _rippleOpacityAnimation = Tween<double>(begin: 0.6, end: 0.0).animate(
        CurvedAnimation(
          parent: _rippleController!,
          curve: Curves.easeOut,
        ),
      );
    }

    _mainController.forward();
    _mainController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });

    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _mainController.dispose();
    _rippleController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _mainController,
        if (_rippleController != null) _rippleController!,
      ]),
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Ripple effect (if enabled)
                if (widget.showRipple && _rippleAnimation != null && _rippleOpacityAnimation != null)
                  Container(
                    width: widget.size * 2 * _rippleAnimation!.value,
                    height: widget.size * 2 * _rippleAnimation!.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.success.withOpacity(_rippleOpacityAnimation!.value),
                        width: 3,
                      ),
                    ),
                  ),
                
                // Main checkmark circle
                Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      boxShadow: [
                        // Enhanced shadow for depth
                        BoxShadow(
                          color: AppColors.success.withOpacity(0.4),
                          blurRadius: 30,
                          spreadRadius: 8,
                          offset: const Offset(0, 8),
                        ),
                        // Inner highlight
                        BoxShadow(
                          color: Colors.white.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(-3, -3),
                        ),
                        // Outer glow
                        BoxShadow(
                          color: AppColors.success.withOpacity(0.2),
                          blurRadius: 50,
                          spreadRadius: 15,
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      painter: CheckmarkPainter(
                        progress: _checkAnimation.value,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Error shake animation
class ErrorShake extends StatefulWidget {
  final Widget child;

  const ErrorShake({super.key, required this.child});

  @override
  State<ErrorShake> createState() => _ErrorShakeState();
}

class _ErrorShakeState extends State<ErrorShake>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.forward();
    HapticFeedback.vibrate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: widget.child,
        );
      },
    );
  }
}

/// Loading pulse animation
class PulseLoading extends StatefulWidget {
  final double size;
  final Color color;

  const PulseLoading({
    super.key,
    this.size = 60,
    this.color = AppColors.primaryRed,
  });

  @override
  State<PulseLoading> createState() => _PulseLoadingState();
}

class _PulseLoadingState extends State<PulseLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.6, end: 0.2).animate(
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withOpacity(_opacityAnimation.value),
                ),
              ),
            ),
            Container(
              width: widget.size * 0.6,
              height: widget.size * 0.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Confetti celebration
class ConfettiAnimation extends StatefulWidget {
  final VoidCallback? onComplete;

  const ConfettiAnimation({super.key, this.onComplete});

  @override
  State<ConfettiAnimation> createState() => _ConfettiAnimationState();
}

class _ConfettiAnimationState extends State<ConfettiAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<ConfettiParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Generate particles
    for (int i = 0; i < 30; i++) {
      _particles.add(ConfettiParticle());
    }

    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });

    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: _particles.map((particle) {
            final progress = _controller.value;
            final x = particle.startX + (particle.velocityX * progress);
            final y = particle.startY + (particle.velocityY * progress) +
                (progress * progress * 500); // Gravity

            return Positioned(
              left: x * size.width,
              top: y * size.height,
              child: Transform.rotate(
                angle: progress * particle.rotation,
                child: Opacity(
                  opacity: 1.0 - progress,
                  child: Container(
                    width: particle.size,
                    height: particle.size,
                    decoration: BoxDecoration(
                      color: particle.color,
                      shape: BoxShape.rectangle,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

/// Checkmark painter (Improved with smoother stroke)
class CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;

  CheckmarkPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.08 // Responsive stroke width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final checkWidth = size.width * 0.55;
    final checkHeight = size.height * 0.55;
    final offsetX = (size.width - checkWidth) / 2;
    final offsetY = (size.height - checkHeight) / 2;

    // Smooth checkmark path
    path.moveTo(offsetX, offsetY + checkHeight * 0.5);
    path.lineTo(offsetX + checkWidth * 0.4, offsetY + checkHeight * 0.8);
    path.lineTo(offsetX + checkWidth, offsetY + checkHeight * 0.2);

    final pathMetric = path.computeMetrics().first;
    final extractPath = pathMetric.extractPath(
      0.0,
      pathMetric.length * progress,
    );

    canvas.drawPath(extractPath, paint);
  }

  @override
  bool shouldRepaint(CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Confetti particle model
class ConfettiParticle {
  final double startX;
  final double startY;
  final double velocityX;
  final double velocityY;
  final double rotation;
  final double size;
  final Color color;

  ConfettiParticle()
      : startX = 0.5 + (0.2 - 0.4 * (DateTime.now().millisecond / 1000)),
        startY = 0.3,
        velocityX = -0.5 + (DateTime.now().microsecond / 1000000),
        velocityY = -1.0 - (DateTime.now().microsecond / 500000),
        rotation = DateTime.now().microsecond / 100000,
        size = 8 + (DateTime.now().microsecond % 8),
        color = [
          AppColors.primaryRed,
          AppColors.success,
          AppColors.warning,
          AppColors.info,
          Colors.purple,
        ][DateTime.now().millisecond % 5];
}

/// Ripple effect widget
class RippleEffect extends StatefulWidget {
  final Widget child;
  final Color rippleColor;

  const RippleEffect({
    super.key,
    required this.child,
    this.rippleColor = AppColors.primaryRed,
  });

  @override
  State<RippleEffect> createState() => _RippleEffectState();
}

class _RippleEffectState extends State<RippleEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _radiusAnimation;
  late Animation<double> _opacityAnimation;

  Offset? _tapPosition;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _radiusAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.6, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap(TapDownDetails details) {
    setState(() {
      _tapPosition = details.localPosition;
    });
    _controller.forward(from: 0);
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTap,
      child: Stack(
        children: [
          widget.child,
          if (_tapPosition != null)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    painter: RipplePainter(
                      position: _tapPosition!,
                      radius: _radiusAnimation.value,
                      opacity: _opacityAnimation.value,
                      color: widget.rippleColor,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Ripple painter
class RipplePainter extends CustomPainter {
  final Offset position;
  final double radius;
  final double opacity;
  final Color color;

  RipplePainter({
    required this.position,
    required this.radius,
    required this.opacity,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.fill;

    final maxRadius = size.width > size.height ? size.width : size.height;
    canvas.drawCircle(position, maxRadius * radius, paint);
  }

  @override
  bool shouldRepaint(RipplePainter oldDelegate) {
    return oldDelegate.radius != radius || oldDelegate.opacity != opacity;
  }
}

