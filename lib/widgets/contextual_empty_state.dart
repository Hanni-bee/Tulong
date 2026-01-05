import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../constants/app_colors.dart';
import '../utils/haptic_helper.dart';

/// Enhanced empty state with contextual actions and helpful guidance
class ContextualEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final String? helpText;
  final String? animationAsset;
  final IconData? icon;
  final List<EmptyStateAction> actions;
  final Color? iconColor;

  const ContextualEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.helpText,
    this.animationAsset,
    this.icon,
    this.actions = const [],
    this.iconColor,
  });

  /// Empty state for no messages
  factory ContextualEmptyState.noMessages({
    required VoidCallback onSendMessage,
  }) {
    return ContextualEmptyState(
      title: 'No Messages Yet',
      message: 'Start a conversation to connect with others',
      helpText: 'Messages you send will be saved locally and synced when you\'re online',
      icon: Icons.chat_bubble_outline,
      iconColor: AppColors.info,
      actions: [
        EmptyStateAction(
          label: 'Send First Message',
          icon: Icons.send,
          onPressed: onSendMessage,
          isPrimary: true,
        ),
      ],
    );
  }

  /// Empty state for no users connected
  factory ContextualEmptyState.noUsersConnected({
    required VoidCallback onScan,
    VoidCallback? onHelp,
  }) {
    return ContextualEmptyState(
      title: 'No Users Connected',
      message: 'Connect with nearby users via Bluetooth',
      helpText: 'Make sure Bluetooth is turned on and other devices are in range',
      icon: Icons.people_outline,
      iconColor: AppColors.online,
      actions: [
        EmptyStateAction(
          label: 'Scan for Users',
          icon: Icons.bluetooth_searching,
          onPressed: onScan,
          isPrimary: true,
        ),
        if (onHelp != null)
          EmptyStateAction(
            label: 'Help',
            icon: Icons.help_outline,
            onPressed: onHelp,
            isPrimary: false,
          ),
      ],
    );
  }

  /// Empty state for no conversations
  factory ContextualEmptyState.noConversations({
    required VoidCallback onFindUsers,
  }) {
    return ContextualEmptyState(
      title: 'No Conversations',
      message: 'Start chatting with nearby users',
      helpText: 'Find users in your area to begin a conversation',
      icon: Icons.forum_outlined,
      iconColor: AppColors.primaryRed,
      actions: [
        EmptyStateAction(
          label: 'Find Users',
          icon: Icons.search,
          onPressed: onFindUsers,
          isPrimary: true,
        ),
      ],
    );
  }

  /// Empty state for no search results
  factory ContextualEmptyState.noSearchResults({
    required String searchQuery,
    required VoidCallback onClearSearch,
    List<String>? suggestions,
  }) {
    return ContextualEmptyState(
      title: 'No Results Found',
      message: 'No results for "$searchQuery"',
      helpText: suggestions != null && suggestions.isNotEmpty
          ? 'Try: ${suggestions.take(3).join(", ")}'
          : 'Try different keywords or check your spelling',
      icon: Icons.search_off,
      iconColor: AppColors.mediumGray,
      actions: [
        EmptyStateAction(
          label: 'Clear Search',
          icon: Icons.clear,
          onPressed: onClearSearch,
          isPrimary: true,
        ),
      ],
    );
  }

  /// Empty state for no emergency alerts
  factory ContextualEmptyState.noEmergencies({
    String? customMessage,
  }) {
    return ContextualEmptyState(
      title: 'All Clear',
      message: customMessage ?? 'No emergency alerts in your area',
      helpText: 'Stay safe and prepared. Emergency alerts will appear here',
      icon: Icons.check_circle_outline,
      iconColor: AppColors.online,
      actions: const [],
    );
  }

  /// Empty state for no connection
  factory ContextualEmptyState.noConnection({
    required VoidCallback onRetry,
  }) {
    return ContextualEmptyState(
      title: 'No Connection',
      message: 'You\'re currently offline',
      helpText: 'Don\'t worry - the app works offline! Your changes will sync when you\'re back online',
      icon: Icons.cloud_off,
      iconColor: AppColors.warning,
      actions: [
        EmptyStateAction(
          label: 'Try Again',
          icon: Icons.refresh,
          onPressed: onRetry,
          isPrimary: true,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animation or Icon
            if (animationAsset != null)
              SizedBox(
                height: 200,
                width: 200,
                child: Lottie.asset(
                  animationAsset!,
                  fit: BoxFit.contain,
                ),
              )
            else if (icon != null)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: (iconColor ?? AppColors.primaryRed).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 64,
                  color: iconColor ?? AppColors.primaryRed,
                ),
              ),

            const SizedBox(height: 24),

            // Title
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 12),

            // Message
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),

            // Help Text
            if (helpText != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.info.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        helpText!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.info,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Actions
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 24),
              ...actions.map((action) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: SizedBox(
                      width: double.infinity,
                      child: action.isPrimary
                          ? ElevatedButton.icon(
                              onPressed: () {
                                HapticHelper.light();
                                action.onPressed();
                              },
                              icon: Icon(action.icon),
                              label: Text(action.label),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryRed,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 24,
                                ),
                              ),
                            )
                          : OutlinedButton.icon(
                              onPressed: () {
                                HapticHelper.light();
                                action.onPressed();
                              },
                              icon: Icon(action.icon),
                              label: Text(action.label),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 24,
                                ),
                              ),
                            ),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

/// Action button for empty state
class EmptyStateAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isPrimary;

  const EmptyStateAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
  });
}

