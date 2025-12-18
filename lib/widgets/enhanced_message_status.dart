import 'package:flutter/material.dart';
import '../services/voice_chat_extension.dart' as voice;

class EnhancedMessageStatus extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (status == voice.MessageStatus.failed) {
      return GestureDetector(
        onTap: onRetry,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 12,
              ),
              const SizedBox(width: 4),
              Text(
                'NOT SENT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    IconData iconData;
    Color color = iconColor ?? Colors.white70;

    switch (status) {
      case voice.MessageStatus.sending:
        return SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        );
      case voice.MessageStatus.sent:
        iconData = Icons.check;
        break;
      case voice.MessageStatus.delivered:
        iconData = Icons.done_all;
        break;
      case voice.MessageStatus.received:
        iconData = Icons.done_all;
        if (isRead) color = Colors.blue;
        break;
      case voice.MessageStatus.failed:
        // Already handled above, but included for exhaustiveness
        iconData = Icons.error_outline;
        color = Colors.red;
        break;
    }

    return Icon(
      iconData,
      size: size,
      color: color,
    );
  }
}
