import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
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

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // Notification channels
  static const String emergencyChannelId = 'emergency_alerts';
  static const String messageChannelId = 'chat_messages';
  static const String systemChannelId = 'system_notifications';
  static const String reminderChannelId = 'reminders';

  // Stream controllers for notification events
  final StreamController<RemoteMessage> _onMessageController = StreamController.broadcast();
  final StreamController<NotificationResponse> _onNotificationTapController = StreamController.broadcast();
  
  Stream<RemoteMessage> get onMessage => _onMessageController.stream;
  Stream<NotificationResponse> get onNotificationTap => _onNotificationTapController.stream;

  bool _isInitialized = false;
  String? _fcmToken;
  
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

      // Initialize Firebase messaging
      await _initializeFirebaseMessaging();

      // Request permissions
      await _requestPermissions();

      // Get FCM token
      await _getFCMToken();

      // Set up message handlers
      _setupMessageHandlers();

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

  Future<void> _initializeFirebaseMessaging() async {
    // Configure settings
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _requestPermissions() async {
    // Request permission for notifications
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ Notification permissions granted');
    } else {
      debugPrint('❌ Notification permissions denied');
    }
  }

  Future<void> _getFCMToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      debugPrint('📱 FCM Token: $_fcmToken');
      
      // Save token to preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', _fcmToken ?? '');
    } catch (e) {
      debugPrint('❌ Failed to get FCM token: $e');
    }
  }

  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📨 Received foreground message: ${message.messageId}');
      _handleForegroundMessage(message);
    });

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('👆 Notification tapped: ${message.messageId}');
      _onMessageController.add(message);
    });

    // Handle notification tap when app is terminated
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('👆 App opened from notification: ${message.messageId}');
        _onMessageController.add(message);
      }
    });
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // When app is in foreground, don't show notification
    // User can see the information directly in the app
    // Only emit to stream for in-app handling
    debugPrint('📨 Received message while app is in foreground. Notification suppressed.');
    
    // Emit to stream so UI can handle it directly
    _onMessageController.add(message);
    
    // DO NOT show notification when app is in foreground
    // Notifications will only show when app is in background
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
          : const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'), // App logo as large icon (always show logo)
      styleInformation: _getStyleInformation(style, body, imageUrl, title),
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
  
  // Get style information for notification (enhanced with dynamic content)
  StyleInformation? _getStyleInformation(
    NotificationStyle style,
    String body,
    String? imageUrl,
    String? title,
  ) {
    final appName = 'T.U.L.O.N.G';
    final timestamp = DateTime.now();
    final timeString = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    
    switch (style) {
      case NotificationStyle.bigPicture:
        if (imageUrl != null) {
          return BigPictureStyleInformation(
            FilePathAndroidBitmap(imageUrl),
            largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'), // App logo always visible
            contentTitle: title ?? body,
            summaryText: '$appName • $timeString', // Dynamic: App name + timestamp
            htmlFormatContentTitle: true,
            htmlFormatSummaryText: true,
          );
        }
        return null;
      case NotificationStyle.bigText:
        return BigTextStyleInformation(
          body,
          contentTitle: title ?? body,
          summaryText: '$appName • $timeString', // Dynamic: App name + timestamp
          htmlFormatBigText: true,
          htmlFormatContentTitle: true,
        );
      case NotificationStyle.inbox:
        return InboxStyleInformation(
          [body],
          contentTitle: title ?? body,
          summaryText: '$appName • $timeString', // Dynamic: App name + timestamp
          htmlFormatLines: true,
          htmlFormatContentTitle: true,
        );
      case NotificationStyle.messaging:
        // Use BigText style for messaging with dynamic content
        return BigTextStyleInformation(
          body,
          contentTitle: title ?? body,
          summaryText: '$appName • $timeString', // Dynamic: App name + timestamp
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

  // Get FCM token
  String? get fcmToken => _fcmToken;

  // Refresh FCM token
  Future<void> refreshFCMToken() async {
    await _getFCMToken();
  }

  // Dispose
  void dispose() {
    _onMessageController.close();
    _onNotificationTapController.close();
  }
}

// Background message handler - shows notification when app is in background
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📨 Handling background message: ${message.messageId}');
  
  // App is in background, show notification with logo and dynamic content
  final notificationService = NotificationService();
  
  // Extract notification data
  final title = message.notification?.title ?? 'T.U.L.O.N.G';
  final body = message.notification?.body ?? '';
  final imageUrl = message.notification?.android?.imageUrl ?? message.notification?.apple?.imageUrl;
  final data = message.data;
  
  // Determine channel based on data type
  String channelId = NotificationService.systemChannelId;
  if (data['type'] == 'emergency') {
    channelId = NotificationService.emergencyChannelId;
  } else if (data['type'] == 'message') {
    channelId = NotificationService.messageChannelId;
  }
  
  // Show notification with app logo and dynamic styling
  await notificationService.showCustomNotification(
    id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title: title,
    body: body,
    channelId: channelId,
    payload: message.data.toString(),
    imageUrl: imageUrl,
    largeIcon: '@mipmap/launcher_icon', // Always show app logo
    style: imageUrl != null ? NotificationStyle.bigPicture : NotificationStyle.bigText,
  );
}
