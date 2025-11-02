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
  final VoidCallback? onSubtitleTap; // NEW: callback for subtitle tap
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final bool compact; // NEW: compact variant
  final List<Widget>? statusBadges; // NEW: optional status badges

  const UnifiedTopBar({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.iconColor = AppColors.primary,
    this.backgroundColor = AppColors.white,
    this.actions,
    this.onIconTap,
    this.onSubtitleTap,
    this.showBackButton = false,
    this.onBackPressed,
    this.compact = false,
    this.statusBadges,
  });

  @override
  Widget build(BuildContext context) {
    final double containerHeight = compact ? 64 : 88;
    final EdgeInsetsGeometry containerPadding = compact
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
        : const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    final double iconBoxSize = compact ? 40 : 52;
    final double iconSize = compact ? 20 : 26;
    final double titleFontSize = compact ? 16 : 20;

    return PolishedFadeIn(
      delay: const Duration(milliseconds: 100),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            height: containerHeight,
            padding: containerPadding,
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
                if (showBackButton) ...[
                  PolishedBounce(
                    onTap: onBackPressed ?? () => Navigator.of(context).pop(),
                    child: Container(
                      width: iconBoxSize,
                      height: iconBoxSize,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.lightGray.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        color: AppColors.primary,
                        size: compact ? 18 : 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],

                // Main icon
                PolishedBounce(
                  onTap: onIconTap,
                  child: Container(
                    width: iconBoxSize,
                    height: iconBoxSize,
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
                      size: iconSize,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Title, subtitle, and badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              overflow: TextOverflow.ellipsis,
                              style: UnifiedTypography.appBarTitle.copyWith(
                                color: AppColors.textPrimary,
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if ((subtitle != null && subtitle!.isNotEmpty) || (statusBadges != null && statusBadges!.isNotEmpty)) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (subtitle != null && subtitle!.isNotEmpty)
                              PolishedBounce(
                                onTap: onSubtitleTap,
                                child: Container(
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
                              ),
                            if (subtitle != null && subtitle!.isNotEmpty && statusBadges != null && statusBadges!.isNotEmpty)
                              const SizedBox(width: 6),
                            if (statusBadges != null && statusBadges!.isNotEmpty)
                              Flexible(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      ...statusBadges!.expand((w) => [w, const SizedBox(width: 6)]).toList()..removeLast(),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                if (actions != null) ...[
                  const SizedBox(width: 12),
                  ...actions!,
                ],
              ],
            ),
          ),
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
    VoidCallback? onSubtitleTap,
    List<Widget>? additionalActions,
    bool compact = false,
    List<Widget>? badges,
  }) {
    return UnifiedTopBar(
      title: 'Local Chat',
      subtitle: status,
      icon: Icons.bluetooth,
      iconColor: status.toLowerCase().contains('connected')
          ? AppColors.success
          : AppColors.warning,
      onIconTap: onBluetoothTap,
      onSubtitleTap: onSubtitleTap,
      actions: additionalActions,
      compact: compact,
      statusBadges: badges,
    );
  }

  static Widget callsTopBar({
    String? status,
    required VoidCallback onRefresh,
    required VoidCallback onSettings,
    List<Widget>? additionalActions,
    bool compact = false,
    List<Widget>? badges,
  }) {
    return UnifiedTopBar(
      title: 'Calls',
      subtitle: status,
      icon: Icons.radio,
      iconColor: AppColors.warning,
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
      compact: compact,
      statusBadges: badges,
    );
  }

  static Widget profileTopBar({
    VoidCallback? onEdit,
    List<Widget>? additionalActions,
    bool compact = false,
    List<Widget>? badges,
  }) {
    return UnifiedTopBar(
      title: 'Profile',
      icon: Icons.person,
      iconColor: AppColors.info,
      actions: additionalActions,
      compact: compact,
      statusBadges: badges,
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
