import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../utils/theme_colors.dart';
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
  final int _totalPages = 6;
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
      title: 'SOS\nAlert',
      description:
          'Receive critical warnings about typhoons, earthquakes, fires, and floods in your area.',
      icon: Icons.sos_rounded,
      iconColor: AppColors.primaryRed,
      features: [
        TutorialFeature(
          icon: Icons.campaign_rounded,
          title: 'Emergency Message Trigger',
          description: 'Sends a pre-set emergency message when the device button is pressed.',
        ),
        TutorialFeature(
          icon: Icons.notifications_active_rounded,
          title: 'Instant SoS Notification',
          description: 'Delivers an emergency alert from a nearby device.',
        ),
        TutorialFeature(
          icon: Icons.emergency_rounded,
          title: 'One-Press Safety Alert',
          description: 'Sends an emergency message with one button press.',
        ),
      ],
      howToSteps: [
        TutorialHowToStep(
          stepNumber: 1,
          icon: Icons.bluetooth_connected_rounded,
          text: 'Ensure that your mobile phone is connected to the device',
        ),
        TutorialHowToStep(
          stepNumber: 2,
          icon: Icons.edit_note_rounded,
          text: 'Enter your emergency message in the pre-set text field.',
        ),
        TutorialHowToStep(
          stepNumber: 3,
          icon: Icons.touch_app_rounded,
          text: 'In case of emergency, long-press the SOS button.',
        ),
        TutorialHowToStep(
          stepNumber: 4,
          icon: Icons.check_circle_outline_rounded,
          text: 'Confirm the action to send your emergency message to nearby devices.',
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
      howToSteps: [
        TutorialHowToStep(
          stepNumber: 1,
          icon: Icons.bluetooth_connected_rounded,
          text: 'Make sure your mobile phone is connected to the device.',
        ),
        TutorialHowToStep(
          stepNumber: 2,
          icon: Icons.chat_bubble_outline_rounded,
          text: 'Once connected, type your message in the text field and send it to other nearby nodes.',
        ),
        TutorialHowToStep(
          stepNumber: 3,
          icon: Icons.mic_rounded,
          text: 'For voice messages, tap and hold the voice message icon while speaking, then release it to send.',
        ),
      ],
    ),
    TutorialPageData(
      title: 'AI Severity\nAssessment',
      description:
          'Capture the scene, get an instant severity assessment, and share it with your community for awareness.',
      icon: Icons.psychology_rounded,
      iconColor: Colors.deepOrange,
      features: [
        TutorialFeature(
          icon: Icons.photo_camera_rounded,
          title: 'Disaster Detection',
          description: 'Captures the current situation and analyzes the severity of the disaster.',
        ),
        TutorialFeature(
          icon: Icons.analytics_rounded,
          title: 'Severity Analysis',
          description: 'Provides an instant assessment of how serious the situation is.',
        ),
        TutorialFeature(
          icon: Icons.share_rounded,
          title: 'Community Information Sharing',
          description: 'Sends the analyzed information directly to the Community Chat to inform other nodes.',
        ),
      ],
      howToSteps: [
        TutorialHowToStep(
          stepNumber: 1,
          icon: Icons.bluetooth_connected_rounded,
          text: 'Make sure your mobile phone is connected to the device.',
        ),
        TutorialHowToStep(
          stepNumber: 2,
          icon: Icons.photo_camera_rounded,
          text: 'Tap the camera icon and capture the current disaster in front of you.',
        ),
        TutorialHowToStep(
          stepNumber: 3,
          icon: Icons.send_rounded,
          text: 'Once the severity result appears, you can choose to send it to other nearby nodes through the Community Chat for awareness.',
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
          icon: Icons.battery_charging_full,
          title: 'Low Power Mode',
          description: 'Optimized for emergencies',
        ),
      ],
    ),
    TutorialPageData(
      title: 'You\'re\nAll Set!',
      description:
          'You\'re ready to use Tulong, stay safe and follow these reminders and keep your device connected.',
      icon: Icons.check_circle_outline,
      iconColor: Colors.green,
      features: [
        TutorialFeature(
          icon: Icons.notifications_active_rounded,
          title: 'Turn on Notifications',
          description: 'To receive all emergency messages',
        ),
        TutorialFeature(
          icon: Icons.bluetooth_rounded,
          title: 'Keep Bluetooth On',
          description: 'To stay connected to your hardware device',
        ),
        TutorialFeature(
          icon: Icons.phone_android_rounded,
          title: 'Carry Your Device',
          description: 'Make sure your hardware device is always with you',
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
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _completeTutorial();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Yes, Skip'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.background(context),
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
          // App logo – red square with logo inside (match reference)
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: NeumorphicUtils.getCardElevation(2),
                ),
                padding: const EdgeInsets.all(6),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/app_logo (3).png',
                  fit: BoxFit.contain,
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
              child: Text(
                'Skip',
                style: TextStyle(
                  color: ThemeColors.textSecondary(context),
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
                    color: ThemeColors.surface(context),
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
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: ThemeColors.textPrimary(context),
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
                    style: TextStyle(
                      fontSize: 16,
                      color: ThemeColors.textSecondary(context),
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
          }),

          // How to Use this feature (when steps are provided)
          if (page.howToSteps != null && page.howToSteps!.isNotEmpty) ...[
            const SizedBox(height: 28),
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 500),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Text(
                    'How to Use This Feature',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: ThemeColors.textPrimary(context),
                      letterSpacing: -0.3,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            ...page.howToSteps!.asMap().entries.map((entry) {
              final stepIndex = entry.key;
              final step = entry.value;
              return TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 500 + (stepIndex * 80)),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 12 * (1 - value)),
                      child: _buildHowToStepCard(context, step, page.iconColor),
                    ),
                  );
                },
              );
            }),
          ],

          // Optional attribution
          if (page.attribution != null && page.attribution!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              page.attribution!,
              style: TextStyle(
                fontSize: 12,
                color: ThemeColors.textTertiary(context),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHowToStepCard(BuildContext context, TutorialHowToStep step, Color accentColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withOpacity(0.25),
          width: 1,
        ),
        boxShadow: NeumorphicUtils.getNeumorphicShadow(depth: 3),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              step.icon,
              color: accentColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step ${step.stepNumber}:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: accentColor,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.text,
                  style: TextStyle(
                    fontSize: 14,
                    color: ThemeColors.textPrimary(context),
                    height: 1.4,
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

  Widget _buildFeatureCard(TutorialFeature feature) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
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
                  style: TextStyle(
                    fontSize: 13,
                    color: ThemeColors.textSecondary(context),
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
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
  final List<TutorialHowToStep>? howToSteps;
  final String? attribution;

  TutorialPageData({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.features,
    this.howToSteps,
    this.attribution,
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

class TutorialHowToStep {
  final int stepNumber;
  final IconData icon;
  final String text;

  TutorialHowToStep({
    required this.stepNumber,
    required this.icon,
    required this.text,
  });
}

