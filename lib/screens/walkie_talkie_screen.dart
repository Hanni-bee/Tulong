import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../widgets/unified_top_bar.dart';

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
  // Users drawer state
  bool _usersExpanded = false;
  late final AnimationController _usersController = AnimationController(vsync: this, duration: const Duration(milliseconds: 350))..value = 0.0;
  late final Animation<double> _usersExpandAnim = CurvedAnimation(parent: _usersController, curve: Curves.easeInOutCubic);
  late AnimationController _emergencyHoldController;
  bool _isEmergencyHolding = false;
  
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
    _emergencyHoldController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          HapticFeedback.heavyImpact();
          _isEmergencyHolding = false;
          _emergencyHoldController.reset();
          _sendEmergencyAlert();
        }
      });
    
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

  void _refreshConnections() {
    // Refresh connected users
    setState(() {
      // Simulate refresh - in real app, this would fetch from service
    });
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings'),
        content: const Text('Settings options will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _recordingController.dispose();
    _voiceLevelController.dispose();
    _usersController.dispose();
    _emergencyHoldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Unified top bar
          TopBarConfigs.callsTopBar(
            status: _isTransmitting ? 'Transmitting...' : null,
            onRefresh: _refreshConnections,
            onSettings: _showSettingsDialog,
          ),
          // Accent line provided by UnifiedTopBar; removed duplicate here

          // Main content (non-scrollable; uses Flexible/Expanded to adapt)
          Expanded(
            child: SafeArea(
              child: Column(
                children: [
              // Connected users list - Collapsible, auto-height
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFE53935).withOpacity(0.15),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    children: [
                      // Tap header to expand/collapse
                      Material(
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
                          splashColor: const Color(0xFFE53935).withOpacity(0.12),
                          highlightColor: const Color(0xFFE53935).withOpacity(0.06),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE53935), // solid red header
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: AppColors.white, // white container
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.people, color: Color(0xFFE53935), size: 15),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Users (${_connectedUsers.where((u) => u['isActive']).length}/${_connectedUsers.length})',
                                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.white),
                                            ),
                                            const Text('Emergency', style: TextStyle(fontSize: 11, color: AppColors.white)),
                                          ],
                                        ),
                                      ),
                                      AnimatedRotation(
                                        duration: const Duration(milliseconds: 250),
                                        turns: _usersExpanded ? 0.0 : 0.5,
                                        child: const Icon(Icons.expand_more, color: AppColors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Collapsible list with staggered ripple (capped height for safety)
                      SizeTransition(
                        sizeFactor: _usersExpandAnim,
                        axisAlignment: -1.0,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            // Cap max height to keep controls visible on small screens
                            maxHeight: MediaQuery.of(context).size.height * 0.38,
                          ),
                          child: ListView.separated(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                          itemCount: _connectedUsers.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final user = _connectedUsers[index];
                            return AnimatedBuilder(
                              animation: _usersController,
                              builder: (context, child) {
                                final t = _usersExpandAnim.value;
                                final delay = (index * 0.08).clamp(0.0, 0.9);
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
                                              margin: const EdgeInsets.symmetric(horizontal: 2),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(12),
                                                gradient: RadialGradient(
                                                  center: const Alignment(-0.95, 0.0),
                                                  radius: 0.8 + 0.4 * effective,
                                                  colors: [
                                                    const Color(0xFFE53935).withOpacity(0.10 * effective),
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
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: user['isSpeaking']
                                      ? const Color(0xFF27AE60).withOpacity(0.15)
                                      : user['isActive']
                                          ? AppColors.white
                                          : const Color(0xFF7F8C8D).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: user['isSpeaking']
                                        ? const Color(0xFF27AE60)
                                        : user['isMuted']
                                            ? const Color(0xFFE53935)
                                            : user['isActive']
                                                ? const Color(0xFFE53935).withOpacity(0.2)
                                                : const Color(0xFF7F8C8D).withOpacity(0.5),
                                    width: user['isSpeaking'] || user['isMuted'] ? 2 : 1,
                                  ),
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
                                            color: user['isActive'] 
                                                ? const Color(0xFFE53935)
                                                : const Color(0xFF7F8C8D),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: user['isSpeaking'] 
                                                  ? const Color(0xFF27AE60)
                                                  : user['isMuted']
                                                      ? const Color(0xFFE53935)
                                                      : AppColors.white,
                                              width: 2,
                                            ),
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
                                                  ? const Color(0xFF27AE60)
                                                  : user['isMuted']
                                                      ? const Color(0xFFE53935)
                                                      : const Color(0xFF27AE60),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: AppColors.white,
                                                width: 2,
                                              ),
                                              boxShadow: const [],
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
                                                      ? const Color(0xFF27AE60)
                                                      : user['isMuted']
                                                          ? const Color(0xFFE53935)
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
                                            ? const Color(0xFF27AE60).withOpacity(0.1)
                                            : user['isMuted']
                                                ? const Color(0xFFE53935).withOpacity(0.1)
                                                : const Color(0xFFE53935).withOpacity(0.1),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: user['isSpeaking'] 
                                              ? const Color(0xFF27AE60)
                                              : user['isMuted']
                                                  ? const Color(0xFFE53935)
                                                  : const Color(0xFFE53935),
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
                                            ? const Color(0xFF27AE60)
                                            : user['isMuted']
                                                ? const Color(0xFFE53935)
                                                  : const Color(0xFFE53935),
                                        size: 14,
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
                    ],
                  ),
                ),
              ),
              ),
              
              // Walkie-talkie controls - adapts to remaining space
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFFE53935).withOpacity(0.15),
                      width: 1.5,
                    ),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double _micSize = (constraints.maxHeight * 0.36).clamp(68.0, 95.0);
                      final double _btnSize = (constraints.maxHeight * 0.16).clamp(36.0, 56.0);
                      return Column(
                        mainAxisSize: MainAxisSize.max,
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
                                color: const Color(0xFFE53935).withOpacity(0.3),
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
                    const SizedBox(height: 8),
                    // Main transmit button - Responsive
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Center(
                        child: SizedBox(
                          width: _micSize,
                          height: _micSize,
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
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE53935),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                        width: 2,
                                      ),
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Icon(Icons.mic, color: AppColors.white, size: _micSize * 0.34),
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
                                                color: Color(0xFFE53935),
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
                            width: _btnSize,
                            height: _btnSize,
                            decoration: BoxDecoration(
                              color: _isListening 
                                  ? const Color(0xFF27AE60)
                                  : const Color(0xFF7F8C8D),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 2,
                              ),
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
                        
                        // Emergency button - Hold to confirm with centered ring
                        GestureDetector(
                          onLongPressStart: (_) {
                            HapticFeedback.selectionClick();
                            setState(() => _isEmergencyHolding = true);
                            _emergencyHoldController.forward(from: 0);
                          },
                          onLongPressEnd: (_) {
                            if (_emergencyHoldController.status != AnimationStatus.completed) {
                              _emergencyHoldController.reverse(from: _emergencyHoldController.value);
                            }
                            setState(() => _isEmergencyHolding = false);
                          },
                          onLongPressCancel: () {
                            _emergencyHoldController.reverse(from: _emergencyHoldController.value);
                            setState(() => _isEmergencyHolding = false);
                          },
                          child: SizedBox(
                            width: _btnSize + 18,
                            height: _btnSize + 18,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: _btnSize + 12,
                                  height: _btnSize + 12,
                                  child: AnimatedBuilder(
                                    animation: _emergencyHoldController,
                                    builder: (context, _) => CircularProgressIndicator(
                                      value: _isEmergencyHolding ? _emergencyHoldController.value : 0,
                                      strokeWidth: 6,
                                      backgroundColor: const Color(0xFFE53935).withOpacity(0.12),
                                      valueColor: const AlwaysStoppedAnimation(Color(0xFFE53935)),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: _btnSize,
                                  height: _btnSize,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE53935),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.emergency,
                                    color: AppColors.white,
                                    size: 22,
                                  ),
                                ),
                              ],
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
                            color: _isListening ? const Color(0xFF27AE60) : AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Text(
                          'Emergency',
                          style: TextStyle(
                            color: Color(0xFFE53935),
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
                          color: const Color(0xFFE53935).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFE53935).withOpacity(0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isTransmitting ? Icons.radio_button_checked : Icons.mic,
                              color: const Color(0xFFE53935),
                              size: 15,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              _isTransmitting ? 'TRANSMITTING...' : 'Hold to transmit',
                              style: const TextStyle(
                                color: Color(0xFFE53935),
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
                    Visibility(
                      visible: _isTransmitting,
                      child: Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE53935).withOpacity(0.2),
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
                                color: Color(0xFFE53935),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${_formatDuration(_transmissionTime)}',
                              style: const TextStyle(
                                color: Color(0xFFE53935),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _sendEmergencyAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.emergency, color: Color(0xFFE53935)),
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
                  backgroundColor: Color(0xFFE53935),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFE53935),
              foregroundColor: AppColors.white,
            ),
            child: const Text('Send Alert'),
          ),
        ],
      ),
    );
  }





}
