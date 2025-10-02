import 'package:flutter/material.dart';

/// Comprehensive responsive helper specifically designed for phone screen sizes
/// Ensures the app adapts perfectly to all phone screen sizes from small to large
class PhoneResponsiveHelper {
  // Phone screen size breakpoints (in logical pixels)
  static const double smallPhoneWidth = 320;  // iPhone SE, small Android phones
  static const double mediumPhoneWidth = 375; // iPhone 12/13/14 standard
  static const double largePhoneWidth = 414;  // iPhone 12/13/14 Plus/Pro Max
  static const double extraLargePhoneWidth = 480; // Large Android phones, foldables

  // Screen size detection
  static bool isSmallPhone(BuildContext context) {
    return MediaQuery.of(context).size.width < mediumPhoneWidth;
  }

  static bool isMediumPhone(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mediumPhoneWidth && width < largePhoneWidth;
  }

  static bool isLargePhone(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= largePhoneWidth && width < extraLargePhoneWidth;
  }

  static bool isExtraLargePhone(BuildContext context) {
    return MediaQuery.of(context).size.width >= extraLargePhoneWidth;
  }

  // Responsive padding based on phone size
  static EdgeInsets getPhonePadding(BuildContext context) {
    if (isSmallPhone(context)) {
      return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    } else if (isMediumPhone(context)) {
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    } else if (isLargePhone(context)) {
      return const EdgeInsets.symmetric(horizontal: 20, vertical: 16);
    } else {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 20);
    }
  }

  // Responsive font sizes for phones
  static double getPhoneFontSize(BuildContext context, {
    double? small,
    double? medium,
    double? large,
    double? extraLarge,
  }) {
    if (isSmallPhone(context)) {
      return small ?? 12;
    } else if (isMediumPhone(context)) {
      return medium ?? 14;
    } else if (isLargePhone(context)) {
      return large ?? 16;
    } else {
      return extraLarge ?? 18;
    }
  }

  // Responsive icon sizes
  static double getPhoneIconSize(BuildContext context, {
    double? small,
    double? medium,
    double? large,
    double? extraLarge,
  }) {
    if (isSmallPhone(context)) {
      return small ?? 16;
    } else if (isMediumPhone(context)) {
      return medium ?? 20;
    } else if (isLargePhone(context)) {
      return large ?? 24;
    } else {
      return extraLarge ?? 28;
    }
  }

  // Responsive button heights
  static double getPhoneButtonHeight(BuildContext context) {
    if (isSmallPhone(context)) {
      return 40;
    } else if (isMediumPhone(context)) {
      return 44;
    } else if (isLargePhone(context)) {
      return 48;
    } else {
      return 52;
    }
  }

  // Responsive card heights
  static double getPhoneCardHeight(BuildContext context) {
    if (isSmallPhone(context)) {
      return 80;
    } else if (isMediumPhone(context)) {
      return 100;
    } else if (isLargePhone(context)) {
      return 120;
    } else {
      return 140;
    }
  }

  // Responsive spacing between elements
  static double getPhoneSpacing(BuildContext context) {
    if (isSmallPhone(context)) {
      return 8;
    } else if (isMediumPhone(context)) {
      return 12;
    } else if (isLargePhone(context)) {
      return 16;
    } else {
      return 20;
    }
  }

  // Responsive border radius
  static double getPhoneBorderRadius(BuildContext context) {
    if (isSmallPhone(context)) {
      return 8;
    } else if (isMediumPhone(context)) {
      return 12;
    } else if (isLargePhone(context)) {
      return 16;
    } else {
      return 20;
    }
  }

  // Responsive grid columns for phones
  static int getPhoneGridColumns(BuildContext context) {
    if (isSmallPhone(context)) {
      return 2;
    } else if (isMediumPhone(context)) {
      return 3;
    } else if (isLargePhone(context)) {
      return 4;
    } else {
      return 5;
    }
  }

  // Responsive list item height
  static double getPhoneListItemHeight(BuildContext context) {
    if (isSmallPhone(context)) {
      return 60;
    } else if (isMediumPhone(context)) {
      return 70;
    } else if (isLargePhone(context)) {
      return 80;
    } else {
      return 90;
    }
  }

  // Responsive app bar height
  static double getPhoneAppBarHeight(BuildContext context) {
    if (isSmallPhone(context)) {
      return 50;
    } else if (isMediumPhone(context)) {
      return 56;
    } else if (isLargePhone(context)) {
      return 60;
    } else {
      return 64;
    }
  }

  // Responsive bottom navigation height
  static double getPhoneBottomNavHeight(BuildContext context) {
    if (isSmallPhone(context)) {
      return 50;
    } else if (isMediumPhone(context)) {
      return 55;
    } else if (isLargePhone(context)) {
      return 60;
    } else {
      return 65;
    }
  }

  // Responsive contact card width
  static double getPhoneContactCardWidth(BuildContext context) {
    if (isSmallPhone(context)) {
      return 80;
    } else if (isMediumPhone(context)) {
      return 90;
    } else if (isLargePhone(context)) {
      return 100;
    } else {
      return 110;
    }
  }

  // Responsive contact avatar size
  static double getPhoneContactAvatarSize(BuildContext context) {
    if (isSmallPhone(context)) {
      return 50;
    } else if (isMediumPhone(context)) {
      return 55;
    } else if (isLargePhone(context)) {
      return 60;
    } else {
      return 65;
    }
  }

  // Safe area handling for phones
  static EdgeInsets getPhoneSafeArea(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return EdgeInsets.only(
      top: mediaQuery.padding.top,
      bottom: mediaQuery.padding.bottom,
      left: getPhonePadding(context).horizontal / 2,
      right: getPhonePadding(context).horizontal / 2,
    );
  }

  // Orientation handling
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  // Screen width and height
  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  // Responsive text scale factor
  static double getTextScaleFactor(BuildContext context) {
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    // Clamp text scale factor to reasonable bounds for phones
    return textScaleFactor.clamp(0.8, 1.3);
  }
}

