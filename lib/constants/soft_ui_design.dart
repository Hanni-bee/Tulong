import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Modern Material Design with Soft UI touches
/// Design tokens and utilities for consistent soft UI implementation

class SoftUIDesign {
  // Card Styling
  static const double cardBorderRadius = 16.0;
  static const double cardPadding = 16.0;
  static const double cardMargin = 8.0;
  
  // Button Styling
  static const double buttonBorderRadius = 12.0;
  static const double buttonHeight = 50.0;
  static const double buttonPadding = 16.0;
  
  // Input Field Styling
  static const double inputBorderRadius = 12.0;
  static const double inputPadding = 16.0;
  
  // Shadow System - Soft UI inspired
  static List<BoxShadow> getSoftShadow({
    double elevation = 2.0,
    Color? shadowColor,
  }) {
    final color = shadowColor ?? Colors.black.withOpacity(0.08);
    final adjustedElevation = elevation.clamp(0.0, 8.0);
    
    return [
      // Main shadow - soft and diffused
      BoxShadow(
        color: color,
        blurRadius: adjustedElevation * 6,
        offset: Offset(0, adjustedElevation * 2),
        spreadRadius: 0,
      ),
      // Subtle highlight for soft UI effect
      if (elevation > 0)
        BoxShadow(
          color: Colors.white.withOpacity(0.5),
          blurRadius: adjustedElevation * 3,
          offset: Offset(0, -(adjustedElevation * 1)),
          spreadRadius: 0,
        ),
    ];
  }
  
  // Card shadow - for elevated cards
  static List<BoxShadow> getCardShadow({double elevation = 4.0}) {
    return getSoftShadow(elevation: elevation, shadowColor: Colors.black.withOpacity(0.06));
  }
  
  // Button shadow - for interactive elements
  static List<BoxShadow> getButtonShadow({Color? color}) {
    final shadowColor = color?.withOpacity(0.2) ?? Colors.black.withOpacity(0.1);
    return [
      BoxShadow(
        color: shadowColor,
        blurRadius: 8,
        offset: const Offset(0, 4),
        spreadRadius: 0,
      ),
      BoxShadow(
        color: Colors.white.withOpacity(0.6),
        blurRadius: 4,
        offset: const Offset(0, -2),
        spreadRadius: 0,
      ),
    ];
  }
  
  // Subtle border for cards
  static Border getCardBorder({Color? color}) {
    return Border.all(
      color: color ?? AppColors.lightGray.withOpacity(0.3),
      width: 1.0,
    );
  }
  
  // Card decoration builder
  static BoxDecoration cardDecoration({
    Color? backgroundColor,
    double? borderRadius,
    double elevation = 4.0,
    Color? borderColor,
    bool showBorder = false,
  }) {
    return BoxDecoration(
      color: backgroundColor ?? AppColors.white,
      borderRadius: BorderRadius.circular(borderRadius ?? cardBorderRadius),
      border: showBorder ? getCardBorder(color: borderColor) : null,
      boxShadow: getCardShadow(elevation: elevation),
    );
  }
  
