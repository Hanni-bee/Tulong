import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../constants/severity_colors.dart';
import '../models/emergency_type.dart';
import '../models/emergency_detection_result.dart';
import '../services/disaster_classification_service.dart';
import '../utils/theme_colors.dart';

/// Widget for displaying AI-based disaster assessment results
class AIAssessmentWidget extends StatelessWidget {
  final EmergencyDetectionResult result;
  final Map<String, dynamic>? detailedAssessment;

  const AIAssessmentWidget({
    super.key,
    required this.result,
    this.detailedAssessment,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;
    final isLargeScreen = screenSize.width > 600;
    
    final classificationService = DisasterClassificationService.instance;
    final assessment = detailedAssessment ?? classificationService.getDetailedAssessment(
      result.type,
      result.confidence,
    );

    final severityColor = SeverityColors.color(result.severity);
    final typeColor = _getTypeColor(result.type);
    final isDark = ThemeColors.isDark(context);

    // Theme-adaptive background: surface container in dark, severity tint in light
    final cardBackground = isDark
        ? ThemeColors.surfaceContainerHigh(context)
        : SeverityColors.background(result.severity);
    final borderColor = SeverityColors.border(result.severity);
    final textPrimary = ThemeColors.textPrimary(context);
    final trackColor = ThemeColors.textTertiary(context).withOpacity(isDark ? 0.35 : 0.45);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 16,
        vertical: isSmallScreen ? 10 : 12,
      ),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
          width: isDark ? 1.5 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: ThemeColors.shadow(context, opacity: isDark ? 0.25 : 0.1),
            blurRadius: isDark ? 16 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Compact row: AI badge + icon + title + severity (fits small screens)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // AI badge - compact
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.psychology, color: AppColors.white, size: 12),
                      const SizedBox(width: 3),
                      Text(
                        'AI ASSESSMENT',
                        style: AppTypography.captionText.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: isSmallScreen ? 6 : 8),
                // Icon - smaller so row fits
                Container(
                  width: isSmallScreen ? 36 : 42,
                  height: isSmallScreen ? 36 : 42,
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: typeColor.withOpacity(0.5), width: 1.5),
                  ),
                  child: Icon(
                    result.type.icon,
                    size: isSmallScreen ? 20 : 24,
                    color: typeColor,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 6 : 8),
                // Title - scale down to fit
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      result.type.label.toUpperCase(),
                      style: AppTypography.titleLarge.copyWith(
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallScreen ? 12 : (isLargeScreen ? 16 : 14),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Severity pill - Flexible to avoid overflow, compact padding
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: severityColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: severityColor.withOpacity(0.35),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_getSeverityIcon(result.severity), color: AppColors.white, size: 12),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            result.severity.label,
                            style: AppTypography.captionText.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Confidence row - theme-aware label and track for readability
            Row(
              children: [
                Text(
                  'Confidence ',
                  style: AppTypography.bodyMedium.copyWith(
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: trackColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: result.confidence,
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: severityColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(result.confidence * 100).toStringAsFixed(0)}%',
                  style: AppTypography.bodyMedium.copyWith(
                    color: textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Risk message - theme-aware; accent border so it pops
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _getRiskBackgroundColor(result.type).withOpacity(isDark ? 0.2 : 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getRiskBackgroundColor(result.type).withOpacity(isDark ? 0.5 : 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _getRiskIcon(result.type),
                    color: _getRiskBackgroundColor(result.type),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      assessment['riskMessage'] as String? ?? classificationService.getRiskAssessmentMessage(result.type, result.confidence),
                      style: AppTypography.bodyMedium.copyWith(
                        color: textPrimary,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Probability breakdown if available - theme-aware
            if (assessment['probabilityBreakdown'] != null) ...[
              const SizedBox(height: 16),
              Text(
                'Classification Breakdown',
                style: AppTypography.bodyLarge.copyWith(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ..._buildProbabilityBreakdown(
                context,
                assessment['probabilityBreakdown'] as Map<String, double>,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildProbabilityBreakdown(BuildContext context, Map<String, double> breakdown) {
    if (breakdown.isEmpty) return [];
    final isDark = ThemeColors.isDark(context);
    final textPrimary = ThemeColors.textPrimary(context);
    final textSecondary = ThemeColors.textSecondary(context);
    final trackBg = ThemeColors.textTertiary(context).withOpacity(isDark ? 0.25 : 0.35);

    final sortedEntries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedEntries.map((entry) {
      final isSelected = _mapLabelToEmergencyType(entry.key) == result.type;
      final barColor = _getTypeColor(_mapLabelToEmergencyType(entry.key));

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? barColor.withOpacity(isDark ? 0.2 : 0.1)
              : trackBg,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(
                  color: barColor,
                  width: 2,
                )
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                entry.key,
                style: AppTypography.bodyMedium.copyWith(
                  color: isSelected ? textPrimary : textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: entry.value,
                  minHeight: 8,
                  backgroundColor: trackBg,
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 50,
              child: Text(
                '${(entry.value * 100).toStringAsFixed(1)}%',
                textAlign: TextAlign.right,
                style: AppTypography.bodySmall.copyWith(
                  color: isSelected ? barColor : textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  EmergencyType _mapLabelToEmergencyType(String label) {
    switch (label.toLowerCase()) {
      case 'flood':
        return EmergencyType.flood;
      case 'wildfire':
        return EmergencyType.fire;
      case 'earthquake':
        return EmergencyType.earthquake;
      case 'cyclone':
        return EmergencyType.calamity;
      default:
        return EmergencyType.general;
    }
  }

  Color _getTypeColor(EmergencyType type) {
    switch (type) {
      case EmergencyType.flood:
        return Colors.blue;
      case EmergencyType.fire:
        return Colors.red;
      case EmergencyType.earthquake:
        return Colors.brown;
      case EmergencyType.calamity:
        return Colors.orange;
      case EmergencyType.noEmergency:
        return AppColors.success;
      default:
        return AppColors.mediumGray;
    }
  }

  Color _getRiskBackgroundColor(EmergencyType type) {
    return _getTypeColor(type);
  }

  IconData _getRiskIcon(EmergencyType type) {
    switch (type) {
      case EmergencyType.flood:
        return Icons.water_drop;
      case EmergencyType.fire:
        return Icons.local_fire_department;
      case EmergencyType.earthquake:
        return Icons.warning;
      case EmergencyType.calamity:
        return Icons.storm;
      case EmergencyType.noEmergency:
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  IconData _getSeverityIcon(SeverityLevel severity) {
    switch (severity) {
      case SeverityLevel.critical:
        return Icons.dangerous;
      case SeverityLevel.high:
        return Icons.warning_amber_rounded;
      case SeverityLevel.medium:
        return Icons.info_outline;
      case SeverityLevel.low:
        return Icons.check_circle_outline;
    }
  }
}
