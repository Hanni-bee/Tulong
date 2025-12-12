import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/unified_typography.dart';

/// Typography Helper for Accessibility and Dynamic Sizing
/// 
/// Provides:
/// - Accessibility-compliant text styles with proper contrast
/// - Dynamic text sizing based on screen size
/// - Consistent line spacing for readability
/// - Helper methods for text contrast validation
class TypographyHelper {
  // Minimum contrast ratios for accessibility (WCAG AA)
  static const double _minContrastRatio = 4.5; // For normal text
  static const double _minContrastRatioLarge = 3.0; // For large text (18pt+)

  /// Get text scale factor based on screen size
  static double getTextScaleFactor(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final textScaleFactor = mediaQuery.textScaleFactor;

    // Base scale factor
    double scaleFactor = 1.0;

    // Adjust for screen size
    if (screenWidth < 360) {
      // Small phones
      scaleFactor = 0.9;
    } else if (screenWidth < 400) {
      // Medium phones
      scaleFactor = 0.95;
    } else if (screenWidth >= 600) {
      // Tablets
      scaleFactor = 1.1;
    }

    // Respect user's text scale preference but cap it
    return (scaleFactor * textScaleFactor).clamp(0.85, 1.3);
  }

  /// Get responsive font size based on screen size
  static double getResponsiveFontSize(BuildContext context, double baseSize) {
    final scaleFactor = getTextScaleFactor(context);
    return baseSize * scaleFactor;
  }

  /// Create accessible text style with proper contrast
  static TextStyle accessibleTextStyle({
    required TextStyle baseStyle,
    required Color backgroundColor,
    Color? textColor,
    double? fontSize,
    double? lineHeight,
    bool isLargeText = false,
  }) {
    // Use provided color or default to textPrimary
    Color finalColor = textColor ?? baseStyle.color ?? AppColors.textPrimary;

    // Ensure contrast ratio meets WCAG AA standards
    finalColor = _ensureContrast(finalColor, backgroundColor, isLargeText);

    return baseStyle.copyWith(
      color: finalColor,
      fontSize: fontSize,
      height: lineHeight ?? _getOptimalLineHeight(baseStyle.fontSize ?? 14),
    );
  }

  /// Ensure text color meets contrast requirements
  static Color _ensureContrast(Color textColor, Color backgroundColor, bool isLargeText) {
    final minRatio = isLargeText ? _minContrastRatioLarge : _minContrastRatio;
    final currentRatio = _calculateContrastRatio(textColor, backgroundColor);

    if (currentRatio >= minRatio) {
      return textColor;
    }

    // Adjust color to meet contrast requirements
    return _adjustColorForContrast(textColor, backgroundColor, minRatio);
  }

