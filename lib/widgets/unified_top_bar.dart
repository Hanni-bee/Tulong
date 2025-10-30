import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/unified_typography.dart';
import 'polished_animations.dart';

/// Unified top bar component for consistent design across LoRa, Calls, and Profile screens
/// Matches the app's neumorphic design system and typography
class UnifiedTopBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final List<Widget>? actions;
  final VoidCallback? onIconTap;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const UnifiedTopBar({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.iconColor = AppColors.primary,
    this.backgroundColor = AppColors.white,
    this.actions,
    this.onIconTap,
    this.showBackButton = false,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return PolishedFadeIn(
      delay: const Duration(milliseconds: 100),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            height: 88,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.lightGray.withOpacity(0.15),
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000), // subtle shadow (6% black)
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
          children: [
            // Enhanced back button (if needed)
            if (showBackButton) ...[
              PolishedBounce(
                onTap: onBackPressed ?? () => Navigator.of(context).pop(),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.lightGray.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 18),
            ],

            // Enhanced main icon with premium styling
            PolishedBounce(
              onTap: onIconTap,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: iconColor.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 26,
                ),
              ),
            ),
            
            const SizedBox(width: 20),
            
            // Enhanced title and subtitle with better typography
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: UnifiedTypography.appBarTitle.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: subtitle!.toLowerCase().contains('connected') 
                            ? AppColors.success.withOpacity(0.1)
                            : AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: subtitle!.toLowerCase().contains('connected') 
                              ? AppColors.success.withOpacity(0.3)
                              : AppColors.warning.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        subtitle!,
                        style: UnifiedTypography.appBarSubtitle.copyWith(
                          color: subtitle!.toLowerCase().contains('connected') 
                              ? AppColors.success
                              : AppColors.warning,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Enhanced actions with better spacing
            if (actions != null) ...[
              const SizedBox(width: 16),
              ...actions!,
            ],
          ],
            ),
          ),
          // Unified solid accent line below top bar
          Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: AppColors.primaryRed,
          ),
        ],
      ),
    );
  }
}

/// Predefined top bar configurations for different screens
/// Each configuration is tailored to match the app's design system
class TopBarConfigs {
  static Widget loraTopBar({
    required String status,
    required VoidCallback onBluetoothTap,
    List<Widget>? additionalActions,
  }) {
    return UnifiedTopBar(
      title: 'Local Chat',
      subtitle: status,
      icon: Icons.bluetooth,
      iconColor: status.toLowerCase().contains('connected') 
          ? AppColors.success 
          : AppColors.warning,
      onIconTap: onBluetoothTap,
      actions: additionalActions,
    );
  }

  static Widget callsTopBar({
    String? status,
    required VoidCallback onRefresh,
    required VoidCallback onSettings,
    List<Widget>? additionalActions,
  }) {
    return UnifiedTopBar(
      title: 'Calls',
      subtitle: status,
      icon: Icons.radio,
      iconColor: AppColors.warning, // Using app's warning color instead of hardcoded
      actions: [
        _buildActionButton(
          icon: Icons.refresh,
          onPressed: onRefresh,
          color: AppColors.primary,
        ),
        const SizedBox(width: 12),
        _buildActionButton(
          icon: Icons.settings,
          onPressed: onSettings,
          color: AppColors.primary,
        ),
        if (additionalActions != null) ...additionalActions,
      ],
    );
  }

  static Widget profileTopBar({
    VoidCallback? onEdit, // kept for backward compat, unused
    List<Widget>? additionalActions,
  }) {
    return UnifiedTopBar(
      title: 'Profile',
      icon: Icons.person,
      iconColor: AppColors.info,
      actions: additionalActions, // no edit action
    );
  }

  /// Enhanced helper method to create premium action buttons with animations
  static Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return PolishedBounce(
      onTap: onPressed,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          color: color,
          size: 22,
        ),
      ),
    );
  }
}
