import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
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
  bool _isInForeground = true;
  bool _isLocalChatVisible = false;
  String? _activeChatId;

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
      // Use default device sound. (Custom raw sound file is not bundled in this repo.)
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
      // When app is open (foreground), DO NOT show system-style notifications.
      // We'll handle updates in-app via streams/badges instead.
      alert: false,
      badge: true,
      sound: false,
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

    // Android 13+ requires runtime POST_NOTIFICATIONS permission; firebase_messaging.requestPermission()
    // does not request it on Android. Ask via flutter_local_notifications plugin.
    if (Platform.isAndroid) {
      try {
        final androidImpl = _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        await androidImpl?.requestNotificationsPermission();
      } catch (e) {
        debugPrint('⚠️ Failed to request Android notification permission: $e');
      }
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
    final content = _buildNotificationContent(message);

    // Avoid showing/propagating empty or nonsense notifications
    final hasMeaningfulContent =
        content.title.trim().isNotEmpty || content.body.trim().isNotEmpty || message.data.isNotEmpty;
    if (!hasMeaningfulContent) {
      return;
    }

    // If user is currently inside the app, do NOT show a local notification.
    // Instead, just emit to stream so the UI can update quietly.
    if (!_isInForeground) {
    _showLocalNotification(
      id: message.hashCode,
        title: content.title,
        body: content.body,
      payload: jsonEncode(message.data),
      channelId: _getChannelIdFromMessage(message),
    );
    }

    // Smart in-app behavior:
    // If user is currently on Local Chat screen and this is a chat message,
    // do a silent update (no in-app banners/toasts should trigger from this stream).
    final channelId = _getChannelIdFromMessage(message);
    final msgType = (message.data['type'] ?? '').toString();
    final incomingChatId = (message.data['chatId'] ?? message.data['chat_id'] ?? '').toString();
    final shouldSuppressInAppSurface =
        _isInForeground &&
        channelId == messageChannelId &&
        (_isLocalChatVisible ||
            (_activeChatId != null &&
                _activeChatId!.isNotEmpty &&
                incomingChatId.isNotEmpty &&
                incomingChatId == _activeChatId &&
                msgType == 'message'));

    if (!shouldSuppressInAppSurface) {
    _onMessageController.add(message);
    }
  }

  String _getChannelIdFromMessage(RemoteMessage message) {
    final data = message.data;
    final type = (data['type'] ?? '').toString();
    if (type == 'emergency' || type == 'emergency_alert') {
      return emergencyChannelId;
    } else if (type == 'message') {
      return messageChannelId;
    } else if (type == 'reminder') {
      return reminderChannelId;
    }
    return systemChannelId;
  }

  ({String title, String body}) _buildNotificationContent(RemoteMessage message) {
    final data = message.data;
    final type = (data['type'] ?? '').toString();

    // Prefer server-sent notification fields when present (best source of truth)
    final serverTitle = message.notification?.title;
    final serverBody = message.notification?.body;
    if ((serverTitle ?? '').trim().isNotEmpty || (serverBody ?? '').trim().isNotEmpty) {
      return (
        title: (serverTitle ?? '').trim().isNotEmpty ? serverTitle!.trim() : 'Notification',
        body: (serverBody ?? '').trim().isNotEmpty ? serverBody!.trim() : '',
      );
    }

    // Data-only fallback
    if (type == 'message') {
      final senderName = (data['senderName'] ?? data['sender_name'] ?? '').toString();
      final msg = (data['message'] ?? data['body'] ?? '').toString();
      return (
        title: senderName.isNotEmpty ? 'New message from $senderName' : 'New message',
        body: msg,
      );
    }

    if (type == 'emergency_alert' || type == 'emergency') {
      final alertType = (data['alertType'] ?? data['alert_type'] ?? '').toString();
      final msg = (data['message'] ?? '').toString();
      final location = (data['location'] ?? '').toString();
      final t = alertType.isNotEmpty ? '🚨 Emergency Alert - ${alertType.toUpperCase()}' : '🚨 Emergency Alert';
      final b = [
        if (msg.isNotEmpty) msg,
        if (location.isNotEmpty) 'Location: $location',
      ].join('\n');
      return (title: t, body: b);
    }

    final title = (data['title'] ?? '').toString();
    final body = (data['body'] ?? data['message'] ?? '').toString();
    return (title: title.isNotEmpty ? title : 'Notification', body: body);
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
    // Use the correct channelId passed in (so messages go to the right channel).
    final androidDetails = AndroidNotificationDetails(
      channelId,
      _getChannelName(channelId),
      channelDescription: _getChannelDescription(channelId),
      importance: channelId == emergencyChannelId ? Importance.max : Importance.high,
      priority: channelId == emergencyChannelId ? Priority.high : Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      // Foreground banners are already disabled globally; keep this for background/local cases.
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

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
    String? payload,
  }) async {
    await _showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: 'New message from $sender',
      body: message,
      payload: payload,
      channelId: messageChannelId,
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
  
  /// Set app lifecycle state (foreground/background)
  void setAppLifecycleState(bool isInForeground) {
    _isInForeground = isInForeground;
    debugPrint('📱 App lifecycle state updated: ${isInForeground ? "Foreground" : "Background"}');
  }

  /// Let the notification system know if Local Chat screen is currently visible.
  /// Used to suppress in-app notification surfacing for chat messages.
  void setLocalChatScreenVisible(bool visible) {
    _isLocalChatVisible = visible;
  }

  /// Set current active chatId (e.g., private chat thread). When active, message notifications
  /// for that same chatId will be suppressed while app is in foreground.
  void setActiveChatId(String? chatId) {
    _activeChatId = chatId;
  }
}

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized for background handling
  await Firebase.initializeApp();

  // Data-only FCM messages do NOT display automatically in background.
  // Show a local notification for meaningful payloads.
  try {
    final plugin = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await plugin.initialize(initSettings);

    // Ensure channels exist (Android 8+)
    final androidImpl = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          NotificationService.emergencyChannelId,
          'Emergency Alerts',
          description: 'Critical emergency notifications',
          importance: Importance.max,
        ),
      );
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          NotificationService.messageChannelId,
          'Chat Messages',
          description: 'New messages in chats',
          importance: Importance.high,
        ),
      );
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          NotificationService.systemChannelId,
          'System Notifications',
          description: 'App updates and system messages',
          importance: Importance.defaultImportance,
        ),
      );
      await androidImpl.createNotificationChannel(
        const AndroidNotificationChannel(
          NotificationService.reminderChannelId,
          'Reminders',
          description: 'Scheduled reminders and notifications',
          importance: Importance.defaultImportance,
        ),
      );
    }

    final data = message.data;
    final type = (data['type'] ?? '').toString();

    final String channelId;
    if (type == 'emergency' || type == 'emergency_alert') {
      channelId = NotificationService.emergencyChannelId;
    } else if (type == 'message') {
      channelId = NotificationService.messageChannelId;
    } else if (type == 'reminder') {
      channelId = NotificationService.reminderChannelId;
    } else {
      channelId = NotificationService.systemChannelId;
    }

    final serverTitle = message.notification?.title;
    final serverBody = message.notification?.body;

    String title = (serverTitle ?? '').trim();
    String body = (serverBody ?? '').trim();

    // Data-only fallback
    if (title.isEmpty && body.isEmpty) {
      if (type == 'message') {
        final senderName = (data['senderName'] ?? data['sender_name'] ?? '').toString();
        final msg = (data['message'] ?? data['body'] ?? '').toString();
        title = senderName.isNotEmpty ? 'New message from $senderName' : 'New message';
        body = msg;
      } else if (type == 'emergency' || type == 'emergency_alert') {
        final alertType = (data['alertType'] ?? data['alert_type'] ?? '').toString();
        final msg = (data['message'] ?? '').toString();
        title = alertType.isNotEmpty ? '🚨 Emergency Alert - ${alertType.toUpperCase()}' : '🚨 Emergency Alert';
        body = msg;
      } else {
        title = (data['title'] ?? 'Notification').toString();
        body = (data['body'] ?? data['message'] ?? '').toString();
      }
    }

    final hasMeaningfulContent = title.trim().isNotEmpty || body.trim().isNotEmpty || data.isNotEmpty;
    if (!hasMeaningfulContent) return;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelId,
      importance: channelId == NotificationService.emergencyChannelId ? Importance.max : Importance.high,
      priority: channelId == NotificationService.emergencyChannelId ? Priority.high : Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await plugin.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(data),
    );
  } catch (e) {
    debugPrint('❌ Background notification display failed: $e');
  }
}
