import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../services/voice_chat_extension.dart' as voice;

/// Enhanced Voice Message Visualization
/// 
/// Features:
/// - Animated waveform visualization
/// - Play/pause button with animation
/// - Duration and size display
/// - Progress indicator when playing
/// - Visual feedback on tap
class EnhancedVoiceMessageView extends StatefulWidget {
  final voice.VoiceMessage voiceMessage;
  final bool isMe;
  final VoidCallback? onPlay;
  final VoidCallback? onPause;
  final bool isPlaying;
  final Duration? currentPosition;

  const EnhancedVoiceMessageView({
    super.key,
    required this.voiceMessage,
    this.isMe = false,
    this.onPlay,
    this.onPause,
    this.isPlaying = false,
    this.currentPosition,
  });

  @override
  State<EnhancedVoiceMessageView> createState() => _EnhancedVoiceMessageViewState();
}

class _EnhancedVoiceMessageViewState extends State<EnhancedVoiceMessageView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    if (widget.isPlaying) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(EnhancedVoiceMessageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !oldWidget.isPlaying) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isPlaying && oldWidget.isPlaying) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  double get _progress {
    if (widget.currentPosition == null || widget.voiceMessage.duration == null) {
      return 0.0;
    }
    return (widget.currentPosition!.inMilliseconds / 
            widget.voiceMessage.duration!.inMilliseconds).clamp(0.0, 1.0);
  }

  String get _currentTime {
    if (widget.currentPosition != null && widget.voiceMessage.duration != null) {
      final pos = widget.currentPosition!;
      return '${pos.inSeconds}.${(pos.inMilliseconds % 1000 ~/ 100).toString().padLeft(1, '0')}s';
    }
    return widget.voiceMessage.formattedDuration;
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.isMe ? Colors.white : AppColors.primaryRed;
    final bgColor = widget.isMe 
        ? AppColors.primaryRed.withOpacity(0.2) 
        : AppColors.primaryRed.withOpacity(0.1);

    return GestureDetector(
      onTap: widget.isPlaying ? widget.onPause : widget.onPlay,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Play/Pause Button
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: widget.isPlaying ? _pulseAnimation.value : 1.0,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                      boxShadow: widget.isPlaying
                          ? [
                              BoxShadow(
                                color: accentColor.withOpacity(0.4),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(
                      widget.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: widget.isMe ? AppColors.primaryRed : Colors.white,
                      size: 24,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            
            // Waveform and Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Waveform Visualization
                  _buildWaveform(accentColor),
                  const SizedBox(height: 6),
                  
                  // Time and Size Info
                  Row(
                    children: [
                      Icon(
                        Icons.mic,
                        size: 12,
                        color: accentColor.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _currentTime,
                        style: AppTypography.bodySmall.copyWith(
                          color: accentColor.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.file_download,
                        size: 12,
                        color: accentColor.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.voiceMessage.formattedSize,
                        style: AppTypography.bodySmall.copyWith(
                          color: accentColor.withOpacity(0.7),
                          fontSize: 11,
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
    ).animate().scale(
      duration: 300.ms,
      begin: const Offset(0.95, 0.95),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildWaveform(Color accentColor) {
    // Simulated waveform bars
    final barCount = 20;
    final bars = List.generate(barCount, (index) {
      // Create animated waveform effect when playing
      double height = 0.3;
      if (widget.isPlaying) {
        // Simulate waveform with varying heights
        final position = index / barCount;
        final progress = _progress;
        final distance = (position - progress).abs();
        
        // Higher bars near current position
        if (distance < 0.1) {
          height = 0.9 - (distance * 5);
        } else if (distance < 0.2) {
          height = 0.5 - ((distance - 0.1) * 2);
        } else {
          height = 0.3 + (index % 3) * 0.1;
        }
        height = height.clamp(0.2, 1.0);
      } else {
        // Static waveform
        height = 0.3 + (index % 4) * 0.15;
      }

      return Container(
        width: 2,
        height: 16 * height,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.6),
          borderRadius: BorderRadius.circular(1),
        ),
      );
    });

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: bars,
    );
  }
}






