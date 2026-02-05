import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_colors.dart';
import 'emergency_badge.dart';
import '../models/emergency_detection_result.dart';
import '../models/emergency_type.dart';
import '../utils/emergency_message_parser.dart';
import '../services/voice_chat_extension.dart' as voice;

class ModernMessageBubble extends StatefulWidget {
  final String text;
  final String senderName;
  final DateTime timestamp;
  final bool isMe;
  final bool isEmergency;
  final bool isRead;
  final voice.MessageStatus status; // Added message status
  final Map<String, dynamic>? messageData; // Full message data for emergency parsing
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final VoidCallback? onRetry; // Added retry callback
  final SeverityLevel? severityLevel; // Severity level for unique UI styling
  final EmergencyType? emergencyType; // Emergency type for styling

  const ModernMessageBubble({
    super.key,
    required this.text,
    required this.senderName,
    required this.timestamp,
    required this.isMe,
    this.isEmergency = false,
    this.isRead = false,
    this.status = voice.MessageStatus.sent, // Default to sent
    this.messageData,
    this.onLongPress,
    this.onTap,
    this.onRetry,
    this.severityLevel, // Severity level for styling
    this.emergencyType, // Emergency type
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
                        // ENHANCED: Unique colors based on severity level
                        color: _getSeverityColor(),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: widget.isMe ? const Radius.circular(20) : const Radius.circular(4),
                          bottomRight: widget.isMe ? const Radius.circular(4) : const Radius.circular(20),
                        ),
                        border: Border.all(
                          color: _getSeverityBorderColor(),
                          width: widget.severityLevel != null ? 2.5 : (widget.isEmergency ? 2 : 1.5),
                        ),
                        boxShadow: widget.severityLevel != null ? [
                          BoxShadow(
                            color: _getSeverityColor().withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                            offset: const Offset(0, 2),
                          ),
                        ] : null,
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
                          
                          // Emergency badge (if emergency message)
                          if (widget.isEmergency) ...[
                            _buildEmergencyBadge(),
                            const SizedBox(height: 8),
                          ],
                          
                          // Message text
                          Text(
                            widget.text,
                            style: TextStyle(
                              // ENHANCED: Text color based on severity
                              color: _getTextColor(),
                              fontSize: 16,
                              height: 1.4,
                              fontWeight: widget.severityLevel != null || widget.isEmergency 
                                  ? FontWeight.w600 
                                  : FontWeight.w500,
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
                                    if (widget.status == voice.MessageStatus.failed) ...[
                                      GestureDetector(
                                        onTap: () {
                                          HapticFeedback.mediumImpact();
                                          widget.onRetry?.call();
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.3),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(0.6),
                                              width: 1.2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.2),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.error_rounded,
                                                size: 13,
                                                color: Colors.white,
                                              ),
                                              const SizedBox(width: 5),
                                              const Text(
                                                'NOT SENT',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 0.8,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                                       .shimmer(duration: 1200.ms, color: Colors.white.withOpacity(0.4))
                                       .scale(duration: 800.ms, begin: const Offset(1, 1), end: const Offset(1.08, 1.08))
                                       .shake(duration: 600.ms, hz: 4),
                                    ] else if (widget.status == voice.MessageStatus.sending) ...[
                                      const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                                        ),
                                      ),
                                    ] else if (widget.isRead) ...[
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

  /// Build emergency badge widget
  Widget _buildEmergencyBadge() {
    EmergencyDetectionResult? emergencyResult;
    
    // Try to parse emergency detection from message data
    if (widget.messageData != null) {
      emergencyResult = EmergencyMessageParser.parseFromMessageData(widget.messageData!);
    }
    
    // Fallback to parsing from text
    if (emergencyResult == null) {
      emergencyResult = EmergencyMessageParser.parseFromMessage(widget.text);
    }
    
    if (emergencyResult != null) {
      return EmergencyBadge(
        result: emergencyResult,
        showPulseAnimation: emergencyResult.severity == SeverityLevel.high ||
            emergencyResult.severity == SeverityLevel.critical,
      );
    }
    
    // Fallback: simple emergency indicator
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning, size: 16, color: AppColors.error),
          const SizedBox(width: 4),
          const Text(
            'Emergency',
            style: TextStyle(
              color: AppColors.error,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Get unique color based on severity level for AI-detected emergencies
  Color _getSeverityColor() {
    // If severity level is provided, use unique colors per severity
    if (widget.severityLevel != null) {
      switch (widget.severityLevel!) {
        case SeverityLevel.low:
          return widget.isMe 
              ? Colors.green.shade300  // Light green for low severity (sent)
              : Colors.green.shade50;   // Very light green for received
        case SeverityLevel.medium:
          return widget.isMe 
              ? Colors.orange.shade300  // Light orange for medium severity (sent)
              : Colors.orange.shade50;  // Very light orange for received
        case SeverityLevel.high:
          return widget.isMe 
              ? Colors.deepOrange.shade300  // Light deep orange for high severity (sent)
              : Colors.deepOrange.shade50;   // Very light deep orange for received
        case SeverityLevel.critical:
          return widget.isMe 
              ? Colors.red.shade300  // Light red for critical severity (sent)
              : Colors.red.shade50;  // Very light red for received
      }
    }
    
    // Fallback to original logic for non-AI messages
    if (widget.isMe) {
      return widget.isEmergency ? Colors.red.shade300 : AppColors.primaryRed;
    }
    return AppColors.white;
  }

  /// Get border color based on severity level
  Color _getSeverityBorderColor() {
    if (widget.severityLevel != null) {
      switch (widget.severityLevel!) {
        case SeverityLevel.low:
          return Colors.green.shade300;
        case SeverityLevel.medium:
          return Colors.orange.shade300;
        case SeverityLevel.high:
          return Colors.deepOrange.shade300;
        case SeverityLevel.critical:
          return Colors.red.shade300;
      }
    }
    
    // Fallback to original logic
    if (widget.isEmergency) {
      return Colors.red.shade300;
    }
    if (widget.isMe) {
      return Colors.white.withOpacity(0.2);
    }
    return AppColors.lightGray.withOpacity(0.5);
  }

  /// Get text color based on severity and message type
  Color _getTextColor() {
    if (widget.severityLevel != null) {
      // For severity-based messages, use white text on colored background (sent) or dark text (received)
      return widget.isMe ? AppColors.white : AppColors.textPrimary;
    }
    
    // Fallback to original logic
    return widget.isMe ? AppColors.white : AppColors.textPrimary;
  }
}