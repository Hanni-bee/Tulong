import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
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

  /// Get badge color based on emergency type and severity
  Color _getBadgeColor() {
    final severity = widget.result.severity;
    
    // Base color by emergency type
    Color baseColor;
    switch (widget.result.type) {
      case EmergencyType.fire:
        baseColor = AppColors.primaryRed;
        break;
      case EmergencyType.flood:
        baseColor = AppColors.info;
        break;
      case EmergencyType.earthquake:
        baseColor = const Color(0xFF8B4513); // Brown
        break;
      case EmergencyType.accident:
        baseColor = AppColors.warning;
        break;
      case EmergencyType.calamity:
        baseColor = AppColors.purple;
        break;
      case EmergencyType.general:
        baseColor = AppColors.mediumGray;
        break;
      case EmergencyType.noEmergency:
        baseColor = AppColors.online; // Green for no emergency
        break;
    }
    
    // Adjust brightness based on severity
    switch (severity) {
      case SeverityLevel.low:
        return baseColor.withOpacity(0.7);
      case SeverityLevel.medium:
        return baseColor;
      case SeverityLevel.high:
        return baseColor;
      case SeverityLevel.critical:
        return baseColor;
    }
  }

  /// Get border color based on severity
  Color _getBorderColor() {
    switch (widget.result.severity) {
      case SeverityLevel.low:
        return Colors.green.withOpacity(0.5);
      case SeverityLevel.medium:
        return Colors.yellow.withOpacity(0.5);
      case SeverityLevel.high:
        return Colors.orange.withOpacity(0.7);
      case SeverityLevel.critical:
        return Colors.red.withOpacity(0.9);
    }
  }

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
          Text(
            widget.result.type.emoji,
            style: const TextStyle(fontSize: 16),
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



