import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:tulong_app/constants/app_colors.dart';
import 'package:tulong_app/constants/storage_keys.dart';
import 'package:tulong_app/constants/unified_typography.dart';
import 'package:tulong_app/constants/soft_ui_design.dart';
import 'package:tulong_app/utils/theme_colors.dart';
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
import '../providers/theme_provider.dart';
import '../services/user_status_service.dart';
import '../models/emergency_type.dart';

class ModernProfileScreen extends StatefulWidget {
  const ModernProfileScreen({super.key, this.refreshTrigger = 0});

  /// When this changes (e.g. parent increments when user taps Profile tab), status is refetched.
  final int refreshTrigger;

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
  
  // Scroll controller for scrollable content
  final ScrollController _scrollController = ScrollController();
  
  // Loading state
  bool _isLoadingProfile = true;

  /// Status future; refreshed when [ModernProfileScreen.refreshTrigger] changes (e.g. user opens Profile tab).
  Future<Map<String, dynamic>?>? _statusFuture;
  int? _lastRefreshTrigger;

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
    
    
    _statusFuture = UserStatusService.instance.getFormattedStatus();
    _lastRefreshTrigger = widget.refreshTrigger;

    // Load user model immediately when screen opens to ensure data is available
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.userUsername != null) {
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
  void didUpdateWidget(ModernProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshTrigger != oldWidget.refreshTrigger) {
      setState(() {
        _lastRefreshTrigger = widget.refreshTrigger;
        _statusFuture = UserStatusService.instance.getFormattedStatus();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _statCardsStagger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.background(context),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Top bar - part of Column layout, fixed at top
                TopBarConfigs.profileTopBar(
                  onEdit: () => _editProfile(context),
                ),
                
                // Scrollable content - only this part scrolls
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.primaryRed,
                    backgroundColor: ThemeColors.surface(context),
                    displacement: 60,
                    onRefresh: _refreshProfile,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const ClampingScrollPhysics(),
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
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
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
  }

  Widget _buildQuickStats() {
    if (_isLoadingProfile) {
      return SkeletonProfileHeader();
    }
    
    return Consumer2<AuthProvider, ChatProvider>(
      builder: (context, auth, chat, child) {
        // Ensure user model is loaded
        if (auth.userUsername != null && auth.currentUserModel == null) {
          // Load user model if not already loaded
          WidgetsBinding.instance.addPostFrameCallback((_) {
            auth.loadUserModel();
          });
        }
        
        final userName = auth.userName ?? 'User';
        final username = auth.userUsername ?? 'username';
        final userModel = auth.currentUserModel;
        final isConnected = chat.isConnected;
        
        // Compose an address label from model fields (short for header display)
        final location = _composeAddressShort(userModel);
        final fullAddress = _composeFullAddress(userModel);
        final avatar = (userModel?.avatar ?? '').trim();
        
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
              ...SoftUIDesign.getCardShadow(context: context, elevation: 6.0),
            ],
            border: Border.all(
              color: Colors.white.withOpacity(0.25),
              width: 1.5,
            ),
             ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1.0);
              final isNarrow = constraints.maxWidth < 360;
              final isA11yLargeText = textScale >= 1.2;
              final isCompact = isNarrow || isA11yLargeText;

              final double padding = isCompact ? 14 : 16;
              final double avatarSize = isCompact ? 56 : 64;
              final double avatarRadius = isCompact ? 14 : 16;
              final double nameFontSize = isCompact ? 16 : 18;
              final double initialsFontSize = isCompact ? 22 : 24;
              final maxQuickActions = isCompact ? 3 : 4;

              final quickActions = _buildHeaderQuickActions(
                context,
                isConnected: isConnected,
                username: username,
                hasAddress: location.isNotEmpty,
                fullAddress: fullAddress,
              );

              return ClipRRect(
                borderRadius: BorderRadius.circular(SoftUIDesign.cardBorderRadius),
                child: Stack(
                  children: [
                    // Decorative overlays using SoftUI system
                    ...SoftUIDesign.buildProfileHeaderOverlays(context: context),

                    // Subtle contrast scrim (solid, no blur) to keep text readable
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withOpacity(0.08),
                                Colors.black.withOpacity(0.16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Content
                    Padding(
                      padding: EdgeInsets.all(padding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDynamicAvatar(
                                userName: userName,
                                avatar: avatar,
                                size: avatarSize,
                                radius: avatarRadius,
                                initialsFontSize: initialsFontSize,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Tooltip(
                                      message: userName, // Show full name on hover
                                      child: Text(
                                        userName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: UnifiedTypography.titleLarge.copyWith(
                                          fontSize: nameFontSize,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatHandle(username),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: UnifiedTypography.bodySmall.copyWith(
                                        color: Colors.white.withOpacity(0.9),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (location.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        location,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: UnifiedTypography.bodySmall.copyWith(
                                          color: Colors.white.withOpacity(0.9),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ] else ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Address not set',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: UnifiedTypography.bodySmall.copyWith(
                                          color: Colors.white.withOpacity(0.85),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    _buildConnectionPill(isConnected: isConnected),
                                  ],
                                ),
                              ),
                              // Header quick edit (still useful; top bar also has edit)
                              InkWell(
                                onTap: () => _editProfile(context),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.35),
                                      width: 1.2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.edit_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),
                          Container(height: 1, color: Colors.white.withOpacity(0.22)),
                          const SizedBox(height: 10),

                          // Quick actions (wrap on small widths)
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ...quickActions.take(maxQuickActions),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Primary quick info actions (copy/open)
                          _buildClickableContactInfo(
                            context,
                            icon: Icons.person_outline,
                            text: username,
                            onTap: () => _copyToClipboard(context, username, 'Username copied'),
                            onLongPress: null,
                          ),
                          const SizedBox(height: 8),
                          if (location.isNotEmpty)
                            _buildClickableContactInfo(
                              context,
                              icon: IconSystem.location,
                              text: location,
                              onTap: () => _copyToClipboard(context, fullAddress, 'Address copied'),
                              onLongPress: () => _openMaps(context, fullAddress),
                            )
                          else
                            _buildHeaderCallToAction(
                              context,
                              icon: IconSystem.location,
                              text: 'Add your address',
                              onTap: () => _editProfile(context),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  List<Widget> _buildHeaderQuickActions(
    BuildContext context, {
    required bool isConnected,
    required String username,
    required bool hasAddress,
    required String fullAddress,
  }) {
    final actions = <Widget>[];

    actions.add(
      _buildHeaderQuickAction(
        icon: Icons.person_outline,
        label: 'Copy username',
        onTap: () => _copyToClipboard(context, username, 'Username copied'),
      ),
    );

    if (hasAddress) {
      actions.add(
        _buildHeaderQuickAction(
          icon: Icons.copy,
          label: 'Copy address',
          onTap: () => _copyToClipboard(context, fullAddress, 'Address copied'),
        ),
      );
    } else {
      actions.add(
        _buildHeaderQuickAction(
          icon: IconSystem.location,
          label: 'Add address',
          onTap: () => _editProfile(context),
        ),
      );
    }

    if (!isConnected) {
      actions.add(
        _buildHeaderQuickAction(
          icon: Icons.bluetooth_searching,
          label: 'Scan devices',
          onTap: () => _openDeviceScanner(context),
        ),
      );
    }

    return actions;
  }

  void _openDeviceScanner(BuildContext context) {
    try {
      Navigator.of(context).pushNamed('/esp32-scanner');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open device scanner: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildDynamicAvatar({
    required String userName,
    required String avatar,
    required double size,
    required double radius,
    required double initialsFontSize,
  }) {
    final hasAvatar = avatar.isNotEmpty;

    Widget content;
    if (hasAvatar && avatar.startsWith('assets/')) {
      content = Image.asset(
        avatar,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildAvatarInitials(userName, initialsFontSize),
      );
    } else if (hasAvatar && (avatar.startsWith('http://') || avatar.startsWith('https://'))) {
      content = Image.network(
        avatar,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildAvatarInitials(userName, initialsFontSize),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryRed),
              ),
            ),
          );
        },
      );
    } else {
      content = _buildAvatarInitials(userName, initialsFontSize);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withOpacity(0.85),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Center(child: content),
      ),
    );
  }

  Widget _buildAvatarInitials(String userName, double initialsFontSize) {
    return Text(
      _getInitials(userName),
      style: UnifiedTypography.displaySmall.copyWith(
        fontSize: initialsFontSize,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
        color: AppColors.primaryRed,
      ),
    );
  }

  Widget _buildHeaderQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withOpacity(0.35),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: UnifiedTypography.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatHandle(String username) {
    final u = username.trim();
    if (u.isEmpty) return '@user';
    return u.startsWith('@') ? u : '@$u';
  }

  Widget _buildConnectionPill({required bool isConnected}) {
    final statusColor = isConnected ? AppColors.success : AppColors.warning;
    final statusText = isConnected ? 'Connected' : 'Not connected';

    return Semantics(
      label: 'Connection status: $statusText',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Colors.white.withOpacity(0.35),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(0.55),
                    blurRadius: 8,
                    spreadRadius: 1.5,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              statusText,
              style: UnifiedTypography.bodySmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _composeAddressShort(UserModel? userModel) {
    if (userModel == null) return '';
    final parts = <String>[
      userModel.street.trim(),
      userModel.city.trim(),
      userModel.province.trim(),
    ].where((p) => p.isNotEmpty).toList();
    return parts.join(', ');
  }

  String _composeFullAddress(UserModel? userModel) {
    if (userModel == null) return '';
    final parts = <String>[
      userModel.street.trim(),
      userModel.barangay.trim(),
      userModel.city.trim(),
      userModel.province.trim(),
      userModel.region.trim(),
    ].where((p) => p.isNotEmpty).toList();
    return parts.join(', ');
  }

  Widget _buildProfileCompletionCard() {
    if (_isLoadingProfile) {
      return const SizedBox.shrink();
    }

    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        final userModel = auth.currentUserModel;
        final name = (userModel?.name ?? auth.userName ?? '').trim();
        final username = (userModel?.username ?? auth.userUsername ?? '').trim();

        final fields = <String, bool>{
          'Name': name.isNotEmpty,
          'Username': username.isNotEmpty,
          'Street': (userModel?.street ?? '').trim().isNotEmpty,
          'Barangay': (userModel?.barangay ?? '').trim().isNotEmpty,
          'City': (userModel?.city ?? '').trim().isNotEmpty,
          'Province': (userModel?.province ?? '').trim().isNotEmpty,
        };

        final total = fields.length;
        final completed = fields.values.where((v) => v).length;
        final missing = fields.entries.where((e) => !e.value).map((e) => e.key).toList();

        if (missing.isEmpty) {
          return const SizedBox.shrink();
        }

        final progress = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
        final percent = (progress * 100).round();

        return AnimatedNeumorphicCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primaryRed.withOpacity(0.18),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.fact_check_outlined,
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
                            'Complete your profile',
                            style: UnifiedTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: ThemeColors.textPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Improve emergency response accuracy by adding missing details.',
                            style: UnifiedTypography.bodySmall.copyWith(
                              color: ThemeColors.textSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$percent%',
                      style: UnifiedTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        color: ThemeColors.textPrimary(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: ThemeColors.border(context).withOpacity(0.5),
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryRed),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final label in missing.take(3)) _buildMissingFieldChip(label),
                    if (missing.length > 3)
                      _buildMissingFieldChip('+${missing.length - 3} more'),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _editProfile(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      foregroundColor: AppColors.primaryRed,
                      textStyle: UnifiedTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: const Text('Update now'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMissingFieldChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryRed.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.primaryRed.withOpacity(0.18),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: UnifiedTypography.bodySmall.copyWith(
          color: AppColors.primaryRed,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _refreshProfile() async {
    HapticFeedback.lightImpact();

    try {
      final auth = context.read<AuthProvider>();
      final chat = context.read<ChatProvider>();

      await Future.wait([
        auth.loadUserModel(),
        chat.loadMessages(forceRefresh: true),
      ]);
    } catch (_) {
      // Best-effort refresh; avoid surfacing errors for pull-to-refresh.
    }

    if (mounted) {
      setState(() {});
    }
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _statCardsStagger.buildAnimatedItem(
                      0,
                      _buildStatCard(
                        context,
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
                            context,
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
              const SizedBox(height: 16),
              _statCardsStagger.buildAnimatedItem(
                2,
                _buildUserStatusCard(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserStatusCard() {
    _statusFuture ??= UserStatusService.instance.getFormattedStatus();
    return FutureBuilder<Map<String, dynamic>?>(
      future: _statusFuture,
      builder: (context, snapshot) {
        final status = snapshot.data;
        if (status == null) {
          return const SizedBox.shrink();
        }
        final severityColor = status['severity_color'] as Color;
        final typeColor = status['type_color'] as Color? ?? severityColor;
        final severityLabel = status['severity_label'] as String;
        final emergencyLabel = status['emergency_type_label'] as String;
        final lastUpdated = status['last_updated_formatted'] as String? ?? '—';
        final emergencyType = status['emergency_type'] as EmergencyType?;
        final statusIcon = emergencyType?.icon ?? Icons.assignment_outlined;
        final isRealEmergency = emergencyType != null && emergencyType.isRealEmergency;
        return AnimatedNeumorphicCard(
          borderRadius: 18,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border(
                  left: BorderSide(
                    color: typeColor,
                    width: 4,
                  ),
                  bottom: isRealEmergency
                      ? BorderSide(
                          color: ThemeColors.error(context),
                          width: 2,
                        )
                      : BorderSide.none,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: typeColor.withOpacity(0.35),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: typeColor.withOpacity(0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        statusIcon,
                        size: 28,
                        color: typeColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Current Status',
                                style: UnifiedTypography.bodySmall.copyWith(
                                  color: ThemeColors.textTertiary(context),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (isRealEmergency) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: ThemeColors.error(context),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.warning_amber_rounded, size: 12, color: Colors.white),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Emergency',
                                        style: UnifiedTypography.labelSmall.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$emergencyLabel · $severityLabel',
                            style: UnifiedTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                              color: typeColor,
                              fontSize: 16,
                              letterSpacing: 0.2,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 14,
                                color: ThemeColors.textTertiary(context),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  lastUpdated,
                                  style: UnifiedTypography.bodySmall.copyWith(
                                    color: ThemeColors.textTertiary(context),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
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
                  ],
                ),
              ),
            ),
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

        // Empty state: no activity yet (avoid showing "all zeros" analytics)
        if (!_isLoadingProfile && messages.isEmpty) {
          return AnimatedNeumorphicCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.info.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.info.withOpacity(0.22),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.insights_outlined,
                          color: AppColors.info,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No activity yet',
                              style: UnifiedTypography.titleLarge.copyWith(
                                fontWeight: FontWeight.bold,
                                color: ThemeColors.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              connectionsCount <= 1
                                  ? 'Connect and send messages to start generating engagement insights.'
                                  : 'Start messaging to generate engagement insights.',
                              style: UnifiedTypography.bodySmall.copyWith(
                                color: ThemeColors.textSecondary(context),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tip: Open the “Local Chat” tab to start messaging.'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.info,
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        foregroundColor: AppColors.primaryRed,
                        textStyle: UnifiedTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('How do I start?'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
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

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 140),
      decoration: BoxDecoration(
        color: ThemeColors.surfaceContainer(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ThemeColors.border(context).withOpacity(0.6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: ThemeColors.shadow(context, opacity: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: color.withOpacity(0.08),
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
                      color: ThemeColors.textPrimary(context),
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
                      color: ThemeColors.textSecondary(context),
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
          title: 'App',
          items: [
            _buildSettingsItem(
              icon: Icons.home_work_outlined,
              title: 'Start screen',
              subtitle: 'Which tab to open when app launches',
              onTap: () => _showStartScreenPreference(context),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSettingsSection(
          title: 'Support',
          items: [
            _buildSettingsItem(
              icon: Icons.palette,
              title: 'Appearance',
              subtitle: 'Theme and display settings',
              onTap: () => _showThemeSelectionModal(context),
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
                color: ThemeColors.textPrimary(context),
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
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
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: UnifiedTypography.bodyLarge.copyWith(
                          color: ThemeColors.textPrimary(context),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: UnifiedTypography.bodySmall.copyWith(
                          color: ThemeColors.textSecondary(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  color: ThemeColors.textSecondary(context).withOpacity(0.9),
                  size: 16,
                ),
              ],
            ),
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
              context: context,
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
                      Text(
                        'Sign Out',
                        style: TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.logout,
                        color: AppColors.white,
                        size: 20,
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
      if (authProvider.userUsername != null) {
        await authProvider.loadUserModel();
        // Force UI rebuild
        setState(() {});
      }
    }
  }

  void _openSecurity(BuildContext context) {
    HapticFeedback.lightImpact();
    final auth = context.read<AuthProvider>();

    // Google SSO has been removed - all users use username/password authentication

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
      backgroundColor: ThemeColors.surface(context),
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
                          Icons.security,
                          color: ThemeColors.primary(context),
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Security',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: ThemeColors.textPrimary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Current Password
                    Container(
                        decoration: SoftUIDesign.cardDecoration(
                          context: context,
                          backgroundColor: ThemeColors.surfaceContainer(context),
                          borderRadius: SoftUIDesign.inputBorderRadius,
                          elevation: 2.0,
                          borderColor: ThemeColors.border(context),
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

                    // New Password
                    Container(
                      decoration: SoftUIDesign.cardDecoration(
                        context: context,
                        backgroundColor: ThemeColors.surfaceContainer(context),
                        borderRadius: SoftUIDesign.inputBorderRadius,
                        elevation: 2.0,
                        borderColor: ThemeColors.border(context),
                        showBorder: true,
                      ),
                      child: TextField(
                      controller: newCtrl,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        hintText: 'Enter your new password',
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
                      decoration: SoftUIDesign.cardDecoration(
                        context: context,
                        backgroundColor: ThemeColors.surfaceContainer(context),
                        borderRadius: SoftUIDesign.inputBorderRadius,
                        elevation: 2.0,
                        borderColor: ThemeColors.border(context),
                        showBorder: true,
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

                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          decoration: SoftUIDesign.cardDecoration(
                            context: context,
                            backgroundColor: ThemeColors.surfaceContainer(context),
                            borderRadius: SoftUIDesign.inputBorderRadius,
                            elevation: 2.0,
                            borderColor: ThemeColors.border(context),
                            showBorder: true,
                          ),
                          child: TextButton(
                          onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: ThemeColors.textSecondary(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: ThemeColors.primary(context),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: ThemeColors.primary(context).withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(3, 3),
                              ),
                              BoxShadow(
                                color: ThemeColors.surface(context).withOpacity(0.3),
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

  Future<void> _showStartScreenPreference(BuildContext context) async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString(StorageKeys.prefStartTab) ?? 'last';
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: ThemeColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Start screen',
                style: UnifiedTypography.titleLarge.copyWith(
                  color: ThemeColors.textPrimary(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Which tab to show when the app opens.',
                style: UnifiedTypography.bodySmall.copyWith(
                  color: ThemeColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 16),
              _startOption(sheetContext, 'last', 'Last used', 'Open where you left off', current, prefs),
              _startOption(sheetContext, 'home', 'Home', 'Always open on Home', current, prefs),
              _startOption(sheetContext, 'emergency', 'Emergency', 'Always open on Emergency', current, prefs),
            ],
          ),
        );
      },
    );
  }

  Widget _startOption(BuildContext context, String value, String title, String subtitle, String current, SharedPreferences prefs) {
    final isSelected = current == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await prefs.setString(StorageKeys.prefStartTab, value);
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Preference saved'), duration: Duration(seconds: 2), behavior: SnackBarBehavior.floating),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          child: Row(
            children: [
              Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: isSelected ? AppColors.primary : ThemeColors.textTertiary(context), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: UnifiedTypography.bodyLarge.copyWith(color: ThemeColors.textPrimary(context), fontWeight: FontWeight.w600)),
                    Text(subtitle, style: UnifiedTypography.bodySmall.copyWith(color: ThemeColors.textSecondary(context))),
                  ],
                ),
              ),
            ],
          ),
        ),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    'Emergency Messages',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ThemeColors.textPrimary(context),
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
                                context: context,
                                backgroundColor: isDefault ? AppColors.primaryRed.withOpacity(0.06) : ThemeColors.surface(context),
                                borderRadius: SoftUIDesign.buttonBorderRadius,
                                elevation: isDefault ? 3.0 : 2.0,
                                borderColor: isDefault ? AppColors.primaryRed.withOpacity(0.4) : ThemeColors.border(context),
                                showBorder: true,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      messages[index],
                                      style: TextStyle(color: ThemeColors.textPrimary(context), fontSize: 14, height: 1.3),
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
                                          backgroundColor: ThemeColors.surface(context),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(SoftUIDesign.cardBorderRadius),
                                          ),
                                          title: const Text('Edit Message'),
                                          content: TextField(
                                            controller: editController,
                                            maxLines: 4,
                                            decoration: SoftUIDesign.inputDecoration(
                                              context: context,
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Text('No saved messages yet. Add one below.', style: TextStyle(color: ThemeColors.textSecondary(context))),
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
                      fillColor: ThemeColors.surfaceContainer(context),
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
      backgroundColor: ThemeColors.surface(rootContext),
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
                Text(
                  'Sign out of T.U.L.O.N.G?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: ThemeColors.textPrimary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'You\'ll be returned to the login screen. Your offline data remains saved on this device.',
                    style: TextStyle(color: ThemeColors.textSecondary(context), height: 1.3),
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
                          foregroundColor: ThemeColors.textPrimary(rootContext),
                          side: BorderSide(color: ThemeColors.border(rootContext).withOpacity(0.8), width: 1.4),
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 38),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
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
                  color: Colors.white.withOpacity(0.8),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Header-only CTA styled like the clickable contact info rows
  Widget _buildHeaderCallToAction(
    BuildContext context, {
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 38),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
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
                  Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(0.85),
                  size: 14,
                ),
              ],
            ),
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
  // ignore: unused_element
  Future<void> _openEmailApp(BuildContext context, String email) async {
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
  // ignore: unused_element
  Future<void> _makePhoneCall(BuildContext context, String phone) async {
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
      final query = Uri.encodeComponent(location);
      final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');

      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) {
          HapticFeedback.lightImpact();
          return;
        }
      }

      // Fallback: copy to clipboard (still useful offline or on restricted platforms)
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

  // Theme Selection Modal (Appearance) - wired to ThemeProvider
  void _showThemeSelectionModal(BuildContext context) {
    final themeProvider = context.read<ThemeProvider>();
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Dialog(
        backgroundColor: ThemeColors.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.palette,
                  color: AppColors.primaryRed,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Appearance',
                style: UnifiedTypography.titleLarge.copyWith(
                  color: ThemeColors.textPrimary(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how the app looks.',
                style: UnifiedTypography.bodyMedium.copyWith(
                  color: ThemeColors.textSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _themeOption(dialogContext, themeProvider, AppThemeMode.light, Icons.light_mode, 'Light'),
              _themeOption(dialogContext, themeProvider, AppThemeMode.dark, Icons.dark_mode, 'Dark'),
              _themeOption(dialogContext, themeProvider, AppThemeMode.darkAmoled, Icons.brightness_2, 'AMOLED Black'),
              _themeOption(dialogContext, themeProvider, AppThemeMode.system, Icons.phone_android, 'System'),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'Close',
                  style: TextStyle(color: ThemeColors.textSecondary(context)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeOption(BuildContext context, ThemeProvider themeProvider, AppThemeMode mode, IconData icon, String label) {
    final isSelected = themeProvider.themeMode == mode;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppColors.primaryRed : ThemeColors.textSecondary(context),
        size: 24,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: ThemeColors.textPrimary(context),
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primaryRed, size: 22) : null,
      onTap: () async {
        await themeProvider.setThemeMode(mode);
        if (context.mounted) Navigator.pop(context);
      },
    );
  }

  // About Modal
  void _showAboutModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: ThemeColors.surface(context),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: ThemeColors.shadow(context, opacity: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
                spreadRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with Gradient
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        ThemeColors.primary(context).withOpacity(0.08),
                        ThemeColors.primary(context).withOpacity(0.03),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ThemeColors.primary(context).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: ThemeColors.primary(context).withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          Icons.info_outline_rounded,
                          color: ThemeColors.primary(context),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'About',
                          style: UnifiedTypography.titleLarge.copyWith(
                            color: ThemeColors.textPrimary(context),
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            fontSize: 22,
                          ),
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.close_rounded,
                              color: ThemeColors.textSecondary(context),
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Content - Made scrollable to prevent overflow
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.7,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // App Logo with Enhanced Styling
                        Container(
                          width: 120,
                          height: 120,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: ThemeColors.surfaceContainer(context),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: ThemeColors.primary(context).withOpacity(0.25),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: ThemeColors.shadow(context, opacity: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: ThemeColors.primary(context).withOpacity(0.15),
                              width: 1.5,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              'assets/images/app_logo (3).png',
                              fit: BoxFit.contain,
                              width: 104,
                              height: 104,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        ThemeColors.primary(context),
                                        ThemeColors.primary(context).withOpacity(0.8),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    Icons.emergency_rounded,
                                    color: Colors.white,
                                    size: 50,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // App Name
                        Text(
                          'T.U.L.O.N.G',
                          style: UnifiedTypography.headlineSmall.copyWith(
                            color: ThemeColors.textPrimary(context),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            fontSize: 26,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // Full Name
                        Text(
                          'Transmission Unit for Local\nOffline Network Generation',
                          textAlign: TextAlign.center,
                          style: UnifiedTypography.bodyMedium.copyWith(
                            color: ThemeColors.textSecondary(context),
                            height: 1.4,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 28),
                        
                        // Version Info Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: ThemeColors.surfaceContainer(context),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: ThemeColors.border(context),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              _buildAboutRow(context, 'Version', '1.0.0'),
                              const SizedBox(height: 20),
                              Container(
                                height: 1,
                                color: ThemeColors.divider(context),
                              ),
                              const SizedBox(height: 20),
                              _buildAboutRow(context, 'Build', 'Release'),
                              const SizedBox(height: 20),
                              Container(
                                height: 1,
                                color: ThemeColors.divider(context),
                              ),
                              const SizedBox(height: 20),
                              _buildAboutRow(context, 'Platform', 'Android'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        
                        // Description
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: ThemeColors.primary(context).withOpacity(0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: ThemeColors.primary(context).withOpacity(0.15),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'A disaster-ready communication system for emergency situations. Connect with nearby users through mesh networking when traditional communication fails.',
                            textAlign: TextAlign.center,
                            style: UnifiedTypography.bodySmall.copyWith(
                              color: ThemeColors.textSecondary(context),
                              height: 1.6,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        
                        // Close Button
                        SizedBox(
                          width: double.infinity,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  ThemeColors.primary(context),
                                  ThemeColors.primary(context).withOpacity(0.85),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: ThemeColors.primary(context).withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.pop(context);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: Text(
                                      'Close',
                                      style: UnifiedTypography.bodyLarge.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
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
  }

  Widget _buildAboutRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: UnifiedTypography.bodyMedium.copyWith(
            color: ThemeColors.textSecondary(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: UnifiedTypography.bodyMedium.copyWith(
            color: ThemeColors.textPrimary(context),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
