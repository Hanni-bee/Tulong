import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/simple_bluetooth_service.dart';
import '../providers/auth_provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

/// ESP32 Bluetooth Authentication Screen
/// Clean UI for connecting and authenticating with ESP32 via Bluetooth
class ESP32AuthScreen extends StatefulWidget {
  const ESP32AuthScreen({super.key});

  @override
  State<ESP32AuthScreen> createState() => _ESP32AuthScreenState();
}

class _ESP32AuthScreenState extends State<ESP32AuthScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    
    // Pulse animation for Bluetooth icon
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Consumer<SimpleBluetoothService>(
          builder: (context, btService, child) {
            return Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        _buildBluetoothIcon(btService),
                        const SizedBox(height: 32),
                        _buildStatusCard(btService),
                        const SizedBox(height: 24),
                        _buildInstructions(),
                        const SizedBox(height: 32),
                        _buildConnectButton(btService),
                        if (btService.isConnected) ...[
                          const SizedBox(height: 16),
                          _buildDisconnectButton(btService),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ESP32 Connection',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Bluetooth Setup',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.mediumGray,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothIcon(SimpleBluetoothService btService) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: btService.isConnecting ? _pulseAnimation.value : 1.0,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: btService.isConnected 
                  ? AppColors.success.withOpacity(0.1)
                  : const Color(0xFFF5F5F5),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: btService.isConnected
                      ? AppColors.success.withOpacity(0.3)
                      : Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              btService.isConnected
                  ? Icons.bluetooth_connected
                  : btService.isConnecting
                      ? Icons.bluetooth_searching
                      : Icons.bluetooth,
              size: 60,
              color: btService.isConnected
                  ? AppColors.success
                  : btService.isConnecting
                      ? AppColors.online
                      : AppColors.mediumGray,
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(SimpleBluetoothService btService) {
    Color statusColor = AppColors.mediumGray;
    String statusText = 'Not Connected';
    IconData statusIcon = Icons.bluetooth_disabled;

    if (btService.isConnected) {
      statusColor = AppColors.success;
      statusText = 'Connected';
      statusIcon = Icons.check_circle;
    } else if (btService.isConnecting) {
      statusColor = AppColors.online;
      statusText = 'Connecting...';
      statusIcon = Icons.sync;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(statusIcon, color: statusColor, size: 24),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: AppTypography.titleMedium.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (btService.isAuthenticated) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            _buildInfoRow('Node ID', btService.esp32NodeId),
            const SizedBox(height: 12),
            _buildInfoRow('User', btService.userName),
          ],
          if (btService.lastError.isNotEmpty && !btService.isConnected) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      btService.lastError,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.mediumGray,
          ),
        ),
        Text(
          value,
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.online.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.online.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.online, size: 20),
              const SizedBox(width: 8),
              Text(
                'How to Connect',
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.online,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInstructionStep('1', 'Power on your ESP32 device'),
          _buildInstructionStep('2', 'Make sure Bluetooth is enabled'),
          _buildInstructionStep('3', 'Tap "Connect to ESP32" button'),
          _buildInstructionStep('4', 'Wait for automatic authentication'),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.online,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTypography.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectButton(SimpleBluetoothService btService) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: btService.isConnected || btService.isConnecting
            ? null
            : () async {
                HapticFeedback.mediumImpact();
                setState(() => _isSearching = true);
                
                final success = await btService.connectToESP32();
                
                setState(() => _isSearching = false);
                
                if (mounted) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('ESP32 connection initiated!'),
                        backgroundColor: AppColors.success,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to connect. Please try again.'),
                        backgroundColor: AppColors.error,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryRed,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
        ),
        child: btService.isConnecting
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Connecting...',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bluetooth_searching, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Connect to ESP32',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDisconnectButton(SimpleBluetoothService btService) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: () async {
          HapticFeedback.lightImpact();
          await btService.disconnect();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Disconnected from ESP32'),
                backgroundColor: AppColors.mediumGray,
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bluetooth_disabled, size: 24),
            const SizedBox(width: 12),
            Text(
              'Disconnect',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

