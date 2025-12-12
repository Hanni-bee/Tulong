import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/simple_bluetooth_service.dart';
import '../constants/app_colors.dart';
import '../constants/unified_typography.dart';

/// Radar-like Connected Users Modal - Shows users connected to the network for chat
class BluetoothRadarModal extends StatefulWidget {
  const BluetoothRadarModal({super.key});

  @override
  State<BluetoothRadarModal> createState() => _BluetoothRadarModalState();
}

class _BluetoothRadarModalState extends State<BluetoothRadarModal>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  String _statusMessage = 'Loading users...';
  
  late AnimationController _radarController;
  late AnimationController _pulseController;
  late Animation<double> _radarAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Radar animation - expanding circles
    _radarController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _radarAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _radarController,
        curve: Curves.easeOut,
      ),
    );
    
    // Pulse animation for user icon
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Load connected users
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadConnectedUsers();
      _setupPeriodicRefresh();
    });
  }

  void _setupPeriodicRefresh() {
    // Refresh every 3 seconds while modal is open
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _requestUsers();
        _setupPeriodicRefresh();
      }
    });
  }

  Future<void> _loadConnectedUsers() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      final btService = Provider.of<SimpleBluetoothService>(context, listen: false);
      
      if (!btService.isConnected) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Not connected';
        });
        return;
      }
      
      // Request discovered users from ESP32
      await _requestUsers();
      
      // Wait a bit for response
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Get users from service
      if (mounted) {
        final users = btService.connectedUsers;
        setState(() {
          _isLoading = false;
          _statusMessage = users.isEmpty 
              ? 'No users found' 
              : 'Found ${users.length} user(s)';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Error loading users';
        });
      }
    }
  }

  Future<void> _requestUsers() async {
    try {
      final btService = Provider.of<SimpleBluetoothService>(context, listen: false);
      if (btService.isConnected && btService.isAuthenticated) {
        await btService.requestDiscoveredUsers();
      }
    } catch (e) {
      // Silently fail - will retry on next refresh
    }
  }

  @override
  void dispose() {
    _radarController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

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
                    AppColors.success,
                    AppColors.success.withOpacity(0.8),
                  ],
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.people,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connected Users',
                          style: UnifiedTypography.titleLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Consumer<SimpleBluetoothService>(
                          builder: (context, btService, child) {
                            final count = btService.connectedUsers.length;
                            return Text(
                              count > 0 ? '$count user(s) online' : _statusMessage,
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
            
            // Radar animation and users list
            Expanded(
              child: Consumer<SimpleBluetoothService>(
                builder: (context, btService, child) {
                  final users = btService.connectedUsers;
                  final isConnected = btService.isConnected;
                  
                  // Show radar if loading or not connected
                  if (!isConnected) {
                    return _buildNotConnectedState();
                  }
                  
                  if (_isLoading && users.isEmpty) {
                    return _buildRadarScanning();
                  }
                  
                  return users.isEmpty
                      ? _buildEmptyState()
                      : _buildUsersList(users);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadarScanning() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Radar animation
            SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Expanding circles
                  AnimatedBuilder(
                    animation: _radarAnimation,
                    builder: (context, child) {
                      return CustomPaint(
                        size: const Size(200, 200),
                        painter: RadarPainter(
                          progress: _radarAnimation.value,
                          color: AppColors.info,
                        ),
                      );
                    },
                  ),
                  
                  // Bluetooth icon with pulse
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.info.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.people,
                            color: AppColors.success,
                            size: 40,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Status text
            Text(
              _isLoading ? 'Loading users...' : 'No users found',
              style: UnifiedTypography.titleMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              _isLoading
                  ? 'Discovering users on the network...'
                  : 'Users will appear here when they connect',
              style: UnifiedTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotConnectedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bluetooth_disabled,
                color: AppColors.error,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Not Connected',
              style: UnifiedTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please connect to an ESP32 device first',
              style: UnifiedTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outline,
                color: AppColors.textSecondary,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Users Connected',
              style: UnifiedTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Users will appear here when they connect to the network',
              style: UnifiedTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersList(List<Map<String, dynamic>> users) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final isOnline = user['isOnline'] ?? false;
        final signalStrength = user['signalStrength'] ?? 0;
        final userName = user['name'] ?? 'Unknown User';
        final nodeId = user['nodeId'] ?? '';
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
              border: Border.all(
              color: isOnline 
                  ? AppColors.success.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isOnline 
                        ? AppColors.success.withOpacity(0.1)
                        : AppColors.textSecondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person,
                    color: isOnline ? AppColors.success : AppColors.textSecondary,
                    size: 28,
                  ),
                ),
                if (isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              userName,
              style: UnifiedTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  nodeId,
                  style: UnifiedTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (isOnline) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 8,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Online',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (signalStrength > 0) ...[
                      Icon(
                        Icons.signal_cellular_alt,
                        size: 14,
                        color: _getSignalColor(signalStrength),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$signalStrength/5',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getSignalColor(int strength) {
    if (strength >= 4) return AppColors.success;
    if (strength >= 2) return AppColors.warning;
    return AppColors.error;
  }
}

/// Custom painter for radar animation
class RadarPainter extends CustomPainter {
  final double progress;
  final Color color;

  RadarPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Draw multiple expanding circles
    for (int i = 0; i < 3; i++) {
      final circleProgress = (progress + i * 0.33) % 1.0;
      final radius = circleProgress * maxRadius;
      final opacity = 1.0 - circleProgress;
      
      if (opacity > 0) {
        final paint = Paint()
          ..color = color.withOpacity(opacity * 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        
        canvas.drawCircle(center, radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

