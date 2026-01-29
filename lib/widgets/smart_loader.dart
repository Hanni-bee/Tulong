import 'package:flutter/material.dart';
import 'enhanced_skeleton_loaders.dart';
import 'modern_loading_indicator.dart';

/// Unified loading state widget that provides consistent loading
/// experiences across the app based on context.
enum LoadingType {
  /// For lists of items (users, messages, etc.)
  list,
  
  /// For card-based content
  card,
  
  /// For full-screen loading
  fullScreen,
  
  /// For inline loading (small, doesn't take full space)
  inline,
  
  /// For grid layouts
  grid,
  
  /// For profile/header sections
  profile,
  
  /// For chat messages
  chat,
}

class SmartLoader extends StatelessWidget {
  final LoadingType type;
  final int? itemCount;
  final String? message;
  final Color? color;

  const SmartLoader({
    super.key,
    required this.type,
    this.itemCount,
    this.message,
    this.color,
  });

  /// Quick constructor for list loading
  const SmartLoader.list({
    super.key,
    this.itemCount = 5,
  })  : type = LoadingType.list,
        message = null,
        color = null;

  /// Quick constructor for card loading
  const SmartLoader.card({super.key})
      : type = LoadingType.card,
        itemCount = null,
        message = null,
        color = null;

  /// Quick constructor for full screen loading
  const SmartLoader.fullScreen({
    super.key,
    this.message,
  })  : type = LoadingType.fullScreen,
        itemCount = null,
        color = null;

  /// Quick constructor for inline loading
  const SmartLoader.inline({
    super.key,
    this.color,
  })  : type = LoadingType.inline,
        itemCount = null,
        message = null;

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case LoadingType.list:
        return Column(
          children: List.generate(
            itemCount ?? 5,
            (index) => const SkeletonUserCard(),
          ),
        );

      case LoadingType.card:
        return const SkeletonStatCard();

      case LoadingType.grid:
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(
            itemCount ?? 6,
            (index) => const SkeletonStatCard(),
          ),
        );

      case LoadingType.profile:
        return Column(
          children: const [
            SkeletonProfileHeader(),
            SizedBox(height: 16),
            SkeletonUserCard(),
            SkeletonUserCard(),
          ],
        );

      case LoadingType.chat:
        return Column(
          children: List.generate(
            itemCount ?? 5,
            (index) => const SkeletonMessageBubble(),
          ),
        );

      case LoadingType.fullScreen:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const ModernLoadingIndicator(),
              if (message != null) ...[
                const SizedBox(height: 16),
                Text(
                  message!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ],
          ),
        );

      case LoadingType.inline:
        return SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              color ?? Theme.of(context).primaryColor,
            ),
          ),
        );
    }
  }
}


