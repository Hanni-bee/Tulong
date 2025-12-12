import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../services/hardware_service.dart';
import '../widgets/hardware_status_widgets.dart';
import '../widgets/enhanced_button.dart';

class HardwareScreen extends StatefulWidget {
  const HardwareScreen({super.key});

  @override
  State<HardwareScreen> createState() => _HardwareScreenState();
}

class _HardwareScreenState extends State<HardwareScreen> {
  late HardwareService _hardwareService;

  @override
  void initState() {
    super.initState();
    _hardwareService = HardwareService();
    _initializeHardware();
  }

  Future<void> _initializeHardware() async {
    await _hardwareService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Hardware Settings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: () => _refreshConnection(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Connection Status Card
              HardwareConnectionCard(
                hardwareService: _hardwareService,
                onTap: () => _showConnectionOptions(),
              ),

              const SizedBox(height: 20),

              // Hardware Information Section
              _buildHardwareInfoSection(),

              const SizedBox(height: 20),

              // LoRa Settings Section
              _buildLoRaSettingsSection(),

              const SizedBox(height: 20),

              // Testing Section
              _buildTestingSection(),

              const SizedBox(height: 20),

              // Action Buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHardwareInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryRed.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Hardware Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Device Name', _hardwareService.deviceName),
          _buildInfoRow('Firmware Version', _hardwareService.firmwareVersion),
          _buildInfoRow('Connection Type', _hardwareService.mockMode ? 'Mock Mode' : 'USB OTG'),
          _buildInfoRow('RF Module', 'SX1278 LoRa (433MHz)'),
        ],
      ),
    );
  }

  Widget _buildLoRaSettingsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryRed.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.radio,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'LoRa Settings',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow('Frequency', '433 MHz'),
          _buildInfoRow('Transmit Power', '20 dBm (100mW)'),
          _buildInfoRow('Range', '2-10 km'),
          _buildInfoRow('Data Rate', '0.3-50 kbps'),
          _buildInfoRow('Mesh Network', 'Enabled'),
        ],
      ),
    );
  }

  Widget _buildTestingSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryRed.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.science,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Testing & Diagnostics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // PTT Test Button
          Center(
            child: HardwarePTTButton(
              hardwareService: _hardwareService,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Test Buttons
          Row(
            children: [
              Expanded(
                child: EnhancedButton(
                  text: 'Test LoRa',
                  variant: ButtonVariant.secondary,
                  size: ButtonSize.medium,
                  icon: Icons.radio,
                  onPressed: _testLoRa,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: EnhancedButton(
                  text: 'Send Test Message',
                  variant: ButtonVariant.secondary,
                  size: ButtonSize.medium,
                  icon: Icons.message,
                  onPressed: _sendTestMessage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        if (_hardwareService.mockMode) ...[
          EnhancedButton(
            text: 'Enable Real Hardware',
            variant: ButtonVariant.primary,
            size: ButtonSize.large,
            icon: Icons.usb,
            fullWidth: true,
            onPressed: _enableRealHardware,
          ),
          const SizedBox(height: 12),
        ] else ...[
          EnhancedButton(
            text: 'Enable Mock Mode',
            variant: ButtonVariant.outline,
            size: ButtonSize.large,
            icon: Icons.bug_report,
            fullWidth: true,
            onPressed: _enableMockMode,
          ),
          const SizedBox(height: 12),
        ],
        
        EnhancedButton(
          text: _hardwareService.isConnected ? 'Disconnect Hardware' : 'Connect Hardware',
          variant: _hardwareService.isConnected ? ButtonVariant.danger : ButtonVariant.primary,
          size: ButtonSize.large,
          icon: _hardwareService.isConnected ? Icons.usb_off : Icons.usb,
          fullWidth: true,
          onPressed: _hardwareService.isConnected ? _disconnectHardware : _connectHardware,
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showConnectionOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.mediumGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Connection Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.usb, color: AppColors.primaryRed),
              title: const Text('Connect Real Hardware'),
              subtitle: const Text('Connect ESP32 + SX1278 via USB OTG'),
              onTap: () {
                Navigator.pop(context);
                _enableRealHardware();
              },
            ),
            ListTile(
              leading: const Icon(Icons.bug_report, color: AppColors.warning),
              title: const Text('Enable Mock Mode'),
              subtitle: const Text('Test without real hardware'),
              onTap: () {
                Navigator.pop(context);
                _enableMockMode();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _refreshConnection() {
    HapticFeedback.selectionClick();
    _hardwareService.connectToHardware();
  }

  void _connectHardware() {
    HapticFeedback.mediumImpact();
    _hardwareService.connectToHardware();
  }

  void _disconnectHardware() {
    HapticFeedback.mediumImpact();
    _hardwareService.disconnectFromHardware();
  }

  void _enableMockMode() {
    HapticFeedback.mediumImpact();
    _hardwareService.enableMockMode();
    _showSnackBar('Mock mode enabled for testing', AppColors.primaryRed);
  }

  void _enableRealHardware() {
    HapticFeedback.mediumImpact();
    _hardwareService.disableMockMode();
    _hardwareService.connectToHardware();
    _showSnackBar('Connecting to real hardware...', AppColors.primaryRed);
  }

  void _testLoRa() {
    HapticFeedback.lightImpact();
    _hardwareService.sendLoRaMessage('TEST_MESSAGE:${DateTime.now().millisecondsSinceEpoch}');
    _showSnackBar('Test message sent via LoRa', AppColors.success);
  }

  void _sendTestMessage() {
    HapticFeedback.lightImpact();
    _hardwareService.sendLoRaMessage('Hello from TULONG App!');
    _showSnackBar('Test message sent', AppColors.success);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
