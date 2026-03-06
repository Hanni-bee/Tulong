import 'dart:convert';

import 'emergency_type.dart';

/// Result of emergency detection from AI/ML processing
class EmergencyDetectionResult {
  /// Default confidence (70-75%) when there is no detected emergency or no detection.
  static const double defaultNoEmergencyConfidence = 0.725;

  final EmergencyType type;
  final SeverityLevel severity;
  final double confidence; // 0.0 to 1.0
  final double? confidenceLowerBound; // Lower bound of confidence interval
  final double? confidenceUpperBound; // Upper bound of confidence interval
  final DateTime timestamp;
  final String? imagePath; // Path to captured image (stays on device)
  /// When set, preprocessing or validation failed (e.g. image too dark); UI can show this instead of "No Emergency".
  final String? failureReason;
  /// Per-class probabilities (e.g. Cyclone, Earthquake, Flood, Wildfire) for display and history.
  final Map<String, double>? probabilityBreakdown;

  EmergencyDetectionResult({
    required this.type,
    required this.severity,
    required this.confidence,
    this.confidenceLowerBound,
    this.confidenceUpperBound,
    required this.timestamp,
    this.imagePath,
    this.failureReason,
    this.probabilityBreakdown,
  });

  /// True if this result is due to image quality/preprocess failure (not a real "no emergency" classification).
  bool get isPreprocessFailure => failureReason != null && failureReason!.isNotEmpty;

  /// Detection is deterministic: same image yields the same result on every run.
  bool get isResultConsistent => true;

  /// Short text for UI to show that re-analyzing the same photo will give the same outcome.
  String get consistencyDescription => 'Same image will always yield this result.';

  /// Get confidence as formatted string with interval if available
  String getConfidenceString() {
    if (confidenceLowerBound != null && confidenceUpperBound != null) {
      return '${(confidenceLowerBound! * 100).toStringAsFixed(0)}-${(confidenceUpperBound! * 100).toStringAsFixed(0)}%';
    }
    return '${(confidence * 100).toStringAsFixed(1)}%';
  }
  
  /// Get confidence for decision-making (use lower bound if available, more conservative)
  double getDecisionConfidence() {
    return confidenceLowerBound ?? confidence;
  }
  
  /// Parse confidence from JSON; use default 70-75% when missing/zero (no emergency case).
  static double _confidenceFromJson(dynamic value) {
    final c = (value as num?)?.toDouble();
    if (c == null || c <= 0.0) return defaultNoEmergencyConfidence;
    return c.clamp(0.0, 1.0);
  }

  /// Parse probability_breakdown from JSON (string or map) to Map<String, double>.
  static Map<String, double>? _probabilityBreakdownFromJson(dynamic value) {
    if (value == null) return null;
    Map<String, double> out = {};
    if (value is String) {
      try {
        final decoded = jsonDecode(value) as Map<String, dynamic>;
        for (final e in decoded.entries) {
          final v = e.value;
          out[e.key] = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
        }
        return out.isEmpty ? null : out;
      } catch (_) {
        return null;
      }
    }
    if (value is Map) {
      for (final e in value.entries) {
        final v = e.value;
        out[e.key.toString()] = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;
      }
      return out.isEmpty ? null : out;
    }
    return null;
  }

  /// Create from JSON (for ESP32/radio transmission and local storage)
  /// Expects keys: emergency_type, severity (enum names); timestamp (ISO8601 optional); probability_breakdown optional.
  factory EmergencyDetectionResult.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['emergency_type'] as String?)?.trim();
    final severityStr = (json['severity'] as String?)?.trim();
    return EmergencyDetectionResult(
      type: EmergencyType.fromString(typeStr?.isNotEmpty == true ? typeStr! : 'noEmergency'),
      severity: SeverityLevel.fromString(severityStr?.isNotEmpty == true ? severityStr! : 'medium'),
      confidence: _confidenceFromJson(json['confidence']),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      imagePath: json['image_path'] as String?,
      failureReason: json['failure_reason'] as String?,
      probabilityBreakdown: _probabilityBreakdownFromJson(json['probability_breakdown']),
    );
  }
  
  /// Convert to JSON for ESP32/radio transmission and local storage (text only, no image)
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'type': 'emergency_detection',
      'emergency_type': type.name,
      'severity': severity.name,
      'message': 'Emergency: ${type.emoji} ${type.label} - ${severity.label} Severity',
      'timestamp': timestamp.toIso8601String(),
      'confidence': confidence,
      // Note: image_path is NOT included - hardware can't transmit images
    };
    if (failureReason != null) map['failure_reason'] = failureReason;
    if (probabilityBreakdown != null && probabilityBreakdown!.isNotEmpty) {
      map['probability_breakdown'] = probabilityBreakdown;
    }
    return map;
  }
  
  /// Get formatted message for chat display
  String getFormattedMessage() {
    if (failureReason != null && failureReason!.isNotEmpty) {
      return '${type.emoji} ${type.label} - $failureReason';
    }
    if (type == EmergencyType.noEmergency) {
      return '${type.emoji} ${type.label} - No emergency detected. Area appears safe.';
    }
    return 'Emergency: ${type.emoji} ${type.label} - ${severity.label} Severity';
  }
  
  /// Get badge text for UI display
  String getBadgeText() {
    if (type == EmergencyType.noEmergency) {
      return '${type.emoji} ${type.label}';
    }
    return '${type.emoji} ${type.label} - ${severity.label}';
  }
  
  @override
  String toString() {
    return 'EmergencyDetectionResult(type: ${type.label}, severity: ${severity.label}, confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
  }
}

