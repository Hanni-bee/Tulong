import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../providers/network_provider.dart';
import '../widgets/connected_user_card.dart';
import 'call_detail_screen.dart';
import '../constants/unified_typography.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  bool _isCallActive = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;

  // Sample connected users data
  final List<Map<String, dynamic>> _connectedUsers = [
    {
      'id': '1',
      'name': 'User 1',
      'isOnline': true,
      'signalStrength': 4,
      'batteryLevel': 85,
    },
    {
      'id': '2',
      'name': 'User 2',
      'isOnline': true,
      'signalStrength': 3,
      'batteryLevel': 72,
    },
    {
      'id': '3',
      'name': 'User 3',
      'isOnline': true,
      'signalStrength': 5,
      'batteryLevel': 95,
    },
    {
      'id': '4',
      'name': 'User 4',
      'isOnline': false,
      'signalStrength': 0,
      'batteryLevel': 0,
    },
    {
      'id': '5',
      'name': 'User 5',
      'isOnline': true,
      'signalStrength': 2,
      'batteryLevel': 45,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          AppStrings.connectedUsers,
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _refreshConnections();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              _showSettingsDialog(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Network status
          Consumer<NetworkProvider>(
            builder: (context, networkProvider, child) {
              return Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: networkProvider.isConnected 
                        ? AppColors.online 
                        : AppColors.mediumGray,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.wifi_tethering,
                      color: networkProvider.isConnected 
                          ? AppColors.online 
                          : AppColors.mediumGray,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Mesh Network Status',
                            style: UnifiedTypography.titleLarge,
                          ),
                          Text(
                            networkProvider.isConnected 
                                ? '${networkProvider.connectedUsers} devices connected'
                                : 'Disconnected',
                            style: TextStyle(
                              fontSize: 14,
                              color: networkProvider.isConnected 
                                  ? AppColors.online 
                                  : AppColors.mediumGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: networkProvider.isConnected 
                            ? AppColors.online 
                            : AppColors.mediumGray,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        networkProvider.isConnected ? 'CONNECTED' : 'OFFLINE',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Connected users list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _connectedUsers.length,
              itemBuilder: (context, index) {
                final user = _connectedUsers[index];
                return ConnectedUserCard(
                  name: user['name'],
                  isOnline: user['isOnline'],
                  signalStrength: user['signalStrength'],
                  batteryLevel: user['batteryLevel'],
                  onCall: () {
                    _initiateCall(context, user);
                  },
                  onDisconnect: () {
                    _disconnectUser(context, user);
                  },
                );
              },
            ),
          ),

          // Call controls (if call is active)
          if (_isCallActive) _buildCallControls(),
        ],
      ),
      floatingActionButton: Consumer<NetworkProvider>(
        builder: (context, networkProvider, child) {
          return FloatingActionButton(
            key: const ValueKey('calls_broadcast_fab'),
            heroTag: 'calls_broadcast_fab',
            onPressed: networkProvider.isConnected 
                ? () => _showBroadcastDialog(context)
                : null,
            backgroundColor: networkProvider.isConnected 
                ? AppColors.primaryRed 
                : AppColors.mediumGray,
            child: const Icon(
              Icons.mic,
              color: AppColors.white,
              size: 28,
            ),
          );
        },
      ),
    );
  }

  Widget _buildCallControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Call in Progress',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCallButton(
                icon: _isMuted ? Icons.mic_off : Icons.mic,
                color: _isMuted ? AppColors.error : AppColors.mediumGray,
                onPressed: () {
                  setState(() {
                    _isMuted = !_isMuted;
                  });
                },
              ),
              _buildCallButton(
                icon: Icons.call_end,
                color: AppColors.error,
                onPressed: () {
                  setState(() {
                    _isCallActive = false;
                  });
                },
              ),
              _buildCallButton(
                icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                color: _isSpeakerOn ? AppColors.online : AppColors.mediumGray,
                onPressed: () {
                  setState(() {
                    _isSpeakerOn = !_isSpeakerOn;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: AppColors.white,
          size: 24,
        ),
      ),
    );
  }

  void _refreshConnections() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Refreshing connections...'),
        backgroundColor: AppColors.primaryRed,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Call Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.volume_up, color: AppColors.primaryRed),
              title: const Text('Audio Settings'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Show audio settings
              },
            ),
            ListTile(
              leading: const Icon(Icons.network_check, color: AppColors.primaryRed),
              title: const Text('Network Settings'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Show network settings
              },
            ),
            ListTile(
              leading: const Icon(Icons.security, color: AppColors.primaryRed),
              title: const Text('Security Settings'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Show security settings
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showBroadcastDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Broadcast Message'),
        content: const Text(
          'This will send a message to all connected devices in your area. Use this for important announcements or emergency information.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isCallActive = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Broadcasting to all connected devices'),
                  backgroundColor: AppColors.primaryRed,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Start Broadcast'),
          ),
        ],
      ),
    );
  }

  void _initiateCall(BuildContext context, Map<String, dynamic> user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CallDetailScreen(
          contactName: user['name'],
          contactId: user['id'],
          isIncoming: false,
        ),
      ),
    );
  }

  void _disconnectUser(BuildContext context, Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Disconnect User'),
        content: Text('Are you sure you want to disconnect ${user['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${user['name']} disconnected'),
                  backgroundColor: AppColors.mediumGray,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }
}
