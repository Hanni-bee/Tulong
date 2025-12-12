import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../utils/standardized_spacing.dart';

/// Enhanced Card System
/// 
/// Provides:
/// - Consistent card elevation/shadow
/// - Better card hover/press states
/// - Improved card content layout
/// - Card animations (subtle entrance)
class EnhancedCardSystem {
  // ============================================================================
  // CARD ELEVATION LEVELS
  // ============================================================================

  /// Level 0: Flat cards (no shadow)
  static const double elevation0 = 0.0;

  /// Level 1: Subtle elevation (cards, list items)
  static const double elevation1 = 2.0;

  /// Level 2: Standard elevation (interactive cards)
  static const double elevation2 = 4.0;

  /// Level 3: Prominent elevation (featured cards)
  static const double elevation3 = 8.0;

  /// Level 4: Maximum elevation (modals, dialogs)
  static const double elevation4 = 16.0;

  // ============================================================================
  // CARD SHADOWS
  // ============================================================================

  /// Get shadow for elevation level
  static List<BoxShadow> getShadow(double elevation) {
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: elevation,
        offset: Offset(0, elevation / 2),
        spreadRadius: 0,
      ),
      BoxShadow(
        color: Colors.black.withOpacity(0.02),
        blurRadius: elevation * 2,
        offset: Offset(0, elevation),
        spreadRadius: -elevation / 2,
      ),
    ];
  }

  /// Get pressed shadow (reduced elevation)
  static List<BoxShadow> getPressedShadow(double elevation) {
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.03),
        blurRadius: elevation / 2,
        offset: Offset(0, elevation / 4),
        spreadRadius: 0,
      ),
    ];
  }

  /// Get hover shadow (increased elevation)
  static List<BoxShadow> getHoverShadow(double elevation) {
    return [
      BoxShadow(
        color: Colors.black.withOpacity(0.08),
        blurRadius: elevation * 1.5,
        offset: Offset(0, elevation * 0.75),
        spreadRadius: elevation / 4,
      ),
      BoxShadow(
        color: Colors.black.withOpacity(0.03),
        blurRadius: elevation * 3,
        offset: Offset(0, elevation * 1.5),
        spreadRadius: -elevation / 2,
      ),
    ];
  }

  // ============================================================================
  // CARD BORDER RADIUS
  // ============================================================================

  /// Small border radius (8px)
  static const double radiusSmall = 8.0;

  /// Medium border radius (12px) - Standard
  static const double radiusMedium = 12.0;

  /// Large border radius (16px)
  static const double radiusLarge = 16.0;

  /// Extra large border radius (20px)
  static const double radiusXLarge = 20.0;
}

/// Enhanced Card Widget
/// 
/// A polished card with consistent elevation, hover/press states, and entrance animations
class EnhancedCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double? elevation;
  final double? borderRadius;
  final Border? border;
  final VoidCallback? onTap;
  final bool enableHover;
  final bool enablePress;
  final bool enableEntrance;
  final Duration? entranceDelay;
  final Color? hoverColor;
  final Color? pressColor;

  const EnhancedCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.elevation,
    this.borderRadius,
    this.border,
    this.onTap,
    this.enableHover = true,
    this.enablePress = true,
    this.enableEntrance = true,
    this.entranceDelay,
    this.hoverColor,
    this.pressColor,
  });

  @override
  State<EnhancedCard> createState() => _EnhancedCardState();
}

