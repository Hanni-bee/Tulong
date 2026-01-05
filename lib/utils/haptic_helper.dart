import 'package:flutter/services.dart';

/// Centralized haptic feedback helper for consistent tactile feedback
/// throughout the app. Provides different intensities for different actions.
class HapticHelper {
  /// Light haptic feedback for subtle interactions
  static void light() {
    HapticFeedback.lightImpact();
  }

  /// Medium haptic feedback for standard interactions
  static void medium() {
    HapticFeedback.mediumImpact();
  }

  /// Heavy haptic feedback for important actions
  static void heavy() {
    HapticFeedback.heavyImpact();
  }

  /// Selection click for picker/slider changes
  static void selection() {
    HapticFeedback.selectionClick();
  }

  /// Vibration pattern for errors
  static void error() {
    HapticFeedback.vibrate();
  }

  /// Success pattern (light + light)
  static Future<void> success() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
  }

  /// Emergency pattern (heavy + pause + heavy)
  static Future<void> emergency() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 150));
    await HapticFeedback.heavyImpact();
  }
}

