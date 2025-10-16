import 'package:flutter/material.dart';

class AppColors {
  // Primary colors with modern tones - Keeping original red theme
  static const Color primaryRed = Color(0xFFD32F2F);
  static const Color primaryRedDark = Color(0xFFB71C1C);
  static const Color primaryRedLight = Color(0xFFFFCDD2);
  static const Color primaryRedAccent = Color(0xFFE53935);
  
  // Neumorphic base colors (neutral grays for depth effects)
  static const Color neumorphicBase = Color(0xFFF5F5F5);
  static const Color neumorphicLight = Color(0xFFFFFFFF);
  static const Color neumorphicDark = Color(0xFFBDBDBD);
  
  // Secondary colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color darkGray = Color(0xFF424242);
  static const Color lightGray = Color(0xFFF5F5F5);
  static const Color mediumGray = Color(0xFF757575);
  static const Color ultraLightGray = Color(0xFFF8F9FA);
  
  // Modern gradient colors (using original red theme)
  static const Color gradientStart = Color(0xFFD32F2F);
  static const Color gradientEnd = Color(0xFFB71C1C);
  static const Color gradientAccent = Color(0xFFE53935);
  
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

  // Text colors with better contrast
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textLight = Color(0xFF9CA3AF);

  // Border and shadow colors
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color shadowColor = Color(0x0A000000);
  
  // Emergency-ready neumorphic shadows and colors
  static const Color redShadow = Color(0x33D32F2F);
  static const Color neumorphicShadow = Color(0x1A000000);
  static const Color neumorphicHighlight = Color(0xFFFFFFFF);

  // Emergency status colors with enhanced contrast
  static const Color emergencyRed = Color(0xFFE53E3E);      // Emergency alerts
  static const Color warningOrange = Color(0xFFED8936);     // Warnings
  static const Color successGreen = Color(0xFF38A169);      // Success/connected
  static const Color infoBlue = Color(0xFF3182CE);          // Information
  static const Color offlineGray = Color(0xFF718096);       // Offline/disconnected

  // Emergency UI backgrounds
  static const Color emergencyBackground = Color(0xFFFFFAFA); // Light emergency background
  static const Color criticalBackground = Color(0xFFFEE2E2);  // Critical alert background
  static const Color warningBackground = Color(0xFFFFF3CD);   // Warning background
  static const Color successBackground = Color(0xFFF0FFF4);   // Success background

  // High contrast text colors for emergency situations
  static const Color emergencyText = Color(0xFF1A202C);      // Dark text for light backgrounds
  static const Color criticalText = Color(0xFF742A2A);      // Dark red text
  static const Color warningText = Color(0xFF744210);       // Dark orange text
  static const Color successText = Color(0xFF22543D);       // Dark green text

  // Solid color replacements for gradients (no gradients/glass effects)
  static const Color primaryGradient = Color(0xFFD32F2F);  // Solid red instead of gradient
  static const Color backgroundGradient = Color(0xFFFAFAFA);  // Solid background
  static const Color cardGradient = Color(0xFFFFFFFF);  // Solid white
  static const Color premiumRedGradient = Color(0xFFD32F2F);  // Solid red
  static const Color errorGradient = Color(0xFFEF4444);  // Solid error red
  static const Color cardGlassGradient = Color(0xFFFFFFFF);  // Solid white
  static const Color glassBorder = Color(0xFFE5E7EB);  // Solid border
  
}
