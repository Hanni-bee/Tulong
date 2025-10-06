import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class EnhancedTextStyles {
  // Display Text Styles - For hero sections and major headings
  static const TextStyle displayXLarge = TextStyle(
    fontSize: 64,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
    letterSpacing: -1.5,
    height: 1.0,
  );

  static const TextStyle displayLarge = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
    letterSpacing: -1.0,
    height: 1.1,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: 0,
    height: 1.3,
  );

  // Headers - Page and section headings
  static const TextStyle headlineXLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.8,
    height: 1.2,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
    height: 1.3,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
    height: 1.4,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.1,
    height: 1.4,
  );

  // Titles - Card and component headings
  static const TextStyle titleXLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
    height: 1.3,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.1,
    height: 1.4,
  );

  static const TextStyle titleSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0,
    height: 1.4,
  );

  // Body Text - Main content text
  static const TextStyle bodyXLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
    height: 1.5,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    letterSpacing: -0.1,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    letterSpacing: 0,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    letterSpacing: 0.1,
    height: 1.4,
  );

  // Labels - Form labels and UI elements
  static const TextStyle labelXLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0,
    height: 1.3,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0,
    height: 1.3,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 0.1,
    height: 1.3,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 0.2,
    height: 1.3,
  );

  // Captions - Small descriptive text
  static const TextStyle captionLarge = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    letterSpacing: 0.1,
    height: 1.4,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    letterSpacing: 0.2,
    height: 1.3,
  );

  // Special Text - Emphasis and status text
  static const TextStyle accentText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryRed,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static const TextStyle errorText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.error,
    letterSpacing: 0.0,
    height: 1.3,
  );

  static const TextStyle successText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.success,
    letterSpacing: 0.0,
    height: 1.3,
  );

  static const TextStyle warningText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.warning,
    letterSpacing: 0.0,
    height: 1.3,
  );

  static const TextStyle infoText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.info,
    letterSpacing: 0.0,
    height: 1.3,
  );

  // Emergency-specific text styles
  static const TextStyle emergencyTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.emergencyText,
    letterSpacing: 0.5,
    height: 1.2,
  );

  static const TextStyle emergencySubtitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.emergencyText,
    letterSpacing: 0.3,
    height: 1.3,
  );

  static const TextStyle emergencyBody = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.emergencyText,
    letterSpacing: 0.2,
    height: 1.4,
  );

  static const TextStyle emergencyCaption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.emergencyText,
    letterSpacing: 0.8,
    height: 1.2,
  );

  static const TextStyle alertText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.criticalText,
    letterSpacing: 0.3,
    height: 1.3,
  );

  static const TextStyle statusText = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.successText,
    letterSpacing: 0.2,
    height: 1.3,
  );

  static const TextStyle networkStatus = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.infoBlue,
    letterSpacing: 0.3,
    height: 1.2,
  );

  // Button Text - Interactive elements
  static const TextStyle buttonXLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.white,
    letterSpacing: -0.2,
    height: 1.2,
  );

  static const TextStyle buttonLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
    letterSpacing: -0.2,
    height: 1.2,
  );

  static const TextStyle buttonMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
    letterSpacing: 0.0,
    height: 1.2,
  );

  static const TextStyle buttonSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
    letterSpacing: 0.1,
    height: 1.2,
  );

  // Navigation - Bottom nav and tabs
  static const TextStyle navLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 0.2,
    height: 1.2,
  );

  static const TextStyle navLabelActive = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryRed,
    letterSpacing: 0.2,
    height: 1.2,
  );

  static const TextStyle tabLabel = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 0.1,
    height: 1.2,
  );

  static const TextStyle tabLabelActive = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryRed,
    letterSpacing: 0.1,
    height: 1.2,
  );

  // Code and monospace text
  static const TextStyle codeText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    fontFamily: 'Courier New',
    letterSpacing: 0.0,
    height: 1.4,
  );

  // Legacy aliases for backward compatibility
  @Deprecated('Use headlineLarge instead')
  static const TextStyle pageTitle = headlineLarge;

  @Deprecated('Use headlineMedium instead')
  static const TextStyle sectionTitle = headlineMedium;

  @Deprecated('Use titleLarge instead')
  static const TextStyle cardTitle = titleLarge;
}

