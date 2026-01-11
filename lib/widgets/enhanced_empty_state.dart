import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

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

  /// Padding around the empty state content (lets screens adapt layout for keyboard/nav).
  final EdgeInsetsGeometry padding;

  /// If false, the empty state will not be scrollable (better for chat idle state).
  /// When true, it uses a scroll view to avoid overflow on small screens / keyboard up.
  final bool scrollable;

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
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
    this.scrollable = true,
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

  Widget _buildIcon() {
    final iconColor = widget.iconColor ?? AppColors.primaryRed;
    final iconBgColor = widget.iconBackgroundColor ?? iconColor.withOpacity(0.08);

    if (widget.illustration != null) {
      return widget.illustration!;
    }

    Widget iconWidget;
    if (widget.iconWidget != null) {
      iconWidget = widget.iconWidget!;
    } else {
      // Reduce icon size when not scrollable to save space
      final iconSize = widget.scrollable ? 64.0 : 56.0;
      iconWidget = Icon(
        widget.icon,
        size: iconSize,
        color: iconColor,
      );
    }

    // Reduce container size when not scrollable to save space
    final containerSize = widget.scrollable ? 140.0 : 120.0;
    
    return Container(
      width: containerSize,
      height: containerSize,
      decoration: BoxDecoration(
        color: iconBgColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
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
        final content = Padding(
          padding: widget.padding,
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
                        child: _buildIcon(),
                      ),
                    ),
                  )
                else
                  _buildIcon(),

                SizedBox(height: widget.scrollable ? 32 : 24), // Reduced spacing when not scrollable

                // Title and message with slide animation
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: AppTypography.headlineMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: widget.scrollable ? 12 : 8), // Reduced spacing when not scrollable
                        Text(
                          widget.message,
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        // Optional tip
                        if (widget.tip != null) ...[
                          SizedBox(height: widget.scrollable ? 16 : 12), // Reduced spacing when not scrollable
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.info.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.info.withOpacity(0.2),
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
                  SizedBox(height: widget.scrollable ? 32 : 24), // Reduced spacing when not scrollable
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
        );

        if (widget.scrollable) {
          return Center(
            child: SingleChildScrollView(child: content),
          );
        }

        // Non-scrollable: keep centered without allowing drag/scroll bounce.
        // Use LayoutBuilder to get available height and constrain content
        return LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 520,
                  maxHeight: constraints.maxHeight * 0.8, // Limit to 80% of available height
                ),
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(), // Prevent scrolling but allow overflow handling
                  child: content,
                ),
              ),
            );
          },
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
    EdgeInsetsGeometry? padding,
    bool scrollable = true,
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
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      scrollable: scrollable,
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

