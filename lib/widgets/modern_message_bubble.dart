import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_colors.dart';
import '../models/message_model.dart';
import 'voice_message_bubble.dart';

class ModernMessageBubble extends StatefulWidget {
  final String text;
  final String senderName;
  final DateTime timestamp;
  final bool isMe;
  final bool isEmergency;
  final bool isRead;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final MessageModel? message;
  final dynamic voiceController;

  const ModernMessageBubble({
    super.key,
    required this.text,
    required this.senderName,
    required this.timestamp,
    required this.isMe,
    this.isEmergency = false,
    this.isRead = false,
    this.onLongPress,
    this.onTap,
    this.message,
    this.voiceController,
  });

  @override
  State<ModernMessageBubble> createState() => _ModernMessageBubbleState();
}

class _ModernMessageBubbleState extends State<ModernMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _animationController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    // Check if this is a voice message
    if (widget.message?.isVoiceMessage == true && widget.message?.voiceFilePath != null) {
      return VoiceMessageBubble(
        voiceFilePath: widget.message!.voiceFilePath!,
        duration: widget.message!.voiceDuration,
        senderName: widget.senderName,
        timestamp: widget.timestamp,
        isMe: widget.isMe,
        isEmergency: widget.isEmergency,
        isRead: widget.isRead,
        onLongPress: widget.onLongPress,
        voiceController: widget.voiceController,
      );
    }

    // Render regular text message
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
          
          // Message bubble
          Flexible(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: GestureDetector(
                    onTapDown: _handleTapDown,
                    onTapUp: _handleTapUp,
                    onTapCancel: _handleTapCancel,
                    onTap: widget.onTap,
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
                        boxShadow: _isPressed
                            ? [
                                // Pressed state - reduced shadow
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : [
                                // Normal state - raised shadow
                                BoxShadow(
                                  color: widget.isMe 
                                      ? (widget.isEmergency ? AppColors.error : AppColors.primaryRed)
                                          .withOpacity(0.2)
                                      : Colors.black.withOpacity(0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.8),
                                  blurRadius: 8,
                                  offset: const Offset(0, -2),
                                ),
                              ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!widget.isMe) ...[
                            // Sender name
                            Text(
                              widget.senderName,
                              style: TextStyle(
                                color: widget.isEmergency ? AppColors.error : AppColors.primaryRed,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          
                          // Message text
                          Text(
                            widget.text,
                            style: TextStyle(
                              color: widget.isMe ? AppColors.white : AppColors.textPrimary,
                              fontSize: 16,
                              height: 1.4,
                              fontWeight: widget.isEmergency ? FontWeight.w600 : FontWeight.w500,
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Timestamp and status
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatTime(widget.timestamp),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: widget.isMe 
                                      ? AppColors.white.withOpacity(0.7)
                                      : AppColors.mediumGray,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (widget.isMe) ...[
                                Row(
                                  children: [
                                    if (widget.isRead) ...[
                                      const Icon(
                                        Icons.done_all,
                                        size: 14,
                                        color: AppColors.success,
                                      ),
                                    ] else ...[
                                      const Icon(
                                        Icons.done,
                                        size: 14,
                                        color: AppColors.white,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
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