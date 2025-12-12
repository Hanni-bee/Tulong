import 'package:flutter/material.dart';
import '../utils/color_system.dart';
import '../constants/app_colors.dart';

/// Semantic Card Widget
/// 
/// Cards with semantic color accents (success, error, warning, info)
class SemanticCard extends StatelessWidget {
  final SemanticColorType? type;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? elevation;
  final bool showBorder;
  final VoidCallback? onTap;

  const SemanticCard({
    super.key,
    this.type,
    required this.child,
    this.padding,
    this.margin,
    this.elevation,
    this.showBorder = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color? borderColor;
    Color? backgroundColor;

    if (type != null) {
      final colors = ColorSystem.getSemanticColor(type!);
      borderColor = showBorder ? colors.background : null;
      backgroundColor = colors.light.withOpacity(0.1);
    }

    Widget card = Container(
      margin: margin ?? const EdgeInsets.all(8),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: borderColor != null
            ? Border.all(color: borderColor, width: 2)
            : null,
        boxShadow: elevation != null
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: elevation!,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      );
    }

    return card;
  }
}

/// Status Card Widget
/// 
/// Cards with status color accents (online, offline, connected, etc.)
class StatusCard extends StatelessWidget {
  final StatusType status;
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? elevation;
  final bool showBorder;
  final VoidCallback? onTap;

  const StatusCard({
    super.key,
    required this.status,
    required this.child,
    this.padding,
    this.margin,
    this.elevation,
    this.showBorder = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColors = ColorSystem.getStatusColor(status);

    Widget card = Container(
      margin: margin ?? const EdgeInsets.all(8),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColors.background.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: showBorder
            ? Border.all(color: statusColors.color, width: 2)
            : null,
        boxShadow: elevation != null
            ? [
                BoxShadow(
                  color: statusColors.color.withOpacity(0.2),
                  blurRadius: elevation!,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      );
    }

    return card;
  }
}

