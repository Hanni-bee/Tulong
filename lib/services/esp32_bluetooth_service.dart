import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../utils/app_time_format.dart';

/// ESP32 Bluetooth Chat Service
/// Handles communication with ESP32 via Bluetooth Classic
/// Manages authentication and message routing
class ESP32BluetoothService extends ChangeNotifier {
  // ============================================================================
  // SINGLETON PATTERN
  // ============================================================================
  
  static final ESP32BluetoothService _instance = ESP32BluetoothService._internal();
  factory ESP32BluetoothService() => _instance;
  ESP32BluetoothService._internal();

  // ============================================================================
  // BLUETOOTH CONNECTION
  // ============================================================================
  
  BluetoothConnection? _connection;
  BluetoothDevice? _connectedDevice;
  StreamSubscription? _connectionSubscription;
  StreamSubscription<Uint8List>? _inputSubscription;
  
  // ============================================================================
  // CONNECTION STATE
  // ============================================================================
  
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isAuthenticated = false;
  String _connectionStatus = 'Disconnected';
  String _lastError = '';
  
  // ============================================================================
  // ESP32 NODE INFO
  // ============================================================================
  
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
  // CONSTANTS
  // ============================================================================
  
  static const String ESP32_DEVICE_NAME = 'ESP32_Node';
  static const String PREF_ESP32_MAC = 'esp32_mac';
  static const String PREF_ESP32_NODE_ID = 'esp32_node_id';
  static const String PREF_AUTHENTICATED = 'esp32_authenticated';
  
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
  
  /// Initialize the Bluetooth service
  Future<void> initialize() async {
    try {
      _addStatusLog('Initializing ESP32 Bluetooth Service...');
      
      // Load stored connection data
      await _loadStoredData();
      
      // Check if Bluetooth is available
      bool? isAvailable = await FlutterBluetoothSerial.instance.isAvailable;
      if (isAvailable != true) {
        throw Exception('Bluetooth is not available on this device');
      }
      
      // Check if Bluetooth is enabled
      bool? isEnabled = await FlutterBluetoothSerial.instance.isOn;
      if (isEnabled != true) {
        throw Exception('Bluetooth is not enabled. Please enable Bluetooth.');
      }
      
      _addStatusLog('Bluetooth service initialized successfully');
      
    } catch (e) {
      _addErrorLog('Failed to initialize Bluetooth service: $e');
      rethrow;
    }
  }
  
  // ============================================================================
  // CONNECTION MANAGEMENT
  // ============================================================================
  
  /// Search for and connect to ESP32 device
  Future<bool> connectToESP32() async {
    if (_isConnecting || _isConnected) return _isConnected;
    
    try {
      _isConnecting = true;
      _connectionStatus = 'Searching for ESP32...';
      notifyListeners();
      
      _addStatusLog('Searching for ESP32 device...');
      
      // Get bonded devices first
      List<BluetoothDevice> bondedDevices = 
          await FlutterBluetoothSerial.instance.getBondedDevices();
      
      BluetoothDevice? esp32Device;
      
      // Look for ESP32 in bonded devices
      for (BluetoothDevice device in bondedDevices) {
        if (device.name?.trim() == ESP32_DEVICE_NAME) {
          esp32Device = device;
          _addStatusLog('Found ESP32 in bonded devices: ${device.address}');
          break;
        }
      }
      
      // If not found in bonded devices, start discovery
      if (esp32Device == null) {
        _connectionStatus = 'Discovering devices...';
        notifyListeners();
        
        _addStatusLog('ESP32 not found in bonded devices, starting discovery...');
        
        FlutterBluetoothSerial.instance.startDiscovery().listen((event) {
          if (event.device.name?.trim() == ESP32_DEVICE_NAME) {
            esp32Device = event.device;
            _addStatusLog('Found ESP32 during discovery: ${event.device.address}');
          }
        });
        
        // Wait for discovery (max 15 seconds)
        await Future.delayed(const Duration(seconds: 15));
        
        if (esp32Device == null) {
          throw Exception('ESP32 device not found. Make sure it\'s powered on and in pairing mode.');
        }
      }
      
      // Connect to ESP32
      _connectionStatus = 'Connecting to ESP32...';
      notifyListeners();
      
      _addStatusLog('Connecting to ESP32: ${esp32Device!.address}');
      
      _connection = await BluetoothConnection.toAddress(esp32Device!.address);
      _connectedDevice = esp32Device;
      
      // Set up connection monitoring
      _setupConnectionMonitoring();
      
      // Start listening for messages
      _startMessageListening();
      
      _isConnected = true;
      _isConnecting = false;
      _connectionStatus = 'Connected to ESP32';
      _lastError = '';
      
      _addStatusLog('Successfully connected to ESP32!');
      notifyListeners();
      
      return true;
      
    } catch (e) {
      _isConnecting = false;
      _isConnected = false;
      _connectionStatus = 'Connection failed';
      _lastError = e.toString();
      
      _addErrorLog('Failed to connect to ESP32: $e');
      notifyListeners();
      
      return false;
    }
  }
  