  /// Calculate contrast ratio between two colors
  static double _calculateContrastRatio(Color color1, Color color2) {
    final luminance1 = _getRelativeLuminance(color1);
    final luminance2 = _getRelativeLuminance(color2);

    final lighter = luminance1 > luminance2 ? luminance1 : luminance2;
    final darker = luminance1 > luminance2 ? luminance2 : luminance1;

    return (lighter + 0.05) / (darker + 0.05);
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

  /// Adjust color to meet contrast requirements
  static Color _adjustColorForContrast(Color textColor, Color backgroundColor, double minRatio) {
    final bgLuminance = _getRelativeLuminance(backgroundColor);
    final isDarkBackground = bgLuminance < 0.5;

    // If dark background, lighten text; if light background, darken text
    if (isDarkBackground) {
      // Lighten text
      return Color.fromRGBO(
        (textColor.red + (255 - textColor.red) * 0.3).round().clamp(0, 255),
        (textColor.green + (255 - textColor.green) * 0.3).round().clamp(0, 255),
        (textColor.blue + (255 - textColor.blue) * 0.3).round().clamp(0, 255),
        textColor.opacity,
      );
    } else {
      // Darken text
      return Color.fromRGBO(
        (textColor.red * 0.7).round().clamp(0, 255),
        (textColor.green * 0.7).round().clamp(0, 255),
        (textColor.blue * 0.7).round().clamp(0, 255),
        textColor.opacity,
      );
    }
  }

  /// Get optimal line height for readability
  static double _getOptimalLineHeight(double fontSize) {
    // Optimal line height is typically 1.4-1.6x font size
    if (fontSize <= 12) {
      return 1.5; // Small text needs more spacing
    } else if (fontSize <= 16) {
      return 1.5; // Standard body text
    } else if (fontSize <= 20) {
      return 1.4; // Headings
    } else {
      return 1.3; // Large headings
    }
  }

  /// Create responsive heading style
  static TextStyle responsiveHeading(
    BuildContext context, {
    required TextStyle baseStyle,
    double? fontSize,
    Color? color,
    Color? backgroundColor,
  }) {
    final responsiveSize = fontSize != null
        ? getResponsiveFontSize(context, fontSize)
        : null;

    return accessibleTextStyle(
      baseStyle: baseStyle,
      backgroundColor: backgroundColor ?? AppColors.backgroundLight,
      textColor: color,
      fontSize: responsiveSize,
      lineHeight: responsiveSize != null ? _getOptimalLineHeight(responsiveSize) : null,
      isLargeText: (responsiveSize ?? baseStyle.fontSize ?? 16) >= 18,
    );
  }

  /// Create responsive body text style
  static TextStyle responsiveBody(
    BuildContext context, {
    required TextStyle baseStyle,
    double? fontSize,
    Color? color,
    Color? backgroundColor,
  }) {
    final responsiveSize = fontSize != null
        ? getResponsiveFontSize(context, fontSize)
        : null;

    return accessibleTextStyle(
      baseStyle: baseStyle,
      backgroundColor: backgroundColor ?? AppColors.backgroundLight,
      textColor: color,
      fontSize: responsiveSize,
      lineHeight: responsiveSize != null ? _getOptimalLineHeight(responsiveSize) : null,
    );
  }

  /// Create accessible chat message text style
  static TextStyle accessibleChatMessage(
    BuildContext context, {
    required bool isMe,
    Color? backgroundColor,
  }) {
    final bgColor = backgroundColor ?? (isMe ? AppColors.primaryRed : AppColors.white);
    final textColor = isMe ? Colors.white : AppColors.textPrimary;

    return accessibleTextStyle(
      baseStyle: UnifiedTypography.bodyMedium,
      backgroundColor: bgColor,
      textColor: textColor,
      fontSize: getResponsiveFontSize(context, 14),
      lineHeight: 1.6, // Extra spacing for chat readability
    );
  }

  /// Create accessible profile text style
  static TextStyle accessibleProfileText(
    BuildContext context, {
    required TextStyle baseStyle,
    bool isHeading = false,
    Color? backgroundColor,
  }) {
    return accessibleTextStyle(
      baseStyle: baseStyle,
      backgroundColor: backgroundColor ?? AppColors.backgroundLight,
      fontSize: isHeading
          ? getResponsiveFontSize(context, baseStyle.fontSize ?? 18)
          : getResponsiveFontSize(context, baseStyle.fontSize ?? 14),
      lineHeight: isHeading ? 1.4 : 1.5,
      isLargeText: isHeading && (baseStyle.fontSize ?? 18) >= 18,
    );
  }
}

/// Extension for easy typography access
extension TypographyExtension on BuildContext {
  /// Get text scale factor for this context
  double get textScale => TypographyHelper.getTextScaleFactor(this);

  /// Get responsive font size
  double responsiveFontSize(double baseSize) =>
      TypographyHelper.getResponsiveFontSize(this, baseSize);

  /// Create accessible heading
  TextStyle accessibleHeading({
    required TextStyle baseStyle,
    double? fontSize,
    Color? color,
    Color? backgroundColor,
  }) =>
      TypographyHelper.responsiveHeading(
        this,
        baseStyle: baseStyle,
        fontSize: fontSize,
        color: color,
        backgroundColor: backgroundColor,
      );

  /// Create accessible body text
  TextStyle accessibleBody({
    required TextStyle baseStyle,
    double? fontSize,
    Color? color,
    Color? backgroundColor,
  }) =>
      TypographyHelper.responsiveBody(
        this,
        baseStyle: baseStyle,
        fontSize: fontSize,
        color: color,
        backgroundColor: backgroundColor,
      );
}

