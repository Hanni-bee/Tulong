import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_colors.dart';
import '../controllers/voice_controller.dart';

class VoiceMessageBubble extends StatefulWidget {
  final String voiceFilePath;
  final int duration;
  final String senderName;
  final DateTime timestamp;
  final bool isMe;
  final bool isEmergency;
  final bool isRead;
  final VoidCallback? onLongPress;
  final VoiceController? voiceController;

  const VoiceMessageBubble({
    super.key,
    required this.voiceFilePath,
    required this.duration,
    required this.senderName,
    required this.timestamp,
    required this.isMe,
    this.isEmergency = false,
    this.isRead = false,
    this.onLongPress,
    this.voiceController,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble>
    with TickerProviderStateMixin {
  late AnimationController _waveformController;
  late AnimationController _playButtonController;
  late Animation<double> _waveformAnimation;
  late Animation<double> _playButtonAnimation;

  bool _isPlaying = false;
  bool _isLoading = false;
  bool _hasError = false;
  int _currentPosition = 0;
  StreamSubscription<bool>? _playingSubscription;

  @override
  void initState() {
    super.initState();
    
    _waveformController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _playButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _waveformAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _waveformController,
      curve: Curves.easeInOut,
    ));

    _playButtonAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _playButtonController,
      curve: Curves.easeInOut,
    ));

    // Listen to voice controller playing state
    if (widget.voiceController != null) {
      _playingSubscription = widget.voiceController!.playingStream.listen((playing) {
        if (mounted) {
          setState(() {
            _isPlaying = playing;
          });
          
          if (playing) {
            _waveformController.repeat();
            _playButtonController.forward();
          } else {
            _waveformController.stop();
            _playButtonController.reverse();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _waveformController.dispose();
    _playButtonController.dispose();
    _playingSubscription?.cancel();
    super.dispose();
  }

  void _togglePlayback() async {
    if (widget.voiceController == null) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      if (_isPlaying) {
        await widget.voiceController!.stopAll();
      } else {
        await widget.voiceController!.playVoiceMessage(widget.voiceFilePath);
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        bottom: 8,
        left: widget.isMe ? 60 : 0,
        right: widget.isMe ? 0 : 60,
      ),
      child: Row(
        mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!widget.isMe) ...[
            // Avatar for other users
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: widget.isEmergency ? AppColors.error : AppColors.primaryRed,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: (widget.isEmergency ? AppColors.error : AppColors.primaryRed)
                        .withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  widget.senderName.isNotEmpty ? widget.senderName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          
          // Voice message bubble
          Flexible(
            child: GestureDetector(
              onTap: _togglePlayback,
              onLongPress: widget.onLongPress,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: widget.isMe 
                      ? (widget.isEmergency ? AppColors.error : AppColors.primaryRed)
                      : AppColors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: widget.isMe ? const Radius.circular(20) : const Radius.circular(4),
                    bottomRight: widget.isMe ? const Radius.circular(4) : const Radius.circular(20),
                  ),
                  border: widget.isEmergency 
                      ? Border.all(color: AppColors.error, width: 2)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Voice message content
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Play/Pause button
                        AnimatedBuilder(
                          animation: _playButtonAnimation,
                          builder: (context, child) {
                            return Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: widget.isMe 
                                    ? Colors.white.withOpacity(0.2)
                                    : AppColors.primaryRed.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: _isLoading
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Icon(
                                      _isPlaying ? Icons.pause : Icons.play_arrow,
                                      color: widget.isMe ? Colors.white : AppColors.primaryRed,
                                      size: 20,
                                    ),
                            );
                          },
                        ),
                        
                        const SizedBox(width: 12),
                        
                        // Waveform
                        Expanded(
                          child: _buildWaveform(),
                        ),
                        
                        const SizedBox(width: 12),
                        
                        // Duration
                        Text(
                          _formatDuration(widget.duration),
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.isMe 
                                ? Colors.white.withOpacity(0.8)
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    
                    if (_hasError) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Playback failed',
                        style: TextStyle(
                          fontSize: 10,
                          color: widget.isMe ? Colors.white70 : AppColors.error,
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 4),
                    
                    // Timestamp
                    Text(
                      _formatTime(widget.timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: widget.isMe 
                            ? Colors.white.withOpacity(0.6)
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          if (widget.isMe) ...[
            const SizedBox(width: 8),
            // Avatar for current user
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primaryRed,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryRed.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'Y',
                  style: TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate()
      .fadeIn(duration: 300.ms)
      .slideX(
        begin: widget.isMe ? 0.3 : -0.3,
        end: 0,
        duration: 300.ms,
        curve: Curves.easeOutCubic,
      );
  }

  Widget _buildWaveform() {
    return AnimatedBuilder(
      animation: _waveformAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(double.infinity, 30),
          painter: VoiceWaveformPainter(
            isPlaying: _isPlaying,
            animationValue: _waveformAnimation.value,
            isMe: widget.isMe,
            isEmergency: widget.isEmergency,
          ),
        );
      },
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }
}

class VoiceWaveformPainter extends CustomPainter {
  final bool isPlaying;
  final double animationValue;
  final bool isMe;
  final bool isEmergency;

  VoiceWaveformPainter({
    required this.isPlaying,
    required this.animationValue,
    required this.isMe,
    required this.isEmergency,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    // Set color based on message type
    if (isEmergency) {
      paint.color = AppColors.error;
    } else if (isMe) {
      paint.color = Colors.white.withOpacity(0.8);
    } else {
      paint.color = AppColors.primaryRed;
    }

    final barWidth = 3.0;
    final barSpacing = 2.0;
    final maxBarHeight = size.height * 0.8;
    final minBarHeight = size.height * 0.2;
    
    final totalBars = 20;
    final totalWidth = (totalBars * barWidth) + ((totalBars - 1) * barSpacing);
    final startX = (size.width - totalWidth) / 2;

    for (int i = 0; i < totalBars; i++) {
      final x = startX + (i * (barWidth + barSpacing));
      
      // Generate bar height based on position and animation
      final baseHeight = minBarHeight + (maxBarHeight - minBarHeight) * 
          (sin(i * 0.3) * 0.5 + 0.5);
      
      double currentHeight;
      if (isPlaying) {
        // Animate bars during playback
        final waveOffset = sin((i * 0.5) + (animationValue * 2 * pi)) * 0.3 + 0.7;
        currentHeight = baseHeight * waveOffset;
      } else {
        // Static bars when not playing
        currentHeight = baseHeight * 0.6;
      }
      
      final rect = Rect.fromLTWH(
        x,
        (size.height - currentHeight) / 2,
        barWidth,
        currentHeight,
      );
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(barWidth / 2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(VoiceWaveformPainter oldDelegate) {
    return oldDelegate.isPlaying != isPlaying ||
           oldDelegate.animationValue != animationValue ||
           oldDelegate.isMe != isMe ||
           oldDelegate.isEmergency != isEmergency;
  }
}
