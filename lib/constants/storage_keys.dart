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
}
