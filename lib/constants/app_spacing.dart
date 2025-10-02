import 'package:flutter/material.dart';

class AppSpacing {
  // Base spacing unit
  static const double base = 8.0;
  
  // Spacing scale
  static const double xs = base * 0.5; // 4
  static const double sm = base * 1;    // 8
  static const double md = base * 2;    // 16
  static const double lg = base * 3;    // 24
  static const double xl = base * 4;    // 32
  static const double xxl = base * 6;   // 48
  
  // Specific spacing
  static const double padding = md;
  static const double margin = md;
  static const double gap = sm;
  
  // Border radius
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusXxl = 24.0;
  
  // Icon sizes
  static const double iconXs = 16.0;
  static const double iconSm = 20.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;
  static const double iconXl = 40.0;
  
  // Button heights
  static const double buttonSm = 36.0;
  static const double buttonMd = 48.0;
  static const double buttonLg = 56.0;
  
  // Input field heights
  static const double inputHeight = 56.0;
  
  // Card dimensions
  static const double cardMinHeight = 80.0;
  static const double cardMaxHeight = 120.0;
  
  // Screen padding
  static const EdgeInsets screenPadding = EdgeInsets.all(md);
  static const EdgeInsets cardPadding = EdgeInsets.all(md);
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(
    horizontal: lg,
    vertical: md,
  );
  
  // List spacing
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: md,
    vertical: sm,
  );
  
  // Grid spacing
  static const double gridSpacing = sm;
  static const double gridCrossAxisSpacing = sm;
  static const double gridMainAxisSpacing = sm;
}