class _EnhancedCardState extends State<EnhancedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _entranceController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  late Animation<Color?> _colorAnimation;
  late Animation<double> _entranceAnimation;

  bool _isHovered = false;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();

    // Press/Hover animation controller
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    // Entrance animation controller
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Scale animation for press
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.98,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // Elevation animation for hover/press
    _elevationAnimation = Tween<double>(
      begin: 0.0,
      end: -2.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // Color animation for hover/press
    _colorAnimation = ColorTween(
      begin: widget.backgroundColor ?? AppColors.white,
      end: widget.pressColor ?? AppColors.lightGray.withOpacity(0.3),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // Entrance animation
    _entranceAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));

    // Start entrance animation
    if (widget.enableEntrance) {
      Future.delayed(widget.entranceDelay ?? Duration.zero, () {
        if (mounted) {
          _entranceController.forward();
        }
      });
    } else {
      _entranceController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.enablePress && widget.onTap != null) {
      setState(() => _isPressed = true);
      HapticFeedback.lightImpact();
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.enablePress && widget.onTap != null) {
      setState(() => _isPressed = false);
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.enablePress && widget.onTap != null) {
      setState(() => _isPressed = false);
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveElevation = widget.elevation ?? EnhancedCardSystem.elevation2;
    final effectiveBorderRadius = widget.borderRadius ?? EnhancedCardSystem.radiusMedium;

    Widget card = AnimatedBuilder(
      animation: Listenable.merge([_controller, _entranceController]),
      builder: (context, child) {
        final currentElevation = _isHovered && widget.enableHover
            ? effectiveElevation * 1.5
            : effectiveElevation + _elevationAnimation.value;
        
        final currentColor = _isPressed && widget.enablePress
            ? _colorAnimation.value
            : (widget.backgroundColor ?? AppColors.white);

        return Transform.scale(
          scale: _entranceAnimation.value * (_isPressed ? _scaleAnimation.value : 1.0),
          child: Transform.translate(
            offset: Offset(0, _elevationAnimation.value),
            child: Opacity(
              opacity: _entranceAnimation.value,
              child: Container(
                margin: widget.margin ?? StandardizedSpacing.cardMargin(context),
                padding: widget.padding ?? StandardizedSpacing.cardPadding(context),
                decoration: BoxDecoration(
                  color: currentColor,
                  borderRadius: BorderRadius.circular(effectiveBorderRadius),
                  border: widget.border,
                  boxShadow: _isPressed && widget.enablePress
                      ? EnhancedCardSystem.getPressedShadow(effectiveElevation)
                      : _isHovered && widget.enableHover
                          ? EnhancedCardSystem.getHoverShadow(effectiveElevation)
                          : EnhancedCardSystem.getShadow(currentElevation),
                ),
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onTap,
        child: MouseRegion(
          onEnter: (_) {
            if (widget.enableHover) {
              setState(() => _isHovered = true);
            }
          },
          onExit: (_) {
            if (widget.enableHover) {
              setState(() => _isHovered = false);
            }
          },
          child: card,
        ),
      );
    }

    return card;
  }
}

/// Quick Action Card
/// 
/// Specialized card for quick actions with icon and title
class QuickActionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final Duration? entranceDelay;

  const QuickActionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
    this.entranceDelay,
  });

  @override
  Widget build(BuildContext context) {
    return EnhancedCard(
      onTap: onTap,
      enableEntrance: true,
      entranceDelay: entranceDelay,
      elevation: EnhancedCardSystem.elevation2,
      borderRadius: EnhancedCardSystem.radiusMedium,
      padding: StandardizedSpacing.cardPadding(context),
      margin: EdgeInsets.only(
        right: StandardizedSpacing.listItemSpacing(context),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: EnhancedCardSystem.getShadow(2.0),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// Status Card
/// 
/// Specialized card for status indicators
class StatusCard extends StatelessWidget {
  final String label;
  final String? subLabel;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final Duration? entranceDelay;

  const StatusCard({
    super.key,
    required this.label,
    this.subLabel,
    required this.icon,
    required this.color,
    this.onTap,
    this.entranceDelay,
  });

  @override
  Widget build(BuildContext context) {
    return EnhancedCard(
      onTap: onTap,
      enableEntrance: true,
      entranceDelay: entranceDelay,
      elevation: EnhancedCardSystem.elevation1,
      borderRadius: EnhancedCardSystem.radiusMedium,
      padding: const EdgeInsets.all(12),
      backgroundColor: color.withOpacity(0.1),
      border: Border.all(
        color: color.withOpacity(0.3),
        width: 1.5,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              subLabel!,
              style: TextStyle(
                fontSize: 12,
                color: color.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

/// User Card
/// 
/// Specialized card for displaying user information
class UserCard extends StatelessWidget {
  final String name;
  final String? subtitle;
  final Widget? avatar;
  final IconData? statusIcon;
  final Color? statusColor;
  final VoidCallback? onTap;
  final Duration? entranceDelay;

  const UserCard({
    super.key,
    required this.name,
    this.subtitle,
    this.avatar,
    this.statusIcon,
    this.statusColor,
    this.onTap,
    this.entranceDelay,
  });

  @override
  Widget build(BuildContext context) {
    return EnhancedCard(
      onTap: onTap,
      enableEntrance: true,
      entranceDelay: entranceDelay,
      elevation: EnhancedCardSystem.elevation1,
      borderRadius: EnhancedCardSystem.radiusMedium,
      padding: StandardizedSpacing.listItemPadding(context),
      child: Row(
        children: [
          if (avatar != null) ...[
            avatar!,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (statusIcon != null) ...[
            const SizedBox(width: 8),
            Icon(
              statusIcon,
              color: statusColor ?? AppColors.success,
              size: 16,
            ),
          ],
        ],
      ),
    );
  }
}

/// Message Card
/// 
/// Specialized card for displaying messages
class MessageCard extends StatelessWidget {
  final String message;
  final String? timestamp;
  final bool isMe;
  final VoidCallback? onTap;
  final Duration? entranceDelay;

  const MessageCard({
    super.key,
    required this.message,
    this.timestamp,
    required this.isMe,
    this.onTap,
    this.entranceDelay,
  });

  @override
  Widget build(BuildContext context) {
    return EnhancedCard(
      onTap: onTap,
      enableEntrance: true,
      entranceDelay: entranceDelay,
      elevation: EnhancedCardSystem.elevation1,
      borderRadius: EnhancedCardSystem.radiusMedium,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      backgroundColor: isMe ? AppColors.primaryRed : AppColors.lightGray,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: isMe ? Colors.white : AppColors.textPrimary,
            ),
          ),
          if (timestamp != null) ...[
            const SizedBox(height: 4),
            Text(
              timestamp!,
              style: TextStyle(
                fontSize: 12,
                color: isMe ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Settings Card
/// 
/// Specialized card for settings items
class SettingsCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Duration? entranceDelay;

  const SettingsCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.iconColor,
    this.trailing,
    this.onTap,
    this.entranceDelay,
  });

  @override
  Widget build(BuildContext context) {
    return EnhancedCard(
      onTap: onTap,
      enableEntrance: true,
      entranceDelay: entranceDelay,
      elevation: EnhancedCardSystem.elevation1,
      borderRadius: EnhancedCardSystem.radiusMedium,
      padding: StandardizedSpacing.listItemPadding(context),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (iconColor ?? AppColors.primaryRed).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: iconColor ?? AppColors.primaryRed,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ] else if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ],
      ),
    );
  }
}

