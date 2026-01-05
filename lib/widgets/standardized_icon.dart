import 'package:flutter/material.dart';
import '../utils/icon_system.dart';
import '../constants/app_colors.dart';

/// Standardized Icon Widget
/// 
/// Provides consistent icon styling throughout the app
class StandardizedIcon extends StatelessWidget {
  final IconData icon;
  final IconContext? context;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  const StandardizedIcon(
    this.icon, {
    super.key,
    this.context,
    this.size,
    this.color,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = size ?? 
        (this.context != null 
            ? IconSystem.getSizeForContext(this.context!)
            : IconSystem.lg);
    
    final iconColor = color ?? IconSystem.secondary;

    return Icon(
      icon,
      size: iconSize,
      color: iconColor,
      semanticLabel: semanticLabel,
    );
  }
}

/// Semantic Icon Widget
/// 
/// Icons with semantic colors (success, error, warning, info)
class SemanticIcon extends StatelessWidget {
  final SemanticIconType type;
  final bool filled;
  final double? size;
  final String? semanticLabel;

  const SemanticIcon({
    super.key,
    required this.type,
    this.filled = false,
    this.size,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (type) {
      case SemanticIconType.success:
        icon = filled ? IconSystem.successFilled : IconSystem.success;
        break;
      case SemanticIconType.error:
        icon = filled ? IconSystem.errorFilled : IconSystem.error;
        break;
      case SemanticIconType.warning:
        icon = filled ? IconSystem.warningFilled : IconSystem.warning;
        break;
      case SemanticIconType.info:
        icon = filled ? IconSystem.infoFilled : IconSystem.info;
        break;
    }

    return StandardizedIcon(
      icon,
      size: size ?? IconSystem.lg,
      color: IconSystem.getSemanticColor(type),
      semanticLabel: semanticLabel,
    );
  }
}

/// Status Icon Widget
/// 
/// Icons with status colors (online, offline, muted, etc.)
class StatusIcon extends StatelessWidget {
  final StatusIconType type;
  final double? size;
  final String? semanticLabel;

  const StatusIcon({
    super.key,
    required this.type,
    this.size,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (type) {
      case StatusIconType.online:
        icon = IconSystem.statusOnline;
        break;
      case StatusIconType.offline:
        icon = IconSystem.statusOffline;
        break;
      case StatusIconType.muted:
        icon = IconSystem.statusMuted;
        break;
      case StatusIconType.active:
        icon = IconSystem.statusActive;
        break;
      case StatusIconType.inactive:
        icon = IconSystem.statusInactive;
        break;
      case StatusIconType.connected:
        icon = IconSystem.statusConnected;
        break;
      case StatusIconType.disconnected:
        icon = IconSystem.statusDisconnected;
        break;
    }

    return StandardizedIcon(
      icon,
      size: size ?? IconSystem.statusIndicator,
      color: IconSystem.getStatusColor(type),
      semanticLabel: semanticLabel,
    );
  }
}

/// Navigation Icon Widget
/// 
/// Icons for navigation bar with active/inactive states
class NavigationIcon extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final bool isActive;
  final double? size;
  final Color? activeColor;
  final Color? inactiveColor;

  const NavigationIcon({
    super.key,
    required this.icon,
    required this.activeIcon,
    required this.isActive,
    this.size,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return StandardizedIcon(
      isActive ? activeIcon : icon,
      context: IconContext.navigation,
      size: size,
      color: isActive 
          ? (activeColor ?? IconSystem.primary)
          : (inactiveColor ?? IconSystem.secondary),
    );
  }
}

/// Quick Action Icon Widget
/// 
/// Icons for quick action cards
class QuickActionIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double? size;
  final Color? backgroundColor;

  const QuickActionIcon({
    super.key,
    required this.icon,
    this.color,
    this.size,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (size ?? IconSystem.quickAction) + 16,
      height: (size ?? IconSystem.quickAction) + 16,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.primaryRed.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: StandardizedIcon(
          icon,
          context: IconContext.quickAction,
          size: size,
          color: color ?? IconSystem.primary,
        ),
      ),
    );
  }
}

/// Settings Item Icon Widget
/// 
/// Icons for settings items
class SettingsItemIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double? size;

  const SettingsItemIcon({
    super.key,
    required this.icon,
    this.color,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (size ?? IconSystem.settingsItem) + 8,
      height: (size ?? IconSystem.settingsItem) + 8,
      decoration: BoxDecoration(
        color: (color ?? IconSystem.primary).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: StandardizedIcon(
          icon,
          context: IconContext.settingsItem,
          size: size,
          color: color ?? IconSystem.primary,
        ),
      ),
    );
  }
}

/// Action Button Icon Widget
/// 
/// Icons for action buttons
class ActionButtonIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double? size;

  const ActionButtonIcon({
    super.key,
    required this.icon,
    this.color,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    return StandardizedIcon(
      icon,
      context: IconContext.actionButton,
      size: size,
      color: color ?? IconSystem.primary,
    );
  }
}








