import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/unified_typography.dart';
import '../utils/prototype_animations.dart';

/// Unified top bar component for consistent design across Local Chat, Calls, and Profile screens
/// Matches the app's neumorphic design system and typography
/// Enhanced with prototype floating bar animation
class UnifiedTopBar extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final List<Widget>? actions;
  final VoidCallback? onIconTap;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final bool compact; // NEW: compact variant
  final List<Widget>? statusBadges; // NEW: optional status badges
  final bool showPresenceDot; // NEW: optional dot above icon
  final Color? presenceColor; // NEW: dot color, defaults to iconColor
  final bool showUnderline; // NEW: animated underline control
  final Color? underlineColor; // NEW: custom underline color
  final VoidCallback? onSubtitleTap; // NEW: tap on subtitle/status badge

  const UnifiedTopBar({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.iconColor = AppColors.primary,
    this.backgroundColor = AppColors.white,
    this.actions,
    this.onIconTap,
    this.showBackButton = false,
    this.onBackPressed,
    this.compact = false,
    this.statusBadges,
    this.showPresenceDot = false,
    this.presenceColor,
    this.showUnderline = true,
    this.underlineColor,
    this.onSubtitleTap,
  });

  @override
  State<UnifiedTopBar> createState() => _UnifiedTopBarState();
}

