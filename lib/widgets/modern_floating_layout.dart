import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class ModernFloatingLayout extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool enableSafeArea;
  final Color? backgroundColor;
  final bool hasFloatingAppBar;
  final bool hasFloatingBottomBar;

  const ModernFloatingLayout({
    super.key,
    required this.child,
    this.padding,
    this.enableSafeArea = true,
    this.backgroundColor,
    this.hasFloatingAppBar = false,
    this.hasFloatingBottomBar = true,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isDesktop = screenWidth > 900;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.backgroundLight,
      ),
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
    double topPadding = 0;
    double bottomPadding = 0;
    
    // Account for floating app bar
    if (hasFloatingAppBar) {
      topPadding = 40.0; // Reduced from 60
    }
    
    // Account for floating bottom bar
    if (hasFloatingBottomBar) {
      bottomPadding = 5.0; // Reduced from 10
    }
    
    if (isDesktop) {
      return EdgeInsets.fromLTRB(
        4, // Reduced from 8
        1 + topPadding, // Reduced from 2
        4, // Reduced from 8
        1 + bottomPadding, // Reduced from 2
      );
    } else if (isTablet) {
      return EdgeInsets.fromLTRB(
        4, // Reduced from 8
        1 + topPadding, // Reduced from 2
        4, // Reduced from 8
        1 + bottomPadding, // Reduced from 2
      );
    } else {
      return EdgeInsets.fromLTRB(
        4, // Reduced from 8
        1 + topPadding, // Reduced from 2
        4, // Reduced from 8
        1 + bottomPadding, // Reduced from 2
      );
    }
  }
}

class ModernFloatingContentLayout extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const ModernFloatingContentLayout({
    super.key,
    required this.child,
    this.padding,
    this.controller,
    this.shrinkWrap = false,
    this.physics,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: controller,
      physics: physics ?? const BouncingScrollPhysics(),
      padding: padding ?? const EdgeInsets.all(8), // Reduced from 16
      child: child,
    );
  }
}

class ModernFloatingAppBarLayout extends StatelessWidget {
  final Widget child;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  const ModernFloatingAppBarLayout({
    super.key,
    required this.child,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      extendBodyBehindAppBar: true,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      body: child,
    );
  }
}
