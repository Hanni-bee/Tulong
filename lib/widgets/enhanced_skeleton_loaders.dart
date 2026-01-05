import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'modern_shimmer_loading.dart';

/// Enhanced skeleton loader with shimmer effect
class EnhancedSkeletonLoader extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? margin;
  final Color? baseColor;

  const EnhancedSkeletonLoader({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.margin,
    this.baseColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height ?? 16,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        color: baseColor ?? AppColors.lightGray.withOpacity(0.3),
      ),
      child: ModernShimmerLoading(
        child: Container(
          width: width,
          height: height ?? 16,
          decoration: BoxDecoration(
            borderRadius: borderRadius ?? BorderRadius.circular(8),
            color: Colors.white.withOpacity(0.1),
          ),
        ),
      ),
    );
  }
}

/// Skeleton loader for user card (Walkie Talkie)
class SkeletonUserCard extends StatelessWidget {
  const SkeletonUserCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          // Avatar skeleton
          EnhancedSkeletonLoader(
            width: 56,
            height: 56,
            borderRadius: BorderRadius.circular(28),
          ),
          const SizedBox(width: 16),
          // Content skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EnhancedSkeletonLoader(
                  width: double.infinity,
                  height: 16,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    EnhancedSkeletonLoader(
                      width: 60,
                      height: 12,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    const SizedBox(width: 8),
                    EnhancedSkeletonLoader(
                      width: 40,
                      height: 12,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Status indicator skeleton
          EnhancedSkeletonLoader(
            width: 12,
            height: 12,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      ),
    );
  }
}

/// Skeleton loader for message bubble (Local Chat)
class SkeletonMessageBubble extends StatelessWidget {
  final bool isMe;

  const SkeletonMessageBubble({
    super.key,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            EnhancedSkeletonLoader(
              width: 32,
              height: 32,
              borderRadius: BorderRadius.circular(16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primaryRed.withOpacity(0.1) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    EnhancedSkeletonLoader(
                      width: 80,
                      height: 12,
                      borderRadius: BorderRadius.circular(6),
                      margin: const EdgeInsets.only(bottom: 6),
                    ),
                  EnhancedSkeletonLoader(
                    width: double.infinity,
                    height: 14,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  const SizedBox(height: 6),
                  EnhancedSkeletonLoader(
                    width: 120,
                    height: 14,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ],
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            EnhancedSkeletonLoader(
              width: 32,
              height: 32,
              borderRadius: BorderRadius.circular(16),
            ),
          ],
        ],
      ),
    );
  }
}

/// Skeleton loader for stat card (Home/Profile)
class SkeletonStatCard extends StatelessWidget {
  const SkeletonStatCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              EnhancedSkeletonLoader(
                width: 40,
                height: 40,
                borderRadius: BorderRadius.circular(12),
              ),
              EnhancedSkeletonLoader(
                width: 60,
                height: 16,
                borderRadius: BorderRadius.circular(8),
              ),
            ],
          ),
          const SizedBox(height: 16),
          EnhancedSkeletonLoader(
            width: 80,
            height: 24,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 8),
          EnhancedSkeletonLoader(
            width: 120,
            height: 14,
            borderRadius: BorderRadius.circular(7),
          ),
        ],
      ),
    );
  }
}

/// Skeleton loader for quick action card (Home)
class SkeletonQuickActionCard extends StatelessWidget {
  const SkeletonQuickActionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EnhancedSkeletonLoader(
            width: 56,
            height: 56,
            borderRadius: BorderRadius.circular(16),
          ),
          const SizedBox(height: 12),
          EnhancedSkeletonLoader(
            width: 80,
            height: 16,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 6),
          EnhancedSkeletonLoader(
            width: 60,
            height: 12,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      ),
    );
  }
}

/// Skeleton loader for profile header
class SkeletonProfileHeader extends StatelessWidget {
  const SkeletonProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryRed,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          EnhancedSkeletonLoader(
            width: 64,
            height: 64,
            borderRadius: BorderRadius.circular(16),
            baseColor: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EnhancedSkeletonLoader(
                  width: 150,
                  height: 18,
                  borderRadius: BorderRadius.circular(9),
                  baseColor: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(height: 8),
                EnhancedSkeletonLoader(
                  width: 80,
                  height: 14,
                  borderRadius: BorderRadius.circular(7),
                  baseColor: Colors.white.withOpacity(0.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// List of skeleton user cards
class SkeletonUserList extends StatelessWidget {
  final int itemCount;

  const SkeletonUserList({
    super.key,
    this.itemCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      itemCount: itemCount,
      separatorBuilder: (context, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) => const SkeletonUserCard(),
    );
  }
}

/// List of skeleton message bubbles
class SkeletonMessageList extends StatelessWidget {
  final int itemCount;

  const SkeletonMessageList({
    super.key,
    this.itemCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Alternate between sent and received messages
        return SkeletonMessageBubble(isMe: index % 2 == 0);
      },
    );
  }
}

/// List of skeleton stat cards
class SkeletonStatCardList extends StatelessWidget {
  final int itemCount;

  const SkeletonStatCardList({
    super.key,
    this.itemCount = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: List.generate(
        itemCount,
        (index) => const SizedBox(
          width: 160,
          child: SkeletonStatCard(),
        ),
      ),
    );
  }
}








