import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import 'package:lottie/lottie.dart';
import '../widgets/modern_responsive_layout.dart';
import '../widgets/modern_toast.dart';
import '../widgets/modern_network_indicator.dart';
import '../widgets/modern_floating_layout.dart';
import '../widgets/emergency_alert_widget.dart';
import '../widgets/enhanced_text_styles.dart';
import '../widgets/polished_animations.dart';
import '../constants/soft_ui_design.dart';
import '../utils/page_transitions.dart';
import '../utils/phone_responsive_helper.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../utils/prototype_animations.dart';
import '../widgets/special_animations.dart';
import 'local_chat_screen.dart';
import 'modern_profile_screen.dart';
import 'disaster_demo_screen.dart';
import '../widgets/solid_modal_header.dart';
import '../widgets/radar_scan_modal.dart';
import '../widgets/enhanced_skeleton_loaders.dart';
import '../widgets/enhanced_micro_interactions.dart' as micro;
import '../widgets/accessible_text.dart';
import '../widgets/animated_neumorphic_card.dart';
import '../utils/icon_system.dart';
import '../utils/enhanced_page_transitions.dart';
import '../services/simple_bluetooth_service.dart';
import '../utils/address_encoder.dart';

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
  
  // Stagger animations for Quick Actions
  late StaggeredListAnimations _quickActionsStagger;
  
  bool _isInitializing = true;
  bool _showWelcome = false;
  bool _isEmergencyHolding = false;
  final bool _isLoadingStats = false;
  
  // Quick Actions list - created as getter to avoid initialization issues
  List<Map<String, dynamic>> _getQuickActions() => [
    {
      'onPressed': () => _navigateToChat(context),
      'backgroundColor': AppColors.info,
      'icon': Icons.chat_bubble_rounded, // Changed icon to match Local Chat
      'title': 'Local',
      'subtitle': 'Chat',
    },
    {
      'onPressed': () => _navigateToSettings(context),
      'backgroundColor': AppColors.warning,
      'icon': IconSystem.actionSettings,
      'title': 'Settings',
      'subtitle': 'App Config',
    },
    {
      'onPressed': () => _navigateToDisasterDemo(context),
      'backgroundColor': Colors.purple,
      'icon': Icons.science,
      'title': 'Simulate',
      'subtitle': 'Disaster',
    },
  ];


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
    
    // Initialize stagger animations for Quick Actions
    _quickActionsStagger = StaggeredListAnimations(
      vsync: this,
      itemCount: _getQuickActions().length,
    );
    
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
    _quickActionsStagger.dispose();
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
            // Subtle background overlay
            SoftUIDesign.buildScreenBackgroundOverlay(
              accentColor: AppColors.primaryRed,
              intensity: 0.012,
            ),
            
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: RefreshIndicator(
                  onRefresh: () async {
                    HapticFeedback.mediumImpact();
                    // Refresh data here
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  color: AppColors.primaryRed,
                  backgroundColor: Colors.white,
                  displacement: 60,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      // Header Section
                      PolishedFadeIn(
                        delay: const Duration(milliseconds: 100),
                        child: _buildHeader(),
                      ),
                      const SizedBox(height: 16),
                      
                      // Emergency Section (Top Priority)
                      PolishedFadeIn(
                        delay: const Duration(milliseconds: 200),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          child: SoftUIDesign.buildEnhancedCard(
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: _buildEmergencySection(),
                            ),
                            elevation: 5.0,
                            showBorder: true,
                            borderColor: AppColors.primaryRed,
                            showDepthOverlay: true,
                            showDiagonalOverlay: true,
                            showCornerAccent: true,
                            accentColor: AppColors.primaryRed,
                            isGlass: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Minimized Status Indicators
                      PolishedFadeIn(
                        delay: const Duration(milliseconds: 300),
                        child: _isLoadingStats 
                              ? Container(
                                margin: const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  children: [
                                    Expanded(child: SkeletonStatCard()),
                                    const SizedBox(width: 16),
                                    Expanded(child: SkeletonStatCard()),
                                  ],
                                ),
                              )
                            : _buildCompactStatus(),
                      ),
                      const SizedBox(height: 16),
                      
                      // Quick Actions
                      PolishedFadeIn(
                        delay: const Duration(milliseconds: 400),
                        child: _isLoadingStats
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    SkeletonQuickActionCard(),
                                    SkeletonQuickActionCard(),
                                    SkeletonQuickActionCard(),
                                  ],
                                ),
                              )
                            : _buildQuickActions(),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Sample Emergency Alert with GIF
                      PolishedFadeIn(
                        delay: const Duration(milliseconds: 500),
                        child: _buildSampleEmergencyAlert(),
                      ),
                      
                      const SizedBox(height: 120),
                      ],
                    ),
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
          decoration: SoftUIDesign.cardDecoration(
            backgroundColor: AppColors.white,
            borderRadius: SoftUIDesign.cardBorderRadius,
            elevation: 3.0,
            borderColor: AppColors.lightGray.withOpacity(0.3),
            showBorder: true,
            isGlass: true,
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
                    borderRadius: BorderRadius.circular(SoftUIDesign.cardBorderRadius),
                    boxShadow: SoftUIDesign.getButtonShadow(color: AppColors.primaryRed),
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
                      AccessibleHeading(
                        'T.U.L.O.N.G',
                        level: HeadingLevel.h3,
                        color: AppColors.primaryRed,
                        backgroundColor: AppColors.white,
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
        // Gradient accent line matching Calls/Messages/Profile style
        AnimatedContainer(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeInOutCubic,
          height: 3,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                AppColors.primaryRed.withOpacity(0.0),
                AppColors.primaryRed.withOpacity(0.85),
                AppColors.primaryRed.withOpacity(0.0),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(32), // More rounded like reference
            border: Border.all(
              color: const Color(0xFFF2F2F2), // Lighter, cleaner border
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.015), // Softer shadow
                blurRadius: 25,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24), // Optimized internal breathing room
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Red Quick Actions Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE), // Very light red
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryRed,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.flash_on_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Quick Actions',
                            style: AppTypography.cardTitle.copyWith(
                              color: AppColors.primaryRed,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Gray Tap to Use Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE0E4E8), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.touch_app_rounded,
                            color: AppColors.textSecondary.withOpacity(0.6),
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Tap to use',
                            style: AppTypography.captionText.copyWith(
                              color: AppColors.textSecondary.withOpacity(0.7),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Builder(
                  builder: (context) {
                    final quickActions = _getQuickActions();
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: quickActions.asMap().entries.map((entry) {
                        final index = entry.key;
                        final action = entry.value;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              left: index == 0 ? 0 : 4, // Tighter horizontal gaps
                              right: index == quickActions.length - 1 ? 0 : 4,
                            ),
                            child: _quickActionsStagger.buildAnimatedItem(
                              index,
                              _buildUniformActionButton(
                                onPressed: action['onPressed'] as VoidCallback,
                                backgroundColor: action['backgroundColor'] as Color,
                                icon: action['icon'] as IconData,
                                title: action['title'] as String,
                                subtitle: action['subtitle'] as String,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 4),
              ],
            ),
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
        return Container(
          height: 120, // Increased height to ensure everything fits comfortably
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: backgroundColor.withOpacity(0.12),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                onPressed();
              },
              borderRadius: BorderRadius.circular(24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // Elite style Blob
                    Positioned(
                      top: -25,
                      right: -15,
                      child: Container(
                        width: 75,
                        height: 75,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              backgroundColor.withOpacity(0.12),
                              backgroundColor.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min, // keep content block tight
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Icon Shell
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: backgroundColor.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                icon,
                                color: backgroundColor,
                                size: 24,
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Title
                            SizedBox(
                              width: double.infinity,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  title,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: const TextStyle(
                                    color: Color(0xFF1A1A1A),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    letterSpacing: -0.3,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 3),

                            // Subtitle
                            SizedBox(
                              width: double.infinity,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  subtitle,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(
                                    color: AppColors.textSecondary.withOpacity(0.55),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 9,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactStatus() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        // Get real-time connection status
        final isConnected = chatProvider.isConnected;
        
        // Get real-time user count - only count other users, not the current user
        final allUsers = chatProvider.connectedUsers;
        final currentUser = chatProvider.currentUserName;
        final nearbyUsers = allUsers.where((user) => user != currentUser && user.isNotEmpty).toList();
        final userCount = nearbyUsers.length;
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // 1. Connection Status - Shows Paired Devices List when clicked
              Expanded(
                child: _buildStatusCard(
                  icon: isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                  label: isConnected ? 'Connected' : 'Offline',
                  subLabel: isConnected ? 'Mesh Active' : 'No Signal',
                  color: isConnected ? AppColors.success : AppColors.error,
                  onTap: () => _showDeviceDialog(),
                ),
              ),
              const SizedBox(width: 16),
              
              // 2. People Nearby - Shows Radar Modal when clicked
              Expanded(
                child: _buildStatusCard(
                  icon: IconSystem.actionPeople,
                  label: '$userCount',
                  subLabel: userCount == 1 ? 'Nearby User' : 'Nearby Users',
                  color: AppColors.info,
                  onTap: () => _showRadarModal(),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required String label,
    required String subLabel,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        height: 110, // Increased height for better visibility
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withOpacity(0.4),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center, // Center horizontally
          children: [
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: color,
                ),
                if (label == 'Connected' || label == 'Offline')
                  Positioned(
                    top: -2,
                    right: -6,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.5),
                            blurRadius: 6,
                            spreadRadius: 1.5,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1.2,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.85),
                height: 1.2,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildEmergencyButton() {
    const double btnSize = 140.0; // Increased for better prominence
    
    return GestureDetector(
      onLongPressStart: (_) {
        HapticFeedback.selectionClick();
        setState(() => _isEmergencyHolding = true);
        _emergencyHoldController.forward(from: 0);
      },
      onLongPressEnd: (_) {
        if (_emergencyHoldController.status == AnimationStatus.completed) {
          // Ring completed - send emergency message
          HapticFeedback.heavyImpact();
          _sendEmergencyMessageOnRingComplete(context);
        } else {
          _emergencyHoldController.reverse(from: _emergencyHoldController.value);
        }
        setState(() => _isEmergencyHolding = false);
      },
      onLongPressCancel: () {
        _emergencyHoldController.reverse(from: _emergencyHoldController.value);
        setState(() => _isEmergencyHolding = false);
      },
      child: SizedBox(
        width: btnSize + 24,
        height: btnSize + 24,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow ring (pulsing)
            AnimatedBuilder(
              animation: _welcomeAnimation,
              builder: (context, _) {
                return Container(
                  width: btnSize + 20 + (_welcomeAnimation.value * 10),
                  height: btnSize + 20 + (_welcomeAnimation.value * 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE53935).withOpacity(0.3 + (_welcomeAnimation.value * 0.2)),
                        blurRadius: 20 + (_welcomeAnimation.value * 10),
                        spreadRadius: 5 + (_welcomeAnimation.value * 5),
                      ),
                    ],
                  ),
                );
              },
            ),
            // Progress ring
            SizedBox(
              width: btnSize + 16,
              height: btnSize + 16,
              child: AnimatedBuilder(
                animation: _emergencyHoldController,
                builder: (context, _) => CircularProgressIndicator(
                  value: _isEmergencyHolding ? _emergencyHoldController.value : 0,
                  strokeWidth: 8,
                  backgroundColor: const Color(0xFFE53935).withOpacity(0.15),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFE53935)),
                ),
              ),
            ),
            // Button with enhanced styling
            _isEmergencyHolding
              ? EmergencyButtonRipple(
                  rippleColor: const Color(0xFFE53935),
                  isActive: true,
                  child: Container(
                    width: btnSize,
                    height: btnSize,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFFE53935),
                          const Color(0xFFC62828),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE53935).withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.sos_rounded,
                      color: AppColors.white,
                      size: 50,
                    ),
                  ),
                )
              : Container(
                  width: btnSize,
                  height: btnSize,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFE53935),
                        const Color(0xFFC62828),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.4),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE53935).withOpacity(0.4),
                        blurRadius: 25,
                        spreadRadius: 8,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.sos_rounded,
                    color: AppColors.white,
                    size: 50,
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(SoftUIDesign.buttonBorderRadius),
                border: Border.all(
                  color: AppColors.primaryRed.withOpacity(0.2),
                  width: 1.0,
                ),
              ),
              child: const Text(
                'Emergency Controls',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryRed,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            
            // Edit SOS Message Button
            IconButton(
              onPressed: () => _showEditEmergencyMessageDialog(context),
              icon: const Icon(Icons.edit_note_rounded),
              color: AppColors.primaryRed,
              tooltip: 'Edit Emergency Message',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primaryRed.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
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
    );
  }

  Widget _buildSampleEmergencyAlert() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primaryRed.withOpacity(0.08),
            borderRadius: BorderRadius.circular(SoftUIDesign.buttonBorderRadius),
            border: Border.all(
              color: AppColors.primaryRed.withOpacity(0.2),
              width: 1.0,
            ),
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
    // Fast transition for quick action
    context.pushFast(const LocalChatScreen());
  }




  void _navigateToSettings(BuildContext context) {
    HapticFeedback.lightImpact();
    // Standard transition
    context.pushStandard(const ModernProfileScreen());
  }

  void _navigateToDisasterDemo(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pushNamed('/disaster-demo');
  }

  // Radar Modal for finding devices
  void _showRadarModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87, // Darker for radar effect
      builder: (context) => RadarScanModal(
        onPairedDevicesTap: _showDeviceDialog,
      ),
    );
  }

  // Device Selection Dialog (Paired Devices List)
  void _showDeviceDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => _DeviceSelectionDialog(),
    );
  }


  /// Show edit emergency message dialog
  /// Seamlessly integrated with profile settings - uses same AuthProvider methods
  void _showEditEmergencyMessageDialog(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    final messages = authProvider.emergencyMessages;
    final defaultIndex = authProvider.defaultEmergencyMessageIndex ?? 0;
    
    String currentMessage = '';
    if (messages.isNotEmpty && defaultIndex < messages.length) {
      currentMessage = messages[defaultIndex];
    } else {
      currentMessage = 'Emergency! Please help and contact me immediately.';
    }
    
    final controller = TextEditingController(text: currentMessage);
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SoftUIDesign.cardBorderRadius),
        ),
        title: const SolidModalHeader(
          icon: Icons.edit_note_rounded,
          iconColor: AppColors.primaryRed,
          title: 'Edit Emergency Message',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customize the message that will be sent during an emergency.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Enter your emergency message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryRed, width: 2),
                ),
                filled: true,
                fillColor: AppColors.backgroundLight.withOpacity(0.5),
              ),
            ),
            if (messages.length > 1) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  // Close this dialog and open full emergency messages manager
                  Navigator.of(dialogContext).pop();
                  _showFullEmergencyMessagesManager(context);
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryRed,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Manage all messages'),
                    SizedBox(width: 8),
                    Icon(Icons.list_alt, size: 16),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.pop(dialogContext);
            },
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.mediumGray,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newMessage = controller.text.trim();
              if (newMessage.isEmpty) {
                ModernToastManager.showError(
                  context,
                  'Message cannot be empty',
                );
                return;
              }
              
              HapticFeedback.mediumImpact();
              
              // Use same AuthProvider methods as profile screen for seamless sync
              if (messages.isEmpty) {
                await authProvider.addEmergencyMessage(newMessage, makeDefault: true);
              } else {
                await authProvider.updateEmergencyMessage(defaultIndex, newMessage);
              }
              
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                ModernToastManager.showSuccess(
                  context,
                  'Emergency message updated',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Show full emergency messages manager (same as profile screen)
  /// This ensures seamless integration between ring and profile
  void _showFullEmergencyMessagesManager(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final TextEditingController controller = TextEditingController(
      text: auth.emergencyMessage ?? 'I need help. Please contact me immediately.'
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: AnimatedNeumorphicCard(
            margin: const EdgeInsets.all(16),
            child: StatefulBuilder(
              builder: (context, setStateSheet) {
                final messages = context.read<AuthProvider>().emergencyMessages;
                final defaultIndex = context.read<AuthProvider>().defaultEmergencyMessageIndex;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text(
                        'Emergency Messages',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    // Current list
                    if (messages.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: messages.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final isDefault = defaultIndex == index;
                            return Container(
                              decoration: SoftUIDesign.cardDecoration(
                                backgroundColor: isDefault ? AppColors.primaryRed.withOpacity(0.06) : AppColors.white,
                                borderRadius: SoftUIDesign.buttonBorderRadius,
                                elevation: isDefault ? 3.0 : 2.0,
                                borderColor: isDefault ? AppColors.primaryRed.withOpacity(0.4) : AppColors.lightGray.withOpacity(0.3),
                                showBorder: true,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      messages[index],
                                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.3),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    tooltip: 'Set default',
                                    icon: Icon(isDefault ? Icons.star : Icons.star_border, color: isDefault ? AppColors.primaryRed : AppColors.mediumGray),
                                    onPressed: () async {
                                      await context.read<AuthProvider>().setDefaultEmergencyMessage(index);
                                      setStateSheet(() {});
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Edit',
                                    icon: const Icon(Icons.edit_outlined, color: AppColors.mediumGray),
                                    onPressed: () async {
                                      final editController = TextEditingController(text: messages[index]);
                                      await showDialog(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          backgroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(SoftUIDesign.cardBorderRadius),
                                          ),
                                          title: const Text('Edit Message'),
                                          content: TextField(
                                            controller: editController,
                                            maxLines: 4,
                                            decoration: SoftUIDesign.inputDecoration(
                                              hintText: 'Enter message',
                                            ),
                                          ),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                            ElevatedButton(
                                              onPressed: () async {
                                                final newText = editController.text.trim();
                                                if (newText.isEmpty) return;
                                                await context.read<AuthProvider>().updateEmergencyMessage(index, newText);
                                                if (!context.mounted) return;
                                                Navigator.pop(context);
                                                setStateSheet(() {});
                                              },
                                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed, foregroundColor: AppColors.white),
                                              child: const Text('Save'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    icon: const Icon(Icons.delete_outline, color: AppColors.error),
                                    onPressed: () async {
                                      await context.read<AuthProvider>().deleteEmergencyMessage(index);
                                      setStateSheet(() {});
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Text('No saved messages yet. Add one below.', style: TextStyle(color: AppColors.textSecondary)),
                      ),

                    const SizedBox(height: 12),
                    // Add new
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: controller,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Type a new emergency message to save...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          filled: true,
                          fillColor: AppColors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final text = controller.text.trim();
                            if (text.isEmpty) return;
                            await context.read<AuthProvider>().addEmergencyMessage(text, makeDefault: messages.isEmpty);
                            controller.clear();
                            setStateSheet(() {});
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message saved'), backgroundColor: AppColors.success));
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed, foregroundColor: AppColors.white),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Add'),
                              SizedBox(width: 8),
                              Icon(Icons.add, size: 18),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Send emergency message when SOS ring completes
  /// Shows confirmation modal first, then sends to local chat if ESP32 is connected
  Future<void> _sendEmergencyMessageOnRingComplete(BuildContext context) async {
    // Show confirmation modal before sending
    final confirmed = await _showEmergencyConfirmationModal(context);
    
    if (!confirmed) {
      // User cancelled, just return
      return;
    }
    
    // Proceed with sending the message
    await _sendEmergencyMessageConfirmed(context);
  }

  bool _isEmergencyEsp32Ready({
    required ChatProvider chatProvider,
    required SimpleBluetoothService bluetoothService,
  }) {
    // Two different connection stacks exist in the app today:
    // - SimpleBluetoothService: platform-channel based (mesh / auth flow)
    // - ChatProvider/BluetoothService: flutter_bluetooth_serial_plus based (local chat)
    // Treat either as "ready" for sending emergency alerts.
    final meshReady = bluetoothService.isConnected && bluetoothService.isAuthenticated;
    final localChatReady = chatProvider.isConnected;
    return meshReady || localChatReady;
  }

  /// Show confirmation modal for emergency message
  /// Offline-first: Only works with ESP32 connection
  Future<bool> _showEmergencyConfirmationModal(BuildContext context) async {
      final authProvider = context.read<AuthProvider>();
      final chatProvider = context.read<ChatProvider>();
      final bluetoothService = context.read<SimpleBluetoothService>();
    
    // Get the user's emergency message (use default if not set)
    String emergencyMessage = authProvider.emergencyMessage ?? 
        '🚨 EMERGENCY: I need immediate assistance!';
    
    // Ensure message is not empty
    if (emergencyMessage.trim().isEmpty) {
      emergencyMessage = '🚨 EMERGENCY: I need immediate assistance!';
    }
    
    final isESP32Ready = _isEmergencyEsp32Ready(
      chatProvider: chatProvider,
      bluetoothService: bluetoothService,
    );
    
    // If ESP32 not connected, show error and return false
    if (!isESP32Ready) {
      if (context.mounted) {
        _showESP32ConnectionRequiredDialog(context);
      }
      return false;
    }
    
    return await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SoftUIDesign.cardBorderRadius),
        ),
        title: const SolidModalHeader(
          icon: Icons.emergency,
          iconColor: AppColors.error,
          title: 'Confirm Emergency Alert',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to send this emergency message?',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.error.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Message:',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          // Close confirmation modal and open edit dialog
                          Navigator.of(dialogContext).pop(false);
                          _showEditEmergencyMessageDialog(context);
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryRed,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Edit'),
                            SizedBox(width: 8),
                            Icon(Icons.edit_note_rounded, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    emergencyMessage,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.info.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.bluetooth_connected,
                    color: AppColors.info,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Will send via local chat network (ESP32)',
                      style: TextStyle(
                        color: AppColors.info,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(dialogContext).pop(false);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.of(dialogContext).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Send Emergency',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ) ?? false; // Return false if dialog is dismissed
  }

  /// Send emergency message after confirmation
  /// Offline-first: Only sends via ESP32 when connected
  Future<void> _sendEmergencyMessageConfirmed(BuildContext context) async {
    try {
      final authProvider = context.read<AuthProvider>();
      final chatProvider = context.read<ChatProvider>();
      final bluetoothService = context.read<SimpleBluetoothService>();
      
      // Get the user's emergency message (use default if not set)
      String emergencyMessage = authProvider.emergencyMessage ?? 
          '🚨 EMERGENCY: I need immediate assistance!';
      
      // Ensure message is not empty
      if (emergencyMessage.trim().isEmpty) {
        emergencyMessage = '🚨 EMERGENCY: I need immediate assistance!';
      }
      final addr = AddressEncoder.fromUser(authProvider.currentUserModel);
      final sosMeta = <String, dynamic>{
        'source': 'sos',
        if (addr.fullAddress.isNotEmpty) 'sender_address': addr.fullAddress,
      };
      
      final meshReady = bluetoothService.isConnected && bluetoothService.isAuthenticated;
      final localChatReady = chatProvider.isConnected;
      
      if (meshReady) {
        // Send via platform-channel mesh service
        try {
          await bluetoothService.sendGroupMessage(
            emergencyMessage,
            isEmergency: true,
            additionalData: sosMeta,
          );
      
      if (context.mounted) {
        // Mirror into Local Chat UI so it always shows (and pins) even though the send is handled by SimpleBluetoothService
        chatProvider.addMirroredMessage(
          text: emergencyMessage,
          isEmergency: true,
          rawData: {
            'type': 'group',
            'message': emergencyMessage,
            'is_emergency': true,
            'sender_name': chatProvider.currentUserName ?? authProvider.userName ?? 'Me',
            'timestamp': DateTime.now().toIso8601String(),
            ...sosMeta,
          },
        );

        ModernToastManager.showSuccess(
          context,
              'Emergency message sent to local chat network',
        );
            // Show success animation
            _showEmergencySuccessAnimation(context);
      }
    } catch (e) {
          // ESP32 send failed
          debugPrint('Failed to send via ESP32: $e');
      if (context.mounted) {
        ModernToastManager.showError(
          context,
              'Failed to send emergency message. Please check ESP32 connection.',
            );
          }
        }
      } else if (localChatReady) {
        // Send via existing Local Chat Bluetooth link (flutter_bluetooth_serial_plus stack)
        final success = await chatProvider.sendMessage(
          emergencyMessage,
          isEmergency: true,
          additionalData: sosMeta,
        );
        if (success && context.mounted) {
          ModernToastManager.showSuccess(
            context,
            'Emergency message sent via Local Chat connection',
          );
          _showEmergencySuccessAnimation(context);
        } else if (context.mounted) {
          ModernToastManager.showError(
            context,
            'Failed to send emergency message. Please check ESP32 connection.',
          );
        }
      } else {
        // Not connected on either stack - show error message
        if (context.mounted) {
          ModernToastManager.showError(
            context,
            'ESP32 not connected. Please connect to ESP32 to send emergency messages.',
          );
          
          // Show dialog with connection instructions
          _showESP32ConnectionRequiredDialog(context);
        }
      }
      
    } catch (e) {
      debugPrint('Error sending emergency message: $e');
      if (context.mounted) {
        ModernToastManager.showError(
          context,
          'Failed to send emergency message: ${e.toString()}',
        );
      }
    }
  }

  /// Show dialog when ESP32 connection is required
  void _showESP32ConnectionRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Consumer2<ChatProvider, SimpleBluetoothService>(
        builder: (context, chatProvider, bluetoothService, _) {
          final meshReady = bluetoothService.isConnected && bluetoothService.isAuthenticated;
          final localChatReady = chatProvider.isConnected;
          final isReady = meshReady || localChatReady;

          Widget buildStatusRow({
            required IconData icon,
            required String label,
            required bool ok,
          }) {
            final color = ok ? AppColors.success : AppColors.warning;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    ok ? 'Connected' : 'Disconnected',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            );
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SoftUIDesign.cardBorderRadius),
            ),
            title: SolidModalHeader(
              icon: isReady ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              iconColor: isReady ? AppColors.success : AppColors.warning,
              title: isReady ? 'ESP32 Connected' : 'ESP32 Connection Required',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isReady
                      ? 'You’re connected. You can send emergency messages now.'
                      : 'Emergency messages can only be sent when connected to ESP32.',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                buildStatusRow(
                  icon: Icons.hub_rounded,
                  label: 'Mesh connection',
                  ok: meshReady,
                ),
                const SizedBox(height: 10),
                buildStatusRow(
                  icon: Icons.chat_bubble_rounded,
                  label: 'Local Chat connection',
                  ok: localChatReady,
                ),
                if (!isReady) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.warning.withOpacity(0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.warning,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Connect via Local Chat (Bluetooth) or via the ESP32 scanner/auth screen.',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              if (isReady)
                ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(dialogContext).pop();
                    _sendEmergencyMessageConfirmed(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Send Now',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(dialogContext).pop();
                  _navigateToChat(context);
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryRed,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                child: const Text(
                  'Open Local Chat',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(dialogContext).pop();
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEmergencySuccessAnimation(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Emergency sent',
      barrierColor: Colors.black.withOpacity(0.35),
      pageBuilder: (context, _, __) {
        // Auto-dismiss quickly; this is just confirmation feedback.
        Future.delayed(const Duration(milliseconds: 1150), () {
          if (context.mounted) Navigator.of(context).pop();
        });

        return SafeArea(
          child: Align(
            alignment: Alignment.center,
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 28),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.error.withOpacity(0.18)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.14),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    micro.SuccessAnimation(
                      size: 56, // smaller, premium
                      color: AppColors.error, // emergency-themed (not green)
                    ),
                    const SizedBox(width: 14),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Emergency sent',
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Broadcasting to nearby devices…',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim, __, child) {
        final curved = Curves.easeOutCubic.transform(anim.value);
        return Opacity(
          opacity: curved,
          child: Transform.translate(
            offset: Offset(0, (1 - curved) * 12),
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 220),
    );
  }

  void _showEmergencyDialog(BuildContext context, [String? emergencyType]) {
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
    
    // Prepend emergency type if provided
    if (emergencyType != null && emergencyType.isNotEmpty) {
      emergencyMessage = '$emergencyType: $emergencyMessage';
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
                borderRadius: BorderRadius.circular(SoftUIDesign.cardBorderRadius),
              ),
              title: const SolidModalHeader(
                icon: Icons.emergency,
                iconColor: AppColors.error,
                title: 'Emergency Alert',
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
                      
                      // Check ESP32 connection first (offline-first approach)
                      final chatProvider = context.read<ChatProvider>();
                      final bluetoothService = context.read<SimpleBluetoothService>();
                      final addr = AddressEncoder.fromUser(authProvider.currentUserModel);
      final sosMeta = <String, dynamic>{
        'source': 'sos',
        if (addr.fullAddress.isNotEmpty) 'sender_address': addr.fullAddress,
      };
                      final meshReady = bluetoothService.isConnected && bluetoothService.isAuthenticated;
                      final localChatReady = chatProvider.isConnected;
                      
                      if (meshReady) {
                        // Send via ESP32 mesh service
                        try {
                          await bluetoothService.sendGroupMessage(
                            emergencyMessage,
                            isEmergency: true,
                            additionalData: sosMeta,
                          );
                      
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                        _showEmergencySuccessAnimation(context);
                      }
                        } catch (e) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              isSending = false;
                            });
                            ModernToastManager.showError(
                              context,
                              'Failed to send. Please check ESP32 connection.',
                            );
                          }
                        }
                      } else if (localChatReady) {
                        // Send via Local Chat connection
                        try {
                          final success = await chatProvider.sendMessage(
                            emergencyMessage,
                            isEmergency: true,
                            additionalData: sosMeta,
                          );
                          if (success && dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                            _showEmergencySuccessAnimation(context);
                          } else if (dialogContext.mounted) {
                            setDialogState(() {
                              isSending = false;
                            });
                            ModernToastManager.showError(
                              context,
                              'Failed to send. Please check ESP32 connection.',
                            );
                          }
                        } catch (_) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              isSending = false;
                            });
                            ModernToastManager.showError(
                              context,
                              'Failed to send. Please check ESP32 connection.',
                            );
                          }
                        }
                      } else {
                        // ESP32 not connected
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            isSending = false;
                          });
                          Navigator.of(dialogContext).pop();
                          _showESP32ConnectionRequiredDialog(context);
                        }
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

/// Device Selection Dialog with Polished UI (for Home Screen)
class _DeviceSelectionDialog extends StatefulWidget {
  @override
  State<_DeviceSelectionDialog> createState() => _DeviceSelectionDialogState();
}

class _DeviceSelectionDialogState extends State<_DeviceSelectionDialog> {
  bool _showAllDevices = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadPairedDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color cyanBlue = Color(0xFF3498DB);
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.maxFinite,
        height: 600,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Consumer<ChatProvider>(
          builder: (context, provider, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Modern Header with Gradient
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cyanBlue,
                        cyanBlue.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.bluetooth,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bluetooth Devices',
                              style: AppTypography.headlineSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Select an ESP32 device to connect',
                              style: AppTypography.bodySmall.copyWith(
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                
                // Connection Status Card
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: provider.isConnected 
                          ? cyanBlue.withOpacity(0.1) 
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: provider.isConnected 
                            ? cyanBlue.withOpacity(0.3) 
                            : Colors.grey.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: provider.isConnected 
                                ? cyanBlue.withOpacity(0.2) 
                                : Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            provider.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                            color: provider.isConnected ? cyanBlue : Colors.grey,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                provider.isConnected 
                                    ? 'Connected' 
                                    : 'Not Connected',
                                style: AppTypography.bodyLarge.copyWith(
                                  color: provider.isConnected ? cyanBlue : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                provider.isConnected 
                                    ? 'Device: ${provider.selectedDevice?.name ?? "ESP32"}' 
                                    : 'No device connected',
                                style: AppTypography.bodySmall.copyWith(
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
                
                // Refresh button and title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Paired Devices',
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkGray,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: provider.isConnecting ? null : () {
                          provider.loadPairedDevices();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cyanBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(provider.isConnecting ? 'Connecting...' : 'Refresh'),
                            const SizedBox(width: 8),
                            if (provider.isConnecting)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            else
                              const Icon(Icons.refresh, size: 18),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Device list
                Expanded(
                  child: provider.pairedDevices.isEmpty
                      ? Center(
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.bluetooth_searching,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'No paired devices found',
                                    style: AppTypography.headlineSmall.copyWith(
                                      color: AppColors.darkGray,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Please pair with ESP32 device first',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.mediumGray,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(8),
                                  itemCount: _showAllDevices 
                                      ? provider.pairedDevices.length 
                                      : (provider.pairedDevices.length > 5 ? 5 : provider.pairedDevices.length),
                                  itemBuilder: (context, index) {
                                    final device = provider.pairedDevices[index];
                                    final isSelected = provider.selectedDevice?.address == device.address;
                                    final isConnected = provider.isConnected && isSelected;
                                    
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isConnected 
                                              ? cyanBlue.withOpacity(0.5) 
                                              : (isSelected 
                                                  ? cyanBlue.withOpacity(0.3) 
                                                  : Colors.grey.withOpacity(0.2)),
                                          width: isConnected || isSelected ? 1.5 : 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        leading: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: isConnected
                                                ? [cyanBlue, cyanBlue.withOpacity(0.7)]
                                                : [Colors.grey.withOpacity(0.3), Colors.grey.withOpacity(0.1)],
                                            ),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                                            color: isConnected ? Colors.white : AppColors.mediumGray,
                                            size: 24,
                                          ),
                                        ),
                                        title: Text(
                                          device.name ?? 'Unknown Device',
                                          style: AppTypography.bodyMedium.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.darkGray,
                                          ),
                                        ),
                                        subtitle: Text(
                                          device.address,
                                          style: AppTypography.bodySmall.copyWith(
                                            color: AppColors.mediumGray,
                                          ),
                                        ),
                                        trailing: isConnected
                                            ? ElevatedButton(
                                                onPressed: () {
                                                  provider.disconnect();
                                                  Navigator.pop(context);
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                                child: const Text('Disconnect'),
                                              )
                                            : ElevatedButton(
                                                onPressed: provider.isConnecting ? null : () async {
                                                  bool success = await provider.connectToDevice(device);
                                                  if (success && mounted) {
                                                    Navigator.pop(context);
                                                  }
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: cyanBlue,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                                child: Text(provider.isConnecting ? 'Connecting...' : 'Connect'),
                                              ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            
                            // Show more button
                            if (!_showAllDevices && provider.pairedDevices.length > 5) ...[
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _showAllDevices = true;
                                    });
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Show more (${provider.pairedDevices.length - 5} more devices)',
                                        style: AppTypography.bodyMedium.copyWith(
                                          color: cyanBlue,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.expand_more, color: cyanBlue),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            
                            // Show less button
                            if (_showAllDevices && provider.pairedDevices.length > 5) ...[
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _showAllDevices = false;
                                    });
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Show less',
                                        style: AppTypography.bodyMedium.copyWith(
                                          color: cyanBlue,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.expand_less, color: cyanBlue),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
                
                // Close button
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: AppTypography.bodyMedium.copyWith(
                          color: cyanBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
