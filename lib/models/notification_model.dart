import 'package:flutter/material.dart';

/// Notification Model
/// 
/// Represents a notification with rich content, actions, and grouping support
class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;
  final String? imageUrl;
  final List<NotificationAction>? actions;
  final String? groupKey; // For grouping notifications
  final Map<String, dynamic>? data; // Additional data
  final String? channelId; // Notification channel

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.imageUrl,
    this.actions,
    this.groupKey,
    this.data,
    this.channelId,
  });

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    NotificationType? type,
    DateTime? timestamp,
    bool? isRead,
    String? imageUrl,
    List<NotificationAction>? actions,
    String? groupKey,
    Map<String, dynamic>? data,
    String? channelId,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      imageUrl: imageUrl ?? this.imageUrl,
      actions: actions ?? this.actions,
      groupKey: groupKey ?? this.groupKey,
      data: data ?? this.data,
      channelId: channelId ?? this.channelId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type.name,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'imageUrl': imageUrl,
      'actions': actions?.map((a) => a.toMap()).toList(),
      'groupKey': groupKey,
      'data': data,
      'channelId': channelId,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      type: NotificationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => NotificationType.info,
      ),
      timestamp: DateTime.parse(map['timestamp'] as String),
      isRead: map['isRead'] as bool? ?? false,
      imageUrl: map['imageUrl'] as String?,
      actions: map['actions'] != null
          ? (map['actions'] as List)
              .map((a) => NotificationAction.fromMap(a as Map<String, dynamic>))
              .toList()
          : null,
      groupKey: map['groupKey'] as String?,
      data: map['data'] as Map<String, dynamic>?,
      channelId: map['channelId'] as String?,
    );
  }
}

/// Notification Type Enum
enum NotificationType {
  emergency,
  message,
  system,
  reminder,
  warning,
  success,
  error,
  info,
}

/// Notification Action
/// 
/// Represents an action button in a rich notification
class NotificationAction {
  final String id;
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final NotificationActionStyle style;

  const NotificationAction({
    required this.id,
    required this.label,
    this.icon,
    this.onTap,
    this.style = NotificationActionStyle.primary,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'icon': icon?.codePoint,
      'style': style.name,
    };
  }

  factory NotificationAction.fromMap(Map<String, dynamic> map) {
    return NotificationAction(
      id: map['id'] as String,
      label: map['label'] as String,
      icon: map['icon'] != null
          ? _constantIconForCodePoint(map['icon'] as int)
          : null,
      style: NotificationActionStyle.values.firstWhere(
        (e) => e.name == map['style'],
        orElse: () => NotificationActionStyle.primary,
      ),
    );
  }

  /// Returns constant IconData for tree-shaking. Only known code points are supported.
  static IconData? _constantIconForCodePoint(int codePoint) {
    if (codePoint == Icons.check.codePoint) return Icons.check;
    if (codePoint == Icons.close.codePoint) return Icons.close;
    if (codePoint == Icons.open_in_new.codePoint) return Icons.open_in_new;
    if (codePoint == Icons.info_outline.codePoint) return Icons.info_outline;
    if (codePoint == Icons.notification_important.codePoint) return Icons.notification_important;
    if (codePoint == Icons.visibility.codePoint) return Icons.visibility;
    if (codePoint == Icons.send.codePoint) return Icons.send;
    if (codePoint == Icons.reply.codePoint) return Icons.reply;
    if (codePoint == Icons.delete_outline.codePoint) return Icons.delete_outline;
    if (codePoint == Icons.settings.codePoint) return Icons.settings;
    return Icons.notification_important;
  }
}

/// Notification Action Style
enum NotificationActionStyle {
  primary,
  secondary,
  destructive,
}

/// Notification Group
/// 
/// Represents a group of notifications
class NotificationGroup {
  final String key;
  final String title;
  final List<AppNotification> notifications;
  final DateTime? latestTimestamp;

  const NotificationGroup({
    required this.key,
    required this.title,
    required this.notifications,
    this.latestTimestamp,
  });

  int get unreadCount => notifications.where((n) => !n.isRead).length;
  bool get hasUnread => unreadCount > 0;
}



