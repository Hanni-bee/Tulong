import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/simple_bluetooth_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../constants/unified_typography.dart';

/// Detailed Network View Modal
class NetworkDetailModal extends StatelessWidget {
  const NetworkDetailModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
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
                    AppColors.primaryRed,
                    AppColors.primaryRed.withOpacity(0.8),
                  ],
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.network_check,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Network Details',
                          style: UnifiedTypography.titleLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Consumer<SimpleBluetoothService>(
                          builder: (context, btService, child) {
                            return Text(
                              btService.isConnected ? 'Connected' : 'Disconnected',
                              style: UnifiedTypography.bodySmall.copyWith(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                              ),
                            );
                          },
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
            
            // Content
            Expanded(
              child: Consumer<SimpleBluetoothService>(
                builder: (context, btService, child) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Connection Status
                        _buildDetailSection(
                          title: 'Connection Status',
                          icon: Icons.bluetooth,
                          children: [
                            _buildDetailRow(
                              label: 'Status',
                              value: btService.isConnected ? 'Connected' : 'Disconnected',
                              valueColor: btService.isConnected 
                                  ? AppColors.success 
                                  : AppColors.error,
                            ),
                            if (btService.isConnected) ...[
                              _buildDetailRow(
                                label: 'Node ID',
                                value: btService.esp32NodeId.isNotEmpty 
                                    ? btService.esp32NodeId 
                                    : 'N/A',
                              ),
                              _buildDetailRow(
                                label: 'Device Name',
                                value: btService.pairedDeviceName.isNotEmpty 
                                    ? btService.pairedDeviceName 
                                    : 'N/A',
                              ),
                              _buildDetailRow(
                                label: 'Authentication',
                                value: btService.isAuthenticated ? 'Authenticated' : 'Pending',
                                valueColor: btService.isAuthenticated 
                                    ? AppColors.success 
                                    : AppColors.warning,
                              ),
                            ],
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Network Stats
                        _buildDetailSection(
                          title: 'Network Statistics',
                          icon: Icons.analytics,
                          children: [
                            _buildDetailRow(
                              label: 'Connected Users',
                              value: '${btService.connectedUsers.length}',
                              valueColor: AppColors.info,
                            ),
                            _buildDetailRow(
                              label: 'Connection Status',
                              value: btService.connectionStatus,
                            ),
                            if (btService.isConnected) ...[
                              _buildDetailRow(
                                label: 'Last Error',
                                value: btService.lastError.isNotEmpty 
                                    ? btService.lastError 
                                    : 'None',
                                valueColor: btService.lastError.isNotEmpty 
                                    ? AppColors.error 
                                    : AppColors.success,
                              ),
                            ],
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Connected Users List
                        if (btService.connectedUsers.isNotEmpty) ...[
                          _buildDetailSection(
                            title: 'Connected Users',
                            icon: Icons.people,
                            children: [
                              ...btService.connectedUsers.map((user) {
                                final name = user['name'] ?? 'Unknown';
                                final nodeId = user['nodeId'] ?? 'N/A';
                                final signal = user['signalStrength'] ?? 0;
                                final isOnline = user['isOnline'] ?? false;
                                
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.lightGray.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isOnline 
                                            ? AppColors.success.withOpacity(0.3)
                                            : Colors.grey.withOpacity(0.2),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: isOnline 
                                                ? AppColors.success.withOpacity(0.1)
                                                : Colors.grey.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.person,
                                            color: isOnline ? AppColors.success : Colors.grey,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: AppTypography.titleSmall.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                nodeId,
                                                style: AppTypography.bodySmall.copyWith(
                                                  color: AppColors.textSecondary,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (signal > 0) ...[
                                          Icon(
                                            Icons.signal_cellular_alt,
                                            size: 16,
                                            color: _getSignalColorFromStrength(signal),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$signal/5',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ],
                        
                        const SizedBox(height: 20),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primaryRed),
            const SizedBox(width: 8),
            Text(
              title,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Color _getSignalColorFromStrength(int strength) {
    if (strength >= 4) return AppColors.success;
    if (strength >= 2) return AppColors.warning;
    return AppColors.error;
  }
}








