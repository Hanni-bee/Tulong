import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
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
  
  // Track connected users (users who have sent messages on the same channel)
  // Key: sender_email or sender_id, Value: sender_name (first_name)
  final Map<String, String> _connectedUsers = <String, String>{};

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
  List<String> get connectedUsers => _connectedUsers.values.toList();

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
      // Async function call to load first_name from database
      _loadUserNameFromDatabase();
      _addStatusLog('Connected to ESP32');
      
      // BYPASS AUTH: Auto-authenticate for testing
      _isAuthenticated = true;
      _esp32NodeId = 'ESP32_TEST';
      _userName = 'TestUser'; // Temporary, will be updated by _loadUserNameFromDatabase
      _addStatusLog('✅ Auto-authenticated (testing mode)');
      _addStatusLog('Loading user name from database...');
      
      // Still send auth request for ESP32 (non-blocking)
      _sendAuthRequest();
      
      // Request connected users list after a short delay to ensure connection is stable
      Future.delayed(const Duration(milliseconds: 800), () {
        if (_isConnected) {
          requestConnectedUsers();
        }
      });
    } else {
      _addStatusLog('Disconnected from ESP32');
      _isAuthenticated = false;
      _clearConnectedUsers();
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
        } else if (data.containsKey('connected_users')) {
          _handleConnectedUsersResponse(data);
        } else if (data.containsKey('type')) {
          // Handle chat messages (ignore voice messages)
          if (data['type'] != 'voice_message') {
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

  // Load user name (first_name) from database
  Future<void> _loadUserNameFromDatabase() async {
    String defaultUserName = 'TestUser'; // Fallback
    String? userEmail = '';
    
    // Get email from SharedPreferences (SQLite session, not Firebase)
    try {
      final prefs = await SharedPreferences.getInstance();
      userEmail = prefs.getString('session_email');
      _addStatusLog('📧 [_loadUserName] Session email from SharedPreferences: ${userEmail ?? 'null'}');
    } catch (e) {
      _addErrorLog('Error getting session_email from SharedPreferences: $e');
    }
    
    // If no email from SharedPreferences, try AuthProvider as fallback
    if (userEmail == null || userEmail.isEmpty) {
      final authProvider = AuthProvider();
      userEmail = authProvider.userEmail;
      _addStatusLog('⚠ [_loadUserName] No session_email in SharedPreferences, using AuthProvider.userEmail: ${userEmail ?? 'null'}');
    }
    
    if (userEmail != null && userEmail.isNotEmpty) {
      try {
        final sqliteService = SQLiteService();
        final user = await sqliteService.getUserByEmail(userEmail);
        if (user != null) {
          final firstName = user['first_name']?.toString();
          if (firstName != null && firstName.isNotEmpty && firstName.trim().isNotEmpty) {
            defaultUserName = firstName.trim();
            _userName = defaultUserName;
            _addStatusLog('✓✓✓ [_loadUserName] Updated userName to first_name from SQLite database: "$defaultUserName" ✓✓✓');
            notifyListeners();
          } else {
            _addStatusLog('⚠ [_loadUserName] User found in SQLite but first_name is empty');
          }
        } else {
          _addStatusLog('⚠ [_loadUserName] User not found in SQLite database for email: $userEmail');
        }
      } catch (e) {
        _addStatusLog('⚠ [_loadUserName] Could not fetch first_name from SQLite: $e, using: "$defaultUserName"');
      }
    } else {
      _addStatusLog('⚠ [_loadUserName] No userEmail available (neither SharedPreferences nor AuthProvider), using: "$defaultUserName"');
    }
    
    if (_userName == 'TestUser' && defaultUserName != 'TestUser') {
      _userName = defaultUserName;
      _addStatusLog('✓ Updated userName to: "$defaultUserName"');
      notifyListeners();
    }
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
      final String messageId = '${DateTime.now().millisecondsSinceEpoch}-${(_userName.isNotEmpty ? _userName[0] : 'U')}';
      
      // Get first_name from SQLite database (local device storage)
      // Get email from SharedPreferences (where it's saved during SQLite sign-in)
      String senderNameToUse = _userName; // Default fallback
      final sqliteService = SQLiteService();
      String? userEmail = '';
      
      // Get email from SharedPreferences (SQLite session, not Firebase)
      try {
        final prefs = await SharedPreferences.getInstance();
        userEmail = prefs.getString('session_email');
        _addStatusLog('📧 Session email from SharedPreferences: ${userEmail ?? 'null'}');
      } catch (e) {
        _addErrorLog('Error getting session_email from SharedPreferences: $e');
      }
      
      // If no email from SharedPreferences, try AuthProvider as fallback
      if (userEmail == null || userEmail.isEmpty) {
        final authProvider = AuthProvider();
        userEmail = authProvider.userEmail;
        _addStatusLog('⚠ No session_email in SharedPreferences, using AuthProvider.userEmail: ${userEmail ?? 'null'}');
      }
      
      // Try to get first_name from SQLite database
      bool foundFirstName = false;
      
      if (userEmail != null && userEmail.isNotEmpty) {
        try {
          final user = await sqliteService.getUserByEmail(userEmail);
          if (user != null) {
            final firstName = user['first_name']?.toString();
            if (firstName != null && firstName.isNotEmpty && firstName.trim().isNotEmpty) {
              senderNameToUse = firstName.trim();
              foundFirstName = true;
              _addStatusLog('📝 ✓✓✓ Using first_name from SQLite database: "$senderNameToUse" ✓✓✓');
            } else {
              _addStatusLog('⚠ User found in SQLite but first_name is empty or null');
            }
          } else {
            _addStatusLog('⚠ User not found in SQLite database for email: $userEmail');
            // Try to get all users and show them
            try {
              final allUsers = await sqliteService.getAllUsers();
              _addStatusLog('📋 SQLite database has ${allUsers.length} users');
              for (var u in allUsers.take(3)) {
                _addStatusLog('  - ${u['email']} -> ${u['first_name']} ${u['last_name']}');
              }
            } catch (_) {}
          }
        } catch (e) {
          _addErrorLog('Error fetching first_name from SQLite: $e');
        }
      } else {
        _addErrorLog('⚠⚠⚠ WARNING: No userEmail available (neither SharedPreferences nor AuthProvider)!');
      }
      
      if (!foundFirstName) {
        _addStatusLog('⚠⚠⚠ Using fallback sender_name: "$senderNameToUse"');
      }

      Map<String, dynamic> messageData = {
        'type': type,
        'sender_name': senderNameToUse,  // Use first_name from database
        'sender_id': _esp32NodeId,
        'sender_email': userEmail ?? '',  // Add email for database lookup
        'receiver_id': receiverId,
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
        'id': messageId,
      };
      
      _addStatusLog('📤 Message data: sender_name="$senderNameToUse", sender_email="${userEmail ?? 'EMPTY'}"');

      // Add current user to connected users list
      String userKey = userEmail ?? _esp32NodeId ?? senderNameToUse;
      if (userKey.isNotEmpty && senderNameToUse.isNotEmpty) {
        _connectedUsers[userKey] = senderNameToUse;
        _addStatusLog('📋 Added current user to connected users: $senderNameToUse');
      }

      // Optimistic append to store for instant UI
      final localData = Map<String, dynamic>.from(messageData)
        ..['isLocal'] = true;
      _messages.add(localData);
      _messagesStreamController.add(List<Map<String, dynamic>>.from(_messages));

      sendMessage(messageData);
      
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

  void _handleChatMessage(Map<String, dynamic> data) async {
    try {
      String messageType = data['type'] ?? '';
      String senderName = data['sender_name'] ?? 'Unknown';
      String message = data['message'] ?? '';
      String? senderEmail = data['sender_email']?.toString();
      String? senderId = data['sender_id']?.toString();

      // Track connected user (add to connected users map)
      if (senderName.isNotEmpty && senderName != 'Unknown') {
        // Use sender_email as key if available, otherwise use sender_id, otherwise use sender_name
        String userKey = senderEmail ?? senderId ?? senderName;
        if (userKey.isNotEmpty) {
          _connectedUsers[userKey] = senderName;
          _addStatusLog('📋 Added to connected users: $senderName (key: $userKey)');
        }
      }

      // Mark as remote by default unless explicitly local
      data['isLocal'] = data['isLocal'] == true;

      // If message is from another user (not local), fetch first_name from database
      if (!data['isLocal']) {
        final sqliteService = SQLiteService();
        String? firstName;
        
        _addStatusLog('🔍 Looking up first_name for sender: "$senderName"');
        
        // Strategy 1: If sender_name is already a first name (matches first_name in DB), use it
        // But first verify it exists in database to avoid using fake names like "TestUser"
        var allUsers = await sqliteService.getAllUsers();
        bool senderNameIsFirstName = false;
        
        for (var user in allUsers) {
          final dbFirstName = user['first_name']?.toString().toLowerCase() ?? '';
          if (dbFirstName == senderName.toLowerCase()) {
            senderNameIsFirstName = true;
            firstName = user['first_name']?.toString(); // Get original case
            _addStatusLog('✓ sender_name "$senderName" matches first_name in database');
            break;
          }
        }
        
        // Strategy 2: If sender_name matches a full name, get first_name
        if (!senderNameIsFirstName && firstName == null) {
          _addStatusLog('🔍 Checking if "$senderName" matches full name or email...');
          
          // Try matching by email first (if sender_email exists)
          String? senderEmail = data['sender_email']?.toString();
          if (senderEmail != null && senderEmail.isNotEmpty && senderEmail.contains('@')) {
            final user = await sqliteService.getUserByEmail(senderEmail);
            if (user != null) {
              firstName = user['first_name']?.toString();
              _addStatusLog('✓ Found first_name by email: $firstName');
            }
          }
          
          // Try matching sender_name as email
          if (firstName == null && senderName.contains('@')) {
            final user = await sqliteService.getUserByEmail(senderName);
            if (user != null) {
              firstName = user['first_name']?.toString();
              _addStatusLog('✓ Found first_name by sender_name (as email): $firstName');
            }
          }
          
          // Try matching by full name
          if (firstName == null) {
            for (var user in allUsers) {
              final dbFirstName = user['first_name']?.toString() ?? '';
              final dbLastName = user['last_name']?.toString() ?? '';
              final dbFullName = '$dbFirstName $dbLastName'.trim().toLowerCase();
              
              if (dbFullName == senderName.toLowerCase() || 
                  dbFirstName.toLowerCase() == senderName.toLowerCase()) {
                firstName = dbFirstName;
                _addStatusLog('✓ Found first_name by full name match: $firstName');
                break;
              }
            }
          }
          
          // If still not found, check if any user's first_name or full name contains senderName
          if (firstName == null) {
            for (var user in allUsers) {
              final dbFirstName = user['first_name']?.toString() ?? '';
              final dbLastName = user['last_name']?.toString() ?? '';
              final dbFullName = '$dbFirstName $dbLastName'.trim();
              
              // Check if senderName is part of full name or vice versa
              if (dbFullName.toLowerCase().contains(senderName.toLowerCase()) ||
                  senderName.toLowerCase().contains(dbFirstName.toLowerCase())) {
                firstName = dbFirstName;
                _addStatusLog('✓ Found first_name by partial match: $firstName');
                break;
              }
            }
          }
        }
        
        // Replace sender_name with first_name from database
        if (firstName != null && firstName.isNotEmpty) {
          data['sender_name'] = firstName;
          senderName = firstName;
          _addStatusLog('📝 ✓✓✓ Displaying first_name: "$senderName" ✓✓✓');
        } else {
          _addStatusLog('⚠ Could not find first_name for "$senderName" in database');
          _addStatusLog('📋 Available users in database:');
          for (var user in allUsers.take(5)) {
            final fname = user['first_name']?.toString() ?? 'no first_name';
            final lname = user['last_name']?.toString() ?? 'no last_name';
            final email = user['email']?.toString() ?? 'no email';
            _addStatusLog('  - $fname $lname ($email)');
          }
        }
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

  void sendMessage(Map<String, dynamic> data) {
    try {
      _channel.invokeMethod('sendMessage', data);
      
      String jsonMessage = json.encode(data);
      _addStatusLog('📤 Sent: $jsonMessage');
      
    } catch (e) {
      _addErrorLog('Error sending message: $e');
    }
  }

  // Request connected users list from ESP32
  void requestConnectedUsers() {
    if (!_isConnected) {
      _addErrorLog('Cannot request connected users: Not connected');
      return;
    }
    
    try {
      final request = {
        'type': 'request',
        'action': 'get_connected_users',
      };
      sendMessage(request);
      _addStatusLog('📋 Requesting connected users from ESP32...');
    } catch (e) {
      _addErrorLog('Error requesting connected users: $e');
    }
  }

  // Clear connected users (when disconnected)
  void _clearConnectedUsers() {
    _connectedUsers.clear();
    notifyListeners();
  }

  // Handle connected users response from ESP32
  void _handleConnectedUsersResponse(Map<String, dynamic> data) {
    try {
      if (data.containsKey('users') && data['users'] is List) {
        List<dynamic> users = data['users'];
        _connectedUsers.clear();
        
        for (var user in users) {
          if (user is Map<String, dynamic>) {
            String? userName = user['name']?.toString() ?? user['sender_name']?.toString() ?? user['first_name']?.toString();
            String? userKey = user['email']?.toString() ?? user['sender_email']?.toString() ?? user['nodeId']?.toString() ?? userName;
            
            if (userName != null && userName.isNotEmpty && userKey != null) {
              _connectedUsers[userKey] = userName;
            }
          }
        }
        
        _addStatusLog('📋 Updated connected users list: ${_connectedUsers.length} users');
        notifyListeners();
      }
    } catch (e) {
      _addErrorLog('Error handling connected users response: $e');
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
      
      if (_esp32Mac.isNotEmpty) {
        _addStatusLog('Loaded stored ESP32 data: $_esp32NodeId');
      }
      
      if (_pairedDeviceName.isNotEmpty) {
        _addStatusLog('✅ Previously paired: $_pairedDeviceName');
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


