import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/color_system.dart';

/// Standardized Icon System
/// 
/// Provides:
/// - Consistent icon style throughout
/// - Icon size standardization
/// - Icon color consistency
/// - Better icon choices (more intuitive)
class IconSystem {
  // ============================================================================
  // STANDARD ICON SIZES
  // ============================================================================

  /// Extra small icons (12px) - For compact spaces, badges
  static const double xs = 12.0;

  /// Small icons (16px) - For list items, secondary actions
  static const double sm = 16.0;

  /// Medium icons (20px) - For buttons, cards
  static const double md = 20.0;

  /// Large icons (24px) - Standard size for most UI elements
  static const double lg = 24.0;

  /// Extra large icons (32px) - For prominent actions, headers
  static const double xl = 32.0;

  /// Extra extra large icons (40px) - For hero elements
  static const double xxl = 40.0;

  /// Extra extra extra large icons (48px) - For major features
  static const double xxxl = 48.0;

  // ============================================================================
  // ICON SIZE BY CONTEXT
  // ============================================================================

  /// Navigation bar icon size
  static const double navigation = lg;

  /// Quick action icon size
  static const double quickAction = xl;

  /// Settings item icon size
  static const double settingsItem = md;

  /// Status indicator icon size
  static const double statusIndicator = sm;

  /// Action button icon size
  static const double actionButton = lg;

  /// Card icon size
  static const double cardIcon = md;

  /// List item icon size
  static const double listItem = md;

  /// Button icon size
  static const double button = md;

  // ============================================================================
  // STANDARDIZED ICON SET - Consistent Material Icons
  // ============================================================================

  // Navigation Icons
  static const IconData navHome = Icons.home_outlined;
  static const IconData navHomeActive = Icons.home;
  static const IconData navChat = Icons.chat_bubble_outline;
  static const IconData navChatActive = Icons.chat_bubble;
  static const IconData navCalls = Icons.call_outlined;
  static const IconData navCallsActive = Icons.call;
  static const IconData navProfile = Icons.person_outline;
  static const IconData navProfileActive = Icons.person;

  // Quick Actions
  static const IconData actionLocalChat = Icons.chat_bubble_rounded;
  static const IconData actionSettings = Icons.settings_rounded;
  static const IconData actionEmergency = Icons.emergency_rounded;
  static const IconData actionSOS = Icons.sos_rounded;
  static const IconData actionBluetooth = Icons.bluetooth_rounded;
  static const IconData actionPeople = Icons.people_rounded;

  // Status Indicators
  static const IconData statusOnline = Icons.circle;
  static const IconData statusOffline = Icons.circle_outlined;
  static const IconData statusConnected = Icons.bluetooth_connected_rounded;
  static const IconData statusDisconnected = Icons.bluetooth_disabled_rounded;
  static const IconData statusMuted = Icons.volume_off_rounded;
  static const IconData statusActive = Icons.radio_button_checked_rounded;
  static const IconData statusInactive = Icons.radio_button_unchecked_rounded;

  // Settings & Actions
  static const IconData settings = Icons.settings_outlined;
  static const IconData settingsFilled = Icons.settings;
  static const IconData edit = Icons.edit_outlined;
  static const IconData editFilled = Icons.edit;
  static const IconData delete = Icons.delete_outline;
  static const IconData deleteFilled = Icons.delete;
  static const IconData save = Icons.save_outlined;
  static const IconData saveFilled = Icons.save;
  static const IconData add = Icons.add_circle_outline;
  static const IconData addFilled = Icons.add_circle;
  static const IconData remove = Icons.remove_circle_outline;
  static const IconData removeFilled = Icons.remove_circle;
  static const IconData close = Icons.close_rounded;
  static const IconData check = Icons.check_circle_outline;
  static const IconData checkFilled = Icons.check_circle;
  static const IconData cancel = Icons.cancel_outlined;

  // Communication
  static const IconData message = Icons.message_outlined;
  static const IconData messageFilled = Icons.message;
  static const IconData send = Icons.send_rounded;
  static const IconData receive = Icons.download_rounded;
  static const IconData mic = Icons.mic_rounded;
  static const IconData micOff = Icons.mic_off_rounded;
  static const IconData volume = Icons.volume_up_rounded;
  static const IconData volumeOff = Icons.volume_off_rounded;

  // Information & Feedback
  static const IconData info = Icons.info_outline_rounded;
  static const IconData infoFilled = Icons.info_rounded;
  static const IconData warning = Icons.warning_amber_rounded;
  static const IconData warningFilled = Icons.warning_rounded;
  static const IconData error = Icons.error_outline_rounded;
  static const IconData errorFilled = Icons.error_rounded;
  static const IconData success = Icons.check_circle_outline_rounded;
  static const IconData successFilled = Icons.check_circle_rounded;

