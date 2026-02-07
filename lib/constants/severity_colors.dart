import 'package:flutter/material.dart';
import '../models/emergency_type.dart';

/// Single source of truth for detection severity colors.
/// Use everywhere (Emergency Detection page, Local Chat, Profile status, badges).
class SeverityColors {
  SeverityColors._();

  // Base colors per severity level (consistent across the app)
  static const Color low = Color(0xFF4CAF50);       // Green – safe / no emergency
  static const Color medium = Color(0xFFFF9800);    // Orange – caution
  static const Color high = Color(0xFFFF5722);      // Deep Orange – danger
  static const Color critical = Color(0xFFD32F2F);   // Red – critical

  /// Returns the canonical color for a severity level.
  static Color color(SeverityLevel level) {
    switch (level) {
      case SeverityLevel.low:
        return low;
      case SeverityLevel.medium:
        return medium;
      case SeverityLevel.high:
        return high;
      case SeverityLevel.critical:
        return critical;
    }
  }

  /// Lighter shade for backgrounds (e.g. chat bubble, card fill).
  static Color background(SeverityLevel level) {
    switch (level) {
      case SeverityLevel.low:
        return const Color(0xFFE8F5E9);   // Green 50
      case SeverityLevel.medium:
        return const Color(0xFFFFF3E0);   // Orange 50
      case SeverityLevel.high:
        return const Color(0xFFFBE9E6);   // Deep Orange 50
      case SeverityLevel.critical:
        return const Color(0xFFFFEBEE);   // Red 50
    }
  }

  /// Darker shade for borders and emphasis (works on light backgrounds).
  static Color border(SeverityLevel level) {
    switch (level) {
      case SeverityLevel.low:
        return const Color(0xFF81C784);   // Green 300
      case SeverityLevel.medium:
        return const Color(0xFFFFB74D);   // Orange 300
      case SeverityLevel.high:
        return const Color(0xFFFF8A65);   // Deep Orange 300
      case SeverityLevel.critical:
        return const Color(0xFFE57373);   // Red 300
    }
  }
}
