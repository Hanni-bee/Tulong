import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class PolishedShimmer extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;

  const PolishedShimmer({
    super.key,
    required this.child,
    required this.isLoading,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<PolishedShimmer> createState() => _PolishedShimmerState();
}

class _PolishedShimmerState extends State<PolishedShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (widget.isLoading) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(PolishedShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                widget.baseColor ?? AppColors.ultraLightGray,
                widget.highlightColor ?? Colors.white.withOpacity(0.6),
                widget.baseColor ?? AppColors.ultraLightGray,
              ],
              stops: [
                0.0,
                0.5,
                1.0,
              ],
              transform: GradientRotation(_animation.value * 3.14159),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

// Sophisticated loading card with shimmer
class PolishedLoadingCard extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const PolishedLoadingCard({
    super.key,
    required this.isLoading,
    required this.child,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.all(8),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.9),
            blurRadius: 12,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      child: PolishedShimmer(
        isLoading: isLoading,
        baseColor: AppColors.ultraLightGray,
        highlightColor: Colors.white.withOpacity(0.8),
        child: child,
      ),
    );
  }
}

// Animated skeleton with sophisticated shimmer
class PolishedSkeleton extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? margin;

  const PolishedSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height ?? 16,
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.ultraLightGray,
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
      child: PolishedShimmer(
        isLoading: true,
        baseColor: AppColors.ultraLightGray,
        highlightColor: Colors.white.withOpacity(0.8),
        child: Container(
          width: width,
          height: height ?? 16,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: borderRadius ?? BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

// Sophisticated list item skeleton
class PolishedListItemSkeleton extends StatelessWidget {
  const PolishedListItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return PolishedLoadingCard(
      isLoading: true,
      child: Row(
        children: [
          // Avatar skeleton
          PolishedSkeleton(
            width: 48,
            height: 48,
            borderRadius: BorderRadius.circular(24),
          ),
          const SizedBox(width: 16),
          // Content skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PolishedSkeleton(
                  width: double.infinity,
                  height: 16,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 8),
                PolishedSkeleton(
                  width: 200,
                  height: 12,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 4),
                PolishedSkeleton(
                  width: 150,
                  height: 12,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
