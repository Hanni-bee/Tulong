import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/simple_bluetooth_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../utils/permission_helper.dart';
import '../widgets/special_animations.dart';

/// ESP32 Device Scanner - In-app Bluetooth pairing and connection
class ESP32DeviceScanner extends StatefulWidget {
  const ESP32DeviceScanner({super.key});

  @override
  State<ESP32DeviceScanner> createState() => _ESP32DeviceScannerState();
}

class _ESP32DeviceScannerState extends State<ESP32DeviceScanner> 
    with TickerProviderStateMixin {
  
  List<Map<String, String>> _availableDevices = [];
  bool _isScanning = false;
  String _selectedDevice = '';
  bool _showAllDevices = false;
  
  @override
  void initState() {
    super.initState();
    
    // Auto-scan on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScan();
    });
  }
  
  Future<void> _startScan() async {
    // Check permissions first
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
    });
    
    HapticFeedback.mediumImpact();
    
    try {
      // Use SimpleBluetoothService to scan for devices
      final btService = Provider.of<SimpleBluetoothService>(context, listen: false);
      final devices = await btService.scanDevices();
      
      if (mounted) {
        setState(() {
          _availableDevices = devices;
          _isScanning = false;
          _showAllDevices = false; // Reset show all when scanning again
        });
        
        if (_availableDevices.isEmpty) {
          _showError('No ESP32 devices found. Make sure they are powered on.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isScanning = false);
        _showError('Scan failed: $e');
      }
    }
  }
  
  Future<void> _pairAndConnect(String deviceName, String deviceAddress) async {
    setState(() => _selectedDevice = deviceName);
    HapticFeedback.mediumImpact();
    
    try {
      // Show pairing dialog
      _showPairingDialog(deviceName);
      
      // Use SimpleBluetoothService to pair
      final btService = Provider.of<SimpleBluetoothService>(context, listen: false);
      final paired = await btService.pairDevice(deviceName, deviceAddress);
      
      // Close pairing dialog
      if (mounted) Navigator.pop(context);
      
      if (paired == true) {
        // Success - save paired device info
        if (mounted) {
          final btService = Provider.of<SimpleBluetoothService>(context, listen: false);
          
          // Save to local storage so it stays paired
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('paired_device_name', deviceName);
          await prefs.setString('paired_device_address', deviceAddress);
          
          _showSuccess('✓ Paired with $deviceName! Connecting...');
          
          // Wait a bit then connect
          await Future.delayed(const Duration(milliseconds: 500));
          
          final connected = await btService.connectToESP32();
          
          if (connected && mounted) {
            _showSuccess('✓ Connected to $deviceName!');
            await Future.delayed(const Duration(seconds: 1));
            Navigator.pop(context); // Go back to chat
          } else {
            _showError('Connected but authentication failed');
          }
        }
      } else {
        _showError('Pairing failed. Try again.');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close pairing dialog
        _showError('Error: $e');
      }
    } finally {
      setState(() => _selectedDevice = '');
    }
  }
  
  void _showPairingDialog(String deviceName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Pairing with $deviceName...'),
            const SizedBox(height: 8),
            Text(
              'Please accept pairing request if prompted',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.mediumGray,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isScanning 
                  ? _buildScanningIndicator()
                  : _availableDevices.isEmpty
                      ? _buildEmptyState()
                      : _buildDeviceListWithSections(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Available Devices',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Tap to pair and connect',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.mediumGray,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.refresh,
              color: _isScanning ? AppColors.mediumGray : AppColors.online,
            ),
            onPressed: _isScanning ? null : _startScan,
          ),
        ],
      ),
    );
  }
  
  Widget _buildScanningIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScanningAnimation(
            glowColor: AppColors.online,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.online.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.online.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.bluetooth_searching,
                size: 50,
                color: AppColors.online,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Scanning for ESP32 devices...',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.darkGray,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure your ESP32 is powered on',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.mediumGray,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bluetooth_disabled,
                size: 50,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No ESP32 Devices Found',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Make sure your ESP32 is:\n'
              '• Powered on\n'
              '• Running the firmware\n'
              '• Within range (< 10 meters)',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.mediumGray,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _startScan,
              icon: const Icon(Icons.refresh),
              label: const Text('Scan Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.online,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Separate devices into paired and nearby
  List<Map<String, String>> get _pairedDevices {
    return _availableDevices.where((d) => d['bonded'] == 'true').toList();
  }
  
  List<Map<String, String>> get _nearbyDevices {
    return _availableDevices.where((d) => d['bonded'] != 'true').toList();
  }
  
  // Get devices to display - show 6 total initially, then all when showAll is true
  Widget _buildDeviceListWithSections() {
    final pairedDevices = _pairedDevices;
    final nearbyDevices = _nearbyDevices;
    final allDevices = [...pairedDevices, ...nearbyDevices];
    final totalCount = allDevices.length;
    
    // Calculate how many devices to show from each section
    int pairedToShowCount = 0;
    int nearbyToShowCount = 0;
    int remainingTotal = 0;
    
    if (_showAllDevices || totalCount <= 6) {
      // Show all devices
      pairedToShowCount = pairedDevices.length;
      nearbyToShowCount = nearbyDevices.length;
      remainingTotal = 0;
    } else {
      // Show up to 6 total devices
      int shown = 0;
      if (shown < 6 && pairedDevices.isNotEmpty) {
        pairedToShowCount = (6 - shown).clamp(0, pairedDevices.length);
        shown += pairedToShowCount;
      }
      if (shown < 6 && nearbyDevices.isNotEmpty) {
        nearbyToShowCount = (6 - shown).clamp(0, nearbyDevices.length);
        shown += nearbyToShowCount;
      }
      remainingTotal = totalCount - 6;
    }
    
    final pairedToShow = pairedDevices.take(pairedToShowCount).toList();
    final nearbyToShow = nearbyDevices.take(nearbyToShowCount).toList();
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Paired Devices Section
        if (pairedDevices.isNotEmpty) ...[
          _buildSectionHeader('Paired Devices', pairedDevices.length),
          const SizedBox(height: 12),
          ...pairedToShow.map((device) => _buildDeviceItem(device)),
          const SizedBox(height: 24),
        ],
        
        // Nearby Devices Section
        if (nearbyDevices.isNotEmpty) ...[
          _buildSectionHeader('Nearby Devices', nearbyDevices.length),
          const SizedBox(height: 12),
          ...nearbyToShow.map((device) => _buildDeviceItem(device)),
        ],
        
        // Show more button (appears after all sections if there are more devices)
        if (remainingTotal > 0 && !_showAllDevices)
          _buildShowMoreButton(remainingTotal, () {
            setState(() {
              _showAllDevices = true;
            });
          }),
      ],
    );
  }
  
  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.darkGray,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primaryRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: AppColors.primaryRed,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Spacer(),
        Text(
          title == 'Paired Devices' 
              ? 'Previously linked devices'
              : 'Visible nearby devices',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.mediumGray,
          ),
        ),
      ],
    );
  }
  
  Widget _buildShowMoreButton(int remainingCount, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Center(
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: Text(
            'Show more ($remainingCount)',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.primaryRed,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildDeviceItem(Map<String, String> device) {
    final deviceName = device['name'] ?? 'Unknown';
    final deviceAddress = device['address'] ?? '';
    final isPaired = device['bonded'] == 'true';
    final isSelected = _selectedDevice == deviceName;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected 
              ? AppColors.online 
              : isPaired
                  ? AppColors.success.withOpacity(0.3)
                  : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
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
            color: (isPaired ? AppColors.success : AppColors.online).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isPaired ? Icons.bluetooth_connected : Icons.bluetooth,
            color: isPaired ? AppColors.success : AppColors.online,
            size: 30,
          ),
        ),
        title: Text(
          deviceName,
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              deviceAddress,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.mediumGray,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (isPaired ? AppColors.success : AppColors.warning).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isPaired ? 'Paired' : 'Available',
                style: TextStyle(
                  color: isPaired ? AppColors.success : AppColors.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        trailing: isSelected
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(
                Icons.arrow_forward_ios,
                size: 20,
                color: AppColors.mediumGray,
              ),
        onTap: isSelected ? null : () {
          _pairAndConnect(deviceName, deviceAddress);
        },
      ),
    );
  }
}

