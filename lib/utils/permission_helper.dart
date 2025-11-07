import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Helper class for requesting and checking runtime permissions
class PermissionHelper {
  
  /// Request all vital permissions for the app
  static Future<bool> requestAllPermissions(BuildContext context) async {
    // List of required permissions
    final permissions = [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
      Permission.locationWhenInUse,
      Permission.storage,
      Permission.microphone,
      Permission.notification,
    ];
    
    // Check which permissions are not granted
    List<Permission> permissionsToRequest = [];
    for (var permission in permissions) {
      final status = await permission.status;
      if (!status.isGranted) {
        permissionsToRequest.add(permission);
      }
    }
    
    // If all granted, return true
    if (permissionsToRequest.isEmpty) {
      return true;
    }
    
    // Show explanation dialog
    if (context.mounted) {
      final shouldRequest = await _showPermissionDialog(context);
      if (!shouldRequest) return false;
    }
    
    // Request permissions
    Map<Permission, PermissionStatus> statuses = await permissionsToRequest.request();
    
    // Check if all are granted
    bool allGranted = true;
    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        allGranted = false;
      }
    });
    
    return allGranted;
  }
  
  /// Request Bluetooth-specific permissions
  static Future<bool> requestBluetoothPermissions(BuildContext context) async {
    // Bluetooth permissions
    final permissions = [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location, // Required for Bluetooth on Android
    ];
    
    // Check current status
    List<Permission> toRequest = [];
    for (var permission in permissions) {
      final status = await permission.status;
      if (!status.isGranted) {
        toRequest.add(permission);
      }
    }
    
    if (toRequest.isEmpty) return true;
    
    // Show explanation
    if (context.mounted) {
      final shouldRequest = await _showBluetoothPermissionDialog(context);
      if (!shouldRequest) return false;
    }
    
    // Request
    Map<Permission, PermissionStatus> statuses = await toRequest.request();
    
    // Check results
    bool allGranted = true;
    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        allGranted = false;
      }
    });
    
    if (!allGranted && context.mounted) {
      _showPermissionDeniedDialog(context);
    }
    
    return allGranted;
  }
  
  /// Check if Bluetooth permissions are granted
  static Future<bool> hasBluetoothPermissions() async {
    final bluetoothConnect = await Permission.bluetoothConnect.isGranted;
    final bluetoothScan = await Permission.bluetoothScan.isGranted;
    final location = await Permission.location.isGranted;
    
    return bluetoothConnect && bluetoothScan && location;
  }
  
  /// Show permission explanation dialog
  static Future<bool> _showPermissionDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Permissions Required'),
        content: const Text(
          'TULONG needs the following permissions to work properly:\n\n'
          '• Bluetooth - To connect with ESP32 device\n'
          '• Location - Required for Bluetooth scanning\n'
          '• Storage - To save messages and media\n'
          '• Microphone - For walkie-talkie feature\n'
          '• Notifications - For emergency alerts\n\n'
          'These permissions are essential for disaster communication.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Grant Permissions'),
          ),
        ],
      ),
    ) ?? false;
  }
  
  /// Show Bluetooth permission explanation
  static Future<bool> _showBluetoothPermissionDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.bluetooth, color: Colors.blue),
            SizedBox(width: 8),
            Text('Bluetooth Permissions'),
          ],
        ),
        content: const Text(
          'To connect with your ESP32 device, TULONG needs:\n\n'
          '✓ Bluetooth permissions - To scan and connect\n'
          '✓ Location permission - Required by Android for Bluetooth\n\n'
          'Without these, offline messaging won\'t work.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow'),
          ),
        ],
      ),
    ) ?? false;
  }
  
  /// Show permission denied dialog
  static Future<void> _showPermissionDeniedDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Permissions Denied'),
        content: const Text(
          'Some permissions were denied. You can grant them later in:\n\n'
          'Settings → Apps → TULONG → Permissions',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}

