import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../constants/storage_keys.dart';
import '../models/emergency_type.dart';
import '../constants/severity_colors.dart';
import 'detection_history_service.dart';

/// Service for managing user's current emergency status
/// Syncs between SQLite and SharedPreferences
class UserStatusService {
  static UserStatusService? _instance;
  static UserStatusService get instance => _instance ??= UserStatusService._internal();
  
  UserStatusService._internal();
  
  final DetectionHistoryService _historyService = DetectionHistoryService.instance;
  
  /// Get current user's emergency status
  /// Returns map with keys: severity (enum name), emergency_type (enum name), last_updated, last_updated_timestamp
  Future<Map<String, dynamic>?> getCurrentStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userUid = prefs.getString(StorageKeys.sessionUid);

      if (userUid == null || userUid.isEmpty) {
        if (kDebugMode) debugPrint('⚠️ [SEVERITY] No session_uid in SharedPreferences');
        return null;
      }

      // Try to get from SharedPreferences first (faster)
      final statusFromPrefs = prefs.getString(StorageKeys.userCurrentStatus);
      final emergencyTypeFromPrefs = prefs.getString(StorageKeys.userCurrentEmergencyType);
      final lastUpdatedFromPrefs = prefs.getInt(StorageKeys.userStatusLastUpdated);

      if (statusFromPrefs != null && statusFromPrefs.isNotEmpty && lastUpdatedFromPrefs != null) {
        final severity = statusFromPrefs.trim();
        final emergencyType = (emergencyTypeFromPrefs?.trim().isNotEmpty == true)
            ? emergencyTypeFromPrefs!.trim()
            : 'noEmergency';
        if (kDebugMode) {
          debugPrint('📦 [SEVERITY] From prefs: severity=$severity, emergencyType=$emergencyType');
        }
        return {
          'severity': severity,
          'emergency_type': emergencyType,
          'last_updated': DateTime.fromMillisecondsSinceEpoch(lastUpdatedFromPrefs),
          'last_updated_timestamp': lastUpdatedFromPrefs,
        };
      }

      // Fallback to SQLite
      final statusFromDb = await _historyService.getCurrentUserStatus();
      if (statusFromDb != null) {
        final severity = statusFromDb['severity'] as String?;
        final emergencyType = statusFromDb['emergency_type'] as String?;
        final timestamp = statusFromDb['timestamp'] as int?;
        if (severity != null && severity.isNotEmpty && timestamp != null) {
          final typeVal = (emergencyType?.trim().isNotEmpty == true) ? emergencyType!.trim() : 'noEmergency';
          await prefs.setString(StorageKeys.userCurrentStatus, severity);
          await prefs.setString(StorageKeys.userCurrentEmergencyType, typeVal);
          await prefs.setInt(StorageKeys.userStatusLastUpdated, timestamp);
          if (kDebugMode) {
            debugPrint('📦 [SEVERITY] Synced from DB to prefs: severity=$severity, emergencyType=$typeVal');
          }
          return {
            'severity': severity,
            'emergency_type': typeVal,
            'last_updated': DateTime.fromMillisecondsSinceEpoch(timestamp),
            'last_updated_timestamp': timestamp,
          };
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ [SEVERITY] Error getCurrentStatus: $e');
      return null;
    }
  }
  
  /// Get formatted status display
  Future<Map<String, dynamic>?> getFormattedStatus() async {
    final status = await getCurrentStatus();
    if (status == null) return null;

    final severityStr = (status['severity'] as String?)?.trim();
    final typeStr = (status['emergency_type'] as String?)?.trim();
    if (severityStr == null || severityStr.isEmpty) return null;

    final severity = SeverityLevel.fromString(severityStr);
    final emergencyType = EmergencyType.fromString(typeStr ?? 'noEmergency');
    final lastUpdated = status['last_updated'] as DateTime;
    
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm:ss a');
    
    return {
      'severity': severity,
      'severity_label': severity.label,
      'severity_color': SeverityColors.color(severity),
      'emergency_type': emergencyType,
      'emergency_type_label': emergencyType.label,
      'emergency_type_emoji': emergencyType.emoji,
      'last_updated': lastUpdated,
      'last_updated_formatted': '${dateFormat.format(lastUpdated)} at ${timeFormat.format(lastUpdated)}',
      'last_updated_date': dateFormat.format(lastUpdated),
      'last_updated_time': timeFormat.format(lastUpdated),
    };
  }
}
