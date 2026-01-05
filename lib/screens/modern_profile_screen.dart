import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tulong_app/constants/app_colors.dart';
import 'package:tulong_app/constants/unified_typography.dart';
import 'package:tulong_app/constants/soft_ui_design.dart';
import 'package:tulong_app/providers/auth_provider.dart';
import 'package:tulong_app/models/user_model.dart';
import 'package:tulong_app/screens/notification_settings_screen.dart';
import 'package:tulong_app/widgets/animated_neumorphic_card.dart';
import 'package:tulong_app/widgets/unified_top_bar.dart';
import 'package:tulong_app/utils/prototype_animations.dart';
import 'package:tulong_app/widgets/enhanced_skeleton_loaders.dart';
import 'package:tulong_app/widgets/accessible_text.dart';
import 'package:tulong_app/utils/icon_system.dart';
import '../widgets/user_engagement_dashboard.dart';
import '../providers/chat_provider.dart';

class ModernProfileScreen extends StatefulWidget {
  const ModernProfileScreen({super.key});

  @override
  State<ModernProfileScreen> createState() => _ModernProfileScreenState();
}

class _ModernProfileScreenState extends State<ModernProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Stagger animations for Stat Cards (2 cards)
  late StaggeredListAnimations _statCardsStagger;
  
  // Loading state
  bool _isLoadingProfile = true;

  // Dynamic user profile data will be fetched from AuthProvider

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

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
    
    // Initialize stagger animations for Stat Cards (4 cards)
    _statCardsStagger = StaggeredListAnimations(
      vsync: this,
      itemCount: 4,
    );
    
    // Load user model immediately when screen opens to ensure data is available
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.userEmail != null) {
        // Always try to load user model, even if it exists (to refresh data)
        await authProvider.loadUserModel();
      }
      // Simulate loading delay for better UX
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _statCardsStagger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar - part of Column layout, fixed at top
            TopBarConfigs.profileTopBar(onEdit: () => _editProfile(context)),
            
            // Scrollable content - only this part scrolls
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        _buildQuickStats(),
                        const SizedBox(height: 20),
                        _buildStatsSection(),
                        const SizedBox(height: 20),
                        _buildUserEngagementDashboard(),
                        const SizedBox(height: 20),
                        _buildSettingsSections(),
                        const SizedBox(height: 20),
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    if (_isLoadingProfile) {
      return SkeletonProfileHeader();
    }
    
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        // Ensure user model is loaded
        if (auth.userEmail != null && auth.currentUserModel == null) {
          // Load user model if not already loaded
          WidgetsBinding.instance.addPostFrameCallback((_) {
            auth.loadUserModel();
          });
        }
        
        final userName = auth.userName ?? 'User';
        final userEmail = auth.userEmail ?? 'user@example.com';
        final userModel = auth.currentUserModel;
        
        // Compose location string from model fields
        final location = [
          if ((userModel?.city ?? '').isNotEmpty) userModel!.city,
          if ((userModel?.province ?? '').isNotEmpty) userModel!.province,
        ].join(', ');
        
        // Get phone from userModel or fallback
        final phone = userModel?.phone ?? '';
        
         return Container(
          margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
            // Enhanced gradient background
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryRed,
                AppColors.primaryRed.withOpacity(0.85),
                AppColors.primaryDark,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(SoftUIDesign.cardBorderRadius),
            boxShadow: [
              // Enhanced shadow for depth
              BoxShadow(
                color: AppColors.primaryRed.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 2,
              ),
              ...SoftUIDesign.getCardShadow(elevation: 6.0),
            ],
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 1.5,
            ),
             ),
          child: Stack(
               children: [
              // Decorative overlays using SoftUI system
              ...SoftUIDesign.buildProfileHeaderOverlays(),

              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.4),
                          width: 2.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: Colors.white.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: AccessibleText(
                          _getInitials(userName),
                          baseStyle: UnifiedTypography.displaySmall.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                          color: Colors.white,
                          backgroundColor: AppColors.primaryRed,
                          isHeading: true,
                        ),
                      ),
                    ),
                 const SizedBox(width: 14),
                 Expanded(
              child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                       Tooltip(
                         message: userName, // Show full name on hover
                        child: AccessibleHeading(
                          userName,
                          level: HeadingLevel.h2,
                          color: Colors.white,
                          backgroundColor: AppColors.primaryRed,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                       ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: Colors.greenAccent,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.greenAccent.withOpacity(0.6),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              const AccessibleBodyText(
                                'Connected',
                                size: BodySize.small,
                                color: Colors.white,
                                backgroundColor: AppColors.primaryRed,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => _editProfile(context),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.4)),
                        ),
                        child: const Icon(Icons.edit, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Container(height: 1, color: Colors.white.withOpacity(0.25)),
                const SizedBox(height: 12),

                         _buildClickableContactInfo(
                           context,
                           icon: Icons.mail_outline,
                           text: userEmail,
                           onTap: () => _copyToClipboard(context, userEmail, 'Email copied'),
                           onLongPress: () => _openEmailApp(context, userEmail),
                         ),
                const SizedBox(height: 8),
                if (phone.isNotEmpty)
                  _buildClickableContactInfo(
                    context,
                    icon: IconSystem.phone,
                    text: phone,
                    onTap: () => _copyToClipboard(context, phone, 'Phone number copied'),
                    onLongPress: () => _makePhoneCall(context, phone),
                  ),
                if (phone.isNotEmpty) const SizedBox(height: 8),
                if (location.isNotEmpty)
                  _buildClickableContactInfo(
                    context,
                    icon: IconSystem.location,
                    text: location,
                    onTap: () => _copyToClipboard(context, location, 'Address copied'),
                    onLongPress: () => _openMaps(context, location),
                  ),
                      ],
                    ),
                  ),
          // end of Padding
                ],
          ),
        );
      },
    );
  }

  Widget _buildStatsSection() {
    if (_isLoadingProfile) {
        return Container(
          margin: const EdgeInsets.only(bottom: 32),
          child: Row(
            children: const [
              Expanded(child: SkeletonStatCard()),
              SizedBox(width: 16),
              Expanded(child: SkeletonStatCard()),
            ],
          ),
        );
    }
    
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        final userModel = auth.currentUserModel;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 32),
          child: Row(
            children: [
              Expanded(
                child: _statCardsStagger.buildAnimatedItem(
                  0,
                  _buildStatCard(
                    title: 'Days Active',
                    value: _getDaysActiveCount(userModel),
                    icon: Icons.calendar_today_outlined,
                    color: AppColors.info,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _statCardsStagger.buildAnimatedItem(
                  1,
                  FutureBuilder<String>(
                    future: _getConnectedDevicesCountAsync(),
                    builder: (context, snapshot) {
                      final deviceCount = snapshot.data ?? '0';
                      return _buildStatCard(
                        title: 'Connected Devices',
                        value: deviceCount,
                        icon: Icons.bluetooth_connected,
                        color: AppColors.primaryRed,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserEngagementDashboard() {
    return Consumer2<AuthProvider, ChatProvider>(
      builder: (context, auth, chatProvider, child) {
        // Get real data from providers
        final messages = chatProvider.messages;
        final sentMessages = messages.where((m) => m.isMe).length;
        final receivedMessages = messages.where((m) => !m.isMe).length;
        final connectionsCount = chatProvider.connectedUsersCount;
        
        // TODO: Get emergency alerts count from OfflineMessagingService or SQLite
        // For now using estimated values based on messages
        final estimatedAlertsSent = (sentMessages * 0.1).round(); // Estimate 10% are alerts
        final estimatedAlertsReceived = (receivedMessages * 0.08).round();
        
        // TODO: Calculate average response time from message timestamps
        // For now, using a placeholder
        double avgResponseTime = 0.0;
        if (messages.isNotEmpty && messages.length > 1) {
          // Simple calculation: average time between sent and received messages
          final sentTimes = messages.where((m) => m.isMe).map((m) => m.timestamp).toList()..sort();
          final receivedTimes = messages.where((m) => !m.isMe).map((m) => m.timestamp).toList()..sort();
          
          if (sentTimes.isNotEmpty && receivedTimes.isNotEmpty) {
            // Calculate average time difference
            int totalDiff = 0;
            int count = 0;
            for (var sentTime in sentTimes) {
              var closestReceived = receivedTimes.firstWhere(
                (rt) => rt.isAfter(sentTime),
                orElse: () => sentTime,
              );
              if (closestReceived != sentTime && closestReceived.isAfter(sentTime)) {
                totalDiff += closestReceived.difference(sentTime).inMinutes;
                count++;
              }
            }
            if (count > 0) {
              avgResponseTime = (totalDiff / count).toDouble();
            }
          }
        }
        
        // TODO: Track help provided/received - for now using placeholder
        final helpProvided = 0; // Track in future updates
        final helpReceived = 0; // Track in future updates
        
        return UserEngagementDashboard(
          isLoading: _isLoadingProfile,
          emergencyAlertsSent: estimatedAlertsSent,
          emergencyAlertsReceived: estimatedAlertsReceived,
          messagesSent: sentMessages,
          messagesReceived: receivedMessages,
          connectionsMade: connectionsCount,
          averageResponseTime: avgResponseTime,
          helpProvided: helpProvided,
          helpReceived: helpReceived,
        );
      },
    );
  }

  // Old weekly activity chart removed - replaced with UserEngagementDashboard

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 140),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withOpacity(0.03),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Content - centered with proper spacing
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon with enhanced styling
                  Container(
                    width: 52,
                    height: 52,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 24,
                    ),
                  ),
                  // Value text - larger and bolder
                  Text(
                    value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 26,
                      height: 1.0,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Title text
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSections() {
    return Column(
      children: [
        _buildSettingsSection(
          title: 'Account Settings',
          items: [
            _buildSettingsItem(
              icon: Icons.sms_failed_outlined,
              title: 'Emergency Message',
              subtitle: 'Set the message sent during emergency',
              onTap: () => _editEmergencyMessage(context),
            ),
            _buildSettingsItem(
              icon: Icons.security,
              title: 'Security',
              subtitle: 'Password and security settings',
              onTap: () => _openSecurity(context),
            ),
            _buildSettingsItem(
              icon: Icons.notifications,
              title: 'Notifications',
              subtitle: 'Manage notification preferences',
              onTap: () => _openNotifications(context),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSettingsSection(
          title: 'Support',
          items: [
            _buildSettingsItem(
              icon: Icons.help,
              title: 'Help Center',
              subtitle: 'Get help and support',
              onTap: () => _showHelpCenterModal(context),
            ),
            _buildSettingsItem(
              icon: IconSystem.info,
              title: 'About',
              subtitle: 'App version and information',
              onTap: () => _showAboutModal(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required List<Widget> items,
  }) {
    return AnimatedNeumorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: UnifiedTypography.titleMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...items,
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(SoftUIDesign.buttonBorderRadius),
                  border: Border.all(
                    color: AppColors.primaryRed.withOpacity(0.2),
                    width: 1.0,
                  ),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primaryRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: UnifiedTypography.bodyLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: UnifiedTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: AppColors.textSecondary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: SoftUIDesign.buttonDecoration(
              backgroundColor: AppColors.primaryRed,
              borderRadius: SoftUIDesign.buttonBorderRadius,
              shadowColor: AppColors.primaryRed,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _signOut(context),
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                        Icons.logout,
                        color: AppColors.white,
                        size: 20,
                            ),
                            SizedBox(width: 8),
                      Text(
                        'Sign Out',
                                style: TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
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
    );
  }

  // Action methods
  void _editProfile(BuildContext context) async {
    HapticFeedback.lightImpact();
    // Navigate to edit profile screen
    await Navigator.of(context).pushNamed('/update-profile');
    
    // Reload user model after returning from edit profile to show updated data
    if (mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.userEmail != null) {
        await authProvider.loadUserModel();
        // Force UI rebuild
        setState(() {});
      }
    }
  }

  void _openSecurity(BuildContext context) {
    HapticFeedback.lightImpact();
    final auth = context.read<AuthProvider>();

    // Check if user is using Gmail SSO
    final bool isGmailSSO = auth.isGmailSSO;

    final TextEditingController currentCtrl = TextEditingController();
    final TextEditingController newCtrl = TextEditingController();
    final TextEditingController confirmCtrl = TextEditingController();

    // State for password visibility
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: AnimatedNeumorphicCard(
                margin: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isGmailSSO ? Icons.account_circle : Icons.security,
                          color: AppColors.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Security',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary),
                          ),
                        ),
                        if (isGmailSSO)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: SoftUIDesign.cardDecoration(
                              backgroundColor: AppColors.white,
                              borderRadius: SoftUIDesign.buttonBorderRadius,
                              elevation: 2.0,
                              borderColor: AppColors.info.withOpacity(0.3),
                              showBorder: true,
                            ),
                            child: const Text(
                              'Google Account',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.info,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (!isGmailSSO) ...[
                      // Current Password (only for sign-up accounts)
                      Container(
                        decoration: SoftUIDesign.cardDecoration(
                          backgroundColor: AppColors.white,
                          borderRadius: SoftUIDesign.inputBorderRadius,
                          elevation: 2.0,
                          borderColor: AppColors.lightGray.withOpacity(0.3),
                          showBorder: true,
                        ),
                        child: TextField(
                        controller: currentCtrl,
                        obscureText: obscureCurrent,
                        decoration: InputDecoration(
                          labelText: 'Current Password',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          hintText: 'Enter your current password',
                            filled: true,
                            fillColor: Colors.transparent,
                          suffixIcon: IconButton(
                            icon: Icon(obscureCurrent
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () {
                              setModalState(() {
                                obscureCurrent = !obscureCurrent;
                              });
                            },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // New Password
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryRed.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(2, 2),
                          ),
                          BoxShadow(
                            color: AppColors.white.withOpacity(0.8),
                            blurRadius: 4,
                            offset: const Offset(-2, -2),
                          ),
                        ],
                      ),
                      child: TextField(
                      controller: newCtrl,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: isGmailSSO ? 'New or Create Password' : 'New Password',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        hintText: isGmailSSO ? 'Enter a password to enable email login' : 'Enter your new password',
                          filled: true,
                          fillColor: Colors.transparent,
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () {
                            setModalState(() {
                              obscureNew = !obscureNew;
                            });
                          },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Confirm Password
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryRed.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(2, 2),
                          ),
                          BoxShadow(
                            color: AppColors.white.withOpacity(0.8),
                            blurRadius: 4,
                            offset: const Offset(-2, -2),
                          ),
                        ],
                      ),
                      child: TextField(
                      controller: confirmCtrl,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        hintText: 'Confirm your new password',
                          filled: true,
                          fillColor: Colors.transparent,
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () {
                            setModalState(() {
                              obscureConfirm = !obscureConfirm;
                            });
                          },
                          ),
                        ),
                      ),
                    ),
                    if (isGmailSSO) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                          color: AppColors.info.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(2, 2),
                            ),
                            BoxShadow(
                              color: AppColors.white.withOpacity(0.8),
                              blurRadius: 4,
                              offset: const Offset(-2, -2),
                            ),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: AppColors.info, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'You can create a password to enable email/password login alongside your Google Sign-In.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.info,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryRed.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(2, 2),
                              ),
                              BoxShadow(
                                color: AppColors.white.withOpacity(0.8),
                                blurRadius: 4,
                                offset: const Offset(-2, -2),
                              ),
                            ],
                          ),
                          child: TextButton(
                          onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryRed.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(3, 3),
                              ),
                              BoxShadow(
                                color: AppColors.white.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(-3, -3),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                          onPressed: () async {
                            if (newCtrl.text.isEmpty || confirmCtrl.text.isEmpty) {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill out all password fields.'), backgroundColor: AppColors.error));
                               return;
                            }
                            if (newCtrl.text.length < 6) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters.'), backgroundColor: AppColors.error));
                              return;
                            }
                            if (newCtrl.text != confirmCtrl.text) {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match.'), backgroundColor: AppColors.error));
                               return;
                            }
                            
                            try {
                               bool success = false;
                               if(isGmailSSO){
                                  await auth.createPasswordForGoogleAccount(newCtrl.text);
                                  success = true;
                               } else {
                                  if (currentCtrl.text.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your current password.'), backgroundColor: AppColors.error));
                                      return;
                                  }
                                  final isValid = await auth.verifyCurrentPassword(currentCtrl.text);
                                  if(!mounted) return;
                                  if(isValid){
                                    await auth.updatePassword(newCtrl.text);
                                    success = true;
                                  } else {
                                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Current password is incorrect.'), backgroundColor: AppColors.error));
                                  }
                               }

                               if(!mounted) return;

                               if(success){
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully!'), backgroundColor: AppColors.success));
                               }
                            } catch (e) {
                              if(!mounted) return;
                               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An error occurred: $e'), backgroundColor: AppColors.error));
                            }
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: AppColors.white,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Update',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _openNotifications(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const NotificationSettingsScreen(),
      ),
    );
  }

  void _editEmergencyMessage(BuildContext context) {
    HapticFeedback.lightImpact();
    final auth = context.read<AuthProvider>();
    final TextEditingController controller = TextEditingController(text: auth.emergencyMessage ?? 'I need help. Please contact me immediately.');

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

  void _signOut(BuildContext context) {
    HapticFeedback.lightImpact();
    final rootContext = context; // preserve parent context for navigation
    showModalBottomSheet(
      context: rootContext,
      backgroundColor: Colors.white,
      isScrollControlled: false,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: AnimatedNeumorphicCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout, color: AppColors.primaryRed, size: 28),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sign out of T.U.L.O.N.G?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'You\'ll be returned to the login screen. Your offline data remains saved on this device.',
                    style: TextStyle(color: AppColors.textSecondary, height: 1.3),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(color: AppColors.lightGray.withOpacity(0.6), width: 1.4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            // Close bottom sheet first
                            Navigator.pop(sheetContext);
                            
                            // Sign out
                            await rootContext.read<AuthProvider>().signOut();
                            
                            // Navigate to sign-in screen and clear navigation stack
                            if (rootContext.mounted) {
                              Navigator.of(rootContext, rootNavigator: true).pushNamedAndRemoveUntil(
                                '/signin',
                                (route) => false,
                              );
                            }
                          } catch (e) {
                            print('❌ Logout error: $e');
                            // Even if there's an error, try to navigate
                            if (rootContext.mounted) {
                              Navigator.of(rootContext, rootNavigator: true).pushNamedAndRemoveUntil(
                                '/signin',
                                (route) => false,
                              );
                            }
                          }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 6,
                          shadowColor: AppColors.primaryRed.withOpacity(0.35),
                        ),
                        child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }


  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return 'U';
    List<String> parts = name.split(' ');
    return (parts[0].isNotEmpty ? parts[0][0] : '') +
        (parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '');
  }

  // Clickable contact info widget with copy functionality
  Widget _buildClickableContactInfo(
    BuildContext context, {
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: AccessibleBodyText(
                  text,
                  color: Colors.white,
                  backgroundColor: AppColors.primaryRed,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.copy,
                color: Colors.white.withOpacity(0.7),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Copy to clipboard helper
  Future<void> _copyToClipboard(BuildContext context, String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(message),
            ],
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
    HapticFeedback.lightImpact();
  }

  // Open email app
  Future<void> _openEmailApp(BuildContext context, String email) async {
    final uri = Uri.parse('mailto:$email');
    try {
      // In a real app, you might use url_launcher package
      // For now, just copy the email
      await _copyToClipboard(context, email, 'Email copied');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open email app: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // Make phone call
  Future<void> _makePhoneCall(BuildContext context, String phone) async {
    final uri = Uri.parse('tel:$phone');
    try {
      // In a real app, you might use url_launcher package
      // For now, just copy the phone number
      await _copyToClipboard(context, phone, 'Phone number copied');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not make call: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // Open maps
  Future<void> _openMaps(BuildContext context, String location) async {
    try {
      // In a real app, you might use url_launcher package with maps URL
      // For now, just copy the location
      await _copyToClipboard(context, location, 'Address copied');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open maps: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // Dynamic stats calculation methods using real data
  String _getDaysActiveCount(UserModel? userModel) {
    if (userModel == null) return '0';
    // Calculate days since user joined using real data
    if (userModel.createdAt > 0) {
      // Handle both milliseconds and seconds timestamps
      int timestamp = userModel.createdAt;
      
      // If timestamp is less than a reasonable date (year 2000 in milliseconds),
      // it's likely in seconds, so convert to milliseconds
      if (timestamp < 946684800000) { // Jan 1, 2000 in milliseconds
        timestamp = timestamp * 1000;
      }
      
      try {
        final createdAtDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final now = DateTime.now();
        final daysSinceJoin = now.difference(createdAtDate).inDays;
        
        // Ensure non-negative result
        return daysSinceJoin >= 0 ? daysSinceJoin.toString() : '0';
      } catch (e) {
        print('Error calculating days active: $e');
        return '0';
      }
    }
    return '0';
  }

  Future<String> _getConnectedDevicesCountAsync() async {
    try {
      int count = 0;
      
      // Check SharedPreferences for saved paired device
      final prefs = await SharedPreferences.getInstance();
      final pairedDeviceName = prefs.getString('paired_device_name');
      
      // Check if we have a paired device saved
      if (pairedDeviceName != null && pairedDeviceName.isNotEmpty) {
        count++;
      }
      
      // Also check for ESP32 MAC address and node ID (from previous connections)
      final esp32Mac = prefs.getString('esp32_mac');
      final esp32NodeId = prefs.getString('esp32_node_id');
      
      // If we have ESP32 connection data but no paired device name, still count it
      if ((esp32Mac != null && esp32Mac.isNotEmpty) || 
          (esp32NodeId != null && esp32NodeId.isNotEmpty)) {
        if (pairedDeviceName == null || pairedDeviceName.isEmpty) {
          count++;
        }
      }
      
      return count.toString();
    } catch (e) {
      return '0';
    }
  }

  // Help Center Modal
  void _showHelpCenterModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.help_outline,
                      color: AppColors.primaryRed,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Help Center',
                          style: UnifiedTypography.titleLarge.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Get help and support',
                          style: UnifiedTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Help Topics
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHelpTopic(
                        icon: Icons.emergency,
                        title: 'Emergency Features',
                        description: 'Learn how to send emergency alerts and SOS messages',
                      ),
                      const SizedBox(height: 16),
                      _buildHelpTopic(
                        icon: Icons.bluetooth,
                        title: 'Bluetooth Connection',
                        description: 'How to connect to ESP32 devices and mesh network',
                      ),
                      const SizedBox(height: 16),
                      _buildHelpTopic(
                        icon: Icons.chat_bubble,
                        title: 'Local Chat',
                        description: 'Send messages and voice recordings to nearby users',
                      ),
                      const SizedBox(height: 16),
                      _buildHelpTopic(
                        icon: Icons.radio,
                        title: 'Voice Calls',
                        description: 'Push-to-talk walkie-talkie style communication',
                      ),
                      const SizedBox(height: 16),
                      _buildHelpTopic(
                        icon: Icons.network_check,
                        title: 'Network Status',
                        description: 'Monitor connection status and nearby users',
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Contact Support Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    // TODO: Open support email or contact form
                  },
                  icon: const Icon(Icons.email),
                  label: const Text('Contact Support'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  Widget _buildHelpTopic({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lightGray.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.lightGray.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppColors.primaryRed,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: UnifiedTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: UnifiedTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // About Modal
  void _showAboutModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: AppColors.primaryRed,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'About',
                      style: UnifiedTypography.titleLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // App Logo/Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryRed.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.emergency,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              
              // App Name
              Text(
                'T.U.L.O.N.G',
                style: UnifiedTypography.headlineSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              
              // Full Name
              Text(
                'Transmission Unit for Local\nOffline Network Generation',
                textAlign: TextAlign.center,
                style: UnifiedTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              
              // Version Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.lightGray.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildAboutRow('Version', '1.0.0'),
                    const Divider(height: 24),
                    _buildAboutRow('Build', 'Release'),
                    const Divider(height: 24),
                    _buildAboutRow('Platform', 'Android'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Description
              Text(
                'A disaster-ready communication system for emergency situations. Connect with nearby users through mesh networking when traditional communication fails.',
                textAlign: TextAlign.center,
                style: UnifiedTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              
              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAboutRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: UnifiedTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: UnifiedTypography.bodyMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