// Enhanced Text Widget with automatic style application and advanced features
class EnhancedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final Color? color;
  final TextDirection? textDirection;
  final TextScaler? textScaler;
  final StrutStyle? strutStyle;
  final Locale? locale;
  final bool enableShadow;
  final Color? shadowColor;
  final double? shadowBlur;
  final Offset? shadowOffset;

  const EnhancedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.color,
    this.textDirection,
    this.textScaler,
    this.strutStyle,
    this.locale,
    this.enableShadow = false,
    this.shadowColor,
    this.shadowBlur,
    this.shadowOffset,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = style?.copyWith(color: color ?? style?.color) ?? const TextStyle();

    TextStyle finalStyle = effectiveStyle;
    if (enableShadow && shadowColor != null) {
      finalStyle = effectiveStyle.copyWith(
        shadows: [
          Shadow(
            color: shadowColor!,
            blurRadius: shadowBlur ?? 4.0,
            offset: shadowOffset ?? const Offset(2, 2),
          ),
        ],
      );
    }

    return Text(
      text,
      style: finalStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      textDirection: textDirection,
      textScaler: textScaler,
      strutStyle: strutStyle,
      locale: locale,
    );
  }
}

// Predefined text widgets for common use cases
class PageTitle extends EnhancedText {
  const PageTitle(super.text, {super.key, super.textAlign, super.maxLines, super.overflow, super.color})
      : super(style: EnhancedTextStyles.headlineLarge);
}

class SectionTitle extends EnhancedText {
  const SectionTitle(super.text, {super.key, super.textAlign, super.maxLines, super.overflow, super.color})
      : super(style: EnhancedTextStyles.headlineMedium);
}

class CardTitle extends EnhancedText {
  const CardTitle(super.text, {super.key, super.textAlign, super.maxLines, super.overflow, super.color})
      : super(style: EnhancedTextStyles.titleLarge);
}

class BodyText extends EnhancedText {
  const BodyText(super.text, {super.key, super.textAlign, super.maxLines, super.overflow, super.color})
      : super(style: EnhancedTextStyles.bodyMedium);
}

class LabelText extends EnhancedText {
  const LabelText(super.text, {super.key, super.textAlign, super.maxLines, super.overflow, super.color})
      : super(style: EnhancedTextStyles.labelLarge);
}

class CaptionText extends EnhancedText {
  const CaptionText(super.text, {super.key, super.textAlign, super.maxLines, super.overflow, super.color})
      : super(style: EnhancedTextStyles.caption);
}

class AccentText extends EnhancedText {
  const AccentText(super.text, {super.key, super.textAlign, super.maxLines, super.overflow})
      : super(style: EnhancedTextStyles.accentText);
}

// Advanced text widgets with animations and special effects

// Animated text that fades in with slide effect
class AnimatedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration animationDuration;
  final Curve animationCurve;
  final bool autoStart;
  final VoidCallback? onAnimationComplete;

  const AnimatedText({
    super.key,
    required this.text,
    this.style,
    this.animationDuration = const Duration(milliseconds: 600),
    this.animationCurve = Curves.easeOut,
    this.autoStart = true,
    this.onAnimationComplete,
  });

  @override
  State<AnimatedText> createState() => _AnimatedTextState();
}

class _AnimatedTextState extends State<AnimatedText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.animationCurve,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.animationCurve,
    ));

    if (widget.autoStart) {
      _controller.forward().then((_) {
        widget.onAnimationComplete?.call();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void startAnimation() {
    _controller.forward().then((_) {
      widget.onAnimationComplete?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Text(
              widget.text,
              style: widget.style,
            ),
          ),
        );
      },
    );
  }
}

