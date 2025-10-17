import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

enum HardwareConnectionState {
  disconnected,
  connecting,
  connected,
  error,
  mockMode
}

enum LoRaConnectionState {
  disconnected,
  scanning,
  connected,
  transmitting,
  receiving,
  error
}

class HardwareService extends ChangeNotifier {
  static final HardwareService _instance = HardwareService._internal();
  factory HardwareService() => _instance;
  HardwareService._internal();

  // Connection states
  HardwareConnectionState _usbState = HardwareConnectionState.disconnected;
  LoRaConnectionState _loraState = LoRaConnectionState.disconnected;
  
  // Mock hardware state
  bool _isRecording = false;
  
  // Hardware info
  String _deviceName = 'TULONG_HARDWARE';
  String _firmwareVersion = '1.0.0';
  int _batteryLevel = 0;
  int _signalStrength = 0;
  
  // Mock mode for testing
  bool _mockMode = false;
  Timer? _mockTimer;

  // Getters
  HardwareConnectionState get usbState => _usbState;
  LoRaConnectionState get loraState => _loraState;
  bool get isConnected => _usbState == HardwareConnectionState.connected;
  bool get isLoRaConnected => _loraState == LoRaConnectionState.connected;
  String get deviceName => _deviceName;
  String get firmwareVersion => _firmwareVersion;
  int get batteryLevel => _batteryLevel;
  int get signalStrength => _signalStrength;
  bool get isRecording => _isRecording;
  bool get mockMode => _mockMode;

  // Initialize hardware service
  Future<void> initialize() async {
    if (kDebugMode) {
      print('🔧 Initializing Hardware Service...');
    }
    
    // Check permissions
    await _requestPermissions();
    
    // Start with mock mode for now
    enableMockMode();
  }

  // Request necessary permissions
  Future<void> _requestPermissions() async {
    final permissions = [
      Permission.microphone,
      Permission.storage,
    ];
    
    for (final permission in permissions) {
      final status = await permission.request();
      if (kDebugMode) {
        print('📋 Permission $permission: ${status.toString()}');
      }
    }
  }

  // Connect to hardware via USB (Mock implementation)
  Future<bool> connectToHardware() async {
    if (_mockMode) {
      return _startMockMode();
    }

    // For now, always start mock mode
    return _startMockMode();
  }

