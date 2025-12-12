import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Accessibility Testing Utility
/// 
/// Provides methods to test and verify WCAG contrast ratios
class AccessibilityTest {
  /// Test contrast ratio between two colors
  static double testContrastRatio(Color foreground, Color background) {
    return _calculateContrastRatio(foreground, background);
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

  /// Check if contrast ratio meets WCAG AA standards
  static bool meetsWCAGAA(Color foreground, Color background, {bool isLargeText = false}) {
    final ratio = testContrastRatio(foreground, background);
    final minRatio = isLargeText ? 3.0 : 4.5;
    return ratio >= minRatio;
  }

  /// Check if contrast ratio meets WCAG AAA standards
  static bool meetsWCAGAAA(Color foreground, Color background, {bool isLargeText = false}) {
    final ratio = testContrastRatio(foreground, background);
    final minRatio = isLargeText ? 4.5 : 7.0;
    return ratio >= minRatio;
  }

  /// Get contrast ratio status
  static String getContrastStatus(Color foreground, Color background, {bool isLargeText = false}) {
    final ratio = testContrastRatio(foreground, background);
    final aaPass = meetsWCAGAA(foreground, background, isLargeText: isLargeText);
    final aaaPass = meetsWCAGAAA(foreground, background, isLargeText: isLargeText);

    if (aaaPass) {
      return 'AAA (${ratio.toStringAsFixed(2)}:1)';
    } else if (aaPass) {
      return 'AA (${ratio.toStringAsFixed(2)}:1)';
    } else {
      return 'FAIL (${ratio.toStringAsFixed(2)}:1)';
    }
  }

  /// Test common app color combinations
  static Map<String, String> testAppColors() {
    final tests = <String, String>{};

    // Test primary red on white
    tests['Primary Red on White'] = getContrastStatus(
      AppColors.primaryRed,
      AppColors.white,
    );

    // Test white on primary red
    tests['White on Primary Red'] = getContrastStatus(
      AppColors.white,
      AppColors.primaryRed,
    );

    // Test text primary on background light
    tests['Text Primary on Background Light'] = getContrastStatus(
      AppColors.textPrimary,
      AppColors.backgroundLight,
    );

    // Test text secondary on background light
    tests['Text Secondary on Background Light'] = getContrastStatus(
      AppColors.textSecondary,
      AppColors.backgroundLight,
    );

    // Test error on white
    tests['Error on White'] = getContrastStatus(
      AppColors.error,
      AppColors.white,
    );

    // Test success on white
    tests['Success on White'] = getContrastStatus(
      AppColors.success,
      AppColors.white,
    );

    // Test warning on white
    tests['Warning on White'] = getContrastStatus(
      AppColors.warning,
      AppColors.white,
    );

    // Test info on white
    tests['Info on White'] = getContrastStatus(
      AppColors.info,
      AppColors.white,
    );

    return tests;
  }

  /// Print accessibility test results
  static void printTestResults() {
    print('=== Accessibility Test Results ===');
    print('');
    print('WCAG Contrast Ratio Tests:');
    print('');
    
    final results = testAppColors();
    results.forEach((key, value) {
      print('$key: $value');
    });
    
    print('');
    print('WCAG Standards:');
    print('  AA Normal Text: 4.5:1');
    print('  AA Large Text: 3.0:1');
    print('  AAA Normal Text: 7.0:1');
    print('  AAA Large Text: 4.5:1');
  }
}

