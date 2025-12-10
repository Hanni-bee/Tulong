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
import '../widgets/micro_interactions.dart';
import '../widgets/polished_animations.dart';
import '../constants/soft_ui_design.dart';
import '../utils/page_transitions.dart';
import '../utils/phone_responsive_helper.dart';
import '../config/page_transition_config.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../services/offline_messaging_service.dart';
import '../widgets/interactive_feedback.dart';
import '../utils/prototype_animations.dart';
import '../widgets/special_animations.dart';
import 'local_chat_screen.dart';
import 'modern_profile_screen.dart';
import 'disaster_demo_screen.dart';
import '../widgets/solid_modal_header.dart';
import '../widgets/radar_scan_modal.dart';

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
      'icon': Icons.settings_rounded,
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
                        child: _buildCompactStatus(),
                      ),
                      const SizedBox(height: 16),
                      
                      // Quick Actions
                      PolishedFadeIn(
                        delay: const Duration(milliseconds: 400),
                        child: _buildQuickActions(),
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
          decoration: SoftUIDesign.cardDecoration(
            backgroundColor: AppColors.white,
            borderRadius: PhoneResponsiveHelper.getPhoneBorderRadius(context),
            elevation: 4.0,
            borderColor: AppColors.lightGray.withOpacity(0.3),
            showBorder: true,
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
                child: Builder(
                  builder: (context) {
                    final quickActions = _getQuickActions();
                    return Center(
                      child: ListView.builder(
                        shrinkWrap: true,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        itemCount: quickActions.length,
                        itemBuilder: (context, index) {
                          final action = quickActions[index];
                          return _quickActionsStagger.buildAnimatedItem(
                            index,
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildUniformActionButton(
                                  onPressed: action['onPressed'] as VoidCallback,
                                  backgroundColor: action['backgroundColor'] as Color,
                                  icon: action['icon'] as IconData,
                                  title: action['title'] as String,
                                  subtitle: action['subtitle'] as String,
                                ),
                                if (index < quickActions.length - 1)
                                  const SizedBox(width: 8), // Reduced spacing between buttons
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
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
          borderRadius: BorderRadius.circular(SoftUIDesign.buttonBorderRadius),
          shadows: SoftUIDesign.getButtonShadow(color: backgroundColor),
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

  Widget _buildCompactStatus() {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        final isConnected = chatProvider.isConnected;
        // Only count other users, not the current user
        final allUsers = chatProvider.connectedUsers;
        final currentUser = chatProvider.currentUserName;
        final nearbyUsers = allUsers.where((user) => user != currentUser).toList();
        final userCount = nearbyUsers.length;
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // 1. Connection Status - Shows Paired Devices List when clicked
              Expanded(
                flex: 1,
                child: _buildStatusCard(
                  icon: isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                  label: isConnected ? 'Connected' : 'Offline',
                  subLabel: isConnected ? 'Mesh Active' : 'No Signal',
                  color: isConnected ? AppColors.success : AppColors.error,
                  onTap: () => _showDeviceDialog(),
                ),
              ),
              const SizedBox(width: 12),
              
              // 2. People Nearby - Shows Radar Modal when clicked
              Expanded(
                flex: 1,
                child: _buildStatusCard(
                  icon: Icons.people_alt_rounded,
                  label: '$userCount',
                  subLabel: 'Nearby',
                  color: AppColors.info,
                  onTap: () => _showRadarModal(),
                ),
              ),
              const SizedBox(width: 12),
              
              // 3. System Health
              Expanded(
                flex: 1,
                child: _buildStatusCard(
                  icon: Icons.battery_charging_full_rounded,
                  label: 'Good',
                  subLabel: 'Health',
                  color: AppColors.warning,
                  onTap: () {},
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
        height: 100, // Increased height
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 8,
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
                  size: 24,
                  color: color,
                ),
                if (label == 'Connected' || label == 'Offline')
                  Positioned(
                    top: -2,
                    right: -6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.4),
                            blurRadius: 4,
                            spreadRadius: 1,
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
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildEmergencyButton() {
    const double btnSize = 120.0; // Increased from 80 to 120
    
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
            _isEmergencyHolding
              ? EmergencyButtonRipple(
                  rippleColor: const Color(0xFFE53935),
                  isActive: true,
                  child: Container(
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
                      Icons.sos_rounded,
                      color: AppColors.white,
                      size: 40,
                    ),
                  ),
                )
              : Container(
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
                Icons.sos_rounded,
                color: AppColors.white,
                size: 40, // Increased from 22 to 40 to match larger button
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
    context.pushPage(const LocalChatScreen());
  }




  void _navigateToSettings(BuildContext context) {
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
      builder: (context) => AlertDialog(
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
              if (newMessage.isEmpty) return;
              
              HapticFeedback.lightImpact();
              Navigator.pop(context);
              
              if (messages.isEmpty) {
                await authProvider.addEmergencyMessage(newMessage, makeDefault: true);
              } else {
                await authProvider.updateEmergencyMessage(defaultIndex, newMessage);
              }
              
              if (mounted) {
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

  void _showSuccessAnimation(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: SuccessAnimation(
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
                      
                      // Use the direct send method with the message from profile
                      await _sendEmergencyAlertDirectly(context, emergencyMessage);
                      
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                        // Show success animation
                        _showSuccessAnimation(context, 'Emergency alert sent!');
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
                      ElevatedButton.icon(
                        onPressed: provider.isConnecting ? null : () {
                          provider.loadPairedDevices();
                        },
                        icon: provider.isConnecting 
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.refresh, size: 18),
                        label: Text(provider.isConnecting ? 'Connecting...' : 'Refresh'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cyanBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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
                                child: TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _showAllDevices = true;
                                    });
                                  },
                                  icon: const Icon(Icons.expand_more, color: cyanBlue),
                                  label: Text(
                                    'Show more (${provider.pairedDevices.length - 5} more devices)',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: cyanBlue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            
                            // Show less button
                            if (_showAllDevices && provider.pairedDevices.length > 5) ...[
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _showAllDevices = false;
                                    });
                                  },
                                  icon: const Icon(Icons.expand_less, color: cyanBlue),
                                  label: Text(
                                    'Show less',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: cyanBlue,
                                      fontWeight: FontWeight.w600,
                                    ),
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
