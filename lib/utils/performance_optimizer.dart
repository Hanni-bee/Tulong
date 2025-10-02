import 'package:flutter/material.dart';

class PerformanceOptimizer {
  // Optimize list performance by limiting items
  static const int maxListItems = 50;
  
  // Optimize image loading
  static const int maxImageCacheSize = 100;
  
  // Optimize animation performance
  static const Duration fastAnimationDuration = Duration(milliseconds: 200);
  static const Duration normalAnimationDuration = Duration(milliseconds: 300);
  
  // Memory management
  static void clearImageCache() {
    imageCache.clear();
    imageCache.clearLiveImages();
  }
  
  // Optimize list builder with pagination
  static Widget buildOptimizedListView({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    ScrollController? controller,
    EdgeInsetsGeometry? padding,
    bool shrinkWrap = false,
  }) {
    final optimizedItemCount = itemCount > maxListItems ? maxListItems : itemCount;
    
    return ListView.builder(
      controller: controller,
      padding: padding,
      shrinkWrap: shrinkWrap,
      itemCount: optimizedItemCount,
      itemBuilder: itemBuilder,
      // Performance optimizations
      cacheExtent: 200.0, // Limit cache extent
      addAutomaticKeepAlives: false, // Don't keep items alive
      addRepaintBoundaries: true, // Add repaint boundaries
      addSemanticIndexes: false, // Disable semantic indexes for performance
    );
  }
  
  // Optimize grid view
  static Widget buildOptimizedGridView({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    required int crossAxisCount,
    double? childAspectRatio,
    double? crossAxisSpacing,
    double? mainAxisSpacing,
    ScrollController? controller,
    EdgeInsetsGeometry? padding,
    bool shrinkWrap = false,
  }) {
    final optimizedItemCount = itemCount > maxListItems ? maxListItems : itemCount;
    
    return GridView.builder(
      controller: controller,
      padding: padding,
      shrinkWrap: shrinkWrap,
      itemCount: optimizedItemCount,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio ?? 1.0,
        crossAxisSpacing: crossAxisSpacing ?? 0.0,
        mainAxisSpacing: mainAxisSpacing ?? 0.0,
      ),
      itemBuilder: itemBuilder,
      // Performance optimizations
      cacheExtent: 200.0,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      addSemanticIndexes: false,
    );
  }
  
  // Optimize animations
  static AnimationController createOptimizedController({
    required TickerProvider vsync,
    Duration duration = normalAnimationDuration,
  }) {
    return AnimationController(
      duration: duration,
      vsync: vsync,
    );
  }
  
  // Debounce function for search
  static void debounce({
    required Duration delay,
    required VoidCallback callback,
  }) {
    Future.delayed(delay, callback);
  }
  
  // Optimize image loading
  static Widget buildOptimizedImage({
    required String imagePath,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    return Image.asset(
      imagePath,
      width: width,
      height: height,
      fit: fit,
      // Performance optimizations
      cacheWidth: width?.toInt(),
      cacheHeight: height?.toInt(),
      filterQuality: FilterQuality.medium, // Balance quality and performance
    );
  }
  
  // Memory cleanup
  static void cleanup() {
    clearImageCache();
    // Force garbage collection
    // Note: This is not recommended in production
    // System.gc() equivalent would be called automatically
  }
}

class OptimizedScrollView extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;

  const OptimizedScrollView({
    super.key,
    required this.child,
    this.padding,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: controller,
      padding: padding,
      // Performance optimizations
      physics: const BouncingScrollPhysics(),
      clipBehavior: Clip.none,
    );
  }
}
