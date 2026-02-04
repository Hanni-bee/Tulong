import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../utils/enhanced_page_transitions.dart';

/// App theme definitions
/// Maintains design integrity - same spacing, typography, and structure across all themes
class AppThemes {
  // Prevent instantiation
  AppThemes._();

  /// Light theme (default)
  static ThemeData get lightTheme => _buildLightTheme();

  /// Standard dark theme (Dark Gray)
  static ThemeData get darkTheme => _buildDarkTheme();

  /// AMOLED Black theme (True Black)
  static ThemeData get darkAmoledTheme => _buildDarkAmoledTheme();

  /// Build light theme
  static ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: EnhancedPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: EnhancedPageTransitionsBuilder(),
          TargetPlatform.macOS: EnhancedPageTransitionsBuilder(),
          TargetPlatform.windows: EnhancedPageTransitionsBuilder(),
        },
      ),
      primarySwatch: Colors.red,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      textTheme: TextTheme(
        // Display styles
        displayLarge: AppTypography.displayLarge,
        displayMedium: AppTypography.displayMedium,
        displaySmall: AppTypography.displaySmall,
        
        // Headline styles
        headlineLarge: AppTypography.headlineLarge,
        headlineMedium: AppTypography.headlineMedium,
        headlineSmall: AppTypography.headlineSmall,
        
        // Title styles
        titleLarge: AppTypography.titleLarge,
        titleMedium: AppTypography.titleMedium,
        titleSmall: AppTypography.titleSmall,
        
        // Body styles
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        bodySmall: AppTypography.bodySmall,
        
        // Label styles
        labelLarge: AppTypography.labelLarge,
        labelMedium: AppTypography.labelMedium,
        labelSmall: AppTypography.labelSmall,
      ),
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: Colors.white,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFF5F5F5),
        foregroundColor: const Color(0xFF2E3A59),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.sectionTitle.copyWith(
          color: const Color(0xFF2E3A59),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: AppTypography.buttonText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // Same as light
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24), // Same as light
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Same as light
          borderSide: const BorderSide(
            color: Color(0xFFE0E0E0),
            width: 1.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Same as light
          borderSide: const BorderSide(
            color: Color(0xFFE0E0E0),
            width: 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Same as light
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 2.0,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Same as light
          borderSide: const BorderSide(
            color: Color(0xFFEF5350),
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Same as light
          borderSide: const BorderSide(
            color: Color(0xFFEF5350),
            width: 2.0,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ), // Same as light
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)), // Same as light
        ),
        color: Colors.white,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
      ),
    );
  }

  /// Build standard dark theme (Dark Gray)
  static ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: EnhancedPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: EnhancedPageTransitionsBuilder(),
          TargetPlatform.macOS: EnhancedPageTransitionsBuilder(),
          TargetPlatform.windows: EnhancedPageTransitionsBuilder(),
        },
      ),
      primarySwatch: Colors.red,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.backgroundDark, // #121212
      textTheme: TextTheme(
        // Same typography structure as light theme
        displayLarge: AppTypography.displayLarge.copyWith(color: AppColors.darkText),
        displayMedium: AppTypography.displayMedium.copyWith(color: AppColors.darkText),
        displaySmall: AppTypography.displaySmall.copyWith(color: AppColors.darkText),
        
        headlineLarge: AppTypography.headlineLarge.copyWith(color: AppColors.darkText),
        headlineMedium: AppTypography.headlineMedium.copyWith(color: AppColors.darkText),
        headlineSmall: AppTypography.headlineSmall.copyWith(color: AppColors.darkText),
        
        titleLarge: AppTypography.titleLarge.copyWith(color: AppColors.darkText),
        titleMedium: AppTypography.titleMedium.copyWith(color: AppColors.darkText),
        titleSmall: AppTypography.titleSmall.copyWith(color: AppColors.darkText),
        
        bodyLarge: AppTypography.bodyLarge.copyWith(color: AppColors.darkText),
        bodyMedium: AppTypography.bodyMedium.copyWith(color: AppColors.darkText),
        bodySmall: AppTypography.bodySmall.copyWith(color: AppColors.darkTextSecondary),
        
        labelLarge: AppTypography.labelLarge.copyWith(color: AppColors.darkText),
        labelMedium: AppTypography.labelMedium.copyWith(color: AppColors.darkText),
        labelSmall: AppTypography.labelSmall.copyWith(color: AppColors.darkTextSecondary),
      ),
      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.darkSurface, // #1E1E1E
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.darkText, // #E0E0E0
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundDark, // #121212
        foregroundColor: AppColors.darkText, // #E0E0E0
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.sectionTitle.copyWith(
          color: AppColors.darkText, // #E0E0E0
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: AppTypography.buttonText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // Same as light
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24), // Same as light
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface, // #1E1E1E
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Same as light
          borderSide: BorderSide(
            color: AppColors.darkBorder, // #404040
            width: 1.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Same as light
          borderSide: BorderSide(
            color: AppColors.darkBorder, // #404040
            width: 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Same as light
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 2.0,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Same as light
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Same as light
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 2.0,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ), // Same as light
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)), // Same as light
        ),
        color: AppColors.darkCard, // #2D2D2D
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.darkSurface, // #1E1E1E
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurface, // #1E1E1E
      ),
    );
  }

  /// Build AMOLED Black theme (True Black)
  static ThemeData _buildDarkAmoledTheme() {
    return ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: EnhancedPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: EnhancedPageTransitionsBuilder(),
          TargetPlatform.macOS: EnhancedPageTransitionsBuilder(),
          TargetPlatform.windows: EnhancedPageTransitionsBuilder(),
        },
      ),
      primarySwatch: Colors.red,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: Colors.black, // True black #000000
      textTheme: TextTheme(
        // Same typography structure as light theme
        displayLarge: AppTypography.displayLarge.copyWith(color: AppColors.darkText),
        displayMedium: AppTypography.displayMedium.copyWith(color: AppColors.darkText),
        displaySmall: AppTypography.displaySmall.copyWith(color: AppColors.darkText),
        
        headlineLarge: AppTypography.headlineLarge.copyWith(color: AppColors.darkText),
        headlineMedium: AppTypography.headlineMedium.copyWith(color: AppColors.darkText),
        headlineSmall: AppTypography.headlineSmall.copyWith(color: AppColors.darkText),
        
        titleLarge: AppTypography.titleLarge.copyWith(color: AppColors.darkText),
        titleMedium: AppTypography.titleMedium.copyWith(color: AppColors.darkText),
        titleSmall: AppTypography.titleSmall.copyWith(color: AppColors.darkText),
        
        bodyLarge: AppTypography.bodyLarge.copyWith(color: AppColors.darkText),
        bodyMedium: AppTypography.bodyMedium.copyWith(color: AppColors.darkText),
        bodySmall: AppTypography.bodySmall.copyWith(color: AppColors.darkTextSecondary),
        
        labelLarge: AppTypography.labelLarge.copyWith(color: AppColors.darkText),
        labelMedium: AppTypography.labelMedium.copyWith(color: AppColors.darkText),
        labelSmall: AppTypography.labelSmall.copyWith(color: AppColors.darkTextSecondary),
      ),
      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: const Color(0xFF0A0A0A), // Near-black
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.darkText, // #E0E0E0
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.black, // True black
        foregroundColor: AppColors.darkText, // #E0E0E0
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTypography.sectionTitle.copyWith(
          color: AppColors.darkText, // #E0E0E0
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: AppTypography.buttonText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // Same as light
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24), // Same as light
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0A0A0A), // Near-black
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Same as light
          borderSide: const BorderSide(
            color: Color(0xFF333333), // Slightly lighter for visibility
            width: 1.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Same as light
          borderSide: const BorderSide(
            color: Color(0xFF333333), // Slightly lighter for visibility
            width: 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Same as light
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 2.0,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Same as light
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12), // Same as light
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 2.0,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ), // Same as light
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)), // Same as light
        ),
        color: Color(0xFF1A1A1A), // Very dark gray for cards (not true black for depth)
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF0A0A0A), // Near-black
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF0A0A0A), // Near-black
      ),
    );
  }
}
