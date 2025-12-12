import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'package:provider/provider.dart';
import '../services/hardware_service.dart';
import '../widgets/hardware_status_widgets.dart';

class WalkieTalkieScreenV2 extends StatefulWidget {
  const WalkieTalkieScreenV2({super.key});

  @override
  State<WalkieTalkieScreenV2> createState() => _WalkieTalkieScreenV2State();
}

class _WalkieTalkieScreenV2State extends State<WalkieTalkieScreenV2>
    with TickerProviderStateMixin {
  final List<Map<String, dynamic>> _connectedUsers = [
    {
      'name': 'John Smith',
      'isActive': true,
      'isMuted': false,
      'isSpeaking': false,
    },
    {
      'name': 'Maria Garcia',
      'isActive': true,
      'isMuted': true,
      'isSpeaking': false,
    },
    {
      'name': 'David Lee',
      'isActive': true,
      'isMuted': false,
      'isSpeaking': true,
    },
  ];

  bool _isTransmitting = false;
  bool _isListening = false;
  bool _usersExpanded = false;
  late final AnimationController _usersController = AnimationController(vsync: this, duration: const Duration(milliseconds: 350))..value = 0.0;
  late final Animation<double> _usersExpandAnim = CurvedAnimation(parent: _usersController, curve: Curves.easeInOutCubic);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: ScrollConfiguration(
          behavior: const _NoScrollbarsBehavior(),
          child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 12),
              _buildUsersCard(),
              const SizedBox(height: 12),
              Expanded(child: _buildControlsCard()),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.radio, color: AppColors.primaryRed, size: 24),
          ),
          const SizedBox(width: 16),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset('assets/images/app_logo (3).png', fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Walkie Talkie',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Consumer<HardwareService>(
                  builder: (context, hardwareService, _) => HardwareStatusBar(hardwareService: hardwareService),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings, color: AppColors.textPrimary),
          )
        ],
      ),
    );
  }

  Widget _buildUsersCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryRed.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              splashColor: AppColors.primaryRed.withOpacity(0.12),
              highlightColor: AppColors.primaryRed.withOpacity(0.06),
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.wifi_tethering, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Users (${_connectedUsers.length}/4)',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.primaryRed.withOpacity(0.3))),
                      child: const Text('Emergency', style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                    const Spacer(),
                    AnimatedRotation(
                      duration: const Duration(milliseconds: 250),
                      turns: _usersExpanded ? 0.0 : 0.5,
                      child: const Icon(Icons.expand_more, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          SizeTransition(
            sizeFactor: _usersExpandAnim,
            axisAlignment: -1.0,
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _connectedUsers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final u = _connectedUsers[i];
                return AnimatedBuilder(
                  animation: _usersController,
                  builder: (context, child) {
                    final t = _usersExpandAnim.value;
                    final delay = (i * 0.08).clamp(0.0, 0.9);
                    final effective = (t - delay).clamp(0.0, 1.0);
                    return Opacity(
                      opacity: effective,
                      child: Transform.scale(
                        scale: 0.98 + 0.02 * effective,
                        child: Transform.translate(
                          offset: Offset(0, (1 - effective) * 8),
                          child: Stack(
                            children: [
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
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: CircleAvatar(
                      backgroundColor: u['isActive'] ? AppColors.primaryRed : AppColors.mediumGray,
                      child: Text(
                        u['name']
                            .toString()
                            .split(' ')
                            .map((n) => n.isNotEmpty ? n[0] : '')
                            .take(2)
                            .join(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                    title: Text(
                      u['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      u['isMuted'] ? 'Muted' : (u['isSpeaking'] ? 'Speaking' : 'Idle'),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    trailing: Icon(
                      u['isMuted'] ? Icons.volume_off : Icons.volume_up,
                      color: u['isMuted'] ? AppColors.error : AppColors.online,
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildControlsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primaryRed.withOpacity(0.18)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.radio, color: AppColors.primaryRed, size: 18),
              SizedBox(width: 8),
              Text('Voice Controls',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  )),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTapDown: (_) => setState(() => _isTransmitting = true),
                onTapUp: (_) => setState(() => _isTransmitting = false),
                onTapCancel: () => setState(() => _isTransmitting = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: _isTransmitting ? AppColors.error : AppColors.primaryRed,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic, color: Colors.white, size: 34),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _circleAction(
                icon: _isListening ? Icons.volume_up : Icons.volume_off,
                color: _isListening ? AppColors.online : AppColors.mediumGray,
                onTap: () => setState(() => _isListening = !_isListening),
              ),
              _circleAction(
                icon: Icons.emergency,
                color: AppColors.error,
                onTap: () {},
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _circleAction({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

}

class _NoScrollbarsBehavior extends ScrollBehavior {
  const _NoScrollbarsBehavior();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child; // no glow
  }

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child; // no scrollbar
  }
}


