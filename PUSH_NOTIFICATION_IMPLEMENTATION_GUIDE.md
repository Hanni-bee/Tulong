# 📱 Push Notification Implementation Guide

## 🎯 Overview

Complete guide on how to implement push notifications throughout the T.U.L.O.N.G app, including all features that should use notifications.

---

## 📋 Table of Contents

1. [Setup & Initialization](#setup--initialization)
2. [Features That Need Push Notifications](#features-that-need-push-notifications)
3. [Implementation Examples](#implementation-examples)
4. [Notification Handling](#notification-handling)
5. [Best Practices](#best-practices)

---

## 🔧 Setup & Initialization

### 1. Initialize Notification Service

**Location:** `lib/main.dart`

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Initialize notification service
  await NotificationService().initialize();
  
  runApp(const TulongApp());
}
```

### 2. Handle Notification Taps

**Location:** `lib/main.dart` or `lib/screens/main_navigation.dart`

```dart
// Listen to notification taps
NotificationService().onNotificationTap.listen((response) {
  // Navigate based on notification type
  final payload = jsonDecode(response.payload ?? '{}');
  final type = payload['type'];
  
  switch (type) {
    case 'emergency':
      Navigator.pushNamed(context, '/emergency');
      break;
    case 'message':
      Navigator.pushNamed(context, '/chat', arguments: payload['chatId']);
      break;
    case 'walkie_talkie':
      Navigator.pushNamed(context, '/walkie-talkie');
      break;
  }
});
```

---

## 🎯 Features That Need Push Notifications

### 1. 🚨 **Emergency Alerts**

#### Use Cases:
- ✅ SOS button pressed
- ✅ Emergency message broadcast
- ✅ Disaster warnings (typhoon, earthquake, flood)
- ✅ Emergency response team alerts
- ✅ Critical system alerts

#### Implementation Points:
- `lib/screens/modern_home_screen.dart` - SOS button
- `lib/screens/disaster_demo_screen.dart` - Disaster alerts
- `backend/routes/emergency.js` - Emergency broadcast

#### Code Example:
```dart
// When SOS button is pressed
await NotificationService().showEmergencyAlert(
  title: '🚨 Emergency Alert',
  body: emergencyMessage,
  payload: jsonEncode({
    'type': 'emergency',
    'alertId': alertId,
    'location': location,
    'priority': 'high',
  }),
  imageUrl: disasterImageUrl, // Optional: disaster map/image
);
```

---

### 2. 💬 **Chat Messages**

#### Use Cases:
- ✅ New message received (Local Chat)
- ✅ New message received (Global Chat)
- ✅ New private message
- ✅ Group chat mentions
- ✅ Message reactions
- ✅ Voice message received

#### Implementation Points:
- `lib/screens/local_chat_screen.dart` - Local chat
- `lib/screens/enhanced_global_chat_screen.dart` - Global chat
- `lib/screens/modern_personal_chat_screen.dart` - Private chat
- `lib/providers/chat_provider.dart` - Chat provider
- `lib/services/simple_bluetooth_service.dart` - Bluetooth messages

#### Code Example:
```dart
// When new message is received
await NotificationService().showMessageNotification(
  sender: senderName,
  message: messageText,
  payload: jsonEncode({
    'type': 'message',
    'chatId': chatId,
    'senderId': senderId,
    'messageId': messageId,
  }),
  avatarUrl: senderAvatarUrl, // Optional: sender's avatar
  imageUrl: messageImageUrl, // Optional: if message has image
);
```

---

### 3. 📞 **Walkie Talkie / PTT**

#### Use Cases:
- ✅ New user connected to channel
- ✅ User started speaking (PTT active)
- ✅ Incoming voice transmission
- ✅ User disconnected
- ✅ Channel status changes
- ✅ Low signal warning

#### Implementation Points:
- `lib/screens/walkie_talkie_screen.dart` - Walkie talkie screen
- `lib/services/hardware_service.dart` - Hardware service

#### Code Example:
```dart
// When user starts speaking
await NotificationService().showSystemNotification(
  title: '📞 Walkie Talkie',
  body: '$userName is speaking on channel',
  payload: jsonEncode({
    'type': 'walkie_talkie',
    'userId': userId,
    'channelId': channelId,
  }),
  color: AppColors.info,
);

// When new user connects
await NotificationService().showSystemNotification(
  title: '👤 User Connected',
  body: '$userName joined the channel',
  payload: jsonEncode({
    'type': 'walkie_talkie',
    'action': 'user_connected',
    'userId': userId,
  }),
);
```

---

### 4. 🌐 **Network & Connectivity**

#### Use Cases:
- ✅ Network connection restored
- ✅ Network connection lost
- ✅ Bluetooth connected/disconnected
- ✅ LoRa node connected/disconnected
- ✅ Mesh network status changes
- ✅ Signal strength warnings

#### Implementation Points:
- `lib/providers/network_provider.dart` - Network provider
- `lib/services/simple_bluetooth_service.dart` - Bluetooth service
- `lib/services/hardware_service.dart` - Hardware service

#### Code Example:
```dart
// When network is restored
await NotificationService().showSystemNotification(
  title: '✅ Connection Restored',
  body: 'You are back online',
  payload: jsonEncode({
    'type': 'network',
    'status': 'connected',
  }),
  color: AppColors.success,
);

// When connection is lost
await NotificationService().showSystemNotification(
  title: '⚠️ Connection Lost',
  body: 'You are now offline',
  payload: jsonEncode({
    'type': 'network',
    'status': 'disconnected',
  }),
  color: AppColors.warning,
);
```

---

### 5. 🔋 **Power & Battery**

#### Use Cases:
- ✅ Low battery warning (< 20%)
- ✅ Critical battery (< 10%)
- ✅ Battery fully charged
- ✅ Power mode changed
- ✅ Charging started/stopped

#### Implementation Points:
- `lib/providers/power_provider.dart` - Power provider
- `lib/screens/modern_home_screen.dart` - Home screen battery display

#### Code Example:
```dart
// When battery is low
if (batteryLevel < 20) {
  await NotificationService().showSystemNotification(
    title: '🔋 Low Battery',
    body: 'Battery level: ${batteryLevel}%. Please charge soon.',
    payload: jsonEncode({
      'type': 'battery',
      'level': batteryLevel,
      'status': 'low',
    }),
    color: AppColors.warning,
  );
}

// When battery is critical
if (batteryLevel < 10) {
  await NotificationService().showEmergencyAlert(
    title: '🔴 Critical Battery',
    body: 'Battery level: ${batteryLevel}%. Charge immediately!',
    payload: jsonEncode({
      'type': 'battery',
      'level': batteryLevel,
      'status': 'critical',
    }),
  );
}
```

---

### 6. 👥 **User Status & Presence**

#### Use Cases:
- ✅ Friend came online
- ✅ Friend went offline
- ✅ User status changed
- ✅ New friend request
- ✅ Friend request accepted
- ✅ Profile update notifications

#### Implementation Points:
- `lib/providers/auth_provider.dart` - Auth provider
- `lib/screens/modern_people_screen.dart` - People screen

#### Code Example:
```dart
// When friend comes online
await NotificationService().showSystemNotification(
  title: '👤 $userName is Online',
  body: '$userName is now available',
  payload: jsonEncode({
    'type': 'user_status',
    'userId': userId,
    'status': 'online',
  }),
  color: AppColors.success,
);
```

---

### 7. 📅 **Reminders & Scheduled Alerts**

#### Use Cases:
- ✅ Scheduled emergency drill reminder
- ✅ Weather alert reminder
- ✅ Check-in reminder
- ✅ Maintenance reminder
- ✅ Backup reminder

#### Implementation Points:
- `lib/services/notification_service.dart` - Schedule function
- `lib/screens/modern_home_screen.dart` - Home screen

#### Code Example:
```dart
// Schedule a reminder
await NotificationService().scheduleNotification(
  id: reminderId,
  title: '📅 Reminder',
  body: 'Emergency drill in 30 minutes',
  scheduledDate: DateTime.now().add(Duration(minutes: 30)),
  channelId: NotificationService.reminderChannelId,
  payload: jsonEncode({
    'type': 'reminder',
    'reminderId': reminderId,
  }),
);
```

---

### 8. 🔔 **System & App Updates**

#### Use Cases:
- ✅ App update available
- ✅ New features available
- ✅ Maintenance notification
- ✅ System status updates
- ✅ Sync status changes
- ✅ Data backup completed

#### Implementation Points:
- `lib/services/notification_service.dart` - System notifications
- `lib/screens/modern_profile_screen.dart` - Profile screen

#### Code Example:
```dart
// System update notification
await NotificationService().showSystemNotification(
  title: '🔄 App Update Available',
  body: 'New version 1.2.0 is available with new features',
  payload: jsonEncode({
    'type': 'system',
    'updateType': 'app_update',
    'version': '1.2.0',
  }),
  style: NotificationStyle.bigText,
);
```

---

### 9. 🗺️ **Location & Geofencing**

#### Use Cases:
- ✅ Entered danger zone
- ✅ Left safe zone
- ✅ Nearby emergency detected
- ✅ Location sharing started/stopped
- ✅ Geofence alert

#### Implementation Points:
- `lib/services/location_service.dart` - Location service (if exists)
- `lib/screens/modern_home_screen.dart` - Home screen

#### Code Example:
```dart
// When entering danger zone
await NotificationService().showEmergencyAlert(
  title: '⚠️ Danger Zone Alert',
  body: 'You have entered a danger zone. Please be careful.',
  payload: jsonEncode({
    'type': 'location',
    'alertType': 'danger_zone',
    'location': currentLocation,
  }),
  imageUrl: dangerZoneMapUrl,
);
```

---

### 10. 📊 **Data Sync & Backup**

#### Use Cases:
- ✅ Sync completed
- ✅ Sync failed
- ✅ Backup completed
- ✅ Backup failed
- ✅ Data conflict detected

#### Implementation Points:
- `lib/services/firebase_service.dart` - Firebase service
- `lib/providers/auth_provider.dart` - Auth provider

#### Code Example:
```dart
// When sync is completed
await NotificationService().showSystemNotification(
  title: '✅ Sync Completed',
  body: 'All data has been synchronized',
  payload: jsonEncode({
    'type': 'sync',
    'status': 'completed',
  }),
  color: AppColors.success,
);
```

---

## 💻 Implementation Examples

### Example 1: Emergency Alert from SOS Button

**File:** `lib/screens/modern_home_screen.dart`

```dart
Future<void> _sendEmergencyAlert(BuildContext context) async {
  final authProvider = context.read<AuthProvider>();
  final user = authProvider.currentUserModel;
  final emergencyMessage = user?.emergencyMessage ?? 'Help! I need assistance!';
  
  // Send emergency alert
  await NotificationService().showEmergencyAlert(
    title: '🚨 Emergency Alert Sent',
    body: emergencyMessage,
    payload: jsonEncode({
      'type': 'emergency',
      'userId': authProvider.currentUser,
      'location': _getUserLocation(user),
      'timestamp': DateTime.now().toIso8601String(),
    }),
  );
  
  // Also broadcast to other users via backend
  // (Backend will send push notifications to all users)
}
```

### Example 2: New Message Received

**File:** `lib/providers/chat_provider.dart`

```dart
void _handleNewMessage(ChatMessage message) {
  // Only show notification if app is in background or message is from different user
  if (message.senderId != currentUserId) {
    NotificationService().showMessageNotification(
      sender: message.senderName,
      message: message.text,
      payload: jsonEncode({
        'type': 'message',
        'chatId': message.chatId,
        'messageId': message.id,
        'senderId': message.senderId,
      }),
      avatarUrl: message.senderAvatarUrl,
    );
  }
  
  // Add to messages list
  _messages.add(message);
  notifyListeners();
}
```

### Example 3: Network Status Change

**File:** `lib/providers/network_provider.dart`

```dart
void _updateNetworkStatus(bool isConnected) {
  if (_isConnected != isConnected) {
    _isConnected = isConnected;
    
    if (isConnected) {
      NotificationService().showSystemNotification(
        title: '✅ Connected',
        body: 'Network connection restored',
        payload: jsonEncode({
          'type': 'network',
          'status': 'connected',
        }),
        color: AppColors.success,
      );
    } else {
      NotificationService().showSystemNotification(
        title: '⚠️ Disconnected',
        body: 'Network connection lost',
        payload: jsonEncode({
          'type': 'network',
          'status': 'disconnected',
        }),
        color: AppColors.warning,
      );
    }
    
    notifyListeners();
  }
}
```

---

## 🔔 Notification Handling

### Handle Notification Tap

**File:** `lib/main.dart` or create `lib/services/notification_handler.dart`

```dart
class NotificationHandler {
  static void setupNotificationHandlers(BuildContext context) {
    // Handle notification tap
    NotificationService().onNotificationTap.listen((response) {
      if (response.payload == null) return;
      
      final payload = jsonDecode(response.payload!);
      final type = payload['type'];
      
      switch (type) {
        case 'emergency':
          _handleEmergencyNotification(context, payload);
          break;
        case 'message':
          _handleMessageNotification(context, payload);
          break;
        case 'walkie_talkie':
          _handleWalkieTalkieNotification(context, payload);
          break;
        case 'network':
          _handleNetworkNotification(context, payload);
          break;
        default:
          _handleSystemNotification(context, payload);
      }
    });
  }
  
  static void _handleEmergencyNotification(BuildContext context, Map<String, dynamic> payload) {
    Navigator.pushNamed(
      context,
      '/emergency',
      arguments: {
        'alertId': payload['alertId'],
        'location': payload['location'],
      },
    );
  }
  
  static void _handleMessageNotification(BuildContext context, Map<String, dynamic> payload) {
    Navigator.pushNamed(
      context,
      '/chat',
      arguments: {
        'chatId': payload['chatId'],
        'messageId': payload['messageId'],
      },
    );
  }
  
  static void _handleWalkieTalkieNotification(BuildContext context, Map<String, dynamic> payload) {
    Navigator.pushNamed(context, '/walkie-talkie');
  }
  
  static void _handleNetworkNotification(BuildContext context, Map<String, dynamic> payload) {
    // Show network status dialog or navigate to settings
    Navigator.pushNamed(context, '/settings');
  }
  
  static void _handleSystemNotification(BuildContext context, Map<String, dynamic> payload) {
    // Handle system notifications
    // Could show a dialog or navigate to relevant screen
  }
}
```

---

## ✅ Implementation Checklist

### Priority 1 (Critical):
- [ ] Emergency alerts (SOS button)
- [ ] New chat messages
- [ ] Network status changes
- [ ] Low battery warnings

### Priority 2 (Important):
- [ ] Walkie talkie notifications
- [ ] User status changes
- [ ] System updates
- [ ] Data sync status

### Priority 3 (Nice to Have):
- [ ] Reminders
- [ ] Location alerts
- [ ] Friend requests
- [ ] Profile updates

---

## 🎯 Best Practices

### 1. **Don't Notify for Own Actions**
```dart
// ❌ Bad
await NotificationService().showMessageNotification(
  sender: 'Me',
  message: myMessage,
);

// ✅ Good
if (message.senderId != currentUserId) {
  await NotificationService().showMessageNotification(
    sender: message.senderName,
    message: message.text,
  );
}
```

### 2. **Use Appropriate Notification Types**
```dart
// Emergency - use showEmergencyAlert
await NotificationService().showEmergencyAlert(...);

// Messages - use showMessageNotification
await NotificationService().showMessageNotification(...);

// System - use showSystemNotification
await NotificationService().showSystemNotification(...);
```

### 3. **Include Payload for Navigation**
```dart
// Always include payload for proper navigation
payload: jsonEncode({
  'type': 'message',
  'chatId': chatId,
  'messageId': messageId,
}),
```

### 4. **Check App State**
```dart
// Only show notification if app is in background
if (AppLifecycleState.paused == WidgetsBinding.instance.lifecycleState) {
  await NotificationService().showMessageNotification(...);
}
```

### 5. **Respect User Preferences**
```dart
// Check notification settings before sending
final settings = await NotificationService().getNotificationSettings();
if (settings['messages'] == true) {
  await NotificationService().showMessageNotification(...);
}
```

---

## 📚 Related Files

- `lib/services/notification_service.dart` - Main notification service
- `lib/providers/notification_provider.dart` - Notification provider
- `lib/screens/notification_settings_screen.dart` - Settings screen
- `backend/services/notification.js` - Backend notification service
- `NOTIFICATION_STYLING_GUIDE.md` - Styling guide
- `NOTIFICATION_STYLING_UPDATE.md` - Design system integration

---

**Last Updated:** December 2025
**Status:** ✅ Ready for implementation!






