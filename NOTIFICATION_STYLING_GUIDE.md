# 🎨 Push Notification UI Styling Guide

## Overview
Ang notification service ay na-enhance na para suportahan ang mas advanced na styling options para sa push notifications.

## 🎯 Available Styling Options

### 1. **Notification Styles**
Mayroon kang 5 different styles na pwedeng gamitin:

```dart
enum NotificationStyle {
  defaultStyle,    // Standard notification
  bigText,         // Expanded text notification
  bigPicture,      // Notification with large image
  inbox,           // Multiple line notification
  messaging,       // Chat-style notification (fallback to bigText)
}
```

### 2. **Custom Colors**
Pwede mong i-customize ang color ng notification:

```dart
await NotificationService().showEmergencyAlert(
  title: 'Emergency Alert',
  body: 'This is an emergency!',
  color: Color(0xFFE53935), // Red color
);
```

### 3. **Big Picture Notifications**
Para sa notifications na may images:

```dart
await NotificationService().showEmergencyAlert(
  title: 'Disaster Alert',
  body: 'Typhoon warning in your area',
  imageUrl: 'https://example.com/disaster-image.jpg',
  // Automatically uses BigPictureStyle
);
```

### 4. **Large Icons**
Para sa avatar o profile picture:

```dart
await NotificationService().showMessageNotification(
  sender: 'John Doe',
  message: 'Hello!',
  avatarUrl: '@drawable/user_avatar', // Android drawable resource
);
```

## 📝 Usage Examples

### Emergency Alert with Image
```dart
await NotificationService().showEmergencyAlert(
  title: '🚨 Emergency Alert',
  body: 'Typhoon warning in Metro Manila. Please stay indoors.',
  imageUrl: 'https://example.com/typhoon-map.jpg',
  color: Color(0xFFE53935), // Red
);
```

### Message Notification with Avatar
```dart
await NotificationService().showMessageNotification(
  sender: 'Maria Garcia',
  message: 'Are you safe?',
  avatarUrl: '@drawable/maria_avatar',
  color: Color(0xFF2196F3), // Blue
);
```

### System Notification with Big Text
```dart
await NotificationService().showSystemNotification(
  title: 'System Update',
  body: 'Your app has been updated with new features...',
  style: NotificationStyle.bigText,
  color: Color(0xFF757575), // Gray
);
```

### Fully Custom Notification
```dart
await NotificationService().showCustomNotification(
  id: 12345,
  title: 'Custom Notification',
  body: 'This is a fully customized notification',
  channelId: NotificationService.systemChannelId,
  imageUrl: 'https://example.com/image.jpg',
  color: Color(0xFF4CAF50), // Green
  style: NotificationStyle.bigPicture,
  payload: 'custom_data',
);
```

## 🎨 Default Colors per Channel

- **Emergency**: `Color(0xFFE53935)` - Red
- **Messages**: `Color(0xFF2196F3)` - Blue  
- **Reminders**: `Color(0xFFFF9800)` - Orange
- **System**: `Color(0xFF757575)` - Gray

## 🔧 Advanced Features

### Vibration Patterns
Ang notifications ay may built-in vibration pattern:
```dart
vibrationPattern: Int64List.fromList([0, 250, 250, 250])
```

### Colorized Notifications
Lahat ng notifications ay `colorized: true`, meaning ang notification background ay mag-match sa color na naka-set.

### Auto-cancel
Lahat ng notifications ay `autoCancel: true` (except emergency na `ongoing: true`).

## 📱 Android vs iOS

### Android
- ✅ Full styling support (colors, images, styles)
- ✅ Big picture, big text, inbox styles
- ✅ Custom icons and large icons
- ✅ Vibration patterns

### iOS
- ✅ Basic styling support
- ✅ Image attachments
- ✅ Sound and badge support
- ⚠️ Limited color customization (iOS handles colors automatically)

## 🎯 Best Practices

1. **Use appropriate styles**:
   - `bigPicture` para sa images
   - `bigText` para sa long messages
   - `defaultStyle` para sa simple notifications

2. **Choose colors wisely**:
   - Red para sa emergency
   - Blue para sa messages
   - Orange para sa reminders
   - Gray para sa system

3. **Optimize images**:
   - Keep images under 1MB
   - Use appropriate dimensions (recommended: 512x256px)

4. **Test on different devices**:
   - Different Android versions may render differently
   - iOS has limited customization

## 🔄 Migration from Old Code

**Old Code:**
```dart
await NotificationService().showEmergencyAlert(
  title: 'Alert',
  body: 'Message',
);
```

**New Code (with styling):**
```dart
await NotificationService().showEmergencyAlert(
  title: 'Alert',
  body: 'Message',
  imageUrl: 'https://example.com/image.jpg', // Optional
  color: Color(0xFFE53935), // Optional
);
```

Backward compatible - lahat ng old code ay gagana pa rin!

## 📚 Related Files

- `lib/services/notification_service.dart` - Main notification service
- `lib/widgets/notification_card.dart` - In-app notification card UI
- `lib/widgets/enhanced_notification_card.dart` - Enhanced notification card

---

**Last Updated:** December 2025
**Status:** ✅ Ready to use!




