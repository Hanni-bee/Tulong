import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import 'package:lottie/lottie.dart';
import '../widgets/modern_neumorphic_card.dart';
import '../widgets/modern_responsive_layout.dart';
import '../widgets/modern_toast.dart';
import '../widgets/modern_network_indicator.dart';
import '../widgets/modern_floating_layout.dart';
import '../widgets/emergency_alert_widget.dart';
import '../widgets/enhanced_text_styles.dart';
import '../widgets/enhanced_shadows.dart' as shadows;
import '../widgets/micro_interactions.dart';
import '../widgets/enhanced_card.dart';
import '../widgets/polished_animations.dart';
import '../utils/page_transitions.dart';
import '../utils/phone_responsive_helper.dart';
import '../config/page_transition_config.dart';
import '../providers/auth_provider.dart';
import '../services/offline_messaging_service.dart';
import 'enhanced_global_chat_screen.dart';
import 'walkie_talkie_screen.dart';
import 'modern_people_screen.dart';
import 'modern_profile_screen.dart';
import 'disaster_demo_screen.dart';

class ModernHomeScreen extends StatefulWidget {
  const ModernHomeScreen({super.key});

  @override
  State<ModernHomeScreen> createState() => _ModernHomeScreenState();
}

class _ModernHomeScreenState extends State<ModernHomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _welcomeController;
  late AnimationController _emergencyHoldController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _welcomeAnimation;
  
  bool _isInitializing = true;
  bool _showWelcome = false;
  bool _isEmergencyHolding = false;


  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _welcomeController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _emergencyHoldController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          HapticFeedback.heavyImpact();
          setState(() {
            _isEmergencyHolding = false;
          });
          _emergencyHoldController.reset();
          _showEmergencyDialog(context);
        }
      });
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _welcomeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _welcomeController,
      curve: Curves.elasticOut,
    ));

    _fadeController.forward();
    _slideController.forward();
    
    // Simulate initialization and show welcome animation
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      // Check if welcome banner has been shown before
      final prefs = await SharedPreferences.getInstance();
      final hasSeenWelcome = prefs.getBool('has_seen_welcome_banner') ?? false;
      
      setState(() {
        _isInitializing = false;
        _showWelcome = !hasSeenWelcome; // Only show if not seen before
      });
      
      if (_showWelcome) {
        // Start welcome animation
        _welcomeController.forward();
        
        // Mark welcome banner as seen
        await prefs.setBool('has_seen_welcome_banner', true);
        
        // Hide welcome animation after 3 seconds
        await Future.delayed(const Duration(milliseconds: 3000));
        if (mounted) {
          setState(() {
            _showWelcome = false;
          });
        }
      }
    }
  }


  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _welcomeController.dispose();
    _emergencyHoldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ModernFloatingLayout(
      hasFloatingAppBar: false,
      hasFloatingBottomBar: true,
      child: ModernNetworkStatusBar(
        child: Stack(
          children: [
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Section
                      PolishedFadeIn(
                        delay: const Duration(milliseconds: 100),
                        child: _buildHeader(),
                      ),
                      const SizedBox(height: 12),
                      
                      // Quick Actions
                      PolishedFadeIn(
                        delay: const Duration(milliseconds: 200),
                        child: PrimaryCard(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildQuickActions(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Recent Activity
                      PolishedFadeIn(
                        delay: const Duration(milliseconds: 300),
                        child: SecondaryCard(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildRecentActivity(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Emergency Section
                      PolishedFadeIn(
                        delay: const Duration(milliseconds: 400),
                        child: AccentCard(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          accentColor: AppColors.emergency,
                          child: _buildEmergencySection(),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Sample Emergency Alert with GIF
                      PolishedFadeIn(
                        delay: const Duration(milliseconds: 500),
                        child: _buildSampleEmergencyAlert(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Welcome animation overlay
            if (_showWelcome)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _welcomeAnimation,
                  builder: (context, child) {
                    return Container(
                      color: AppColors.backgroundLight.withOpacity(0.95),
                      child: Center(
                        child: Transform.scale(
                          scale: _welcomeAnimation.value,
                          child: Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryRed.withOpacity(0.2),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color: AppColors.white.withOpacity(0.8),
                                  blurRadius: 30,
                                  offset: const Offset(0, -10),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Welcome icon
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryRed,
                                    borderRadius: BorderRadius.circular(40),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryRed.withOpacity(0.3),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.check_circle,
                                    color: AppColors.white,
                                    size: 40,
                                  ),
                                ),
                                
                                const SizedBox(height: 12),
                                
                                // Welcome text
                                const PageTitle('Welcome Back!'),
                                
                                const SizedBox(height: 12),
                                
                                const BodyText('Emergency network is ready'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Inline, lightweight init animation (no blocking overlay)
            if (_isInitializing)
              Positioned(
                top: 8,
                left: 16,
                right: 16,
                child: AnimatedOpacity(
                  opacity: _isInitializing ? 1 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: Lottie.asset('assets/lottie/loading.json', fit: BoxFit.contain),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Initializing T.U.L.O.N.G...',
                          style: TextStyle(
                            color: AppColors.primaryRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Compact header card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: AppColors.white,
            border: Border.all(
              color: AppColors.primaryRed.withOpacity(0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryRed.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // App Logo - Compact size
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryRed.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/app_logo (3).png',
                      width: 60,
                      height: 60,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // App Info - Compact layout
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'T.U.L.O.N.G',
                        style: AppTypography.titleLarge.copyWith(
                          color: AppColors.primaryRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Emergency Communication',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.mediumGray,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.primaryRed,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }


  Widget _buildQuickActions() {
    return PhoneResponsiveBuilder(
      builder: (context, screenSize) {
        return Container(
          padding: PhoneResponsiveHelper.getPhonePadding(context),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(PhoneResponsiveHelper.getPhoneBorderRadius(context)),
            border: Border.all(
              color: AppColors.primaryRed.withOpacity(0.06),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: PhoneResponsiveHelper.getPhoneSpacing(context) * 0.5,
                      vertical: PhoneResponsiveHelper.getPhoneSpacing(context) * 0.25,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(PhoneResponsiveHelper.getPhoneBorderRadius(context) * 0.5),
                    ),
                    child: Text(
                      'Quick Actions',
                      style: AppTypography.cardTitle.copyWith(
                        color: AppColors.primaryRed,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Tap to use',
                    style: AppTypography.captionText.copyWith(
                      color: AppColors.primaryRed.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 100, // Reduced height for more compact layout
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  children: [
                    _buildUniformActionButton(
                      onPressed: () => _showEmergencyDialog(context),
                      backgroundColor: AppColors.error,
                      icon: Icons.emergency,
                      title: 'Emergency',
                      subtitle: 'Alert',
                    ),
                    const SizedBox(width: 8), // Reduced spacing between buttons
                    _buildUniformActionButton(
                      onPressed: () => _navigateToChat(context),
                      backgroundColor: AppColors.info,
                      icon: Icons.message_rounded,
                      title: 'Send',
                      subtitle: 'Message',
                    ),
                    const SizedBox(width: 8), // Reduced spacing between buttons
                    _buildUniformActionButton(
                      onPressed: () => _navigateToWalkieTalkie(context),
                      backgroundColor: AppColors.success,
                      icon: Icons.call_rounded,
                      title: 'Voice',
                      subtitle: 'Call',
                    ),
                    const SizedBox(width: 8), // Reduced spacing between buttons
                    _buildUniformActionButton(
                      onPressed: () => _navigateToPeople(context),
                      backgroundColor: AppColors.warning,
                      icon: Icons.people_rounded,
                      title: 'People',
                      subtitle: 'Contacts',
                    ),
                    const SizedBox(width: 8), // Reduced spacing between buttons
                    _buildUniformActionButton(
                      onPressed: () => _navigateToProfile(context),
                      backgroundColor: AppColors.primaryRed,
                      icon: Icons.person_rounded,
                      title: 'Profile',
                      subtitle: 'Settings',
                    ),
                    const SizedBox(width: 8), // Reduced spacing between buttons
                    _buildUniformActionButton(
                      onPressed: () => _navigateToDisasterDemo(context),
                      backgroundColor: Colors.purple,
                      icon: Icons.science,
                      title: 'Disaster',
                      subtitle: 'Demo',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUniformActionButton({
    required VoidCallback onPressed,
    required Color backgroundColor,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return PhoneResponsiveBuilder(
      builder: (context, screenSize) {
        return InteractiveButton(
          onPressed: onPressed,
          backgroundColor: backgroundColor,
          padding: const EdgeInsets.all(12),
          borderRadius: BorderRadius.circular(12),
          shadows: shadows.EnhancedShadows.buttonMedium,
          child: SizedBox(
            width: 80, // More compact width
            height: 80, // More compact height
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon, 
                  color: AppColors.white, 
                  size: 24, // Slightly smaller icon
                ),
                const SizedBox(height: 6), // Reduced spacing
                Text(
                  title,
                  style: AppTypography.buttonLabel.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12, // Smaller font size
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1), // Minimal spacing
                Text(
                  subtitle,
                  style: AppTypography.captionText.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 10, // Smaller font size
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primaryRed.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const AccentText('Recent Activity'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ModernNeumorphicCard(
            child: Column(
              children: [
                _buildActivityItem(
                  icon: Icons.message,
                  title: 'New message from User 1',
                  subtitle: '2 minutes ago',
                  color: AppColors.info,
                ),
                const Divider(height: 32),
                _buildActivityItem(
                  icon: Icons.emergency,
                  title: 'Emergency alert resolved',
                  subtitle: '15 minutes ago',
                  color: AppColors.success,
                ),
                const Divider(height: 24),
                _buildActivityItem(
                  icon: Icons.network_check,
                  title: 'Network connection restored',
                  subtitle: '1 hour ago',
                  color: AppColors.success,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ModernResponsiveText(
                text: title,
                isSubtitle: true,
              ),
              const SizedBox(height: 2),
              ModernResponsiveText(
                text: subtitle,
                isCaption: true,
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildEmergencyButton() {
    const double btnSize = 80.0;
    
    return GestureDetector(
      onLongPressStart: (_) {
        HapticFeedback.selectionClick();
        setState(() => _isEmergencyHolding = true);
        _emergencyHoldController.forward(from: 0);
      },
      onLongPressEnd: (_) {
        if (_emergencyHoldController.status != AnimationStatus.completed) {
          _emergencyHoldController.reverse(from: _emergencyHoldController.value);
        }
        setState(() => _isEmergencyHolding = false);
      },
      onLongPressCancel: () {
        _emergencyHoldController.reverse(from: _emergencyHoldController.value);
        setState(() => _isEmergencyHolding = false);
      },
      child: SizedBox(
        width: btnSize + 18,
        height: btnSize + 18,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: btnSize + 12,
              height: btnSize + 12,
              child: AnimatedBuilder(
                animation: _emergencyHoldController,
                builder: (context, _) => CircularProgressIndicator(
                  value: _isEmergencyHolding ? _emergencyHoldController.value : 0,
                  strokeWidth: 6,
                  backgroundColor: const Color(0xFFE53935).withOpacity(0.12),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFE53935)),
                ),
              ),
            ),
            Container(
              width: btnSize,
              height: btnSize,
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.emergency,
                color: AppColors.white,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencySection() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.error.withOpacity(0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Emergency Controls',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 20),
        Center(
          child: _buildEmergencyButton(),
        ),
        const SizedBox(height: 20),
        const ModernResponsiveText(
          text: 'Hold to send emergency alert to all connected users',
          isCaption: true,
          textAlign: TextAlign.center,
        ),
        ],
      ),
    );
  }

  Widget _buildSampleEmergencyAlert() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primaryRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppColors.primaryRed,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Sample Emergency Alert',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryRed,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        EmergencyAlertWidget(
          title: 'Emergency System Active', // Shortened title to prevent wrapping
          message: 'Emergency alert system is monitoring for disasters and will automatically notify all users in your area.',
          severity: 'High',
          showGif: true,
          gifPath: 'assets/gifs/disasters/emergency.gif',
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              ModernPageRoute(
                child: const DisasterDemoScreen(),
                transitionType: ModernTransitionType.slideAndFade,
              ),
            );
          },
        ),
      ],
    );
  }

  void _navigateToChat(BuildContext context) {
    HapticFeedback.mediumImpact();
    context.pushPage(const EnhancedGlobalChatScreen());
  }

  void _navigateToWalkieTalkie(BuildContext context) {
    HapticFeedback.mediumImpact();
    context.pushPage(const WalkieTalkieScreen());
  }

  void _navigateToPeople(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      ModernPageRoute(
        child: const ModernPeopleScreen(),
        transitionType: ModernTransitionType.slideAndFade,
      ),
    );
  }

  void _navigateToProfile(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      ModernPageRoute(
        child: const ModernProfileScreen(),
        transitionType: ModernTransitionType.slideAndFade,
      ),
    );
  }

  void _navigateToDisasterDemo(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pushNamed('/disaster-demo');
  }


  Future<void> _sendEmergencyAlertDirectly(BuildContext context, String emergencyMessage) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.currentUserModel;
      final userId = authProvider.currentUser ?? authProvider.userEmail ?? 'unknown';
      
      // Build location string from user's address data
      String location = 'Unknown Location';
      if (user != null) {
        final locationParts = <String>[];
        if (user.street.isNotEmpty) locationParts.add(user.street);
        if (user.barangay.isNotEmpty) locationParts.add(user.barangay);
        if (user.city.isNotEmpty) locationParts.add(user.city);
        if (user.province.isNotEmpty) locationParts.add(user.province);
        if (user.region.isNotEmpty) locationParts.add(user.region);
        
        if (locationParts.isNotEmpty) {
          location = locationParts.join(', ');
        } else {
          location = 'Location not set';
        }
      }
      
      HapticFeedback.heavyImpact();
      
      // Send emergency alert using OfflineMessagingService
      final messagingService = OfflineMessagingService();
      await messagingService.sendEmergencyAlert(
        message: emergencyMessage,
        location: location,
        userId: userId,
      );
      
      if (context.mounted) {
        ModernToastManager.showSuccess(
          context,
          'Emergency alert sent: "$emergencyMessage"',
        );
      }
    } catch (e) {
      if (context.mounted) {
        ModernToastManager.showError(
          context,
          'Failed to send emergency alert: ${e.toString()}',
        );
      }
    }
  }

  void _showEmergencyDialog(BuildContext context) {
    HapticFeedback.heavyImpact();
    final authProvider = context.read<AuthProvider>();
    
    // Get emergency message from profile (from AuthProvider)
    String emergencyMessage;
    if (authProvider.emergencyMessage != null && authProvider.emergencyMessage!.isNotEmpty) {
      emergencyMessage = authProvider.emergencyMessage!;
    } else if (authProvider.emergencyMessages.isNotEmpty) {
      final defaultIndex = authProvider.defaultEmergencyMessageIndex ?? 0;
      if (defaultIndex >= 0 && defaultIndex < authProvider.emergencyMessages.length) {
        emergencyMessage = authProvider.emergencyMessages[defaultIndex];
      } else {
        emergencyMessage = authProvider.emergencyMessages[0];
      }
    } else {
      emergencyMessage = 'Emergency! Please help and contact me immediately.';
    }
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isSending = false;
            
            Widget buildSendButtonChild() {
              if (isSending) {
                return const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: AppColors.white,
                    strokeWidth: 2,
                  ),
                );
              }
              return const Text('Send Alert');
            }
            
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.emergency,
                      color: AppColors.error,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Emergency Alert',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This will send an emergency alert to all connected users in your network.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Message to send:',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLight.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderColor),
                    ),
                    child: Text(
                      emergencyMessage,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                if (!isSending)
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppColors.mediumGray,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                AbsorbPointer(
                  absorbing: isSending,
                  child: ElevatedButton(
                    onPressed: () async {
                      setDialogState(() {
                        isSending = true;
                      });
                      
                      HapticFeedback.heavyImpact();
                      
                      // Use the direct send method with the message from profile
                      await _sendEmergencyAlertDirectly(context, emergencyMessage);
                      
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: buildSendButtonChild(),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
