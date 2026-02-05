import '../models/emergency_type.dart';
import '../models/emergency_detection_result.dart';

/// Utility to parse emergency detection messages from chat
class EmergencyMessageParser {
  /// Check if a message is an emergency detection message (from app or copy-paste)
  static bool isEmergencyMessage(String message) {
    final upper = message.toUpperCase();
    // From Emergency Detection page: "FIRE DETECTED", "NO EMERGENCY DETECTED", etc.
    if (upper.contains(' DETECTED') && (upper.contains('EMERGENCY') || upper.contains('SEVERITY'))) return true;
    if (upper.startsWith('NO EMERGENCY DETECTED')) return true;
    // Legacy / copy-paste with emojis or "Emergency:"
    return message.startsWith('Emergency:') ||
        message.contains('🌋') || message.contains('🌍') || message.contains('🌧️') ||
        message.contains('🔥') || message.contains('🚑') || message.contains('⚠️');
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
      
      // IMPROVED: Handle multiple emojis with priority-based selection
      // Priority: Fire > Accident > Flood > Earthquake > Calamity > General
      // This ensures the most critical emergency is detected if multiple emojis exist
      final emojiMatches = <String, EmergencyType>{
        '🔥': EmergencyType.fire,        // Highest priority - immediate danger
        '🚑': EmergencyType.accident,    // High priority - medical emergency
        '🌧️': EmergencyType.flood,      // High priority - environmental
        '🌍': EmergencyType.earthquake,  // High priority - structural
        '🌋': EmergencyType.calamity,     // Medium priority - natural disaster
        '⚠️': EmergencyType.general,     // Lowest priority - general warning
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
      
      // If no emoji: try "X DETECTED" / "NO EMERGENCY DETECTED" (from Emergency Detection page)
      if (matchedType == null) {
        final upper = message.toUpperCase();
        if (upper.contains('NO EMERGENCY DETECTED')) {
          matchedType = EmergencyType.noEmergency;
        } else {
          final typeLabels = {
            'FIRE DETECTED': EmergencyType.fire,
            'FLOOD DETECTED': EmergencyType.flood,
            'EARTHQUAKE DETECTED': EmergencyType.earthquake,
            'ACCIDENT DETECTED': EmergencyType.accident,
            'CALAMITY DETECTED': EmergencyType.calamity,
            'GENERAL EMERGENCY DETECTED': EmergencyType.general,
          };
          for (final entry in typeLabels.entries) {
            if (upper.contains(entry.key)) {
              matchedType = entry.value;
              break;
            }
          }
        }
      }
      // Fallback: "Emergency:" or text labels (fire, flood, etc.)
      if (matchedType == null && message.startsWith('Emergency:')) {
        final typeLabels = {
          'fire': EmergencyType.fire,
          'flood': EmergencyType.flood,
          'earthquake': EmergencyType.earthquake,
          'accident': EmergencyType.accident,
          'calamity': EmergencyType.calamity,
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
      // Support: " - High Severity", "Severity: HIGH", "High", etc.
      SeverityLevel? parsedSeverity;
      
      // Format from Emergency Detection page: "Severity: HIGH"
      var severityMatch = RegExp(r'Severity:\s*(\w+)', caseSensitive: false)
          .firstMatch(message);
      if (severityMatch == null) {
        // Legacy: " - {severity} Severity"
        severityMatch = RegExp(r'-\s*(\w+)\s+Severity', caseSensitive: false)
            .firstMatch(message);
      }
      if (severityMatch == null) {
        // Relaxed: " - {severity}"
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

