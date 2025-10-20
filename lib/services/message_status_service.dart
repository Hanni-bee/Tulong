import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Message Status Data Model
class MessageStatusData {
    final String messageId;
    final String senderId;
    final String receiverId;
    final String message;
    final DateTime timestamp;
    MessageStatus status;
    final Map<String, DateTime> readBy; // userId -> read timestamp
    final Map<String, DateTime> deliveredTo; // userId -> delivered timestamp
    String? esp32AckId; // ESP32 acknowledgment ID
    DateTime? sentAt;
    DateTime? deliveredAt;
    DateTime? seenAt;

    MessageStatusData({
      required this.messageId,
      required this.senderId,
      required this.receiverId,
      required this.message,
      required this.timestamp,
      this.status = MessageStatus.sending,
      Map<String, DateTime>? readBy,
      Map<String, DateTime>? deliveredTo,
      this.esp32AckId,
      this.sentAt,
      this.deliveredAt,
      this.seenAt,
    }) : readBy = readBy ?? {},
         deliveredTo = deliveredTo ?? {};

    Map<String, dynamic> toMap() {
      return {
        'messageId': messageId,
        'senderId': senderId,
        'receiverId': receiverId,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
        'status': status.name,
        'readBy': readBy.map((k, v) => MapEntry(k, v.toIso8601String())),
        'deliveredTo': deliveredTo.map((k, v) => MapEntry(k, v.toIso8601String())),
        'esp32AckId': esp32AckId,
        'sentAt': sentAt?.toIso8601String(),
        'deliveredAt': deliveredAt?.toIso8601String(),
        'seenAt': seenAt?.toIso8601String(),
      };
    }

    factory MessageStatusData.fromMap(Map<String, dynamic> map) {
      return MessageStatusData(
        messageId: map['messageId'] ?? '',
        senderId: map['senderId'] ?? '',
        receiverId: map['receiverId'] ?? '',
        message: map['message'] ?? '',
        timestamp: DateTime.parse(map['timestamp']),
        status: MessageStatus.values.firstWhere(
          (e) => e.name == map['status'],
          orElse: () => MessageStatus.sending,
        ),
        readBy: (map['readBy'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, DateTime.parse(v)),
        ) ?? {},
        deliveredTo: (map['deliveredTo'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, DateTime.parse(v)),
        ) ?? {},
        esp32AckId: map['esp32AckId'],
        sentAt: map['sentAt'] != null ? DateTime.parse(map['sentAt']) : null,
        deliveredAt: map['deliveredAt'] != null ? DateTime.parse(map['deliveredAt']) : null,
        seenAt: map['seenAt'] != null ? DateTime.parse(map['seenAt']) : null,
      );
    }
  }

/// Message Status Enum
enum MessageStatus {
  sending,
  sent,
  delivered,
  seen,
  failed,
}

/// Message Status Service
/// Handles realistic message status tracking: sending → sent → delivered → seen
class MessageStatusService extends ChangeNotifier {
  static final MessageStatusService _instance = MessageStatusService._internal();
  factory MessageStatusService() => _instance;
  MessageStatusService._internal();

  // ============================================================================
  // STATUS TRACKING
  // ============================================================================

  final Map<String, MessageStatusData> _messageStatuses = {};
  final StreamController<Map<String, dynamic>> _statusUpdateController = 
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get statusUpdateStream => _statusUpdateController.stream;

  // ============================================================================
  // MESSAGE TRACKING
  // ============================================================================

  /// Create a new message with sending status
  String createMessage({
    required String senderId,
    required String receiverId,
    required String message,
    String? messageId,
  }) {
    final id = messageId ?? '${DateTime.now().millisecondsSinceEpoch}-${senderId.substring(0, 3)}';
    
    final statusData = MessageStatusData(
      messageId: id,
      senderId: senderId,
      receiverId: receiverId,
      message: message,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );

    _messageStatuses[id] = statusData;
    _notifyStatusUpdate(id, MessageStatus.sending);
    _saveToStorage();
    
    return id;
  }

  /// Update message status to sent (ESP32 acknowledgment)
  void markAsSent(String messageId, {String? esp32AckId}) {
    final statusData = _messageStatuses[messageId];
    if (statusData == null) return;

    statusData.status = MessageStatus.sent;
    statusData.sentAt = DateTime.now();
    statusData.esp32AckId = esp32AckId;

    _notifyStatusUpdate(messageId, MessageStatus.sent);
    _saveToStorage();
  }

