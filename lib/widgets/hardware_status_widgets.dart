import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../services/hardware_service.dart';

class HardwareConnectionCard extends StatelessWidget {
  final HardwareService hardwareService;
  final VoidCallback? onTap;

  const HardwareConnectionCard({
    super.key,
    required this.hardwareService,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<HardwareService>(
      stream: Stream.periodic(const Duration(milliseconds: 500))
          .map((_) => hardwareService),
      builder: (context, snapshot) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _getCardColor(),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _getBorderColor(),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: _getShadowColor(),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 12),
                _buildStatusRow(),
                const SizedBox(height: 8),
                _buildInfoRow(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getIconColor(),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: _getIconColor().withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            _getIcon(),
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getTitle(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                _getSubtitle(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        _buildStatusIndicator(),
      ],
    );
  }

  Widget _buildStatusRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatusItem(
            icon: Icons.usb,
            label: 'USB',
            status: _getUsbStatusText(),
            color: _getUsbStatusColor(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatusItem(
            icon: Icons.radio,
            label: 'LoRa',
            status: _getLoRaStatusText(),
            color: _getLoRaStatusColor(),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    required String status,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow() {
    return Row(
      children: [
        if (hardwareService.batteryLevel > 0) ...[
          Expanded(
            child: _buildInfoItem(
              icon: Icons.battery_std,
              label: 'Battery',
              value: '${hardwareService.batteryLevel}%',
              color: _getBatteryColor(),
            ),
          ),
          const SizedBox(width: 12),
        ],
        if (hardwareService.signalStrength > 0) ...[
          Expanded(
            child: _buildInfoItem(
              icon: Icons.signal_cellular_alt,
              label: 'Signal',
              value: '${hardwareService.signalStrength}%',
              color: _getSignalColor(),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: _buildInfoItem(
            icon: Icons.memory,
            label: 'Firmware',
            value: hardwareService.firmwareVersion,
            color: AppColors.mediumGray,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: color,
          size: 14,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: _getStatusColor(),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _getStatusColor().withOpacity(0.5),
            blurRadius: 4,
            offset: const Offset(0, 0),
          ),
        ],
      ),
    );
  }

  // Status getters
  String _getTitle() {
    switch (hardwareService.usbState) {
      case HardwareConnectionState.connected:
        return 'Hardware Connected';
      case HardwareConnectionState.connecting:
        return 'Connecting...';
      case HardwareConnectionState.mockMode:
        return 'Mock Mode';
      case HardwareConnectionState.error:
        return 'Connection Error';
      case HardwareConnectionState.disconnected:
        return 'Hardware Disconnected';
    }
  }

  String _getSubtitle() {
    switch (hardwareService.usbState) {
      case HardwareConnectionState.connected:
        return hardwareService.deviceName;
      case HardwareConnectionState.connecting:
        return 'Establishing connection...';
      case HardwareConnectionState.mockMode:
        return 'Testing mode - No hardware required';
      case HardwareConnectionState.error:
        return 'Check USB connection';
      case HardwareConnectionState.disconnected:
        return 'Connect hardware via USB OTG';
    }
  }

  String _getUsbStatusText() {
    switch (hardwareService.usbState) {
      case HardwareConnectionState.connected:
        return 'Connected';
      case HardwareConnectionState.connecting:
        return 'Connecting';
      case HardwareConnectionState.mockMode:
        return 'Mock';
      case HardwareConnectionState.error:
        return 'Error';
      case HardwareConnectionState.disconnected:
        return 'Disconnected';
    }
  }

  String _getLoRaStatusText() {
    switch (hardwareService.loraState) {
      case LoRaConnectionState.connected:
        return 'Ready';
      case LoRaConnectionState.scanning:
        return 'Scanning';
      case LoRaConnectionState.transmitting:
        return 'TX';
      case LoRaConnectionState.receiving:
        return 'RX';
      case LoRaConnectionState.error:
        return 'Error';
      case LoRaConnectionState.disconnected:
        return 'Offline';
    }
  }

  IconData _getIcon() {
    switch (hardwareService.usbState) {
      case HardwareConnectionState.connected:
        return Icons.usb;
      case HardwareConnectionState.connecting:
        return Icons.sync;
      case HardwareConnectionState.mockMode:
        return Icons.bug_report;
      case HardwareConnectionState.error:
        return Icons.error_outline;
      case HardwareConnectionState.disconnected:
        return Icons.usb_off;
    }
  }

  Color _getCardColor() {
    switch (hardwareService.usbState) {
      case HardwareConnectionState.connected:
        return AppColors.success.withOpacity(0.05);
      case HardwareConnectionState.connecting:
        return AppColors.warning.withOpacity(0.05);
      case HardwareConnectionState.mockMode:
        return AppColors.primaryRed.withOpacity(0.05);
      case HardwareConnectionState.error:
        return AppColors.error.withOpacity(0.05);
      case HardwareConnectionState.disconnected:
        return AppColors.mediumGray.withOpacity(0.05);
    }
  }

  Color _getBorderColor() {
    switch (hardwareService.usbState) {
      case HardwareConnectionState.connected:
        return AppColors.success.withOpacity(0.3);
      case HardwareConnectionState.connecting:
        return AppColors.warning.withOpacity(0.3);
      case HardwareConnectionState.mockMode:
        return AppColors.primaryRed.withOpacity(0.3);
      case HardwareConnectionState.error:
        return AppColors.error.withOpacity(0.3);
      case HardwareConnectionState.disconnected:
        return AppColors.mediumGray.withOpacity(0.3);
    }
  }

  Color _getShadowColor() {
    switch (hardwareService.usbState) {
      case HardwareConnectionState.connected:
        return AppColors.success.withOpacity(0.1);
      case HardwareConnectionState.connecting:
        return AppColors.warning.withOpacity(0.1);
      case HardwareConnectionState.mockMode:
        return AppColors.primaryRed.withOpacity(0.1);
      case HardwareConnectionState.error:
        return AppColors.error.withOpacity(0.1);
      case HardwareConnectionState.disconnected:
        return AppColors.mediumGray.withOpacity(0.1);
    }
  }

  Color _getIconColor() {
    switch (hardwareService.usbState) {
      case HardwareConnectionState.connected:
        return AppColors.success;
      case HardwareConnectionState.connecting:
        return AppColors.warning;
      case HardwareConnectionState.mockMode:
        return AppColors.primaryRed;
      case HardwareConnectionState.error:
        return AppColors.error;
      case HardwareConnectionState.disconnected:
        return AppColors.mediumGray;
    }
  }

  Color _getStatusColor() {
    return _getIconColor();
  }

  Color _getUsbStatusColor() {
    switch (hardwareService.usbState) {
      case HardwareConnectionState.connected:
        return AppColors.success;
      case HardwareConnectionState.connecting:
        return AppColors.warning;
      case HardwareConnectionState.mockMode:
        return AppColors.primaryRed;
      case HardwareConnectionState.error:
        return AppColors.error;
      case HardwareConnectionState.disconnected:
        return AppColors.mediumGray;
    }
  }

  Color _getLoRaStatusColor() {
    switch (hardwareService.loraState) {
      case LoRaConnectionState.connected:
        return AppColors.success;
      case LoRaConnectionState.scanning:
        return AppColors.warning;
      case LoRaConnectionState.transmitting:
        return AppColors.primaryRed;
      case LoRaConnectionState.receiving:
        return AppColors.online;
      case LoRaConnectionState.error:
        return AppColors.error;
      case LoRaConnectionState.disconnected:
        return AppColors.mediumGray;
    }
  }

  Color _getBatteryColor() {
    if (hardwareService.batteryLevel > 50) {
      return AppColors.success;
    } else if (hardwareService.batteryLevel > 20) {
      return AppColors.warning;
    } else {
      return AppColors.error;
    }
  }

  Color _getSignalColor() {
    if (hardwareService.signalStrength > 70) {
      return AppColors.success;
    } else if (hardwareService.signalStrength > 40) {
      return AppColors.warning;
    } else {
      return AppColors.error;
    }
  }
}

class HardwarePTTButton extends StatelessWidget {
  final HardwareService hardwareService;
  final VoidCallback? onPressed;

  const HardwarePTTButton({
    super.key,
    required this.hardwareService,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<HardwareService>(
      stream: Stream.periodic(const Duration(milliseconds: 100))
          .map((_) => hardwareService),
      builder: (context, snapshot) {
        final isConnected = hardwareService.isConnected || hardwareService.mockMode;
        final isRecording = hardwareService.isRecording;
        final canTransmit = isConnected && hardwareService.isLoRaConnected;

        return GestureDetector(
          onTapDown: canTransmit ? _onTapDown : null,
          onTapUp: canTransmit ? _onTapUp : null,
          onTapCancel: canTransmit ? () => _onTapUp(null) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: _getButtonColor(canTransmit, isRecording),
              shape: BoxShape.circle,
              border: Border.all(
                color: _getBorderColor(canTransmit, isRecording),
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: _getShadowColor(canTransmit, isRecording),
                  blurRadius: isRecording ? 20 : 12,
                  spreadRadius: isRecording ? 8 : 4,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              _getIcon(canTransmit, isRecording),
              color: Colors.white,
              size: 40,
            ),
          ),
        );
      },
    );
  }

  void _onTapDown(_) {
    HapticFeedback.mediumImpact();
    hardwareService.startVoiceTransmission();
  }

  void _onTapUp(_) {
    HapticFeedback.lightImpact();
    hardwareService.stopVoiceTransmission();
  }

  IconData _getIcon(bool canTransmit, bool isRecording) {
    if (!canTransmit) return Icons.block;
    if (isRecording) return Icons.mic;
    return Icons.mic_none;
  }

  Color _getButtonColor(bool canTransmit, bool isRecording) {
    if (!canTransmit) return AppColors.mediumGray;
    if (isRecording) return AppColors.error;
    return AppColors.primaryRed;
  }

  Color _getBorderColor(bool canTransmit, bool isRecording) {
    if (!canTransmit) return AppColors.mediumGray;
    if (isRecording) return AppColors.error;
    return AppColors.primaryRed;
  }

  Color _getShadowColor(bool canTransmit, bool isRecording) {
    if (!canTransmit) return AppColors.mediumGray.withOpacity(0.3);
    if (isRecording) return AppColors.error.withOpacity(0.5);
    return AppColors.primaryRed.withOpacity(0.4);
  }
}

class HardwareStatusBar extends StatelessWidget {
  final HardwareService hardwareService;

  const HardwareStatusBar({
    super.key,
    required this.hardwareService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<HardwareService>(
      stream: Stream.periodic(const Duration(milliseconds: 500))
          .map((_) => hardwareService),
      builder: (context, snapshot) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _getBorderColor(),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _getStatusColor(),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _getStatusText(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _getTextColor(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getStatusText() {
    if (hardwareService.mockMode) return 'Mock Mode';
    if (hardwareService.isConnected && hardwareService.isLoRaConnected) {
      return 'Hardware Ready';
    }
    if (hardwareService.isConnected) return 'USB Connected';
    return 'Hardware Offline';
  }

  Color _getStatusColor() {
    if (hardwareService.mockMode) return AppColors.primaryRed;
    if (hardwareService.isConnected && hardwareService.isLoRaConnected) {
      return AppColors.success;
    }
    if (hardwareService.isConnected) return AppColors.warning;
    return AppColors.error;
  }

  Color _getBackgroundColor() {
    return _getStatusColor().withOpacity(0.1);
  }

  Color _getBorderColor() {
    return _getStatusColor().withOpacity(0.3);
  }

  Color _getTextColor() {
    return _getStatusColor();
  }
}