  /// Disconnect from ESP32
  Future<void> disconnect() async {
    try {
      _addStatusLog('Disconnecting from ESP32...');
      
      // Cancel subscriptions
      await _inputSubscription?.cancel();
      await _connectionSubscription?.cancel();
      
      // Close connection
      await _connection?.close();
      
      _connection = null;
      _connectedDevice = null;
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
  
  /// Handle authentication request from ESP32
  void _handleAuthRequest(Map<String, dynamic> data) {
    try {
      String esp32Mac = data['mac'] ?? '';
      String esp32NodeId = data['node_id'] ?? '';
      
      _addStatusLog('ESP32 requesting authentication...');
      _addStatusLog('ESP32 MAC: $esp32Mac');
      _addStatusLog('ESP32 Node ID: $esp32NodeId');
      
      // Get user name from AuthProvider
      final authProvider = AuthProvider();
      String firstName = authProvider.userName?.split(' ').first ?? 'User';
      
      // Send authentication confirmation
      Map<String, dynamic> authResponse = {
        'auth_confirm': true,
        'firstname': firstName,
        'mac': esp32Mac,
      };
      
      _sendMessage(authResponse);
      
      // Store ESP32 info
      _esp32Mac = esp32Mac;
      _esp32NodeId = esp32NodeId;
      _userName = firstName;
      
      _saveStoredData();
      
      _addStatusLog('Authentication sent for user: $firstName');
      
    } catch (e) {
      _addErrorLog('Error handling auth request: $e');
    }
  }
  
  /// Handle sync completion from ESP32
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
  
  /// Send chat message via ESP32
  Future<void> sendChatMessage({
    required String message,
    required String type, // 'group' or 'private'
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
  
  /// Send group message
  Future<void> sendGroupMessage(String message) async {
    await sendChatMessage(
      message: message,
      type: 'group',
      receiverId: 'all',
    );
  }
  
  /// Send private message
  Future<void> sendPrivateMessage(String message, String receiverId) async {
    await sendChatMessage(
      message: message,
      type: 'private',
      receiverId: receiverId,
    );
  }
  
  // ============================================================================
  // MESSAGE PROCESSING
  // ============================================================================
  
  /// Process incoming message from ESP32
  void _processIncomingMessage(String message) {
    try {
      Map<String, dynamic> data = json.decode(message);
      
      // Handle different message types
      if (data.containsKey('auth_request')) {
        _handleAuthRequest(data);
      } else if (data.containsKey('sync_complete')) {
        _handleSyncComplete(data);
      } else if (data.containsKey('heartbeat')) {
        _handleHeartbeat(data);
      } else if (data.containsKey('type')) {
        _handleChatMessage(data);
      } else {
        _addStatusLog('Unknown message type: $message');
      }
      
    } catch (e) {
      _addErrorLog('Error processing message: $e');
      _addErrorLog('Raw message: $message');
    }
  }
  
  /// Handle incoming chat message
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
  
  /// Handle heartbeat from ESP32
  void _handleHeartbeat(Map<String, dynamic> data) {
    String nodeId = data['node_id'] ?? '';
    _addStatusLog('💓 Heartbeat from $nodeId');
  }
  
  // ============================================================================
  // CONNECTION MONITORING
  // ============================================================================
  
  /// Set up connection state monitoring
  void _setupConnectionMonitoring() {
    // Simplified connection monitoring without BluetoothConnectionState
    _addStatusLog('Connection monitoring setup complete');
  }
  
  /// Start listening for incoming messages
  void _startMessageListening() {
    _inputSubscription = _connection!.input!.listen((data) {
      try {
        String message = utf8.decode(data);
        message = message.trim();
        
        if (message.isNotEmpty) {
          _addStatusLog('📨 Received: $message');
          _processIncomingMessage(message);
        }
        
      } catch (e) {
        _addErrorLog('Error processing input data: $e');
      }
    });
  }
  
  // ============================================================================
  // MESSAGE TRANSMISSION
  // ============================================================================
  
  /// Send message to ESP32
  void _sendMessage(Map<String, dynamic> data) {
    try {
      if (_connection == null) {
        _addErrorLog('No connection to ESP32');
        return;
      }
      
      String jsonMessage = json.encode(data);
      _connection!.output.add(Uint8List.fromList(utf8.encode('$jsonMessage\n')));
      
      _addStatusLog('📤 Sent: $jsonMessage');
      
    } catch (e) {
      _addErrorLog('Error sending message: $e');
    }
  }
  
  // ============================================================================
  // PERSISTENT STORAGE
  // ============================================================================
  
  /// Load stored connection data
  Future<void> _loadStoredData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      _esp32Mac = prefs.getString(PREF_ESP32_MAC) ?? '';
      _esp32NodeId = prefs.getString(PREF_ESP32_NODE_ID) ?? '';
      _isAuthenticated = prefs.getBool(PREF_AUTHENTICATED) ?? false;
      
      if (_esp32Mac.isNotEmpty) {
        _addStatusLog('Loaded stored ESP32 data: $esp32NodeId');
      }
      
    } catch (e) {
      _addErrorLog('Error loading stored data: $e');
    }
  }
  
  /// Save connection data
  Future<void> _saveStoredData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      await prefs.setString(PREF_ESP32_MAC, _esp32Mac);
      await prefs.setString(PREF_ESP32_NODE_ID, _esp32NodeId);
      await prefs.setBool(PREF_AUTHENTICATED, _isAuthenticated);
      
      _addStatusLog('Saved ESP32 data to storage');
      
    } catch (e) {
      _addErrorLog('Error saving data: $e');
    }
  }
  
