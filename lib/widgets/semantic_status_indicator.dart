import 'package:flutter/material.dart';
import '../utils/color_system.dart';

/// Semantic Status Indicator Widget
/// 
/// Displays status with consistent color coding:
/// - Online/Connected: Green
/// - Offline/Disconnected: Gray
/// - Muted: Orange/Warning
/// - Active: Cyan
/// - Inactive: Gray
class SemanticStatusIndicator extends StatelessWidget {
  final StatusType status;
  final String? label;
  final bool showDot;
  final bool showLabel;
  final double dotSize;
  final TextStyle? labelStyle;

  const SemanticStatusIndicator({
    super.key,
    required this.status,
    this.label,
    this.showDot = true,
    this.showLabel = true,
    this.dotSize = 8.0,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    final statusColors = ColorSystem.getStatusColor(status);
    final displayLabel = label ?? _getDefaultLabel(status);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDot)
          Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: statusColors.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: statusColors.color.withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        if (showDot && showLabel) const SizedBox(width: 6),
        if (showLabel)
          Text(
            displayLabel,
            style: labelStyle ??
                TextStyle(
                  color: statusColors.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
          ),
      ],
    );
  }

  String _getDefaultLabel(StatusType status) {
    switch (status) {
      case StatusType.online:
        return 'Online';
      case StatusType.offline:
        return 'Offline';
      case StatusType.muted:
        return 'Muted';
      case StatusType.active:
        return 'Active';
      case StatusType.inactive:
        return 'Inactive';
      case StatusType.connected:
        return 'Connected';
      case StatusType.disconnected:
        return 'Disconnected';
    }
  }
}

/// Semantic Badge Widget
/// 
/// Displays badges with semantic colors (success, error, warning, info)
class SemanticBadge extends StatelessWidget {
  final SemanticColorType type;
  final String label;
  final bool filled;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;

  const SemanticBadge({
    super.key,
    required this.type,
    required this.label,
    this.filled = true,
    this.fontSize,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ColorSystem.getSemanticColor(type);

    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? colors.background : Colors.transparent,
        border: filled ? null : Border.all(color: colors.background, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: filled ? colors.text : colors.background,
          fontSize: fontSize ?? 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Status Badge Widget
/// 
/// Displays status badges with consistent color coding
class StatusBadge extends StatelessWidget {
  final StatusType status;
  final String? label;
  final bool filled;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;

  const StatusBadge({
    super.key,
    required this.status,
    this.label,
    this.filled = true,
    this.fontSize,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final statusColors = ColorSystem.getStatusColor(status);
    final displayLabel = label ?? _getDefaultLabel(status);

    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? statusColors.color : Colors.transparent,
        border: filled ? null : Border.all(color: statusColors.color, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayLabel,
        style: TextStyle(
          color: filled ? statusColors.text : statusColors.color,
          fontSize: fontSize ?? 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _getDefaultLabel(StatusType status) {
    switch (status) {
      case StatusType.online:
        return 'Online';
      case StatusType.offline:
        return 'Offline';
      case StatusType.muted:
        return 'Muted';
      case StatusType.active:
        return 'Active';
      case StatusType.inactive:
        return 'Inactive';
      case StatusType.connected:
        return 'Connected';
      case StatusType.disconnected:
        return 'Disconnected';
    }
  }
}

