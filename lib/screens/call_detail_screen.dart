import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/theme_colors.dart';

class CallDetailScreen extends StatefulWidget {
  final String contactName;
  final String contactId;
  final String? contactAvatar;
  final bool isIncoming;

  const CallDetailScreen({
    super.key,
    required this.contactName,
    required this.contactId,
    this.contactAvatar,
    this.isIncoming = false,
  });

  @override
  State<CallDetailScreen> createState() => _CallDetailScreenState();
}

class _CallDetailScreenState extends State<CallDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  
  bool _isCallActive = false;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  Duration _callDuration = Duration.zero;
  
  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    if (widget.isIncoming) {
      _startIncomingCallAnimation();
    } else {
      _startOutgoingCallAnimation();
    }
    
    // Start call duration timer
    _startCallTimer();
  }
  
  void _startIncomingCallAnimation() {
    _pulseController.repeat(reverse: true);
    _fadeController.forward();
  }
  
  void _startOutgoingCallAnimation() {
    _pulseController.repeat(reverse: true);
    _fadeController.forward();
  }
  
  void _startCallTimer() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isCallActive = true;
        });
        
        // Start duration timer
        _updateCallDuration();
      }
    });
  }
  
  void _updateCallDuration() {
    if (_isCallActive) {
      setState(() {
        _callDuration = Duration(seconds: _callDuration.inSeconds + 1);
      });
      
      Future.delayed(const Duration(seconds: 1), _updateCallDuration);
    }
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
  
  void _answerCall() {
    setState(() {
      _isCallActive = true;
    });
    _pulseController.stop();
  }
  
  void _endCall() {
    Navigator.of(context).pop();
  }
  
  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
  }
  
  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
  }
  

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      body: SafeArea(
        child: Column(
          children: [
            // Status bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isCallActive ? 'Call in progress' : 'Connecting...',
                    style: TextStyle(
                      color: ThemeColors.surface(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_isCallActive)
                    Text(
                      _formatDuration(_callDuration),
                      style: TextStyle(
                        color: ThemeColors.surface(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            
            // Main content
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Contact avatar
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryRed,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryRed.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: widget.contactAvatar != null
                              ? ClipOval(
                                  child: Image.network(
                                    widget.contactAvatar!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    widget.contactName.isNotEmpty
                                        ? widget.contactName[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: ThemeColors.surface(context),
                                      fontSize: 60,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Contact name
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      widget.contactName,
                      style: TextStyle(
                        color: ThemeColors.surface(context),
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Call status
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      _isCallActive
                          ? 'Connected'
                          : widget.isIncoming
                              ? 'Incoming call...'
                              : 'Calling...',
                      style: const TextStyle(
                        color: AppColors.lightGray,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                  
                  // Call controls
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Mute button
                        _buildControlButton(
                          icon: _isMuted ? Icons.mic_off : Icons.mic,
                          isActive: _isMuted,
                          onPressed: _toggleMute,
                        ),
                        
                        // Speaker button
                        _buildControlButton(
                          icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                          isActive: _isSpeakerOn,
                          onPressed: _toggleSpeaker,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Main call buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (widget.isIncoming && !_isCallActive) ...[
                        // Decline button
                        _buildCallButton(
                          icon: Icons.call_end,
                          color: AppColors.error,
                          onPressed: _endCall,
                        ),
                        const SizedBox(width: 40),
                        // Answer button
                        _buildCallButton(
                          icon: Icons.call,
                          color: AppColors.online,
                          onPressed: _answerCall,
                        ),
                      ] else ...[
                        // End call button
                        _buildCallButton(
                          icon: Icons.call_end,
                          color: AppColors.error,
                          onPressed: _endCall,
                        ),
                      ],
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
  
  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryRed : AppColors.mediumGray,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: ThemeColors.surface(context),
          size: 24,
        ),
      ),
    );
  }
  
  Widget _buildCallButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Icon(
          icon,
          color: ThemeColors.surface(context),
          size: 32,
        ),
      ),
    );
  }
}
