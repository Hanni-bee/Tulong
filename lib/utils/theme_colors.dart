import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Theme-aware color utility class
/// Provides colors that adapt to the current theme (Light/Dark/AMOLED Black)
class ThemeColors {
  // Prevent instantiation
  ThemeColors._();

  // ============================================================================
  // BACKGROUND COLORS
  // ============================================================================

  /// Main background color (Scaffold background)
  static Color background(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  /// Surface color (Cards, containers)
  static Color surface(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }

  /// Surface container color (Elevated cards)
  static Color surfaceContainer(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (brightness == Brightness.dark) {
      // Check if AMOLED black mode
      final isAmoled = Theme.of(context).scaffoldBackgroundColor == Colors.black;
      return isAmoled ? const Color(0xFF1A1A1A) : const Color(0xFF2D2D2D);
    }
    return Colors.white;
  }

  /// Surface container high (Highly elevated cards)
  static Color surfaceContainerHigh(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (brightness == Brightness.dark) {
      final isAmoled = Theme.of(context).scaffoldBackgroundColor == Colors.black;
      return isAmoled ? const Color(0xFF252525) : const Color(0xFF3A3A3A);
    }
    return const Color(0xFFFAFAFA);
  }

  /// Card background color
  static Color cardBackground(BuildContext context) {
    return surfaceContainer(context);
  }

  /// White color (adapts in dark mode)
  static Color white(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? surface(context) : Colors.white;
  }

  // ============================================================================
  // TEXT COLORS
  // ============================================================================

  /// Primary text color
  static Color textPrimary(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  /// Secondary text color (WCAG AA compliant - min 4.5:1 on dark surfaces)
  static Color textSecondary(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (brightness == Brightness.dark) {
      return const Color(0xFFB8B8B8); // Lighter for better contrast on dark BG
    }
    return AppColors.textSecondary;
  }

  /// Tertiary text color (WCAG AA compliant for placeholders/hints)
  static Color textTertiary(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (brightness == Brightness.dark) {
      return const Color(0xFF9A9A9A); // Readable on dark surfaces
    }
    return AppColors.textLight;
  }

  /// White text (always white, but may need adjustment for contrast)
  static Color textWhite(BuildContext context) {
    return Colors.white;
  }

  // ============================================================================
  // BORDER COLORS
  // ============================================================================

  /// Border color
  static Color border(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (brightness == Brightness.dark) {
      final isAmoled = Theme.of(context).scaffoldBackgroundColor == Colors.black;
      return isAmoled ? const Color(0xFF333333) : const Color(0xFF404040);
    }
    return AppColors.borderColor;
  }

  /// Divider color
  static Color divider(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (brightness == Brightness.dark) {
      final isAmoled = Theme.of(context).scaffoldBackgroundColor == Colors.black;
      return isAmoled ? const Color(0xFF1A1A1A) : const Color(0xFF2D2D2D);
    }
    return AppColors.lightGray;
  }

  // ============================================================================
  // SHADOW COLORS
  // ============================================================================

  /// Shadow color (for BoxShadow)
  static Color shadow(BuildContext context, {double opacity = 0.1}) {
    final brightness = Theme.of(context).brightness;
    if (brightness == Brightness.dark) {
      final isAmoled = Theme.of(context).scaffoldBackgroundColor == Colors.black;
      final shadowOpacity = isAmoled ? (opacity * 1.5).clamp(0.0, 1.0) : (opacity * 1.2).clamp(0.0, 1.0);
      return Colors.black.withOpacity(shadowOpacity);
    }
    return Colors.black.withOpacity(opacity);
  }

  /// Elevation shadow color (for higher elevation)
  static Color shadowElevation(BuildContext context, {double opacity = 0.2}) {
    final brightness = Theme.of(context).brightness;
    if (brightness == Brightness.dark) {
      final isAmoled = Theme.of(context).scaffoldBackgroundColor == Colors.black;
      final shadowOpacity = isAmoled ? (opacity * 1.5).clamp(0.0, 1.0) : (opacity * 1.2).clamp(0.0, 1.0);
      return Colors.black.withOpacity(shadowOpacity);
    }
    return Colors.black.withOpacity(opacity);
  }

  // ============================================================================
  // ACCENT COLORS (Keep same across themes, but may need contrast adjustment)
  // ============================================================================

  /// Primary red (Emergency color)
  static Color primary(BuildContext context) {
    return AppColors.primary;
  }

  /// Primary red dark
  static Color primaryDark(BuildContext context) {
    return AppColors.primaryDark;
  }

  /// Primary red light
  static Color primaryLight(BuildContext context) {
    return AppColors.primaryLight;
  }

  /// Accent green (Success/Online)
  static Color accent(BuildContext context) {
    return AppColors.accent;
  }

  /// Warning orange
  static Color warning(BuildContext context) {
    return AppColors.warning;
  }

  /// Info blue
  static Color info(BuildContext context) {
    return AppColors.info;
  }

  /// Error red
  static Color error(BuildContext context) {
    return AppColors.error;
  }

  /// Success green
  static Color success(BuildContext context) {
    return AppColors.success;
  }

  // ============================================================================
  // STATUS COLORS
  // ============================================================================

  /// Online status color
  static Color online(BuildContext context) {
    return AppColors.online;
  }

  /// Offline status color
  static Color offline(BuildContext context) {
    return AppColors.offline;
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /// Check if current theme is dark
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  /// Check if current theme is AMOLED black
  static bool isAmoledBlack(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark &&
           Theme.of(context).scaffoldBackgroundColor == Colors.black;
  }

  /// Get appropriate text color for a given background color
  static Color textColorForBackground(Color backgroundColor) {
    // Calculate luminance
    final luminance = backgroundColor.computeLuminance();
    // Use white text for dark backgrounds, dark text for light backgrounds
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