  // Start mock mode for testing
  bool _startMockMode() {
    _mockMode = true;
    _usbState = HardwareConnectionState.mockMode;
    _loraState = LoRaConnectionState.connected;
    _deviceName = 'TULONG_MOCK';
    _firmwareVersion = '1.0.0-MOCK';
    _batteryLevel = 85;
    _signalStrength = 75;
    
    // Simulate periodic updates
    _mockTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _simulateMockData();
    });
    
    notifyListeners();
    return true;
  }

  // Simulate mock data updates
  void _simulateMockData() {
    if (!_mockMode) return;
    
    // Simulate battery drain
    if (_batteryLevel > 20) {
      _batteryLevel = (_batteryLevel - 1).clamp(0, 100);
    }
    
    // Simulate signal strength changes
    _signalStrength = (75 + (DateTime.now().millisecond % 50 - 25)).clamp(0, 100);
    
    notifyListeners();
  }

  // Handle incoming data from hardware
  void _onDataReceived(Uint8List data) {
    final message = String.fromCharCodes(data);
    if (kDebugMode) {
      print('📨 Hardware data: $message');
    }
    
    _parseHardwareMessage(message);
  }

  // Parse messages from hardware
  void _parseHardwareMessage(String message) {
    final parts = message.trim().split(':');
    if (parts.length < 2) return;
    
    final command = parts[0];
    final data = parts[1];
    
    switch (command) {
      case 'STATUS':
        _parseStatusUpdate(data);
        break;
      case 'LORA':
        _parseLoRaStatus(data);
        break;
      case 'BATTERY':
        _batteryLevel = int.tryParse(data) ?? 0;
        break;
      case 'SIGNAL':
        _signalStrength = int.tryParse(data) ?? 0;
        break;
      case 'AUDIO':
        _handleAudioData(data);
        break;
      case 'MESSAGE':
        _handleReceivedMessage(data);
        break;
      case 'EMERGENCY':
        _handleEmergencySignal(data);
        break;
    }
    
    notifyListeners();
  }

  // Parse status update from hardware
  void _parseStatusUpdate(String data) {
    final statusParts = data.split(',');
    for (final part in statusParts) {
      final keyValue = part.split('=');
      if (keyValue.length == 2) {
        final key = keyValue[0];
        final value = keyValue[1];
        
        switch (key) {
          case 'NAME':
            _deviceName = value;
            break;
          case 'FW':
            _firmwareVersion = value;
            break;
          case 'BAT':
            _batteryLevel = int.tryParse(value) ?? 0;
            break;
          case 'SIG':
            _signalStrength = int.tryParse(value) ?? 0;
            break;
        }
      }
    }
  }

  // Parse LoRa status
  void _parseLoRaStatus(String data) {
    switch (data) {
      case 'CONNECTED':
        _loraState = LoRaConnectionState.connected;
        break;
      case 'SCANNING':
        _loraState = LoRaConnectionState.scanning;
        break;
      case 'TRANSMITTING':
        _loraState = LoRaConnectionState.transmitting;
        break;
      case 'RECEIVING':
        _loraState = LoRaConnectionState.receiving;
        break;
      case 'DISCONNECTED':
        _loraState = LoRaConnectionState.disconnected;
        break;
      case 'ERROR':
        _loraState = LoRaConnectionState.error;
        break;
    }
  }

  // Send command to hardware (Mock implementation)
  Future<void> _sendCommand(String command, [String? data]) async {
    if (!_mockMode) return;
    
    final message = data != null ? '$command:$data' : command;
    
    if (kDebugMode) {
      print('📤 Mock command sent: $message');
    }
  }

  // Start voice transmission (PTT)
  Future<void> startVoiceTransmission() async {
    _isRecording = true;
    _loraState = LoRaConnectionState.transmitting;
    
    // Send PTT start command to hardware
    await _sendCommand('PTT_START');
    
    if (kDebugMode) {
      print('🎤 Voice transmission started (Mock)');
    }
    
    notifyListeners();
  }

  // Stop voice transmission
  Future<void> stopVoiceTransmission() async {
    _isRecording = false;
    _loraState = LoRaConnectionState.connected;
    
    // Send PTT stop command to hardware
    await _sendCommand('PTT_STOP');
    
    if (kDebugMode) {
      print('🎤 Voice transmission stopped (Mock)');
    }
    
    notifyListeners();
  }

  // Send text message via LoRa
  Future<void> sendLoRaMessage(String message) async {
    await _sendCommand('LORA_SEND', message);
    
    if (kDebugMode) {
      print('📡 Sent LoRa message: $message');
    }
  }

  // Send emergency signal
  Future<void> sendEmergencySignal(String emergencyData) async {
    await _sendCommand('EMERGENCY', emergencyData);
    
    if (kDebugMode) {
      print('🚨 Sent emergency signal: $emergencyData');
    }
  }

  // Handle received audio data
  void _handleAudioData(String data) {
    // Process received audio data
    if (kDebugMode) {
      print('🔊 Received audio data');
    }
  }

  // Handle received message
  void _handleReceivedMessage(String data) {
    // Process received LoRa message
    if (kDebugMode) {
      print('📨 Received LoRa message: $data');
    }
  }

  // Handle emergency signal
  void _handleEmergencySignal(String data) {
    // Process emergency signal
    if (kDebugMode) {
      print('🚨 Received emergency signal: $data');
    }
  }

  // Enable mock mode for testing
  void enableMockMode() {
    disconnectFromHardware();
    _startMockMode();
    if (kDebugMode) {
      print('🧪 Mock mode enabled');
    }
  }

  // Disable mock mode
  void disableMockMode() {
    _mockMode = false;
    _mockTimer?.cancel();
    _mockTimer = null;
    _usbState = HardwareConnectionState.disconnected;
    _loraState = LoRaConnectionState.disconnected;
    notifyListeners();
  }

  // Disconnect from hardware
  Future<void> disconnectFromHardware() async {
    _mockTimer?.cancel();
    _mockTimer = null;
    
    if (_isRecording) {
      await stopVoiceTransmission();
    }
    
    _usbState = HardwareConnectionState.disconnected;
    _loraState = LoRaConnectionState.disconnected;
    _mockMode = false;
    notifyListeners();
    
    if (kDebugMode) {
      print('🔌 Hardware disconnected');
    }
  }

  @override
  void dispose() {
    disconnectFromHardware();
    super.dispose();
  }
}
