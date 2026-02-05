import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper class for requesting and checking runtime permissions
class PermissionHelper {
  static const String _permissionDialogShownKey = 'permission_dialog_shown';
  
  /// Request all vital permissions for the app
  /// Only shows the explanation dialog once for new users
  static Future<bool> requestAllPermissions(BuildContext context, {bool forceShowDialog = false}) async {
    // List of required permissions
    final permissions = [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
      Permission.locationWhenInUse,
      Permission.storage, // For older Android versions
      Permission.microphone,
      Permission.notification,
      Permission.camera, // For emergency detection feature
    ];
    
    // ENHANCED: For Android 13+, also check photos permission
    // Try to add photos permission (Android 13+) if available
    try {
      final photosStatus = await Permission.photos.status;
      // If photos permission exists, add it to the list
      if (!photosStatus.isGranted && !photosStatus.isLimited) {
        permissions.add(Permission.photos);
      }
    } catch (e) {
      // Photos permission not available on this platform/version, skip it
      debugPrint('Photos permission not available: $e');
    }
    
    // Check which permissions are not granted
    List<Permission> permissionsToRequest = [];
    for (var permission in permissions) {
      final status = await permission.status;
      if (!status.isGranted && !status.isLimited) {
        permissionsToRequest.add(permission);
      }
    }
    
    // If all granted, return true
    if (permissionsToRequest.isEmpty) {
      return true;
    }
    
    // Check if dialog has been shown before
    final prefs = await SharedPreferences.getInstance();
    final hasShownDialog = prefs.getBool(_permissionDialogShownKey) ?? false;
    
    // Only show explanation dialog for new users (first time) or if forced
    bool shouldRequest = true;
    if (!hasShownDialog || forceShowDialog) {
      if (context.mounted) {
        shouldRequest = await _showPermissionDialog(context);
        // Mark dialog as shown after user sees it (whether they grant or cancel)
        await prefs.setBool(_permissionDialogShownKey, true);
        if (!shouldRequest) {
          // User cancelled - still request permissions silently but return false
          // This way permissions are requested but we respect user's choice
          await permissionsToRequest.request();
          return false;
        }
      }
    }
    
    // Request permissions (silently if dialog was already shown)
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
          '• Camera - For emergency detection feature\n'
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
  
  /// Reset the permission dialog shown flag (useful for testing or if user wants to see it again)
  static Future<void> resetPermissionDialogFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_permissionDialogShownKey);
  }
  
  /// Check if permission dialog has been shown before
  static Future<bool> hasShownPermissionDialog() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_permissionDialogShownKey) ?? false;
  }
  
  /// Request camera permission specifically for emergency detection
  static Future<bool> requestCameraPermission(BuildContext context) async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      return true;
    }
    
    if (status.isPermanentlyDenied) {
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text('Camera Permission Required'),
            content: const Text(
              'Camera access is needed for emergency detection.\n\n'
              'Please enable it in:\n'
              'Settings → Apps → TULONG → Permissions → Camera',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
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
      return false;
    }
    
    final result = await Permission.camera.request();
    return result.isGranted;
  }

  /// Request storage permission for gallery image selection
  /// ENHANCED: Handles both Android 13+ (photos) and older versions (storage)
  /// CRITICAL: Always requests permission with proper dialog if needed
  static Future<bool> requestStoragePermission(BuildContext context) async {
    // For Android 13+, use photos permission
    // For older versions, use storage permission
    Permission permission = Permission.storage;
    
    // Try photos and videos permission (Android 13+)
    // Note: Android 13+ uses "Photos and Videos" permission for gallery access
    // If it fails or is not available, we'll use storage
    try {
      final photosStatus = await Permission.photos.status;
      // If photos permission exists, use it
      if (photosStatus.isGranted || photosStatus.isLimited || photosStatus.isDenied || photosStatus.isPermanentlyDenied) {
        permission = Permission.photos;
        debugPrint('📸 Using Photos and Videos permission (Android 13+)');
      }
    } catch (e) {
      // Photos permission not available on this platform/version, use storage
      debugPrint('📁 Photos and Videos permission not available, using storage permission (Android < 13)');
      permission = Permission.storage;
    }
    
    // Check current status
    final status = await permission.status;
    debugPrint('📊 Current permission status: $status');
    
    // If already granted or limited, return true
    if (status.isGranted || status.isLimited) {
      debugPrint('✅ Permission already granted');
      return true;
    }
    
    // If permanently denied, show settings dialog
    if (status.isPermanentlyDenied) {
      debugPrint('⚠️ Permission permanently denied, showing settings dialog');
      if (context.mounted) {
        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text('Storage Permission Required'),
            content: const Text(
              'Storage access is needed to select images from gallery.\n\n'
              'Please enable it in:\n'
              'Settings → Apps → TULONG → Permissions → Photos and Videos (Android 13+)\n'
              'or Storage (Android < 13)',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, true);
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
        
        if (shouldOpenSettings == true) {
          await openAppSettings();
        }
      }
      return false;
    }
    
    // Request permission (this will show system dialog)
    debugPrint('🔄 Requesting permission...');
    final result = await permission.request();
    debugPrint('📊 Permission request result: $result');
    
    // Check final status
    final finalStatus = await permission.status;
    final granted = finalStatus.isGranted || finalStatus.isLimited;
    
    if (granted) {
      debugPrint('✅ Permission granted');
    } else {
      debugPrint('❌ Permission denied');
      if (context.mounted && !finalStatus.isPermanentlyDenied) {
        // Show explanation if denied but not permanently
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission is required to select images from gallery'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
    
    return granted;
  }
}

