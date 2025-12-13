# 🚨 Emergency Alert System - How It Works

## 📋 Overview

When ESP32 is **NOT connected**, the SOS ring uses the **Emergency Alert System** as a fallback. This is a cloud-based system that works through Firebase and push notifications.

---

## 🔄 Two Delivery Methods

### Method 1: ESP32 Local Chat (Preferred)
**When:** ESP32 is connected and authenticated  
**How:** Message sent directly through Bluetooth to ESP32 mesh network  
**Range:** Local network only (works offline)  
**Speed:** Instant (no internet required)

### Method 2: Emergency Alert System (Fallback)
**When:** ESP32 is NOT connected  
**How:** Message sent through cloud services (Firebase/Backend)  
**Range:** Global (requires internet)  
**Speed:** Depends on internet connection

---

## 🏗️ Emergency Alert System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    USER SENDS SOS                           │
│              (ESP32 Not Connected)                          │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│         _sendEmergencyAlertDirectly()                        │
│  • Gets user's emergency message                            │
│  • Gets user's location from profile                        │
│  • Gets user ID                                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│         OfflineMessagingService.sendEmergencyAlert()        │
│                                                              │
│  Step 1: Save to Local SQLite Database                       │
│  ┌────────────────────────────────────────┐                │
│  │  • Stores alert locally first          │                │
│  │  • Works even if offline               │                │
│  │  • Marks as is_synced: 0              │                │
│  └────────────────────────────────────────┘                │
│                         │                                    │
│                         ▼                                    │
│  Step 2: Check Internet Connection                         │
│  ┌────────────────────────────────────────┐                │
│  │  IF Online:                             │                │
│  │    → Sync to Firebase immediately       │                │
│  │  IF Offline:                            │                │
│  │    → Add to sync queue for later       │                │
│  └────────────────────────────────────────┘                │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│         Firebase Realtime Database                           │
│  ┌────────────────────────────────────────┐                │
│  │  /emergency_alerts/{alertId}           │                │
│  │  {                                    │                │
│  │    message: "Emergency message",      │                │
│  │    location: "User's address",        │                │
│  │    user_id: "userId",                 │                │
│  │    timestamp: 1234567890,             │                │
│  │    status: "active"                   │                │
│  │  }                                    │                │
│  └────────────────────────────────────────┘                │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│         Firebase Cloud Functions                             │
│  ┌────────────────────────────────────────┐                │
│  │  broadcastEmergencyAlert()             │                │
│  │  • Gets all online users               │                │
│  │  • Sends push notifications            │                │
│  │  • Broadcasts via WebSocket            │                │
│  └────────────────────────────────────────┘                │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│         Push Notifications                                   │
│  ┌────────────────────────────────────────┐                │
│  │  NotificationService.showEmergencyAlert()│              │
│  │  • Title: "🚨 Emergency Alert Sent"     │                │
│  │  • Body: Emergency message              │                │
│  │  • Priority: High                      │                │
│  │  • Sound: Emergency alert sound        │                │
│  │  • Vibration: Heavy pattern           │                │
│  └────────────────────────────────────────┘                │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│         All Connected Users Receive                          │
│  • Push notification on their devices                       │
│  • Alert appears in app                                     │
│  • Can view in emergency alerts screen                      │
└─────────────────────────────────────────────────────────────┘
```

---

## 📱 How It Works Step-by-Step

### Step 1: User Triggers SOS (ESP32 Not Connected)

```dart
// In modern_home_screen.dart
if (isESP32Connected) {
  // Send via ESP32
} else {
  // ESP32 not connected, send emergency alert instead
  await _sendEmergencyAlertDirectly(context, emergencyMessage);
}
```

### Step 2: Get User Information

```dart
final authProvider = context.read<AuthProvider>();
final user = authProvider.currentUserModel;
final userId = authProvider.currentUser ?? authProvider.userEmail ?? 'unknown';

// Build location from user's profile
String location = 'Unknown Location';
if (user != null) {
  final locationParts = <String>[];
  if (user.street.isNotEmpty) locationParts.add(user.street);
  if (user.barangay.isNotEmpty) locationParts.add(user.barangay);
  if (user.city.isNotEmpty) locationParts.add(user.city);
  if (user.province.isNotEmpty) locationParts.add(user.province);
  if (user.region.isNotEmpty) locationParts.add(user.region);
  
  if (locationParts.isNotEmpty) {
    location = locationParts.join(', ');
  }
}
```

### Step 3: Save to Local Database (Offline-First)

```dart
// In OfflineMessagingService.sendEmergencyAlert()
final alertData = {
  'message': message,
  'location': location,
  'user_id': userId,
  'timestamp': DateTime.now().millisecondsSinceEpoch,
  'status': 'active',
  'is_synced': 0,  // Not synced yet
};

// Save to SQLite first (works offline)
final alertId = await _sqliteService.insertEmergencyAlert(alertData);
```

**Why SQLite First?**
- Works even if device is offline
- Ensures alert is never lost
- Syncs to cloud when internet is available

### Step 4: Sync to Firebase (If Online)

```dart
if (await _networkService.isOnline()) {
  // Sync to Firebase immediately
  await _syncAlertToFirebase(alertId, alertData);
} else {
  // Add to sync queue for later
  await _sqliteService.addToSyncQueue(
    tableName: 'emergency_alerts',
    recordId: alertId,
    operation: 'create',
    data: alertData,
  );
}
```

**Firebase Structure:**
```
/emergency_alerts/{alertId}
  ├── message: "Emergency message text"
  ├── location: "Street, City, Province"
  ├── user_id: "userId123"
  ├── timestamp: 1234567890
  ├── status: "active"
  └── is_synced: 1
