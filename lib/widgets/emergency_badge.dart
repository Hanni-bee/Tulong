import 'package:flutter/material.dart';
import '../constants/severity_colors.dart';
import '../models/emergency_type.dart';
import '../models/emergency_detection_result.dart';

/// Badge widget for displaying emergency detection results in chat
class EmergencyBadge extends StatefulWidget {
  final EmergencyDetectionResult result;
  final bool showPulseAnimation;
  final double? size;

  const EmergencyBadge({
    super.key,
    required this.result,
    this.showPulseAnimation = false,
    this.size,
  });

  @override
  State<EmergencyBadge> createState() => _EmergencyBadgeState();
}

class _EmergencyBadgeState extends State<EmergencyBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.showPulseAnimation) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1000),
      );
      _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
        CurvedAnimation(
          parent: _pulseController,
          curve: Curves.easeInOut,
        ),
      );
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    if (widget.showPulseAnimation) {
      _pulseController.dispose();
    }
    super.dispose();
  }

  /// Get badge color from app-wide severity palette
  Color _getBadgeColor() => SeverityColors.color(widget.result.severity);

  /// Get border color from app-wide severity palette
  Color _getBorderColor() => SeverityColors.border(widget.result.severity);

  @override
  Widget build(BuildContext context) {
    final badgeColor = _getBadgeColor();
    final borderColor = _getBorderColor();
    final shouldPulse = widget.showPulseAnimation &&
        (widget.result.severity == SeverityLevel.high ||
            widget.result.severity == SeverityLevel.critical);

    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: widget.result.severity == SeverityLevel.critical ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.result.type.icon,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            widget.result.getBadgeText(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );

    if (shouldPulse) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: badge,
          );
        },
      );
    }

    return badge;
  }
}


