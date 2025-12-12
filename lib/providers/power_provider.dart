import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import 'dart:convert';

class PowerProvider extends ChangeNotifier {
  int _batteryLevel = 85;
  bool _isCharging = false;
  bool _isLowBattery = false;
  String _powerStatus = 'Normal';
  bool _lowBatteryNotificationShown = false;
  bool _criticalBatteryNotificationShown = false;
  
  int get batteryLevel => _batteryLevel;
  bool get isCharging => _isCharging;
  bool get isLowBattery => _isLowBattery;
  String get powerStatus => _powerStatus;
  
  void updateBatteryLevel(int level) {
    final previousLevel = _batteryLevel;
    _batteryLevel = level;
    _isLowBattery = level < 20;
    _powerStatus = _isLowBattery ? 'Low Battery' : 'Normal';
    
    // Show notifications for battery warnings
    if (!_isCharging) {
      // Low battery warning (< 20%)
      if (level < 20 && level > 10 && previousLevel >= 20 && !_lowBatteryNotificationShown) {
        _showLowBatteryNotification(level);
        _lowBatteryNotificationShown = true;
      }
      
      // Critical battery warning (< 10%)
      if (level < 10 && previousLevel >= 10 && !_criticalBatteryNotificationShown) {
        _showCriticalBatteryNotification(level);
        _criticalBatteryNotificationShown = true;
      }
      
      // Reset notification flags if battery goes back up
      if (level >= 20) {
        _lowBatteryNotificationShown = false;
      }
      if (level >= 10) {
        _criticalBatteryNotificationShown = false;
      }
    } else {
      // Reset flags when charging
      if (level >= 20) {
        _lowBatteryNotificationShown = false;
      }
      if (level >= 10) {
        _criticalBatteryNotificationShown = false;
      }
    }
    
    notifyListeners();
  }
  
  Future<void> _showLowBatteryNotification(int level) async {
    try {
      final notificationService = NotificationService();
      await notificationService.showSystemNotification(
        title: '🔋 Low Battery Warning',
        body: 'Battery is at $level%. Please charge your device soon.',
        payload: jsonEncode({
          'type': 'battery',
          'level': level,
          'status': 'low',
          'timestamp': DateTime.now().toIso8601String(),
        }),
        color: const Color(0xFFFF9800), // Orange for warning
      );
    } catch (e) {
      debugPrint('Error showing low battery notification: $e');
    }
  }
  
  Future<void> _showCriticalBatteryNotification(int level) async {
    try {
      final notificationService = NotificationService();
      await notificationService.showEmergencyAlert(
        title: '🚨 Critical Battery Level',
        body: 'Battery is at $level%! Charge immediately to maintain emergency connectivity.',
        payload: jsonEncode({
          'type': 'battery',
          'level': level,
          'status': 'critical',
          'timestamp': DateTime.now().toIso8601String(),
        }),
        color: const Color(0xFFE53935), // Red for critical
      );
    } catch (e) {
      debugPrint('Error showing critical battery notification: $e');
    }
  }
  
  void startCharging() {
    _isCharging = true;
    _powerStatus = 'Charging';
    // Reset notification flags when charging starts
    _lowBatteryNotificationShown = false;
    _criticalBatteryNotificationShown = false;
    notifyListeners();
  }
  
  void stopCharging() {
    _isCharging = false;
    _powerStatus = _isLowBattery ? 'Low Battery' : 'Normal';
    notifyListeners();
  }
  
  void simulateBatteryDrain() {
    if (_batteryLevel > 0 && !_isCharging) {
      updateBatteryLevel(_batteryLevel - 1);
    }
  }
  
  void emergencyPowerMode() {
    _powerStatus = 'Emergency Mode';
    notifyListeners();
  }
}
