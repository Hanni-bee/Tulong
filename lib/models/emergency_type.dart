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
  
  /// Get emergency type from string
  static EmergencyType fromString(String value) {
    return EmergencyType.values.firstWhere(
      (type) => type.name == value.toLowerCase(),
      orElse: () => EmergencyType.general,
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

