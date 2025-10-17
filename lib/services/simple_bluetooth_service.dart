import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// Simple Bluetooth Service for ESP32 Communication
/// Uses platform channels to communicate with Android Bluetooth
class SimpleBluetoothService extends ChangeNotifier {
  // ============================================================================
  // SINGLETON PATTERN
  // ============================================================================
  
  static final SimpleBluetoothService _instance = SimpleBluetoothService._internal();
  factory SimpleBluetoothService() => _instance;
  SimpleBluetoothService._internal();

  // ============================================================================
  // PLATFORM CHANNEL
  // ============================================================================
  
  static const MethodChannel _channel = MethodChannel('simple_bluetooth');

  // ============================================================================
  // STATE VARIABLES
  // ============================================================================
  
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isAuthenticated = false;
  String _connectionStatus = 'Disconnected';
  String _lastError = '';
  String _esp32NodeId = '';
  String _esp32Mac = '';
  String _userName = '';

  // ============================================================================
  // MESSAGE HANDLING
  // ============================================================================
  
  final StreamController<Map<String, dynamic>> _messageController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _statusController = 
      StreamController<String>.broadcast();

  // ============================================================================
  // GETTERS
  // ============================================================================
  
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  bool get isAuthenticated => _isAuthenticated;
  String get connectionStatus => _connectionStatus;
  String get lastError => _lastError;
  String get esp32NodeId => _esp32NodeId;
  String get esp32Mac => _esp32Mac;
  String get userName => _userName;
  
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<String> get statusStream => _statusController.stream;

  // ============================================================================
  // INITIALIZATION
  // ============================================================================
  
  Future<void> initialize() async {
    try {
      _addStatusLog('Initializing Simple Bluetooth Service...');
      
      // Set up method call handler
      _channel.setMethodCallHandler(_handleMethodCall);
      
      // Load stored data
      await _loadStoredData();
      
      _addStatusLog('Simple Bluetooth Service initialized');
      
    } catch (e) {
      _addErrorLog('Failed to initialize Bluetooth service: $e');
      rethrow;
    }
  }

