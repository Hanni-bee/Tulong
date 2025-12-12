import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../services/simple_bluetooth_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../constants/soft_ui_design.dart';
import 'network_detail_modal.dart';

/// Network Status Dashboard - Shows ESP32 connection status and network health
class NetworkStatusDashboard extends StatefulWidget {
  const NetworkStatusDashboard({super.key});

  @override
  State<NetworkStatusDashboard> createState() => _NetworkStatusDashboardState();
}

class _NetworkStatusDashboardState extends State<NetworkStatusDashboard> {
  bool _isRefreshing = false;

  Future<void> _refreshNetworkStatus() async {
    setState(() => _isRefreshing = true);
    HapticFeedback.mediumImpact();
    
    try {
      final btService = Provider.of<SimpleBluetoothService>(context, listen: false);
      
      if (btService.isConnected && btService.isAuthenticated) {
        // Request users to update stats
        await btService.requestDiscoveredUsers();
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      // Silently handle errors
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _showNetworkDetails(BuildContext context) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => const NetworkDetailModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SimpleBluetoothService, ChatProvider>(
      builder: (context, btService, chatProvider, child) {
        final bool isConnectedViaService = btService.isConnected;
        final bool isConnectedViaChat = chatProvider.isConnected;
        final bool isConnected = isConnectedViaService || isConnectedViaChat;

        final bool isAuthenticated = isConnectedViaService && btService.isAuthenticated;

        final String nodeId = isConnectedViaService
            ? btService.esp32NodeId
            : (chatProvider.selectedDevice?.name ?? '');

        final String status = isConnectedViaService
            ? btService.connectionStatus
            : isConnectedViaChat
                ? 'Connected via Local Chat'
                : btService.connectionStatus;

        final int connectedUsersCount = isConnectedViaService
            ? btService.connectedUsers.length
            : chatProvider.connectedUsersCount;

        final int signalStrength = isConnectedViaService
            ? _calculateSignalStrength(btService.connectedUsers)
            : 0;

        // Battery level placeholder (would come from ESP32 if available)
        final int batteryLevel = isConnectedViaService ? 85 : 0; // Mock value

        return GestureDetector(
          onTap: () => _showNetworkDetails(context),
          child: Container(
            padding: const EdgeInsets.all(SoftUIDesign.cardPadding),
            decoration: SoftUIDesign.cardDecoration(
              backgroundColor: AppColors.white,
              borderRadius: SoftUIDesign.cardBorderRadius,
              elevation: 4.0,
              borderColor: AppColors.lightGray.withOpacity(0.3),
              showBorder: true,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.network_check,
                            size: 16,
                            color: AppColors.primaryRed,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Network Status',
                            style: AppTypography.cardTitle.copyWith(
                              color: AppColors.primaryRed,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _buildStatusIndicator(isConnected),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: _isRefreshing
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryRed),
                              ),
                            )
                          : Icon(
                              Icons.refresh,
                              size: 20,
                              color: AppColors.primaryRed.withOpacity(0.7),
                            ),
                      onPressed: _isRefreshing ? null : _refreshNetworkStatus,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Refresh network status',
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppColors.textSecondary.withOpacity(0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildConnectionCard(
                  isConnected: isConnected,
                  isAuthenticated: isAuthenticated,
                  status: status,
                  nodeId: nodeId,
                ),
                const SizedBox(height: 12),
                _buildStatsGrid(
                  connectedUsers: connectedUsersCount,
                  signalStrength: signalStrength,
                  batteryLevel: batteryLevel,
                  isConnected: isConnected,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int _calculateSignalStrength(List<Map<String, dynamic>> users) {
    if (users.isEmpty) return 0;
    
    // Get average signal strength from connected users
    int totalSignal = 0;
    int count = 0;
    
    for (var user in users) {
      final signal = user['signalStrength'] ?? 0;
      if (signal is int && signal > 0) {
        totalSignal += signal;
        count++;
      }
    }
    
    if (count == 0) return 0;
    
    // Convert to percentage (assuming signal strength is 0-5 scale)
    final avgSignal = (totalSignal / count).round();
    return ((avgSignal / 5) * 100).round().clamp(0, 100);
  }

  Widget _buildStatusIndicator(bool isConnected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isConnected 
            ? AppColors.success.withOpacity(0.1)
            : AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isConnected 
              ? AppColors.success
              : AppColors.error,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isConnected ? AppColors.success : AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isConnected ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isConnected ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard({
    required bool isConnected,
    required bool isAuthenticated,
    required String status,
    required String nodeId,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isConnected 
            ? AppColors.success.withOpacity(0.05)
            : AppColors.error.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected 
              ? AppColors.success.withOpacity(0.3)
              : AppColors.error.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isConnected 
                  ? AppColors.success.withOpacity(0.15)
                  : AppColors.error.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              color: isConnected ? AppColors.success : AppColors.error,
              size: 28,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Status Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? 'ESP32 Connected' : 'ESP32 Disconnected',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isConnected ? AppColors.success : AppColors.error,
                  ),
                ),
                const SizedBox(height: 4),
                if (isConnected && nodeId.isNotEmpty) ...[
                  Text(
                    'Node ID: $nodeId',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  isAuthenticated && isConnected 
                      ? 'Authenticated • Ready'
                      : status,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid({
    required int connectedUsers,
    required int signalStrength,
    required int batteryLevel,
    required bool isConnected,
  }) {
    return Row(
      children: [
        // Connected Users Stat
        Expanded(
          child: _buildStatCard(
            icon: Icons.people,
            label: 'Users',
            value: connectedUsers.toString(),
            color: AppColors.info,
            isActive: isConnected && connectedUsers > 0,
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Signal Strength Stat with percentage
        Expanded(
          child: _buildStatCard(
            icon: Icons.signal_cellular_alt,
            label: 'Signal',
            value: isConnected && signalStrength > 0 
                ? '$signalStrength%'
                : 'N/A',
            color: _getSignalColor(signalStrength),
            isActive: isConnected && signalStrength > 0,
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Battery Level Stat with percentage
        Expanded(
          child: _buildStatCard(
            icon: _getBatteryIcon(batteryLevel),
            label: 'Power',
            value: isConnected && batteryLevel > 0
                ? '$batteryLevel%'
                : 'N/A',
            color: _getBatteryColor(batteryLevel),
            isActive: isConnected && batteryLevel > 0,
          ),
        ),
      ],
    );
  }

  Color _getSignalColor(int strength) {
    if (strength >= 70) return AppColors.success;
    if (strength >= 40) return AppColors.warning;
    return AppColors.error;
  }

  Color _getBatteryColor(int level) {
    if (level >= 50) return AppColors.success;
    if (level >= 20) return AppColors.warning;
    return AppColors.error;
  }

  IconData _getBatteryIcon(int level) {
    if (level >= 80) return Icons.battery_full;
    if (level >= 50) return Icons.battery_5_bar;
    if (level >= 20) return Icons.battery_3_bar;
    if (level > 0) return Icons.battery_1_bar;
    return Icons.battery_0_bar;
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive 
            ? color.withOpacity(0.08)
            : AppColors.lightGray.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive 
              ? color.withOpacity(0.2)
              : AppColors.lightGray.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 24,
            color: isActive ? color : AppColors.textSecondary,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isActive ? color : AppColors.textSecondary,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