class _UnifiedTopBarState extends State<UnifiedTopBar>
    with TickerProviderStateMixin {
  late AnimationController _floatingBarController;
  late AnimationController _iconPulseController;
  late AnimationController _subtitleController;
  late Animation<Offset> _floatingBarSlide;
  late Animation<double> _floatingBarFade;
  late Animation<double> _iconScale;
  late Animation<double> _iconGlow;
  late Animation<double> _subtitleFade;
  bool _isIconPressed = false;

  @override
  void initState() {
    super.initState();
    // Floating bar animation: slide down from top + fade in
    _floatingBarController = AnimationController(
      duration: PrototypeAnimations.floatingBarDuration, // 400ms
      vsync: this,
    );

    // Icon pulse animation
    _iconPulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    // Subtitle transition animation
    _subtitleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _floatingBarSlide = Tween<Offset>(
      begin: const Offset(0, -0.05), // -20px from top
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _floatingBarController,
      curve: PrototypeAnimations.pageEntryCurve, // easeOut
    ));

    _floatingBarFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _floatingBarController,
      curve: PrototypeAnimations.pageEntryCurve,
    ));

    // Icon scale animation (subtle pulse)
    _iconScale = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _iconPulseController,
      curve: Curves.easeInOut,
    ));

    // Icon glow animation
    _iconGlow = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _iconPulseController,
      curve: Curves.easeInOut,
    ));

    // Subtitle fade animation
    _subtitleFade = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _subtitleController,
      curve: Curves.easeOut,
    ));

    // Start animations
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _floatingBarController.forward();
      _subtitleController.forward();
    });
  }

  @override
  void didUpdateWidget(UnifiedTopBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Animate subtitle changes
    if (oldWidget.subtitle != widget.subtitle) {
      _subtitleController.reset();
      _subtitleController.forward();
    }
  }

  @override
  void dispose() {
    _floatingBarController.dispose();
    _iconPulseController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double containerHeight = widget.compact ? 64 : 88;
    final EdgeInsetsGeometry containerPadding = widget.compact
        ? const EdgeInsets.symmetric(horizontal: 18, vertical: 12)
        : const EdgeInsets.symmetric(horizontal: 20, vertical: 16);
    final double iconBoxSize = widget.compact ? 44 : 56;
    final double iconSize = widget.compact ? 22 : 28;
    final double titleFontSize = widget.compact ? 17 : 21;

    return FadeTransition(
      opacity: _floatingBarFade,
      child: SlideTransition(
        position: _floatingBarSlide,
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            constraints: BoxConstraints(
              minHeight: containerHeight,
              maxHeight: containerHeight + 2,
            ),
            padding: containerPadding,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.grey.withOpacity(0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.showBackButton) ...[
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.onBackPressed ?? () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: iconBoxSize,
                            height: iconBoxSize,
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.grey.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new,
                              color: AppColors.textPrimary,
                              size: widget.compact ? 20 : 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                    ],

                // Main icon with optional presence dot and animations
                Material(
                  color: Colors.transparent,
                  child: GestureDetector(
                    onTapDown: (_) {
                      setState(() => _isIconPressed = true);
                      HapticFeedback.lightImpact();
                    },
                    onTapUp: (_) {
                      setState(() => _isIconPressed = false);
                      widget.onIconTap?.call();
                    },
                    onTapCancel: () {
                      setState(() => _isIconPressed = false);
                    },
                    child: AnimatedBuilder(
                      animation: _iconPulseController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _isIconPressed ? 0.95 : _iconScale.value,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Glow effect
                              Container(
                                width: iconBoxSize,
                                height: iconBoxSize,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: widget.iconColor.withOpacity(0.15 * _iconGlow.value),
                                      blurRadius: 12 * _iconGlow.value,
                                      spreadRadius: 2 * _iconGlow.value,
                                    ),
                                  ],
                                ),
                              ),
                              // Main icon container
                              Container(
                                width: iconBoxSize,
                                height: iconBoxSize,
                                decoration: BoxDecoration(
                                  color: widget.iconColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: widget.iconColor.withOpacity(0.2),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: widget.iconColor.withOpacity(0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                      spreadRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  widget.icon,
                                  color: widget.iconColor,
                                  size: iconSize,
                                ),
                              ),
                              // Presence dot (top right)
                              if (widget.showPresenceDot)
                                Positioned(
                                  top: -3,
                                  right: -3,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: (widget.presenceColor ?? widget.iconColor),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: widget.backgroundColor,
                                        width: 2.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (widget.presenceColor ?? widget.iconColor).withOpacity(0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Title, subtitle, and badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: UnifiedTypography.appBarTitle.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          height: 1.2,
                        ),
                      ),
                      if ((widget.subtitle != null && widget.subtitle!.isNotEmpty) || (widget.statusBadges != null && widget.statusBadges!.isNotEmpty)) ...[
                        const SizedBox(height: 3),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
                              Flexible(
                                child: FadeTransition(
                                  opacity: _subtitleFade,
                                  child: GestureDetector(
                                    onTap: widget.onSubtitleTap,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                      constraints: const BoxConstraints(maxHeight: 24),
                                      decoration: BoxDecoration(
                                        color: widget.subtitle!.toLowerCase().contains('connected')
                                            ? AppColors.success.withOpacity(0.12)
                                            : AppColors.warning.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: widget.subtitle!.toLowerCase().contains('connected')
                                              ? AppColors.success.withOpacity(0.25)
                                              : AppColors.warning.withOpacity(0.25),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Text(
                                        widget.subtitle!,
                                        style: UnifiedTypography.appBarSubtitle.copyWith(
                                          color: widget.subtitle!.toLowerCase().contains('connected')
                                              ? AppColors.success
                                              : AppColors.warning,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          height: 1.0,
                                          letterSpacing: 0.2,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (widget.subtitle != null && widget.subtitle!.isNotEmpty && widget.statusBadges != null && widget.statusBadges!.isNotEmpty)
                              const SizedBox(width: 6),
                            if (widget.statusBadges != null && widget.statusBadges!.isNotEmpty)
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ...widget.statusBadges!.expand((w) => [w, const SizedBox(width: 6)]).toList()..removeLast(),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                if (widget.actions != null) ...[
                  const SizedBox(width: 12),
                  ...widget.actions!,
                ],
              ],
            ),
          ),
          if (widget.showUnderline)
            AnimatedBuilder(
              animation: _floatingBarController,
              builder: (context, child) {
                return Container(
                  margin: const EdgeInsets.only(top: 6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeInOutCubic,
                    height: 3.5,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          (widget.underlineColor ?? widget.iconColor).withOpacity(0.0),
                          (widget.underlineColor ?? widget.iconColor).withOpacity(0.85 * _floatingBarFade.value),
                          (widget.underlineColor ?? widget.iconColor).withOpacity(0.0),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (widget.underlineColor ?? widget.iconColor).withOpacity(0.2 * _floatingBarFade.value),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Predefined top bar configurations for different screens
/// Each configuration is tailored to match the app's design system
class TopBarConfigs {
  static Widget localChatTopBar({
    required String status,
    VoidCallback? onBluetoothTap, // Made optional - removed from chat screen
    VoidCallback? onConnectedTap,
    List<Widget>? additionalActions,
    bool compact = false,
    List<Widget>? badges,
  }) {
    return UnifiedTopBar(
      title: 'Local Chat',
      subtitle: status,
      icon: Icons.bluetooth,
      iconColor: status.toLowerCase().contains('connected')
          ? AppColors.success
          : AppColors.warning,
      onIconTap: onBluetoothTap, // Can be null now
      onSubtitleTap: status.toLowerCase().contains('connected') ? onConnectedTap : null,
      actions: additionalActions,
      compact: compact,
      statusBadges: badges,
    );
  }

  static Widget callsTopBar({
    String? status,
    required VoidCallback onRefresh,
    List<Widget>? additionalActions,
    bool compact = false,
    List<Widget>? badges,
  }) {
    return UnifiedTopBar(
      title: 'Calls',
      subtitle: null, // Removed subtitle to match Profile height
      icon: Icons.radio,
      iconColor: AppColors.warning,
      actions: [
        _buildActionButton(
          icon: Icons.refresh,
          onPressed: onRefresh,
          color: AppColors.textSecondary,
        ),
        if (additionalActions != null) ...additionalActions,
      ],
      compact: compact,
      statusBadges: badges,
    );
  }

  static Widget messagesTopBar({
    required VoidCallback onCallTap,
    required VoidCallback onMoreTap,
    List<Widget>? additionalActions,
    bool compact = false,
    List<Widget>? badges,
  }) {
    return UnifiedTopBar(
      title: 'Messages',
      subtitle: null, // No subtitle to match Profile height
      icon: Icons.chat_bubble_outline,
      iconColor: AppColors.primary,
      actions: [
        _buildActionButton(
          icon: Icons.call,
          onPressed: onCallTap,
          color: AppColors.primary,
        ),
        const SizedBox(width: 12),
        _buildActionButton(
          icon: Icons.more_vert,
          onPressed: onMoreTap,
          color: AppColors.primary,
        ),
        if (additionalActions != null) ...additionalActions,
      ],
      compact: compact,
      statusBadges: badges,
    );
  }

  static Widget profileTopBar({
    VoidCallback? onEdit,
    List<Widget>? additionalActions,
    bool compact = false,
    List<Widget>? badges,
  }) {
    return UnifiedTopBar(
      title: 'Profile',
      icon: Icons.person,
      iconColor: AppColors.info,
      actions: additionalActions,
      compact: compact,
      statusBadges: badges,
    );
  }

  /// Material UI action button helper with enhanced animations
  static Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return _AnimatedActionButton(
      icon: icon,
      onPressed: onPressed,
      color: color,
    );
  }
}

/// Animated action button with press feedback
class _AnimatedActionButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  const _AnimatedActionButton({
    required this.icon,
    required this.onPressed,
    required this.color,
  });

  @override
  State<_AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<_AnimatedActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _pressController.forward();
        HapticFeedback.selectionClick();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _pressController.reverse();
        widget.onPressed();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _pressController.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: widget.color.withOpacity(_isPressed ? 0.18 : 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.color.withOpacity(_isPressed ? 0.3 : 0.2),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(_isPressed ? 0.1 : 0.06),
                    blurRadius: _isPressed ? 8 : 6,
                    offset: const Offset(0, 2),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Icon(
                widget.icon,
                color: widget.color,
                size: 22,
              ),
            ),
          );
        },
      ),
    );
  }
}
