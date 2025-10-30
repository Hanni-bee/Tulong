import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../utils/neumorphic_utils.dart';

/// Swipeable card with gesture controls
class SwipeableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final double borderRadius;

  const SwipeableCard({
    super.key,
    required this.child,
    this.onSwipeLeft,
    this.onSwipeRight,
    this.onTap,
    this.backgroundColor,
    this.borderRadius = 20.0,
  });

  @override
  State<SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<SwipeableCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _scaleAnimation;
  
  double _dragOffset = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
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

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.primaryDelta ?? 0.0;
      _isDragging = true;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    if (_dragOffset.abs() > screenWidth * 0.3) {
      // Swipe detected
      if (_dragOffset > 0 && widget.onSwipeRight != null) {
        HapticFeedback.mediumImpact();
        widget.onSwipeRight!();
      } else if (_dragOffset < 0 && widget.onSwipeLeft != null) {
        HapticFeedback.mediumImpact();
        widget.onSwipeLeft!();
      }
    }

    // Reset
    setState(() {
      _dragOffset = 0.0;
      _isDragging = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final swipeProgress = (_dragOffset / screenWidth).clamp(-1.0, 1.0);

    return GestureDetector(
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap?.call();
      },
      child: Transform.translate(
        offset: Offset(_dragOffset, 0),
        child: Transform.scale(
          scale: 1.0 - (swipeProgress.abs() * 0.05),
          child: Transform.rotate(
            angle: swipeProgress * 0.1,
            child: Container(
              decoration: BoxDecoration(
                color: widget.backgroundColor ?? Colors.white,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                boxShadow: _isDragging
                    ? NeumorphicUtils.getElevatedShadow(elevation: 16)
                    : NeumorphicUtils.getNeumorphicShadow(),
              ),
              child: Stack(
                children: [
                  widget.child,
                  
                  // Swipe indicators
                  if (_isDragging) ...[
                    if (swipeProgress > 0)
                      Positioned(
                        right: 20,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Icon(
                            Icons.arrow_forward,
                            color: Colors.green.withOpacity(swipeProgress),
                            size: 40,
                          ),
                        ),
                      ),
                    if (swipeProgress < 0)
                      Positioned(
                        left: 20,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: Icon(
                            Icons.arrow_back,
                            color: Colors.red.withOpacity(swipeProgress.abs()),
                            size: 40,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Long press menu with haptic feedback
class LongPressMenu extends StatefulWidget {
  final Widget child;
  final List<MenuAction> actions;

  const LongPressMenu({
    super.key,
    required this.child,
    required this.actions,
  });

  @override
  State<LongPressMenu> createState() => _LongPressMenuState();
}

class _LongPressMenuState extends State<LongPressMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showMenu(BuildContext context) {
    HapticFeedback.mediumImpact();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: NeumorphicUtils.getElevatedShadow(elevation: 12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...widget.actions.map((action) => ListTile(
              leading: Icon(action.icon, color: action.color),
              title: Text(
                action.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(context);
                HapticFeedback.lightImpact();
                action.onTap();
              },
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onLongPressEnd: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        _showMenu(context);
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: widget.child,
          );
        },
      ),
    );
  }
}

/// Double tap to like/favorite
class DoubleTapAction extends StatefulWidget {
  final Widget child;
  final VoidCallback onDoubleTap;
  final Widget? likeIcon;

  const DoubleTapAction({
    super.key,
    required this.child,
    required this.onDoubleTap,
    this.likeIcon,
  });

  @override
  State<DoubleTapAction> createState() => _DoubleTapActionState();
}

class _DoubleTapActionState extends State<DoubleTapAction>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  
  bool _showIcon = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.3),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.3, end: 1.0),
        weight: 50,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() => _showIcon = false);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    HapticFeedback.mediumImpact();
    setState(() => _showIcon = true);
    _controller.forward(from: 0);
    widget.onDoubleTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.child,
          if (_showIcon)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: widget.likeIcon ??
                        const Icon(
                          Icons.favorite,
                          color: Colors.red,
                          size: 80,
                        ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Pull to refresh with custom animation
class CustomPullToRefresh extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const CustomPullToRefresh({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  @override
  State<CustomPullToRefresh> createState() => _CustomPullToRefreshState();
}

class _CustomPullToRefreshState extends State<CustomPullToRefresh>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotateAnimation;
  
  bool _isRefreshing = false;
  double _pullDistance = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    
    setState(() => _isRefreshing = true);
    _controller.repeat();
    HapticFeedback.mediumImpact();

    await widget.onRefresh();

    if (mounted) {
      setState(() => _isRefreshing = false);
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: AppColors.primaryRed,
      backgroundColor: Colors.white,
      displacement: 60,
      child: widget.child,
    );
  }
}

/// Menu action model
class MenuAction {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  MenuAction({
    required this.label,
    required this.icon,
    this.color = AppColors.textPrimary,
    required this.onTap,
  });
}

/// Drag to dismiss
class DragToDismiss extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismissed;
  final DismissDirection direction;

  const DragToDismiss({
    super.key,
    required this.child,
    required this.onDismissed,
    this.direction = DismissDirection.horizontal,
  });

  @override
  State<DragToDismiss> createState() => _DragToDismissState();
}

class _DragToDismissState extends State<DragToDismiss> {
  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: UniqueKey(),
      direction: widget.direction,
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        widget.onDismissed();
      },
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 32),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 32),
      ),
      child: widget.child,
    );
  }
}

