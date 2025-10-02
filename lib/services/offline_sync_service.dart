import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'firebase_service.dart';

class OfflineSyncService {
  static final OfflineSyncService _instance = OfflineSyncService._internal();
  factory OfflineSyncService() => _instance;
  OfflineSyncService._internal();

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseService _firebaseService = FirebaseService();
  
  Timer? _syncTimer;
  bool _isOnline = false;
  bool _isSyncing = false;
  final List<Map<String, dynamic>> _pendingOperations = [];

  // Stream controllers
  final StreamController<bool> _connectionStatusController = StreamController.broadcast();
  final StreamController<SyncProgress> _syncProgressController = StreamController.broadcast();

  Stream<bool> get connectionStatus => _connectionStatusController.stream;
  Stream<SyncProgress> get syncProgress => _syncProgressController.stream;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;

  Future<void> initialize() async {
    debugPrint('🔄 Initializing OfflineSyncService...');
    
    // Monitor connectivity
    _monitorConnectivity();
    
    // Start periodic sync
    _startPeriodicSync();
    
    // Load pending operations
    await _loadPendingOperations();
    
    // Initial sync if online
    if (_isOnline) {
      await performSync();
    }
  }

  void _monitorConnectivity() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final wasOnline = _isOnline;
      final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
      _isOnline = result != ConnectivityResult.none;

      _connectionStatusController.add(_isOnline);

      debugPrint('🌐 Connectivity changed: ${_isOnline ? "Online" : "Offline"}');
      
      // If we just came online, perform sync
      if (!wasOnline && _isOnline) {
        performSync();
      }
    });
  }

  void _startPeriodicSync() {
    // Sync every 30 seconds when online
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isOnline && !_isSyncing) {
        performSync();
      }
    });
  }

  // Perform sync operation
  Future<void> performSync() async {
    if (_isSyncing || !_isOnline || _pendingOperations.isEmpty) {
      return;
    }

    _isSyncing = true;
    _syncProgressController.add(SyncProgress(isSyncing: true, progress: 0.0));

    try {
      debugPrint('🔄 Starting sync with ${_pendingOperations.length} pending operations');
      
      int completed = 0;
      final total = _pendingOperations.length;

      for (final operation in List.from(_pendingOperations)) {
        try {
          await _executeOperation(operation);
          _pendingOperations.remove(operation);
          completed++;
          
          final progress = completed / total;
          _syncProgressController.add(SyncProgress(
            isSyncing: true,
            progress: progress,
            completed: completed,
            total: total,
          ));
          
          debugPrint('✅ Synced operation ${operation['type']} ($completed/$total)');
        } catch (e) {
          debugPrint('❌ Failed to sync operation ${operation['type']}: $e');
          // Keep failed operations for retry
        }
      }

      // Save updated pending operations
      await _savePendingOperations();
      
      _syncProgressController.add(SyncProgress(
        isSyncing: false,
        progress: 1.0,
        completed: completed,
        total: total,
        success: true,
      ));
      
      debugPrint('✅ Sync completed: $completed/$total operations successful');
      
    } catch (e) {
      debugPrint('❌ Sync failed: $e');
      _syncProgressController.add(SyncProgress(
        isSyncing: false,
        success: false,
        error: e.toString(),
      ));
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _executeOperation(Map<String, dynamic> operation) async {
    final type = operation['type'] as String;
    
    switch (type) {
      case 'create_message':
        await _syncCreateMessage(operation);
        break;
      case 'update_user_profile':
        await _syncUpdateUserProfile(operation);
        break;
      case 'create_emergency_alert':
        await _syncCreateEmergencyAlert(operation);
        break;
      case 'update_message_status':
        await _syncUpdateMessageStatus(operation);
        break;
      default:
        debugPrint('⚠️ Unknown operation type: $type');
    }
  }

  Future<void> _syncCreateMessage(Map<String, dynamic> operation) async {
    final data = operation['data'] as Map<String, dynamic>;
    final chatId = data['chatId'] as String;
    final messageData = data['messageData'] as Map<String, dynamic>;
    
    await _database.ref('chats/$chatId/messages').push().set(messageData);
  }

  Future<void> _syncUpdateUserProfile(Map<String, dynamic> operation) async {
    final data = operation['data'] as Map<String, dynamic>;
    final userId = data['userId'] as String;
    final profileData = data['profileData'] as Map<String, dynamic>;
    
    await _database.ref('users/$userId').update(profileData);
  }

  Future<void> _syncCreateEmergencyAlert(Map<String, dynamic> operation) async {
    final data = operation['data'] as Map<String, dynamic>;
    final alertData = data['alertData'] as Map<String, dynamic>;
    
    await _database.ref('emergency_alerts').push().set(alertData);
  }

  Future<void> _syncUpdateMessageStatus(Map<String, dynamic> operation) async {
    final data = operation['data'] as Map<String, dynamic>;
    final chatId = data['chatId'] as String;
    final messageId = data['messageId'] as String;
    final status = data['status'] as String;
    
    await _database.ref('chats/$chatId/messages/$messageId/status').set(status);
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

  // Force sync (for manual trigger)
  Future<void> forceSync() async {
    if (!_isOnline) {
      throw Exception('Cannot sync while offline');
    }
    await performSync();
  }

  // Download data for offline use
  Future<void> downloadOfflineData() async {
    if (!_isOnline) {
      throw Exception('Cannot download data while offline');
    }

    try {
      debugPrint('📥 Downloading offline data...');
      
      final user = _auth.currentUser;
      if (user == null) return;

      // Download user's chats
      await _downloadUserChats(user.uid);
      
      // Download user's profile
      await _downloadUserProfile(user.uid);
      
      // Download emergency contacts
      await _downloadEmergencyContacts();
      
      debugPrint('✅ Offline data download completed');
    } catch (e) {
      debugPrint('❌ Failed to download offline data: $e');
      rethrow;
    }
  }

  Future<void> _downloadUserChats(String userId) async {
    try {
      final snapshot = await _database.ref('users/$userId/chats').get();
      final prefs = await SharedPreferences.getInstance();
      
      if (snapshot.exists) {
        await prefs.setString('offline_chats', jsonEncode(snapshot.value));
      }
    } catch (e) {
      debugPrint('❌ Failed to download chats: $e');
    }
  }

  Future<void> _downloadUserProfile(String userId) async {
    try {
      final snapshot = await _database.ref('users/$userId').get();
      final prefs = await SharedPreferences.getInstance();
      
      if (snapshot.exists) {
        await prefs.setString('offline_profile', jsonEncode(snapshot.value));
      }
    } catch (e) {
      debugPrint('❌ Failed to download profile: $e');
    }
  }

  Future<void> _downloadEmergencyContacts() async {
    try {
      final snapshot = await _database.ref('emergency_contacts').get();
      final prefs = await SharedPreferences.getInstance();
      
      if (snapshot.exists) {
        await prefs.setString('offline_emergency_contacts', jsonEncode(snapshot.value));
      }
    } catch (e) {
      debugPrint('❌ Failed to download emergency contacts: $e');
    }
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
    _syncTimer?.cancel();
    _connectionStatusController.close();
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
