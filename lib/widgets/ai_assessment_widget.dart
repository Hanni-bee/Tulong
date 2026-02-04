import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../models/emergency_type.dart';
import '../models/emergency_detection_result.dart';
import '../services/disaster_classification_service.dart';

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

    final severityColor = _getSeverityColor(result.severity);
    final typeColor = _getTypeColor(result.type);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 16,
        vertical: isSmallScreen ? 10 : 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.white,
            typeColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: typeColor.withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: typeColor.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // AI Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.purple.shade400,
                    Colors.blue.shade400,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.psychology,
                    color: AppColors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'AI DYNAMIC ASSESSMENT',
                    style: AppTypography.captionText.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.green.shade300,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: isSmallScreen ? 56 : (isLargeScreen ? 80 : 70),
                  height: isSmallScreen ? 56 : (isLargeScreen ? 80 : 70),
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        typeColor.withOpacity(0.3),
                        typeColor.withOpacity(0.1),
                        Colors.transparent,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                  child: Text(
                    result.type.emoji,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 28 : (isLargeScreen ? 40 : 36),
                    ),
                  ),
                  ),
                ),
                SizedBox(width: isSmallScreen ? 10 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        result.type.label.toUpperCase(),
                        style: AppTypography.titleLarge.copyWith(
                          color: AppColors.darkGray,
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 14 : (isLargeScreen ? 20 : 18),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: severityColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: severityColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.analytics,
                              size: 14,
                              color: severityColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${(result.confidence * 100).toStringAsFixed(1)}%',
                              style: AppTypography.bodySmall.copyWith(
                                color: severityColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        severityColor,
                        severityColor.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getSeverityIcon(result.severity),
                        color: AppColors.white,
                        size: 18,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        result.severity.label,
                        style: AppTypography.captionText.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Confidence progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Confidence Level',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.mediumGray,
                      ),
                    ),
                    Text(
                      '${(result.confidence * 100).toStringAsFixed(0)}%',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.darkGray,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Stack(
                  children: [
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.lightGray.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: result.confidence,
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              severityColor,
                              severityColor.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Risk assessment
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getRiskBackgroundColor(result.type).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getRiskBackgroundColor(result.type).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _getRiskIcon(result.type),
                    color: _getRiskBackgroundColor(result.type),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      assessment['riskMessage'] as String? ?? classificationService.getRiskAssessmentMessage(result.type, result.confidence),
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.mediumGray,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Probability breakdown if available
            if (assessment['probabilityBreakdown'] != null) ...[
              const SizedBox(height: 20),
              Text(
                'Classification Breakdown',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.darkGray,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ..._buildProbabilityBreakdown(
                assessment['probabilityBreakdown'] as Map<String, double>,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildProbabilityBreakdown(Map<String, double> breakdown) {
    if (breakdown.isEmpty) return [];

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
              ? barColor.withOpacity(0.1)
              : AppColors.lightGray.withOpacity(0.3),
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
                  color: isSelected ? AppColors.darkGray : AppColors.mediumGray,
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
                  backgroundColor: AppColors.lightGray.withOpacity(0.3),
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
                  color: isSelected ? barColor : AppColors.mediumGray,
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

  Color _getSeverityColor(SeverityLevel severity) {
    switch (severity) {
      case SeverityLevel.critical:
        return AppColors.error;
      case SeverityLevel.high:
        return AppColors.warning;
      case SeverityLevel.medium:
        return AppColors.info;
      case SeverityLevel.low:
        return AppColors.success;
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
