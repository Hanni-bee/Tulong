import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import 'package:lottie/lottie.dart';
import '../widgets/modern_neumorphic_card.dart';
import '../widgets/modern_emergency_button.dart';
import '../widgets/modern_responsive_layout.dart';
import '../widgets/modern_toast.dart';
import '../widgets/modern_network_indicator.dart';
import '../widgets/modern_floating_layout.dart';
import '../widgets/emergency_alert_widget.dart';
import '../widgets/enhanced_text_styles.dart';
import '../widgets/enhanced_shadows.dart' as shadows;
import '../widgets/micro_interactions.dart';
import '../utils/page_transitions.dart';
import '../utils/phone_responsive_helper.dart';
import 'modern_global_chat_screen.dart';
import 'walkie_talkie_screen.dart';
import 'modern_people_screen.dart';
import 'modern_profile_screen.dart';
import 'modern_personal_chat_screen.dart';
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
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _welcomeAnimation;
  
  bool _isInitializing = true;
  bool _showWelcome = false;

  // Sample contacts data
  final List<Map<String, dynamic>> _sampleContacts = [
    {
      'name': 'John Doe',
      'icon': Icons.person,
      'color': AppColors.info,
      'id': 'user1',
    },
    {
      'name': 'Jane Smith',
      'icon': Icons.person_outline,
      'color': AppColors.success,
      'id': 'user2',
    },
    {
      'name': 'Mike Johnson',
      'icon': Icons.account_circle,
      'color': AppColors.warning,
      'id': 'user3',
    },
    {
      'name': 'Sarah Wilson',
      'icon': Icons.person_pin,
      'color': AppColors.error,
      'id': 'user4',
    },
    {
      'name': 'David Brown',
      'icon': Icons.face,
      'color': Colors.purple,
      'id': 'user5',
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
                      _buildHeader(),
                      const SizedBox(height: 16),
                      
                      // Quick Actions
                      shadows.FloatingCard(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: _buildQuickActions(),
                      ),
                      const SizedBox(height: 16),
                      
                      // Recent Activity
                      shadows.FloatingCard(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: _buildRecentActivity(),
                      ),
                      const SizedBox(height: 12),
                      
                      // Contacts Section
                      shadows.FloatingCard(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: _buildContactsSection(),
                      ),
                      const SizedBox(height: 12),
                      
                      // Emergency Section
                      shadows.FloatingCard(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        child: _buildEmergencySection(),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Sample Emergency Alert with GIF
                      _buildSampleEmergencyAlert(),
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
                            color: AppColors.textPrimary,
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
        // Card with beautiful red accent border and gradient background
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AppColors.white,
            border: Border.all(
              color: AppColors.primaryRed.withOpacity(0.04),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryRed.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ModernNeumorphicCard(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          // Top row with logo and notifications
          Row(
            children: [
              // App Logo - Larger and more prominent
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryRed.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: AppColors.white.withOpacity(0.9),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/app_logo (3).png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              
              const Spacer(),
              
              // Notifications
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                    BoxShadow(
                      color: AppColors.white.withOpacity(0.9),
                      blurRadius: 8,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    const Icon(
                      Icons.notifications_outlined,
                      color: AppColors.mediumGray,
                      size: 24,
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // App Info - Better typography hierarchy
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome to T.U.L.O.N.G',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Your emergency communication network',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mediumGray,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Red accent bar under the card to clearly separate from the next section
        Container(
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.primaryRed,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryRed.withOpacity(0.35),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
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
                    child: PhoneResponsiveText(
                      'Quick Actions',
                      textSize: PhoneTextSize.subtitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryRed,
                      ),
                    ),
                  ),
                  const Spacer(),
                  PhoneResponsiveText(
                    'Tap to use',
                    textSize: PhoneTextSize.caption,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryRed.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              SizedBox(height: PhoneResponsiveHelper.getPhoneSpacing(context)),
              SizedBox(
                height: PhoneResponsiveHelper.getPhoneButtonHeight(context) + PhoneResponsiveHelper.getPhoneSpacing(context) * 2,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildUniformActionButton(
                      onPressed: () => _showEmergencyDialog(context),
                      backgroundColor: AppColors.error,
                      icon: Icons.emergency,
                      title: 'Emergency',
                      subtitle: 'Alert',
                    ),
                    SizedBox(width: PhoneResponsiveHelper.getPhoneSpacing(context)),
                    _buildUniformActionButton(
                      onPressed: () => _navigateToChat(context),
                      backgroundColor: AppColors.info,
                      icon: Icons.message_rounded,
                      title: 'Send',
                      subtitle: 'Message',
                    ),
                    SizedBox(width: PhoneResponsiveHelper.getPhoneSpacing(context)),
                    _buildUniformActionButton(
                      onPressed: () => _navigateToContacts(context),
                      backgroundColor: Colors.green,
                      icon: Icons.person_add,
                      title: 'Message',
                      subtitle: 'Contact',
                    ),
                    SizedBox(width: PhoneResponsiveHelper.getPhoneSpacing(context)),
                    _buildUniformActionButton(
                      onPressed: () => _navigateToWalkieTalkie(context),
                      backgroundColor: AppColors.success,
                      icon: Icons.call_rounded,
                      title: 'Voice',
                      subtitle: 'Call',
                    ),
                    SizedBox(width: PhoneResponsiveHelper.getPhoneSpacing(context)),
                    _buildUniformActionButton(
                      onPressed: () => _navigateToPeople(context),
                      backgroundColor: AppColors.warning,
                      icon: Icons.people_rounded,
                      title: 'People',
                      subtitle: 'Contacts',
                    ),
                    SizedBox(width: PhoneResponsiveHelper.getPhoneSpacing(context)),
                    _buildUniformActionButton(
                      onPressed: () => _navigateToProfile(context),
                      backgroundColor: AppColors.primaryRed,
                      icon: Icons.person_rounded,
                      title: 'Profile',
                      subtitle: 'Settings',
                    ),
                    SizedBox(width: PhoneResponsiveHelper.getPhoneSpacing(context)),
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
          padding: PhoneResponsiveHelper.getPhonePadding(context),
          borderRadius: BorderRadius.circular(PhoneResponsiveHelper.getPhoneBorderRadius(context) * 0.75),
          shadows: shadows.EnhancedShadows.buttonMedium,
          child: SizedBox(
            width: PhoneResponsiveHelper.getPhoneContactCardWidth(context) * 0.8,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon, 
                  color: AppColors.white, 
                  size: PhoneResponsiveHelper.getPhoneIconSize(context, small: 20, medium: 22, large: 24, extraLarge: 26),
                ),
                SizedBox(height: PhoneResponsiveHelper.getPhoneSpacing(context) * 0.5),
                PhoneResponsiveText(
                  title,
                  textSize: PhoneTextSize.caption,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                PhoneResponsiveText(
                  subtitle,
                  textSize: PhoneTextSize.caption,
                  style: const TextStyle(
                    color: AppColors.white,
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

  Widget _buildContactsSection() {
    return PhoneResponsiveBuilder(
      builder: (context, screenSize) {
        return Container(
          padding: PhoneResponsiveHelper.getPhonePadding(context),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(PhoneResponsiveHelper.getPhoneBorderRadius(context)),
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
                    padding: EdgeInsets.symmetric(
                      horizontal: PhoneResponsiveHelper.getPhoneSpacing(context) * 0.5,
                      vertical: PhoneResponsiveHelper.getPhoneSpacing(context) * 0.25,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(PhoneResponsiveHelper.getPhoneBorderRadius(context) * 0.5),
                    ),
                    child: PhoneResponsiveText(
                      'Contacts',
                      textSize: PhoneTextSize.subtitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryRed,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _navigateToPeople(context),
                    child: PhoneResponsiveText(
                      'View All',
                      textSize: PhoneTextSize.body,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryRed,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: PhoneResponsiveHelper.getPhoneSpacing(context)),
              SizedBox(
                height: PhoneResponsiveHelper.getPhoneContactCardWidth(context) + 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _sampleContacts.length,
                  itemBuilder: (context, index) {
                    final contact = _sampleContacts[index];
                    return Container(
                      width: PhoneResponsiveHelper.getPhoneContactCardWidth(context),
                      margin: EdgeInsets.only(right: PhoneResponsiveHelper.getPhoneSpacing(context)),
                      child: Column(
                        children: [
                          // Contact Avatar
                          GestureDetector(
                            onTap: () => _startPrivateChat(context, contact),
                            child: Container(
                              width: PhoneResponsiveHelper.getPhoneContactAvatarSize(context),
                              height: PhoneResponsiveHelper.getPhoneContactAvatarSize(context),
                              decoration: BoxDecoration(
                                color: contact['color'].withOpacity(0.1),
                                borderRadius: BorderRadius.circular(PhoneResponsiveHelper.getPhoneBorderRadius(context)),
                                border: Border.all(
                                  color: contact['color'].withOpacity(0.3),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: contact['color'].withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                contact['icon'],
                                color: contact['color'],
                                size: PhoneResponsiveHelper.getPhoneIconSize(context, small: 24, medium: 26, large: 28, extraLarge: 30),
                              ),
                            ),
                          ),
                          SizedBox(height: PhoneResponsiveHelper.getPhoneSpacing(context) * 0.5),
                          // Contact Name
                          PhoneResponsiveText(
                            contact['name'],
                            textSize: PhoneTextSize.caption,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: PhoneResponsiveHelper.getPhoneSpacing(context) * 0.25),
                          // Message Button
                          GestureDetector(
                            onTap: () => _startPrivateChat(context, contact),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: PhoneResponsiveHelper.getPhoneSpacing(context) * 0.5,
                                vertical: PhoneResponsiveHelper.getPhoneSpacing(context) * 0.25,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryRed,
                                borderRadius: BorderRadius.circular(PhoneResponsiveHelper.getPhoneBorderRadius(context) * 0.75),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryRed.withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.message,
                                    color: AppColors.white,
                                    size: PhoneResponsiveHelper.getPhoneIconSize(context, small: 10, medium: 12, large: 14, extraLarge: 16),
                                  ),
                                  SizedBox(width: PhoneResponsiveHelper.getPhoneSpacing(context) * 0.25),
                                  PhoneResponsiveText(
                                    'Message',
                                    textSize: PhoneTextSize.caption,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
          child: ModernEmergencyFAB(
            onPressed: () => _showEmergencyDialog(context),
            isActive: true,
            showPulse: true,
          ),
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
          title: 'Emergency Alert System Active',
          message: 'This is how emergency alerts will appear in the app. The system is monitoring for disasters and will automatically notify all users.',
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
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      ModernPageRoute(
        child: const ModernGlobalChatScreen(),
        transitionType: ModernTransitionType.slideAndFade,
      ),
    );
  }

  void _navigateToWalkieTalkie(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      ModernPageRoute(
        child: const WalkieTalkieScreen(),
        transitionType: ModernTransitionType.slideAndFade,
      ),
    );
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

  void _navigateToContacts(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      ModernPageRoute(
        child: const ModernPeopleScreen(),
        transitionType: ModernTransitionType.slideAndFade,
      ),
    );
  }

  void _startPrivateChat(BuildContext context, Map<String, dynamic> contact) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      ModernPageRoute(
        child: ModernPersonalChatScreen(
          contactName: contact['name'],
          contactId: contact['id'],
        ),
        transitionType: ModernTransitionType.slideAndFade,
      ),
    );
  }

  void _showEmergencyDialog(BuildContext context) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isSending = false;
            
            return AlertDialog(
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
              content: const Text(
                'This will send an emergency alert to all connected users in your network. Are you sure you want to proceed?',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSending ? null : () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.mediumGray,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSending ? null : () async {
                    setDialogState(() {
                      isSending = true;
                    });
                    
                    HapticFeedback.heavyImpact();
                    
                    // Simulate sending emergency alert
                    await Future.delayed(const Duration(seconds: 2));
                    
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      ModernToastManager.showSuccess(
                        context,
                        'Emergency alert sent successfully!',
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: AppColors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Send Alert'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
