import 'package:flutter/material.dart';

/// Enhanced List Animation System
/// 
/// Provides:
/// - Smoother stagger timing
/// - Better entrance animations
/// - Reorder animations (when list changes)
/// - Optimized for performance
class EnhancedListAnimations {
  // ============================================================================
  // TIMING CONSTANTS
  // ============================================================================

  /// Stagger delay between items (smoother: 50ms instead of 100ms)
  static const int staggerDelayMs = 50;

  /// Animation duration per item
  static const Duration itemDuration = Duration(milliseconds: 300);

  /// Reorder animation duration
  static const Duration reorderDuration = Duration(milliseconds: 250);

  /// Curve for smoother animations
  static const Curve animationCurve = Curves.easeOutCubic;

  // ============================================================================
  // ENTRANCE ANIMATION TYPES
  // ============================================================================

  /// Fade + slide from bottom
  static Widget fadeSlideUp({
    required Widget child,
    required int index,
    required Animation<double> animation,
    double slideDistance = 20.0,
  }) {
    final delay = index * staggerDelayMs;
    final delayedAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: Interval(
          delay / (delay + itemDuration.inMilliseconds),
          1.0,
          curve: animationCurve,
        ),
      ),
    );

    return AnimatedBuilder(
      animation: delayedAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, slideDistance * (1 - delayedAnimation.value)),
          child: Opacity(
            opacity: delayedAnimation.value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  /// Fade + slide from right
  static Widget fadeSlideRight({
    required Widget child,
    required int index,
    required Animation<double> animation,
    double slideDistance = 30.0,
  }) {
    final delay = index * staggerDelayMs;
    final delayedAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: Interval(
          delay / (delay + itemDuration.inMilliseconds),
          1.0,
          curve: animationCurve,
        ),
      ),
    );

    return AnimatedBuilder(
      animation: delayedAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(slideDistance * (1 - delayedAnimation.value), 0),
          child: Opacity(
            opacity: delayedAnimation.value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  /// Scale + fade
  static Widget scaleFade({
    required Widget child,
    required int index,
    required Animation<double> animation,
    double minScale = 0.8,
  }) {
    final delay = index * staggerDelayMs;
    final delayedAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: Interval(
          delay / (delay + itemDuration.inMilliseconds),
          1.0,
          curve: animationCurve,
        ),
      ),
    );

    return AnimatedBuilder(
      animation: delayedAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: minScale + (1.0 - minScale) * delayedAnimation.value,
          child: Opacity(
            opacity: delayedAnimation.value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Enhanced Animated List Widget
/// 
/// Provides smooth entrance animations with stagger timing
class EnhancedAnimatedList extends StatefulWidget {
  final List<Widget> children;
  final ScrollController? scrollController;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final Axis scrollDirection;
  final EntranceAnimationType entranceType;
  final bool enableReorder;
  final Function(int, int)? onReorder;

  const EnhancedAnimatedList({
    super.key,
    required this.children,
    this.scrollController,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.scrollDirection = Axis.vertical,
    this.entranceType = EntranceAnimationType.fadeSlideUp,
    this.enableReorder = false,
    this.onReorder,
  });

  @override
  State<EnhancedAnimatedList> createState() => _EnhancedAnimatedListState();
}

class _EnhancedAnimatedListState extends State<EnhancedAnimatedList>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late List<GlobalKey> _itemKeys;
  final Map<int, AnimationController> _reorderControllers = {};

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      duration: Duration(
        milliseconds: widget.children.length * EnhancedListAnimations.staggerDelayMs +
            EnhancedListAnimations.itemDuration.inMilliseconds,
      ),
      vsync: this,
    );

    _itemKeys = List.generate(
      widget.children.length,
      (index) => GlobalKey(),
    );

    _entranceController.forward();
  }

  @override
  void didUpdateWidget(EnhancedAnimatedList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle list changes
    if (widget.children.length != oldWidget.children.length) {
      // New items added
      if (widget.children.length > oldWidget.children.length) {
        _itemKeys = List.generate(
          widget.children.length,
          (index) => index < oldWidget.children.length
              ? _itemKeys[index]
              : GlobalKey(),
        );
        _entranceController.duration = Duration(
          milliseconds: widget.children.length *
                  EnhancedListAnimations.staggerDelayMs +
              EnhancedListAnimations.itemDuration.inMilliseconds,
        );
        _entranceController.forward(from: 0.0);
      } else {
        // Items removed - animate out
        _itemKeys = List.generate(
          widget.children.length,
          (index) => _itemKeys[index],
        );
      }
    }

    // Handle reorder
    if (widget.enableReorder && widget.children.length == oldWidget.children.length) {
      _animateReorder(oldWidget.children, widget.children);
    }
  }

  void _animateReorder(List<Widget> oldChildren, List<Widget> newChildren) {
    // Detect which items moved
    for (int i = 0; i < newChildren.length; i++) {
      final newChild = newChildren[i];
      final oldIndex = oldChildren.indexOf(newChild);
      
      if (oldIndex != i && oldIndex != -1) {
        // Item moved - animate reorder
        if (!_reorderControllers.containsKey(i)) {
          _reorderControllers[i] = AnimationController(
            duration: EnhancedListAnimations.reorderDuration,
            vsync: this,
          );
        }
        _reorderControllers[i]!.forward(from: 0.0);
      }
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    for (final controller in _reorderControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _buildAnimatedItem(int index, Widget child) {
    Widget animatedChild;

    switch (widget.entranceType) {
      case EntranceAnimationType.fadeSlideUp:
        animatedChild = EnhancedListAnimations.fadeSlideUp(
          child: child,
          index: index,
          animation: _entranceController,
        );
        break;
      case EntranceAnimationType.fadeSlideRight:
        animatedChild = EnhancedListAnimations.fadeSlideRight(
          child: child,
          index: index,
          animation: _entranceController,
        );
        break;
      case EntranceAnimationType.scaleFade:
        animatedChild = EnhancedListAnimations.scaleFade(
          child: child,
          index: index,
          animation: _entranceController,
        );
        break;
    }

    // Add reorder animation if enabled
    if (widget.enableReorder && _reorderControllers.containsKey(index)) {
      final reorderAnimation = _reorderControllers[index]!;
      animatedChild = AnimatedBuilder(
        animation: reorderAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(
              0,
              (1 - reorderAnimation.value) * 10 * (index % 2 == 0 ? 1 : -1),
            ),
            child: Opacity(
              opacity: 0.5 + 0.5 * reorderAnimation.value,
              child: child,
            ),
          );
        },
        child: animatedChild,
      );
    }

    return animatedChild;
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: widget.scrollController,
      padding: widget.padding,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      scrollDirection: widget.scrollDirection,
      itemCount: widget.children.length,
      itemBuilder: (context, index) {
        return _buildAnimatedItem(index, widget.children[index]);
      },
    );
  }
}

