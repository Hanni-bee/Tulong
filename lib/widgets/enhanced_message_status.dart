import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/voice_chat_extension.dart' as voice;

/// Enhanced Message Status Indicator
/// 
/// Shows message status with animations:
/// - Sending: Animated clock
/// - Sent: Single checkmark
/// - Delivered: Double checkmark (gray)
/// - Read: Double checkmark (blue)
/// - Failed: Error icon with retry option
class EnhancedMessageStatus extends StatefulWidget {
  final voice.MessageStatus status;
  final bool isRead;
  final VoidCallback? onRetry;
  final Color? iconColor;
  final double size;

  const EnhancedMessageStatus({
    super.key,
    required this.status,
    this.isRead = false,
    this.onRetry,
    this.iconColor,
    this.size = 16.0,
  });

  @override
  State<EnhancedMessageStatus> createState() => _EnhancedMessageStatusState();
}

class _EnhancedMessageStatusState extends State<EnhancedMessageStatus>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    if (widget.status == voice.MessageStatus.sending) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(EnhancedMessageStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == voice.MessageStatus.sending) {
      _pulseController.repeat();
    } else {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.iconColor ?? Colors.white70;
    
    switch (widget.status) {
      case voice.MessageStatus.sending:
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Opacity(
              opacity: 0.5 + (_pulseController.value * 0.5),
              child: Icon(
                Icons.access_time,
                color: baseColor,
                size: widget.size,
              ),
            );
          },
        ).animate().scale(duration: 200.ms, begin: const Offset(0.8, 0.8));

      case voice.MessageStatus.sent:
        return Icon(
          Icons.check,
          color: baseColor,
          size: widget.size,
        ).animate()
          .scale(duration: 200.ms, begin: const Offset(0.8, 0.8))
          .fadeIn(duration: 200.ms);

      case voice.MessageStatus.delivered:
        return Icon(
          Icons.done_all,
          color: baseColor,
          size: widget.size,
        ).animate()
          .scale(duration: 200.ms, begin: const Offset(0.8, 0.8))
          .fadeIn(duration: 200.ms);

      case voice.MessageStatus.received:
        return Icon(
          Icons.done_all,
          color: widget.isRead ? Colors.blue[300] : baseColor,
          size: widget.size,
        ).animate()
          .scale(duration: 200.ms, begin: const Offset(0.8, 0.8))
          .fadeIn(duration: 200.ms);

      case voice.MessageStatus.failed:
        return GestureDetector(
          onTap: widget.onRetry,
          child: Tooltip(
            message: 'Tap to retry',
            child: Icon(
              Icons.error_outline,
              color: Colors.red[300],
              size: widget.size,
            ),
          ),
        ).animate()
          .shake(duration: 400.ms, hz: 4)
          .fadeIn(duration: 200.ms);
    }
  }
}

