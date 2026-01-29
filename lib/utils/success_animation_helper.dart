import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

/// Success animation types
enum SuccessType {
  /// Simple checkmark animation (default)
  checkmark,
  
  /// Checkmark with ripple effect
  ripple,
}

/// Helper class for showing success animations
class SuccessAnimationHelper {
  /// Show a success animation overlay
  /// 
  /// [context] - BuildContext to show overlay
  /// [type] - Type of success animation (default: checkmark)
  /// [message] - Optional message to show after animation
  /// [showSnackBar] - Whether to show snackbar after animation (default: true)
  /// [duration] - Duration before auto-dismiss (default: 1500ms)
  /// [onComplete] - Callback when animation completes
  static Future<void> showSuccess({
    required BuildContext context,
    SuccessType type = SuccessType.checkmark,
    String? message,
    bool showSnackBar = true,
    Duration? duration,
    VoidCallback? onComplete,
  }) async {
    // Haptic feedback
    HapticFeedback.heavyImpact();
    
    // Show animation overlay
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      barrierDismissible: false,
      builder: (dialogContext) => _SuccessAnimationOverlay(
        type: type,
        duration: duration ?? const Duration(milliseconds: 1500),
        onComplete: () {
          Navigator.of(dialogContext).pop();
          if (showSnackBar && message != null) {
            _showSuccessSnackBar(context, message);
          }
          onComplete?.call();
        },
      ),
    );
  }

  /// Show success snackbar
  static void showSuccessSnackBar(BuildContext context, String message) {
    _showSuccessSnackBar(context, message);
  }

  /// Internal method to show success snackbar
  static void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        elevation: 8,
      ),
    );
    HapticFeedback.lightImpact();
  }
}

/// Success animation overlay widget
class _SuccessAnimationOverlay extends StatefulWidget {
  final SuccessType type;
  final Duration duration;
  final VoidCallback onComplete;

  const _SuccessAnimationOverlay({
    required this.type,
    required this.duration,
    required this.onComplete,
  });

  @override
  State<_SuccessAnimationOverlay> createState() => _SuccessAnimationOverlayState();
}

class _SuccessAnimationOverlayState extends State<_SuccessAnimationOverlay>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController? _rippleController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;
  late Animation<double> _fadeAnimation;
  Animation<double>? _rippleAnimation;
  Animation<double>? _rippleOpacityAnimation;

  @override
  void initState() {
    super.initState();
    
    // Main animation controller
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Ripple controller (if needed)
    if (widget.type == SuccessType.ripple) {
      _rippleController = AnimationController(
        duration: const Duration(milliseconds: 800),
        vsync: this,
      )..repeat();
    }

    // Scale animation (elastic bounce)
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

    // Ripple animation
    if (widget.type == SuccessType.ripple && _rippleController != null) {
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

    // Start animations
    _mainController.forward();
    
    // Auto-dismiss after duration
    Future.delayed(widget.duration, () {
      if (mounted) {
        _mainController.reverse().then((_) {
          widget.onComplete();
        });
      }
    });
  }

  @override
  void dispose() {
    _mainController.dispose();
    _rippleController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Main success animation
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Ripple effect (if enabled)
                  if (widget.type == SuccessType.ripple &&
                      _rippleController != null &&
                      _rippleAnimation != null &&
                      _rippleOpacityAnimation != null)
                    AnimatedBuilder(
                      animation: _rippleController!,
                      builder: (context, child) {
                        return Container(
                          width: 200 * _rippleAnimation!.value,
                          height: 200 * _rippleAnimation!.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.success.withOpacity(_rippleOpacityAnimation!.value),
                              width: 3,
                            ),
                          ),
                        );
                      },
                    ),
                  
                  // Main checkmark circle
                  Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: 140,
                      height: 140,
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
                        painter: _EnhancedCheckmarkPainter(
                          progress: _checkAnimation.value,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Enhanced checkmark painter with smoother animation
class _EnhancedCheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;

  _EnhancedCheckmarkPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 10
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
  bool shouldRepaint(_EnhancedCheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