/// Enhanced Animated ListView.builder
/// 
/// Wrapper for ListView.builder with enhanced animations
class EnhancedAnimatedListView extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final ScrollController? scrollController;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final Axis scrollDirection;
  final EntranceAnimationType entranceType;

  const EnhancedAnimatedListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.scrollController,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.scrollDirection = Axis.vertical,
    this.entranceType = EntranceAnimationType.fadeSlideUp,
  });

  @override
  Widget build(BuildContext context) {
    return _EnhancedAnimatedListViewStateful(
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      scrollController: scrollController,
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      scrollDirection: scrollDirection,
      entranceType: entranceType,
    );
  }
}

class _EnhancedAnimatedListViewStateful extends StatefulWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final ScrollController? scrollController;
  final EdgeInsetsGeometry? padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final Axis scrollDirection;
  final EntranceAnimationType entranceType;

  const _EnhancedAnimatedListViewStateful({
    required this.itemCount,
    required this.itemBuilder,
    this.scrollController,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.scrollDirection = Axis.vertical,
    this.entranceType = EntranceAnimationType.fadeSlideUp,
  });

  @override
  State<_EnhancedAnimatedListViewStateful> createState() =>
      _EnhancedAnimatedListViewStatefulState();
}

class _EnhancedAnimatedListViewStatefulState
    extends State<_EnhancedAnimatedListViewStateful>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  final Map<int, AnimationController> _itemControllers = {};

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      duration: Duration(
        milliseconds: widget.itemCount * EnhancedListAnimations.staggerDelayMs +
            EnhancedListAnimations.itemDuration.inMilliseconds,
      ),
      vsync: this,
    );

    // Initialize item controllers
    for (int i = 0; i < widget.itemCount; i++) {
      _itemControllers[i] = AnimationController(
        duration: EnhancedListAnimations.itemDuration,
        vsync: this,
      );
    }

    _entranceController.forward();
    _startItemAnimations();
  }

  void _startItemAnimations() {
    for (int i = 0; i < widget.itemCount; i++) {
      final delay = i * EnhancedListAnimations.staggerDelayMs;
      Future.delayed(Duration(milliseconds: delay), () {
        if (mounted && _itemControllers.containsKey(i)) {
          _itemControllers[i]!.forward();
        }
      });
    }
  }

  @override
  void didUpdateWidget(_EnhancedAnimatedListViewStateful oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle item count changes
    if (widget.itemCount != oldWidget.itemCount) {
      // Dispose old controllers
      for (int i = widget.itemCount; i < oldWidget.itemCount; i++) {
        _itemControllers[i]?.dispose();
        _itemControllers.remove(i);
      }

      // Create new controllers
      for (int i = oldWidget.itemCount; i < widget.itemCount; i++) {
        _itemControllers[i] = AnimationController(
          duration: EnhancedListAnimations.itemDuration,
          vsync: this,
        );
      }

      // Update entrance controller duration
      _entranceController.duration = Duration(
        milliseconds: widget.itemCount * EnhancedListAnimations.staggerDelayMs +
            EnhancedListAnimations.itemDuration.inMilliseconds,
      );

      // Restart animations for new items
      _entranceController.reset();
      _entranceController.forward();
      _startItemAnimations();
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    for (final controller in _itemControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _buildAnimatedItem(BuildContext context, int index) {
    final child = widget.itemBuilder(context, index);
    final controller = _itemControllers[index] ?? _entranceController;

    Widget animatedChild;

    switch (widget.entranceType) {
      case EntranceAnimationType.fadeSlideUp:
        animatedChild = EnhancedListAnimations.fadeSlideUp(
          child: child,
          index: index,
          animation: controller,
        );
        break;
      case EntranceAnimationType.fadeSlideRight:
        animatedChild = EnhancedListAnimations.fadeSlideRight(
          child: child,
          index: index,
          animation: controller,
        );
        break;
      case EntranceAnimationType.scaleFade:
        animatedChild = EnhancedListAnimations.scaleFade(
          child: child,
          index: index,
          animation: controller,
        );
        break;
    }

    return animatedChild;
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: widget.scrollController,
      padding: widget.padding,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      scrollDirection: widget.scrollDirection,
      itemCount: widget.itemCount,
      itemBuilder: _buildAnimatedItem,
    );
  }
}

// ============================================================================
// ENUMS
// ============================================================================

enum EntranceAnimationType {
  fadeSlideUp,
  fadeSlideRight,
  scaleFade,
}

