import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
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
                        Consumer2<SimpleBluetoothService, ChatProvider>(
                          builder: (context, btService, chatProvider, child) {
                            final isConnected = btService.isConnected || chatProvider.isConnected;
                            return Text(
                              isConnected ? 'Connected' : 'Disconnected',
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
              child: Consumer2<SimpleBluetoothService, ChatProvider>(
                builder: (context, btService, chatProvider, child) {
                  final bool isConnectedService = btService.isConnected;
                  final bool isConnectedChat = chatProvider.isConnected;
                  final bool isConnected = isConnectedService || isConnectedChat;

                  final String deviceName = isConnectedService
                      ? (btService.pairedDeviceName.isNotEmpty
                          ? btService.pairedDeviceName
                          : 'N/A')
                      : (chatProvider.selectedDevice?.name ?? 'N/A');

                  final String nodeId = isConnectedService
                      ? (btService.esp32NodeId.isNotEmpty
                          ? btService.esp32NodeId
                          : 'N/A')
                      : (chatProvider.selectedDevice?.address ?? 'N/A');

                  final String connectionStatus = isConnectedService
                      ? btService.connectionStatus
                      : (isConnectedChat ? 'Connected via Local Chat' : 'Disconnected');

                  final String authenticationLabel;
                  final Color authenticationColor;

                  if (isConnectedService) {
                    authenticationLabel = btService.isAuthenticated ? 'Authenticated' : 'Pending';
                    authenticationColor = btService.isAuthenticated
                        ? AppColors.success
                        : AppColors.warning;
                  } else if (isConnectedChat) {
                    authenticationLabel = 'Local Chat Active';
                    authenticationColor = AppColors.info;
                  } else {
                    authenticationLabel = 'Disconnected';
                    authenticationColor = AppColors.error;
                  }

                  final List<Map<String, dynamic>> userEntries = isConnectedService
                      ? btService.connectedUsers
                      : chatProvider.connectedUsers
                          .map((name) => {
                                'name': name,
                                'nodeId': '',
                                'signalStrength': 0,
                                'isOnline': true,
                              })
                          .toList();

                  final String lastError = isConnectedService ? btService.lastError : '';

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
                              value: isConnected ? 'Connected' : 'Disconnected',
                              valueColor: isConnected ? AppColors.success : AppColors.error,
                            ),
                            _buildDetailRow(
                              label: 'Connection Source',
                              value: connectionStatus,
                            ),
                            if (isConnected && nodeId.isNotEmpty) ...[
                              _buildDetailRow(
                                label: 'Node ID',
                                value: nodeId,
                              ),
                              _buildDetailRow(
                                label: 'Device Name',
                                value: deviceName,
                              ),
                            ],
                            if (isConnected)
                              _buildDetailRow(
                                label: 'Authentication',
                                value: authenticationLabel,
                                valueColor: authenticationColor,
                              ),
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
                              value: '${userEntries.length}',
                              valueColor: AppColors.info,
                            ),
                            _buildDetailRow(
                              label: 'Connection Status',
                              value: connectionStatus,
                            ),
                            if (isConnectedService && lastError.isNotEmpty)
                              _buildDetailRow(
                                label: 'Last Error',
                                value: lastError,
                                valueColor: AppColors.error,
                              ),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Connected Users List
                        if (userEntries.isNotEmpty) ...[
                          _buildDetailSection(
                            title: 'Connected Users',
                            icon: Icons.people,
                            children: [
                              ...userEntries.map((user) {
                                final name = user['name'] ?? 'Unknown';
                                final node = user['nodeId'] ?? 'N/A';
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
                                                ? AppColors.success.withOpacity(0.2)
                                                : Colors.grey.withOpacity(0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            isOnline ? Icons.wifi : Icons.wifi_off,
                                            color: isOnline ? AppColors.success : AppColors.mediumGray,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: AppTypography.bodyMedium.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Node: ${node.isNotEmpty ? node : 'N/A'}',
                                                style: AppTypography.bodySmall.copyWith(
                                                  color: AppColors.textSecondary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              signal is int && signal > 0 ? 'Signal: $signal' : 'Signal: N/A',
                                              style: AppTypography.bodySmall.copyWith(
                                                color: AppColors.textSecondary,
                                                fontSize: 11,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isOnline 
                                                    ? AppColors.success.withOpacity(0.15)
                                                    : Colors.grey.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                isOnline ? 'Online' : 'Offline',
                                                style: AppTypography.bodySmall.copyWith(
                                                  fontSize: 11,
                                                  color: isOnline ? AppColors.success : AppColors.mediumGray,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ],
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




