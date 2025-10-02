import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../widgets/modern_floating_layout.dart';
import '../widgets/enhanced_text_styles.dart';
import '../widgets/enhanced_shadows.dart' as shadows;

class WalkieTalkieScreen extends StatefulWidget {
  const WalkieTalkieScreen({super.key});

  @override
  State<WalkieTalkieScreen> createState() => _WalkieTalkieScreenState();
}

class _WalkieTalkieScreenState extends State<WalkieTalkieScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _recordingController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _recordingAnimation;
  
  bool _isTransmitting = false;
  bool _isListening = false;
  Duration _transmissionTime = Duration.zero;
  
  // Sample connected users
  final List<Map<String, dynamic>> _connectedUsers = [
    {
      'id': '1',
      'name': 'User 1',
      'isActive': true,
      'isMuted': false,
      'isSpeaking': false,
    },
    {
      'id': '2',
      'name': 'User 2',
      'isActive': true,
      'isMuted': true,
      'isSpeaking': false,
    },
    {
      'id': '3',
      'name': 'User 3',
      'isActive': true,
      'isMuted': false,
      'isSpeaking': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _recordingController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _recordingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _recordingController,
      curve: Curves.easeInOut,
    ));
    
    _pulseController.repeat(reverse: true);
  }
  
  void _startTransmission() {
    setState(() {
      _isTransmitting = true;
    });
    _recordingController.forward();
    _startTransmissionTimer();
  }
  
  void _stopTransmission() {
    setState(() {
      _isTransmitting = false;
    });
    _recordingController.reverse();
    _transmissionTime = Duration.zero;
  }
  
  void _startTransmissionTimer() {
    if (_isTransmitting) {
      setState(() {
        _transmissionTime = Duration(seconds: _transmissionTime.inSeconds + 1);
      });
      
      Future.delayed(const Duration(seconds: 1), _startTransmissionTimer);
    }
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
  
  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _recordingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ModernFloatingAppBarLayout(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              // Neumorphic shadow - outer shadow
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(8, 8),
              ),
              // Neumorphic shadow - inner highlight
              BoxShadow(
                color: Colors.white.withOpacity(0.8),
                blurRadius: 20,
                offset: const Offset(-8, -8),
              ),
            ],
          ),
          child: SafeArea(
            child: Container(
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  // Radio icon (consistent with other screens)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: shadows.EnhancedShadows.buttonLight,
                    ),
                    child: const Icon(
                      Icons.radio,
                      color: AppColors.primaryRed,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // App logo
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
                      child: Image.asset(
                        'assets/images/app_logo (3).png',
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Title and status
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SectionTitle('Walkie Talkie'),
                      ],
                    ),
                  ),
                  
                  // Settings button
                  _buildNeumorphicActionButton(
                    icon: Icons.settings,
                    onPressed: () => _showSettings(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      child: ModernFloatingLayout(
        hasFloatingAppBar: true,
        hasFloatingBottomBar: false,
        child: Column(
        children: [
          // Transmission status
          if (_isTransmitting)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.radio_button_checked,
                    color: AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Transmitting: ${_formatDuration(_transmissionTime)}',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          
          // Connected users list - Fixed height to prevent overlap
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              itemCount: _connectedUsers.length,
              itemBuilder: (context, index) {
                final user = _connectedUsers[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: user['isSpeaking'] 
                        ? Border.all(color: AppColors.success, width: 2)
                        : user['isMuted']
                            ? Border.all(color: AppColors.error, width: 2)
                            : Border.all(color: AppColors.lightGray.withOpacity(0.3), width: 1),
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
                      // User avatar
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: user['isActive'] 
                            ? AppColors.success 
                            : AppColors.mediumGray,
                        child: Text(
                          user['name'].toString().split(' ').map((n) => n[0]).join(''),
                          style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // User info
                      Expanded(
                        child: Text(
                          user['name'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      
                      // Status icons
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: user['isSpeaking'] 
                              ? AppColors.success
                              : user['isMuted']
                                  ? AppColors.error
                                  : AppColors.mediumGray,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          user['isSpeaking']
                              ? Icons.volume_up
                              : user['isMuted']
                                  ? Icons.mic_off
                                  : Icons.mic,
                          color: AppColors.white,
                          size: 14,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Walkie-talkie controls - Fixed at bottom, no overlap
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: AppColors.backgroundLight.withOpacity(0.8),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Main transmit button - Big and centered
                Center(
                  child: GestureDetector(
                    onTapDown: (_) => _startTransmission(),
                    onTapUp: (_) => _stopTransmission(),
                    onTapCancel: () => _stopTransmission(),
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _isTransmitting ? _recordingAnimation.value : _pulseAnimation.value,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: _isTransmitting ? AppColors.error : AppColors.primaryRed,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (_isTransmitting ? AppColors.error : AppColors.primaryRed).withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                            child: Icon(
                              _isTransmitting ? Icons.mic : Icons.mic,
                              color: AppColors.white,
                              size: 40,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Status text - Clear and centered
                Center(
                  child: Text(
                    _isTransmitting 
                        ? 'TRANSMITTING...'
                        : 'Hold to transmit',
                    style: TextStyle(
                      color: _isTransmitting ? AppColors.error : AppColors.primaryRed,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Additional controls - Horizontal layout at bottom
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Listen toggle
                    GestureDetector(
                      onTap: _toggleListening,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _isListening ? AppColors.online : AppColors.mediumGray,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          _isListening ? Icons.volume_up : Icons.volume_off,
                          color: AppColors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    
                    // Emergency button
                    GestureDetector(
                      onTap: () {
                        _sendEmergencyAlert();
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.error.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(2, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.emergency,
                          color: AppColors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
  
  void _sendEmergencyAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.emergency, color: AppColors.error),
            SizedBox(width: 8),
            Text('Emergency Alert'),
          ],
        ),
        content: const Text(
          'This will send an emergency alert to all connected users. Use only in genuine emergency situations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Emergency alert sent to all connected users'),
                  backgroundColor: AppColors.error,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Send Alert'),
          ),
        ],
      ),
    );
  }

  Widget _buildNeumorphicButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
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
      child: IconButton(
        icon: Icon(
          icon,
          color: AppColors.primaryRed,
          size: 20,
        ),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildNeumorphicActionButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(3, 3),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 6,
            offset: const Offset(-3, -3),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: AppColors.textPrimary,
          size: 18,
        ),
        onPressed: onPressed,
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildMenuOption(
                    icon: Icons.volume_up,
                    title: 'Audio Settings',
                    color: AppColors.primaryRed,
                    onTap: () {
                      Navigator.pop(context);
                      _showAudioSettings();
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildMenuOption(
                    icon: Icons.notifications,
                    title: 'Notification Settings',
                    color: AppColors.textSecondary,
                    onTap: () {
                      Navigator.pop(context);
                      _showNotificationSettings();
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildMenuOption(
                    icon: Icons.info_outline,
                    title: 'About Walkie Talkie',
                    color: AppColors.textSecondary,
                    onTap: () {
                      Navigator.pop(context);
                      _showAboutDialog(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(2, 2),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.8),
              blurRadius: 8,
              offset: const Offset(-2, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: AppColors.textSecondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showAudioSettings() {
    // TODO: Implement audio settings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Audio settings coming soon!'),
        backgroundColor: AppColors.primaryRed,
      ),
    );
  }

  void _showNotificationSettings() {
    // TODO: Implement notification settings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notification settings coming soon!'),
        backgroundColor: AppColors.primaryRed,
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('About Walkie Talkie'),
        content: const Text(
          'Walkie Talkie allows you to communicate with other users in real-time using voice messages. Hold the talk button to transmit your message.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
