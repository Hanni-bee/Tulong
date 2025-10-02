import 'package:flutter/material.dart';

class AppIcons {
  // Custom Icon Data for T.U.L.O.N.G App
  static const IconData disaster = IconData(0xe900, fontFamily: 'AppIcons');
  static const IconData emergency = IconData(0xe901, fontFamily: 'AppIcons');
  static const IconData network = IconData(0xe902, fontFamily: 'AppIcons');
  static const IconData radio = IconData(0xe903, fontFamily: 'AppIcons');
  static const IconData message = IconData(0xe904, fontFamily: 'AppIcons');
  static const IconData call = IconData(0xe905, fontFamily: 'AppIcons');
  static const IconData location = IconData(0xe906, fontFamily: 'AppIcons');
  static const IconData battery = IconData(0xe907, fontFamily: 'AppIcons');
  static const IconData signal = IconData(0xe908, fontFamily: 'AppIcons');
  static const IconData sos = IconData(0xe909, fontFamily: 'AppIcons');
  static const IconData broadcast = IconData(0xe90a, fontFamily: 'AppIcons');
  static const IconData group = IconData(0xe90b, fontFamily: 'AppIcons');
  static const IconData offline = IconData(0xe90c, fontFamily: 'AppIcons');
  static const IconData online = IconData(0xe90d, fontFamily: 'AppIcons');
  static const IconData warning = IconData(0xe90e, fontFamily: 'AppIcons');
  static const IconData success = IconData(0xe90f, fontFamily: 'AppIcons');
  static const IconData error = IconData(0xe910, fontFamily: 'AppIcons');
  static const IconData info = IconData(0xe911, fontFamily: 'AppIcons');
  static const IconData settings = IconData(0xe912, fontFamily: 'AppIcons');
  static const IconData profile = IconData(0xe913, fontFamily: 'AppIcons');
  static const IconData home = IconData(0xe914, fontFamily: 'AppIcons');
  static const IconData people = IconData(0xe915, fontFamily: 'AppIcons');
  static const IconData chat = IconData(0xe916, fontFamily: 'AppIcons');
  static const IconData walkie = IconData(0xe917, fontFamily: 'AppIcons');
  static const IconData tulong = IconData(0xe918, fontFamily: 'AppIcons');
}

class CustomIcon extends StatelessWidget {
  final IconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  const CustomIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: size,
      color: color,
      semanticLabel: semanticLabel,
    );
  }
}

class AnimatedIcon extends StatefulWidget {
  final IconData icon;
  final double? size;
  final Color? color;
  final Duration duration;
  final Curve curve;
  final bool animate;

  const AnimatedIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
    this.animate = true,
  });

  @override
  State<AnimatedIcon> createState() => _AnimatedIconState();
}

class _AnimatedIconState extends State<AnimatedIcon>
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
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    ));

    if (widget.animate) {
      _controller.repeat(reverse: true);
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
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Icon(
            widget.icon,
            size: widget.size,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class PulsingIcon extends StatefulWidget {
  final IconData icon;
  final double? size;
  final Color? color;
  final Duration duration;
  final double minOpacity;
  final double maxOpacity;

  const PulsingIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.duration = const Duration(milliseconds: 1000),
    this.minOpacity = 0.3,
    this.maxOpacity = 1.0,
  });

  @override
  State<PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _opacityAnimation = Tween<double>(
      begin: widget.minOpacity,
      end: widget.maxOpacity,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Icon(
            widget.icon,
            size: widget.size,
            color: widget.color,
          ),
        );
      },
    );
  }
}
