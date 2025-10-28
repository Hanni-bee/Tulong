import 'package:flutter/material.dart';

class AppColors {
  // Professional Emergency App Color Palette
  // Primary - Red for danger/emergency
  static const Color primary = Color(0xFFD32F2F);           // Primary Red #D32F2F
  static const Color primaryDark = Color(0xFFB71C1C);       // Darker red
  static const Color primaryLight = Color(0xFFFFCDD2);      // Light red
  static const Color primaryAccent = Color(0xFFD32F2F);     // Accent red
  
  // Secondary - Dark Gray for professional look
  static const Color secondary = Color(0xFF2C2C2C);         // Secondary Dark Gray #2C2C2C
  static const Color secondaryDark = Color(0xFF1A1A1A);     // Darker gray
  static const Color secondaryLight = Color(0xFF424242);    // Light dark gray
  static const Color secondaryAccent = Color(0xFF2C2C2C);   // Accent dark gray
  
  // Accent - Muted Green for success/active
  static const Color accent = Color(0xFF27AE60);            // Accent Muted Green #27AE60
  static const Color accentLight = Color(0xFF4CAF50);       // Light green
  static const Color accentDark = Color(0xFF1B5E20);        // Dark green
  static const Color accentAccent = Color(0xFF27AE60);      // Accent green
  
  // Background - White
  static const Color background = Color(0xFFFFFFFF);        // Background White #FFFFFF
  static const Color backgroundDark = Color(0xFF121212);    // Dark background
  static const Color backgroundLight = Color(0xFFFAFAFA);   // Light background
  
  // Warning - Orange for caution
  static const Color warning = Color(0xFFE67E22);           // Warning Orange #E67E22
  static const Color warningLight = Color(0xFFFF9800);      // Light orange
  static const Color warningDark = Color(0xFFE65100);       // Dark orange
  static const Color warningAccent = Color(0xFFE67E22);     // Accent orange
  
  // Info - Blue for information
  static const Color info = Color(0xFF3498DB);              // Info Blue #3498DB
  static const Color infoLight = Color(0xFF64B5F6);         // Light blue
  static const Color infoDark = Color(0xFF1976D2);          // Dark blue
  static const Color infoAccent = Color(0xFF3498DB);        // Accent blue
  
  // Additional Accent Colors for Enhanced UI
  // Purple - For premium features and special actions
  static const Color purple = Color(0xFF9C27B0);            // Purple #9C27B0
  static const Color purpleLight = Color(0xFFBA68C8);       // Light purple
  static const Color purpleDark = Color(0xFF7B1FA2);        // Dark purple
  static const Color purpleAccent = Color(0xFFE1BEE7);      // Purple accent
  
  // Teal - For communication and chat features
  static const Color teal = Color(0xFF009688);              // Teal #009688
  static const Color tealLight = Color(0xFF4DB6AC);         // Light teal
  static const Color tealDark = Color(0xFF00695C);          // Dark teal
  static const Color tealAccent = Color(0xFFB2DFDB);        // Teal accent
  
  // Indigo - For navigation and system features
  static const Color indigo = Color(0xFF3F51B5);            // Indigo #3F51B5
  static const Color indigoLight = Color(0xFF7986CB);       // Light indigo
  static const Color indigoDark = Color(0xFF303F9F);        // Dark indigo
  static const Color indigoAccent = Color(0xFFC5CAE9);      // Indigo accent
  
  // Amber - For highlights and important notices
  static const Color amber = Color(0xFFFFC107);             // Amber #FFC107
  static const Color amberLight = Color(0xFFFFD54F);        // Light amber
  static const Color amberDark = Color(0xFFFF8F00);         // Dark amber
  static const Color amberAccent = Color(0xFFFFF8E1);       // Amber accent
  
  // Deep Orange - For emergency alerts and critical actions
  static const Color deepOrange = Color(0xFFFF5722);        // Deep Orange #FF5722
  static const Color deepOrangeLight = Color(0xFFFF8A65);   // Light deep orange
  static const Color deepOrangeDark = Color(0xFFD84315);    // Dark deep orange
  static const Color deepOrangeAccent = Color(0xFFFFCCBC);  // Deep orange accent
  
  // Cyan - For status indicators and notifications
  static const Color cyan = Color(0xFF00BCD4);              // Cyan #00BCD4
  static const Color cyanLight = Color(0xFF4DD0E1);         // Light cyan
  static const Color cyanDark = Color(0xFF0097A7);          // Dark cyan
  static const Color cyanAccent = Color(0xFFB2EBF2);        // Cyan accent
  
  // Neutral colors - Gray for inactive/neutral
  static const Color neutralGray = Color(0xFF7F8C8D);       // Neutral gray
  static const Color neutralGrayLight = Color(0xFFB0BEC5);  // Light gray
  static const Color neutralGrayDark = Color(0xFF455A64);   // Dark gray
  
  // Background colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color cardBackground = Color(0xFFFFFFFF);
  
  // Text colors
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textLight = Color(0xFF9CA3AF);
  
  // Status colors (using the new palette)
  static const Color online = Color(0xFF27AE60);            // Green for online
  static const Color offline = Color(0xFF7F8C8D);           // Gray for offline
  static const Color error = Color(0xFFD32F2F);             // Red for error (using primary)
  static const Color success = Color(0xFF27AE60);           // Green for success (using accent)
  
