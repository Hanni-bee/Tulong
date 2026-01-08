import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/simple_bluetooth_service.dart';
import '../constants/app_colors.dart';
import '../constants/unified_typography.dart';
import '../utils/permission_helper.dart';

/// ESP32 Device Scanner Modal - Shows available ESP32 devices to pair and connect
class ConnectedUsersModal extends StatefulWidget {
  const ConnectedUsersModal({super.key});

  @override
  State<ConnectedUsersModal> createState() => _ConnectedUsersModalState();
}

class _ConnectedUsersModalState extends State<ConnectedUsersModal> {
  List<Map<String, String>> _availableDevices = [];
  bool _isScanning = false;
  String _selectedDevice = '';
  String _statusMessage = 'Initializing...';

  @override
  void initState() {
    super.initState();
    // Auto-start scan
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScan();
    });
  }

  Future<void> _startScan() async {
    // Check permissions
    if (!await PermissionHelper.hasBluetoothPermissions()) {
      if (mounted) {
        final granted = await PermissionHelper.requestBluetoothPermissions(context);
        if (!granted) {
          _showError('Bluetooth permissions required');
          return;
        }
      }
    }
    
    setState(() {
      _isScanning = true;
      _availableDevices.clear();
      _statusMessage = 'Searching for devices...';
    });
    
    HapticFeedback.mediumImpact();
    
    try {
      final btService = Provider.of<SimpleBluetoothService>(context, listen: false);
      final devices = await btService.scanDevices();
      
      if (mounted) {
        setState(() {
          _availableDevices = devices;
          _isScanning = false;
          _statusMessage = devices.isEmpty 
              ? 'No devices found' 
              : 'Found ${devices.length} device(s)';
        });
        
        if (_availableDevices.isEmpty) {
          _showError('No ESP32 devices found. Make sure they are powered on.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _statusMessage = 'Scan failed';
        });
        _showError('Scan failed: $e');
      }
    }
  }

  Future<void> _pairAndConnect(String deviceName, String deviceAddress) async {
    setState(() {
      _selectedDevice = deviceName;
      _statusMessage = 'Pairing with $deviceName...';
    });
    
    HapticFeedback.mediumImpact();
    
    try {
      final btService = Provider.of<SimpleBluetoothService>(context, listen: false);
      final paired = await btService.pairDevice(deviceName, deviceAddress);
      
      if (paired == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('paired_device_name', deviceName);
        await prefs.setString('paired_device_address', deviceAddress);
        
        setState(() {
          _statusMessage = 'Connecting...';
        });
        
        await Future.delayed(const Duration(milliseconds: 500));
        
        final connected = await btService.connectToESP32();
        
        if (connected && mounted) {
          _showSuccess('✓ Connected to $deviceName!');
          await Future.delayed(const Duration(seconds: 1));
          Navigator.pop(context);
        } else {
          _showError('Connection failed');
        }
      } else {
        _showError('Pairing failed. Try again.');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _selectedDevice = '';
          if (!_isScanning) {
            _statusMessage = _availableDevices.isEmpty 
                ? 'No devices found' 
                : 'Found ${_availableDevices.length} device(s)';
          }
        });
      }
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 500),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.info,
                    AppColors.info.withOpacity(0.8),
                  ],
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.bluetooth_searching,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Search for Devices',
                          style: UnifiedTypography.titleLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _statusMessage,
                          style: UnifiedTypography.bodySmall.copyWith(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Device list
            Expanded(
              child: _isScanning || _availableDevices.isEmpty
                  ? _buildScanningIndicator()
                  : _buildDeviceList(),
            ),
            
            // Retry button
            if (!_isScanning && _availableDevices.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _startScan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.info,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Retry Finding Device'),
                        SizedBox(width: 8),
                        Icon(Icons.refresh),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningIndicator() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.info.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: _isScanning
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.info),
                      ),
                    )
                  : Icon(
                      Icons.bluetooth_disabled,
                      size: 50,
                      color: AppColors.info,
                    ),
            ),
            const SizedBox(height: 24),
            Text(
              _isScanning ? 'Scanning for ESP32 devices...' : 'No devices found',
              style: UnifiedTypography.titleMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isScanning
                  ? 'Make sure your ESP32 is powered on'
                  : 'Try scanning again or check your device',
              style: UnifiedTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _availableDevices.length,
      itemBuilder: (context, index) {
        final device = _availableDevices[index];
        final deviceName = device['name'] ?? 'Unknown Device';
        final deviceAddress = device['address'] ?? '';
        final isSelected = _selectedDevice == deviceName;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected 
                  ? AppColors.info 
                  : Colors.grey.withOpacity(0.2),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.bluetooth,
                color: AppColors.info,
                size: 28,
              ),
            ),
            title: Text(
              deviceName,
              style: UnifiedTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                deviceAddress,
                style: UnifiedTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            trailing: isSelected
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.arrow_forward_ios,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
            onTap: isSelected ? null : () {
              _pairAndConnect(deviceName, deviceAddress);
            },
          ),
        );
      },
    );
  }
}


      },
    );
  }
}