// Enhanced text widget for special effects (neumorphic styling)
class StyledText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final bool neumorphic;

  const StyledText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.backgroundColor,
    this.padding,
    this.neumorphic = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget textWidget = Text(
      text,
      style: neumorphic
        ? style?.copyWith(
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 2,
                offset: const Offset(1, 1),
              ),
              Shadow(
                color: Colors.white.withOpacity(0.8),
                blurRadius: 2,
                offset: const Offset(-1, -1),
              ),
            ],
          ) ?? const TextStyle()
        : style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );

    if (backgroundColor != null || padding != null) {
      return Container(
        padding: padding,
        color: backgroundColor,
        child: textWidget,
      );
    }

    return textWidget;
  }
}

// Neumorphic text widget
class NeumorphicText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const NeumorphicText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return StyledText(
      text,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      neumorphic: true,
    );
  }
}

// Responsive text that scales based on screen size
class ResponsiveText extends StatelessWidget {
  final String text;
  final TextStyle baseStyle;
  final double minFontSize;
  final double maxFontSize;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const ResponsiveText(
    this.text, {
    super.key,
    required this.baseStyle,
    this.minFontSize = 12,
    this.maxFontSize = 32,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final scaleFactor = (screenWidth / 375).clamp(0.8, 1.5); // Base on iPhone 6/7/8 width

        final fontSize = (baseStyle.fontSize ?? 16) * scaleFactor;
        final clampedFontSize = fontSize.clamp(minFontSize, maxFontSize);

        return Text(
          text,
          style: baseStyle.copyWith(fontSize: clampedFontSize),
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
        );
      },
    );
  }
}

