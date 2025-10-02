import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'enhanced_shadows.dart';

class EnhancedIcons {
  // Standard icon sizes
  static const double xs = 12;
  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // Icon colors
  static const Color primary = AppColors.primaryRed;
  static const Color secondary = AppColors.textSecondary;
  static const Color accent = AppColors.primaryRed;
  static const Color successColor = AppColors.success;
  static const Color errorColor = AppColors.error;
  static const Color warningColor = AppColors.warning;

  // Common icon set
  static const IconData home = Icons.home_outlined;
  static const IconData homeFilled = Icons.home;
  static const IconData people = Icons.people_outline;
  static const IconData peopleFilled = Icons.people;
  static const IconData chat = Icons.chat_bubble_outline;
  static const IconData chatFilled = Icons.chat_bubble;
  static const IconData radio = Icons.radio;
  static const IconData radioFilled = Icons.radio;
  static const IconData profile = Icons.person_outline;
  static const IconData profileFilled = Icons.person;
  static const IconData message = Icons.message_outlined;
  static const IconData messageFilled = Icons.message;
  static const IconData emergency = Icons.emergency_outlined;
  static const IconData emergencyFilled = Icons.emergency;
  static const IconData notification = Icons.notifications_outlined;
  static const IconData notificationFilled = Icons.notifications;
  static const IconData settings = Icons.settings_outlined;
  static const IconData settingsFilled = Icons.settings;
  static const IconData search = Icons.search;
  static const IconData add = Icons.add;
  static const IconData edit = Icons.edit_outlined;
  static const IconData delete = Icons.delete_outline;
  static const IconData save = Icons.save_outlined;
  static const IconData send = Icons.send;
  static const IconData back = Icons.arrow_back_ios_new;
  static const IconData forward = Icons.arrow_forward_ios;
  static const IconData close = Icons.close;
  static const IconData menu = Icons.menu;
  static const IconData more = Icons.more_vert;
  static const IconData check = Icons.check;
  static const IconData cancel = Icons.cancel_outlined;
  static const IconData info = Icons.info_outline;
  static const IconData warningIcon = Icons.warning_outlined;
  static const IconData errorIcon = Icons.error_outline;
  static const IconData successIcon = Icons.check_circle_outline;
  static const IconData online = Icons.circle;
  static const IconData offline = Icons.circle_outlined;
  static const IconData mic = Icons.mic;
  static const IconData micOff = Icons.mic_off;
  static const IconData volume = Icons.volume_up;
  static const IconData volumeOff = Icons.volume_off;
  static const IconData location = Icons.location_on_outlined;
  static const IconData time = Icons.access_time;
  static const IconData date = Icons.calendar_today;
  static const IconData phone = Icons.phone;
  static const IconData email = Icons.email_outlined;
  static const IconData lock = Icons.lock_outline;
  static const IconData visibility = Icons.visibility_outlined;
  static const IconData visibilityOff = Icons.visibility_off_outlined;
}

// Enhanced icon widget with consistent styling
class EnhancedIcon extends StatelessWidget {
  final IconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  const EnhancedIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: size ?? EnhancedIcons.lg,
      color: color ?? EnhancedIcons.secondary,
      semanticLabel: semanticLabel,
    );
  }
}

// Icon button with enhanced styling
class EnhancedIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double? size;
  final Color? iconColor;
  final Color? backgroundColor;
  final String? tooltip;
  final bool showBackground;
  final List<BoxShadow>? shadows;

  const EnhancedIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size,
    this.iconColor,
    this.backgroundColor,
    this.tooltip,
    this.showBackground = true,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final buttonSize = size ?? EnhancedIcons.xl;
    final iconSize = buttonSize * 0.6;

    Widget iconWidget = Icon(
      icon,
      size: iconSize,
      color: iconColor ?? EnhancedIcons.primary,
    );

    if (showBackground) {
      iconWidget = Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: backgroundColor ?? AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: shadows ?? EnhancedShadows.buttonLight,
        ),
        child: Center(child: iconWidget),
      );
    }

    if (tooltip != null) {
      iconWidget = Tooltip(
        message: tooltip!,
        child: iconWidget,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: iconWidget,
      ),
    );
  }
}

// Status indicator icon
class StatusIcon extends StatelessWidget {
  final bool isOnline;
  final double size;
  final Color? onlineColor;
  final Color? offlineColor;

  const StatusIcon({
    super.key,
    required this.isOnline,
    this.size = 12,
    this.onlineColor,
    this.offlineColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isOnline 
          ? (onlineColor ?? EnhancedIcons.successColor)
          : (offlineColor ?? EnhancedIcons.secondary),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.white,
          width: 1.5,
        ),
      ),
    );
  }
}

// Icon with badge
class BadgedIcon extends StatelessWidget {
  final IconData icon;
  final String? badgeText;
  final Color? badgeColor;
  final Color? badgeTextColor;
  final double? size;
  final Color? iconColor;

  const BadgedIcon({
    super.key,
    required this.icon,
    this.badgeText,
    this.badgeColor,
    this.badgeTextColor,
    this.size,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          icon,
          size: size ?? EnhancedIcons.lg,
          color: iconColor ?? EnhancedIcons.secondary,
        ),
        if (badgeText != null && badgeText!.isNotEmpty)
          Positioned(
            right: -8,
            top: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor ?? EnhancedIcons.errorColor,
                borderRadius: BorderRadius.circular(10),
                boxShadow: EnhancedShadows.buttonLight,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                badgeText!,
                style: TextStyle(
                  color: badgeTextColor ?? AppColors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

// Icon with label
class IconWithLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final double? iconSize;
  final double? fontSize;
  final Color? iconColor;
  final Color? textColor;
  final MainAxisAlignment alignment;

  const IconWithLabel({
    super.key,
    required this.icon,
    required this.label,
    this.iconSize,
    this.fontSize,
    this.iconColor,
    this.textColor,
    this.alignment = MainAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: iconSize ?? EnhancedIcons.lg,
          color: iconColor ?? EnhancedIcons.secondary,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize ?? 12,
            fontWeight: FontWeight.w500,
            color: textColor ?? EnhancedIcons.secondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// Floating action icon
class FloatingActionIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double? size;
  final String? tooltip;

  const FloatingActionIcon({
    super.key,
    required this.icon,
    this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = size ?? 56;
    final iconIconSize = iconSize * 0.6;

    Widget iconWidget = Container(
      width: iconSize,
      height: iconSize,
      decoration: BoxDecoration(
        color: backgroundColor ?? EnhancedIcons.primary,
        shape: BoxShape.circle,
        boxShadow: EnhancedShadows.buttonStrong,
      ),
      child: Icon(
        icon,
        size: iconIconSize,
        color: iconColor ?? AppColors.white,
      ),
    );

    if (tooltip != null) {
      iconWidget = Tooltip(
        message: tooltip!,
        child: iconWidget,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(iconSize / 2),
        onTap: onPressed,
        child: iconWidget,
      ),
    );
  }
}
