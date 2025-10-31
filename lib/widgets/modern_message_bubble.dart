import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_colors.dart';

class ModernMessageBubble extends StatefulWidget {
  final String text;
  final String senderName;
  final DateTime timestamp;
  final bool isMe;
  final bool isEmergency;
  final bool isRead;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

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
  });

  @override
  State<ModernMessageBubble> createState() => _ModernMessageBubbleState();
}

class _ModernMessageBubbleState extends State<ModernMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150), // Standardized with PolishedBounce
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95, // Consistent with PolishedBounce scale
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut, // Consistent with PolishedBounce
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _animationController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _animationController.reverse();
  }

  void _handleTapCancel() {
    _animationController.reverse();
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
                border: Border.all(
                  color: AppColors.white.withOpacity(0.3),
                  width: 1.5,
                ),
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
                        border: Border.all(
                          color: widget.isEmergency 
                              ? AppColors.error 
                              : widget.isMe 
                                  ? Colors.white.withOpacity(0.2)
                                  : AppColors.lightGray.withOpacity(0.5),
                          width: widget.isEmergency ? 2 : 1.5,
                        ),
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
                border: Border.all(
                  color: AppColors.white.withOpacity(0.3),
                  width: 1.5,
                ),
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
      .fadeIn(duration: 400.ms, curve: Curves.easeOutCubic) // Standardized duration
      .slideX(
        begin: widget.isMe ? 0.2 : -0.2, // Reduced slide distance for subtlety
        end: 0,
        duration: 400.ms,
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