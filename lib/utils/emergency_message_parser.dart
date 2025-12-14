import '../models/emergency_type.dart';
import '../models/emergency_detection_result.dart';

/// Utility to parse emergency detection messages from chat
class EmergencyMessageParser {
  /// Check if a message is an emergency detection message
  static bool isEmergencyMessage(String message) {
    // Check for emergency message pattern
    return message.startsWith('Emergency:') ||
        message.contains('🌋') ||
        message.contains('🌍') ||
        message.contains('🌧️') ||
        message.contains('🔥') ||
        message.contains('🚑') ||
        message.contains('⚠️');
  }

  /// Parse emergency detection from message text
  /// Format: "Emergency: {emoji} {type} - {severity} Severity"
  static EmergencyDetectionResult? parseFromMessage(String message) {
    if (!isEmergencyMessage(message)) {
      return null;
    }

    try {
      // Pattern: "Emergency: {emoji} {type} - {severity} Severity"
      // Example: "Emergency: 🔥 Fire - High Severity"
      
      // Extract emoji and match to emergency type
      EmergencyType? emergencyType;
      SeverityLevel? severity;
      
      // Try to match by emoji
      if (message.contains('🌋')) {
        emergencyType = EmergencyType.calamity;
      } else if (message.contains('🌍')) {
        emergencyType = EmergencyType.earthquake;
      } else if (message.contains('🌧️')) {
        emergencyType = EmergencyType.flood;
      } else if (message.contains('🔥')) {
        emergencyType = EmergencyType.fire;
      } else if (message.contains('🚑')) {
        emergencyType = EmergencyType.accident;
      } else if (message.contains('⚠️')) {
        emergencyType = EmergencyType.general;
      }
      
      // Extract severity from message
      final severityMatch = RegExp(r'-\s*(\w+)\s*Severity', caseSensitive: false)
          .firstMatch(message);
      if (severityMatch != null) {
        final severityText = severityMatch.group(1)?.toLowerCase() ?? '';
        severity = SeverityLevel.fromString(severityText);
      }
      
      // Default values if parsing fails
      emergencyType ??= EmergencyType.general;
      severity ??= SeverityLevel.medium;
      
      return EmergencyDetectionResult(
        type: emergencyType,
        severity: severity,
        confidence: 0.7, // Default confidence for parsed messages
        timestamp: DateTime.now(),
      );
    } catch (e) {
      // If parsing fails, return null
      return null;
    }
  }

  /// Extract emergency metadata from message data map
  static EmergencyDetectionResult? parseFromMessageData(Map<String, dynamic> messageData) {
    // First check if emergency_detection metadata exists
    if (messageData.containsKey('emergency_detection')) {
      try {
        final emergencyData = messageData['emergency_detection'] as Map<String, dynamic>;
        return EmergencyDetectionResult.fromJson(emergencyData);
      } catch (e) {
        // Fall through to text parsing
      }
    }
    
    // Fallback to parsing from message text
    final message = messageData['message'] as String? ?? '';
    return parseFromMessage(message);
  }
}

