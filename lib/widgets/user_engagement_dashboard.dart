import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/unified_typography.dart';
import '../utils/theme_colors.dart';
import '../widgets/animated_neumorphic_card.dart';

/// User Engagement Dashboard
/// 
/// Replaces weekly activity chart with more useful metrics:
/// - Emergency alerts sent/received
/// - Messages sent/received
/// - Connections made
/// - Response time
/// - Help provided/received
class UserEngagementDashboard extends StatelessWidget {
  final int emergencyAlertsSent;
  final int emergencyAlertsReceived;
  final int messagesSent;
  final int messagesReceived;
  final int connectionsMade;
  final double averageResponseTime; // in minutes
  final int helpProvided;
  final int helpReceived;
  final bool isLoading;

  const UserEngagementDashboard({
    super.key,
    this.emergencyAlertsSent = 0,
    this.emergencyAlertsReceived = 0,
    this.messagesSent = 0,
    this.messagesReceived = 0,
    this.connectionsMade = 0,
    this.averageResponseTime = 0.0,
    this.helpProvided = 0,
    this.helpReceived = 0,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingState();
    }

    return AnimatedNeumorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.insights,
                    color: AppColors.primaryRed,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Engagement Overview',
                    style: UnifiedTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: ThemeColors.textPrimary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    // TODO: Show detailed analytics screen
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'View Details',
                    style: UnifiedTypography.bodySmall.copyWith(
                      color: AppColors.primaryRed,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Key Metrics Grid
            _buildMetricsGrid(context),

            const SizedBox(height: 24),

            // Help & Response Stats
            _buildHelpStats(context),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Builder(
      builder: (context) {
        final skeletonColor = ThemeColors.textTertiary(context).withOpacity(0.3);
        return AnimatedNeumorphicCard(
          child: Container(
            height: 400,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: skeletonColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 150,
                            height: 16,
                            decoration: BoxDecoration(
                              color: skeletonColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    children: List.generate(4, (index) {
                      return Container(
                        decoration: BoxDecoration(
                          color: skeletonColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricsGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          context,
          icon: Icons.warning_amber_rounded,
          label: 'Alerts Sent',
          value: emergencyAlertsSent.toString(),
          color: AppColors.error,
        ),
        _buildMetricCard(
          context,
          icon: Icons.message_outlined,
          label: 'Messages Sent',
          value: messagesSent.toString(),
          color: AppColors.info,
        ),
        _buildMetricCard(
          context,
          icon: Icons.bluetooth_connected,
          label: 'Connections',
          value: connectionsMade.toString(),
          color: AppColors.success,
        ),
        _buildMetricCard(
          context,
          icon: Icons.timer_outlined,
          label: 'Avg Response',
          value: averageResponseTime > 0 
              ? '${averageResponseTime.toStringAsFixed(1)}m'
              : 'N/A',
          color: AppColors.warning,
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: UnifiedTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: ThemeColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: UnifiedTypography.bodySmall.copyWith(
              color: ThemeColors.textSecondary(context),
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildHelpStats(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.success.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.handshake_outlined,
              color: AppColors.success,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community Impact',
                  style: UnifiedTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: ThemeColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Helped $helpProvided • Received $helpReceived',
                  style: UnifiedTypography.bodySmall.copyWith(
                    color: ThemeColors.textSecondary(context),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

