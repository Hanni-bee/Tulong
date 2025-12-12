import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'notification_service.dart';
import 'dart:convert';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal() {
    _connectionChecker = InternetConnectionChecker.createInstance();
  }

  final Connectivity _connectivity = Connectivity();
  late final InternetConnectionChecker _connectionChecker;
  
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;
  
  bool _isConnected = false;
  bool _previousConnectionState = false;
  bool _isInitialized = false;
  bool get isConnected => _isConnected;

  // Initialize network monitoring
  Future<void> initialize() async {
    // Check initial connection
    await _checkConnection();
    _previousConnectionState = _isConnected;
    _isInitialized = true;
    
    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _checkConnection();
    });
    
    // Listen to internet connection changes
    _connectionChecker.onStatusChange.listen((InternetConnectionStatus status) {
      _updateConnectionStatus(status == InternetConnectionStatus.connected);
    });
  }

  // Check if device has internet connection
  Future<void> _checkConnection() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();

      // If no connectivity results or all are none
      if (connectivityResults.isEmpty || connectivityResults.every((result) => result == ConnectivityResult.none)) {
        _updateConnectionStatus(false);
        return;
      }

      // Check if we can actually reach the internet
      final hasInternet = await _connectionChecker.hasConnection;
      _updateConnectionStatus(hasInternet);
    } catch (e) {
      _updateConnectionStatus(false);
    }
  }

  // Update connection status
  void _updateConnectionStatus(bool connected) {
    if (_isConnected != connected) {
      final wasConnected = _previousConnectionState;
      _isConnected = connected;
      _connectionController.add(_isConnected);
      
      print('🌐 Network status changed: ${_isConnected ? "Connected" : "Disconnected"}');
      
      // Show notification for connection status change
      _showNetworkStatusNotification(connected, wasConnected);
      _previousConnectionState = connected;
    }
  }
  
  Future<void> _showNetworkStatusNotification(bool isConnected, bool wasConnected) async {
    // Don't show notification on initial state
    if (!_isInitialized) {
      return;
    }
    
    try {
      final notificationService = NotificationService();
      
      if (isConnected && !wasConnected) {
        // Connection restored
        await notificationService.showSystemNotification(
          title: '🌐 Connection Restored',
          body: 'You are back online',
          payload: jsonEncode({
            'type': 'network',
            'status': 'connected',
            'timestamp': DateTime.now().toIso8601String(),
          }),
        );
      } else if (!isConnected && wasConnected) {
        // Connection lost
        await notificationService.showSystemNotification(
          title: '⚠️ Connection Lost',
          body: 'You are now offline',
          payload: jsonEncode({
            'type': 'network',
            'status': 'disconnected',
            'timestamp': DateTime.now().toIso8601String(),
          }),
        );
      }
    } catch (e) {
      print('Error showing network status notification: $e');
    }
  }

  // Check if device is online
  Future<bool> isOnline() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }
      
      return await _connectionChecker.hasConnection;
    } catch (e) {
      return false;
    }
  }

  // Get connection type
  Future<String> getConnectionType() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();

      // Return the first available connection type
      if (connectivityResults.contains(ConnectivityResult.wifi)) {
        return 'WiFi';
      } else if (connectivityResults.contains(ConnectivityResult.mobile)) {
        return 'Mobile Data';
      } else if (connectivityResults.contains(ConnectivityResult.ethernet)) {
        return 'Ethernet';
      } else if (connectivityResults.contains(ConnectivityResult.bluetooth)) {
        return 'Bluetooth';
      } else if (connectivityResults.contains(ConnectivityResult.vpn)) {
        return 'VPN';
      } else if (connectivityResults.contains(ConnectivityResult.other)) {
        return 'Other';
      } else {
        return 'No Connection';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  // Dispose
  void dispose() {
    _connectionController.close();
  }
}