/// Responsive widget builder for phone screens
class PhoneResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, PhoneScreenSize screenSize) builder;

  const PhoneResponsiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    PhoneScreenSize screenSize;
    
    if (PhoneResponsiveHelper.isSmallPhone(context)) {
      screenSize = PhoneScreenSize.small;
    } else if (PhoneResponsiveHelper.isMediumPhone(context)) {
      screenSize = PhoneScreenSize.medium;
    } else if (PhoneResponsiveHelper.isLargePhone(context)) {
      screenSize = PhoneScreenSize.large;
    } else {
      screenSize = PhoneScreenSize.extraLarge;
    }

    return builder(context, screenSize);
  }
}

/// Phone screen size enum
enum PhoneScreenSize {
  small,
  medium,
  large,
  extraLarge,
}

/// Responsive text widget for phones
class PhoneResponsiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final PhoneTextSize? textSize;

  const PhoneResponsiveText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.textSize,
  });

  @override
  Widget build(BuildContext context) {
    double fontSize;
    
    switch (textSize) {
      case PhoneTextSize.title:
        fontSize = PhoneResponsiveHelper.getPhoneFontSize(context, small: 18, medium: 20, large: 22, extraLarge: 24);
        break;
      case PhoneTextSize.subtitle:
        fontSize = PhoneResponsiveHelper.getPhoneFontSize(context, small: 14, medium: 16, large: 18, extraLarge: 20);
        break;
      case PhoneTextSize.body:
        fontSize = PhoneResponsiveHelper.getPhoneFontSize(context, small: 12, medium: 14, large: 16, extraLarge: 18);
        break;
      case PhoneTextSize.caption:
        fontSize = PhoneResponsiveHelper.getPhoneFontSize(context, small: 10, medium: 12, large: 14, extraLarge: 16);
        break;
      case null:
        fontSize = PhoneResponsiveHelper.getPhoneFontSize(context);
        break;
    }

    return Text(
      text,
      style: style?.copyWith(fontSize: fontSize) ?? TextStyle(fontSize: fontSize),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Phone text size enum
enum PhoneTextSize {
  title,
  subtitle,
  body,
  caption,
}

/// Responsive container for phones
class PhoneResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? color;
  final Decoration? decoration;
  final BoxConstraints? constraints;

  const PhoneResponsiveContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.color,
    this.decoration,
    this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      padding: padding ?? PhoneResponsiveHelper.getPhonePadding(context),
      margin: margin,
      decoration: decoration,
      color: color,
      constraints: constraints,
      child: child,
    );
  }
}

/// Responsive grid view for phones
class PhoneResponsiveGridView extends StatelessWidget {
  final List<Widget> children;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;
  final int? crossAxisCount;
  final ScrollController? controller;
  final ScrollPhysics? physics;

  const PhoneResponsiveGridView({
    super.key,
    required this.children,
    this.crossAxisSpacing = 12.0,
    this.mainAxisSpacing = 12.0,
    this.childAspectRatio = 1.0,
    this.crossAxisCount,
    this.controller,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: controller,
      physics: physics ?? const BouncingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount ?? PhoneResponsiveHelper.getPhoneGridColumns(context),
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}
