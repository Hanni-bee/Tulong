import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';

/// Feature Highlight Widget
/// 
/// Highlights new features with:
/// - Spotlight effect (dark overlay with highlighted area)
/// - Feature description
/// - "Got it" button
/// - "Show again" option
class FeatureHighlight extends StatefulWidget {
  final String featureId;
  final String title;
  final String description;
  final Widget target;
  final GlobalKey? targetKey;
  final EdgeInsets? padding;
  final VoidCallback? onComplete;
  final Color? highlightColor;
  final bool enableHaptic;

  const FeatureHighlight({
    super.key,
    required this.featureId,
    required this.title,
    required this.description,
    required this.target,
    this.targetKey,
    this.padding,
    this.onComplete,
    this.highlightColor,
    this.enableHaptic = true,
  });

  @override
  State<FeatureHighlight> createState() => _FeatureHighlightState();

  /// Check if feature highlight should be shown
  static Future<bool> shouldShowFeatureHighlight(String featureId) async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('feature_highlight_$featureId') ?? false);
  }

  /// Mark feature highlight as shown
  static Future<void> markFeatureHighlightShown(String featureId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('feature_highlight_$featureId', true);
  }

  /// Reset feature highlight (show again)
  static Future<void> resetFeatureHighlight(String featureId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('feature_highlight_$featureId');
  }
}

class _FeatureHighlightState extends State<FeatureHighlight>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();
    if (widget.enableHaptic) {
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss({bool showAgain = false}) async {
    if (!_isVisible) return;

    setState(() => _isVisible = false);
    await _controller.reverse();

    if (!showAgain) {
      await FeatureHighlight.markFeatureHighlightShown(widget.featureId);
    }

    widget.onComplete?.call();
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return widget.target;

    return Stack(
      children: [
        widget.target,
        _buildOverlay(),
      ],
    );
  }

  Widget _buildOverlay() {
    final renderBox = widget.targetKey?.currentContext?.findRenderObject() as RenderBox?;
    final targetOffset = renderBox?.localToGlobal(Offset.zero);
    final targetSize = renderBox?.size;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onTap: () => _dismiss(),
        child: Container(
          color: Colors.black87,
          child: CustomPaint(
            painter: SpotlightPainter(
              targetOffset: targetOffset,
              targetSize: targetSize,
              highlightColor: widget.highlightColor ?? AppColors.primaryRed,
            ),
            child: Stack(
              children: [
                if (targetOffset != null && targetSize != null)
                  Positioned(
                    left: targetOffset.dx,
                    top: targetOffset.dy + targetSize.height + 16,
                    right: 16,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: (widget.highlightColor ?? AppColors.primaryRed)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.star_outline,
                                    color: widget.highlightColor ?? AppColors.primaryRed,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    widget.title,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.darkGray,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.description,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.mediumGray,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => _dismiss(showAgain: true),
                                  child: const Text(
                                    'Show again later',
                                    style: TextStyle(
                                      color: AppColors.mediumGray,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => _dismiss(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: widget.highlightColor ?? AppColors.primaryRed,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Got it'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SpotlightPainter extends CustomPainter {
  final Offset? targetOffset;
  final Size? targetSize;
  final Color highlightColor;

  SpotlightPainter({
    required this.targetOffset,
    required this.targetSize,
    required this.highlightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (targetOffset == null || targetSize == null) return;

    final paint = Paint()
      ..color = Colors.black87
      ..blendMode = BlendMode.srcOut;

    // Draw overlay
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.black87,
    );

    // Draw spotlight (cutout)
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        targetOffset!.dx - 8,
        targetOffset!.dy - 8,
        targetSize!.width + 16,
        targetSize!.height + 16,
      ),
      const Radius.circular(12),
    );

    canvas.drawRRect(rect, paint);

    // Draw glow effect
    final glowPaint = Paint()
      ..color = highlightColor.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    
    canvas.drawRRect(rect, glowPaint);
  }

  @override
  bool shouldRepaint(SpotlightPainter oldDelegate) {
    return oldDelegate.targetOffset != targetOffset ||
           oldDelegate.targetSize != targetSize;
  }
}