```

### Step 5: Firebase Cloud Functions Broadcast

When alert is saved to Firebase, a Cloud Function triggers:

```javascript
// In firebase-functions/index.js
exports.broadcastEmergencyAlert = functions.https.onCall(async (data, context) => {
  // Get all online users
  const usersSnapshot = await admin.database().ref('users')
    .orderByChild('isOnline')
    .equalTo(true)
    .once('value');
  
  const onlineUsers = usersSnapshot.val() || {};
  const userIds = Object.keys(onlineUsers);
  
  // Send push notifications to all online users
  await sendBulkPushNotification(userIds, {
    title: `🚨 Emergency Alert`,
    body: message,
    data: {
      alertId: alertRef.key,
      priority: 'high',
      location: location,
      type: 'emergency_alert'
    }
  });
});
```

### Step 6: Push Notifications Sent

```dart
// In NotificationService.showEmergencyAlert()
await NotificationService().showEmergencyAlert(
  title: '🚨 Emergency Alert Sent',
  body: emergencyMessage,
  payload: jsonEncode({
    'type': 'emergency',
    'userId': userId,
    'location': location,
    'timestamp': DateTime.now().toIso8601String(),
    'message': emergencyMessage,
  }),
);
```

**Notification Features:**
- **High Priority:** Appears even if phone is on silent
- **Sound:** Special emergency alert sound
- **Vibration:** Heavy vibration pattern
- **Ongoing:** Stays in notification bar until dismissed
- **Color:** Red color scheme

### Step 7: Users Receive Alert

All users with the app installed and online will receive:
1. **Push notification** on their device
2. **Alert in app** - appears in emergency alerts screen
3. **Real-time update** - if app is open, alert appears immediately

---

## 🔄 Offline Support

### If User is Offline When Sending:

1. Alert saved to **SQLite** (local database)
2. Marked as `is_synced: 0`
3. Added to **sync queue**
4. When internet returns:
   - Sync queue processes automatically
   - Alert uploaded to Firebase
   - Push notifications sent

### If Recipients are Offline:

1. Alert saved to Firebase
2. When recipients come online:
   - Firebase syncs alerts to their devices
   - They receive push notification
   - Alert appears in their app

---

## 📊 Comparison: ESP32 vs Emergency Alert

| Feature | ESP32 Local Chat | Emergency Alert System |
|---------|-----------------|----------------------|
| **Connection** | Bluetooth (ESP32) | Internet (Firebase) |
| **Range** | Local mesh network | Global (anywhere with internet) |
| **Speed** | Instant | Depends on internet |
| **Offline** | Works offline | Requires internet (with offline queue) |
| **Recipients** | Users in mesh network | All app users (online) |
| **Message Type** | Chat message | Emergency alert |
| **Display** | In local chat screen | In emergency alerts screen + notifications |
| **Visual** | Red emergency styling | Push notification + alert widget |

---

## 🎯 When Each Method is Used

### ESP32 Method (Preferred):
✅ ESP32 is connected  
✅ ESP32 is authenticated  
✅ User wants instant local communication  
✅ Works in disaster scenarios (no internet)

### Emergency Alert Method (Fallback):
✅ ESP32 is NOT connected  
✅ Internet connection available  
✅ Need to reach users globally  
✅ Need push notifications  
✅ Need alert tracking/management

---

## 🔐 Data Flow Summary

```
User Profile
    ↓
Emergency Message (from settings)
    ↓
User Location (from profile)
    ↓
OfflineMessagingService
    ↓
SQLite (Local) → Firebase (Cloud) → Cloud Functions
    ↓
Push Notifications → All Online Users
    ↓
Emergency Alerts Screen
```

---

## 💡 Key Benefits

1. **Reliability:** Works even if ESP32 is disconnected
2. **Global Reach:** Can reach users anywhere (with internet)
3. **Offline Support:** Saves locally, syncs when online
4. **Push Notifications:** Alerts users even if app is closed
5. **Tracking:** Emergency alerts can be tracked and managed
6. **Fallback:** Ensures message is sent even if ESP32 fails

---

## 🚨 Emergency Alert Features

- **High Priority:** Bypasses silent mode
- **Persistent:** Stays in notification bar
- **Rich Data:** Includes location, timestamp, user info
- **Trackable:** Can be acknowledged and resolved
- **Broadcast:** Reaches all online users
- **Offline Queue:** Works even when offline initially

---

## 📝 Summary

The **Emergency Alert System** is a cloud-based fallback that:
- Saves alerts locally first (SQLite)
- Syncs to Firebase when online
- Broadcasts to all online users via push notifications
- Works globally (not just local mesh network)
- Provides tracking and management features
- Ensures alerts are never lost (offline queue)

It's used when ESP32 is not connected, ensuring emergency messages can still be sent and received through the cloud infrastructure.

---

**Last Updated:** December 13, 2025

