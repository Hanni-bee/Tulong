import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../utils/theme_colors.dart';

/// Enhanced empty state widget with consistent design, animations, and actionable guidance
class EnhancedEmptyState extends StatefulWidget {
  /// Icon to display (or use iconWidget for custom widget)
  final IconData? icon;
  
  /// Custom icon widget (takes precedence over icon)
  final Widget? iconWidget;
  
  /// Main title text
  final String title;
  
  /// Descriptive message/guidance
  final String message;
  
  /// Optional helpful tip or additional context
  final String? tip;
  
  /// Action button label (if null, no button shown)
  final String? actionLabel;
  
  /// Action button callback
  final VoidCallback? onAction;
  
  /// Secondary action label (e.g., "Learn More")
  final String? secondaryActionLabel;
  
  /// Secondary action callback
  final VoidCallback? onSecondaryAction;
  
  /// Icon color (defaults to primaryRed)
  final Color? iconColor;
  
  /// Background color for icon container
  final Color? iconBackgroundColor;
  
  /// Whether to show illustration animation
  final bool animated;
  
  /// Custom illustration widget
  final Widget? illustration;

  const EnhancedEmptyState({
    super.key,
    this.icon,
    this.iconWidget,
    required this.title,
    required this.message,
    this.tip,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.iconColor,
    this.iconBackgroundColor,
    this.animated = true,
    this.illustration,
  }) : assert(icon != null || iconWidget != null || illustration != null,
         'Either icon, iconWidget, or illustration must be provided');

  @override
  State<EnhancedEmptyState> createState() => _EnhancedEmptyStateState();
}

class _EnhancedEmptyStateState extends State<EnhancedEmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _iconPulseAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));

    _iconPulseAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.1), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 1.1, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (widget.animated) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildIcon(BuildContext context) {
    final iconColor = widget.iconColor ?? AppColors.primaryRed;
    final isDark = ThemeColors.isDark(context);
    final iconBgColor = widget.iconBackgroundColor ??
        (isDark ? iconColor.withOpacity(0.12) : iconColor.withOpacity(0.08));

    if (widget.illustration != null) {
      return widget.illustration!;
    }

    Widget iconWidget;
    if (widget.iconWidget != null) {
      iconWidget = widget.iconWidget!;
    } else {
      iconWidget = Icon(
        widget.icon,
        size: 64,
        color: iconColor,
      );
    }

    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: iconBgColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(isDark ? 0.2 : 0.15),
            blurRadius: isDark ? 20 : 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          if (!isDark)
            BoxShadow(
              color: Colors.white.withOpacity(0.6),
              blurRadius: 12,
              offset: const Offset(0, -4),
              spreadRadius: 0,
            ),
        ],
      ),
      child: Center(child: iconWidget),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon/Illustration with animation
                if (widget.animated)
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Transform.scale(
                        scale: _iconPulseAnimation.value,
                        child: _buildIcon(context),
                      ),
                    ),
                  )
                else
                  _buildIcon(context),

                const SizedBox(height: 32),

                // Title and message with slide animation
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        Text(
                          widget.title,
                          style: AppTypography.headlineMedium.copyWith(
                            color: ThemeColors.textPrimary(context),
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.message,
                          style: AppTypography.bodyLarge.copyWith(
                            color: ThemeColors.textSecondary(context),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        // Optional tip
                        if (widget.tip != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: ThemeColors.surfaceContainer(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: ThemeColors.border(context),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  size: 18,
                                  color: AppColors.info,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    widget.tip!,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.info,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Action buttons
                if (widget.actionLabel != null && widget.onAction != null) ...[
                  const SizedBox(height: 32),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              widget.onAction!();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                              shadowColor: Colors.transparent,
                            ),
                            child: Text(
                              widget.actionLabel!,
                              style: AppTypography.buttonText.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        // Secondary action
                        if (widget.secondaryActionLabel != null &&
                            widget.onSecondaryAction != null) ...[
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              widget.onSecondaryAction!();
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            child: Text(
                              widget.secondaryActionLabel!,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.primaryRed,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Pre-configured empty states for common scenarios
class EmptyStatePresets {
  /// No messages in chat
  static EnhancedEmptyState noMessages({
    VoidCallback? onStartChatting,
    VoidCallback? onConnectDevice,
  }) {
    return EnhancedEmptyState(
      icon: Icons.chat_bubble_outline,
      title: 'No messages yet',
      message: 'Start a conversation to connect with others in your network.',
      tip: 'Connect to an ESP32 device to begin chatting',
      actionLabel: onStartChatting != null ? 'Start Chatting' : null,
      onAction: onStartChatting,
      secondaryActionLabel: onConnectDevice != null ? 'Connect Device' : null,
      onSecondaryAction: onConnectDevice,
      iconColor: AppColors.primaryRed,
    );
  }

  /// No users connected
  static EnhancedEmptyState noUsersConnected({
    VoidCallback? onRefresh,
    VoidCallback? onScanDevices,
  }) {
    return EnhancedEmptyState(
      icon: Icons.people_outline,
      title: 'No users connected',
      message: 'No other users are currently connected to the network. They will appear here once connected.',
      tip: 'Make sure your ESP32 device is powered on and in range',
      actionLabel: onRefresh != null ? 'Refresh' : null,
      onAction: onRefresh,
      secondaryActionLabel: onScanDevices != null ? 'Scan for Devices' : null,
      onSecondaryAction: onScanDevices,
      iconColor: AppColors.info,
    );
  }

  /// No conversations
  static EnhancedEmptyState noConversations({
    VoidCallback? onStartNewChat,
  }) {
    return EnhancedEmptyState(
      icon: Icons.message_outlined,
      title: 'No conversations',
      message: 'You haven\'t started any conversations yet. Start chatting with others in your network.',
      actionLabel: onStartNewChat != null ? 'Start New Chat' : null,
      onAction: onStartNewChat,
      iconColor: AppColors.primaryRed,
    );
  }

  /// No search results
  static EnhancedEmptyState noSearchResults({
    VoidCallback? onClearSearch,
    String? searchQuery,
  }) {
    return EnhancedEmptyState(
      icon: Icons.search_off,
      title: 'No results found',
      message: searchQuery != null && searchQuery.isNotEmpty
          ? 'No matches found for "$searchQuery". Try different keywords or filters.'
          : 'No matches found. Try adjusting your search or filters.',
      actionLabel: onClearSearch != null ? 'Clear Search' : null,
      onAction: onClearSearch,
      iconColor: AppColors.textSecondary,
    );
  }

  /// Missing profile data
  static EnhancedEmptyState missingProfileData({
    required String section,
    VoidCallback? onEdit,
  }) {
    return EnhancedEmptyState(
      icon: Icons.person_outline,
      title: '$section not set',
      message: 'Complete your profile by adding your $section information.',
      actionLabel: onEdit != null ? 'Edit Profile' : null,
      onAction: onEdit,
      iconColor: AppColors.warning,
    );
  }

  /// Not connected
  static EnhancedEmptyState notConnected({
    VoidCallback? onConnect,
  }) {
    return EnhancedEmptyState(
      icon: Icons.bluetooth_disabled,
      title: 'Not connected',
      message: 'Connect to an ESP32 device to access this feature.',
      tip: 'Make sure Bluetooth is enabled and the device is in range',
      actionLabel: onConnect != null ? 'Connect Device' : null,
      onAction: onConnect,
      iconColor: AppColors.textSecondary,
    );
  }
}

