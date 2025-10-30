import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../providers/network_provider.dart';
import 'call_detail_screen.dart';
import '../constants/unified_typography.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> with SingleTickerProviderStateMixin {
  bool _isCallActive = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;

  // UI state
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _activeFilter = 'All'; // All, Online, Offline
  bool _usersExpanded = false;

  late final AnimationController _usersController;
  late final Animation<double> _usersExpandAnim;

  @override
  void initState() {
    super.initState();
    _usersController = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _usersExpandAnim = CurvedAnimation(parent: _usersController, curve: Curves.easeInOutCubic);
    _usersController.value = 0.0; // start collapsed by default
  }

  @override
  void dispose() {
    _usersController.dispose();
    super.dispose();
  }

  // Sample connected users data
  final List<Map<String, dynamic>> _connectedUsers = [
    {
      'id': '1',
      'name': 'User 1',
      'isOnline': true,
      'signalStrength': 4,
      'batteryLevel': 85,
      'isMuted': false,
    },
    {
      'id': '2',
      'name': 'User 2',
      'isOnline': true,
      'signalStrength': 3,
      'batteryLevel': 72,
      'isMuted': true,
    },
    {
      'id': '3',
      'name': 'User 3',
      'isOnline': true,
      'signalStrength': 5,
      'batteryLevel': 95,
      'isMuted': false,
    },
    {
      'id': '4',
      'name': 'User 4',
      'isOnline': false,
      'signalStrength': 0,
      'batteryLevel': 0,
      'isMuted': false,
    },
    {
      'id': '5',
      'name': 'User 5',
      'isOnline': true,
      'signalStrength': 2,
      'batteryLevel': 45,
      'isMuted': false,
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
                          Text(
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

          // Filters & search (compact)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                _buildFilters(),
                const SizedBox(height: 8),
                _buildSearchField(),
              ],
            ),
          ),

          // Users drawer + list (non-scrollable, always shows all users)
          Builder(builder: (context) {
            final filtered = _connectedUsers.where((u) {
              final matchesFilter = _activeFilter == 'All'
                  ? true
                  : (_activeFilter == 'Online' ? u['isOnline'] == true : u['isOnline'] != true);
              final matchesQuery = _query.isEmpty ||
                  (u['name'] as String).toLowerCase().contains(_query.toLowerCase());
              return matchesFilter && matchesQuery;
            }).toList();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildUsersDrawerHeader(
                    total: _connectedUsers.length,
                    visible: filtered.length,
                  ),
                  SizeTransition(
                    sizeFactor: _usersExpandAnim,
                    axisAlignment: -1.0,
                    child: filtered.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text('No users found', style: TextStyle(color: AppColors.textSecondary)),
                            ),
                          )
                        : Column(
                            children: [
                              for (int index = 0; index < filtered.length; index++) ...[
                                AnimatedBuilder(
                                  animation: _usersController,
                                  builder: (context, child) {
                                    final t = _usersExpandAnim.value;
                                    final delay = (index * 0.06).clamp(0.0, 0.9);
                                    final effective = (t - delay).clamp(0.0, 1.0);
                                    return Opacity(
                                      opacity: effective,
                                      child: Transform.scale(
                                        scale: 0.98 + 0.02 * effective,
                                        child: Transform.translate(
                                          offset: Offset(0, (1 - effective) * 6),
                                          child: Stack(
                                            children: [
                                              // Ripple glow background expanding from the avatar side
                                              IgnorePointer(
                                                ignoring: true,
                                                child: Container(
                                                  height: 56,
                                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(12),
                                                    gradient: RadialGradient(
                                                      center: const Alignment(-0.95, 0.0),
                                                      radius: 0.8 + 0.4 * effective,
                                                      colors: [
                                                        AppColors.primaryRed.withOpacity(0.10 * effective),
                                                        Colors.transparent,
                                                      ],
                                                      stops: const [0.0, 1.0],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              child!,
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  child: _buildUserTile(filtered[index]),
                                ),
                                if (index != filtered.length - 1)
                                  const Divider(height: 1, thickness: 0.7, color: Color(0x11000000)),
                              ]
                            ],
                          ),
                  ),
                ],
              ),
            );
          }),

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

  // Compact user tile with status dot and trailing actions
  Widget _buildUserTile(Map<String, dynamic> user) {
    final bool isOnline = user['isOnline'] == true;
    final bool isMuted = user['isMuted'] == true;
    final String name = user['name'] as String;
    final int battery = user['batteryLevel'] as int;
    final int signal = user['signalStrength'] as int;

    // Style like the mock: white card by default, red-tinted when muted, green-tinted when idle/ok
    final bool idleGood = isOnline && !isMuted && signal >= 4;
    final Color bgColor = isMuted
        ? const Color(0xFFFFF1F1)
        : (idleGood ? const Color(0xFFF1FFF6) : Colors.white);
    final Color borderColor = isMuted
        ? const Color(0xFFFFCACA)
        : (idleGood ? const Color(0xFFC6F3D8) : const Color(0xFFE6E8EC));

    return InkWell(
      onTap: () => _initiateCall(context, user),
      borderRadius: BorderRadius.circular(14),
          child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        child: Row(
          children: [
            // Avatar + status dot
            Stack(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white,
                  child: Text(
                    _initials(name),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryRed,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isOnline ? AppColors.online : AppColors.mediumGray,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Name and meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        isOnline ? Icons.check_circle : Icons.remove_circle,
                        size: 14,
                        color: isOnline ? AppColors.online : AppColors.mediumGray,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOnline ? 'Active' : 'Idle',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.network_cell, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 2),
                      Text('$signal', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(width: 10),
                      const Icon(Icons.battery_full, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 2),
                      Text('$battery%', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Trailing small action (alert when muted, chevron for idle/ok, call otherwise)
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  isMuted
                      ? Icons.error_outline
                      : (idleGood ? Icons.expand_less : Icons.call),
                  size: 18,
                  color: isMuted
                      ? AppColors.primaryRed
                      : (idleGood ? AppColors.mediumGray : AppColors.primaryRed),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Drawer header with ripple splash and chevron
  Widget _buildUsersDrawerHeader({int? total, int? visible}) {
    final countText = (total != null && visible != null) ? 'Users ($visible/$total)' : 'Users';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _usersExpanded = !_usersExpanded;
            if (_usersExpanded) {
              _usersController.forward();
            } else {
              _usersController.reverse();
            }
          });
        },
        borderRadius: BorderRadius.circular(20),
        splashColor: AppColors.primaryRed.withOpacity(0.12),
        highlightColor: AppColors.primaryRed.withOpacity(0.06),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.wifi_tethering, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                countText,
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary, fontSize: 16),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: const Text('Emergency', style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
              const Spacer(),
              AnimatedRotation(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                turns: _usersExpanded ? 0.0 : 0.5,
                child: const Icon(Icons.expand_more, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final filters = ['All', 'Online', 'Offline'];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final label = filters[index];
          final bool selected = _activeFilter == label;
          return ChoiceChip(
            label: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textPrimary)),
            selected: selected,
            onSelected: (_) => setState(() => _activeFilter = label),
            selectedColor: AppColors.primaryRed,
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: selected ? AppColors.primaryRed : AppColors.lightGray.withOpacity(0.6))),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _query = v.trim()),
      decoration: InputDecoration(
        hintText: 'Search users...',
        prefixIcon: const Icon(Icons.search, color: AppColors.mediumGray),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.lightGray.withOpacity(0.6))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.lightGray.withOpacity(0.6))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5)),
      ),
      style: const TextStyle(fontSize: 14),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '';
    final first = parts.first.isNotEmpty ? parts.first[0] : '';
    final second = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    return (first + second).toUpperCase();
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