  // Semantic Color Categories for Better UI Integration
  // Communication & Chat
  static const Color chatBubble = teal;                     // Chat bubbles
  static const Color chatBubbleLight = tealLight;           // Light chat bubbles
  static const Color chatBubbleDark = tealDark;             // Dark chat bubbles
  
  // Navigation & System
  static const Color navActive = indigo;                    // Active navigation
  static const Color navInactive = neutralGray;             // Inactive navigation
  
  // Notifications & Alerts
  static const Color notification = amber;                  // General notifications
  static const Color notificationLight = amberLight;        // Light notifications
  
  // Emergency & Critical
  static const Color emergency = deepOrange;                // Emergency alerts
  static const Color emergencyLight = deepOrangeLight;      // Light emergency
  
  // Status Indicators
  static const Color statusActive = cyan;                   // Active status
  static const Color statusInactive = neutralGray;          // Inactive status
  
  // Premium & Special Features
  static const Color premium = purple;                      // Premium features
  static const Color premiumLight = purpleLight;            // Light premium
  
  // Missing Color Definitions for Backward Compatibility
  // Gradient colors
  static const Color gradientStart = primary;               // Gradient start color
  static const Color gradientEnd = primaryDark;             // Gradient end color
  static const Color primaryGradient = primary;             // Primary gradient color
  static const Color backgroundGradient = backgroundLight;  // Background gradient
  static const Color errorGradient = error;                 // Error gradient
  static const Color cardGlassGradient = background;        // Card glass gradient
  static const Color premiumRedGradient = primary;          // Premium red gradient
  
  // Status colors with specific names
  static const Color successGreen = success;                // Success green
  static const Color offlineGray = offline;                 // Offline gray
  static const Color emergencyRed = emergency;              // Emergency red
  
  // Legacy colors for backward compatibility
  static const Color primaryRed = primary;                  // Alias for primary
  static const Color primaryRedDark = primaryDark;          // Alias for primaryDark
  static const Color primaryRedLight = primaryLight;        // Alias for primaryLight
  static const Color primaryRedAccent = primaryAccent;      // Alias for primaryAccent
  
  // Note: secondaryDark, secondaryLight, secondaryAccent are already defined above
  
  static const Color accentGreen = accent;                  // Alias for accent
  static const Color accentGreenLight = accentLight;        // Alias for accentLight
  static const Color accentGreenDark = accentDark;          // Alias for accentDark
  static const Color accentGreenAccent = accentAccent;      // Alias for accentAccent
  
  static const Color warningOrange = warning;               // Alias for warning
  static const Color warningOrangeLight = warningLight;     // Alias for warningLight
  static const Color warningOrangeDark = warningDark;       // Alias for warningDark
  static const Color warningOrangeAccent = warningAccent;   // Alias for warningAccent
  
  static const Color infoBlue = info;                       // Alias for info
  static const Color infoBlueLight = infoLight;             // Alias for infoLight
  static const Color infoBlueDark = infoDark;               // Alias for infoDark
  static const Color infoBlueAccent = infoAccent;           // Alias for infoAccent
  
  static const Color darkGray = Color(0xFF424242);
  static const Color lightGray = Color(0xFFF5F5F5);
  static const Color mediumGray = Color(0xFF757575);
  static const Color ultraLightGray = Color(0xFFF8F9FA);
  
  // Neumorphic colors
  static const Color neumorphicBase = Color(0xFFF5F5F5);
  static const Color neumorphicLight = Color(0xFFFFFFFF);
  static const Color neumorphicDark = Color(0xFFBDBDBD);
  
  // Dark Mode Colors
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF2D2D2D);
  static const Color darkText = Color(0xFFE0E0E0);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  static const Color darkBorder = Color(0xFF404040);

  // Border and shadow colors
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color shadowColor = Color(0x0A000000);
  
  // Emergency UI backgrounds (using new palette)
  static const Color emergencyBackground = Color(0xFFFFFAFA); // Light emergency background
  static const Color criticalBackground = deepOrangeAccent;   // Critical alert background (deep orange tint)
  static const Color warningBackground = amberAccent;         // Warning background (amber tint)
  static const Color successBackground = accentAccent;        // Success background (green tint)
  static const Color infoBackground = infoAccent;             // Info background (blue tint)
  static const Color chatBackground = tealAccent;             // Chat background (teal tint)
  static const Color navBackground = indigoAccent;            // Navigation background (indigo tint)
  static const Color notificationBackground = amberAccent;    // Notification background (amber tint)
  static const Color statusBackground = cyanAccent;           // Status background (cyan tint)
  static const Color premiumBackground = purpleAccent;        // Premium background (purple tint)
  
  // High contrast text colors for emergency situations
  static const Color emergencyText = Color(0xFF1A202C);      // Dark text for light backgrounds
  static const Color criticalText = Color(0xFF742A2A);      // Dark red text
  static const Color warningText = Color(0xFF744210);       // Dark orange text
  static const Color successText = Color(0xFF22543D);       // Dark green text
  static const Color infoText = Color(0xFF0D47A1);          // Dark blue text
  
}
