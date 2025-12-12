import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

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
  bool _hasPermission = false;

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
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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

    _hasPermission = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    // On Android 13+, also request the POST_NOTIFICATIONS permission via plugin
    final androidImpl = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      final androidGranted = await androidImpl.requestNotificationsPermission();
      _hasPermission = _hasPermission || (androidGranted ?? false);
    }

    if (_hasPermission) {
      debugPrint('✅ Notification permissions granted');
    } else {
      debugPrint('❌ Notification permissions denied');
    }
  }

  /// Ensure we have notification permission; if not, prompt the user.
  Future<bool> ensurePermissionGranted() async {
    if (_hasPermission) return true;
    await _requestPermissions();
    return _hasPermission;
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
    // Show local notification for foreground messages
    _showLocalNotification(
      id: message.hashCode,
      title: message.notification?.title ?? 'New Message',
      body: message.notification?.body ?? 'You have a new message',
      payload: jsonEncode(message.data),
      channelId: _getChannelIdFromMessage(message),
    );

    // Emit to stream
    _onMessageController.add(message);
  }

  String _getChannelIdFromMessage(RemoteMessage message) {
    final data = message.data;
    if (data['type'] == 'emergency') {
      return emergencyChannelId;
    } else if (data['type'] == 'message') {
      return messageChannelId;
    } else if (data['type'] == 'reminder') {
      return reminderChannelId;
    }
    return systemChannelId;
  }

  void _onNotificationResponse(NotificationResponse response) {
    debugPrint('👆 Local notification tapped: ${response.id}');
    _onNotificationTapController.add(response);
  }

  // Show local notification
  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    required String channelId,
  }) async {
    // Check/ask permission before attempting to show
    final permitted = await ensurePermissionGranted();
    if (!permitted) {
      debugPrint('❌ Notifications not permitted; skipping local notification');
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      channelDescription: _getChannelDescription(channelId),
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
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

  // Public methods for showing notifications
  Future<void> showEmergencyAlert({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      payload: payload,
      channelId: emergencyChannelId,
    );
  }

  Future<void> showMessageNotification({
    required String sender,
    required String message,
    DateTime? sentAt,
    String? payload,
  }) async {
    if (!await ensurePermissionGranted()) {
      debugPrint('❌ Notifications not permitted; skipping message notification');
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      messageChannelId,
      _getChannelName(messageChannelId),
      channelDescription: _getChannelDescription(messageChannelId),
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      styleInformation: BigTextStyleInformation(
        message,
        contentTitle: sender,
        summaryText: 'T.U.L.O.N.G',
      ),
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      color: const Color(0xFFD32F2F),
      showWhen: true,
      when: (sentAt ?? DateTime.now()).millisecondsSinceEpoch,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      subtitle: 'T.U.L.O.N.G',
    );

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      sender,
      message,
      details,
      payload: payload ?? jsonEncode({'sender': sender, 'message': message}),
    );
  }

  Future<void> showSystemNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      payload: payload,
      channelId: systemChannelId,
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

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📨 Handling background message: ${message.messageId}');
  
  // Ensure Firebase is initialized in background isolate
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Ignore if already initialized
  }

  // Show a simple local notification for background FCM messages
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  const androidDetails = AndroidNotificationDetails(
    NotificationService.messageChannelId,
    'Chat Messages',
    channelDescription: 'New messages in chats',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );
  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );
  const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

  await flutterLocalNotificationsPlugin.show(
    message.hashCode,
    message.notification?.title ?? 'New Message',
    message.notification?.body ?? 'You have a new message',
    details,
    payload: jsonEncode(message.data),
  );
}
