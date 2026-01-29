import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();
  
  bool _isSyncing = false;
  final List<Map<String, dynamic>> _pendingOperations = [];

  // Stream controllers
  final StreamController<SyncProgress> _syncProgressController = StreamController.broadcast();

  Stream<SyncProgress> get syncProgress => _syncProgressController.stream;

  bool get isSyncing => _isSyncing;

  bool _isOnline = false; // Always false for offline-only app

  Future<void> initialize() async {
    debugPrint('🔄 Initializing OfflineSyncService (offline-only mode)...');
    
    // Load pending operations
    await _loadPendingOperations();
  }

  // Perform sync operation (no-op for offline-only app)
  Future<void> performSync() async {
    debugPrint('📴 Offline-only mode - sync operations disabled');
  }

  // Getter for isOnline (always false for offline-only app)
  bool get isOnline => false;

  // Download offline data (no-op for offline-only app)
  Future<void> downloadOfflineData() async {
    debugPrint('📴 Offline-only mode - download operations disabled');
  }

  // Queue operations for offline sync
  Future<void> queueOperation(String type, Map<String, dynamic> data) async {
    final operation = {
      'type': type,
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    _pendingOperations.add(operation);
    await _savePendingOperations();
    
    debugPrint('📝 Queued operation: $type');
    
    // Try immediate sync if online
    if (_isOnline && !_isSyncing) {
      performSync();
    }
  }

  // Specific queue methods
  Future<void> queueCreateMessage(String chatId, Map<String, dynamic> messageData) async {
    await queueOperation('create_message', {
      'chatId': chatId,
      'messageData': messageData,
    });
  }

  Future<void> queueUpdateUserProfile(String userId, Map<String, dynamic> profileData) async {
    await queueOperation('update_user_profile', {
      'userId': userId,
      'profileData': profileData,
    });
  }

  Future<void> queueCreateEmergencyAlert(Map<String, dynamic> alertData) async {
    await queueOperation('create_emergency_alert', {
      'alertData': alertData,
    });
  }

  Future<void> queueUpdateMessageStatus(String chatId, String messageId, String status) async {
    await queueOperation('update_message_status', {
      'chatId': chatId,
      'messageId': messageId,
      'status': status,
    });
  }

  // Save pending operations to local storage
  Future<void> _savePendingOperations() async {
    final prefs = await SharedPreferences.getInstance();
    final operationsJson = jsonEncode(_pendingOperations);
    await prefs.setString('pending_operations', operationsJson);
  }

  // Load pending operations from local storage
  Future<void> _loadPendingOperations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final operationsJson = prefs.getString('pending_operations');
      
      if (operationsJson != null) {
        final List<dynamic> operationsList = jsonDecode(operationsJson);
        _pendingOperations.clear();
        _pendingOperations.addAll(
          operationsList.map((op) => Map<String, dynamic>.from(op))
        );
        debugPrint('📋 Loaded ${_pendingOperations.length} pending operations');
      }
    } catch (e) {
      debugPrint('❌ Failed to load pending operations: $e');
    }
  }

  // Get pending operations count
  int get pendingOperationsCount => _pendingOperations.length;

  // Clear all pending operations (use with caution)
  Future<void> clearPendingOperations() async {
    _pendingOperations.clear();
    await _savePendingOperations();
    debugPrint('🗑️ Cleared all pending operations');
  }

  // Force sync (no-op for offline-only app)
  Future<void> forceSync() async {
    debugPrint('📴 Offline-only mode - sync operations disabled');
  }

  // Get offline data
  Future<Map<String, dynamic>?> getOfflineData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataJson = prefs.getString('offline_$key');
      
      if (dataJson != null) {
        return Map<String, dynamic>.from(jsonDecode(dataJson));
      }
    } catch (e) {
      debugPrint('❌ Failed to get offline data for $key: $e');
    }
    return null;
  }

  // Dispose
  void dispose() {
    _syncProgressController.close();
  }
}

// Sync progress model
class SyncProgress {
  final bool isSyncing;
  final double progress;
  final int? completed;
  final int? total;
  final bool? success;
  final String? error;

  SyncProgress({
    required this.isSyncing,
    this.progress = 0.0,
    this.completed,
    this.total,
    this.success,
    this.error,
  });
}
