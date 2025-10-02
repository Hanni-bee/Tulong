import 'package:flutter/material.dart';

class AppColors {
  // Primary colors with modern tones
  static const Color primaryRed = Color(0xFFD32F2F);
  static const Color primaryRedDark = Color(0xFFB71C1C);
  static const Color primaryRedLight = Color(0xFFFFCDD2);
  static const Color primaryRedAccent = Color(0xFFE53935);
  
  // Secondary colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color darkGray = Color(0xFF424242);
  static const Color lightGray = Color(0xFFF5F5F5);
  static const Color mediumGray = Color(0xFF757575);
  static const Color ultraLightGray = Color(0xFFF8F9FA);
  
  // Status colors with modern palette
  static const Color online = Color(0xFF10B981);
  static const Color offline = Color(0xFF9E9E9E);
  
  // Dark Mode Colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF2D2D2D);
  static const Color darkText = Color(0xFFE0E0E0);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  static const Color darkBorder = Color(0xFF404040);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);
  static const Color info = Color(0xFF3B82F6);
  
  // Background colors
  static const Color backgroundLight = Color(0xFFFAFAFA);
  static const Color backgroundDark = Color(0xFF212121);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color glassBackground = Color(0x1AFFFFFF);
  
  // Text colors with better contrast
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textLight = Color(0xFF9CA3AF);
  
  // Border and shadow colors
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color shadowColor = Color(0x0A000000);
  static const Color glassBorder = Color(0x33FFFFFF);
  
  // Modern gradient colors with enhanced red theme
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryRedDark, primaryRed, primaryRedAccent],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF8F9FA), Color(0xFFFFFFFF)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [white, Color(0xFFF8F9FA)],
  );

  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x1AFFFFFF), Color(0x0DFFFFFF)],
  );

  // Enhanced red gradients with sophisticated effects
  static const LinearGradient redGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryRedDark, primaryRed, primaryRedAccent],
    stops: [0.0, 0.6, 1.0],
  );

  // Premium gradient system
  static const LinearGradient premiumRedGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB71C1C), Color(0xFFD32F2F), Color(0xFFE53935)],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient subtleRedGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFCE4EC), Color(0xFFFFEBEE)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
  );

  static const LinearGradient warningGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF57C00), Color(0xFFFF9800)],
  );

  static const LinearGradient infoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1976D2), Color(0xFF2196F3)],
  );

  static const LinearGradient redGlassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x40D32F2F), Color(0x20D32F2F)],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryRedDark, primaryRed, primaryRedAccent],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient glassButtonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x60FFFFFF), Color(0x30FFFFFF)],
  );

  // Premium glassmorphism gradients
  static const LinearGradient premiumGlassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x25FFFFFF), Color(0x10FFFFFF)],
  );

  static const LinearGradient cardGlassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x30FFFFFF), Color(0x15FFFFFF)],
  );

  // Error and status gradients
  static const LinearGradient errorGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD32F2F), Color(0xFFEF4444)],
  );

  // Enhanced shadow colors
  static const Color premiumShadow = Color(0x1A000000);
  static const Color glassShadow = Color(0x0D000000);
  static const Color redShadow = Color(0x33D32F2F);
  
}
