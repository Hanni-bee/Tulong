import 'emergency_type.dart';

/// Result of emergency detection from AI/ML processing
class EmergencyDetectionResult {
  final EmergencyType type;
  final SeverityLevel severity;
  final double confidence; // 0.0 to 1.0
  final DateTime timestamp;
  final String? imagePath; // Path to captured image (stays on device)
  
  EmergencyDetectionResult({
    required this.type,
    required this.severity,
    required this.confidence,
    required this.timestamp,
    this.imagePath,
  });
  
  /// Create from JSON (for ESP32/radio transmission)
  factory EmergencyDetectionResult.fromJson(Map<String, dynamic> json) {
    return EmergencyDetectionResult(
      type: EmergencyType.fromString(json['emergency_type'] as String? ?? 'general'),
      severity: SeverityLevel.fromString(json['severity'] as String? ?? 'medium'),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      imagePath: json['image_path'] as String?,
    );
  }
  
  /// Convert to JSON for ESP32/radio transmission (text only, no image)
  Map<String, dynamic> toJson() {
    return {
      'type': 'emergency_detection',
      'emergency_type': type.name,
      'severity': severity.name,
      'message': 'Emergency: ${type.emoji} ${type.label} - ${severity.label} Severity',
      'timestamp': timestamp.toIso8601String(),
      'confidence': confidence,
      // Note: image_path is NOT included - hardware can't transmit images
    };
  }
  
  /// Get formatted message for chat display
  String getFormattedMessage() {
    return 'Emergency: ${type.emoji} ${type.label} - ${severity.label} Severity';
  }
  
  /// Get badge text for UI display
  String getBadgeText() {
    return '${type.emoji} ${type.label} - ${severity.label}';
  }
  
  @override
  String toString() {
    return 'EmergencyDetectionResult(type: ${type.label}, severity: ${severity.label}, confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
  }
}

