import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'accessibility_test.dart';

/// Refined Color System with Semantic Colors and Accessibility
/// 
/// Provides:
/// - Semantic color helpers (success, error, warning, info)
/// - WCAG-compliant color combinations
/// - Dark mode support
/// - Status color coding (online, offline, muted, etc.)
/// - Automatic contrast adjustment
class ColorSystem {
  // ============================================================================
  // SEMANTIC COLORS - Consistent use across the app
  // ============================================================================

  /// Success color - for positive actions and confirmations
  static const Color success = AppColors.success;
  static const Color successLight = AppColors.accentLight;
  static const Color successDark = AppColors.accentDark;
  static const Color successBackground = AppColors.successBackground;
  static const Color successText = AppColors.successText;

  /// Error color - for errors and critical issues
  static const Color error = AppColors.error;
  static const Color errorLight = AppColors.primaryLight;
  static const Color errorDark = AppColors.primaryDark;
  static const Color errorBackground = AppColors.criticalBackground;
  static const Color errorText = AppColors.criticalText;

  /// Warning color - for cautionary messages
  static const Color warning = AppColors.warning;
  static const Color warningLight = AppColors.warningLight;
  static const Color warningDark = AppColors.warningDark;
  static const Color warningBackground = AppColors.warningBackground;
  static const Color warningText = AppColors.warningText;

  /// Info color - for informational messages
  static const Color info = AppColors.info;
  static const Color infoLight = AppColors.infoLight;
  static const Color infoDark = AppColors.infoDark;
  static const Color infoBackground = AppColors.infoBackground;
  static const Color infoText = AppColors.infoText;

  // ============================================================================
  // STATUS COLORS - Consistent status coding
  // ============================================================================

  /// Online status - user is active/connected
  static const Color statusOnline = AppColors.online;
  static const Color statusOnlineLight = AppColors.accentLight;
  static const Color statusOnlineBackground = AppColors.successBackground;

  /// Offline status - user is inactive/disconnected
  static const Color statusOffline = AppColors.offline;
  static const Color statusOfflineLight = AppColors.neutralGrayLight;
  static const Color statusOfflineBackground = AppColors.lightGray;

  /// Muted status - user is muted
  static const Color statusMuted = AppColors.warning;
  static const Color statusMutedLight = AppColors.warningLight;
  static const Color statusMutedBackground = AppColors.warningBackground;

  /// Active status - system/feature is active
  static const Color statusActive = AppColors.statusActive;
  static const Color statusActiveLight = AppColors.cyanLight;
  static const Color statusActiveBackground = AppColors.statusBackground;

  /// Inactive status - system/feature is inactive
  static const Color statusInactive = AppColors.statusInactive;
  static const Color statusInactiveLight = AppColors.neutralGrayLight;
  static const Color statusInactiveBackground = AppColors.lightGray;

  /// Connected status - device/network is connected
  static const Color statusConnected = AppColors.online;
  static const Color statusConnectedLight = AppColors.accentLight;
  static const Color statusConnectedBackground = AppColors.successBackground;

  /// Disconnected status - device/network is disconnected
  static const Color statusDisconnected = AppColors.offline;
  static const Color statusDisconnectedLight = AppColors.neutralGrayLight;
  static const Color statusDisconnectedBackground = AppColors.lightGray;

  // ============================================================================
  // ACCESSIBLE COLOR HELPERS - WCAG-compliant combinations
  // ============================================================================

  /// Get accessible text color for a background
  static Color getAccessibleTextColor(Color backgroundColor, {bool isLargeText = false}) {
    // Test white text first
    if (AccessibilityTest.meetsWCAGAA(Colors.white, backgroundColor, isLargeText: isLargeText)) {
      return Colors.white;
    }
    // Test black text
    if (AccessibilityTest.meetsWCAGAA(Colors.black, backgroundColor, isLargeText: isLargeText)) {
      return Colors.black;
    }
    // If neither works, return a calculated accessible color
    return _calculateAccessibleTextColor(backgroundColor);
  }

  /// Calculate accessible text color based on background luminance
  static Color _calculateAccessibleTextColor(Color backgroundColor) {
    final luminance = _getRelativeLuminance(backgroundColor);
    // If background is dark, use light text; if light, use dark text
    return luminance < 0.5 ? Colors.white : Colors.black;
  }

  /// Get relative luminance of a color
  static double _getRelativeLuminance(Color color) {
    final r = _linearize(color.red / 255.0);
    final g = _linearize(color.green / 255.0);
    final b = _linearize(color.blue / 255.0);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Linearize color component
  static double _linearize(double component) {
    if (component <= 0.03928) {
      return component / 12.92;
    }
    return math.pow((component + 0.055) / 1.055, 2.4).toDouble();
  }

  /// Get semantic color with accessible text
  static SemanticColorPair getSemanticColor(SemanticColorType type) {
    switch (type) {
      case SemanticColorType.success:
        return SemanticColorPair(
          background: success,
          text: getAccessibleTextColor(success),
          light: successLight,
          dark: successDark,
        );
      case SemanticColorType.error:
        return SemanticColorPair(
          background: error,
          text: getAccessibleTextColor(error),
          light: errorLight,
          dark: errorDark,
        );
      case SemanticColorType.warning:
        return SemanticColorPair(
          background: warning,
          text: getAccessibleTextColor(warning),
          light: warningLight,
          dark: warningDark,
        );
      case SemanticColorType.info:
        return SemanticColorPair(
          background: info,
          text: getAccessibleTextColor(info),
          light: infoLight,
          dark: infoDark,
        );
    }
  }

  /// Get status color with accessible text
  static StatusColorPair getStatusColor(StatusType type) {
    switch (type) {
      case StatusType.online:
        return StatusColorPair(
          color: statusOnline,
          text: getAccessibleTextColor(statusOnline),
          background: statusOnlineBackground,
        );
      case StatusType.offline:
        return StatusColorPair(
          color: statusOffline,
          text: getAccessibleTextColor(statusOffline),
          background: statusOfflineBackground,
        );
      case StatusType.muted:
        return StatusColorPair(
          color: statusMuted,
          text: getAccessibleTextColor(statusMuted),
          background: statusMutedBackground,
        );
      case StatusType.active:
        return StatusColorPair(
          color: statusActive,
          text: getAccessibleTextColor(statusActive),
          background: statusActiveBackground,
        );
      case StatusType.inactive:
        return StatusColorPair(
          color: statusInactive,
          text: getAccessibleTextColor(statusInactive),
          background: statusInactiveBackground,
        );
      case StatusType.connected:
        return StatusColorPair(
          color: statusConnected,
          text: getAccessibleTextColor(statusConnected),
          background: statusConnectedBackground,
        );
      case StatusType.disconnected:
        return StatusColorPair(
          color: statusDisconnected,
          text: getAccessibleTextColor(statusDisconnected),
          background: statusDisconnectedBackground,
        );
    }
  }
}

// ============================================================================
// ENUMS AND DATA CLASSES
// ============================================================================

enum SemanticColorType { success, error, warning, info }
enum StatusType { online, offline, muted, active, inactive, connected, disconnected }

class SemanticColorPair {
  final Color background;
  final Color text;
  final Color light;
  final Color dark;

  const SemanticColorPair({
    required this.background,
    required this.text,
    required this.light,
    required this.dark,
  });
}

class StatusColorPair {
  final Color color;
  final Color text;
  final Color background;

  const StatusColorPair({
    required this.color,
    required this.text,
    required this.background,
  });
}


