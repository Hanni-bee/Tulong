import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class ModernResponsiveLayout extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool enableSafeArea;
  final Color? backgroundColor;

  const ModernResponsiveLayout({
    super.key,
    required this.child,
    this.padding,
    this.enableSafeArea = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isDesktop = screenWidth > 900;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: backgroundColor ?? AppColors.backgroundLight,
      child: enableSafeArea
          ? SafeArea(
              child: Padding(
                padding: padding ?? _getResponsivePadding(context, isTablet, isDesktop),
                child: child,
              ),
            )
          : Padding(
              padding: padding ?? _getResponsivePadding(context, isTablet, isDesktop),
              child: child,
            ),
    );
  }

  EdgeInsetsGeometry _getResponsivePadding(BuildContext context, bool isTablet, bool isDesktop) {
    // Add extra bottom padding to account for floating bottom bar (reduced)
    final bottomPadding = 80.0; // Reduced from 120
    
    if (isDesktop) {
      return const EdgeInsets.fromLTRB(16, 12, 16, 92); // Reduced padding
    } else if (isTablet) {
      return const EdgeInsets.fromLTRB(12, 10, 12, 90); // Reduced padding
    } else {
      return const EdgeInsets.fromLTRB(8, 8, 8, 88); // Reduced padding
    }
  }
}

class ModernResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int? crossAxisCount;
  final double? childAspectRatio;
  final double? crossAxisSpacing;
  final double? mainAxisSpacing;
  final EdgeInsetsGeometry? padding;

  const ModernResponsiveGrid({
    super.key,
    required this.children,
    this.crossAxisCount,
    this.childAspectRatio,
    this.crossAxisSpacing,
    this.mainAxisSpacing,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isDesktop = screenWidth > 900;

    int gridCrossAxisCount = crossAxisCount ?? _getResponsiveCrossAxisCount(isTablet, isDesktop);
    double gridChildAspectRatio = childAspectRatio ?? _getResponsiveAspectRatio(isTablet, isDesktop);
    double gridCrossAxisSpacing = crossAxisSpacing ?? (isDesktop ? 24 : isTablet ? 20 : 16);
    double gridMainAxisSpacing = mainAxisSpacing ?? (isDesktop ? 24 : isTablet ? 20 : 16);

    return Padding(
      padding: padding ?? EdgeInsets.zero,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: gridCrossAxisCount,
          childAspectRatio: gridChildAspectRatio,
          crossAxisSpacing: gridCrossAxisSpacing,
          mainAxisSpacing: gridMainAxisSpacing,
        ),
        itemCount: children.length,
        itemBuilder: (context, index) => children[index],
      ),
    );
  }

  int _getResponsiveCrossAxisCount(bool isTablet, bool isDesktop) {
    if (isDesktop) return 4;
    if (isTablet) return 3;
    return 2;
  }

  double _getResponsiveAspectRatio(bool isTablet, bool isDesktop) {
    if (isDesktop) return 1.2;
    if (isTablet) return 1.1;
    return 1.0;
  }
}

class ModernResponsiveList extends StatelessWidget {
  final List<Widget> children;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const ModernResponsiveList({
    super.key,
    required this.children,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isDesktop = screenWidth > 900;

    return ListView.builder(
      controller: controller,
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: padding ?? _getResponsivePadding(isTablet, isDesktop),
      itemCount: children.length,
      itemBuilder: (context, index) => Padding(
        padding: EdgeInsets.only(
          bottom: index < children.length - 1 
              ? (isDesktop ? 16 : isTablet ? 14 : 12)
              : 0,
        ),
        child: children[index],
      ),
    );
  }

  EdgeInsetsGeometry _getResponsivePadding(bool isTablet, bool isDesktop) {
    if (isDesktop) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
    } else if (isTablet) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    } else {
      return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    }
  }
}

class ModernResponsiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool isTitle;
  final bool isSubtitle;
  final bool isCaption;

  const ModernResponsiveText({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.isTitle = false,
    this.isSubtitle = false,
    this.isCaption = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isDesktop = screenWidth > 900;

    TextStyle responsiveStyle = _getResponsiveTextStyle(context, isTablet, isDesktop);

    return Text(
      text,
      style: style ?? responsiveStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  TextStyle _getResponsiveTextStyle(BuildContext context, bool isTablet, bool isDesktop) {
    if (isTitle) {
      return TextStyle(
        fontSize: isDesktop ? 28 : isTablet ? 24 : 20,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      );
    } else if (isSubtitle) {
      return TextStyle(
        fontSize: isDesktop ? 20 : isTablet ? 18 : 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );
    } else if (isCaption) {
      return TextStyle(
        fontSize: isDesktop ? 14 : isTablet ? 13 : 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      );
    } else {
      return TextStyle(
        fontSize: isDesktop ? 16 : isTablet ? 15 : 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      );
    }
  }
}
