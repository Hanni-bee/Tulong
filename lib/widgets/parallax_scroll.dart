import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class ParallaxScrollView extends StatefulWidget {
  final List<Widget> children;
  final ScrollController? controller;
  final double parallaxFactor;
  final EdgeInsetsGeometry? padding;

  const ParallaxScrollView({
    super.key,
    required this.children,
    this.controller,
    this.parallaxFactor = 0.5,
    this.padding,
  });

  @override
  State<ParallaxScrollView> createState() => _ParallaxScrollViewState();
}

class _ParallaxScrollViewState extends State<ParallaxScrollView> {
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      padding: widget.padding,
      itemCount: widget.children.length,
      itemBuilder: (context, index) {
        return ParallaxWidget(
          offset: _scrollOffset,
          factor: widget.parallaxFactor,
          child: widget.children[index],
        );
      },
    );
  }
}

class ParallaxWidget extends StatelessWidget {
  final Widget child;
  final double offset;
  final double factor;
  final double? height;

  const ParallaxWidget({
    super.key,
    required this.child,
    required this.offset,
    this.factor = 0.5,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, offset * factor),
      child: SizedBox(
        height: height,
        child: child,
      ),
    );
  }
}

class ParallaxImage extends StatelessWidget {
  final String imagePath;
  final double height;
  final double parallaxFactor;
  final double scrollOffset;
  final BoxFit fit;
  final Widget? child;

  const ParallaxImage({
    super.key,
    required this.imagePath,
    required this.height,
    this.parallaxFactor = 0.5,
    required this.scrollOffset,
    this.fit = BoxFit.cover,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Transform.translate(
            offset: Offset(0, scrollOffset * parallaxFactor),
            child: Image.asset(
              imagePath,
              fit: fit,
              width: double.infinity,
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class ParallaxCard extends StatelessWidget {
  final Widget child;
  final double scrollOffset;
  final double parallaxFactor;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final double? elevation;
  final BorderRadius? borderRadius;

  const ParallaxCard({
    super.key,
    required this.child,
    required this.scrollOffset,
    this.parallaxFactor = 0.3,
    this.padding,
    this.backgroundColor,
    this.elevation,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, scrollOffset * parallaxFactor),
      child: Card(
        elevation: elevation ?? 4.0,
        color: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius ?? BorderRadius.circular(12),
        ),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16.0),
          child: child,
        ),
      ),
    );
  }
}

class ParallaxHeader extends StatelessWidget {
  final Widget child;
  final double scrollOffset;
  final double maxHeight;
  final double minHeight;
  final Color? backgroundColor;
  final Widget? backgroundImage;

  const ParallaxHeader({
    super.key,
    required this.child,
    required this.scrollOffset,
    required this.maxHeight,
    required this.minHeight,
    this.backgroundColor,
    this.backgroundImage,
  });

  @override
  Widget build(BuildContext context) {
    final double height = maxHeight - (scrollOffset * 0.5);
    final double clampedHeight = height.clamp(minHeight, maxHeight);
    final double opacity = (height - minHeight) / (maxHeight - minHeight);

    return SizedBox(
      height: clampedHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (backgroundImage != null)
            Opacity(
              opacity: opacity,
              child: backgroundImage!,
            ),
          if (backgroundColor != null)
            Container(
              color: backgroundColor!.withOpacity(opacity),
            ),
          Center(
            child: Opacity(
              opacity: opacity,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class StaggeredParallaxList extends StatefulWidget {
  final List<Widget> children;
  final ScrollController? controller;
  final double staggerDelay;
  final double parallaxFactor;
  final EdgeInsetsGeometry? padding;

  const StaggeredParallaxList({
    super.key,
    required this.children,
    this.controller,
    this.staggerDelay = 0.1,
    this.parallaxFactor = 0.5,
    this.padding,
  });

  @override
  State<StaggeredParallaxList> createState() => _StaggeredParallaxListState();
}

class _StaggeredParallaxListState extends State<StaggeredParallaxList> {
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    setState(() {
      _scrollOffset = _scrollController.offset;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      padding: widget.padding,
      itemCount: widget.children.length,
      itemBuilder: (context, index) {
        final double delay = index * widget.staggerDelay;
        return AnimatedOpacity(
          opacity: _scrollOffset > (index * 100) - 200 ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Transform.translate(
            offset: Offset(0, (_scrollOffset * widget.parallaxFactor) + delay),
            child: widget.children[index],
          ),
        );
      },
    );
  }
}
