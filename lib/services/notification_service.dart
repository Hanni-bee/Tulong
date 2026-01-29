import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../constants/app_colors.dart';

// Notification style enum
enum NotificationStyle {
  defaultStyle,
  bigText,
  bigPicture,
  inbox,
  messaging,
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // Notification channels
  static const String emergencyChannelId = 'emergency_alerts';
  static const String messageChannelId = 'chat_messages';
  static const String systemChannelId = 'system_notifications';
  static const String reminderChannelId = 'reminders';

  // Stream controllers for notification events
  final StreamController<NotificationResponse> _onNotificationTapController = StreamController.broadcast();
  
  Stream<NotificationResponse> get onNotificationTap => _onNotificationTapController.stream;

  bool _isInitialized = false;
  
  // App lifecycle state tracking
  bool _isAppInForeground = true; // Default to true (assume foreground on init)

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Manila'));

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Request permissions
      await _requestPermissions();

      _isInitialized = true;
      debugPrint('🔔 NotificationService initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize NotificationService: $e');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    // Use app logo for notification icon
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Create notification channels for Android
    await _createNotificationChannels();
  }

  Future<void> _createNotificationChannels() async {
    const emergencyChannel = AndroidNotificationChannel(
      emergencyChannelId,
      'Emergency Alerts',
      description: 'Critical emergency notifications',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound('emergency_alert'),
    );

    const messageChannel = AndroidNotificationChannel(
      messageChannelId,
      'Chat Messages',
      description: 'New messages in chats',
      importance: Importance.high,
    );

    const systemChannel = AndroidNotificationChannel(
      systemChannelId,
      'System Notifications',
      description: 'App updates and system messages',
      importance: Importance.defaultImportance,
    );

    const reminderChannel = AndroidNotificationChannel(
      reminderChannelId,
      'Reminders',
      description: 'Scheduled reminders and notifications',
      importance: Importance.defaultImportance,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(emergencyChannel);
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(messageChannel);
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(systemChannel);
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(reminderChannel);
  }

  Future<void> _requestPermissions() async {
    // Request permission for local notifications (Android)
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImplementation = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final granted = await androidImplementation.requestNotificationsPermission();
        if (granted == true) {
          debugPrint('✅ Notification permissions granted');
        } else {
          debugPrint('❌ Notification permissions denied');
        }
      }
    }
  }
  
  /// Set app lifecycle state
  /// Called from main app when lifecycle changes
  void setAppLifecycleState(bool isInForeground) {
    _isAppInForeground = isInForeground;
    debugPrint('📱 App lifecycle changed: ${isInForeground ? "Foreground" : "Background"}');
  }
  
  /// Check if app is currently in foreground
  bool get isAppInForeground => _isAppInForeground;


  void _onNotificationResponse(NotificationResponse response) {
    debugPrint('👆 Local notification tapped: ${response.id}');
    _onNotificationTapController.add(response);
  }

  // Show local notification with enhanced styling
  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    required String channelId,
    String? imageUrl,
    Color? color,
    String? largeIcon,
    NotificationStyle style = NotificationStyle.defaultStyle,
    bool forceShow = false, // Allow forcing notification even in foreground (emergency only)
  }) async {
    // Don't show notification if app is in foreground (unless forced for emergencies)
    if (_isAppInForeground && !forceShow) {
      debugPrint('🔕 Notification suppressed - app is in foreground: $title');
      return;
    }
    
    // Determine color based on channel
    final notificationColor = color ?? _getColorForChannel(channelId);
    
    // Create Android notification details with app's design system
    final androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      channelDescription: _getChannelDescription(channelId),
      importance: _getImportanceForChannel(channelId),
      priority: _getPriorityForChannel(channelId),
      icon: '@mipmap/launcher_icon', // App logo - visible in status bar
      color: notificationColor,
      colorized: true, // Enable colored notification background
      largeIcon: largeIcon != null 
          ? DrawableResourceAndroidBitmap(largeIcon)
          : const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'), // App logo as large icon
      styleInformation: _getStyleInformation(style, body, imageUrl),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
      playSound: true,
      channelShowBadge: true,
      autoCancel: true,
      ongoing: channelId == emergencyChannelId, // Emergency notifications are ongoing
      showWhen: true,
      when: DateTime.now().millisecondsSinceEpoch,
      ticker: title, // Text that appears in status bar
      // App design system styling
      subText: 'T.U.L.O.N.G', // App name as subtitle
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.public,
      // Neumorphic/Soft UI inspired rounded corners
      channelAction: AndroidNotificationChannelAction.createIfNotExists,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      badgeNumber: 1,
      threadIdentifier: channelId,
      categoryIdentifier: channelId,
      attachments: imageUrl != null
          ? [
              DarwinNotificationAttachment(imageUrl),
            ]
          : null,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      id,
      title,
      body,
      details,
      payload: payload,
    );
  }
  
  // Get color for notification based on channel (using app colors)
  Color _getColorForChannel(String channelId) {
    switch (channelId) {
      case emergencyChannelId:
        return AppColors.primaryRed; // App's primary red for emergency
      case messageChannelId:
        return AppColors.info; // App's info blue for messages
      case reminderChannelId:
        return AppColors.warning; // App's warning orange for reminders
      default:
        return AppColors.mediumGray; // App's medium gray for system
    }
  }
  
  // Get importance level for channel
  Importance _getImportanceForChannel(String channelId) {
    switch (channelId) {
      case emergencyChannelId:
        return Importance.max;
      case messageChannelId:
        return Importance.high;
      default:
        return Importance.defaultImportance;
    }
  }
  
  // Get priority for channel
  Priority _getPriorityForChannel(String channelId) {
    switch (channelId) {
      case emergencyChannelId:
        return Priority.max;
      case messageChannelId:
        return Priority.high;
      default:
        return Priority.defaultPriority;
    }
  }
  
  // Get style information for notification
  StyleInformation? _getStyleInformation(
    NotificationStyle style,
    String body,
    String? imageUrl,
  ) {
    switch (style) {
      case NotificationStyle.bigPicture:
        if (imageUrl != null) {
          return BigPictureStyleInformation(
            FilePathAndroidBitmap(imageUrl),
            largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'), // App logo
            contentTitle: body,
            summaryText: body,
            htmlFormatContentTitle: true,
            htmlFormatSummaryText: true,
          );
        }
        return null;
      case NotificationStyle.bigText:
        return BigTextStyleInformation(
          body,
          contentTitle: body,
          summaryText: 'T.U.L.O.N.G', // App name
          htmlFormatBigText: true,
          htmlFormatContentTitle: true,
        );
      case NotificationStyle.inbox:
        return InboxStyleInformation(
          [body],
          contentTitle: body,
          summaryText: 'T.U.L.O.N.G', // App name
          htmlFormatLines: true,
          htmlFormatContentTitle: true,
        );
      case NotificationStyle.messaging:
        // Use BigText style for messaging as fallback
        return BigTextStyleInformation(
          body,
          contentTitle: body,
          summaryText: 'T.U.L.O.N.G', // App name
          htmlFormatBigText: true,
          htmlFormatContentTitle: true,
        );
      default:
        return null;
    }
  }

  // Public methods for showing notifications with app's design system
  Future<void> showEmergencyAlert({
    required String title,
    required String body,
    String? payload,
    String? imageUrl,
    Color? color,
  }) async {
    // Emergency alerts can still show in foreground if needed, but by default follow app state
    await _showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      payload: payload,
      channelId: emergencyChannelId,
      imageUrl: imageUrl,
      color: color ?? AppColors.primaryRed, // App's primary red
      style: imageUrl != null ? NotificationStyle.bigPicture : NotificationStyle.bigText,
      forceShow: false, // Don't force - respect app state
    );
  }

  Future<void> showMessageNotification({
    required String sender,
    required String message,
    String? payload,
    String? imageUrl,
    String? avatarUrl,
    Color? color,
  }) async {
    await _showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'New message from $sender',
      body: message,
      payload: payload,
      channelId: messageChannelId,
      imageUrl: imageUrl,
      largeIcon: avatarUrl ?? '@mipmap/launcher_icon', // Use app logo if no avatar
      color: color ?? AppColors.info, // App's info blue
      style: imageUrl != null 
          ? NotificationStyle.bigPicture 
          : NotificationStyle.messaging,
    );
  }

  Future<void> showSystemNotification({
    required String title,
    required String body,
    String? payload,
    String? imageUrl,
    Color? color,
    NotificationStyle style = NotificationStyle.defaultStyle,
  }) async {
    await _showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      payload: payload,
      channelId: systemChannelId,
      imageUrl: imageUrl,
      color: color ?? AppColors.mediumGray, // App's medium gray
      style: style,
    );
  }
  
  // Enhanced notification with full customization
  Future<void> showCustomNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    String? payload,
    String? imageUrl,
    String? largeIcon,
    Color? color,
    NotificationStyle style = NotificationStyle.defaultStyle,
    Importance? importance,
    Priority? priority,
    bool? enableVibration,
    bool? playSound,
    bool? ongoing,
  }) async {
    await _showLocalNotification(
      id: id,
      title: title,
      body: body,
      payload: payload,
      channelId: channelId,
      imageUrl: imageUrl,
      largeIcon: largeIcon,
      color: color,
      style: style,
    );
  }

  // Schedule notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    String channelId = systemChannelId,
  }) async {
    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          _getChannelName(channelId),
          channelDescription: _getChannelDescription(channelId),
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  String _getChannelName(String channelId) {
    switch (channelId) {
      case emergencyChannelId:
        return 'Emergency Alerts';
      case messageChannelId:
        return 'Chat Messages';
      case reminderChannelId:
        return 'Reminders';
      default:
        return 'System Notifications';
    }
  }

  String _getChannelDescription(String channelId) {
    switch (channelId) {
      case emergencyChannelId:
        return 'Critical emergency notifications';
      case messageChannelId:
        return 'New messages in chats';
      case reminderChannelId:
        return 'Scheduled reminders and notifications';
      default:
        return 'App updates and system messages';
    }
  }

  // Cancel scheduled notification
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  // Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _localNotifications.pendingNotificationRequests();
  }

  // Notification settings management
  Future<void> updateNotificationSettings({
    bool? emergencyEnabled,
    bool? messageEnabled,
    bool? systemEnabled,
    bool? reminderEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (emergencyEnabled != null) {
      await prefs.setBool('notification_emergency', emergencyEnabled);
    }
    if (messageEnabled != null) {
      await prefs.setBool('notification_messages', messageEnabled);
    }
    if (systemEnabled != null) {
      await prefs.setBool('notification_system', systemEnabled);
    }
    if (reminderEnabled != null) {
      await prefs.setBool('notification_reminders', reminderEnabled);
    }
    if (soundEnabled != null) {
      await prefs.setBool('notification_sound', soundEnabled);
    }
    if (vibrationEnabled != null) {
      await prefs.setBool('notification_vibration', vibrationEnabled);
    }
  }

  // Get notification settings
  Future<Map<String, bool>> getNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'emergency': prefs.getBool('notification_emergency') ?? true,
      'messages': prefs.getBool('notification_messages') ?? true,
      'system': prefs.getBool('notification_system') ?? true,
      'reminders': prefs.getBool('notification_reminders') ?? false,
      'sound': prefs.getBool('notification_sound') ?? true,
      'vibration': prefs.getBool('notification_vibration') ?? true,
    };
  }

  // Dispose
  void dispose() {
    _onNotificationTapController.close();
  }
}
