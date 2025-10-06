import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/network_provider.dart';
import '../utils/responsive_spacing.dart';
import '../utils/phone_responsive_helper.dart';
import '../widgets/enhanced_card.dart';
import '../widgets/enhanced_text_styles.dart';
import 'modern_home_screen.dart';
import 'modern_global_chat_screen.dart';
import 'walkie_talkie_screen.dart';
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
  late AnimationController _statusController;
  late Animation<double> _statusAnimation;
  
  final List<Widget> _screens = [
    const ModernHomeScreen(),
    const ModernGlobalChatScreen(),
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
      icon: Icons.message_outlined,
      activeIcon: Icons.message,
      label: 'Chat',
      color: AppColors.success,
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
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _statusController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _statusAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _statusController,
      curve: Curves.easeInOut,
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
    _statusController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onTabTapped(int index) {
    if (_currentIndex != index) {
      HapticFeedback.lightImpact();
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient for visual depth
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFF8F9FA),
                  Color(0xFFF1F3F4),
                  Color(0xFFE8EAED),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Page content
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _screens.length,
            itemBuilder: (context, index) {
              final screen = _screens[index];
              final isCurrent = index == _currentIndex;
              return AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: isCurrent ? 1.0 : 0.85,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.95),
                        Colors.white.withOpacity(0.9),
                      ],
                    ),
                  ),
                  child: screen,
                ),
              );
            },
          ),


        ],
      ),
      bottomNavigationBar: PhoneResponsiveBuilder(
        builder: (context, screenSize) {
          return Container(
            height: PhoneResponsiveHelper.getPhoneBottomNavHeight(context) + 8,
            padding: EdgeInsets.zero,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Enhanced floating bottom bar background
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 8,
                  child: Container(
                    height: PhoneResponsiveHelper.getPhoneBottomNavHeight(context),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.95),
                          Colors.white.withOpacity(0.9),
                          Colors.white.withOpacity(0.85),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(PhoneResponsiveHelper.getPhoneBorderRadius(context) * 1.5),
                      border: Border.all(
                        color: AppColors.borderColor.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.6),
                          blurRadius: 15,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: PhoneResponsiveHelper.getPhoneSpacing(context) * 0.125,
                        vertical: PhoneResponsiveHelper.getPhoneSpacing(context) * 0.25,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: _navigationItems.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          return _buildModernNavItem(index, item);
                        }).toList(),
                      ),
                    ),
                  ),
                ),

              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNavItem(int index, NavigationItem item) {
    final isSelected = _currentIndex == index;
    
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: ResponsiveSpacing.getResponsivePadding(context, horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? item.color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected ? [
            BoxShadow(
              color: item.color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: AppColors.white.withOpacity(0.8),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ] : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.all(ResponsiveSpacing.getResponsiveSpacing(context, xs: 4, sm: 5, md: 6)),
              decoration: BoxDecoration(
                color: isSelected ? item.color : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: item.color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: AppColors.white.withOpacity(0.8),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ] : null,
              ),
              child: Icon(
                isSelected ? item.activeIcon : item.icon,
                color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                size: 20,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isSelected ? item.color : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
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
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: 60,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? item.color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            border: isSelected ? Border.all(
              color: item.color.withOpacity(0.3),
              width: 2,
            ) : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background glow effect for selected item
              if (isSelected)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.color.withOpacity(0.2),
                    boxShadow: [
                      BoxShadow(
                        color: item.color.withOpacity(0.4),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),

              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon container with enhanced styling
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected ? item.color : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: item.color.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, -2),
                        ),
                      ] : null,
                    ),
                    child: Icon(
                      isSelected ? item.activeIcon : item.icon,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                      size: 20,
                    ),
                  ),

                  const SizedBox(height: 2),

                  // Enhanced label with better typography
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? item.color : AppColors.textSecondary,
                      letterSpacing: 0.3,
                      shadows: isSelected ? [
                        Shadow(
                          color: item.color.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ] : null,
                    ),
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ),

              // Floating indicator dot
              if (isSelected)
                Positioned(
                  top: 6,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: item.color,
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color: item.color.withOpacity(0.5),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmergencyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: AppColors.backgroundLight,
          title: const Row(
            children: [
              Icon(Icons.emergency, color: AppColors.primaryRed),
              SizedBox(width: 8),
              Text('Emergency Broadcast'),
            ],
          ),
          content: const Text(
            'This will send an emergency message to all connected devices in your area. Use only in genuine emergencies.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // TODO: Implement emergency broadcast
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Emergency broadcast sent'),
                    backgroundColor: AppColors.primaryRed,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: AppColors.white,
              ),
              child: const Text('Send'),
            ),
          ],
        );
      },
    );
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
