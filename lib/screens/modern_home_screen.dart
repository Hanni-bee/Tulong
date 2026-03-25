import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
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
import '../widgets/animated_neumorphic_card.dart';
import '../utils/icon_system.dart';
import '../utils/enhanced_page_transitions.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';

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
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        final isConnected = chatProvider.isConnected;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced header card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: SoftUIDesign.cardDecoration(
                backgroundColor: AppColors.white,
                borderRadius: SoftUIDesign.cardBorderRadius,
                elevation: 4.0,
                borderColor: AppColors.lightGray.withOpacity(0.2),
                showBorder: true,
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    // App Logo - Enhanced with better shadows
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryRed.withOpacity(0.3),
                            blurRadius: 12,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          'assets/images/app_logo (3).png',
                          width: 64,
                          height: 64,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // App Info - Enhanced layout
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'T.U.L.O.N.G',
                                  style: AppTypography.headlineSmall.copyWith(
                                    color: AppColors.primaryRed,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Enhanced CONNECTED badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isConnected
                                        ? [
                                            AppColors.success.withOpacity(0.15),
                                            AppColors.success.withOpacity(0.1),
                                          ]
                                        : [
                                            AppColors.error.withOpacity(0.15),
                                            AppColors.error.withOpacity(0.1),
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isConnected
                                        ? AppColors.success.withOpacity(0.3)
                                        : AppColors.error.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        color: isConnected ? AppColors.success : AppColors.error,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: (isConnected ? AppColors.success : AppColors.error).withOpacity(0.5),
                                            blurRadius: 4,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isConnected ? 'CONNECTED' : 'OFFLINE',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: isConnected ? AppColors.success : AppColors.error,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
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
      },
    );
  }


  Widget _buildQuickActions() {
    return PhoneResponsiveBuilder(
      builder: (context, screenSize) {
        final cardRadius = PhoneResponsiveHelper.getPhoneBorderRadius(context).clamp(12, 20).toDouble();
        final spacing = PhoneResponsiveHelper.getPhoneSpacing(context);
        return Container(
          padding: PhoneResponsiveHelper.getPhonePadding(context),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(
              color: AppColors.lightGray.withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              // Solid soft-depth (no inner highlight/glow)
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 18,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryRed.withOpacity(0.12),
                          AppColors.primaryRed.withOpacity(0.06),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primaryRed.withOpacity(0.25),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryRed.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.flash_on_rounded,
                            color: AppColors.primaryRed,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Quick Actions',
                          style: AppTypography.cardTitle.copyWith(
                            color: AppColors.primaryRed,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.ultraLightGray.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.borderColor.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          color: AppColors.textSecondary.withOpacity(0.8),
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Tap to use',
                          style: AppTypography.captionText.copyWith(
                            color: AppColors.textSecondary.withOpacity(0.9),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing),
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
                            left: index == 0 ? 0 : 8,
                            right: index == quickActions.length - 1 ? 0 : 8,
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
        // Further increased height to ensure all text is visible and layout is spacious
        final height = PhoneResponsiveHelper.getPhoneCardHeight(context).clamp(120, 140).toDouble();
        final radius = SoftUIDesign.cardBorderRadius;
        
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: backgroundColor.withOpacity(0.12),
              width: 1.5,
            ),
            boxShadow: SoftUIDesign.getCardShadow(elevation: 3),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.mediumImpact();
                onPressed();
              },
              borderRadius: BorderRadius.circular(radius),
              child: Stack(
                children: [
                  // Subtle colored accent in the corner
                  SoftUIDesign.buildCornerAccentOverlay(
                    accentColor: backgroundColor,
                    alignment: Alignment.topRight,
                    size: 60,
                    opacity: 0.12,
                  ),
                  
                  // Content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                backgroundColor.withOpacity(0.15),
                                backgroundColor.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: backgroundColor.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            icon,
                            color: backgroundColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 10),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            title,
                            style: AppTypography.cardTitle.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppTypography.captionText.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
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
    final bool isActive = label != 'Offline' && label != '0';
    
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
            color: color.withOpacity(isActive ? 0.5 : 0.3),
            width: isActive ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(isActive ? 0.15 : 0.05),
              blurRadius: isActive ? 15 : 8,
              offset: const Offset(0, 4),
              spreadRadius: isActive ? 1 : 0,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
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
            // Static Radar Background (no pulse)
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: btnSize + 40,
                  height: btnSize + 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE53935).withOpacity(0.15),
                      width: 2,
                    ),
                  ),
                ),
                Container(
                  width: btnSize + 80,
                  height: btnSize + 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE53935).withOpacity(0.08),
                      width: 1,
                    ),
                  ),
                ),
              ],
            ),
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
              TextButton.icon(
                onPressed: () {
                  // Close this dialog and open full emergency messages manager
                  Navigator.of(dialogContext).pop();
                  _showFullEmergencyMessagesManager(context);
                },
                icon: const Icon(Icons.list_alt, size: 16),
                label: const Text('Manage all messages'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryRed,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                        ElevatedButton.icon(
                          onPressed: () async {
                            final text = controller.text.trim();
                            if (text.isEmpty) return;
                            await context.read<AuthProvider>().addEmergencyMessage(text, makeDefault: messages.isEmpty);
                            controller.clear();
                            setStateSheet(() {});
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message saved'), backgroundColor: AppColors.success));
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed, foregroundColor: AppColors.white),
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

  /// Show confirmation modal for emergency message
  /// Offline-first: Only works with ESP32 connection
  Future<bool> _showEmergencyConfirmationModal(BuildContext context) async {
      final authProvider = context.read<AuthProvider>();
    
    // Get the user's emergency message (use default if not set)
    String emergencyMessage = authProvider.emergencyMessage ?? 
        '🚨 EMERGENCY: I need immediate assistance!';
    
    // Ensure message is not empty
    if (emergencyMessage.trim().isEmpty) {
      emergencyMessage = '🚨 EMERGENCY: I need immediate assistance!';
    }
    
    // Same source as Home "CONNECTED" badge: ChatProvider SPP link to ESP32
    final isEsp32Connected = context.read<ChatProvider>().isConnected;

    if (!isEsp32Connected) {
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
                      TextButton.icon(
                        onPressed: () {
                          // Close confirmation modal and open edit dialog
                          Navigator.of(dialogContext).pop(false);
                          _showEditEmergencyMessageDialog(context);
                        },
                        icon: const Icon(Icons.edit_note_rounded, size: 16),
                        label: const Text('Edit'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryRed,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

  /// Send emergency message after confirmation (`send_sos` over SPP — same stack as Local Chat).
  Future<void> _sendEmergencyMessageConfirmed(BuildContext context) async {
    try {
      final authProvider = context.read<AuthProvider>();

      String emergencyMessage = authProvider.emergencyMessage ??
          '🚨 EMERGENCY: I need immediate assistance!';

      if (emergencyMessage.trim().isEmpty) {
        emergencyMessage = '🚨 EMERGENCY: I need immediate assistance!';
      }

      await _sendSosViaEsp32Protocol(context, emergencyMessage);
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

  /// Uses [ChatProvider] SPP connection (matches Home header) and firmware `send_sos` JSON.
  Future<void> _sendSosViaEsp32Protocol(BuildContext context, String emergencyMessage) async {
    final chat = context.read<ChatProvider>();
    if (!chat.isConnected) {
      if (context.mounted) {
        _showESP32ConnectionRequiredDialog(context);
      }
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final severity = prefs.getString('sos_severity') ?? 'UNKNOWN';
    try {
      await chat.sendSosNow(
        message: emergencyMessage.trim(),
        severity: severity,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      );
      if (context.mounted) {
        ModernToastManager.showSuccess(
          context,
          'Emergency message sent to local chat network',
        );
        _showEmergencySuccessAnimation(context);
      }
    } catch (e) {
      debugPrint('Failed to send SOS via ESP32: $e');
      if (context.mounted) {
        ModernToastManager.showError(
          context,
          'Failed to send emergency message. Please check ESP32 connection.',
        );
      }
    }
  }

  /// Show dialog when ESP32 connection is required
  void _showESP32ConnectionRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SoftUIDesign.cardBorderRadius),
        ),
        title: const SolidModalHeader(
          icon: Icons.settings_input_antenna,
          iconColor: AppColors.warning,
          title: 'ESP32 Connection Required',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Emergency messages can only be sent when connected to ESP32.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
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
                      'Please connect to ESP32 to send emergency messages through the local mesh network.',
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
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(dialogContext).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'OK',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEmergencySuccessAnimation(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success checkmark with urgent styling
            micro.SuccessAnimation(
              size: 120,
              color: AppColors.error, // Red for emergency, not green
              onComplete: () {
                Future.delayed(const Duration(milliseconds: 800), () {
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                });
              },
            ),
            const SizedBox(height: 24),
            // Emergency confirmation message
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Emergency Alert Sent',
                    style: AppTypography.headlineSmall.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Help is on the way',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessAnimation(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: micro.SuccessAnimation(
          onComplete: () {
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
    );
    
    // Also show toast message
    Future.delayed(const Duration(milliseconds: 600), () {
      if (context.mounted) {
        ModernToastManager.showSuccess(context, message);
      }
    });
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

                      final chat = context.read<ChatProvider>();
                      if (!chat.isConnected) {
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            isSending = false;
                          });
                          Navigator.of(dialogContext).pop();
                          _showESP32ConnectionRequiredDialog(context);
                        }
                        return;
                      }

                      try {
                        final prefs = await SharedPreferences.getInstance();
                        final severity = prefs.getString('sos_severity') ?? 'UNKNOWN';
                        await chat.sendSosNow(
                          message: emergencyMessage.trim(),
                          severity: severity,
                          timestampMs: DateTime.now().millisecondsSinceEpoch,
                        );
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                          _showSuccessAnimation(
                            context,
                            'Emergency message sent to local chat network!',
                          );
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadPairedDevices();
    });
    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.toLowerCase().trim();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatMacAddress(String address) {
    // Format MAC address with colons every 2 characters
    final cleaned = address.replaceAll(':', '').replaceAll('-', '');
    if (cleaned.length < 12) return address;
    
    final buffer = StringBuffer();
    for (int i = 0; i < cleaned.length; i += 2) {
      if (i > 0) buffer.write(':');
      if (i + 2 <= cleaned.length) {
        buffer.write(cleaned.substring(i, i + 2));
      } else {
        buffer.write(cleaned.substring(i));
      }
    }
    return buffer.toString().toUpperCase();
  }

  Widget _buildDeviceCard(
    BuildContext context,
    BluetoothDevice device,
    ChatProvider provider,
    Color primaryColor,
    bool isESP32,
  ) {
    final isSelected = provider.selectedDevice?.address == device.address && provider.isConnected;
    final deviceName = device.name ?? 'Unknown Device';
    final formattedAddress = _formatMacAddress(device.address);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.accent.withOpacity(0.08),
                  AppColors.accent.withOpacity(0.03),
                ],
              )
            : null,
        color: isSelected ? null : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isSelected 
              ? AppColors.accent.withOpacity(0.4) 
              : AppColors.lightGray.withOpacity(0.3),
          width: isSelected ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AppColors.accent.withOpacity(0.15)
                : Colors.black.withOpacity(0.04),
            blurRadius: isSelected ? 12 : 8,
            offset: const Offset(0, 4),
            spreadRadius: isSelected ? 1 : 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () async {
            HapticFeedback.selectionClick();
            if (isSelected) {
              await provider.disconnect();
            } else {
              Navigator.pop(context);
              final success = await provider.connectToDevice(device);
              if (context.mounted) {
                if (success) {
                  ModernToastManager.showSuccess(context, 'Connected to $deviceName');
                } else {
                  ModernToastManager.showError(context, 'Failed to connect to $deviceName');
                }
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                // Device Icon with Type Indicator
                Stack(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.accent,
                                  AppColors.accent.withOpacity(0.8),
                                ],
                              )
                            : null,
                        color: isSelected ? null : AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.accent.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Icon(
                        isSelected 
                            ? Icons.bluetooth_connected_rounded 
                            : (isESP32 ? Icons.memory_rounded : Icons.bluetooth_rounded),
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        size: 28,
                      ),
                    ),
                    if (isESP32 && !isSelected)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: AppColors.info,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.verified_rounded,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                // Device Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              deviceName,
                              style: AppTypography.bodyLarge.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                fontSize: 17,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isESP32)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.info.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.info.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                'ESP32',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.info,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.fingerprint_rounded,
                            size: 12,
                            color: AppColors.textSecondary.withOpacity(0.7),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              formattedAddress,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontFamily: 'monospace',
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Status Badge or Connect Button
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accent,
                          AppColors.accent.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text(
                          'Active',
                          style: AppTypography.bodySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: primaryColor.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = AppColors.info;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          minHeight: 450,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Consumer<ChatProvider>(
          builder: (context, provider, child) {
            final allDevices = provider.pairedDevices;
            final filteredDevices = _searchQuery.isEmpty
                ? allDevices
                : allDevices.where((device) {
                    final name = (device.name ?? '').toLowerCase().trim();
                    final address = device.address.toLowerCase().replaceAll(':', '').replaceAll('-', '');
                    final searchTerm = _searchQuery.replaceAll(':', '').replaceAll('-', '');
                    return name.contains(_searchQuery) || 
                           address.contains(searchTerm) ||
                           name.startsWith(_searchQuery) ||
                           address.startsWith(searchTerm);
                  }).toList();
            
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Minimal Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primaryColor,
                        primaryColor.withOpacity(0.85),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                        ),
                        child: const Icon(
                          Icons.bluetooth_searching_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Bluetooth Devices',
                          style: AppTypography.headlineSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                          highlightColor: Colors.white.withOpacity(0.1),
                          padding: const EdgeInsets.all(6),
                          minimumSize: const Size(36, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Search Bar - Integrated below header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.lightGray.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextFormField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase().trim();
                        });
                      },
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search by name or address...',
                        hintStyle: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: primaryColor,
                          size: 22,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                  onTap: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    child: Icon(
                                      Icons.clear_rounded,
                                      color: AppColors.textSecondary,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              )
                            : null,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),
                
                // Status & Content
                Expanded(
                  child: Column(
                    children: [
                      // Status Card
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: provider.isConnected 
                                ? AppColors.accent.withOpacity(0.08) 
                                : AppColors.backgroundLight,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: provider.isConnected 
                                  ? AppColors.accent.withOpacity(0.3) 
                                  : AppColors.lightGray.withOpacity(0.5),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: provider.isConnected 
                                      ? AppColors.accent.withOpacity(0.15) 
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    if (!provider.isConnected)
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                  ],
                                ),
                                child: Icon(
                                  provider.isConnected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_disabled_rounded,
                                  color: provider.isConnected ? AppColors.accent : AppColors.textSecondary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      provider.isConnected ? 'Connected Securely' : 'Not Connected',
                                      style: AppTypography.bodyLarge.copyWith(
                                        color: provider.isConnected ? AppColors.accentDark : AppColors.textPrimary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 17,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      provider.isConnected 
                                          ? 'Active: ${provider.selectedDevice?.name ?? "ESP32 Device"}' 
                                          : 'Tap a device below to connect',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Paired Devices Header with Count
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: primaryColor.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.devices_rounded,
                                        size: 16,
                                        color: primaryColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${filteredDevices.length} ${filteredDevices.length == 1 ? 'Device' : 'Devices'}',
                                        style: AppTypography.bodySmall.copyWith(
                                          color: primaryColor,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_searchQuery.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.backgroundLight,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Filtered',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: primaryColor.withOpacity(0.25),
                                  width: 1.5,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: provider.isConnecting ? null : () {
                                    HapticFeedback.lightImpact();
                                    provider.loadPairedDevices();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (provider.isConnecting)
                                          const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.info),
                                            ),
                                          )
                                        else
                                          Icon(Icons.refresh_rounded, size: 18, color: primaryColor),
                                        const SizedBox(width: 6),
                                        Text(
                                          provider.isConnecting ? 'Scanning...' : 'Refresh',
                                          style: AppTypography.bodySmall.copyWith(
                                            color: primaryColor,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Device List with Grouping
                      Expanded(
                        child: filteredDevices.isEmpty
                            ? SingleChildScrollView(
                                physics: const ClampingScrollPhysics(),
                                child: Padding(
                                  padding: const EdgeInsets.all(40),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 120,
                                        height: 120,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              AppColors.backgroundLight,
                                              AppColors.backgroundLight.withOpacity(0.7),
                                            ],
                                          ),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.05),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          _searchQuery.isNotEmpty 
                                              ? Icons.search_off_rounded 
                                              : Icons.bluetooth_disabled_rounded,
                                          size: 56,
                                          color: AppColors.textSecondary.withOpacity(0.5),
                                        ),
                                      ),
                                      const SizedBox(height: 32),
                                      Text(
                                        _searchQuery.isNotEmpty
                                            ? 'No devices found'
                                            : 'No paired devices',
                                        style: AppTypography.headlineSmall.copyWith(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 22,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                        decoration: BoxDecoration(
                                          color: AppColors.backgroundLight,
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(
                                            color: AppColors.lightGray.withOpacity(0.3),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Text(
                                          _searchQuery.isNotEmpty
                                              ? 'No devices match "${_searchController.text}". Try searching by device name or MAC address.'
                                              : 'Pair a device in your device\'s Bluetooth settings first, then refresh to see available devices.',
                                          style: AppTypography.bodyMedium.copyWith(
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w500,
                                            height: 1.5,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      if (_searchQuery.isEmpty) ...[
                                        const SizedBox(height: 28),
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                primaryColor,
                                                primaryColor.withOpacity(0.85),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(18),
                                            boxShadow: [
                                              BoxShadow(
                                                color: primaryColor.withOpacity(0.4),
                                                blurRadius: 12,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(18),
                                              onTap: provider.isConnecting ? null : () {
                                                HapticFeedback.mediumImpact();
                                                provider.loadPairedDevices();
                                              },
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    if (provider.isConnecting)
                                                      const SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2.5,
                                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                        ),
                                                      )
                                                    else
                                                      const Icon(
                                                        Icons.refresh_rounded,
                                                        color: Colors.white,
                                                        size: 22,
                                                      ),
                                                    const SizedBox(width: 10),
                                                    Flexible(
                                                      child: Text(
                                                        provider.isConnecting ? 'Scanning...' : 'Refresh Devices',
                                                        style: AppTypography.bodyLarge.copyWith(
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.w800,
                                                          fontSize: 16,
                                                          letterSpacing: 0.2,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                        maxLines: 1,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ] else ...[
                                        const SizedBox(height: 28),
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(16),
                                            onTap: () {
                                              setState(() {
                                                _searchController.clear();
                                                _searchQuery = '';
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                              decoration: BoxDecoration(
                                                color: AppColors.backgroundLight,
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: AppColors.lightGray.withOpacity(0.3),
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.clear_rounded,
                                                    color: AppColors.textSecondary,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Clear search',
                                                    style: AppTypography.bodyMedium.copyWith(
                                                      color: AppColors.textSecondary,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              )
                            : Builder(
                                builder: (context) {
                                  // Separate ESP32 and other devices
                                  final esp32Devices = filteredDevices.where((d) => 
                                    (d.name ?? '').toLowerCase().contains('esp32')
                                  ).toList();
                                  final otherDevices = filteredDevices.where((d) => 
                                    !(d.name ?? '').toLowerCase().contains('esp32')
                                  ).toList();
                                  
                                  final displayCount = _showAllDevices 
                                      ? filteredDevices.length 
                                      : (filteredDevices.length > 4 ? 4 : filteredDevices.length);
                                  
                                  return ListView(
                                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                    children: [
                                      // ESP32 Devices Section
                                      if (esp32Devices.isNotEmpty) ...[
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 12, top: 4),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 4,
                                                height: 20,
                                                decoration: BoxDecoration(
                                                  color: AppColors.info,
                                                  borderRadius: BorderRadius.circular(2),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                'ESP32 DEVICES',
                                                style: AppTypography.bodySmall.copyWith(
                                                  color: AppColors.info,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 1.5,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.info.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '${esp32Devices.length}',
                                                  style: AppTypography.bodySmall.copyWith(
                                                    color: AppColors.info,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        ...esp32Devices.take(_showAllDevices ? esp32Devices.length : 
                                            (esp32Devices.length > 2 ? 2 : esp32Devices.length))
                                            .map((device) => _buildDeviceCard(
                                              context, 
                                              device, 
                                              provider, 
                                              primaryColor,
                                              true, // isESP32
                                            )),
                                        if (esp32Devices.length > 2 && !_showAllDevices)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 8),
                                            child: Center(
                                              child: TextButton(
                                                onPressed: () {
                                                  setState(() => _showAllDevices = true);
                                                },
                                                child: Text(
                                                  '+${esp32Devices.length - 2} more ESP32',
                                                  style: TextStyle(color: AppColors.info, fontSize: 12),
                                                ),
                                              ),
                                            ),
                                          ),
                                        if (otherDevices.isNotEmpty && esp32Devices.isNotEmpty)
                                          const SizedBox(height: 8),
                                      ],
                                      
                                      // Other Devices Section
                                      if (otherDevices.isNotEmpty) ...[
                                        if (esp32Devices.isEmpty) const SizedBox(height: 4),
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 4,
                                                height: 20,
                                                decoration: BoxDecoration(
                                                  color: AppColors.textSecondary.withOpacity(0.4),
                                                  borderRadius: BorderRadius.circular(2),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                'OTHER DEVICES',
                                                style: AppTypography.bodySmall.copyWith(
                                                  color: AppColors.textSecondary,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 1.5,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.backgroundLight,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '${otherDevices.length}',
                                                  style: AppTypography.bodySmall.copyWith(
                                                    color: AppColors.textSecondary,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        ...otherDevices.take(_showAllDevices ? otherDevices.length : 
                                            (displayCount - esp32Devices.length))
                                            .map((device) => _buildDeviceCard(
                                              context, 
                                              device, 
                                              provider, 
                                              primaryColor,
                                              false, // isESP32
                                            )),
                                      ],
                                    ],
                                  );
                                },
                              ),
                      ),
                      
                      if (filteredDevices.length > 4 && !_showAllDevices)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  primaryColor.withOpacity(0.08),
                                  primaryColor.withOpacity(0.04),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: primaryColor.withOpacity(0.2),
                                width: 1.5,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  setState(() {
                                    _showAllDevices = !_showAllDevices;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _showAllDevices 
                                            ? Icons.expand_less_rounded 
                                            : Icons.expand_more_rounded,
                                        color: primaryColor,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _showAllDevices 
                                            ? 'Show less' 
                                            : 'Show all ${filteredDevices.length} devices',
                                        style: AppTypography.bodyMedium.copyWith(
                                          color: primaryColor,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
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
                          color: AppColors.textSecondary,
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
