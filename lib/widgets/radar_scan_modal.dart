import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import '../constants/app_colors.dart';
import '../utils/haptic_helper.dart';

/// Radar Scan Modal for device discovery with real-time Bluetooth scanning
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
  StreamSubscription<BluetoothState>? _stateSubscription;
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  
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
    
    // Listen to Bluetooth state changes
    _stateSubscription = FlutterBluetoothSerial.instance.onStateChanged().listen((state) {
      if (!mounted) return;
      setState(() {
        _bluetoothState = state;
        if (state == BluetoothState.STATE_ON) {
          _startDynamicScan();
        } else {
          _isScanning = false;
          _scanStatus = 'Please enable Bluetooth';
          _discoveredDevices.clear();
        }
      });
    });

    // Check initial state
    FlutterBluetoothSerial.instance.state.then((state) {
      if (mounted) {
        setState(() {
          _bluetoothState = state;
          if (state == BluetoothState.STATE_ON) {
            _startDynamicScan();
          } else {
            _scanStatus = 'Please enable Bluetooth';
          }
        });
      }
    });
    
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
      final state = await FlutterBluetoothSerial.instance.state;
      
      if (state != BluetoothState.STATE_ON) {
        setState(() {
          _bluetoothState = state;
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
              HapticHelper.light();
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
    _stateSubscription?.cancel();
    _searchController.dispose();
    FlutterBluetoothSerial.instance.cancelDiscovery();
    super.dispose();
  }

  Future<void> _requestEnableBluetooth() async {
    try {
      HapticHelper.medium();
      await FlutterBluetoothSerial.instance.requestEnable();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enable Bluetooth in your device settings')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isBluetoothOff = _bluetoothState != BluetoothState.STATE_ON;

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
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _scanStatus,
                key: ValueKey<String>(_scanStatus),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isBluetoothOff ? AppColors.error : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            
            // Radar Animation / Bluetooth Off Warning
            SizedBox(
              height: 200,
              width: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (!isBluetoothOff) ...[
                    _buildRipple(0),
                    _buildRipple(0.33),
                    _buildRipple(0.66),
                  ] else ...[
                    _buildStaticRing(1.0, AppColors.error.withOpacity(0.1)),
                    _buildStaticRing(0.7, AppColors.error.withOpacity(0.05)),
                  ],
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: isBluetoothOff ? AppColors.error : AppColors.primaryRed,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isBluetoothOff ? AppColors.error : AppColors.primaryRed).withOpacity(0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Icon(
                      isBluetoothOff 
                          ? Icons.bluetooth_disabled_rounded 
                          : (_isScanning ? Icons.radar : Icons.bluetooth_searching),
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                  if (!isBluetoothOff) ..._buildDeviceIndicators(),
                ],
              ),
            ),
            
            const SizedBox(height: 32),

            if (isBluetoothOff) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.error.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Bluetooth is Disabled',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.error,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Turn on Bluetooth to scan for nearby devices and ESP32 nodes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _requestEnableBluetooth,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Turn on Bluetooth', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            // Discovered ESP32 Devices Section
            if (!isBluetoothOff && _filteredDiscoveredDevices.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Nearby ESP32 Nodes',
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
            if (!isBluetoothOff && 
                _filteredDiscoveredDevices.isEmpty && 
                !_isScanning &&
                _searchQuery.isEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'No nodes found nearby',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Ensure hardware is in range and\nin discovery mode.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
            
            // View Paired Devices Button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  HapticHelper.selection();
                  Navigator.pop(context);
                  widget.onPairedDevicesTap();
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.info,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('View Paired Devices', style: TextStyle(fontWeight: FontWeight.w800)),
                    SizedBox(width: 8),
                    Icon(Icons.bluetooth_connected, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaticRing(double scale, Color color) {
    return Container(
      width: 200 * scale,
      height: 200 * scale,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
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
                  style: const TextStyle(
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