  // Navigation & Movement
  static const IconData back = Icons.arrow_back_ios_new_rounded;
  static const IconData forward = Icons.arrow_forward_ios_rounded;
  static const IconData up = Icons.arrow_upward_rounded;
  static const IconData down = Icons.arrow_downward_rounded;
  static const IconData next = Icons.arrow_forward_rounded;
  static const IconData previous = Icons.arrow_back_rounded;

  // Search & Filter
  static const IconData search = Icons.search_rounded;
  static const IconData filter = Icons.filter_list_rounded;
  static const IconData sort = Icons.sort_rounded;
  static const IconData refresh = Icons.refresh_rounded;
  static const IconData clear = Icons.clear_rounded;

  // User & Profile
  static const IconData user = Icons.person_outline_rounded;
  static const IconData userFilled = Icons.person_rounded;
  static const IconData profile = Icons.account_circle_outlined;
  static const IconData profileFilled = Icons.account_circle;
  static const IconData location = Icons.location_on_outlined;
  static const IconData locationFilled = Icons.location_on;
  static const IconData phone = Icons.phone_outlined;
  static const IconData phoneFilled = Icons.phone;
  static const IconData email = Icons.email_outlined;
  static const IconData emailFilled = Icons.email;

  // Security & Privacy
  static const IconData lock = Icons.lock_outline_rounded;
  static const IconData lockFilled = Icons.lock_rounded;
  static const IconData unlock = Icons.lock_open_outlined;
  static const IconData visibility = Icons.visibility_outlined;
  static const IconData visibilityOff = Icons.visibility_off_outlined;

  // Time & Date
  static const IconData time = Icons.access_time_rounded;
  static const IconData date = Icons.calendar_today_rounded;
  static const IconData clock = Icons.schedule_rounded;

  // Network & Connectivity
  static const IconData wifi = Icons.wifi_rounded;
  static const IconData wifiOff = Icons.wifi_off_rounded;
  static const IconData network = Icons.network_check_rounded;
  static const IconData signal = Icons.signal_cellular_alt_rounded;
  static const IconData battery = Icons.battery_charging_full_rounded;

  // ============================================================================
  // ICON COLORS - Consistent with Color System
  // ============================================================================

  /// Primary icon color
  static const Color primary = AppColors.primaryRed;

  /// Secondary icon color (for less important icons)
  static const Color secondary = AppColors.textSecondary;

  /// Success icon color
  static Color get successColor => ColorSystem.success;

  /// Error icon color
  static Color get errorColor => ColorSystem.error;

  /// Warning icon color
  static Color get warningColor => ColorSystem.warning;

  /// Info icon color
  static Color get infoColor => ColorSystem.info;

  /// Online/Connected icon color
  static Color get online => ColorSystem.statusOnline;

  /// Offline/Disconnected icon color
  static Color get offline => ColorSystem.statusOffline;

  /// Muted icon color
  static Color get muted => ColorSystem.statusMuted;

  /// Active icon color
  static Color get active => ColorSystem.statusActive;

  /// Inactive icon color
  static Color get inactive => ColorSystem.statusInactive;

  /// White icon color
  static const Color white = Colors.white;

  /// Black icon color
  static const Color black = Colors.black;

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Get icon size for context
  static double getSizeForContext(IconContext context) {
    switch (context) {
      case IconContext.navigation:
        return navigation;
      case IconContext.quickAction:
        return quickAction;
      case IconContext.settingsItem:
        return settingsItem;
      case IconContext.statusIndicator:
        return statusIndicator;
      case IconContext.actionButton:
        return actionButton;
      case IconContext.card:
        return cardIcon;
      case IconContext.listItem:
        return listItem;
      case IconContext.button:
        return button;
    }
  }

  /// Get semantic icon color
  static Color getSemanticColor(SemanticIconType type) {
    switch (type) {
      case SemanticIconType.success:
        return successColor;
      case SemanticIconType.error:
        return errorColor;
      case SemanticIconType.warning:
        return warningColor;
      case SemanticIconType.info:
        return infoColor;
    }
  }

  /// Get status icon color
  static Color getStatusColor(StatusIconType type) {
    switch (type) {
      case StatusIconType.online:
        return online;
      case StatusIconType.offline:
        return offline;
      case StatusIconType.muted:
        return muted;
      case StatusIconType.active:
        return active;
      case StatusIconType.inactive:
        return inactive;
      case StatusIconType.connected:
        return ColorSystem.statusConnected;
      case StatusIconType.disconnected:
        return ColorSystem.statusDisconnected;
    }
  }
}

// ============================================================================
// ENUMS
// ============================================================================

enum IconContext {
  navigation,
  quickAction,
  settingsItem,
  statusIndicator,
  actionButton,
  card,
  listItem,
  button,
}

enum SemanticIconType {
  success,
  error,
  warning,
  info,
}

enum StatusIconType {
  online,
  offline,
  muted,
  active,
  inactive,
  connected,
  disconnected,
}