  /// Mark message as delivered to recipient
  void markAsDelivered(String messageId, String recipientId) {
    final statusData = _messageStatuses[messageId];
    if (statusData == null) return;

    statusData.deliveredTo[recipientId] = DateTime.now();
    
    // Update overall status if all recipients have received it
    if (statusData.receiverId == 'all' || statusData.deliveredTo.containsKey(statusData.receiverId)) {
      statusData.status = MessageStatus.delivered;
      statusData.deliveredAt = DateTime.now();
    }

    _notifyStatusUpdate(messageId, statusData.status);
    _saveToStorage();
  }

  /// Mark message as seen by recipient
  void markAsSeen(String messageId, String recipientId) {
    final statusData = _messageStatuses[messageId];
    if (statusData == null) return;

    statusData.readBy[recipientId] = DateTime.now();
    
    // Update overall status if all recipients have seen it
    if (statusData.receiverId == 'all' || statusData.readBy.containsKey(statusData.receiverId)) {
      statusData.status = MessageStatus.seen;
      statusData.seenAt = DateTime.now();
    }

    _notifyStatusUpdate(messageId, statusData.status);
    _saveToStorage();
  }

  /// Mark message as failed
  void markAsFailed(String messageId) {
    final statusData = _messageStatuses[messageId];
    if (statusData == null) return;

    statusData.status = MessageStatus.failed;
    _notifyStatusUpdate(messageId, MessageStatus.failed);
    _saveToStorage();
  }

  /// Get message status
  MessageStatusData? getMessageStatus(String messageId) {
    return _messageStatuses[messageId];
  }

  /// Get all message statuses
  Map<String, MessageStatusData> getAllStatuses() {
    return Map.unmodifiable(_messageStatuses);
  }

  // ============================================================================
  // ESP32 INTEGRATION
  // ============================================================================

  /// Handle ESP32 acknowledgment
  void handleESP32Acknowledgment(String messageId, String ackId) {
    markAsSent(messageId, esp32AckId: ackId);
  }

  /// Handle delivery confirmation from ESP32
  void handleDeliveryConfirmation(String messageId, String recipientId) {
    markAsDelivered(messageId, recipientId);
  }

  /// Handle read receipt from ESP32
  void handleReadReceipt(String messageId, String recipientId) {
    markAsSeen(messageId, recipientId);
  }

  // ============================================================================
  // STATUS NOTIFICATIONS
  // ============================================================================

  void _notifyStatusUpdate(String messageId, MessageStatus status) {
    final statusData = _messageStatuses[messageId];
    if (statusData == null) return;

    _statusUpdateController.add({
      'messageId': messageId,
      'status': status.name,
      'statusData': statusData.toMap(),
      'timestamp': DateTime.now().toIso8601String(),
    });

    notifyListeners();
  }

  // ============================================================================
  // PERSISTENT STORAGE
  // ============================================================================

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statusMap = _messageStatuses.map(
        (k, v) => MapEntry(k, v.toMap()),
      );
      
      await prefs.setString('message_statuses', json.encode(statusMap));
    } catch (e) {
      print('Error saving message statuses: $e');
    }
  }

  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statusJson = prefs.getString('message_statuses');
      
      if (statusJson != null) {
        final statusMap = json.decode(statusJson) as Map<String, dynamic>;
        _messageStatuses.clear();
        
        statusMap.forEach((messageId, data) {
          _messageStatuses[messageId] = MessageStatusData.fromMap(
            Map<String, dynamic>.from(data),
          );
        });
        
        notifyListeners();
      }
    } catch (e) {
      print('Error loading message statuses: $e');
    }
  }

  // ============================================================================
  // UTILITY FUNCTIONS
  // ============================================================================

  /// Get status icon for UI
  IconData getStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return Icons.access_time;
      case MessageStatus.sent:
        return Icons.check;
      case MessageStatus.delivered:
        return Icons.done_all;
      case MessageStatus.seen:
        return Icons.done_all;
      case MessageStatus.failed:
        return Icons.error;
    }
  }

  /// Get status color for UI
  Color getStatusColor(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return Colors.orange;
      case MessageStatus.sent:
        return Colors.blue;
      case MessageStatus.delivered:
        return Colors.green;
      case MessageStatus.seen:
        return Colors.green;
      case MessageStatus.failed:
        return Colors.red;
    }
  }

  /// Get status text for UI
  String getStatusText(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return 'Sending...';
      case MessageStatus.sent:
        return 'Sent';
      case MessageStatus.delivered:
        return 'Delivered';
      case MessageStatus.seen:
        return 'Seen';
      case MessageStatus.failed:
        return 'Failed';
    }
  }

  /// Clear old message statuses (older than 7 days)
  Future<void> cleanupOldStatuses() async {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 7));
    
    _messageStatuses.removeWhere((key, value) {
      return value.timestamp.isBefore(cutoffDate);
    });
    
    await _saveToStorage();
    notifyListeners();
  }

  @override
  void dispose() {
    _statusUpdateController.close();
    super.dispose();
  }
}
