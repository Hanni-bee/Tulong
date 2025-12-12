import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../constants/app_colors.dart';
import '../utils/icon_system.dart';
import '../utils/color_system.dart';
import '../widgets/accessible_text.dart';

/// Enhanced Notification Card
/// 
/// Displays a notification with rich content, actions, and grouping support
class EnhancedNotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final bool showActions;
  final bool isGrouped;

  const EnhancedNotificationCard({
    super.key,
    required this.notification,
    this.onTap,
    this.onDismiss,
    this.showActions = true,
    this.isGrouped = false,
  });

  Color get _typeColor {
    switch (notification.type) {
      case NotificationType.emergency:
        return ColorSystem.getSemanticColor(SemanticColorType.error).background;
      case NotificationType.error:
        return ColorSystem.getSemanticColor(SemanticColorType.error).background;
      case NotificationType.warning:
        return ColorSystem.getSemanticColor(SemanticColorType.warning).background;
      case NotificationType.success:
        return ColorSystem.getSemanticColor(SemanticColorType.success).background;
      case NotificationType.message:
        return ColorSystem.getStatusColor(StatusType.connected).color;
      default:
        return ColorSystem.getSemanticColor(SemanticColorType.info).background;
    }
  }

  IconData get _typeIcon {
    switch (notification.type) {
      case NotificationType.emergency:
        return IconSystem.actionSOS;
      case NotificationType.error:
        return IconSystem.error;
      case NotificationType.warning:
        return IconSystem.warning;
      case NotificationType.success:
        return IconSystem.success;
      case NotificationType.message:
        return IconSystem.message;
      case NotificationType.reminder:
        return IconSystem.time;
      case NotificationType.system:
        return IconSystem.info;
      default:
        return IconSystem.info;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: isGrouped ? 8 : 12),
      child: Material(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: notification.isRead
                    ? AppColors.lightGray
                    : _typeColor.withOpacity(0.5),
                width: notification.isRead ? 1 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Notification icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _typeIcon,
                        color: _typeColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Notification content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: AccessibleHeading(
                                  notification.title,
                                  level: HeadingLevel.h6,
                                  color: notification.isRead
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                                ),
                              ),
                              if (!notification.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _typeColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          AccessibleBodyText(
                            notification.body,
                            size: BodySize.medium,
                            color: AppColors.textSecondary,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              AccessibleBodyText(
                                _formatTimestamp(notification.timestamp),
                                size: BodySize.small,
                                color: AppColors.textSecondary,
                              ),
                              const Spacer(),
                              if (onDismiss != null)
                                GestureDetector(
                                  onTap: onDismiss,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppColors.lightGray,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Icon(
                                      IconSystem.close,
                                      size: 14,
                                      color: AppColors.mediumGray,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Notification image (if available)
                if (notification.imageUrl != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      notification.imageUrl!,
                      width: double.infinity,
                      height: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: double.infinity,
                          height: 150,
                          color: AppColors.lightGray,
                          child: Icon(
                            IconSystem.error,
                            color: AppColors.mediumGray,
                          ),
                        );
                      },
                    ),
                  ),
                ],
                // Notification actions
                if (showActions && notification.actions != null && notification.actions!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: notification.actions!.map((action) {
                      return _buildActionButton(action);
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(NotificationAction action) {
    Color backgroundColor;
    Color textColor;

    switch (action.style) {
      case NotificationActionStyle.primary:
        backgroundColor = _typeColor;
        textColor = Colors.white;
        break;
      case NotificationActionStyle.secondary:
        backgroundColor = _typeColor.withOpacity(0.1);
        textColor = _typeColor;
        break;
      case NotificationActionStyle.destructive:
        backgroundColor = AppColors.error;
        textColor = Colors.white;
        break;
    }

    return OutlinedButton(
      onPressed: action.onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        side: BorderSide(
          color: action.style == NotificationActionStyle.secondary
              ? _typeColor
              : Colors.transparent,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (action.icon != null) ...[
            Icon(action.icon, size: 16),
            const SizedBox(width: 6),
          ],
          Text(action.label),
        ],
      ),
    );
  }
}

