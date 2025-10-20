import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../widgets/modern_floating_layout.dart';
import '../widgets/enhanced_text_styles.dart';
import '../widgets/enhanced_shadows.dart' as shadows;
import '../services/hardware_service.dart';
import '../widgets/hardware_status_widgets.dart';

class WalkieTalkieScreen extends StatefulWidget {
  const WalkieTalkieScreen({super.key});

  @override
  State<WalkieTalkieScreen> createState() => _WalkieTalkieScreenState();
}

class _WalkieTalkieScreenState extends State<WalkieTalkieScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _recordingController;
  late AnimationController _voiceLevelController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _recordingAnimation;
  late Animation<double> _voiceLevelAnimation;
  
  bool _isTransmitting = false;
  bool _isListening = false;
  Duration _transmissionTime = Duration.zero;
  
  // Sample connected users with enhanced data
  final List<Map<String, dynamic>> _connectedUsers = [
    {
      'id': '1',
      'name': 'John Smith',
      'isActive': true,
      'isMuted': false,
      'isSpeaking': false,
      'connectionQuality': 'excellent', // excellent, good, fair, poor
      'voiceLevel': 0.0, // 0.0 to 1.0
      'lastSeen': DateTime.now().subtract(const Duration(minutes: 2)),
      'role': 'admin',
    },
    {
      'id': '2',
      'name': 'Maria Garcia',
      'isActive': true,
      'isMuted': true,
      'isSpeaking': false,
      'connectionQuality': 'good',
      'voiceLevel': 0.0,
      'lastSeen': DateTime.now().subtract(const Duration(minutes: 5)),
      'role': 'member',
    },
    {
      'id': '3',
      'name': 'David Lee',
      'isActive': true,
      'isMuted': false,
      'isSpeaking': true,
      'connectionQuality': 'excellent',
      'voiceLevel': 0.8,
      'lastSeen': DateTime.now(),
      'role': 'member',
    },
    {
      'id': '4',
      'name': 'Sarah Johnson',
      'isActive': false,
      'isMuted': false,
      'isSpeaking': false,
      'connectionQuality': 'poor',
      'voiceLevel': 0.0,
      'lastSeen': DateTime.now().subtract(const Duration(minutes: 15)),
      'role': 'member',
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
    
    _voiceLevelController = AnimationController(
      duration: const Duration(milliseconds: 300),
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
    
    _voiceLevelAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _voiceLevelController,
      curve: Curves.easeInOut,
    ));
    
    _pulseController.repeat(reverse: true);
    _voiceLevelController.repeat(reverse: true);
  }
  
  void _startTransmission() {
    HapticFeedback.heavyImpact(); // Heavy vibration when starting
    setState(() {
      _isTransmitting = true;
    });
    _recordingController.forward();
    _startTransmissionTimer();
  }
  
  void _stopTransmission() {
    HapticFeedback.mediumImpact(); // Medium vibration when stopping
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
    _voiceLevelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.white,
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
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SectionTitle('Walkie Talkie'),
                        SizedBox(height: 4),
                        Text(
                          'Ready',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
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
      body: SafeArea(
        child: Column(
          children: [
              // Connected users list - Polished design
              Container(
                height: 220, // Optimized height to fit all 4 users
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.white,
                        AppColors.white.withOpacity(0.95),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primaryRed.withOpacity(0.15),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryRed.withOpacity(0.08),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.8),
                        blurRadius: 15,
                        offset: const Offset(-2, -2),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(2, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      children: [
                        // Header for users list with polished gradient
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                AppColors.primaryRed.withOpacity(0.08),
                                AppColors.primaryRed.withOpacity(0.03),
                              ],
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                            border: const Border(
                              bottom: BorderSide(
                                color: Color(0x10E53935),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFFE53935),
                                          Color(0xFFD32F2F),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primaryRed.withOpacity(0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.people,
                                      color: AppColors.white,
                                      size: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Users (${_connectedUsers.where((u) => u['isActive']).length}/${_connectedUsers.length})',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          'Emergency',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Connection quality indicator - Polished with glow
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: AppColors.success,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.success.withOpacity(0.5),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Users list - Fixed height, scrollable
                        SizedBox(
                          height: 155,
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
                            itemCount: _connectedUsers.length,
                            itemBuilder: (context, index) {
                              final user = _connectedUsers[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: user['isSpeaking'] 
                                      ? LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppColors.success.withOpacity(0.15),
                                            AppColors.success.withOpacity(0.08),
                                          ],
                                        )
                                      : user['isActive'] 
                                          ? LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                AppColors.white,
                                                AppColors.white.withOpacity(0.98),
                                              ],
                                            )
                                          : LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                AppColors.mediumGray.withOpacity(0.1),
                                                AppColors.mediumGray.withOpacity(0.05),
                                              ],
                                            ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: user['isSpeaking'] 
                                        ? AppColors.success
                                        : user['isMuted']
                                            ? AppColors.error
                                            : user['isActive']
                                                ? AppColors.primaryRed.withOpacity(0.2)
                                                : AppColors.mediumGray.withOpacity(0.5),
                                    width: user['isSpeaking'] || user['isMuted'] ? 2 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 2),
                                    ),
                                    if (user['isSpeaking'])
                                      BoxShadow(
                                        color: AppColors.success.withOpacity(0.3),
                                        blurRadius: 15,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 0),
                                      ),
                                    if (user['isMuted'])
                                      BoxShadow(
                                        color: AppColors.error.withOpacity(0.2),
                                        blurRadius: 12,
                                        spreadRadius: 1,
                                        offset: const Offset(0, 0),
                                      ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // User avatar with status indicator
                                    Stack(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            gradient: user['isActive'] 
                                                ? const LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [
                                                      Color(0xFFE53935),
                                                      Color(0xFFD32F2F),
                                                    ],
                                                  )
                                                : LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [
                                                      AppColors.mediumGray,
                                                      AppColors.mediumGray.withOpacity(0.8),
                                                    ],
                                                  ),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: user['isSpeaking'] 
                                                  ? AppColors.success
                                                  : user['isMuted']
                                                      ? AppColors.error
                                                      : AppColors.white,
                                              width: 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: user['isActive']
                                                    ? AppColors.primaryRed.withOpacity(0.3)
                                                    : Colors.black.withOpacity(0.1),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Text(
                                              user['name'].toString().split(' ').map((n) => n[0]).join(''),
                                              style: const TextStyle(
                                                color: AppColors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Status dot with glow
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: user['isSpeaking'] 
                                                  ? AppColors.success
                                                  : user['isMuted']
                                                      ? AppColors.error
                                                      : AppColors.online,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: AppColors.white,
                                                width: 2,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: (user['isSpeaking'] 
                                                      ? AppColors.success
                                                      : user['isMuted']
                                                          ? AppColors.error
                                                          : AppColors.online).withOpacity(0.6),
                                                  blurRadius: 4,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    const SizedBox(width: 10),
                                    
                                    // User info - Compact
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                user['name'],
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: user['isActive'] 
                                                      ? AppColors.textPrimary
                                                      : AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            user['isSpeaking'] 
                                                ? 'Speaking'
                                                : user['isMuted']
                                                    ? 'Muted'
                                                    : 'Active',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: user['isSpeaking'] 
                                                  ? AppColors.success
                                                  : user['isMuted']
                                                      ? AppColors.error
                                                      : AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Status action button
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: user['isSpeaking'] 
                                            ? AppColors.success.withOpacity(0.1)
                                            : user['isMuted']
                                                ? AppColors.error.withOpacity(0.1)
                                                : AppColors.primaryRed.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: user['isSpeaking'] 
                                              ? AppColors.success
                                              : user['isMuted']
                                                  ? AppColors.error
                                                  : AppColors.primaryRed,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Icon(
                                        user['isSpeaking']
                                            ? Icons.volume_up
                                            : user['isMuted']
                                                ? Icons.mic_off
                                                : Icons.mic,
                                        color: user['isSpeaking'] 
                                            ? AppColors.success
                                            : user['isMuted']
                                                ? AppColors.error
                                                  : AppColors.primaryRed,
                                        size: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // Walkie-talkie controls - Polished design
              Container(
                height: 300, // Optimized height
                margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.white,
                        AppColors.white.withOpacity(0.96),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.primaryRed.withOpacity(0.15),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryRed.withOpacity(0.1),
                        blurRadius: 24,
                        spreadRadius: 2,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.8),
                        blurRadius: 18,
                        offset: const Offset(-3, -3),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(3, 3),
                      ),
                    ],
                  ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header for controls - Polished
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFE53935),
                                Color(0xFFD32F2F),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryRed.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.radio,
                            color: AppColors.white,
                            size: 13,
                          ),
                        ),
                        const SizedBox(width: 7),
                        const Text(
                          'Voice Controls',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    
                    // Main transmit button - Enhanced with better feedback
                    Center(
                      child: GestureDetector(
                        onTapDown: (_) {
                          HapticFeedback.mediumImpact();
                          _startTransmission();
                        },
                        onTapUp: (_) {
                          HapticFeedback.lightImpact();
                          _stopTransmission();
                        },
                        onTapCancel: () {
                          HapticFeedback.lightImpact();
                          _stopTransmission();
                        },
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _isTransmitting ? _recordingAnimation.value : _pulseAnimation.value,
                              child: Container(
                                width: 95,
                                height: 95,
                                decoration: BoxDecoration(
                                  gradient: _isTransmitting 
                                      ? const RadialGradient(
                                          colors: [
                                            Color(0xFFFF5252),
                                            Color(0xFFE53935),
                                          ],
                                          center: Alignment(-0.3, -0.3),
                                        )
                                      : const RadialGradient(
                                          colors: [
                                            Color(0xFFE53935),
                                            Color(0xFFD32F2F),
                                          ],
                                          center: Alignment(-0.3, -0.3),
                                        ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (_isTransmitting ? AppColors.error : AppColors.primaryRed).withOpacity(0.5),
                                      blurRadius: 20,
                                      spreadRadius: 5,
                                      offset: const Offset(0, 0),
                                    ),
                                    BoxShadow(
                                      color: (_isTransmitting ? AppColors.error : AppColors.primaryRed).withOpacity(0.3),
                                      blurRadius: 30,
                                      spreadRadius: 8,
                                      offset: const Offset(0, 6),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 10,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    const Icon(
                                      Icons.mic,
                                      color: AppColors.white,
                                      size: 33,
                                    ),
                                    if (_isTransmitting)
                                      Positioned(
                                        top: 20,
                                        right: 20,
                                        child: Container(
                                          width: 16,
                                          height: 16,
                                          decoration: const BoxDecoration(
                                            color: AppColors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.radio_button_checked,
                                            color: AppColors.error,
                                            size: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 14),
                    
                    // Additional controls - Optimized
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Listen toggle - Polished
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _toggleListening();
                          },
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: _isListening 
                                  ? const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF4CAF50),
                                        Color(0xFF388E3C),
                                      ],
                                    )
                                  : LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppColors.mediumGray,
                                        AppColors.mediumGray.withOpacity(0.9),
                                      ],
                                    ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isListening ? AppColors.online : AppColors.mediumGray).withOpacity(0.4),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 4),
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  _isListening ? Icons.volume_up : Icons.volume_off,
                                  color: AppColors.white,
                                  size: 22,
                                ),
                                if (_isListening)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppColors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Emergency button - Polished
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.heavyImpact();
                            _sendEmergencyAlert();
                          },
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFFF5252),
                                  Color(0xFFE53935),
                                ],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.error.withOpacity(0.5),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 4),
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.emergency,
                              color: AppColors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 7),
                    
                    // Control labels - Optimized
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Text(
                          'Listen',
                          style: TextStyle(
                            color: _isListening ? AppColors.online : AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Text(
                          'Emergency',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // Status text - Optimized
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: _isTransmitting 
                              ? AppColors.error.withOpacity(0.1)
                              : AppColors.primaryRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isTransmitting 
                                ? AppColors.error.withOpacity(0.3)
                                : AppColors.primaryRed.withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isTransmitting ? Icons.radio_button_checked : Icons.mic,
                              color: _isTransmitting ? AppColors.error : AppColors.primaryRed,
                              size: 15,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              _isTransmitting 
                                  ? 'TRANSMITTING...'
                                  : 'Hold to transmit',
                              style: TextStyle(
                                color: _isTransmitting ? AppColors.error : AppColors.primaryRed,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Transmission timer - Optimized
                    if (_isTransmitting)
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.error.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${_formatDuration(_transmissionTime)}',
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
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

  // Helper methods for enhanced functionality
  Color _getConnectionQualityColor(String quality) {
    switch (quality.toLowerCase()) {
      case 'excellent':
        return AppColors.success;
      case 'good':
        return AppColors.online;
      case 'fair':
        return AppColors.warning;
      case 'poor':
        return AppColors.error;
      default:
        return AppColors.mediumGray;
    }
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 14,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _unmuteAllUsers() {
    setState(() {
      for (var user in _connectedUsers) {
        user['isMuted'] = false;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('All users unmuted'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _muteAllUsers() {
    setState(() {
      for (var user in _connectedUsers) {
        user['isMuted'] = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('All users muted'),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _refreshUsers() {
    HapticFeedback.mediumImpact();
    // Simulate refreshing user list
    setState(() {
      // Update last seen times
      for (var user in _connectedUsers) {
        if (user['isActive']) {
          user['lastSeen'] = DateTime.now();
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('User list refreshed'),
        backgroundColor: AppColors.primaryRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