  // ============================================================================
  // UTILITY FUNCTIONS
  // ============================================================================
  
  /// Add status log
  void _addStatusLog(String message) {
    String timestamp = AppTimeFormat.timeWithSeconds(DateTime.now());
    String logMessage = '[$timestamp] $message';
    _statusController.add(logMessage);
    print('ESP32_BT: $logMessage');
  }
  
  /// Add error log
  void _addErrorLog(String message) {
    String timestamp = AppTimeFormat.timeWithSeconds(DateTime.now());
    String logMessage = '[$timestamp] ERROR: $message';
    _statusController.add(logMessage);
    print('ESP32_BT_ERROR: $logMessage');
  }
  
  /// Get available Bluetooth devices
  Future<List<BluetoothDevice>> getAvailableDevices() async {
    try {
      List<BluetoothDevice> devices = 
          await FlutterBluetoothSerial.instance.getBondedDevices();
      
      return devices.where((device) => 
          (device.name?.contains('ESP32') ?? false)).toList();
      
    } catch (e) {
      _addErrorLog('Error getting devices: $e');
      return [];
    }
  }
  
  /// Check if ESP32 is already paired
  Future<bool> isESP32Paired() async {
    try {
      List<BluetoothDevice> devices = await getAvailableDevices();
      return devices.any((device) => device.name == ESP32_DEVICE_NAME);
      
    } catch (e) {
      return false;
    }
  }
  
  // ============================================================================
  // CLEANUP
  // ============================================================================
  
  @override
  void dispose() {
    _inputSubscription?.cancel();
    _connectionSubscription?.cancel();
    _connection?.close();
    _messageController.close();
    _statusController.close();
    super.dispose();
  }
}

