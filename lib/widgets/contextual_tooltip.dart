import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import 'dart:async';

/// Contextual Tooltip Widget
/// 
/// Displays tooltips for new features with:
/// - Skip option
/// - "Show again" functionality
/// - Progressive disclosure
/// - Feature highlights
class ContextualTooltip extends StatefulWidget {
  final String tooltipId;
  final String title;
  final String description;
  final Widget target;
  final Offset? targetOffset;
  final TooltipPosition position;
  final VoidCallback? onDismiss;
  final VoidCallback? onComplete;
  final bool showSkip;
  final String? featureId; // For tracking which features have been shown

  const ContextualTooltip({
    super.key,
    required this.tooltipId,
    required this.title,
    required this.description,
    required this.target,
    this.targetOffset,
    this.position = TooltipPosition.bottom,
    this.onDismiss,
    this.onComplete,
    this.showSkip = true,
    this.featureId,
  });

  @override
  State<ContextualTooltip> createState() => _ContextualTooltipState();
}

class _ContextualTooltipState extends State<ContextualTooltip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
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

    _slideAnimation = Tween<Offset>(
      begin: widget.position == TooltipPosition.bottom
          ? const Offset(0, -0.1)
          : widget.position == TooltipPosition.top
              ? const Offset(0, 0.1)
              : widget.position == TooltipPosition.right
                  ? const Offset(-0.1, 0)
                  : const Offset(0.1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward();
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss({bool skip = false}) async {
    if (!_isVisible) return;

    setState(() => _isVisible = false);
    await _controller.reverse();
    
    if (skip) {
      await TooltipPreferences.setSkipped(widget.tooltipId);
      widget.onDismiss?.call();
    } else {
      await TooltipPreferences.setCompleted(widget.tooltipId);
      widget.onComplete?.call();
    }
    
    if (mounted) {
      widget.onDismiss?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return widget.target;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.target,
        Positioned.fill(
          child: GestureDetector(
            onTap: () => _dismiss(),
            child: Container(
              color: Colors.black54,
            ),
          ),
        ),
        _buildTooltip(),
      ],
    );
  }

  Widget _buildTooltip() {
    final screenSize = MediaQuery.of(context).size;
    final padding = 16.0;
    
    // Calculate position based on tooltip position preference
    double left = padding;
    double top = padding;
    double? right;
    double? bottom;
    
    switch (widget.position) {
      case TooltipPosition.top:
        bottom = screenSize.height * 0.6;
        left = screenSize.width * 0.5 - 150;
        break;
      case TooltipPosition.bottom:
        top = screenSize.height * 0.4;
        left = screenSize.width * 0.5 - 150;
        break;
      case TooltipPosition.left:
        right = screenSize.width * 0.5 + 20;
        top = screenSize.height * 0.4;
        break;
      case TooltipPosition.right:
        left = screenSize.width * 0.5 + 20;
        top = screenSize.height * 0.4;
        break;
      case TooltipPosition.center:
        left = screenSize.width * 0.5 - 150;
        top = screenSize.height * 0.4;
        break;
    }

    return Positioned(
      left: widget.position == TooltipPosition.right || widget.position == TooltipPosition.center || widget.position == TooltipPosition.bottom || widget.position == TooltipPosition.top ? left : null,
      top: top,
      right: right,
      bottom: bottom,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 300),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.lightbulb_outline,
                          color: AppColors.primaryRed,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.darkGray,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.description,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.mediumGray,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => _dismiss(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (widget.showSkip)
                        TextButton(
                          onPressed: () => _dismiss(skip: true),
                          child: const Text(
                            "Don't show again",
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
                          backgroundColor: AppColors.primaryRed,
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
      ),
    );
  }
}

enum TooltipPosition {
  top,
  bottom,
  left,
  right,
  center,
}

/// Tooltip Preferences Manager
class TooltipPreferences {
  static const String _skippedPrefix = 'tooltip_skipped_';
  static const String _completedPrefix = 'tooltip_completed_';

  /// Check if tooltip should be shown
  static Future<bool> shouldShowTooltip(String tooltipId) async {
    final prefs = await SharedPreferences.getInstance();
    final skipped = prefs.getBool('$_skippedPrefix$tooltipId') ?? false;
    final completed = prefs.getBool('$_completedPrefix$tooltipId') ?? false;
    return !skipped && !completed;
  }

  /// Mark tooltip as skipped
  static Future<void> setSkipped(String tooltipId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_skippedPrefix$tooltipId', true);
  }

  /// Mark tooltip as completed
  static Future<void> setCompleted(String tooltipId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_completedPrefix$tooltipId', true);
  }

  /// Reset tooltip (show again)
  static Future<void> resetTooltip(String tooltipId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_skippedPrefix$tooltipId');
    await prefs.remove('$_completedPrefix$tooltipId');
  }

  /// Reset all tooltips
  static Future<void> resetAllTooltips() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) =>
        key.startsWith(_skippedPrefix) || key.startsWith(_completedPrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}

