import 'dart:async';
import 'sqlite_service.dart';

class OfflineMessagingService {
  static final OfflineMessagingService _instance = OfflineMessagingService._internal();
  factory OfflineMessagingService() => _instance;
  OfflineMessagingService._internal();

  final SQLiteService _sqliteService = SQLiteService();

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

      // Save to SQLite (offline-only)
      final messageId = await _sqliteService.insertMessage(messageData);

      return messageId;
    } catch (e) {
      throw Exception('Failed to send message: ${e.toString()}');
    }
  }

  // Get messages for a chat (offline-only)
  Future<List<Map<String, dynamic>>> getMessages(String chatId) async {
    try {
      // Get from SQLite (offline-only)
      final localMessages = await _sqliteService.getMessagesByChatId(chatId);
      return localMessages;
    } catch (e) {
      throw Exception('Failed to get messages: ${e.toString()}');
    }
  }

  // Get messages stream (offline-only)
  Stream<List<Map<String, dynamic>>> getMessagesStream(String chatId) async* {
    // Yield local messages (offline-only)
    final localMessages = await _sqliteService.getMessagesByChatId(chatId);
    yield localMessages;
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

      // Save to SQLite (offline-only)
      final alertId = await _sqliteService.insertEmergencyAlert(alertData);

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

  // Get emergency alerts stream (offline-only)
  Stream<List<Map<String, dynamic>>> getEmergencyAlertsStream() async* {
    // Yield local alerts (offline-only)
    final localAlerts = await _sqliteService.getAllEmergencyAlerts();
    yield localAlerts;
  }
}
