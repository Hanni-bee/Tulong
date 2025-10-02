import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

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
  bool get isConnected => _isConnected;

  // Initialize network monitoring
  Future<void> initialize() async {
    // Check initial connection
    await _checkConnection();
    
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
      _isConnected = connected;
      _connectionController.add(_isConnected);
      
      print('🌐 Network status changed: ${_isConnected ? "Connected" : "Disconnected"}');
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
