import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Unified Typography System for T.U.L.O.N.G App
/// 
/// This class provides a consistent typography system across the entire app.
/// All text styles should use these predefined styles instead of inline TextStyle.
/// 
/// Usage:
/// - For headers: UnifiedTypography.headlineLarge
/// - For body text: UnifiedTypography.bodyMedium
/// - For labels: UnifiedTypography.labelMedium
/// - For buttons: UnifiedTypography.buttonText
class UnifiedTypography {
  // Font Weights
  static const FontWeight _regular = FontWeight.w400;
  static const FontWeight _medium = FontWeight.w500;
  static const FontWeight _semiBold = FontWeight.w600;
  static const FontWeight _bold = FontWeight.w700;
  static const FontWeight _extraBold = FontWeight.w800;
  static const FontWeight _black = FontWeight.w900;

  // Base Text Style with consistent font family
  static TextStyle _baseStyle({
    double fontSize = 16,
    FontWeight fontWeight = _regular,
    Color? color,
    double letterSpacing = 0,
    double height = 1.5,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color ?? AppColors.textPrimary,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  // ============================================================================
  // DISPLAY TEXT STYLES - For hero sections and major headings
  // ============================================================================
  
  /// App title and major hero text (e.g., "T.U.L.O.N.G")
  static TextStyle get displayXLarge => _baseStyle(
    fontSize: 48,
    fontWeight: _black,
    letterSpacing: -1.0,
    height: 1.1,
  );

  /// Large display text for main headings
  static TextStyle get displayLarge => _baseStyle(
    fontSize: 36,
    fontWeight: _extraBold,
    letterSpacing: -0.5,
    height: 1.2,
  );

  /// Medium display text for section headers
  static TextStyle get displayMedium => _baseStyle(
    fontSize: 28,
    fontWeight: _bold,
    letterSpacing: -0.25,
    height: 1.3,
  );

  /// Small display text for subsections
  static TextStyle get displaySmall => _baseStyle(
    fontSize: 24,
    fontWeight: _bold,
    letterSpacing: 0,
    height: 1.3,
  );

  // ============================================================================
  // HEADLINE STYLES - For page and section headings
  // ============================================================================
  
  /// Large headlines for page titles
  static TextStyle get headlineLarge => _baseStyle(
    fontSize: 22,
    fontWeight: _bold,
    letterSpacing: -0.2,
    height: 1.3,
  );

  /// Medium headlines for section titles
  static TextStyle get headlineMedium => _baseStyle(
    fontSize: 20,
    fontWeight: _semiBold,
    letterSpacing: -0.1,
    height: 1.4,
  );

  /// Small headlines for subsection titles
  static TextStyle get headlineSmall => _baseStyle(
    fontSize: 18,
    fontWeight: _semiBold,
    letterSpacing: 0,
    height: 1.4,
  );

  // ============================================================================
  // TITLE STYLES - For card and component headings
  // ============================================================================
  
  /// Large titles for cards and components
  static TextStyle get titleLarge => _baseStyle(
    fontSize: 16,
    fontWeight: _semiBold,
    letterSpacing: 0.1,
    height: 1.4,
  );

  /// Medium titles for smaller components
  static TextStyle get titleMedium => _baseStyle(
    fontSize: 14,
    fontWeight: _semiBold,
    letterSpacing: 0.1,
    height: 1.4,
  );

  /// Small titles for labels and small components
  static TextStyle get titleSmall => _baseStyle(
    fontSize: 12,
    fontWeight: _semiBold,
    letterSpacing: 0.1,
    height: 1.4,
  );

  // ============================================================================
  // BODY TEXT STYLES - For main content
  // ============================================================================
  
  /// Large body text for important content
  static TextStyle get bodyLarge => _baseStyle(
    fontSize: 16,
    fontWeight: _regular,
    letterSpacing: 0.15,
    height: 1.5,
  );

  /// Medium body text for standard content
  static TextStyle get bodyMedium => _baseStyle(
    fontSize: 14,
    fontWeight: _regular,
    letterSpacing: 0.25,
    height: 1.5,
  );

  /// Small body text for secondary content
  static TextStyle get bodySmall => _baseStyle(
    fontSize: 12,
    fontWeight: _regular,
    letterSpacing: 0.4,
    height: 1.5,
  );

  // ============================================================================
  // LABEL STYLES - For form labels and UI elements
  // ============================================================================
  
  /// Large labels for form fields
  static TextStyle get labelLarge => _baseStyle(
    fontSize: 14,
    fontWeight: _medium,
    letterSpacing: 0.1,
    height: 1.4,
  );

  /// Medium labels for standard UI elements
  static TextStyle get labelMedium => _baseStyle(
    fontSize: 12,
    fontWeight: _medium,
    letterSpacing: 0.5,
    height: 1.4,
  );

  /// Small labels for compact UI elements
  static TextStyle get labelSmall => _baseStyle(
    fontSize: 10,
    fontWeight: _medium,
    letterSpacing: 0.5,
    height: 1.4,
  );

  // ============================================================================
  // BUTTON TEXT STYLES - For buttons and interactive elements
  // ============================================================================
  
  /// Primary button text
  static TextStyle get buttonLarge => _baseStyle(
    fontSize: 16,
    fontWeight: _semiBold,
    letterSpacing: 0.1,
    height: 1.3,
  );

  /// Medium button text
  static TextStyle get buttonMedium => _baseStyle(
    fontSize: 14,
    fontWeight: _semiBold,
    letterSpacing: 0.1,
    height: 1.3,
  );

  /// Small button text
  static TextStyle get buttonSmall => _baseStyle(
    fontSize: 12,
    fontWeight: _semiBold,
    letterSpacing: 0.1,
    height: 1.3,
  );

  // ============================================================================
  // CAPTION STYLES - For small descriptive text
  // ============================================================================
  
  /// Large captions
  static TextStyle get captionLarge => _baseStyle(
    fontSize: 13,
    fontWeight: _regular,
    letterSpacing: 0.1,
    height: 1.4,
  );

  /// Standard captions
  static TextStyle get caption => _baseStyle(
    fontSize: 11,
    fontWeight: _regular,
    letterSpacing: 0.2,
    height: 1.3,
  );

  // ============================================================================
  // SPECIAL TEXT STYLES - For specific use cases
  // ============================================================================
  
  /// Error text styling
  static TextStyle get errorText => _baseStyle(
    fontSize: 12,
    fontWeight: _medium,
    color: AppColors.error,
    letterSpacing: 0.1,
    height: 1.3,
  );

  /// Success text styling
  static TextStyle get successText => _baseStyle(
    fontSize: 12,
    fontWeight: _medium,
    color: AppColors.success,
    letterSpacing: 0.1,
    height: 1.3,
  );

  /// Warning text styling
  static TextStyle get warningText => _baseStyle(
    fontSize: 12,
    fontWeight: _medium,
    color: AppColors.warning,
    letterSpacing: 0.1,
    height: 1.3,
  );

  /// Info text styling
  static TextStyle get infoText => _baseStyle(
    fontSize: 12,
    fontWeight: _medium,
    color: AppColors.info,
    letterSpacing: 0.1,
    height: 1.3,
  );

  /// Accent text styling (for primary color text)
  static TextStyle get accentText => _baseStyle(
    fontSize: 14,
    fontWeight: _semiBold,
    color: AppColors.primaryRed,
    letterSpacing: 0.1,
    height: 1.3,
  );

  // ============================================================================
  // EMERGENCY COMMUNICATION STYLES - For disaster-related content
  // ============================================================================
  
  /// Emergency title styling
  static TextStyle get emergencyTitle => _baseStyle(
    fontSize: 24,
    fontWeight: _black,
    color: AppColors.emergencyText,
    letterSpacing: 0.5,
    height: 1.2,
  );

  /// Emergency subtitle styling
  static TextStyle get emergencySubtitle => _baseStyle(
    fontSize: 18,
    fontWeight: _bold,
    color: AppColors.emergencyText,
    letterSpacing: 0.3,
    height: 1.3,
  );

  /// Emergency body text styling
  static TextStyle get emergencyBody => _baseStyle(
    fontSize: 16,
    fontWeight: _medium,
    color: AppColors.emergencyText,
    letterSpacing: 0.2,
    height: 1.4,
  );

  // ============================================================================
  // APP BAR STYLES - For navigation and headers
  // ============================================================================
  
  /// App bar title styling
  static TextStyle get appBarTitle => _baseStyle(
    fontSize: 18,
    fontWeight: _bold,
    color: AppColors.textPrimary,
    letterSpacing: 0.1,
    height: 1.3,
  );

  /// App bar subtitle styling
  static TextStyle get appBarSubtitle => _baseStyle(
    fontSize: 14,
    fontWeight: _medium,
    color: AppColors.textSecondary,
    letterSpacing: 0.1,
    height: 1.3,
  );

  // ============================================================================
  // FORM STYLES - For input fields and forms
  // ============================================================================
  
  /// Form field label styling
  static TextStyle get formLabel => _baseStyle(
    fontSize: 14,
    fontWeight: _semiBold,
    color: AppColors.primaryRed,
    letterSpacing: 0.1,
    height: 1.3,
  );

  /// Form field hint styling
  static TextStyle get formHint => _baseStyle(
    fontSize: 14,
    fontWeight: _regular,
    color: AppColors.mediumGray,
    letterSpacing: 0.1,
    height: 1.3,
  );

  /// Form field input styling
  static TextStyle get formInput => _baseStyle(
    fontSize: 16,
    fontWeight: _medium,
    color: AppColors.textPrimary,
    letterSpacing: 0.1,
    height: 1.3,
  );

  // ============================================================================
  // CARD STYLES - For card content
  // ============================================================================
  
  /// Card title styling
  static TextStyle get cardTitle => _baseStyle(
    fontSize: 16,
    fontWeight: _semiBold,
    color: AppColors.textPrimary,
    letterSpacing: 0.1,
    height: 1.3,
  );

  /// Card subtitle styling
  static TextStyle get cardSubtitle => _baseStyle(
    fontSize: 14,
    fontWeight: _medium,
    color: AppColors.textSecondary,
    letterSpacing: 0.1,
    height: 1.4,
  );

  /// Card body styling
  static TextStyle get cardBody => _baseStyle(
    fontSize: 14,
    fontWeight: _regular,
    color: AppColors.textPrimary,
    letterSpacing: 0.1,
    height: 1.4,
  );

  // ============================================================================
  // UTILITY METHODS - For creating variations
  // ============================================================================
  
  /// Create a text style with custom color
  static TextStyle withColor(TextStyle baseStyle, Color color) {
    return baseStyle.copyWith(color: color);
  }

  /// Create a text style with custom weight
  static TextStyle withWeight(TextStyle baseStyle, FontWeight weight) {
    return baseStyle.copyWith(fontWeight: weight);
  }

  /// Create a text style with custom size
  static TextStyle withSize(TextStyle baseStyle, double size) {
    return baseStyle.copyWith(fontSize: size);
  }

  /// Create a text style with custom opacity
  static TextStyle withOpacity(TextStyle baseStyle, double opacity) {
    return baseStyle.copyWith(color: baseStyle.color?.withOpacity(opacity));
  }
}
