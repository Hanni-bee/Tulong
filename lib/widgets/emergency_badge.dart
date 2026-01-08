import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_colors.dart';
import '../models/emergency_type.dart';
import '../models/emergency_detection_result.dart';

/// Elite Badge widget for displaying emergency detection results with glassmorphism and animations.
class EmergencyBadge extends StatelessWidget {
  final EmergencyDetectionResult result;
  final bool showPulseAnimation;

  const EmergencyBadge({
    super.key,
    required this.result,
    this.showPulseAnimation = true,
  });

  Color _getTypeColor() {
    switch (result.type) {
      case EmergencyType.fire:
        return AppColors.primaryRed;
      case EmergencyType.flood:
        return AppColors.info;
      case EmergencyType.earthquake:
        return const Color(0xFF8B4513); // Brown for earthquake
      case EmergencyType.accident:
        return AppColors.warning;
      case EmergencyType.calamity:
        return AppColors.purple;
      case EmergencyType.general:
        return AppColors.mediumGray;
      case EmergencyType.noEmergency:
        return AppColors.success;
    }
  }

  Color _getSeverityColor() {
    switch (result.severity) {
      case SeverityLevel.critical:
        return AppColors.error;
      case SeverityLevel.high:
        return Colors.orangeAccent;
      case SeverityLevel.medium:
        return AppColors.warning;
      case SeverityLevel.low:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _getTypeColor();
    final severityColor = _getSeverityColor();
    final isCritical = result.severity == SeverityLevel.critical || result.severity == SeverityLevel.high;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: typeColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: typeColor.withOpacity(0.4),
          width: isCritical ? 2.0 : 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            result.type.emoji,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                result.type.label.toUpperCase(),
                style: TextStyle(
                  color: typeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: severityColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${result.severity.label} • ${result.getConfidenceString()}',
                    style: TextStyle(
                      color: AppColors.textPrimary.withOpacity(0.7),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    )
    .animate(target: (showPulseAnimation && isCritical) ? 1 : 0, onPlay: (c) => c.repeat(reverse: true))
    .shimmer(duration: 2.seconds, color: Colors.white.withOpacity(0.2))
    .scale(begin: const Offset(1, 1), end: const Offset(1.04, 1.04), duration: 1200.ms, curve: Curves.easeInOut);
  }
}
