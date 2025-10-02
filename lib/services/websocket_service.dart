import 'dart:async';
import 'package:flutter/foundation.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  final StreamController<Map<String, dynamic>> _messageController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<bool> _connectionController = 
      StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  bool _isConnected = false;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  bool get isConnected => _isConnected;

  Future<void> connect() async {
    try {
      // Simulate WebSocket connection
      await Future.delayed(const Duration(seconds: 1));
      _isConnected = true;
      _connectionController.add(true);
      
      // Start heartbeat
      _startHeartbeat();
      
      if (kDebugMode) {
        // WebSocket connected
      }
    } catch (e) {
      if (kDebugMode) {
        // WebSocket connection failed: $e
      }
      _scheduleReconnect();
    }
  }

  Future<void> disconnect() async {
    _isConnected = false;
    _connectionController.add(false);
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    
    if (kDebugMode) {
      // WebSocket disconnected
    }
  }

  void sendMessage(Map<String, dynamic> message) {
    if (!_isConnected) {
      if (kDebugMode) {
        // Cannot send message: WebSocket not connected
      }
      return;
    }

    // Simulate sending message
    if (kDebugMode) {
      // Sending message: ${jsonEncode(message)}
    }

    // Simulate receiving response
    _simulateMessageReceived(message);
  }

  void _simulateMessageReceived(Map<String, dynamic> message) {
    // Simulate network delay
    Future.delayed(const Duration(milliseconds: 500), () {
      final response = {
        ...message,
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'delivered',
      };
      _messageController.add(response);
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected) {
        sendMessage({
          'type': 'heartbeat',
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  void _scheduleReconnect() {
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected) {
        connect();
      }
    });
  }

  void dispose() {
    _messageController.close();
    _connectionController.close();
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
  }
}
