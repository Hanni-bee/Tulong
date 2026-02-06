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

      case voice.MessageStatus.unconfirmed:
        return Icon(
          Icons.schedule,
          color: baseColor,
          size: widget.size,
        ).animate()
          .scale(duration: 200.ms, begin: const Offset(0.8, 0.8))
          .fadeIn(duration: 200.ms);

      case voice.MessageStatus.failed:
        return GestureDetector(
          onTap: widget.onRetry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3), // Darker background for contrast
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
                  color: Colors.white,
                  size: 13,
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
          .shake(duration: 600.ms, hz: 4);
    }
  }
}