  // ============================================================================
  // PLATFORM CHANNEL HANDLER
  // ============================================================================
  
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onBluetoothStateChanged':
        _handleBluetoothStateChanged(call.arguments);
        break;
      case 'onMessageReceived':
        _handleMessageReceived(call.arguments);
        break;
      case 'onStatusChanged':
        _handleStatusChanged(call.arguments);
        break;
      case 'onError':
        _handleError(call.arguments);
        break;
    }
  }

  void _handleBluetoothStateChanged(dynamic arguments) {
    final Map<String, dynamic> data = Map<String, dynamic>.from(arguments);
    _isConnected = data['connected'] ?? false;
    _connectionStatus = data['status'] ?? 'Unknown';
    
    if (_isConnected) {
      _addStatusLog('Connected to ESP32');
      
      // BYPASS AUTH: Auto-authenticate for testing
      _isAuthenticated = true;
      _esp32NodeId = 'ESP32_TEST';
      _userName = 'TestUser';
      _addStatusLog('✅ Auto-authenticated (testing mode)');
      _addStatusLog('Ready to send/receive messages!');
      
      // Still send auth request for ESP32 (non-blocking)
      _sendAuthRequest();
    } else {
      _addStatusLog('Disconnected from ESP32');
      _isAuthenticated = false;
    }
    
    notifyListeners();
  }

  void _handleStatusChanged(dynamic arguments) {
    final Map<String, dynamic> data = Map<String, dynamic>.from(arguments);
    final String status = data['status'] ?? '';
    
    if (status.isNotEmpty) {
      _connectionStatus = status;
      _addStatusLog(status);
      notifyListeners();
    }
  }

  void _handleMessageReceived(dynamic arguments) {
    try {
      final Map<String, dynamic> data = Map<String, dynamic>.from(arguments);
      
      if (data.containsKey('auth_request')) {
        _handleAuthRequest(data);
      } else if (data.containsKey('sync_complete')) {
        _handleSyncComplete(data);
      } else if (data.containsKey('type')) {
        _handleChatMessage(data);
      }
      
    } catch (e) {
      _addErrorLog('Error handling received message: $e');
    }
  }

  void _handleError(dynamic arguments) {
    _lastError = arguments.toString();
    _addErrorLog('Bluetooth error: $_lastError');
    notifyListeners();
  }

  // ============================================================================
  // CONNECTION MANAGEMENT
  // ============================================================================
  
  Future<bool> connectToESP32() async {
    if (_isConnecting || _isConnected) return _isConnected;
    
    try {
      _isConnecting = true;
      _connectionStatus = 'Searching for ESP32...';
      notifyListeners();
      
      _addStatusLog('Searching for ESP32 LoRa Node...');
      
      final bool result = await _channel.invokeMethod('connectToESP32');
      
      if (result) {
        _isConnecting = false;
        _addStatusLog('Connection initiated successfully');
        return true;
      } else {
        _isConnecting = false;
        _connectionStatus = 'Connection failed';
        _addStatusLog('Failed to initiate connection');
        return false;
      }
      
    } catch (e) {
      _isConnecting = false;
      _connectionStatus = 'Connection failed';
      _lastError = e.toString();
      _addErrorLog('Failed to connect to ESP32: $e');
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      _addStatusLog('Disconnecting from ESP32...');
      
      await _channel.invokeMethod('disconnect');
      
      _isConnected = false;
      _isAuthenticated = false;
      _connectionStatus = 'Disconnected';
      
      _addStatusLog('Disconnected from ESP32');
      notifyListeners();
      
    } catch (e) {
      _addErrorLog('Error during disconnect: $e');
    }
  }

  // ============================================================================
  // AUTHENTICATION
  // ============================================================================
  
  void _sendAuthRequest() {
    try {
      _addStatusLog('Sending authentication request...');
      
      _channel.invokeMethod('sendAuthRequest');
      
    } catch (e) {
      _addErrorLog('Error sending auth request: $e');
    }
  }

  void _handleAuthRequest(Map<String, dynamic> data) {
    try {
      String esp32NodeId = data['node_id'] ?? '';
      
      _addStatusLog('ESP32 requesting authentication...');
      _addStatusLog('ESP32 Node ID: $esp32NodeId');
      
      // Get user name from AuthProvider
      final authProvider = AuthProvider();
      String firstName = authProvider.userName?.split(' ').first ?? 'User';
      
      // Send authentication confirmation (firstname only, no MAC)
      Map<String, dynamic> authResponse = {
        'auth_confirm': true,
        'firstname': firstName,
      };
      
      _sendMessage(authResponse);
      
      // Store ESP32 info
      _esp32NodeId = esp32NodeId;
      _userName = firstName;
      
      _saveStoredData();
      
      _addStatusLog('Authentication sent for user: $firstName');
      
    } catch (e) {
      _addErrorLog('Error handling auth request: $e');
    }
  }

  void _handleSyncComplete(Map<String, dynamic> data) {
    try {
      String nodeId = data['node_id'] ?? '';
      String userName = data['user_name'] ?? '';
      
      _isAuthenticated = true;
      _esp32NodeId = nodeId;
      _userName = userName;
      
      _addStatusLog('✅ ESP32 Authentication Complete!');
      _addStatusLog('Node ID: $nodeId');
      _addStatusLog('User: $userName');
      
      // Save authentication status
      _saveStoredData();
      
      notifyListeners();
      
    } catch (e) {
      _addErrorLog('Error handling sync complete: $e');
    }
  }

  // ============================================================================
  // MESSAGE HANDLING
  // ============================================================================
  
  Future<void> sendChatMessage({
    required String message,
    required String type,
    String receiverId = 'all',
  }) async {
    if (!_isConnected || !_isAuthenticated) {
      _addErrorLog('Cannot send message: Not connected or authenticated');
      return;
    }
    
    try {
      Map<String, dynamic> messageData = {
        'type': type,
        'sender_name': _userName,
        'sender_id': _esp32NodeId,
        'receiver_id': receiverId,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      _sendMessage(messageData);
      
      _addStatusLog('Sent $type message: $message');
      
    } catch (e) {
      _addErrorLog('Error sending chat message: $e');
    }
  }

  Future<void> sendGroupMessage(String message) async {
    await sendChatMessage(
      message: message,
      type: 'group',
      receiverId: 'all',
    );
  }

  Future<void> sendPrivateMessage(String message, String receiverId) async {
    await sendChatMessage(
      message: message,
      type: 'private',
      receiverId: receiverId,
    );
  }

  void _handleChatMessage(Map<String, dynamic> data) {
    try {
      String messageType = data['type'] ?? '';
      String senderName = data['sender_name'] ?? 'Unknown';
      String message = data['message'] ?? '';
      
      if (messageType == 'group') {
        _addStatusLog('📢 Group message from $senderName: $message');
      } else if (messageType == 'private') {
        String receiverId = data['receiver_id'] ?? '';
        _addStatusLog('💬 Private message from $senderName → $receiverId: $message');
      }
      
      // Forward to UI
      _messageController.add(data);
      
    } catch (e) {
      _addErrorLog('Error handling chat message: $e');
    }
  }

  void _sendMessage(Map<String, dynamic> data) {
    try {
      _channel.invokeMethod('sendMessage', data);
      
      String jsonMessage = json.encode(data);
      _addStatusLog('📤 Sent: $jsonMessage');
      
    } catch (e) {
      _addErrorLog('Error sending message: $e');
    }
  }

  // ============================================================================
  // PERSISTENT STORAGE
  // ============================================================================
  
  Future<void> _loadStoredData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      _esp32Mac = prefs.getString('esp32_mac') ?? '';
      _esp32NodeId = prefs.getString('esp32_node_id') ?? '';
      _isAuthenticated = prefs.getBool('esp32_authenticated') ?? false;
      
      if (_esp32Mac.isNotEmpty) {
        _addStatusLog('Loaded stored ESP32 data: $_esp32NodeId');
      }
      
    } catch (e) {
      _addErrorLog('Error loading stored data: $e');
    }
  }

  Future<void> _saveStoredData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      await prefs.setString('esp32_mac', _esp32Mac);
      await prefs.setString('esp32_node_id', _esp32NodeId);
      await prefs.setBool('esp32_authenticated', _isAuthenticated);
      
      _addStatusLog('Saved ESP32 data to storage');
      
    } catch (e) {
      _addErrorLog('Error saving data: $e');
    }
  }

  // ============================================================================
  // UTILITY FUNCTIONS
  // ============================================================================
  
  void _addStatusLog(String message) {
    String timestamp = DateTime.now().toString().substring(11, 19);
    String logMessage = '[$timestamp] $message';
    _statusController.add(logMessage);
    print('ESP32_BT: $logMessage');
  }

  void _addErrorLog(String message) {
    String timestamp = DateTime.now().toString().substring(11, 19);
    String logMessage = '[$timestamp] ERROR: $message';
    _statusController.add(logMessage);
    print('ESP32_BT_ERROR: $logMessage');
  }

  // ============================================================================
  // CLEANUP
  // ============================================================================
  
  @override
  void dispose() {
    _messageController.close();
    _statusController.close();
    super.dispose();
  }
}


