import 'package:flutter/material.dart';

/// Emergency types that can be detected by AI/ML
enum EmergencyType {
  calamity('Calamity', '🌋'),
  earthquake('Earthquake', '🌍'),
  flood('Flood', '🌧️'),
  fire('Fire', '🔥'),
  accident('Accident', '🚑'),
  general('General Emergency', '⚠️'),
  noEmergency('No Emergency', '✅'); // Positive result - no emergency detected

  const EmergencyType(this.label, this.emoji);
  
  final String label;
  final String emoji;

  /// Professional icon for UI (replaces emoji in modals and cards)
  IconData get icon {
    switch (this) {
      case EmergencyType.calamity:
        return Icons.warning_amber_rounded;
      case EmergencyType.earthquake:
        return Icons.terrain_rounded;
      case EmergencyType.flood:
        return Icons.water_drop_rounded;
      case EmergencyType.fire:
        return Icons.local_fire_department_rounded;
      case EmergencyType.accident:
        return Icons.emergency_rounded;
      case EmergencyType.general:
        return Icons.warning_rounded;
      case EmergencyType.noEmergency:
        return Icons.check_circle_rounded;
    }
  }
  
  /// Get emergency type from string
  static EmergencyType fromString(String value) {
    return EmergencyType.values.firstWhere(
      (type) => type.name == value.toLowerCase(),
      orElse: () => EmergencyType.noEmergency, // Default to "No Emergency" instead of "General Emergency"
    );
  }
  
  /// Check if this is a real emergency (not "no emergency")
  bool get isRealEmergency => this != EmergencyType.noEmergency;
}

/// Severity levels for emergency situations
enum SeverityLevel {
  low('Low', 1),
  medium('Medium', 2),
  high('High', 3),
  critical('Critical', 4);

  const SeverityLevel(this.label, this.value);
  
  final String label;
  final int value;
  
  /// Get severity level from string
  static SeverityLevel fromString(String value) {
    return SeverityLevel.values.firstWhere(
      (level) => level.name == value.toLowerCase(),
      orElse: () => SeverityLevel.medium,
    );
  }
  
  /// Get severity level from numeric value
  static SeverityLevel fromValue(int value) {
    return SeverityLevel.values.firstWhere(
      (level) => level.value == value,
      orElse: () => SeverityLevel.medium,
    );
  }
}

