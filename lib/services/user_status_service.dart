import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/emergency_type.dart';
import 'detection_history_service.dart';

/// Service for managing user's current emergency status
/// Syncs between SQLite and SharedPreferences
class UserStatusService {
  static UserStatusService? _instance;
  static UserStatusService get instance => _instance ??= UserStatusService._internal();

  UserStatusService._internal();

  final DetectionHistoryService _historyService = DetectionHistoryService.instance;

  /// Get current user's emergency status
  Future<Map<String, dynamic>?> getCurrentStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userUid = prefs.getString('session_uid');

      if (userUid == null) {
        debugPrint('⚠️ No user UID found in SharedPreferences');
        return null;
      }

      // Try to get from SharedPreferences first (faster)
      final statusFromPrefs = prefs.getString('user_current_status');
      final emergencyTypeFromPrefs = prefs.getString('user_current_emergency_type');
      final lastUpdatedFromPrefs = prefs.getInt('user_status_last_updated');

      if (statusFromPrefs != null && lastUpdatedFromPrefs != null) {
        return {
          'severity': statusFromPrefs,
          'emergency_type': emergencyTypeFromPrefs ?? 'noEmergency',
          'last_updated': DateTime.fromMillisecondsSinceEpoch(lastUpdatedFromPrefs),
          'last_updated_timestamp': lastUpdatedFromPrefs,
        };
      }

      // Fallback to SQLite
      final statusFromDb = await _historyService.getCurrentUserStatus();
      if (statusFromDb != null) {
        // Sync to SharedPreferences
        await prefs.setString('user_current_status', statusFromDb['severity'] as String);
        await prefs.setString('user_current_emergency_type', statusFromDb['emergency_type'] as String);
        await prefs.setInt('user_status_last_updated', statusFromDb['timestamp'] as int);

        return {
          'severity': statusFromDb['severity'],
          'emergency_type': statusFromDb['emergency_type'],
          'last_updated': DateTime.fromMillisecondsSinceEpoch(statusFromDb['timestamp'] as int),
          'last_updated_timestamp': statusFromDb['timestamp'],
        };
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error getting current status: $e');
      return null;
    }
  }

  /// Get formatted status display
  Future<Map<String, dynamic>?> getFormattedStatus() async {
    final status = await getCurrentStatus();
    if (status == null) return null;

    final severity = SeverityLevel.fromString(status['severity'] as String);
    final emergencyType = EmergencyType.fromString(status['emergency_type'] as String? ?? 'noEmergency');
    final lastUpdated = status['last_updated'] as DateTime;

    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm:ss a');

    return {
      'severity': severity,
      'severity_label': severity.label,
      'severity_color': _getSeverityColor(severity),
      'emergency_type': emergencyType,
      'emergency_type_label': emergencyType.label,
      'emergency_type_emoji': emergencyType.emoji,
      'last_updated': lastUpdated,
      'last_updated_formatted': '${dateFormat.format(lastUpdated)} at ${timeFormat.format(lastUpdated)}',
      'last_updated_date': dateFormat.format(lastUpdated),
      'last_updated_time': timeFormat.format(lastUpdated),
    };
  }

  Color _getSeverityColor(SeverityLevel severity) {
    switch (severity) {
      case SeverityLevel.low:
        return const Color(0xFF4CAF50); // Green
      case SeverityLevel.medium:
        return const Color(0xFFFF9800); // Orange
      case SeverityLevel.high:
        return const Color(0xFFFF5722); // Deep Orange
      case SeverityLevel.critical:
        return const Color(0xFFD32F2F); // Red
    }
  }
}
