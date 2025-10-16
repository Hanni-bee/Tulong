import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Modern shimmer loading effect for skeleton screens
class ModernShimmerLoading extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final Color? baseColor;
  final Color? highlightColor;

  const ModernShimmerLoading({
    super.key,
    required this.child,
    this.isLoading = true,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<ModernShimmerLoading> createState() => _ModernShimmerLoadingState();
}

class _ModernShimmerLoadingState extends State<ModernShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
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

    final baseColor = widget.baseColor ?? AppColors.lightGray.withOpacity(0.3);
    final highlightColor =
        widget.highlightColor ?? Colors.white.withOpacity(0.5);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                0.0,
                0.5 + (_animation.value * 0.25),
                1.0,
              ],
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Skeleton container for loading states
class SkeletonContainer extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const SkeletonContainer({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8.0,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.lightGray.withOpacity(0.3),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Card skeleton for list items
class SkeletonCard extends StatelessWidget {
  final EdgeInsetsGeometry? margin;
  final double height;

  const SkeletonCard({
    super.key,
    this.margin,
    this.height = 120.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.neumorphicDark.withOpacity(0.1),
            offset: const Offset(4, 4),
            blurRadius: 8,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.7),
            offset: const Offset(-2, -2),
            blurRadius: 6,
          ),
        ],
      ),
      child: ModernShimmerLoading(
        child: Row(
          children: [
            // Avatar
            SkeletonContainer(
              width: 56,
              height: 56,
              borderRadius: 16,
            ),
            const SizedBox(width: 16),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SkeletonContainer(
                    height: 16,
                    width: double.infinity,
                    borderRadius: 8,
                  ),
                  const SizedBox(height: 8),
                  SkeletonContainer(
                    height: 12,
                    width: 200,
                    borderRadius: 6,
                  ),
                  const SizedBox(height: 8),
                  SkeletonContainer(
                    height: 12,
                    width: 150,
                    borderRadius: 6,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// List of skeleton cards
class SkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const SkeletonList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 120.0,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: itemCount,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemBuilder: (context, index) {
        return SkeletonCard(height: itemHeight);
      },
    );
  }
}

/// Modern circular loading indicator
class ModernLoadingIndicator extends StatefulWidget {
  final double size;
  final Color? color;
  final double strokeWidth;
  final String? message;

  const ModernLoadingIndicator({
    super.key,
    this.size = 40.0,
    this.color,
    this.strokeWidth = 3.0,
    this.message,
  });

  @override
  State<ModernLoadingIndicator> createState() => _ModernLoadingIndicatorState();
}

class _ModernLoadingIndicatorState extends State<ModernLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RotationTransition(
          turns: _controller,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.color ?? AppColors.primaryRed,
                  (widget.color ?? AppColors.primaryRed).withOpacity(0.5),
                ],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(widget.strokeWidth),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 16),
          Text(
            widget.message!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Full screen loading overlay
class LoadingOverlay extends StatelessWidget {
  final String? message;
  final bool isTransparent;

  const LoadingOverlay({
    super.key,
    this.message,
    this.isTransparent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isTransparent
          ? Colors.black.withOpacity(0.3)
          : AppColors.neumorphicBase,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.neumorphicDark.withOpacity(0.3),
                offset: const Offset(8, 8),
                blurRadius: 16,
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.9),
                offset: const Offset(-4, -4),
                blurRadius: 12,
              ),
            ],
          ),
          child: ModernLoadingIndicator(
            size: 48,
            message: message ?? 'Loading...',
          ),
        ),
      ),
    );
  }
}

/// Pulsing dot indicator
class PulsingDotIndicator extends StatefulWidget {
  final Color? color;
  final double size;

  const PulsingDotIndicator({
    super.key,
    this.color,
    this.size = 12.0,
  });

  @override
  State<PulsingDotIndicator> createState() => _PulsingDotIndicatorState();
}

class _PulsingDotIndicatorState extends State<PulsingDotIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (widget.color ?? AppColors.primaryRed)
                .withOpacity(_animation.value),
            boxShadow: [
              BoxShadow(
                color: (widget.color ?? AppColors.primaryRed)
                    .withOpacity(_animation.value * 0.5),
                blurRadius: widget.size * _animation.value,
                spreadRadius: widget.size * 0.2 * _animation.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Three dots loading animation
class ThreeDotsLoading extends StatefulWidget {
  final Color? color;
  final double dotSize;

  const ThreeDotsLoading({
    super.key,
    this.color,
    this.dotSize = 8.0,
  });

  @override
  State<ThreeDotsLoading> createState() => _ThreeDotsLoadingState();
}

class _ThreeDotsLoadingState extends State<ThreeDotsLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final delay = index * 0.2;
        final value = (_controller.value - delay) % 1.0;
        final opacity = (value < 0.5) ? value * 2 : (1.0 - value) * 2;

        return Container(
          width: widget.dotSize,
          height: widget.dotSize,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (widget.color ?? AppColors.primaryRed)
                .withOpacity(0.3 + (opacity * 0.7)),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildDot(0),
        _buildDot(1),
        _buildDot(2),
      ],
    );
  }
}

