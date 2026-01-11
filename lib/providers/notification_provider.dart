import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';
import '../services/offline_messaging_service.dart';
import '../services/firebase_service.dart';

/// Notification Provider
/// 
/// Manages notification state, grouping, and badge counts
class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();
  final List<AppNotification> _notifications = [];
  final Map<String, bool> _notificationSettings = {};
  int _unreadCount = 0;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  bool get hasUnread => _unreadCount > 0;

  NotificationProvider() {
    _loadNotifications();
    _loadNotificationSettings();
    _listenToNotifications();
    _listenToEmergencyAlerts();
    _listenToGlobalChat();
    _listenToPrivateChats();
  }
  
  StreamSubscription<List<Map<String, dynamic>>>? _emergencyAlertsSubscription;
  StreamSubscription<dynamic>? _globalChatSubscription;
  final Map<String, StreamSubscription<dynamic>> _privateChatSubscriptions = {};
  List<Map<String, dynamic>> _previousAlerts = [];
  final Set<String> _previousGlobalMessageIds = {};
  final Map<String, Set<String>> _previousPrivateMessageIds = {};

  // ============================================================================
  // NOTIFICATION MANAGEMENT
  // ============================================================================

  /// Add a new notification
  Future<void> addNotification(AppNotification notification) async {
    // Check if notification type is enabled
    if (!_isNotificationTypeEnabled(notification.type)) {
      return;
    }

    _notifications.insert(0, notification);
    if (!notification.isRead) {
      _unreadCount++;
    }
    await _saveNotifications();
    notifyListeners();
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      final notification = _notifications[index];
      if (!notification.isRead) {
        _notifications[index] = notification.copyWith(isRead: true);
        _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
        await _saveNotifications();
        notifyListeners();
      }
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    }
    _unreadCount = 0;
    await _saveNotifications();
    notifyListeners();
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      final notification = _notifications[index];
      if (!notification.isRead) {
        _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
      }
      _notifications.removeAt(index);
      await _saveNotifications();
      notifyListeners();
    }
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    _notifications.clear();
    _unreadCount = 0;
    await _saveNotifications();
    notifyListeners();
  }

  // ============================================================================
  // NOTIFICATION GROUPING
  // ============================================================================

  /// Get grouped notifications
  List<NotificationGroup> getGroupedNotifications() {
    final Map<String, List<AppNotification>> groups = {};

    for (final notification in _notifications) {
      final groupKey = notification.groupKey ?? notification.type.name;
      if (!groups.containsKey(groupKey)) {
        groups[groupKey] = [];
      }
      groups[groupKey]!.add(notification);
    }

    return groups.entries.map((entry) {
      final notifications = entry.value;
      notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final latestTimestamp = notifications.isNotEmpty
          ? notifications.first.timestamp
          : null;

      return NotificationGroup(
        key: entry.key,
        title: _getGroupTitle(entry.key),
        notifications: notifications,
        latestTimestamp: latestTimestamp,
      );
    }).toList()
      ..sort((a, b) {
        if (a.latestTimestamp == null && b.latestTimestamp == null) return 0;
        if (a.latestTimestamp == null) return 1;
        if (b.latestTimestamp == null) return -1;
        return b.latestTimestamp!.compareTo(a.latestTimestamp!);
      });
  }

  String _getGroupTitle(String groupKey) {
    switch (groupKey) {
      case 'emergency':
        return 'Emergency Alerts';
      case 'message':
        return 'Messages';
      case 'system':
        return 'System Notifications';
      case 'reminder':
        return 'Reminders';
      case 'warning':
        return 'Warnings';
      case 'success':
        return 'Success';
      case 'error':
        return 'Errors';
      default:
        return 'Notifications';
    }
  }

  // ============================================================================
  // NOTIFICATION SETTINGS
  // ============================================================================

  /// Check if notification type is enabled
  bool isNotificationTypeEnabled(NotificationType type) {
    return _notificationSettings[type.name] ?? true;
  }

  /// Toggle notification type
  Future<void> toggleNotificationType(NotificationType type, bool enabled) async {
    _notificationSettings[type.name] = enabled;
    await _saveNotificationSettings();
    notifyListeners();
  }

  /// Get notification setting
  bool getNotificationSetting(NotificationType type) {
    return _notificationSettings[type.name] ?? true;
  }

  bool _isNotificationTypeEnabled(NotificationType type) {
    return _notificationSettings[type.name] ?? true;
  }

  // ============================================================================
  // BADGE COUNTS
  // ============================================================================

  /// Get badge count for a specific notification type
  int getBadgeCountForType(NotificationType type) {
    return _notifications
        .where((n) => n.type == type && !n.isRead)
        .length;
  }

  /// Get badge count for navigation
  int getNavigationBadgeCount() {
    return _unreadCount;
  }

  // ============================================================================
  // PERSISTENCE
  // ============================================================================

  Future<void> _loadNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('notifications');
      if (json != null) {
        final List<dynamic> decoded = jsonDecode(json);
        _notifications.clear();
        _notifications.addAll(
          decoded.map((n) => AppNotification.fromMap(n as Map<String, dynamic>)),
        );
        _unreadCount = _notifications.where((n) => !n.isRead).length;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_notifications.map((n) => n.toMap()).toList());
      await prefs.setString('notifications', json);
    } catch (e) {
      debugPrint('Error saving notifications: $e');
    }
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('notification_settings');
      if (json != null) {
        _notificationSettings.addAll(
          Map<String, bool>.from(jsonDecode(json)),
        );
      } else {
        // Default: all enabled
        for (final type in NotificationType.values) {
          _notificationSettings[type.name] = true;
        }
      }
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
    }
  }

  Future<void> _saveNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_notificationSettings);
      await prefs.setString('notification_settings', json);
    } catch (e) {
      debugPrint('Error saving notification settings: $e');
    }
  }

  // ============================================================================
  // NOTIFICATION LISTENERS
  // ============================================================================

  void _listenToNotifications() {
    _notificationService.onMessage.listen((message) {
      final data = message.data;
      final type = (data['type'] ?? '').toString();

      // Build meaningful, dynamic title/body (avoid generic/random notifications)
      String title = (message.notification?.title ?? '').trim();
      String body = (message.notification?.body ?? '').trim();

      if (title.isEmpty) {
        if (type == 'message') {
          final sender = (data['senderName'] ?? data['sender_name'] ?? 'Someone').toString();
          title = 'New message from $sender';
        } else if (type == 'emergency_alert' || type == 'emergency') {
          final alertType = (data['alertType'] ?? data['alert_type'] ?? '').toString();
          title = alertType.isNotEmpty
              ? '🚨 Emergency Alert - ${alertType.toUpperCase()}'
              : '🚨 Emergency Alert';
        } else if ((data['title'] ?? '').toString().trim().isNotEmpty) {
          title = data['title'].toString().trim();
        } else {
          title = 'Notification';
        }
      }

      if (body.isEmpty) {
        if (type == 'message') {
          body = (data['message'] ?? data['body'] ?? '').toString();
        } else if (type == 'emergency_alert' || type == 'emergency') {
          final msg = (data['message'] ?? '').toString();
          final loc = (data['location'] ?? '').toString();
          body = [if (msg.isNotEmpty) msg, if (loc.isNotEmpty) 'Location: $loc'].join('\n');
        } else if ((data['body'] ?? '').toString().trim().isNotEmpty) {
          body = data['body'].toString().trim();
        } else if ((data['message'] ?? '').toString().trim().isNotEmpty) {
          body = data['message'].toString().trim();
        } else {
          body = '';
        }
      }

      // If still nothing meaningful, ignore
      if (title.trim().isEmpty && body.trim().isEmpty && data.isEmpty) {
        return;
      }

      final notification = AppNotification(
        id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        body: body,
        type: _getNotificationTypeFromMessage(message),
        timestamp: message.sentTime ?? DateTime.now(),
        isRead: false,
        data: message.data,
        // Backend doesn't always provide this; derive from type for consistency
        channelId: type == 'message'
            ? 'chat_messages'
            : (type == 'emergency_alert' || type == 'emergency')
                ? 'emergency_alerts'
                : (type == 'reminder' ? 'reminders' : 'system_notifications'),
      );
      addNotification(notification);
    });

    _notificationService.onNotificationTap.listen((response) {
      if (response.payload != null) {
        final data = jsonDecode(response.payload!);
        final notificationId = data['id'] as String?;
        if (notificationId != null) {
          markAsRead(notificationId);
        }
      }
    });
  }

  NotificationType _getNotificationTypeFromMessage(RemoteMessage message) {
    final type = message.data['type'] as String?;
    if (type != null) {
      return NotificationType.values.firstWhere(
        (e) => e.name == type,
        orElse: () => NotificationType.info,
      );
    }
    return NotificationType.info;
  }
  
  // ============================================================================
  // EMERGENCY ALERTS LISTENER
  // ============================================================================
  
  void _listenToEmergencyAlerts() {
    final messagingService = OfflineMessagingService();
    
    _emergencyAlertsSubscription = messagingService.getEmergencyAlertsStream().listen(
      (alerts) {
        // Check for new alerts (not from current user)
        if (_previousAlerts.isEmpty) {
          _previousAlerts = alerts;
          return;
        }
        
        // Find new alerts
        for (final alert in alerts) {
          final alertId = alert['id']?.toString() ?? alert['firebase_key']?.toString();
          final exists = _previousAlerts.any((a) => 
            (a['id']?.toString() ?? a['firebase_key']?.toString()) == alertId
          );
          
          if (!exists) {
            // New alert received - show notification
            final message = alert['message'] as String? ?? 'Emergency alert';
            final location = alert['location'] as String? ?? 'Unknown location';
            final userId = alert['user_id'] as String? ?? alert['userId'] as String?;
            
            // Get current user ID to avoid notifying for own alerts
            // Note: This requires BuildContext, so we'll check in the notification service
            _showEmergencyAlertNotification(
              message: message,
              location: location,
              userId: userId ?? '',
            );
          }
        }
        
        _previousAlerts = alerts;
      },
      onError: (error) {
        debugPrint('Error listening to emergency alerts: $error');
      },
    );
  }
  
  Future<void> _showEmergencyAlertNotification({
    required String message,
    required String location,
    required String userId,
  }) async {
    // Check if emergency notifications are enabled
    if (!isNotificationTypeEnabled(NotificationType.emergency)) {
      return;
    }
    
    // Only show notification when app is in background (not when app is open)
    if (NotificationService().isInForeground) {
      return;
    }
    
    // Get current user to avoid notifying for own alerts
    final prefs = await SharedPreferences.getInstance();
    final currentUserEmail = prefs.getString('user_email') ?? '';
    final currentUserId = prefs.getString('user_id') ?? '';
    
    // Don't notify if this is the current user's own alert
    if (userId == currentUserId || userId == currentUserEmail) {
      return;
    }
    
    // Show push notification
    await NotificationService().showEmergencyAlert(
      title: '🚨 Emergency Alert',
      body: message,
      payload: jsonEncode({
        'type': 'emergency',
        'userId': userId,
        'location': location,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
    
    // Add to notification list
    final notification = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: '🚨 Emergency Alert',
      body: message,
      type: NotificationType.emergency,
      timestamp: DateTime.now(),
      isRead: false,
      data: {
        'userId': userId,
        'location': location,
        'message': message,
      },
    );
    
    await addNotification(notification);
  }
  
  // ============================================================================
  // GLOBAL CHAT LISTENER
  // ============================================================================
  
  void _listenToGlobalChat() {
    final firebaseService = FirebaseService();
    
    _globalChatSubscription = firebaseService.getMessagesStream('global').listen(
      (event) {
        if (!event.snapshot.exists) return;
        
        final data = event.snapshot.value;
        if (data == null) return;
        
        final messages = Map<String, dynamic>.from(data as Map);
        
        // Process each new message
        for (final entry in messages.entries) {
          final messageId = entry.key;
          final messageData = Map<String, dynamic>.from(entry.value);
          
          // Skip if we've already processed this message
          if (_previousGlobalMessageIds.contains(messageId)) {
            continue;
          }
          
          // Add to processed set
          _previousGlobalMessageIds.add(messageId);
          
          // Get sender info
          final senderId = messageData['senderId'] as String? ?? '';
          final senderName = messageData['senderName'] as String? ?? 'Unknown User';
          final messageText = messageData['message'] as String? ?? '';
          
          // Get current user to avoid notifying for own messages
          SharedPreferences.getInstance().then((prefs) {
            final currentUserId = prefs.getString('user_id') ?? '';
            final currentUserEmail = prefs.getString('user_email') ?? '';
            
            // Don't notify if this is the current user's message
            if (senderId == currentUserId || senderId == currentUserEmail) {
              return;
            }
            
            // Show notification
            _showGlobalChatNotification(
              senderName: senderName,
              message: messageText,
              messageId: messageId,
            );
          });
        }
      },
      onError: (error) {
        debugPrint('Error listening to global chat: $error');
      },
    );
  }
  
  Future<void> _showGlobalChatNotification({
    required String senderName,
    required String message,
    required String messageId,
  }) async {
    // Check if message notifications are enabled
    if (!isNotificationTypeEnabled(NotificationType.message)) {
      return;
    }
    
    // Only show notification when app is in background (not when app is open)
    if (NotificationService().isInForeground) {
      return;
    }
    
    // Show notification
    await NotificationService().showMessageNotification(
      sender: senderName,
      message: message,
      payload: jsonEncode({
        'type': 'message',
        'chatType': 'global',
        'senderName': senderName,
        'message': message,
        'messageId': messageId,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
    
    // Add to notification list
    final notification = AppNotification(
      id: messageId,
      title: 'Global Chat: $senderName',
      body: message,
      type: NotificationType.message,
      timestamp: DateTime.now(),
      isRead: false,
      data: {
        'chatType': 'global',
        'senderName': senderName,
        'message': message,
        'messageId': messageId,
      },
    );
    
    await addNotification(notification);
  }
  
  // ============================================================================
  // PRIVATE CHAT LISTENER
  // ============================================================================
  
  void _listenToPrivateChats() {
    // Listen to all private chats
    // In a real implementation, you'd get the list of active private chats
    // For now, we'll listen to messages that come through the offline messaging service
    // Private messages are handled through the same stream but with different chatId
    
    // Note: Private chat IDs are typically in format: "user1_user2" or sorted format
    // We'll need to listen to all potential private chat streams
    // This is a simplified version - in production, you'd track active chats
    
    // For now, we'll rely on the offline messaging service stream
    // which already handles private messages through getMessagesStream
    // We'll add a specific listener when a private chat is opened
  }
  
  /// Start listening to a specific private chat
  void startListeningToPrivateChat(String chatId, String contactName) {
    // Cancel existing subscription if any
    _privateChatSubscriptions[chatId]?.cancel();
    
    final firebaseService = FirebaseService();
    
    _privateChatSubscriptions[chatId] = firebaseService.getMessagesStream(chatId).listen(
      (event) {
        if (!event.snapshot.exists) return;
        
        final data = event.snapshot.value;
        if (data == null) return;
        
        final messages = Map<String, dynamic>.from(data as Map);
        
        // Initialize message IDs set for this chat if not exists
        if (!_previousPrivateMessageIds.containsKey(chatId)) {
          _previousPrivateMessageIds[chatId] = {};
        }
        
        // Process each new message
        for (final entry in messages.entries) {
          final messageId = entry.key;
          final messageData = Map<String, dynamic>.from(entry.value);
          
          // Skip if we've already processed this message
          if (_previousPrivateMessageIds[chatId]!.contains(messageId)) {
            continue;
          }
          
          // Add to processed set
          _previousPrivateMessageIds[chatId]!.add(messageId);
          
          // Get sender info
          final senderId = messageData['senderId'] as String? ?? '';
          final senderName = messageData['senderName'] as String? ?? contactName;
          final messageText = messageData['message'] as String? ?? '';
          
          // Get current user to avoid notifying for own messages
          SharedPreferences.getInstance().then((prefs) {
            final currentUserId = prefs.getString('user_id') ?? '';
            final currentUserEmail = prefs.getString('user_email') ?? '';
            
            // Don't notify if this is the current user's message
            if (senderId == currentUserId || senderId == currentUserEmail) {
              return;
            }
            
            // Show notification
            _showPrivateMessageNotification(
              senderName: senderName,
              message: messageText,
              messageId: messageId,
              chatId: chatId,
            );
          });
        }
      },
      onError: (error) {
        debugPrint('Error listening to private chat $chatId: $error');
      },
    );
  }
  
  /// Stop listening to a specific private chat
  void stopListeningToPrivateChat(String chatId) {
    _privateChatSubscriptions[chatId]?.cancel();
    _privateChatSubscriptions.remove(chatId);
    _previousPrivateMessageIds.remove(chatId);
  }
  
  Future<void> _showPrivateMessageNotification({
    required String senderName,
    required String message,
    required String messageId,
    required String chatId,
  }) async {
    // Check if message notifications are enabled
    if (!isNotificationTypeEnabled(NotificationType.message)) {
      return;
    }
    
    // Only show notification when app is in background (not when app is open)
    if (NotificationService().isInForeground) {
      return;
    }
    
    // Show notification
    await NotificationService().showMessageNotification(
      sender: senderName,
      message: message,
      payload: jsonEncode({
        'type': 'message',
        'chatType': 'private',
        'chatId': chatId,
        'senderName': senderName,
        'message': message,
        'messageId': messageId,
        'timestamp': DateTime.now().toIso8601String(),
      }),
    );
    
    // Add to notification list
    final notification = AppNotification(
      id: messageId,
      title: senderName,
      body: message,
      type: NotificationType.message,
      timestamp: DateTime.now(),
      isRead: false,
      data: {
        'chatType': 'private',
        'chatId': chatId,
        'senderName': senderName,
        'message': message,
        'messageId': messageId,
      },
    );
    
    await addNotification(notification);
  }
  
  @override
  void dispose() {
    _emergencyAlertsSubscription?.cancel();
    _globalChatSubscription?.cancel();
    for (final subscription in _privateChatSubscriptions.values) {
      subscription.cancel();
    }
    _privateChatSubscriptions.clear();
    super.dispose();
  }
}


