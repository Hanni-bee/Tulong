import 'package:flutter/material.dart';

class ResponsiveHelper {
  // Enhanced screen size detection
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 768;
  }

  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= 768 && MediaQuery.of(context).size.width < 1024;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1024;
  }

  static bool isSmallMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 360;
  }

  static bool isLargeMobile(BuildContext context) {
    return MediaQuery.of(context).size.width >= 360 && MediaQuery.of(context).size.width < 768;
  }

  static bool isLargeTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1024 && MediaQuery.of(context).size.width < 1440;
  }

  static bool isUltraWide(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1440;
  }

  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  static double getResponsivePadding(BuildContext context) {
    if (isSmallMobile(context)) {
      return 12.0;
    } else if (isLargeMobile(context)) {
      return 16.0;
    } else if (isTablet(context)) {
      return 24.0;
    } else if (isLargeTablet(context)) {
      return 28.0;
    } else {
      return 32.0;
    }
  }

  static double getResponsiveFontSize(BuildContext context, double baseFontSize) {
    if (isSmallMobile(context)) {
      return baseFontSize * 0.9;
    } else if (isLargeMobile(context)) {
      return baseFontSize;
    } else if (isTablet(context)) {
      return baseFontSize * 1.1;
    } else if (isLargeTablet(context)) {
      return baseFontSize * 1.15;
    } else {
      return baseFontSize * 1.2;
    }
  }

  static int getGridCrossAxisCount(BuildContext context) {
    if (isSmallMobile(context)) {
      return 1;
    } else if (isLargeMobile(context)) {
      return 2;
    } else if (isTablet(context)) {
      return 3;
    } else if (isLargeTablet(context)) {
      return 4;
    } else {
      return 5;
    }
  }

  static double getGridChildAspectRatio(BuildContext context) {
    if (isSmallMobile(context)) {
      return 0.8;
    } else if (isLargeMobile(context)) {
      return 1.0;
    } else if (isTablet(context)) {
      return 1.2;
    } else if (isLargeTablet(context)) {
      return 1.25;
    } else {
      return 1.3;
    }
  }

  static EdgeInsets getResponsiveEdgeInsets(BuildContext context) {
    final padding = getResponsivePadding(context);
    return EdgeInsets.all(padding);
  }

  static double getResponsiveSpacing(BuildContext context) {
    if (isSmallMobile(context)) {
      return 12.0;
    } else if (isLargeMobile(context)) {
      return 16.0;
    } else if (isTablet(context)) {
      return 20.0;
    } else if (isLargeTablet(context)) {
      return 22.0;
    } else {
      return 24.0;
    }
  }

  // Enhanced responsive methods
  static double getResponsiveIconSize(BuildContext context, double baseSize) {
    if (isSmallMobile(context)) {
      return baseSize * 0.8;
    } else if (isLargeMobile(context)) {
      return baseSize;
    } else if (isTablet(context)) {
      return baseSize * 1.1;
    } else if (isLargeTablet(context)) {
      return baseSize * 1.15;
    } else {
      return baseSize * 1.2;
    }
  }

  static double getResponsiveButtonHeight(BuildContext context) {
    if (isSmallMobile(context)) {
      return 40.0;
    } else if (isLargeMobile(context)) {
      return 48.0;
    } else if (isTablet(context)) {
      return 52.0;
    } else if (isLargeTablet(context)) {
      return 56.0;
    } else {
      return 60.0;
    }
  }

  static double getResponsiveCardHeight(BuildContext context) {
    if (isSmallMobile(context)) {
      return 80.0;
    } else if (isLargeMobile(context)) {
      return 100.0;
    } else if (isTablet(context)) {
      return 120.0;
    } else if (isLargeTablet(context)) {
      return 140.0;
    } else {
      return 160.0;
    }
  }

  static EdgeInsets getResponsiveMargin(BuildContext context) {
    final margin = getResponsivePadding(context) * 0.5;
    return EdgeInsets.all(margin);
  }

  static double getResponsiveBorderRadius(BuildContext context) {
    if (isSmallMobile(context)) {
      return 8.0;
    } else if (isLargeMobile(context)) {
      return 12.0;
    } else if (isTablet(context)) {
      return 16.0;
    } else if (isLargeTablet(context)) {
      return 18.0;
    } else {
      return 20.0;
    }
  }

  static double getResponsiveElevation(BuildContext context) {
    if (isSmallMobile(context)) {
      return 2.0;
    } else if (isLargeMobile(context)) {
      return 4.0;
    } else if (isTablet(context)) {
      return 6.0;
    } else if (isLargeTablet(context)) {
      return 8.0;
    } else {
      return 10.0;
    }
  }

  // Safe area handling
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return EdgeInsets.only(
      top: mediaQuery.padding.top,
      bottom: mediaQuery.padding.bottom,
      left: mediaQuery.padding.left,
      right: mediaQuery.padding.right,
    );
  }

  // Orientation handling
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  // Screen density handling
  static double getPixelRatio(BuildContext context) {
    return MediaQuery.of(context).devicePixelRatio;
  }

  static bool isHighDensity(BuildContext context) {
    return getPixelRatio(context) > 2.0;
  }
}

class ResponsiveBuilder extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    if (ResponsiveHelper.isDesktop(context) && desktop != null) {
      return desktop!;
    } else if (ResponsiveHelper.isTablet(context) && tablet != null) {
      return tablet!;
    } else {
      return mobile;
    }
  }
}

class ResponsiveScrollView extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final bool primary;

  const ResponsiveScrollView({
    super.key,
    required this.child,
    this.padding,
    this.controller,
    this.shrinkWrap = false,
    this.physics,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: controller,
      physics: physics ?? const BouncingScrollPhysics(),
      padding: padding ?? ResponsiveHelper.getResponsiveEdgeInsets(context),
      child: child,
    );
  }
}

// Enhanced responsive container
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Color? color;
  final Decoration? decoration;
  final BoxConstraints? constraints;

  const ResponsiveContainer({
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
      padding: padding ?? ResponsiveHelper.getResponsiveEdgeInsets(context),
      margin: margin ?? ResponsiveHelper.getResponsiveMargin(context),
      decoration: decoration,
      color: color,
      constraints: constraints,
      child: child,
    );
  }
}

// Responsive grid view
class ResponsiveGridView extends StatelessWidget {
  final List<Widget> children;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;
  final int? crossAxisCount;
  final ScrollController? controller;
  final ScrollPhysics? physics;

  const ResponsiveGridView({
    super.key,
    required this.children,
    this.crossAxisSpacing = 16.0,
    this.mainAxisSpacing = 16.0,
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
        crossAxisCount: crossAxisCount ?? ResponsiveHelper.getGridCrossAxisCount(context),
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}

// Responsive text widget
class ResponsiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const ResponsiveText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style?.copyWith(
        fontSize: style?.fontSize != null 
            ? ResponsiveHelper.getResponsiveFontSize(context, style!.fontSize!)
            : null,
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
