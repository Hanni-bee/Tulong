import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class PrivateCallScreen extends StatefulWidget {
  final String contactName;
  final String contactId;
  final String? contactAvatar;
  final bool isVideoCall;

  const PrivateCallScreen({
    super.key,
    required this.contactName,
    required this.contactId,
    this.contactAvatar,
    this.isVideoCall = false,
  });

  @override
  State<PrivateCallScreen> createState() => _PrivateCallScreenState();
}

class _PrivateCallScreenState extends State<PrivateCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _recordingController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _recordingAnimation;
  
  final bool _isConnected = true;
  bool _isTransmitting = false;
  bool _isListening = false;
  Duration _transmissionTime = Duration.zero;
  
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
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      appBar: AppBar(
        backgroundColor: AppColors.darkGray,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'CALLING ${widget.contactName.toUpperCase()}',
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isConnected ? AppColors.online : AppColors.offline,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isConnected ? 'Connected' : 'Disconnected',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                if (_isTransmitting)
                  Text(
                    _formatDuration(_transmissionTime),
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          
          // Contact info
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
                        width: 150,
                        height: 150,
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
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 30),
                
                // Contact name
                Text(
                  widget.contactName,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Call status
                Text(
                  _isTransmitting
                      ? 'Transmitting...'
                      : 'Ready to transmit',
                  style: const TextStyle(
                    color: AppColors.lightGray,
                    fontSize: 16,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Walkie-talkie controls
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Main transmit button
                      GestureDetector(
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
                      
                      const SizedBox(height: 16),
                      
                      // Status text
                      Text(
                        _isTransmitting 
                            ? 'TRANSMITTING... Hold to speak'
                            : 'Hold to transmit',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Additional controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Listen toggle
                          GestureDetector(
                            onTap: _toggleListening,
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: _isListening ? AppColors.online : AppColors.mediumGray,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isListening ? Icons.volume_up : Icons.volume_off,
                                color: AppColors.white,
                                size: 24,
                              ),
                            ),
                          ),
                          
                          // End call button
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop();
                            },
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: const BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.call_end,
                                color: AppColors.white,
                                size: 24,
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
        ],
      ),
    );
  }
}
