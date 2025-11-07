import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/soft_ui_design.dart';
import '../providers/network_provider.dart';
import '../utils/prototype_animations.dart';
import '../widgets/solid_badge.dart';
import 'modern_home_screen.dart';
import 'local_chat_screen.dart';
import 'walkie_talkie_screen.dart';
// Hardware screen removed - using pure Bluetooth only
import 'modern_profile_screen.dart';

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
  late Animation<double> _pageEntranceFade;
  late Animation<Offset> _pageEntranceSlide;
  
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
  
  // Badge counts - can be updated from providers/state later
  int _messagesUnreadCount = 0; // Example: will be connected to real data
  int _callsActiveCount = 0; // Example: active calls or emergency alerts
  
  final List<Widget> _screens = [
    const ModernHomeScreen(),
    const LocalChatScreen(),
    const WalkieTalkieScreen(),
    const ModernProfileScreen(),
  ];

  final List<NavigationItem> _navigationItems = [
    const NavigationItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Home',
      color: AppColors.primaryRed,
    ),
    const NavigationItem(
      icon: Icons.chat_outlined,
      activeIcon: Icons.chat,
      label: 'Local Chat',
      color: AppColors.online,
    ),
    const NavigationItem(
      icon: Icons.call_outlined,
      activeIcon: Icons.call,
      label: 'Calls',
      color: AppColors.warning,
    ),
    const NavigationItem(
      icon: Icons.person_outlined,
      activeIcon: Icons.person,
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
    // Exit animation: fade out (quick and clean)
    _pageExitController = AnimationController(
      duration: const Duration(milliseconds: 200),
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
      end: const Offset(0, -0.02), // Subtle slide up on exit
    ).animate(CurvedAnimation(
      parent: _pageExitController,
      curve: Curves.easeInCubic,
    ));
    
    // Entrance animation: fade in + slide up
    _pageEntranceController = AnimationController(
      duration: const Duration(milliseconds: 350),
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
      begin: const Offset(0, 0.08), // Slide up from 8% below
      end: Offset.zero,
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
    super.dispose();
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
      
      // Start exit animation first (fade out + subtle slide up)
      _pageExitController.forward().then((_) {
        // After exit completes, switch page and start entrance
        setState(() {
          _currentIndex = index;
        });
        
        // Start entrance animation (fade in + slide up)
        _pageEntranceController.forward().then((_) {
          _iconAnimationController.reverse();
          // Reset exit controller for next transition
          _pageExitController.reset();
          // Keep entrance visible for next transition
          _pageEntranceController.value = 1.0;
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
                animation: _pageExitController,
                builder: (context, child) {
                  return Positioned.fill(
                    child: IgnorePointer(
                      child: FadeTransition(
                        opacity: _pageExitFade,
                        child: SlideTransition(
                          position: _pageExitSlide,
                          child: IndexedStack(
                            index: _previousIndex,
                            children: _screens,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            // Entering page (current page with entrance animation)
            AnimatedBuilder(
              animation: _pageEntranceController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _pageEntranceFade,
                  child: SlideTransition(
                    position: _pageEntranceSlide,
                    child: IndexedStack(
                      index: _currentIndex,
                      children: _screens,
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
                color: AppColors.lightGray.withOpacity(0.35), // subtle ring to distinguish
                width: 1.2,
              ),
              boxShadow: SoftUIDesign.getCardShadow(elevation: 6.0), // Soft UI shadow for nav bar
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
                  // Sliding pill indicator (from prototype: smooth transition with spring)
                  AnimatedPositioned(
                    duration: PrototypeAnimations.navTransitionDuration, // 400ms
                    curve: Curves.easeInOutCubic,
                    left: itemWidth * _currentIndex,
                    width: itemWidth,
                    top: 6,
                    bottom: 6,
                    child: AnimatedContainer(
                      duration: PrototypeAnimations.navTransitionDuration,
                      curve: Curves.easeInOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: _navigationItems[_currentIndex].color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onTabTapped(index),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    ...SoftUIDesign.getSoftShadow(elevation: 3.0, shadowColor: item.color.withOpacity(0.2)),
                    // Subtle glow overlay for active items
                    ...SoftUIDesign.getGlowOverlay(color: item.color, intensity: 0.08, blur: 6.0),
                  ]
                : [
                    // Subtle shadow for unselected items
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
              // Enhanced icon with multiple animations and badge
              Semantics(
                selected: isSelected,
                label: item.label,
                child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Active dot above the icon (centered), matching icon color
                  if (isSelected)
                    Positioned(
                      top: -10,
                      left: 0,
                      right: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: item.color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: item.color.withOpacity(0.35),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Subtle color-matched gradient glow behind each icon
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeInOutCubic,
                          width: isSelected ? 66 : 46,
                          height: isSelected ? 66 : 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: RadialGradient(
                              center: Alignment.center,
                              radius: 0.85,
                              colors: [
                                item.color.withOpacity(isSelected ? 0.18 : 0.06),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Icon with wobble animation and glow effect
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _iconScaleAnimation,
                      if (_iconWobbleControllers.containsKey(index)) ...[
                        _iconWobbleScaleAnimations[index]!,
                        _iconWobbleRotateAnimations[index]!,
                      ],
                      if (isSelected) _glowPulseAnimation,
                    ]),
                    builder: (context, child) {
                      final baseScale = isSelected ? _iconScaleAnimation.value : 1.0;
                      final wobbleScale = _iconWobbleControllers.containsKey(index) && 
                          _iconWobbleControllers[index]!.isAnimating
                          ? _iconWobbleScaleAnimations[index]!.value
                          : 1.0;
                      final wobbleRotate = _iconWobbleControllers.containsKey(index) && 
                          _iconWobbleControllers[index]!.isAnimating
                          ? _iconWobbleRotateAnimations[index]!.value
                          : 0.0;
                      final glowOpacity = isSelected ? _glowPulseAnimation.value : 0.0;

                      return Container(
                        decoration: isSelected
                            ? BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: item.color.withOpacity(glowOpacity),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ],
                              )
                            : null,
                        child: Transform.scale(
                          scale: baseScale * wobbleScale,
                          child: Transform.rotate(
                            angle: wobbleRotate,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 320),
                              curve: Curves.easeInOutCubic,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSelected ? item.color : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                                // Color-matched ring around active icon tile
                                border: isSelected
                                    ? Border.all(
                                        color: item.color.withOpacity(0.25),
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
                                      scale: Tween<double>(begin: 0.98, end: 1.0).animate(animation),
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0, 0.06),
                                          end: const Offset(0, 0),
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    ),
                                  );
                                },
                                child: Icon(
                                  isSelected ? item.activeIcon : item.icon,
                                  key: ValueKey(isSelected),
                                  color: isSelected ? Colors.white : AppColors.mediumGray,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Badge counter - positioned top-right of icon
                  if (_shouldShowBadge(index))
                    Positioned(
                      right: -2,
                      top: -2,
                      child: SolidBadge(
                        count: _getBadgeCount(index),
                        backgroundColor: AppColors.primaryRed,
                      ),
                    ),
                ],
              )),
              const SizedBox(height: 6),
              // Enhanced label with smooth transitions
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                style: TextStyle(
                  fontSize: isSelected ? 12 : 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? item.color : AppColors.mediumGray,
                  letterSpacing: isSelected ? 0.3 : 0.2,
                  height: 1.1,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeInOutCubic,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSelected ? 8 : 4,
                    vertical: isSelected ? 2 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? item.color.withOpacity(0.1) 
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                    child: Text(
                      item.label,
                      key: ValueKey(isSelected),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              // Underline indicator matching icon color (subtle)
              AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeInOutCubic,
                margin: const EdgeInsets.only(top: 4),
                height: 3,
                width: isSelected ? 16 : 0,
                decoration: BoxDecoration(
                  color: item.color.withOpacity(isSelected ? 0.8 : 0.0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
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
