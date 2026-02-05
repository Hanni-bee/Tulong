import '../models/emergency_type.dart';
import '../models/emergency_detection_result.dart';

/// Utility to parse emergency detection messages from chat
class EmergencyMessageParser {
  /// Check if a message is an emergency detection message
  /// Aligned with PyImageSearch 4-class model: Cyclone, Earthquake, Flood, Wildfire
  static bool isEmergencyMessage(String message) {
    // Check for emergency message pattern (4-class model emojis only)
    return message.startsWith('Emergency:') ||
        message.contains('🌀') || // Cyclone
        message.contains('🌋') || // Cyclone (alternative)
        message.contains('🌍') || // Earthquake
        message.contains('🌧️') || // Flood
        message.contains('🔥');    // Wildfire
  }

  /// Parse emergency detection from message text
  /// Format: "Emergency: {emoji} {type} - {severity} Severity"
  /// Handles edge cases: multiple emojis, invalid severity text
  static EmergencyDetectionResult? parseFromMessage(String message) {
    if (!isEmergencyMessage(message)) {
      return null;
    }

    try {
      // Pattern: "Emergency: {emoji} {type} - {severity} Severity"
      // Example: "Emergency: 🔥 Fire - High Severity"
      
      EmergencyType? emergencyType;
      SeverityLevel? severity;
      
      // Aligned with PyImageSearch 4-class model: Cyclone, Earthquake, Flood, Wildfire
      // Only supports the 4 disaster types that the ML model can classify
      final emojiMatches = <String, EmergencyType>{
        '🔥': EmergencyType.fire,        // Wildfire (Index 3)
        '🌧️': EmergencyType.flood,      // Flood (Index 2)
        '🌍': EmergencyType.earthquake,  // Earthquake (Index 1)
        '🌀': EmergencyType.cyclone,     // Cyclone (Index 0)
        '🌋': EmergencyType.cyclone,     // Alternative cyclone emoji
      };
      
      // Find all matching emojis and select by priority
      EmergencyType? matchedType;
      int highestPriority = -1;
      
      for (final entry in emojiMatches.entries) {
        if (message.contains(entry.key)) {
          // Calculate priority (lower index = higher priority)
          final priority = emojiMatches.keys.toList().indexOf(entry.key);
          if (priority < highestPriority || highestPriority == -1) {
            highestPriority = priority;
            matchedType = entry.value;
          }
        }
      }
      
      // If no emoji found but message starts with "Emergency:", try to extract from text
      // Aligned with PyImageSearch 4-class model labels only
      if (matchedType == null && message.startsWith('Emergency:')) {
        // Try to match emergency type from text label (4-class model only)
        final typeLabels = {
          'wildfire': EmergencyType.fire,    // Wildfire -> Fire (Index 3)
          'fire': EmergencyType.fire,        // Fire (Index 3)
          'flood': EmergencyType.flood,      // Flood (Index 2)
          'earthquake': EmergencyType.earthquake, // Earthquake (Index 1)
          'cyclone': EmergencyType.cyclone, // Cyclone (Index 0)
          'hurricane': EmergencyType.cyclone, // Hurricane -> Cyclone
        };
        
        final lowerMessage = message.toLowerCase();
        for (final entry in typeLabels.entries) {
          if (lowerMessage.contains(entry.key)) {
            matchedType = entry.value;
            break;
          }
        }
      }
      
      emergencyType = matchedType;
      
      // IMPROVED: Extract severity with better regex and validation
      // Support multiple formats: "High Severity", "High", "high", etc.
      SeverityLevel? parsedSeverity;
      
      // Try strict format first: " - {severity} Severity"
      var severityMatch = RegExp(r'-\s*(\w+)\s+Severity', caseSensitive: false)
          .firstMatch(message);
      
      if (severityMatch == null) {
        // Try relaxed format: " - {severity}"
        severityMatch = RegExp(r'-\s*(\w+)(?:\s|$)', caseSensitive: false)
            .firstMatch(message);
      }
      
      if (severityMatch == null) {
        // Try finding severity anywhere in message
        final severityKeywords = {
          'critical': SeverityLevel.critical,
          'high': SeverityLevel.high,
          'medium': SeverityLevel.medium,
          'low': SeverityLevel.low,
        };
        
        final lowerMessage = message.toLowerCase();
        for (final entry in severityKeywords.entries) {
          if (lowerMessage.contains(entry.key)) {
            parsedSeverity = entry.value;
            break;
          }
        }
      } else {
        final severityText = severityMatch.group(1)?.toLowerCase() ?? '';
        parsedSeverity = SeverityLevel.fromString(severityText);
      }
      
      severity = parsedSeverity;
      
      // Default values if parsing fails
      // Aligned with ML model: default to "No Emergency" if not one of the 4 disaster types
      emergencyType ??= EmergencyType.noEmergency;
      severity ??= SeverityLevel.low;
      
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

