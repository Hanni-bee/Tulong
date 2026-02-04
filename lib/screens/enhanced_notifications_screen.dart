import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notification_model.dart';
import '../providers/notification_provider.dart';
import '../widgets/enhanced_notification_card.dart';
import '../widgets/enhanced_empty_state.dart';
import '../utils/standardized_spacing.dart';
import '../widgets/accessible_text.dart';
import '../constants/app_colors.dart';
import '../utils/theme_colors.dart';
import '../utils/icon_system.dart';

/// Enhanced Notifications Screen
/// 
/// In-app notification center with grouping, filtering, and actions
class EnhancedNotificationsScreen extends StatefulWidget {
  const EnhancedNotificationsScreen({super.key});

  @override
  State<EnhancedNotificationsScreen> createState() => _EnhancedNotificationsScreenState();
}

class _EnhancedNotificationsScreenState extends State<EnhancedNotificationsScreen> {
  String _selectedFilter = 'All';
  bool _showGrouped = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.background(context),
      appBar: AppBar(
        title: const AccessibleHeading('Notifications', level: HeadingLevel.h4),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              if (provider.unreadCount > 0) {
                return TextButton(
                  onPressed: () => provider.markAllAsRead(),
                  child: const AccessibleBodyText(
                    'Mark all as read',
                    size: BodySize.medium,
                    color: AppColors.primaryRed,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(IconSystem.settings),
            onPressed: () {
              Navigator.pushNamed(context, '/notification-settings');
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          if (provider.notifications.isEmpty) {
            return EnhancedEmptyState(
              icon: Icons.notifications_none,
              title: 'No Notifications',
              message: 'You\'re all caught up! No new notifications.',
            );
          }

          return Column(
            children: [
              // Filter and Group Toggle
              _buildFilterBar(provider),
              
              // Notifications List
              Expanded(
                child: _showGrouped
                    ? _buildGroupedList(provider)
                    : _buildFlatList(provider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterBar(NotificationProvider provider) {
    return Container(
      padding: StandardizedSpacing.screenPadding(context),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', provider.notifications.length),
                  _buildFilterChip('Unread', provider.unreadCount),
                  _buildFilterChip('Emergency', provider.getBadgeCountForType(NotificationType.emergency)),
                  _buildFilterChip('Messages', provider.getBadgeCountForType(NotificationType.message)),
                  _buildFilterChip('System', provider.getBadgeCountForType(NotificationType.system)),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(_showGrouped ? Icons.view_list : Icons.view_module),
            onPressed: () {
              setState(() {
                _showGrouped = !_showGrouped;
              });
            },
            tooltip: _showGrouped ? 'Ungroup' : 'Group',
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AccessibleBodyText(
              label,
              size: BodySize.small,
              color: isSelected ? AppColors.white : AppColors.textPrimary,
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.white.withOpacity(0.3)
                      : AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: AccessibleBodyText(
                  count.toString(),
                  size: BodySize.small,
                  color: AppColors.white,
                ),
              ),
            ],
          ],
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = label;
          });
        },
        backgroundColor: ThemeColors.surface(context),
        selectedColor: AppColors.primaryRed,
        checkmarkColor: AppColors.white,
      ),
    );
  }

  Widget _buildGroupedList(NotificationProvider provider) {
    final groups = provider.getGroupedNotifications();
    final filteredGroups = _filterGroups(groups);

    if (filteredGroups.isEmpty) {
      return EmptyStatePresets.noSearchResults();
    }

    return ListView.builder(
      padding: StandardizedSpacing.screenPadding(context),
      itemCount: filteredGroups.length,
      itemBuilder: (context, index) {
        final group = filteredGroups[index];
        return _buildNotificationGroup(group, provider);
      },
    );
  }

  Widget _buildFlatList(NotificationProvider provider) {
    final notifications = _filterNotifications(provider.notifications);

    return ListView.builder(
      padding: StandardizedSpacing.screenPadding(context),
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return EnhancedNotificationCard(
          notification: notification,
          onTap: () {
            provider.markAsRead(notification.id);
          },
          onDismiss: () {
            provider.deleteNotification(notification.id);
          },
        );
      },
    );
  }

  Widget _buildNotificationGroup(NotificationGroup group, NotificationProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              AccessibleHeading(
                group.title,
                level: HeadingLevel.h5,
                color: ThemeColors.textPrimary(context),
              ),
              const SizedBox(width: 8),
              if (group.hasUnread)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: AccessibleBodyText(
                    group.unreadCount.toString(),
                    size: BodySize.small,
                    color: AppColors.white,
                  ),
                ),
            ],
          ),
        ),
        ...group.notifications.map((notification) {
          return EnhancedNotificationCard(
            notification: notification,
            isGrouped: true,
            onTap: () {
              provider.markAsRead(notification.id);
            },
            onDismiss: () {
              provider.deleteNotification(notification.id);
            },
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  List<NotificationGroup> _filterGroups(List<NotificationGroup> groups) {
    if (_selectedFilter == 'All') {
      return groups;
    }

    return groups.where((group) {
      switch (_selectedFilter) {
        case 'Unread':
          return group.hasUnread;
        case 'Emergency':
          return group.key == 'emergency';
        case 'Messages':
          return group.key == 'message';
        case 'System':
          return group.key == 'system';
        default:
          return true;
      }
    }).toList();
  }

  List<AppNotification> _filterNotifications(List<AppNotification> notifications) {
    switch (_selectedFilter) {
      case 'Unread':
        return notifications.where((n) => !n.isRead).toList();
      case 'Emergency':
        return notifications.where((n) => n.type == NotificationType.emergency).toList();
      case 'Messages':
        return notifications.where((n) => n.type == NotificationType.message).toList();
      case 'System':
        return notifications.where((n) => n.type == NotificationType.system).toList();
      default:
        return notifications;
    }
  }
}