// Typewriter effect text
class TypewriterText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration typingSpeed;
  final Duration cursorBlinkSpeed;
  final bool showCursor;
  final String cursor;
  final VoidCallback? onComplete;

  const TypewriterText({
    super.key,
    required this.text,
    this.style,
    this.typingSpeed = const Duration(milliseconds: 50),
    this.cursorBlinkSpeed = const Duration(milliseconds: 500),
    this.showCursor = true,
    this.cursor = '|',
    this.onComplete,
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> with TickerProviderStateMixin {
  late AnimationController _typingController;
  late AnimationController _cursorController;
  late Animation<int> _textAnimation;
  late Animation<double> _cursorAnimation;

  @override
  void initState() {
    super.initState();

    _typingController = AnimationController(
      duration: Duration(milliseconds: widget.text.length * widget.typingSpeed.inMilliseconds),
      vsync: this,
    );

    _cursorController = AnimationController(
      duration: widget.cursorBlinkSpeed,
      vsync: this,
    )..repeat(reverse: true);

    _textAnimation = IntTween(begin: 0, end: widget.text.length).animate(
      CurvedAnimation(parent: _typingController, curve: Curves.linear),
    );

    _cursorAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cursorController, curve: Curves.easeInOut),
    );

    _typingController.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _typingController.dispose();
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_typingController, _cursorController]),
      builder: (context, child) {
        final currentLength = _textAnimation.value;
        final isCursorVisible = _cursorAnimation.value > 0.5;

        return RichText(
          text: TextSpan(
            style: widget.style,
            children: [
              TextSpan(text: widget.text.substring(0, currentLength)),
              if (widget.showCursor && isCursorVisible)
                TextSpan(
                  text: widget.cursor,
                  style: widget.style?.copyWith(
                    color: widget.style?.color?.withOpacity(0.7),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// Marquee text for long text that doesn't fit
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration scrollDuration;
  final double gap;
  final bool pauseOnHover;

  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.scrollDuration = const Duration(seconds: 10),
    this.gap = 50,
    this.pauseOnHover = true,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Text(widget.text, style: widget.style),
              SizedBox(width: widget.gap),
              Text(widget.text, style: widget.style),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

// Auto-sizing text that fits within bounds
class AutoSizeText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final double minFontSize;
  final double maxFontSize;
  final double stepGranularity;

  const AutoSizeText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.minFontSize = 8,
    this.maxFontSize = 32,
    this.stepGranularity = 1,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Binary search for optimal font size
        double low = minFontSize;
        double high = maxFontSize;

        while (low <= high) {
          final mid = (low + high) / 2;
          final testStyle = style?.copyWith(fontSize: mid) ?? TextStyle(fontSize: mid);

          final textPainter = TextPainter(
            text: TextSpan(text: text, style: testStyle),
            maxLines: maxLines,
            textDirection: TextDirection.ltr,
          );

          textPainter.layout(maxWidth: constraints.maxWidth);

          if (textPainter.size.height <= constraints.maxHeight &&
              textPainter.size.width <= constraints.maxWidth) {
            low = mid + stepGranularity;
          } else {
            high = mid - stepGranularity;
          }
        }

        final optimalFontSize = high.clamp(minFontSize, maxFontSize);

        return Text(
          text,
          style: style?.copyWith(fontSize: optimalFontSize) ?? TextStyle(fontSize: optimalFontSize),
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}

// Emergency Status Indicator Widget
class EmergencyStatusIndicator extends StatelessWidget {
  final EmergencyStatus status;
  final String message;
  final bool showIcon;
  final bool isCompact;

  const EmergencyStatusIndicator({
    super.key,
    required this.status,
    required this.message,
    this.showIcon = true,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusConfig = _getStatusConfig();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 8 : 12,
        vertical: isCompact ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: statusConfig.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: statusConfig.borderColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              statusConfig.icon,
              size: isCompact ? 14 : 16,
              color: statusConfig.textColor,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            message,
            style: isCompact
              ? EnhancedTextStyles.emergencyCaption.copyWith(color: statusConfig.textColor)
              : EnhancedTextStyles.statusText.copyWith(color: statusConfig.textColor),
          ),
        ],
      ),
    );
  }

  _StatusConfig _getStatusConfig() {
    switch (status) {
      case EmergencyStatus.connected:
        return _StatusConfig(
          icon: Icons.wifi,
          backgroundColor: AppColors.successBackground,
          borderColor: AppColors.successGreen,
          textColor: AppColors.successText,
        );
      case EmergencyStatus.disconnected:
        return _StatusConfig(
          icon: Icons.wifi_off,
          backgroundColor: AppColors.warningBackground,
          borderColor: AppColors.offlineGray,
          textColor: AppColors.warningText,
        );
      case EmergencyStatus.emergency:
        return _StatusConfig(
          icon: Icons.emergency,
          backgroundColor: AppColors.criticalBackground,
          borderColor: AppColors.emergencyRed,
          textColor: AppColors.criticalText,
        );
      case EmergencyStatus.warning:
        return _StatusConfig(
          icon: Icons.warning,
          backgroundColor: AppColors.warningBackground,
          borderColor: AppColors.warningOrange,
          textColor: AppColors.warningText,
        );
      case EmergencyStatus.offline:
        return _StatusConfig(
          icon: Icons.cloud_off,
          backgroundColor: AppColors.emergencyBackground,
          borderColor: AppColors.offlineGray,
          textColor: AppColors.offlineGray,
        );
    }
  }
}

class _StatusConfig {
  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  _StatusConfig({
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });
}

enum EmergencyStatus {
  connected,     // Network connected
  disconnected,  // Network disconnected
  emergency,     // Emergency mode active
  warning,       // Warning state
  offline,       // Completely offline
}

// Emergency Alert Banner
class EmergencyAlertBanner extends StatelessWidget {
  final String title;
  final String message;
  final EmergencyAlertType type;
  final VoidCallback? onDismiss;
  final bool showDismissButton;

  const EmergencyAlertBanner({
    super.key,
    required this.title,
    required this.message,
    this.type = EmergencyAlertType.info,
    this.onDismiss,
    this.showDismissButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final alertConfig = _getAlertConfig();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: alertConfig.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alertConfig.borderColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: alertConfig.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                alertConfig.icon,
                color: alertConfig.textColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: EnhancedTextStyles.alertText.copyWith(
                    color: alertConfig.textColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (showDismissButton && onDismiss != null)
                IconButton(
                  icon: Icon(Icons.close, color: alertConfig.textColor),
                  onPressed: onDismiss,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: EnhancedTextStyles.bodyMedium.copyWith(
              color: alertConfig.textColor.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  _AlertConfig _getAlertConfig() {
    switch (type) {
      case EmergencyAlertType.emergency:
        return _AlertConfig(
          icon: Icons.emergency,
          backgroundColor: AppColors.criticalBackground,
          borderColor: AppColors.emergencyRed,
          textColor: AppColors.criticalText,
          shadowColor: AppColors.emergencyRed.withOpacity(0.3),
        );
      case EmergencyAlertType.warning:
        return _AlertConfig(
          icon: Icons.warning,
          backgroundColor: AppColors.warningBackground,
          borderColor: AppColors.warningOrange,
          textColor: AppColors.warningText,
          shadowColor: AppColors.warningOrange.withOpacity(0.3),
        );
      case EmergencyAlertType.success:
        return _AlertConfig(
          icon: Icons.check_circle,
          backgroundColor: AppColors.successBackground,
          borderColor: AppColors.successGreen,
          textColor: AppColors.successText,
          shadowColor: AppColors.successGreen.withOpacity(0.3),
        );
      case EmergencyAlertType.info:
        return _AlertConfig(
          icon: Icons.info,
          backgroundColor: AppColors.emergencyBackground,
          borderColor: AppColors.infoBlue,
          textColor: AppColors.emergencyText,
          shadowColor: AppColors.infoBlue.withOpacity(0.3),
        );
    }
  }
}

class _AlertConfig {
  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color shadowColor;

  _AlertConfig({
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.shadowColor,
  });
}

enum EmergencyAlertType {
  emergency,  // Critical emergency alerts
  warning,    // Warning messages
  success,    // Success notifications
  info,       // General information
}

// Network Quality Indicator
class NetworkQualityIndicator extends StatelessWidget {
  final NetworkQuality quality;
  final bool showLabel;
  final bool isCompact;

  const NetworkQualityIndicator({
    super.key,
    required this.quality,
    this.showLabel = true,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final qualityConfig = _getQualityConfig();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 8,
        vertical: isCompact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: qualityConfig.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: qualityConfig.borderColor,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            qualityConfig.icon,
            size: isCompact ? 12 : 14,
            color: qualityConfig.textColor,
          ),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              qualityConfig.label,
              style: isCompact
                ? EnhancedTextStyles.emergencyCaption.copyWith(color: qualityConfig.textColor)
                : EnhancedTextStyles.networkStatus.copyWith(color: qualityConfig.textColor),
            ),
          ],
        ],
      ),
    );
  }

  _QualityConfig _getQualityConfig() {
    switch (quality) {
      case NetworkQuality.excellent:
        return _QualityConfig(
          icon: Icons.wifi,
          label: 'Excellent',
          backgroundColor: AppColors.successBackground,
          borderColor: AppColors.successGreen,
          textColor: AppColors.successText,
        );
      case NetworkQuality.good:
        return _QualityConfig(
          icon: Icons.wifi,
          label: 'Good',
          backgroundColor: AppColors.emergencyBackground,
          borderColor: AppColors.infoBlue,
          textColor: AppColors.infoBlue,
        );
      case NetworkQuality.fair:
        return _QualityConfig(
          icon: Icons.wifi,
          label: 'Fair',
          backgroundColor: AppColors.warningBackground,
          borderColor: AppColors.warningOrange,
          textColor: AppColors.warningText,
        );
      case NetworkQuality.poor:
        return _QualityConfig(
          icon: Icons.wifi_off,
          label: 'Poor',
          backgroundColor: AppColors.criticalBackground,
          borderColor: AppColors.emergencyRed,
          textColor: AppColors.criticalText,
        );
      case NetworkQuality.offline:
        return _QualityConfig(
          icon: Icons.cloud_off,
          label: 'Offline',
          backgroundColor: AppColors.emergencyBackground,
          borderColor: AppColors.offlineGray,
          textColor: AppColors.offlineGray,
        );
    }
  }
}

class _QualityConfig {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  _QualityConfig({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });
}

enum NetworkQuality {
  excellent,  // Strong signal, fast connection
  good,       // Good signal, reliable connection
  fair,       // Moderate signal, some lag
  poor,       // Weak signal, unreliable
  offline,    // No connection
}
