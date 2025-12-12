import 'package:flutter/material.dart';
import '../utils/color_system.dart';

/// Semantic Button Widget
/// 
/// Buttons with semantic colors (success, error, warning, info)
/// Automatically ensures WCAG-compliant contrast
class SemanticButton extends StatelessWidget {
  final SemanticColorType type;
  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final IconData? icon;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;

  const SemanticButton({
    super.key,
    required this.type,
    required this.label,
    this.onPressed,
    this.outlined = false,
    this.icon,
    this.width,
    this.height,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ColorSystem.getSemanticColor(type);

    return SizedBox(
      width: width,
      height: height ?? 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: outlined ? Colors.transparent : colors.background,
          foregroundColor: outlined ? colors.background : colors.text,
          side: outlined ? BorderSide(color: colors.background, width: 2) : null,
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: outlined ? 0 : 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Status Button Widget
/// 
/// Buttons with status colors (online, offline, connected, etc.)
class StatusButton extends StatelessWidget {
  final StatusType status;
  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final IconData? icon;
  final double? width;
  final double? height;

  const StatusButton({
    super.key,
    required this.status,
    required this.label,
    this.onPressed,
    this.outlined = false,
    this.icon,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final statusColors = ColorSystem.getStatusColor(status);

    return SizedBox(
      width: width,
      height: height ?? 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: outlined ? Colors.transparent : statusColors.color,
          foregroundColor: outlined ? statusColors.color : statusColors.text,
          side: outlined ? BorderSide(color: statusColors.color, width: 2) : null,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: outlined ? 0 : 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

