/// Centralized keys for SharedPreferences used in the severity assessment pipeline.
/// Use these constants everywhere to avoid typos and ensure consistency.
class StorageKeys {
  StorageKeys._();

  /// User session UID (used for detection history and status ownership).
  static const String sessionUid = 'session_uid';

  /// Current severity from latest detection (enum name: low, medium, high, critical).
  static const String userCurrentStatus = 'user_current_status';

  /// Current emergency type from latest detection (enum name: noEmergency, fire, etc.).
  static const String userCurrentEmergencyType = 'user_current_emergency_type';

  /// Timestamp (ms since epoch) when status was last updated.
  static const String userStatusLastUpdated = 'user_status_last_updated';

  /// Last selected bottom nav index (0–3) for "remember last tab".
  static const String lastNavIndex = 'last_nav_index';

  /// Start tab preference: "last" | "home" | "emergency".
  static const String prefStartTab = 'pref_start_tab';

  /// One-time tip: Re-analyze shown in emergency result dialog.
  static const String emergencyTipReanalyzeShown = 'emergency_tip_reanalyze_shown';

  /// One-time cooldown tip shown after first capture.
  static const String cooldownTipShown = 'cooldown_tip_shown';

  /// Last expanded disaster index on Disaster Tips screen (0-based).
  static const String disasterTipsLastExpandedIndex = 'disaster_tips_last_expanded_index';

  /// One-time hint on Disaster Tips: "Tap a disaster to see what to do..."
  static const String disasterTipsHintShown = 'disaster_tips_hint_shown';

  /// Checklist state: prefix for keys like "disaster_tips_check_Flood_0" (type name + tip index).
  static const String disasterTipsCheckPrefix = 'disaster_tips_check_';
}
