import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../utils/neumorphic_utils.dart';
import '../widgets/modern_gradient_button.dart';
import '../providers/auth_provider.dart';

class InteractiveTutorialScreen extends StatefulWidget {
  const InteractiveTutorialScreen({super.key});

  @override
  State<InteractiveTutorialScreen> createState() =>
      _InteractiveTutorialScreenState();
}

class _InteractiveTutorialScreenState extends State<InteractiveTutorialScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _buttonController;
  late AnimationController _progressController;

  int _currentPage = 0;
  final int _totalPages = 5;
  bool _isLastPage = false;

  final List<TutorialPageData> _pages = [
    TutorialPageData(
      title: 'Welcome to\nT.U.L.O.N.G',
      description:
          'Your trusted companion during emergencies. Stay connected, informed, and safe.',
      icon: Icons.shield_outlined,
      iconColor: AppColors.primaryRed,
      features: [
        TutorialFeature(
          icon: Icons.notifications_active,
          title: 'Instant Alerts',
          description: 'Get real-time disaster notifications',
        ),
        TutorialFeature(
          icon: Icons.people,
          title: 'Community',
          description: 'Connect with neighbors and family',
        ),
        TutorialFeature(
          icon: Icons.offline_bolt,
          title: 'Works Offline',
          description: 'Access even without internet',
        ),
      ],
    ),
    TutorialPageData(
      title: 'Emergency\nAlerts',
      description:
          'Receive critical warnings about typhoons, earthquakes, fires, and floods in your area.',
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.orange,
      features: [
        TutorialFeature(
          icon: Icons.thunderstorm,
          title: 'Weather Alerts',
          description: 'Typhoon and storm warnings',
        ),
        TutorialFeature(
          icon: Icons.terrain,
          title: 'Earthquake Updates',
          description: 'Real-time seismic activity',
        ),
        TutorialFeature(
          icon: Icons.water_damage,
          title: 'Flood Warnings',
          description: 'Water level monitoring',
        ),
      ],
    ),
    TutorialPageData(
      title: 'Community\nChat',
      description:
          'Share information, request help, and support others in your community during emergencies.',
      icon: Icons.chat_bubble_outline,
      iconColor: Colors.blue,
      features: [
        TutorialFeature(
          icon: Icons.group,
          title: 'Global Chat',
          description: 'Connect with your community',
        ),
        TutorialFeature(
          icon: Icons.mic,
          title: 'Voice Messages',
          description: 'Walkie-talkie feature',
        ),
        TutorialFeature(
          icon: Icons.send,
          title: 'Quick Messaging',
          description: 'Send and receive messages',
        ),
      ],
    ),
    TutorialPageData(
      title: 'Offline\nMode',
      description:
          'T.U.L.O.N.G works even without internet. Messages sync automatically when connected.',
      icon: Icons.cloud_off_outlined,
      iconColor: Colors.purple,
      features: [
        TutorialFeature(
          icon: Icons.save,
          title: 'Auto-Save',
          description: 'Messages stored locally',
        ),
        TutorialFeature(
          icon: Icons.sync,
          title: 'Auto-Sync',
          description: 'Syncs when online',
        ),
        TutorialFeature(
          icon: Icons.battery_charging_full,
          title: 'Low Power Mode',
          description: 'Optimized for emergencies',
        ),
      ],
    ),
    TutorialPageData(
      title: 'You\'re\nAll Set!',
      description:
          'You\'re ready to use T.U.L.O.N.G. Stay safe and connected during emergencies.',
      icon: Icons.check_circle_outline,
      iconColor: Colors.green,
      features: [
        TutorialFeature(
          icon: Icons.safety_check,
          title: 'Stay Prepared',
          description: 'Keep emergency contacts updated',
        ),
        TutorialFeature(
          icon: Icons.location_on,
          title: 'Enable Location',
          description: 'For accurate alerts',
        ),
        TutorialFeature(
          icon: Icons.notifications,
          title: 'Allow Notifications',
          description: 'Never miss critical alerts',
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _buttonController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeTutorial();
    }
  }

  void _previousPage() {
    HapticFeedback.lightImpact();
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _completeTutorial() async {
    HapticFeedback.mediumImpact();
    
    if (mounted) {
      // Mark tutorial as completed using AuthProvider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.markTutorialCompleted();
      
      // Check if user is Google Auth and needs address setup
      if (authProvider.isAddressSetupRequired) {
        // Redirect to address setup for Google Auth users
        Navigator.of(context).pushReplacementNamed('/address-setup');
      } else {
        // Go directly to main app for regular users
        Navigator.of(context).pushReplacementNamed('/main');
      }
    }
  }

  void _skipTutorial() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Skip Tutorial?'),
        content: const Text(
          'Are you sure you want to skip the tutorial? You can always view it later in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ModernGradientButton(
            text: 'Skip',
            onPressed: () {
              Navigator.pop(context);
              _completeTutorial();
            },
            height: 40,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neumorphicBase,
      body: SafeArea(
        child: Column(
          children: [
            // Header with skip button
            _buildHeader(),

            // Page indicator
            _buildPageIndicator(),

            // Main content (swipeable pages)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                    _isLastPage = index == _totalPages - 1;
                  });
                  HapticFeedback.selectionClick();
                  _progressController.forward(from: 0);
                },
                itemCount: _totalPages,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index], index);
                },
              ),
            ),

            // Navigation buttons
            _buildNavigationButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: NeumorphicUtils.getModernGradient(),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: NeumorphicUtils.getCardElevation(2),
                ),
                child: const Icon(
                  Icons.shield,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'T.U.L.O.N.G',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryRed,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),

          // Skip button
          if (!_isLastPage)
            TextButton(
              onPressed: _skipTutorial,
              child: const Text(
                'Skip',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_totalPages, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: _currentPage == index ? 32 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: _currentPage == index
                  ? NeumorphicUtils.getModernGradient()
                  : null,
              color: _currentPage == index
                  ? null
                  : AppColors.mediumGray.withOpacity(0.3),
              boxShadow: _currentPage == index
                  ? [
                      BoxShadow(
                        color: AppColors.primaryRed.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPage(TutorialPageData page, int index) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Animated icon
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 800),
            tween: Tween(begin: 0.0, end: 1.0),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      ...NeumorphicUtils.getNeumorphicShadow(depth: 12),
                      BoxShadow(
                        color: page.iconColor.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    page.icon,
                    size: 60,
                    color: page.iconColor,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 32),

          // Title
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 600),
            tween: Tween(begin: 0.0, end: 1.0),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Text(
                    page.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      height: 1.2,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Description
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 800),
            tween: Tween(begin: 0.0, end: 1.0),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Text(
                    page.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 40),

          // Features
          ...page.features.asMap().entries.map((entry) {
            final featureIndex = entry.key;
            final feature = entry.value;
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 600 + (featureIndex * 100)),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: _buildFeatureCard(feature),
                  ),
                );
              },
            );
          }).toList(),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(TutorialFeature feature) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: NeumorphicUtils.getNeumorphicShadow(depth: 4),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryRed.withOpacity(0.2),
                  AppColors.primaryRed.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              feature.icon,
              color: AppColors.primaryRed,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  feature.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          if (_currentPage > 0)
            ModernIconButton(
              icon: Icons.arrow_back,
              onPressed: _previousPage,
              color: AppColors.textPrimary,
              backgroundColor: Colors.white,
            )
          else
            const SizedBox(width: 48),

          // Next/Get Started button
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ModernGradientButton(
                text: _isLastPage ? 'Get Started' : 'Next',
                icon: _isLastPage ? Icons.check : Icons.arrow_forward,
                onPressed: _nextPage,
                height: 56,
              ),
            ),
          ),

          // Placeholder for symmetry
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

// Data models
class TutorialPageData {
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final List<TutorialFeature> features;

  TutorialPageData({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.features,
  });
}

class TutorialFeature {
  final IconData icon;
  final String title;
  final String description;

  TutorialFeature({
    required this.icon,
    required this.title,
    required this.description,
  });
}

