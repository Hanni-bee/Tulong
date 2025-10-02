import 'package:flutter/material.dart';
import '../constants/app_spacing.dart';

class ResponsiveSpacing {
  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  static bool isSmallScreen(BuildContext context) {
    return getScreenWidth(context) < 360;
  }

  static bool isMediumScreen(BuildContext context) {
    final width = getScreenWidth(context);
    return width >= 360 && width < 600;
  }

  static bool isLargeScreen(BuildContext context) {
    return getScreenWidth(context) >= 600;
  }

  // Responsive spacing based on screen size
  static double getResponsiveSpacing(BuildContext context, {
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
  }) {
    if (isSmallScreen(context)) {
      return xs ?? AppSpacing.xs;
    } else if (isMediumScreen(context)) {
      return sm ?? AppSpacing.sm;
    } else if (isLargeScreen(context)) {
      return md ?? AppSpacing.md;
    }
    return lg ?? AppSpacing.lg;
  }

  // Responsive padding
  static EdgeInsets getResponsivePadding(BuildContext context, {
    double? horizontal,
    double? vertical,
    double? all,
  }) {
    final responsiveHorizontal = horizontal ?? getResponsiveSpacing(context);
    final responsiveVertical = vertical ?? getResponsiveSpacing(context);
    
    if (all != null) {
      return EdgeInsets.all(getResponsiveSpacing(context, xs: all * 0.5, sm: all * 0.75, md: all));
    }
    
    return EdgeInsets.symmetric(
      horizontal: responsiveHorizontal,
      vertical: responsiveVertical,
    );
  }

  // Responsive margin
  static EdgeInsets getResponsiveMargin(BuildContext context, {
    double? horizontal,
    double? vertical,
    double? all,
  }) {
    return getResponsivePadding(context, 
      horizontal: horizontal, 
      vertical: vertical, 
      all: all
    );
  }

  // Responsive font size
  static double getResponsiveFontSize(BuildContext context, {
    double? small,
    double? medium,
    double? large,
  }) {
    if (isSmallScreen(context)) {
      return small ?? 12;
    } else if (isMediumScreen(context)) {
      return medium ?? 14;
    } else {
      return large ?? 16;
    }
  }

  // Responsive icon size
  static double getResponsiveIconSize(BuildContext context, {
    double? small,
    double? medium,
    double? large,
  }) {
    if (isSmallScreen(context)) {
      return small ?? AppSpacing.iconSm;
    } else if (isMediumScreen(context)) {
      return medium ?? AppSpacing.iconMd;
    } else {
      return large ?? AppSpacing.iconLg;
    }
  }

  // Responsive card height
  static double getResponsiveCardHeight(BuildContext context, {
    double? small,
    double? medium,
    double? large,
  }) {
    if (isSmallScreen(context)) {
      return small ?? 60;
    } else if (isMediumScreen(context)) {
      return medium ?? 80;
    } else {
      return large ?? 100;
    }
  }

  // Responsive button height
  static double getResponsiveButtonHeight(BuildContext context, {
    double? small,
    double? medium,
    double? large,
  }) {
    if (isSmallScreen(context)) {
      return small ?? AppSpacing.buttonSm;
    } else if (isMediumScreen(context)) {
      return medium ?? AppSpacing.buttonMd;
    } else {
      return large ?? AppSpacing.buttonLg;
    }
  }

  // Safe area padding
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return EdgeInsets.only(
      top: mediaQuery.padding.top,
      bottom: mediaQuery.padding.bottom,
      left: getResponsiveSpacing(context),
      right: getResponsiveSpacing(context),
    );
  }

  // Screen content padding
  static EdgeInsets getScreenPadding(BuildContext context) {
    return EdgeInsets.all(getResponsiveSpacing(context));
  }

  // List item spacing
  static double getListItemSpacing(BuildContext context) {
    return getResponsiveSpacing(context, xs: 8, sm: 12, md: 16);
  }

  // Grid spacing
  static double getGridSpacing(BuildContext context) {
    return getResponsiveSpacing(context, xs: 4, sm: 8, md: 12);
  }
}
