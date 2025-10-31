import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/soft_ui_design.dart';
import '../providers/network_provider.dart';
import '../widgets/solid_badge.dart';
import 'modern_home_screen.dart';
import 'esp32_lora_chat_screen.dart';
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
  late PageController _pageController;
  late AnimationController _animationController;
  late AnimationController _iconAnimationController;
  late Animation<double> _iconScaleAnimation;
  
  // Badge counts - can be updated from providers/state later
  int _messagesUnreadCount = 0; // Example: will be connected to real data
  int _callsActiveCount = 0; // Example: active calls or emergency alerts
  
  final List<Widget> _screens = [
    const ModernHomeScreen(),
    const ESP32LoRaChatScreen(),
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
      color: AppColors.mediumGray,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _iconAnimationController = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );

    // Smoother, subtle scale animation for icons
    _iconScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.08,
    ).animate(CurvedAnimation(
      parent: _iconAnimationController,
      curve: Curves.easeInOutCubic,
    ));

    // Initialize network connection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final networkProvider = Provider.of<NetworkProvider>(context, listen: false);
      networkProvider.connectToNetwork();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _iconAnimationController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    // Trigger smooth animations
    _iconAnimationController.forward().then((_) {
      _iconAnimationController.reverse();
    });
    HapticFeedback.selectionClick();
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      HapticFeedback.lightImpact();
      
      // Start animations before page transition
      _iconAnimationController.forward();
      
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      ).then((_) {
        // Complete animations after page transition
        _iconAnimationController.reverse();
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
        child: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          physics: const ClampingScrollPhysics(), // Smoother physics for better control
          children: _screens,
        ),
      ),
      bottomNavigationBar: Container(
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
                  // Sliding pill indicator
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOutCubic,
                    left: itemWidth * _currentIndex,
                    width: itemWidth,
                    top: 6,
                    bottom: 6,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
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
    );
  }


  Widget _buildModernNavItem(int index, NavigationItem item) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
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
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedBuilder(
                    animation: _iconScaleAnimation,
                    builder: (context, child) {
                      final scale = isSelected ? _iconScaleAnimation.value : 1.0;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeInOutCubic,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected ? item.color : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: ScaleTransition(
                                scale: Tween<double>(begin: 0.98, end: scale).animate(animation),
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
              ),
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
            ],
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