  // Button decoration builder
  static BoxDecoration buttonDecoration({
    required Color backgroundColor,
    double? borderRadius,
    Color? shadowColor,
    bool isPressed = false,
  }) {
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(borderRadius ?? buttonBorderRadius),
      boxShadow: isPressed ? [] : getButtonShadow(color: shadowColor ?? backgroundColor),
    );
  }
  
  // Input field decoration builder
  static InputDecoration inputDecoration({
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool isFocused = false,
    bool hasError = false,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: inputPadding,
        vertical: inputPadding,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputBorderRadius),
        borderSide: BorderSide(
          color: hasError
              ? AppColors.error
              : AppColors.lightGray.withOpacity(0.3),
          width: 1.0,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputBorderRadius),
        borderSide: BorderSide(
          color: hasError
              ? AppColors.error
              : AppColors.lightGray.withOpacity(0.3),
          width: 1.0,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputBorderRadius),
        borderSide: BorderSide(
          color: hasError ? AppColors.error : AppColors.primaryRed,
          width: 2.0,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputBorderRadius),
        borderSide: const BorderSide(
          color: AppColors.error,
          width: 2.0,
        ),
      ),
    );
  }
  
  // Spacing system
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;
  
  // Typography scale (to be used with existing typography system)
  static const double fontSizeXS = 10.0;
  static const double fontSizeS = 12.0;
  static const double fontSizeM = 14.0;
  static const double fontSizeL = 16.0;
  static const double fontSizeXL = 18.0;
  static const double fontSizeXXL = 24.0;
  
  // Icon sizes
  static const double iconSizeXS = 16.0;
  static const double iconSizeS = 20.0;
  static const double iconSizeM = 24.0;
  static const double iconSizeL = 32.0;
  static const double iconSizeXL = 48.0;
  
  // ==========================================
  // SUBTLE OVERLAY SYSTEM
  // ==========================================
  
  /// Subtle gradient overlay for cards - adds depth
  static BoxDecoration? getCardOverlay({
    Color? accentColor,
    double intensity = 0.03,
  }) {
    final overlayColor = accentColor ?? AppColors.primaryRed;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(cardBorderRadius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          overlayColor.withOpacity(intensity),
          Colors.transparent,
          Colors.transparent,
          overlayColor.withOpacity(intensity * 0.5),
        ],
        stops: const [0.0, 0.3, 0.7, 1.0],
      ),
    );
  }
  
  /// Subtle press/hover overlay for interactive elements
  static BoxDecoration? getPressOverlay({
    Color? baseColor,
    bool isPressed = false,
  }) {
    if (!isPressed) return null;
    final overlayColor = baseColor ?? AppColors.primaryRed;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(buttonBorderRadius),
      color: overlayColor.withOpacity(0.08),
    );
  }
  
  /// Subtle radial overlay for highlighted items
  static Widget buildRadialOverlay({
    required Color color,
    double opacity = 0.06,
    Alignment alignment = Alignment.topLeft,
  }) {
    return IgnorePointer(
      ignoring: true,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(cardBorderRadius),
          gradient: RadialGradient(
            center: alignment,
            radius: 1.2,
            colors: [
              color.withOpacity(opacity),
              color.withOpacity(opacity * 0.5),
              Colors.transparent,
            ],
            stops: const [0.0, 0.4, 1.0],
          ),
        ),
      ),
    );
  }
  
  /// Subtle glow overlay for important elements
  static List<BoxShadow> getGlowOverlay({
    required Color color,
    double intensity = 0.15,
    double blur = 12.0,
  }) {
    return [
      BoxShadow(
        color: color.withOpacity(intensity),
        blurRadius: blur,
        spreadRadius: 2.0,
        offset: Offset.zero,
      ),
    ];
  }
  
  /// Subtle backdrop overlay for modals
  static Color getModalBackdrop({double opacity = 0.4}) {
    return Colors.black.withOpacity(opacity);
  }
  
  /// Subtle status indicator overlay
  static BoxDecoration? getStatusOverlay({
    required Color statusColor,
    bool isActive = false,
  }) {
    if (!isActive) return null;
    return BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: getGlowOverlay(
        color: statusColor,
        intensity: 0.2,
        blur: 8.0,
      ),
    );
  }
  
  /// Subtle accent overlay for profile headers
  static List<Widget> buildProfileHeaderOverlays() {
    return [
      // Top-right decorative circle
      Positioned(
        top: -22,
        right: -18,
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
        ),
      ),
      // Middle-right decorative circle
      Positioned(
        top: 6,
        right: 38,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            shape: BoxShape.circle,
          ),
        ),
      ),
      // Bottom-left decorative circle
      Positioned(
        bottom: -28,
        left: -24,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
        ),
      ),
    ];
  }
  
  /// Subtle depth overlay for elevated cards
  static Widget? buildDepthOverlay({
    Color? accentColor,
    double elevation = 4.0,
  }) {
    if (elevation < 3.0) return null;
    final overlayColor = accentColor ?? AppColors.primaryRed;
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cardBorderRadius),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                overlayColor.withOpacity(0.02),
                Colors.transparent,
                overlayColor.withOpacity(0.01),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // ADVANCED OVERLAY SYSTEM
  // ==========================================

  /// Screen-level subtle background gradient overlay
  static Widget buildScreenBackgroundOverlay({
    Color? accentColor,
    double intensity = 0.015,
  }) {
    final overlayColor = accentColor ?? AppColors.primaryRed;
    return IgnorePointer(
      ignoring: true,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              overlayColor.withOpacity(intensity),
              Colors.transparent,
              overlayColor.withOpacity(intensity * 0.6),
              Colors.transparent,
            ],
            stops: const [0.0, 0.25, 0.75, 1.0],
          ),
        ),
      ),
    );
  }

  /// Subtle diagonal gradient overlay for cards
  static Widget buildDiagonalOverlay({
    Color? accentColor,
    double intensity = 0.04,
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
  }) {
    final overlayColor = accentColor ?? AppColors.primaryRed;
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cardBorderRadius),
            gradient: LinearGradient(
              begin: begin,
              end: end,
              colors: [
                overlayColor.withOpacity(intensity),
                Colors.transparent,
                overlayColor.withOpacity(intensity * 0.4),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  /// Multi-layer gradient overlay for rich depth
  static Widget buildLayeredGradientOverlay({
    Color? primaryColor,
    Color? secondaryColor,
    double primaryIntensity = 0.025,
    double secondaryIntensity = 0.015,
  }) {
    final primary = primaryColor ?? AppColors.primaryRed;
    final secondary = secondaryColor ?? AppColors.info;
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cardBorderRadius),
            gradient: RadialGradient(
              center: Alignment.topLeft,
              radius: 1.5,
              colors: [
                primary.withOpacity(primaryIntensity),
                Colors.transparent,
                secondary.withOpacity(secondaryIntensity),
                Colors.transparent,
              ],
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  /// Subtle shimmer-like overlay for special cards
  static Widget buildShimmerOverlay({
    Color? accentColor,
    double opacity = 0.03,
  }) {
    final overlayColor = accentColor ?? AppColors.primaryRed;
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cardBorderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0, -0.5),
              end: Alignment(1.0, 0.5),
              colors: [
                Colors.transparent,
                overlayColor.withOpacity(opacity),
                Colors.transparent,
                overlayColor.withOpacity(opacity * 0.5),
                Colors.transparent,
              ],
              stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
            ),
          ),
        ),
      ),
    );
  }

  /// Corner accent overlay for highlighted cards
  static Widget buildCornerAccentOverlay({
    Color? accentColor,
    Alignment alignment = Alignment.topRight,
    double size = 80,
    double opacity = 0.08,
  }) {
    final overlayColor = accentColor ?? AppColors.primaryRed;
    return Positioned(
      top: alignment == Alignment.topRight || alignment == Alignment.topLeft ? -size * 0.3 : null,
      bottom: alignment == Alignment.bottomRight || alignment == Alignment.bottomLeft ? -size * 0.3 : null,
      right: alignment == Alignment.topRight || alignment == Alignment.bottomRight ? -size * 0.3 : null,
      left: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft ? -size * 0.3 : null,
      child: IgnorePointer(
        ignoring: true,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: overlayColor.withOpacity(opacity),
          ),
        ),
      ),
    );
  }

  /// Subtle border glow overlay
  static List<BoxShadow> getBorderGlow({
    required Color color,
    double intensity = 0.12,
    double blur = 10.0,
  }) {
    return [
      BoxShadow(
        color: color.withOpacity(intensity),
        blurRadius: blur,
        spreadRadius: 1.0,
        offset: Offset.zero,
      ),
      BoxShadow(
        color: color.withOpacity(intensity * 0.5),
        blurRadius: blur * 1.5,
        spreadRadius: 0.5,
        offset: Offset.zero,
      ),
    ];
  }

  /// Interactive press feedback overlay
  static Widget buildPressFeedbackOverlay({
    required Color color,
    required bool isPressed,
    double intensity = 0.10,
  }) {
    if (!isPressed) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(buttonBorderRadius),
            color: color.withOpacity(intensity),
          ),
        ),
      ),
    );
  }

  /// Subtle pattern overlay (dot pattern)
  static Widget buildDotPatternOverlay({
    Color? color,
    double spacing = 20.0,
    double dotSize = 1.5,
    double opacity = 0.04,
  }) {
    final overlayColor = color ?? AppColors.primaryRed;
    return IgnorePointer(
      ignoring: true,
      child: CustomPaint(
        painter: _DotPatternPainter(
          color: overlayColor.withOpacity(opacity),
          spacing: spacing,
          dotSize: dotSize,
        ),
      ),
    );
  }

  /// Enhanced card with multiple overlays
  static Widget buildEnhancedCard({
    required Widget child,
    Color? backgroundColor,
    double? borderRadius,
    double elevation = 4.0,
    Color? borderColor,
    bool showBorder = false,
    bool showDepthOverlay = true,
    bool showDiagonalOverlay = false,
    bool showCornerAccent = false,
    Color? accentColor,
  }) {
    return Container(
      decoration: cardDecoration(
        backgroundColor: backgroundColor,
        borderRadius: borderRadius,
        elevation: elevation,
        borderColor: borderColor,
        showBorder: showBorder,
      ),
      child: Stack(
        children: [
          // Depth overlay
          if (showDepthOverlay && elevation >= 3.0)
            buildDepthOverlay(
              accentColor: accentColor,
              elevation: elevation,
            ) ?? const SizedBox.shrink(),
          
          // Diagonal overlay
          if (showDiagonalOverlay)
            buildDiagonalOverlay(
              accentColor: accentColor,
              intensity: 0.04,
            ),
          
          // Corner accent
          if (showCornerAccent)
            buildCornerAccentOverlay(
              accentColor: accentColor,
              alignment: Alignment.topRight,
              opacity: 0.08,
            ),
          
          // Content
          child,
        ],
      ),
    );
  }
}

/// Custom painter for dot pattern overlay
class _DotPatternPainter extends CustomPainter {
  final Color color;
  final double spacing;
  final double dotSize;

  _DotPatternPainter({
    required this.color,
    required this.spacing,
    required this.dotSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotSize, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPatternPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.spacing != spacing ||
        oldDelegate.dotSize != dotSize;
  }
}

