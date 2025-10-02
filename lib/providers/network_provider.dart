import 'package:flutter/foundation.dart';

class NetworkProvider extends ChangeNotifier {
  bool _isConnected = false;
  int _connectedUsers = 0;
  String _networkStatus = 'Disconnected';
  List<String> _connectedDevices = [];
  
  bool get isConnected => _isConnected;
  int get connectedUsers => _connectedUsers;
  String get networkStatus => _networkStatus;
  List<String> get connectedDevices => _connectedDevices;
  
  void connectToNetwork() {
    _isConnected = true;
    _networkStatus = 'Connected';
    _connectedUsers = 42; // Simulate connected users
    _connectedDevices = [
      'Device 1',
      'Device 2', 
      'Device 3',
      'Device 4',
      'Device 5',
    ];
    notifyListeners();
  }
  
  void disconnectFromNetwork() {
    _isConnected = false;
    _networkStatus = 'Disconnected';
    _connectedUsers = 0;
    _connectedDevices.clear();
    notifyListeners();
  }
  
  void addDevice(String deviceId) {
    if (!_connectedDevices.contains(deviceId)) {
      _connectedDevices.add(deviceId);
      _connectedUsers = _connectedDevices.length;
      notifyListeners();
    }
  }
  
  void removeDevice(String deviceId) {
    _connectedDevices.remove(deviceId);
    _connectedUsers = _connectedDevices.length;
    notifyListeners();
  }
  
  void updateNetworkStatus(String status) {
    _networkStatus = status;
    notifyListeners();
  }
}
