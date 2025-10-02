import 'dart:async';
import 'sqlite_service.dart';
import 'firebase_service.dart';
import 'network_service.dart';

class OfflineMessagingService {
  static final OfflineMessagingService _instance = OfflineMessagingService._internal();
  factory OfflineMessagingService() => _instance;
  OfflineMessagingService._internal();

  final SQLiteService _sqliteService = SQLiteService();
  final FirebaseService _firebaseService = FirebaseService();
  final NetworkService _networkService = NetworkService();

  // Send message (offline-first)
  Future<int> sendMessage({
    required String chatId,
    required String message,
    required String senderId,
    required String senderName,
    String? imageUrl,
  }) async {
    try {
      final messageData = {
        'chat_id': chatId,
        'message': message,
        'sender_id': senderId,
        'sender_name': senderName,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'message_type': imageUrl != null ? 'image' : 'text',
        'image_url': imageUrl,
        'is_synced': 0,
      };

      // Save to SQLite first
      final messageId = await _sqliteService.insertMessage(messageData);

      // Try to sync to Firebase if online
      if (await _networkService.isOnline()) {
        await _syncMessageToFirebase(messageId, messageData);
      } else {
        // Add to sync queue for later
        await _sqliteService.addToSyncQueue(
          tableName: 'messages',
          recordId: messageId,
          operation: 'create',
          data: messageData,
        );
      }

      return messageId;
    } catch (e) {
      throw Exception('Failed to send message: ${e.toString()}');
    }
  }

  // Get messages for a chat (offline-first)
  Future<List<Map<String, dynamic>>> getMessages(String chatId) async {
    try {
      // Get from SQLite first
      final localMessages = await _sqliteService.getMessagesByChatId(chatId);
      
      // If online, try to get latest from Firebase and merge
      if (await _networkService.isOnline()) {
        await _syncMessagesFromFirebase(chatId);
        // Return updated local messages
        return await _sqliteService.getMessagesByChatId(chatId);
      }
      
      return localMessages;
    } catch (e) {
      throw Exception('Failed to get messages: ${e.toString()}');
    }
  }

  // Get messages stream (real-time)
  Stream<List<Map<String, dynamic>>> getMessagesStream(String chatId) async* {
    // Yield local messages first
    final localMessages = await _sqliteService.getMessagesByChatId(chatId);
    yield localMessages;

    // If online, listen to Firebase changes
    if (await _networkService.isOnline()) {
      await for (final event in _firebaseService.getMessagesStream(chatId)) {
        if (event.snapshot.exists) {
          // Process Firebase messages and save to SQLite
          await _processFirebaseMessages(chatId, event.snapshot.value);
          
          // Yield updated local messages
          final updatedMessages = await _sqliteService.getMessagesByChatId(chatId);
          yield updatedMessages;
        }
      }
    }
  }

  // Send emergency alert (offline-first)
  Future<int> sendEmergencyAlert({
    required String message,
    required String location,
    required String userId,
  }) async {
    try {
      final alertData = {
        'message': message,
        'location': location,
        'user_id': userId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'status': 'active',
        'is_synced': 0,
      };

      // Save to SQLite first
      final alertId = await _sqliteService.insertEmergencyAlert(alertData);

      // Try to sync to Firebase if online
      if (await _networkService.isOnline()) {
        await _syncAlertToFirebase(alertId, alertData);
      } else {
        // Add to sync queue for later
        await _sqliteService.addToSyncQueue(
          tableName: 'emergency_alerts',
          recordId: alertId,
          operation: 'create',
          data: alertData,
        );
      }

      return alertId;
    } catch (e) {
      throw Exception('Failed to send emergency alert: ${e.toString()}');
    }
  }

  // Get emergency alerts
  Future<List<Map<String, dynamic>>> getEmergencyAlerts() async {
    try {
      return await _sqliteService.getAllEmergencyAlerts();
    } catch (e) {
      throw Exception('Failed to get emergency alerts: ${e.toString()}');
    }
  }

  // Get emergency alerts stream
  Stream<List<Map<String, dynamic>>> getEmergencyAlertsStream() async* {
    // Yield local alerts first
    final localAlerts = await _sqliteService.getAllEmergencyAlerts();
    yield localAlerts;

    // If online, listen to Firebase changes
    if (await _networkService.isOnline()) {
      await for (final event in _firebaseService.getEmergencyAlerts()) {
        if (event.snapshot.exists) {
          // Process Firebase alerts and save to SQLite
          await _processFirebaseAlerts(event.snapshot.value);
          
          // Yield updated local alerts
          final updatedAlerts = await _sqliteService.getAllEmergencyAlerts();
          yield updatedAlerts;
        }
      }
    }
  }

