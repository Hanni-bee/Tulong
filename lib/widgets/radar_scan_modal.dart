import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import '../constants/app_colors.dart';

class RadarScanModal extends StatefulWidget {
  final VoidCallback onPairedDevicesTap;
  
  const RadarScanModal({super.key, required this.onPairedDevicesTap});

  @override
  State<RadarScanModal> createState() => _RadarScanModalState();
}

class _RadarScanModalState extends State<RadarScanModal> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String _scanStatus = 'Scanning for nearby devices...';
  Timer? _statusTimer;
  StreamSubscription<BluetoothDiscoveryResult>? _discoverySubscription;
  BluetoothState? _bluetoothState;
  
  final List<BluetoothDiscoveryResult> _discoveredDevices = [];
  bool _isScanning = false;
  int _scanProgress = 0;
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  final List<String> _statusMessages = [
    'Scanning for nearby devices...',
    'Looking for ESP32 devices...',
    'Analyzing signal strength...',
    'Discovering available channels...',
  ];
  
  List<BluetoothDiscoveryResult> get _filteredDiscoveredDevices {
    if (_searchQuery.isEmpty) {
      // Filter to only show ESP32 devices
      return _discoveredDevices.where((result) {
        final name = result.device.name?.toLowerCase() ?? '';
        return name.contains('esp32') || name.contains('esp_32');
      }).toList();
    }
    return _discoveredDevices.where((result) {
      final name = result.device.name?.toLowerCase() ?? '';
      final address = result.device.address.toLowerCase();
      final query = _searchQuery.toLowerCase();
      final isESP32 = name.contains('esp32') || name.contains('esp_32');
      return isESP32 && (name.contains(query) || address.contains(query));
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Initialize search listener
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    
    // Start dynamic scanning for ESP32 devices
    _startDynamicScan();
    
    // Update status text based on scan progress
    _statusTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (!mounted || !_isScanning) return;
      setState(() {
        _scanProgress = (_scanProgress + 1) % _statusMessages.length;
        _updateScanStatus();
      });
    });
  }
  
  void _updateScanStatus() {
    if (_discoveredDevices.isEmpty) {
      _scanStatus = _statusMessages[_scanProgress];
    } else if (_discoveredDevices.length == 1) {
      _scanStatus = 'Found 1 device';
    } else {
      _scanStatus = 'Found ${_discoveredDevices.length} devices';
    }
  }
  
  Future<void> _startDynamicScan() async {
    setState(() {
      _isScanning = true;
      _discoveredDevices.clear();
      _scanStatus = 'Initializing scan...';
    });
    
    try {
      // Check Bluetooth state
      _bluetoothState = await FlutterBluetoothSerial.instance.state;
      
      if (_bluetoothState != BluetoothState.STATE_ON) {
        setState(() {
          _scanStatus = 'Please enable Bluetooth';
          _isScanning = false;
        });
        return;
      }
      
      setState(() {
        _scanStatus = 'Starting discovery...';
      });
      
      // Start discovery subscription
      _discoverySubscription = FlutterBluetoothSerial.instance.startDiscovery().listen(
        (BluetoothDiscoveryResult result) {
          if (!mounted) return;
          
          setState(() {
            // Only add ESP32 devices
            final name = result.device.name?.toLowerCase() ?? '';
            final isESP32 = name.contains('esp32') || name.contains('esp_32');
            
            if (isESP32 && !_discoveredDevices.any((d) => d.device.address == result.device.address)) {
              _discoveredDevices.add(result);
              _updateScanStatus();
            }
          });
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            _isScanning = false;
            if (_discoveredDevices.isEmpty) {
              _scanStatus = 'No devices found';
            } else {
              _scanStatus = 'Scan complete: ${_discoveredDevices.length} device(s)';
            }
          });
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _isScanning = false;
            _scanStatus = 'Scan error: ${error.toString()}';
          });
        },
      );
      
      // Only discover ESP32 devices, don't load paired devices here
      
      // Stop discovery after 10 seconds
      Timer(const Duration(seconds: 10), () {
        if (_discoverySubscription != null) {
          FlutterBluetoothSerial.instance.cancelDiscovery();
          _discoverySubscription?.cancel();
          if (mounted) {
            setState(() {
              _isScanning = false;
              _updateScanStatus();
            });
          }
        }
      });
      
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _scanStatus = 'Error: ${e.toString()}';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _statusTimer?.cancel();
    _discoverySubscription?.cancel();
    _searchController.dispose();
    FlutterBluetoothSerial.instance.cancelDiscovery();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Scanning Area',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _scanStatus,
                key: ValueKey<String>(_scanStatus),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            
            const SizedBox(height: 24),
            
            // Radar Animation with dynamic device indicators
            SizedBox(
              height: 200,
              width: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _buildRipple(0),
                  _buildRipple(0.33),
                  _buildRipple(0.66),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryRed.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isScanning ? Icons.radar : Icons.check_circle,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  // Dynamic device indicators around radar
                  ..._buildDeviceIndicators(),
                ],
              ),
            ),
            
            // Discovered ESP32 Devices Section
            if (_filteredDiscoveredDevices.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Discovered ESP32 Devices',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (_isScanning)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filteredDiscoveredDevices.length,
                  itemBuilder: (context, index) {
                    final result = _filteredDiscoveredDevices[index];
                    return _buildDeviceCard(result.device, isPaired: false, rssi: result.rssi);
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Empty state for discovered devices
            if (_filteredDiscoveredDevices.isEmpty && 
                !_isScanning &&
                _searchQuery.isEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'No ESP32 devices found nearby',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Make sure ESP32 devices are powered on\nand in pairing mode',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
            
            const SizedBox(height: 8),
            
            // View Paired Devices Button (to go to paired devices list)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onPairedDevicesTap();
                },
                icon: const Icon(Icons.bluetooth_connected),
                label: const Text('View Paired Devices'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.info,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRipple(double startValue) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double t = (_controller.value + startValue) % 1.0;
        final double size = 200 * t;
        final double opacity = 1.0 - t;
        
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _isScanning 
                ? AppColors.primaryRed.withOpacity(opacity)
                : AppColors.success.withOpacity(opacity * 0.5),
              width: 2,
            ),
          ),
        );
      },
    );
  }
  
  List<Widget> _buildDeviceIndicators() {
    if (_discoveredDevices.isEmpty) return [];
    
    final List<Widget> indicators = [];
    final int deviceCount = math.min(_discoveredDevices.length, 8); // Max 8 indicators
    
    for (int i = 0; i < deviceCount; i++) {
      final angle = (i * 360.0 / deviceCount) * math.pi / 180.0; // Convert to radians
      final radius = 80.0;
      final x = radius * 0.8 * math.cos(angle);
      final y = radius * 0.8 * math.sin(angle);
      
      indicators.add(
        Positioned(
          left: 100 + x - 8,
          top: 100 + y - 8,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return indicators;
  }
  
  Widget _buildDeviceCard(BluetoothDevice device, {required bool isPaired, int? rssi}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isPaired ? AppColors.info.withOpacity(0.1) : AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPaired ? AppColors.info.withOpacity(0.3) : AppColors.lightGray,
          width: isPaired ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isPaired ? AppColors.info.withOpacity(0.2) : AppColors.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPaired ? Icons.bluetooth_connected : Icons.bluetooth_searching,
              color: isPaired ? AppColors.info : AppColors.success,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name ?? 'Unknown Device',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (device.address.isNotEmpty)
                  Text(
                    device.address,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (isPaired)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Paired',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.info,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (rssi != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$rssi dBm',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

