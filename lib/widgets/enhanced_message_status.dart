import 'package:flutter/material.dart';
import '../services/voice_chat_extension.dart' as voice;

/// Enhanced message status indicator widget
class EnhancedMessageStatus extends StatelessWidget {
  final voice.MessageStatus status;
  final bool isRead;
  final VoidCallback? onRetry;
  final Color? iconColor;
  final double size;

  const EnhancedMessageStatus({
    super.key,
    required this.status,
    required this.isRead,
    this.onRetry,
    this.iconColor,
    this.size = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (status) {
      case voice.MessageStatus.sending:
        icon = Icons.access_time;
        color = iconColor ?? Colors.orange;
        break;
      case voice.MessageStatus.sent:
        icon = Icons.check;
        color = iconColor ?? Colors.blue;
        break;
      case voice.MessageStatus.received:
        icon = Icons.done_all;
        color = iconColor ?? Colors.green;
        break;
      case voice.MessageStatus.failed:
        icon = Icons.error_outline;
        color = iconColor ?? Colors.red;
        break;
      default:
        icon = Icons.circle;
        color = iconColor ?? Colors.grey;
    }

    return GestureDetector(
      onTap: onRetry,
      child: Icon(
        icon,
        size: size,
        color: color,
      ),
    );
  }
}
