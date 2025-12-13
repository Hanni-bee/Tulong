import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/soft_ui_design.dart';
import '../providers/network_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/chat_provider.dart';
import '../utils/prototype_animations.dart';
import '../widgets/solid_badge.dart';
import '../utils/icon_system.dart';
import 'modern_home_screen.dart';
import 'local_chat_screen.dart';
import 'walkie_talkie_screen.dart';
// Hardware screen removed - using pure Bluetooth only
import 'modern_profile_screen.dart';
import '../models/notification_model.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _previousIndex = 0;
  late AnimationController _animationController;
  late AnimationController _iconAnimationController;
  late Animation<double> _iconScaleAnimation;
  late AnimationController _pageExitController;
  late AnimationController _pageEntranceController;
  late Animation<double> _pageExitFade;
  late Animation<Offset> _pageExitSlide;
  late Animation<double> _pageExitScale;
  late Animation<double> _pageEntranceFade;
  late Animation<Offset> _pageEntranceSlide;
  late Animation<double> _pageEntranceScale;
  
  // Floating bottom nav animation
  late AnimationController _floatingNavController;
  late Animation<Offset> _floatingNavSlide;
  late Animation<double> _floatingNavFade;
  
  // Icon wobble and glow animations
  final Map<int, AnimationController> _iconWobbleControllers = {};
  final Map<int, Animation<double>> _iconWobbleScaleAnimations = {};
  final Map<int, Animation<double>> _iconWobbleRotateAnimations = {};
  late AnimationController _glowPulseController;
  late Animation<double> _glowPulseAnimation;
  
  // Badge counts - connected to NotificationProvider
  int _messagesUnreadCount = 0;
  int _callsActiveCount = 0;
  
  final List<Widget> _screens = [
    const ModernHomeScreen(),
    const LocalChatScreen(),
    const WalkieTalkieScreen(),
    const ModernProfileScreen(),
  ];

  final List<NavigationItem> _navigationItems = [
    const NavigationItem(
      icon: IconSystem.navHome,
      activeIcon: IconSystem.navHomeActive,
      label: 'Home',
      color: AppColors.primaryRed,
    ),
    const NavigationItem(
      icon: IconSystem.navChat,
      activeIcon: IconSystem.navChatActive,
      label: 'Local Chat',
      color: AppColors.online,
    ),
    const NavigationItem(
      icon: IconSystem.navCalls,
      activeIcon: IconSystem.navCallsActive,
      label: 'Calls',
      color: AppColors.warning,
    ),
    const NavigationItem(
      icon: IconSystem.navProfile,
      activeIcon: IconSystem.navProfileActive,
      label: 'Profile',
      color: AppColors.info,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _iconAnimationController = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );
    // Enhanced exit animation: fade out + slide + scale (smooth and polished)
    _pageExitController = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    )..value = 0.0; // Start hidden
    
    _pageExitFade = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _pageExitController,
      curve: Curves.easeInCubic,
    ));
    
    _pageExitSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.04), // Slide up on exit
    ).animate(CurvedAnimation(
      parent: _pageExitController,
      curve: Curves.easeInCubic,
    ));
    
    _pageExitScale = Tween<double>(
      begin: 1.0,
      end: 0.96, // Slight scale down on exit
    ).animate(CurvedAnimation(
      parent: _pageExitController,
      curve: Curves.easeInCubic,
    ));
    
    // Enhanced entrance animation: fade in + slide up + scale (smooth entrance)
    _pageEntranceController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..value = 1.0; // Start visible
    
    _pageEntranceFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pageEntranceController,
      curve: Curves.easeOutCubic,
    ));
    
    _pageEntranceSlide = Tween<Offset>(
      begin: const Offset(0, 0.06), // Slide up from 6% below
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _pageEntranceController,
      curve: Curves.easeOutCubic,
    ));
    
    _pageEntranceScale = Tween<double>(
      begin: 0.96, // Start slightly scaled down
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pageEntranceController,
      curve: Curves.easeOutCubic,
    ));

    // Smoother, subtle scale animation for icons
    _iconScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(
      parent: _iconAnimationController,
      curve: Curves.easeInOutCubic,
    ));

    // Icon wobble animations for each nav item (from prototype: scale 1.0 → 1.05, rotate [0, -10, 10, 0])
    for (int i = 0; i < _navigationItems.length; i++) {
      final controller = AnimationController(
        duration: PrototypeAnimations.iconWobbleDuration, // 500ms
        vsync: this,
      );

      final scaleAnimation = TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.05), weight: 1),
        TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.05), weight: 1),
        TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 1),
      ]).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeInOut,
      ));

      final rotateAnimation = TweenSequence<double>([
        TweenSequenceItem(
          tween: Tween(begin: 0.0, end: -0.1745), // -10 degrees
          weight: 1,
        ),
        TweenSequenceItem(
          tween: Tween(begin: -0.1745, end: 0.1745), // 10 degrees
          weight: 1,
        ),
        TweenSequenceItem(
          tween: Tween(begin: 0.1745, end: 0.0), // back to 0
          weight: 1,
        ),
      ]).animate(CurvedAnimation(
        parent: controller,
        curve: Curves.easeInOut,
      ));

      _iconWobbleControllers[i] = controller;
      _iconWobbleScaleAnimations[i] = scaleAnimation;
      _iconWobbleRotateAnimations[i] = rotateAnimation;
    }

    // Glow pulse animation (from prototype: pulsing glow behind active icon, opacity [0.5, 0.8, 0.5], infinite)
    _glowPulseController = AnimationController(
      duration: PrototypeAnimations.pulseEffectDuration, // 2000ms
      vsync: this,
    )..repeat(reverse: true);

    _glowPulseAnimation = Tween<double>(
      begin: 0.5,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _glowPulseController,
      curve: Curves.easeInOut,
    ));

    // Floating bottom nav animation: slide up from bottom + fade in
    _floatingNavController = AnimationController(
      duration: PrototypeAnimations.floatingBarDuration, // 400ms
      vsync: this,
    );

    _floatingNavSlide = Tween<Offset>(
      begin: const Offset(0, 0.05), // +20px from bottom
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _floatingNavController,
      curve: PrototypeAnimations.pageEntryCurve, // easeOut
    ));

    _floatingNavFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _floatingNavController,
      curve: PrototypeAnimations.pageEntryCurve,
    ));

    // Start animation with delay 100ms (from prototype)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _floatingNavController.forward();
        }
      });
    });

    // Initialize network connection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final networkProvider = Provider.of<NetworkProvider>(context, listen: false);
      networkProvider.connectToNetwork();
    });

    // Listen to notification provider and chat provider for badge updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
      notificationProvider.addListener(_updateBadgeCounts);
      
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.addListener(_updateBadgeCounts);
      
      _updateBadgeCounts();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _iconAnimationController.dispose();
    _pageExitController.dispose();
    _pageEntranceController.dispose();
    _floatingNavController.dispose();
    _glowPulseController.dispose();
    for (final controller in _iconWobbleControllers.values) {
      controller.dispose();
    }
    // Remove listeners
    try {
      final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
      notificationProvider.removeListener(_updateBadgeCounts);
      
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      chatProvider.removeListener(_updateBadgeCounts);
    } catch (_) {
      // Providers might not be available during dispose
    }
    super.dispose();
  }

  void _updateBadgeCounts() {
    if (!mounted) return;
    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final notificationProvider = Provider.of<NotificationProvider>(context, listen: false);
      setState(() {
        // Use ChatProvider's unread count for local chat (index 1)
        _messagesUnreadCount = chatProvider.unreadMessageCount;
        _callsActiveCount = notificationProvider.getBadgeCountForType(NotificationType.emergency);
      });
    } catch (_) {
      // Providers might not be available
    }
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      HapticFeedback.lightImpact();
      
      // Start icon wobble animation (from prototype)
      if (_iconWobbleControllers.containsKey(index)) {
        _iconWobbleControllers[index]!.forward(from: 0);
      }
      
      // Start scale animation
      _iconAnimationController.forward();
      
      // Store previous index for exit animation
      _previousIndex = _currentIndex;
      
      // Reset controllers for clean transition
      _pageExitController.reset();
      _pageEntranceController.reset();
      
      // Start exit animation first (fade out + slide up + scale)
      _pageExitController.forward().then((_) {
        // After exit completes, switch page and start entrance
        setState(() {
          _currentIndex = index;
        });
        
        // Small delay for smoother transition (10ms)
        Future.delayed(const Duration(milliseconds: 10), () {
          // Start entrance animation (fade in + slide up + scale)
          _pageEntranceController.forward().then((_) {
            _iconAnimationController.reverse();
            // Reset exit controller for next transition
            _pageExitController.reset();
            // Keep entrance visible for next transition
            _pageEntranceController.value = 1.0;
          });
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // allow body to render under the floating nav pill
      backgroundColor: AppColors.neumorphicBase,
      body: ScrollConfiguration(
        behavior: const _NoScrollbarsBehavior(),
        child: Stack(
          children: [
            // Exiting page (only visible during exit animation)
            if (_pageExitController.value > 0.0)
              AnimatedBuilder(
                animation: Listenable.merge([
                  _pageExitController,
                  _pageExitFade,
                  _pageExitSlide,
                  _pageExitScale,
                ]),
                builder: (context, child) {
                  return Positioned.fill(
                    child: IgnorePointer(
                      child: FadeTransition(
                        opacity: _pageExitFade,
                        child: SlideTransition(
                          position: _pageExitSlide,
                          child: ScaleTransition(
                            scale: _pageExitScale,
                            child: IndexedStack(
                              index: _previousIndex,
                              children: _screens,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            // Entering page (current page with entrance animation)
            AnimatedBuilder(
              animation: Listenable.merge([
                _pageEntranceController,
                _pageEntranceFade,
                _pageEntranceSlide,
                _pageEntranceScale,
              ]),
              builder: (context, child) {
                return FadeTransition(
                  opacity: _pageEntranceFade,
                  child: SlideTransition(
                    position: _pageEntranceSlide,
                    child: ScaleTransition(
                      scale: _pageEntranceScale,
                      child: IndexedStack(
                        index: _currentIndex,
                        children: _screens,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: FadeTransition(
        opacity: _floatingNavFade,
        child: SlideTransition(
          position: _floatingNavSlide,
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: EdgeInsets.zero, // transparent feel, no extra padding
            decoration: BoxDecoration(
              color: Colors.white, // solid pill
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.lightGray.withOpacity(0.25), // More subtle border
                width: 1.0,
              ),
              boxShadow: [
                // Enhanced shadow with multiple layers
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.8),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                  spreadRadius: 0,
                ),
              ],
            ),
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemCount = _navigationItems.length;
              final itemWidth = constraints.maxWidth / itemCount;
              return Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Enhanced sliding pill indicator with glow effect
                  AnimatedPositioned(
                    duration: PrototypeAnimations.navTransitionDuration, // 400ms
                    curve: Curves.easeInOutCubic,
                    left: itemWidth * _currentIndex,
                    width: itemWidth,
                    top: 6,
                    bottom: 6,
                    child: AnimatedBuilder(
                      animation: _glowPulseController,
                      builder: (context, child) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: _navigationItems[_currentIndex].color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: _navigationItems[_currentIndex].color.withOpacity(0.15 * _glowPulseAnimation.value),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _navigationItems.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return _buildModernNavItem(index, item);
                    }).toList(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  ),
);
  }


  Widget _buildModernNavItem(int index, NavigationItem item) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: _AnimatedNavItem(
        isSelected: isSelected,
        item: item,
        index: index,
        onTap: () => _onTabTapped(index),
        iconScaleAnimation: _iconScaleAnimation,
        iconWobbleScale: _iconWobbleScaleAnimations[index],
        iconWobbleRotate: _iconWobbleRotateAnimations[index],
        glowPulse: _glowPulseAnimation,
        shouldShowBadge: _shouldShowBadge(index),
        badgeCount: _getBadgeCount(index),
      ),
    );
  }

  bool _shouldShowBadge(int index) {
    // Show badge for Messages (index 1) and Calls (index 2)
    if (index == 1) return _messagesUnreadCount > 0;
    if (index == 2) return _callsActiveCount > 0;
    return false;
  }

  int _getBadgeCount(int index) {
    if (index == 1) return _messagesUnreadCount;
    if (index == 2) return _callsActiveCount;
    return 0;
  }
}

class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;

  const NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.color,
  });
}

/// Enhanced animated navigation item with press feedback
class _AnimatedNavItem extends StatefulWidget {
  final bool isSelected;
  final NavigationItem item;
  final int index;
  final VoidCallback onTap;
  final Animation<double> iconScaleAnimation;
  final Animation<double>? iconWobbleScale;
  final Animation<double>? iconWobbleRotate;
  final Animation<double> glowPulse;
  final bool shouldShowBadge;
  final int badgeCount;

  const _AnimatedNavItem({
    required this.isSelected,
    required this.item,
    required this.index,
    required this.onTap,
    required this.iconScaleAnimation,
    this.iconWobbleScale,
    this.iconWobbleRotate,
    required this.glowPulse,
    required this.shouldShowBadge,
    required this.badgeCount,
  });

  @override
  State<_AnimatedNavItem> createState() => _AnimatedNavItemState();
}

class _AnimatedNavItemState extends State<_AnimatedNavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _pressScale;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTapDown: (_) {
          setState(() => _isPressed = true);
          _pressController.forward();
          HapticFeedback.selectionClick();
        },
        onTapUp: (_) {
          setState(() => _isPressed = false);
          _pressController.reverse();
          widget.onTap();
        },
        onTapCancel: () {
          setState(() => _isPressed = false);
          _pressController.reverse();
        },
        child: AnimatedBuilder(
          animation: Listenable.merge([
            widget.iconScaleAnimation,
            widget.glowPulse,
            _pressScale,
            if (widget.iconWobbleScale != null) widget.iconWobbleScale!,
            if (widget.iconWobbleRotate != null) widget.iconWobbleRotate!,
          ]),
          builder: (context, child) {
            final baseScale = widget.isSelected ? widget.iconScaleAnimation.value : 1.0;
            final wobbleScale = widget.iconWobbleScale?.value ?? 1.0;
            final wobbleRotate = widget.iconWobbleRotate?.value ?? 0.0;
            final glowOpacity = widget.isSelected ? widget.glowPulse.value : 0.0;
            final pressScale = _pressScale.value;

            return Transform.scale(
              scale: pressScale,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeInOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: widget.isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: widget.isSelected
                      ? [
                          ...SoftUIDesign.getSoftShadow(
                            elevation: _isPressed ? 4.0 : 3.0,
                            shadowColor: widget.item.color.withOpacity(0.2),
                          ),
                          ...SoftUIDesign.getGlowOverlay(
                            color: widget.item.color,
                            intensity: 0.08,
                            blur: 6.0,
                          ),
                          BoxShadow(
                            color: widget.item.color.withOpacity(glowOpacity * 0.3),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            offset: const Offset(0, 1),
                            blurRadius: 4,
                            spreadRadius: 0,
                          ),
                        ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Semantics(
                      selected: widget.isSelected,
                      label: widget.item.label,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Active dot above icon
                          if (widget.isSelected)
                            Positioned(
                              top: -10,
                              left: 0,
                              right: 0,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: widget.item.color,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: widget.item.color.withOpacity(0.4 * glowOpacity),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Gradient glow background
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Center(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 320),
                                  curve: Curves.easeInOutCubic,
                                  width: widget.isSelected ? 66 : 46,
                                  height: widget.isSelected ? 66 : 46,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    gradient: RadialGradient(
                                      center: Alignment.center,
                                      radius: 0.85,
                                      colors: [
                                        widget.item.color.withOpacity(
                                          widget.isSelected ? 0.18 : 0.06,
                                        ),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Icon with animations
                          Transform.scale(
                            scale: baseScale * wobbleScale,
                            child: Transform.rotate(
                              angle: wobbleRotate,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 320),
                                curve: Curves.easeInOutCubic,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: widget.isSelected ? widget.item.color : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  border: widget.isSelected
                                      ? Border.all(
                                          color: widget.item.color.withOpacity(0.25),
                                          width: 1,
                                        )
                                      : null,
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: ScaleTransition(
                                        scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Icon(
                                    widget.isSelected ? widget.item.activeIcon : widget.item.icon,
                                    key: ValueKey(widget.isSelected),
                                    color: widget.isSelected ? Colors.white : AppColors.mediumGray,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Badge
                          if (widget.shouldShowBadge)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: SolidBadge(
                                count: widget.badgeCount,
                                backgroundColor: AppColors.primaryRed,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Label
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOutCubic,
                      style: TextStyle(
                        fontSize: widget.isSelected ? 12 : 11,
                        fontWeight: widget.isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: widget.isSelected ? widget.item.color : AppColors.mediumGray,
                        letterSpacing: widget.isSelected ? 0.3 : 0.2,
                        height: 1.1,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeInOutCubic,
                        padding: EdgeInsets.symmetric(
                          horizontal: widget.isSelected ? 8 : 4,
                          vertical: widget.isSelected ? 2 : 0,
                        ),
                        decoration: BoxDecoration(
                          color: widget.isSelected
                              ? widget.item.color.withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    // Underline
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeInOutCubic,
                      margin: const EdgeInsets.only(top: 4),
                      height: 3,
                      width: widget.isSelected ? 16 : 0,
                      decoration: BoxDecoration(
                        color: widget.item.color.withOpacity(widget.isSelected ? 0.8 : 0.0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Local scroll behavior that removes glow and scrollbar indicators
class _NoScrollbarsBehavior extends ScrollBehavior {
  const _NoScrollbarsBehavior();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child; // no glow
  }

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child; // no scrollbar
  }
}
