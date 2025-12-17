import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PolishedBounce extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final Duration duration;
  final Curve curve;

  const PolishedBounce({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.95, // From prototype: scale to 0.95 on press
    this.duration = const Duration(milliseconds: 100), // From prototype: 100ms
    this.curve = Curves.easeInOut, // From prototype: easeInOut
  });

  @override
  State<PolishedBounce> createState() => _PolishedBounceState();
}

class _PolishedBounceState extends State<PolishedBounce>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      HapticFeedback.lightImpact();
      _controller.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      _controller.reverse().then((_) {
        widget.onTap!();
      });
    }
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        child: widget.child,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
      ),
    );
  }
}

class PolishedFadeIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final Offset offset;

  const PolishedFadeIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.delay = Duration.zero,
    this.curve = Curves.easeOutCubic,
    this.offset = const Offset(0, 0.3),
  });

  @override
  State<PolishedFadeIn> createState() => _PolishedFadeInState();
}

class _PolishedFadeInState extends State<PolishedFadeIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    _slideAnimation = Tween<Offset>(
      begin: widget.offset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: child!,
          ),
        );
      },
    );
  }
}

class PolishedStaggeredList extends StatelessWidget {
  final List<Widget> children;
  final Duration staggerDuration;
  final Duration itemDuration;
  final Curve curve;

  const PolishedStaggeredList({
    super.key,
    required this.children,
    this.staggerDuration = const Duration(milliseconds: 100),
    this.itemDuration = const Duration(milliseconds: 600),
    this.curve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: children.asMap().entries.map((entry) {
        final index = entry.key;
        final child = entry.value;
        return PolishedFadeIn(
          duration: itemDuration,
          delay: Duration(milliseconds: staggerDuration.inMilliseconds * index),
          curve: curve,
          child: child,
        );
      }).toList(),
    );
  }
}

class PolishedPulse extends StatefulWidget {
  final Widget child;
  final bool isActive;
  final Duration duration;
  final double minScale;
  final double maxScale;

  const PolishedPulse({
    super.key,
    required this.child,
    this.isActive = false,
    this.duration = const Duration(milliseconds: 1000),
    this.minScale = 0.95,
    this.maxScale = 1.05,
  });

  @override
  State<PolishedPulse> createState() => _PolishedPulseState();
}

class _PolishedPulseState extends State<PolishedPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(PolishedPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.reset();
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
    return AnimatedBuilder(
      animation: _scaleAnimation,
      child: widget.child,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
    );
  }
}

// Sophisticated ripple effect
class PolishedRipple extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? rippleColor;
  final double borderRadius;

  const PolishedRipple({
    super.key,
    required this.child,
    this.onTap,
    this.rippleColor,
    this.borderRadius = 0,
  });

  @override
  State<PolishedRipple> createState() => _PolishedRippleState();
}

class _PolishedRippleState extends State<PolishedRipple>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rippleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _rippleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    _controller.forward().then((_) {
      _controller.reset();
    });
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Stack(
          children: [
            widget.child,
            AnimatedBuilder(
              animation: _rippleAnimation,
              builder: (context, child) {
                return Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    color: (widget.rippleColor ?? Colors.white.withOpacity(0.3))
                        .withOpacity(1 - _rippleAnimation.value),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
