# T.U.L.O.N.G - Transmission Unit for Local Offline Network Generation

A Flutter mobile application designed for disaster-ready communication when conventional telecommunications infrastructure fails.

## Overview

T.U.L.O.N.G is a disaster communication system that creates a self-sustaining offline network for emergency situations. When earthquakes, typhoons, floods, or other disasters take down power grids and cellular towers, this app enables users to:

- Exchange short messages for coordination
- Establish real-time voice conversations
- Share messages privately or broadcast to local groups
- Maintain communication without GSM, Wi-Fi, or internet
- Access emergency power features

## Features

### 🔐 Authentication
- User registration and login
- Profile management
- Secure password handling
- Social login options (Google, Apple)

### 🏠 Home Dashboard
- Network status monitoring
- Emergency power status
- Quick action buttons
- Emergency contacts
- Real-time connection count

### 👥 People & Contacts
- View connected users
- Search and filter contacts
- User status indicators
- Direct calling capabilities
- User profile management

### 💬 Messaging
- Private messaging
- Group conversations
- Message broadcasting
- Real-time chat interface
- Message history

### 📞 Voice Communication
- Direct voice calls
- Group calling
- Broadcast messaging
- Call controls (mute, speaker, end)
- Network quality indicators

### 👤 Profile Management
- Personal information editing
- Password changes
- Notification preferences
- Privacy settings
- Account management

### 🔔 Notifications
- Emergency alerts
- Network status updates
- Message notifications
- Power warnings
- System updates

### ⚡ Emergency Features
- Emergency power monitoring
- Low battery warnings
- Emergency broadcast
- Disaster-ready interface
- Offline functionality

## Technical Architecture

### State Management
- **Provider Pattern**: Used for state management across the app
- **AuthProvider**: Handles user authentication and profile data
- **NetworkProvider**: Manages network connections and device status
- **PowerProvider**: Monitors battery levels and power status

### UI Components
- **Custom Widgets**: Reusable components for consistent design
- **Material Design**: Modern, clean interface following Material Design principles
- **Responsive Layout**: Optimized for various screen sizes
- **Accessibility**: Screen reader support and high contrast options

### Color Scheme
- **Primary Red**: #D32F2F (Emergency, alerts, primary actions)
- **Online Green**: #4CAF50 (Connected status, success)
- **Warning Orange**: #FF9800 (Warnings, low battery)
- **Error Red**: #F44336 (Errors, critical alerts)
- **Text Colors**: Various shades for hierarchy and readability

## Project Structure

```
lib/
├── constants/
│   ├── app_colors.dart      # Color definitions
│   └── app_strings.dart     # String constants
├── providers/
│   ├── auth_provider.dart   # Authentication state
│   ├── network_provider.dart # Network state
│   └── power_provider.dart  # Power/battery state
├── screens/
│   ├── auth/
│   │   ├── sign_in_screen.dart
│   │   └── sign_up_screen.dart
│   ├── home_screen.dart
│   ├── people_screen.dart
│   ├── messages_screen.dart
│   ├── calls_screen.dart
│   ├── profile_screen.dart
│   ├── change_password_screen.dart
│   ├── notifications_screen.dart
│   ├── splash_screen.dart
│   └── main_navigation.dart
├── widgets/
│   ├── custom_button.dart
│   ├── custom_text_field.dart
│   ├── status_card.dart
│   ├── quick_action_card.dart
│   ├── emergency_contacts.dart
│   ├── user_card.dart
│   ├── chat_card.dart
│   ├── connected_user_card.dart
│   ├── profile_info_card.dart
│   ├── settings_tile.dart
│   ├── notification_card.dart
│   └── search_bar.dart
└── main.dart
```

## Getting Started

### Prerequisites
- Flutter SDK (>=3.0.0)
- Dart SDK
- Android Studio / VS Code
- Android device or emulator

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd tulong_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the application**
   ```bash
   flutter run
   ```

### Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.2
  google_fonts: ^6.1.0
  flutter_svg: ^2.0.9
  provider: ^6.1.1
  shared_preferences: ^2.2.2
  intl: ^0.19.0
```

## Key Features Implementation

### 1. Offline-First Design
- All core functionality works without internet
- Local data storage and caching
- Mesh network simulation
- Emergency mode activation

### 2. Emergency Communication
- Priority messaging system
- Emergency broadcast capabilities
- Critical alert notifications
- Disaster-specific UI adaptations

### 3. Power Management
- Battery level monitoring
- Low power mode warnings
- Emergency charging indicators
- Power optimization features

### 4. Network Resilience
- Connection status monitoring
- Automatic reconnection attempts
- Signal strength indicators
- Network quality assessment

## Design Principles

### 1. Disaster-Ready Interface
- Large, easy-to-tap buttons
- High contrast colors
- Clear visual hierarchy
- Minimal cognitive load

### 2. Emergency-First UX
- Quick access to critical functions
- One-tap emergency actions
- Clear status indicators
- Intuitive navigation

### 3. Accessibility
- Screen reader compatibility
- High contrast mode support
- Large text options
- Voice control integration

## Future Enhancements

### Phase 2 Features
- [ ] Real mesh networking implementation
- [ ] GPS location sharing
- [ ] Offline maps integration
- [ ] Emergency resource sharing
- [ ] Multi-language support

### Phase 3 Features
- [ ] AI-powered emergency detection
- [ ] Automated emergency responses
- [ ] Integration with emergency services
- [ ] Advanced encryption
- [ ] Cross-platform compatibility

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support and questions:
- Create an issue in the repository
- Contact the development team
- Check the documentation

## Acknowledgments

- Flutter team for the excellent framework
- Material Design for UI guidelines
- Emergency response organizations for requirements
- Disaster preparedness communities for feedback

---

**T.U.L.O.N.G** - When disaster strikes, communication is the first lifeline to break. We're here to help you stay connected.
