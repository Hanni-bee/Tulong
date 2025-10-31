import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Solid color badge widget for displaying counts/notifications
/// Consistent with the app's solid design system
class SolidBadge extends StatelessWidget {
  final int count;
  final Color? backgroundColor;
  final Color? textColor;
  final double? size;
  final bool showDot; // If true, shows a dot instead of count

  const SolidBadge({
    super.key,
    required this.count,
    this.backgroundColor,
    this.textColor,
    this.size,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0 && !showDot) return const SizedBox.shrink();

    final badgeSize = size ?? (showDot ? 8.0 : 18.0);
    final bgColor = backgroundColor ?? AppColors.primaryRed;
    final txtColor = textColor ?? AppColors.white;

    if (showDot) {
      return Container(
        width: badgeSize,
        height: badgeSize,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(
        minWidth: badgeSize,
        minHeight: badgeSize,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.white,
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          count > 99 ? '99+' : count.toString(),
          style: TextStyle(
            color: txtColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            height: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

