import 'package:flutter/material.dart';
import '../constants/unified_typography.dart';

/// Utility class to help update text styles throughout the app
/// This provides common text style patterns that can be easily applied
class TypographyUpdater {
  
  /// Common text style patterns for different UI elements
  static final Map<String, TextStyle> commonStyles = {
    // App titles and major headings
    'appTitle': UnifiedTypography.displayLarge,
    'appSubtitle': UnifiedTypography.bodyLarge,
    
    // Page headers
    'pageTitle': UnifiedTypography.headlineLarge,
    'pageSubtitle': UnifiedTypography.bodyMedium,
    
    // Section headers
    'sectionHeader': UnifiedTypography.titleLarge,
    'subsectionHeader': UnifiedTypography.titleMedium,
    
    // Form elements
    'formLabel': UnifiedTypography.labelLarge,
    'formHint': UnifiedTypography.bodyMedium,
    'formInput': UnifiedTypography.bodyLarge,
    
    // Buttons
    'buttonPrimary': UnifiedTypography.buttonLarge,
    'buttonSecondary': UnifiedTypography.buttonMedium,
    
    // Cards and content
    'cardTitle': UnifiedTypography.titleLarge,
    'cardSubtitle': UnifiedTypography.bodyMedium,
    'cardBody': UnifiedTypography.bodyMedium,
    
    // Navigation
    'navTitle': UnifiedTypography.titleMedium,
    'navSubtitle': UnifiedTypography.bodySmall,
    
    // Status messages
    'errorMessage': UnifiedTypography.errorText,
    'successMessage': UnifiedTypography.successText,
    'warningMessage': UnifiedTypography.warningText,
    'infoMessage': UnifiedTypography.infoText,
    
    // Emergency content
    'emergencyTitle': UnifiedTypography.emergencyTitle,
    'emergencySubtitle': UnifiedTypography.emergencySubtitle,
    'emergencyBody': UnifiedTypography.emergencyBody,
  };

  /// Get a text style by name with optional color override
  static TextStyle getStyle(String styleName, {Color? color}) {
    final baseStyle = commonStyles[styleName] ?? UnifiedTypography.bodyMedium;
    return color != null ? baseStyle.copyWith(color: color) : baseStyle;
  }

  /// Common text style replacements for migration
  static const Map<String, String> styleReplacements = {
    // Common inline styles to replace
    'TextStyle(fontSize: 32, fontWeight: FontWeight.bold)': 'UnifiedTypography.displayLarge',
    'TextStyle(fontSize: 24, fontWeight: FontWeight.bold)': 'UnifiedTypography.displaySmall',
    'TextStyle(fontSize: 20, fontWeight: FontWeight.w600)': 'UnifiedTypography.headlineMedium',
    'TextStyle(fontSize: 18, fontWeight: FontWeight.w600)': 'UnifiedTypography.headlineSmall',
    'TextStyle(fontSize: 16, fontWeight: FontWeight.w600)': 'UnifiedTypography.titleLarge',
    'TextStyle(fontSize: 14, fontWeight: FontWeight.w600)': 'UnifiedTypography.titleMedium',
    'TextStyle(fontSize: 16, fontWeight: FontWeight.w400)': 'UnifiedTypography.bodyLarge',
    'TextStyle(fontSize: 14, fontWeight: FontWeight.w400)': 'UnifiedTypography.bodyMedium',
    'TextStyle(fontSize: 12, fontWeight: FontWeight.w400)': 'UnifiedTypography.bodySmall',
  };

  /// Helper method to create consistent text widgets
  static Widget createText(
    String text, {
    String styleName = 'bodyMedium',
    Color? color,
    TextAlign? textAlign,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    return Text(
      text,
      style: getStyle(styleName, color: color),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  /// Helper method to create consistent section headers
  static Widget createSectionHeader(String text, {Color? color}) {
    return Text(
      text,
      style: UnifiedTypography.titleLarge.copyWith(
        color: color ?? UnifiedTypography.titleLarge.color,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  /// Helper method to create consistent page titles
  static Widget createPageTitle(String text, {Color? color}) {
    return Text(
      text,
      style: UnifiedTypography.headlineLarge.copyWith(
        color: color ?? UnifiedTypography.headlineLarge.color,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  /// Helper method to create consistent app titles
  static Widget createAppTitle(String text, {Color? color}) {
    return Text(
      text,
      style: UnifiedTypography.displayLarge.copyWith(
        color: color ?? UnifiedTypography.displayLarge.color,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  /// Helper method to create consistent error messages
  static Widget createErrorMessage(String text) {
    return Text(
      text,
      style: UnifiedTypography.errorText,
    );
  }

  /// Helper method to create consistent success messages
  static Widget createSuccessMessage(String text) {
    return Text(
      text,
      style: UnifiedTypography.successText,
    );
  }

  /// Helper method to create consistent info messages
  static Widget createInfoMessage(String text) {
    return Text(
      text,
      style: UnifiedTypography.infoText,
    );
  }
}
