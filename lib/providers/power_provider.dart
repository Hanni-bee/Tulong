import 'package:flutter/foundation.dart';

class PowerProvider extends ChangeNotifier {
  int _batteryLevel = 85;
  bool _isCharging = false;
  bool _isLowBattery = false;
  String _powerStatus = 'Normal';
  
  int get batteryLevel => _batteryLevel;
  bool get isCharging => _isCharging;
  bool get isLowBattery => _isLowBattery;
  String get powerStatus => _powerStatus;
  
  void updateBatteryLevel(int level) {
    _batteryLevel = level;
    _isLowBattery = level < 20;
    _powerStatus = _isLowBattery ? 'Low Battery' : 'Normal';
    notifyListeners();
  }
  
  void startCharging() {
    _isCharging = true;
    _powerStatus = 'Charging';
    notifyListeners();
  }
  
  void stopCharging() {
    _isCharging = false;
    _powerStatus = _isLowBattery ? 'Low Battery' : 'Normal';
    notifyListeners();
  }
  
  void simulateBatteryDrain() {
    if (_batteryLevel > 0 && !_isCharging) {
      _batteryLevel -= 1;
      _isLowBattery = _batteryLevel < 20;
      _powerStatus = _isLowBattery ? 'Low Battery' : 'Normal';
      notifyListeners();
    }
  }
  
  void emergencyPowerMode() {
    _powerStatus = 'Emergency Mode';
    notifyListeners();
  }
}
