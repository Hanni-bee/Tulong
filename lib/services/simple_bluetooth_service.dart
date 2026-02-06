import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/storage_keys.dart';
import '../providers/auth_provider.dart';
import '../utils/emergency_message_parser.dart';
import '../services/sqlite_service.dart';

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
  String _pairedDeviceName = '';
  String _pairedDeviceAddress = '';
  
  // ESP32 flash memory counts
  int _esp32ProfileSavedCount = 0;
  int _esp32SosSavedCount = 0;
  
  // Connected users from ESP32
  List<Map<String, dynamic>> _connectedUsers = [];

  // ============================================================================
  // MESSAGE HANDLING
  // ============================================================================
  
  final StreamController<Map<String, dynamic>> _messageController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _statusController = 
      StreamController<String>.broadcast();

  // =========================================================================
  // MESSAGE STORE (Single source of truth for chat UI)
  // =========================================================================

  final List<Map<String, dynamic>> _messages = <Map<String, dynamic>>[];
  final StreamController<List<Map<String, dynamic>>> _messagesStreamController =
      StreamController<List<Map<String, dynamic>>>.broadcast();

  // ============================================================================
  // GETTERS
  // ============================================================================
  
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  bool get isAuthenticated => _isAuthenticated;
  String get connectionStatus => _connectionStatus;
  String get lastError => _lastError;
  String get esp32NodeId => _esp32NodeId;
  String get pairedDeviceName => _pairedDeviceName;
  String get pairedDeviceAddress => _pairedDeviceAddress;
  String get esp32Mac => _esp32Mac;
  String get userName => _userName;
  
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<String> get statusStream => _statusController.stream;
  Stream<List<Map<String, dynamic>>> get messagesStream => _messagesStreamController.stream;
  List<Map<String, dynamic>> get messages => List.unmodifiable(_messages);
  List<Map<String, dynamic>> get connectedUsers => List.unmodifiable(_connectedUsers);

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
      print('🔵 [CONNECTION] ESP32 Connected - State changed to connected');
      _addStatusLog('Connected to ESP32');
      
      // BYPASS AUTH: Auto-authenticate for testing
      _isAuthenticated = true;
      _esp32NodeId = 'ESP32_TEST';
      _userName = 'TestUser';
      _addStatusLog('✅ Auto-authenticated (testing mode)');
      _addStatusLog('Ready to send/receive messages!');
      
      print('🔵 [CONNECTION] Authentication set to true, triggering data sync...');
      
      // Still send auth request for ESP32 (non-blocking)
      _sendAuthRequest();
      
      // Trigger sync after connection
      print('🔵 [SYNC] Calling _triggerDataSync()...');
      _triggerDataSync();
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
      final Map<String, dynamic> wrapper = Map<String, dynamic>.from(arguments);
      
      // Kotlin sends {"message": "JSON_STRING"}
      // We need to parse the JSON string inside
      if (wrapper.containsKey('message')) {
        final String messageJson = wrapper['message'] as String;
        _addStatusLog('Raw RX: $messageJson');
        
        // Parse the JSON string
        final Map<String, dynamic> data = json.decode(messageJson);
        
        if (data.containsKey('auth_request')) {
          _handleAuthRequest(data);
        } else if (data.containsKey('sync_complete')) {
          _handleSyncComplete(data);
        } else if (data.containsKey('profile_saved_count')) {
          _handleProfileSavedCount(data).catchError((e) {
            _addErrorLog('Error in profile saved count handler: $e');
          });
        } else if (data.containsKey('sos_saved_count')) {
          _handleSosSavedCount(data).catchError((e) {
            _addErrorLog('Error in SOS saved count handler: $e');
          });
        } else if (data.containsKey('discovered_users')) {
          _handleDiscoveredUsers(data);
        } else if (data.containsKey('type')) {
          if (data['type'] == 'voice_message') {
            _handleVoiceMessage(data);
          } else {
            _handleChatMessage(data);
          }
        } else if (data.containsKey('ack')) {
          // Acknowledgment, just log it
          _addStatusLog('✓ ESP32 acknowledged');
        } else {
          _addStatusLog('Unknown message type: $messageJson');
        }
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
  // DEVICE SCANNING AND PAIRING
  // ============================================================================
  
  Future<List<Map<String, String>>> scanDevices() async {
    try {
      _addStatusLog('Scanning for ESP32 devices...');
      
      final devices = await _channel.invokeMethod<List>('scanDevices');
      
      if (devices != null) {
        final deviceList = devices
            .map((d) => Map<String, String>.from(d as Map))
            .where((d) => d['name']?.startsWith('ESP32_Node') ?? false)
            .toList();
        
        _addStatusLog('Found ${deviceList.length} ESP32 device(s)');
        return deviceList;
      }
      
      return [];
    } catch (e) {
      _addErrorLog('Error scanning devices: $e');
      return [];
    }
  }
  
  Future<bool> pairDevice(String name, String address) async {
    try {
      _addStatusLog('Pairing with $name...');
      
      final result = await _channel.invokeMethod<bool>('pairDevice', {
        'name': name,
        'address': address,
      });
      
      if (result == true) {
        _addStatusLog('✓ Paired with $name');
        await savePairedDevice(name, address);
        return true;
      } else {
        _addErrorLog('Pairing failed');
        return false;
      }
    } catch (e) {
      _addErrorLog('Error pairing device: $e');
      return false;
    }
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
      
      _addStatusLog('Searching for ESP32 device...');
      
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
      
      sendMessage(authResponse);
      
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
      
      // Trigger sync after authentication
      _triggerDataSync();
      
      notifyListeners();
      
    } catch (e) {
      _addErrorLog('Error handling sync complete: $e');
    }
  }

  Future<void> _handleProfileSavedCount(Map<String, dynamic> data) async {
    try {
      final count = data['profile_saved_count'] as int? ?? 0;
      _esp32ProfileSavedCount = count;
      await _saveStoredData();
      _addStatusLog('✅ Profile saved to ESP32 flash (count: $count)');
      notifyListeners();
    } catch (e) {
      _addErrorLog('Error handling profile saved count: $e');
    }
  }

  Future<void> _handleSosSavedCount(Map<String, dynamic> data) async {
    try {
      final count = data['sos_saved_count'] as int? ?? 0;
      _esp32SosSavedCount = count;
      await _saveStoredData();
      _addStatusLog('✅ SOS message saved to ESP32 flash (count: $count)');
      notifyListeners();
    } catch (e) {
      _addErrorLog('Error handling SOS saved count: $e');
    }
  }

  void _handleDiscoveredUsers(Map<String, dynamic> data) {
    try {
      if (data.containsKey('users') && data['users'] is List) {
        final List<dynamic> usersList = data['users'];
        _connectedUsers = usersList.map((user) {
          return Map<String, dynamic>.from(user as Map);
        }).toList();
        
        _addStatusLog('📡 Discovered ${_connectedUsers.length} user(s)');
        notifyListeners();
      }
    } catch (e) {
      _addErrorLog('Error handling discovered users: $e');
    }
  }

  // Request discovered users from ESP32
  Future<void> requestDiscoveredUsers() async {
    if (!_isConnected || !_isAuthenticated) {
      _addErrorLog('Cannot request users: Not connected or authenticated');
      return;
    }
    
    try {
      sendMessage({'discover_users': true});
      _addStatusLog('📡 Requesting discovered users...');
    } catch (e) {
      _addErrorLog('Error requesting discovered users: $e');
    }
  }

  // ============================================================================
  // MESSAGE HANDLING
  // ============================================================================
  
  Future<void> sendChatMessage({
    required String message,
    required String type,
    String receiverId = 'all',
    bool isEmergency = false, // Flag for emergency messages from SOS ring
    Map<String, dynamic>? additionalData, // For emergency detection metadata
  }) async {
    if (!_isConnected || !_isAuthenticated) {
      _addErrorLog('Cannot send message: Not connected or authenticated');
      return;
    }
    
    try {
      final String messageId = '${DateTime.now().millisecondsSinceEpoch}-${(_userName.isNotEmpty ? _userName[0] : 'U')}';

      Map<String, dynamic> messageData = {
        'type': type,
        'sender_name': _userName,
        'sender_id': _esp32NodeId,
        'receiver_id': receiverId,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
        'id': messageId,
        'is_emergency': isEmergency, // Add emergency flag to message data
      };

      // Add additional data (e.g., emergency detection metadata)
      if (additionalData != null) {
        messageData.addAll(additionalData);
      }

      // Optimistic append to store for instant UI
      final localData = Map<String, dynamic>.from(messageData)
        ..['isLocal'] = true;
      _messages.add(localData);
      _messagesStreamController.add(List<Map<String, dynamic>>.from(_messages));

      sendMessage(messageData);
      
      _addStatusLog('Sent ${isEmergency ? "EMERGENCY " : ""}$type message: $message');
      
    } catch (e) {
      _addErrorLog('Error sending chat message: $e');
    }
  }

  Future<void> sendGroupMessage(String message, {bool isEmergency = false, Map<String, dynamic>? additionalData}) async {
    await sendChatMessage(
      message: message,
      type: 'group',
      receiverId: 'all',
      isEmergency: isEmergency,
      additionalData: additionalData,
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

      // Mark as remote by default unless explicitly local
      data['isLocal'] = data['isLocal'] == true;

      // Check if message is an emergency detection
      try {
        if (EmergencyMessageParser.isEmergencyMessage(message)) {
          data['isEmergency'] = true;
          // Try to parse emergency detection
          final emergencyResult = EmergencyMessageParser.parseFromMessage(message);
          if (emergencyResult != null) {
            data['emergency_detection'] = emergencyResult.toJson();
          }
        }
      } catch (e) {
        // Ignore emergency parsing errors, treat as regular message
      }

      if (messageType == 'group') {
        _addStatusLog('📢 Group message from $senderName: $message');
      } else if (messageType == 'private') {
        String receiverId = data['receiver_id'] ?? '';
        _addStatusLog('💬 Private message from $senderName → $receiverId: $message');
      }

      // Push to old per-message stream (backwards compatibility)
      _messageController.add(data);

      // Append to message store and notify list stream
      _messages.add(Map<String, dynamic>.from(data));
      _messagesStreamController.add(List<Map<String, dynamic>>.from(_messages));

    } catch (e) {
      _addErrorLog('Error handling chat message: $e');
    }
  }

  void _handleVoiceMessage(Map<String, dynamic> data) {
    try {
      String messageId = data['messageId'] ?? 'unknown';
      String fromNode = data['from_node'] ?? 'unknown';
      
      _addStatusLog('🎵 Voice message received from $fromNode (ID: $messageId)');
      
      // Push to message stream for voice controller to handle
      _messageController.add(data);
      
      // Also add to message store for UI display
      _messages.add(Map<String, dynamic>.from(data));
      _messagesStreamController.add(List<Map<String, dynamic>>.from(_messages));
      
    } catch (e) {
      _addErrorLog('Error handling voice message: $e');
    }
  }

  void sendMessage(Map<String, dynamic> data) {
    try {
      String jsonMessage = json.encode(data);
      
      // Debug logging before sending
      print('🔍 [SEND] sendMessage() called with data: $data');
      print('I/flutter: 🔍 [SEND] Data map: $data');
      print('🔍 [SEND] JSON encoded message: $jsonMessage');
      print('I/flutter: 🔍 [SEND] JSON string: $jsonMessage');
      _addStatusLog('🔍 [DEBUG] Invoking sendMessage via platform channel');
      
      print('🔍 [SEND] Invoking platform channel method: sendMessage');
      _channel.invokeMethod('sendMessage', data);
      print('✅ [SEND] Platform channel invokeMethod completed');
      
      _addStatusLog('📤 Sent via Bluetooth: $jsonMessage');
      print('✅ [SEND] Message sent successfully via platform channel');
      print('I/flutter: ✅ [SEND] Message forwarded to ESP32');
      
    } catch (e) {
      _addErrorLog('❌ Error sending message: $e');
      print('❌ [DEBUG] sendMessage() error: $e');
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
      _pairedDeviceName = prefs.getString('paired_device_name') ?? '';
      _pairedDeviceAddress = prefs.getString('paired_device_address') ?? '';
      _esp32ProfileSavedCount = prefs.getInt('esp32_profile_saved_count') ?? 0;
      _esp32SosSavedCount = prefs.getInt('esp32_sos_saved_count') ?? 0;
      
      if (_esp32Mac.isNotEmpty) {
        _addStatusLog('Loaded stored ESP32 data: $_esp32NodeId');
      }
      
      if (_pairedDeviceName.isNotEmpty) {
        _addStatusLog('✅ Previously paired: $_pairedDeviceName');
      }
      
      if (_esp32ProfileSavedCount > 0 || _esp32SosSavedCount > 0) {
        _addStatusLog('ESP32 flash counts - Profile: $_esp32ProfileSavedCount, SOS: $_esp32SosSavedCount');
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
      await prefs.setString('paired_device_name', _pairedDeviceName);
      await prefs.setString('paired_device_address', _pairedDeviceAddress);
      await prefs.setInt('esp32_profile_saved_count', _esp32ProfileSavedCount);
      await prefs.setInt('esp32_sos_saved_count', _esp32SosSavedCount);
      
      _addStatusLog('Saved ESP32 data to storage');
      
    } catch (e) {
      _addErrorLog('Error saving data: $e');
    }
  }
  
  Future<void> savePairedDevice(String name, String address) async {
    _pairedDeviceName = name;
    _pairedDeviceAddress = address;
    await _saveStoredData();
    _addStatusLog('✅ Saved paired device: $name');
    notifyListeners();
  }
  
  Future<void> clearPairedDevice() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('paired_device_name');
      await prefs.remove('paired_device_address');
      
      _pairedDeviceName = '';
      _pairedDeviceAddress = '';
      _addStatusLog('Cleared paired device');
      notifyListeners();
    } catch (e) {
      _addErrorLog('Error clearing paired device: $e');
    }
  }

  // ============================================================================
  // DATA SYNC TO ESP32 FLASH MEMORY
  // ============================================================================
  
  /// Trigger data sync to ESP32 flash memory
  /// Checks if first-time connect or if counts changed
  Future<void> _triggerDataSync() async {
    print('🔵 [SYNC] _triggerDataSync() called');
    print('🔵 [SYNC] Connection status - isConnected: $_isConnected, isAuthenticated: $_isAuthenticated');
    
    if (!_isConnected || !_isAuthenticated) {
      print('❌ [SYNC] Cannot sync: Not connected or authenticated');
      _addStatusLog('⚠️ Cannot sync: Not connected or authenticated');
      return;
    }
    
    try {
      final authProvider = AuthProvider();
      print('🔵 [SYNC] AuthProvider userUsername: ${authProvider.userUsername}');
      
      if (authProvider.userUsername == null) {
        print('❌ [SYNC] Cannot sync: No user logged in');
        _addStatusLog('⚠️ Cannot sync: No user logged in');
        return;
      }
      
      // Check if first-time connect (no previous authentication)
      final prefs = await SharedPreferences.getInstance();
      final wasAuthenticatedBefore = prefs.getBool('esp32_authenticated') ?? false;
      
      print('🔵 [SYNC] wasAuthenticatedBefore: $wasAuthenticatedBefore');
      
      if (!wasAuthenticatedBefore) {
        // First time connecting - send all data
        print('🆕 [SYNC] FIRST TIME CONNECTION - Will forward all data to ESP32');
        _addStatusLog('🆕 FIRST TIME CONNECTION DETECTED - Forwarding all data to ESP32 flash');
        _addStatusLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('🆕 [SYNC] Calling syncProfileDataToESP32()...');
        await syncProfileDataToESP32();
        _addStatusLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('🆕 [SYNC] Calling syncSosMessageToESP32()...');
        await syncSosMessageToESP32();
        _addStatusLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      } else {
        // Subsequent connection - check if counts changed
        print('🔄 [SYNC] SUBSEQUENT CONNECTION - Checking for updates...');
        _addStatusLog('🔄 SUBSEQUENT CONNECTION - Checking for updates...');
        final sqliteService = SQLiteService();
        final updateCounts = await sqliteService.getUpdateCounts(authProvider.userUsername!);
        
        print('🔵 [SYNC] Update counts from DB: $updateCounts');
        
        if (updateCounts != null) {
          final appProfileCount = updateCounts['profile_update_count'] as int? ?? 0;
          final appSosCount = updateCounts['sos_message_update_count'] as int? ?? 0;
          
          print('🔵 [SYNC] App counts - Profile: $appProfileCount, SOS: $appSosCount');
          print('🔵 [SYNC] ESP32 counts - Profile: $_esp32ProfileSavedCount, SOS: $_esp32SosSavedCount');
          
          _addStatusLog('   App counts - Profile: $appProfileCount, SOS: $appSosCount');
          _addStatusLog('   ESP32 counts - Profile: $_esp32ProfileSavedCount, SOS: $_esp32SosSavedCount');
          
          // Compare with ESP32 saved counts
          if (appProfileCount > _esp32ProfileSavedCount) {
            print('📝 [SYNC] Profile update detected! ($appProfileCount > $_esp32ProfileSavedCount) - Will sync profile');
            _addStatusLog('📝 Profile update detected ($appProfileCount > $_esp32ProfileSavedCount)');
            _addStatusLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
            print('📝 [SYNC] Calling syncProfileDataToESP32()...');
            await syncProfileDataToESP32();
            _addStatusLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          } else {
            print('✓ [SYNC] Profile count unchanged ($appProfileCount) - skipping profile sync');
            _addStatusLog('✓ Profile count unchanged ($appProfileCount) - skipping profile sync');
          }
          
          if (appSosCount > _esp32SosSavedCount) {
            print('📝 [SYNC] SOS update detected! ($appSosCount > $_esp32SosSavedCount) - Will sync SOS');
            _addStatusLog('📝 SOS update detected ($appSosCount > $_esp32SosSavedCount)');
            _addStatusLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
            print('📝 [SYNC] Calling syncSosMessageToESP32()...');
            await syncSosMessageToESP32();
            _addStatusLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          } else {
            print('✓ [SYNC] SOS count unchanged ($appSosCount) - skipping SOS sync');
            _addStatusLog('✓ SOS count unchanged ($appSosCount) - skipping SOS sync');
          }
        } else {
          // No update counts record - send all data
          _addStatusLog('⚠️ No update counts record found - Forwarding all data to ESP32 flash');
          _addStatusLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          await syncProfileDataToESP32();
          _addStatusLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          await syncSosMessageToESP32();
          _addStatusLog('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        }
      }
    } catch (e) {
      _addErrorLog('Error triggering data sync: $e');
    }
  }
  
  /// Sync profile data to ESP32 flash memory
  Future<void> syncProfileDataToESP32() async {
    if (!_isConnected || !_isAuthenticated) {
      _addErrorLog('Cannot sync profile: Not connected or authenticated');
      return;
    }
    
    try {
      final authProvider = AuthProvider();
      final userModel = authProvider.currentUserModel;
      
      if (userModel == null) {
        _addErrorLog('Cannot sync profile: No user model available');
        return;
      }
      
      // Get profile data (name, username, street, province, city, barangay)
      final name = userModel.name ?? '';
      final username = userModel.username ?? '';
      final street = userModel.street ?? '';
      final province = userModel.province ?? '';
      final city = userModel.city ?? '';
      final barangay = userModel.barangay ?? '';
      
      final profileData = {
        'command': 'sync_profile',
        'data': {
          'name': name,
          'username': username,
          'street': street,
          'province': province,
          'city': city,
          'barangay': barangay,
        }
      };
      
      // Log profile data being forwarded
      _addStatusLog('📤 FORWARDING PROFILE DATA TO ESP32 FLASH MEMORY');
      _addStatusLog('   Name: $name');
      _addStatusLog('   Username: $username');
      _addStatusLog('   Street: $street');
      _addStatusLog('   Province: $province');
      _addStatusLog('   City: $city');
      _addStatusLog('   Barangay: $barangay');
      
      // Debug: Print exact JSON being sent
      final jsonString = json.encode(profileData);
      print('🔍 [PROFILE SYNC] Sending sync_profile command: $jsonString');
      print('I/flutter: 🔍 [PROFILE SYNC] JSON payload: $jsonString');
      _addStatusLog('🔍 [DEBUG] JSON payload: $jsonString');
      
      print('🔍 [PROFILE SYNC] Calling sendMessage() with profileData...');
      sendMessage(profileData);
      print('✅ [PROFILE SYNC] sendMessage() completed');
      
      _addStatusLog('✅ Profile data forwarded to ESP32 successfully');
      
    } catch (e) {
      _addErrorLog('❌ Error syncing profile data: $e');
    }
  }
  
  /// Sync SOS message to ESP32 flash memory (includes AI severity and timestamp for [SOS_META])
  Future<void> syncSosMessageToESP32() async {
    if (!_isConnected || !_isAuthenticated) {
      _addErrorLog('Cannot sync SOS: Not connected or authenticated');
      return;
    }

    try {
      final authProvider = AuthProvider();
      final sosMessage = authProvider.emergencyMessage ?? 'I need help. Please contact me immediately.';

      final prefs = await SharedPreferences.getInstance();
      final severity = prefs.getString(StorageKeys.userCurrentStatus)?.trim();
      final timestampMs = prefs.getInt(StorageKeys.userStatusLastUpdated);
      final severityValue = (severity != null && severity.isNotEmpty)
          ? severity.toUpperCase()
          : 'LOW';
      final timestampValue = (timestampMs != null && timestampMs > 0)
          ? timestampMs
          : DateTime.now().millisecondsSinceEpoch;

      final sosData = {
        'command': 'sync_sos',
        'message': sosMessage,
        'severity': severityValue,
        'timestamp_ms': timestampValue,
      };

      // Log SOS message being forwarded
      _addStatusLog('📤 FORWARDING SOS MESSAGE TO ESP32 FLASH MEMORY');
      _addStatusLog('   Message: "$sosMessage"');
      _addStatusLog('   severity=$severityValue timestamp_ms=$timestampValue');
      _addStatusLog('   Message length: ${sosMessage.length} characters');
      
      // Debug: Print exact JSON being sent
      final jsonString = json.encode(sosData);
      print('🔍 [SOS SYNC] Sending sync_sos command: $jsonString');
      print('I/flutter: 🔍 [SOS SYNC] JSON payload: $jsonString');
      _addStatusLog('🔍 [DEBUG] JSON payload: $jsonString');
      
      print('🔍 [SOS SYNC] Calling sendMessage() with sosData...');
      sendMessage(sosData);
      print('✅ [SOS SYNC] sendMessage() completed');
      
      _addStatusLog('✅ SOS message forwarded to ESP32 successfully');
      
    } catch (e) {
      _addErrorLog('❌ Error syncing SOS message: $e');
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
    print('I/flutter: ESP32_BT: $logMessage'); // Ensure it shows in Flutter logs
  }

  void _addErrorLog(String message) {
    String timestamp = DateTime.now().toString().substring(11, 19);
    String logMessage = '[$timestamp] ERROR: $message';
    _statusController.add(logMessage);
    print('ESP32_BT_ERROR: $logMessage');
    print('I/flutter: ESP32_BT_ERROR: $logMessage'); // Ensure it shows in Flutter logs
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