  // Sync message to Firebase
  Future<void> _syncMessageToFirebase(int messageId, Map<String, dynamic> messageData) async {
    try {
      final firebaseData = {
        'message': messageData['message'],
        'senderId': messageData['sender_id'],
        'senderName': messageData['sender_name'],
        'timestamp': messageData['timestamp'],
        'imageUrl': messageData['image_url'],
        'type': messageData['message_type'],
      };

      final ref = _firebaseService.database.ref('chats/${messageData['chat_id']}/messages').push();
      await ref.set(firebaseData);
      
      // Mark as synced
      await _sqliteService.markMessageAsSynced(messageId, ref.key!);
      
      print('✅ Message synced to Firebase');
    } catch (e) {
      print('❌ Failed to sync message to Firebase: $e');
    }
  }

  // Sync alert to Firebase
  Future<void> _syncAlertToFirebase(int alertId, Map<String, dynamic> alertData) async {
    try {
      final firebaseData = {
        'message': alertData['message'],
        'location': alertData['location'],
        'userId': alertData['user_id'],
        'timestamp': alertData['timestamp'],
        'type': 'emergency',
        'status': alertData['status'],
      };

      final ref = _firebaseService.database.ref('emergency_alerts').push();
      await ref.set(firebaseData);
      
      // Mark as synced
      await _sqliteService.markAlertAsSynced(alertId, ref.key!);
      
      print('✅ Alert synced to Firebase');
    } catch (e) {
      print('❌ Failed to sync alert to Firebase: $e');
    }
  }

  // Sync messages from Firebase
  Future<void> _syncMessagesFromFirebase(String chatId) async {
    try {
      final snapshot = await _firebaseService.database.ref('chats/$chatId/messages').get();
      if (snapshot.exists) {
        final messages = Map<String, dynamic>.from(snapshot.value as Map);
        for (final entry in messages.entries) {
          final messageData = Map<String, dynamic>.from(entry.value);
          
          // Check if message already exists locally
          final existingMessages = await _sqliteService.getMessagesByChatId(chatId);
          final exists = existingMessages.any((msg) => msg['firebase_key'] == entry.key);
          
          if (!exists) {
            // Save to SQLite
            await _sqliteService.insertMessage({
              'firebase_key': entry.key,
              'chat_id': chatId,
              'message': messageData['message'],
              'sender_id': messageData['senderId'],
              'sender_name': messageData['senderName'],
              'timestamp': messageData['timestamp'],
              'message_type': messageData['type'] ?? 'text',
              'image_url': messageData['imageUrl'],
              'is_synced': 1,
              'sync_timestamp': DateTime.now().millisecondsSinceEpoch,
            });
          }
        }
      }
    } catch (e) {
      print('❌ Failed to sync messages from Firebase: $e');
    }
  }

  // Process Firebase messages
  Future<void> _processFirebaseMessages(String chatId, dynamic data) async {
    try {
      if (data != null) {
        final messages = Map<String, dynamic>.from(data);
        for (final entry in messages.entries) {
          final messageData = Map<String, dynamic>.from(entry.value);
          
          // Check if message already exists locally
          final existingMessages = await _sqliteService.getMessagesByChatId(chatId);
          final exists = existingMessages.any((msg) => msg['firebase_key'] == entry.key);
          
          if (!exists) {
            // Save to SQLite
            await _sqliteService.insertMessage({
              'firebase_key': entry.key,
              'chat_id': chatId,
              'message': messageData['message'],
              'sender_id': messageData['senderId'],
              'sender_name': messageData['senderName'],
              'timestamp': messageData['timestamp'],
              'message_type': messageData['type'] ?? 'text',
              'image_url': messageData['imageUrl'],
              'is_synced': 1,
              'sync_timestamp': DateTime.now().millisecondsSinceEpoch,
            });
          }
        }
      }
    } catch (e) {
      print('❌ Failed to process Firebase messages: $e');
    }
  }

  // Process Firebase alerts
  Future<void> _processFirebaseAlerts(dynamic data) async {
    try {
      if (data != null) {
        final alerts = Map<String, dynamic>.from(data);
        for (final entry in alerts.entries) {
          final alertData = Map<String, dynamic>.from(entry.value);
          
          // Check if alert already exists locally
          final existingAlerts = await _sqliteService.getAllEmergencyAlerts();
          final exists = existingAlerts.any((alert) => alert['firebase_key'] == entry.key);
          
          if (!exists) {
            // Save to SQLite
            await _sqliteService.insertEmergencyAlert({
              'firebase_key': entry.key,
              'message': alertData['message'],
              'location': alertData['location'],
              'user_id': alertData['userId'],
              'timestamp': alertData['timestamp'],
              'status': alertData['status'],
              'is_synced': 1,
              'sync_timestamp': DateTime.now().millisecondsSinceEpoch,
            });
          }
        }
      }
    } catch (e) {
      print('❌ Failed to process Firebase alerts: $e');
    }
  }
}
