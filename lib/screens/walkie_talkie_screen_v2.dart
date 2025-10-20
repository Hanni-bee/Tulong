import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../widgets/enhanced_shadows.dart' as shadows;
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(8, 8),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.9),
            blurRadius: 20,
            offset: const Offset(-8, -8),
          ),
        ],
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
              boxShadow: shadows.EnhancedShadows.buttonLight,
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(4, 4),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.8),
                  blurRadius: 8,
                  offset: const Offset(-4, -4),
                ),
              ],
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.people, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                Text(
                  'Connected Users (${_connectedUsers.length}/4)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 120,
            child: ListView.builder(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _connectedUsers.length,
              itemBuilder: (context, i) {
                final u = _connectedUsers[i];
                return ListTile(
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
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
                    boxShadow: [
                      BoxShadow(
                        color: (_isTransmitting ? AppColors.error : AppColors.primaryRed)
                            .withOpacity(0.35),
                        blurRadius: 14,
                        spreadRadius: 4,
                        offset: const Offset(0, 6),
                      ),
                    ],
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
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4)),
          ],
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


