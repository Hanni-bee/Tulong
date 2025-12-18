import 'package:flutter/material.dart';
import '../constants/unified_typography.dart';
import '../utils/typography_helper.dart';

/// Accessible Text Widget with automatic contrast and responsive sizing
class AccessibleText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? baseStyle;
  final Color? color;
  final Color? backgroundColor;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool isHeading;
  final bool isLargeText;

  const AccessibleText(
    this.text, {
    super.key,
    this.style,
    this.baseStyle,
    this.color,
    this.backgroundColor,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.isHeading = false,
    this.isLargeText = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBaseStyle = baseStyle ??
        (isHeading ? UnifiedTypography.headlineMedium : UnifiedTypography.bodyMedium);

    final accessibleStyle = isHeading
        ? TypographyHelper.responsiveHeading(
            context,
            baseStyle: effectiveBaseStyle,
            fontSize: style?.fontSize,
            color: color ?? style?.color,
            backgroundColor: backgroundColor,
          )
        : TypographyHelper.responsiveBody(
            context,
            baseStyle: effectiveBaseStyle,
            fontSize: style?.fontSize,
            color: color ?? style?.color,
            backgroundColor: backgroundColor,
          );

    final finalStyle = (style ?? accessibleStyle).copyWith(
      color: accessibleStyle.color,
      fontSize: accessibleStyle.fontSize,
      height: accessibleStyle.height,
    );

    return Text(
      text,
      style: finalStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Accessible Heading Widget
class AccessibleHeading extends StatelessWidget {
  final String text;
  final HeadingLevel level;
  final Color? color;
  final Color? backgroundColor;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const AccessibleHeading(
    this.text, {
    super.key,
    this.level = HeadingLevel.h2,
    this.color,
    this.backgroundColor,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    TextStyle baseStyle;
    switch (level) {
      case HeadingLevel.h1:
        baseStyle = UnifiedTypography.displayLarge;
        break;
      case HeadingLevel.h2:
        baseStyle = UnifiedTypography.headlineLarge;
        break;
      case HeadingLevel.h3:
        baseStyle = UnifiedTypography.headlineMedium;
        break;
      case HeadingLevel.h4:
        baseStyle = UnifiedTypography.headlineSmall;
        break;
      case HeadingLevel.h5:
        baseStyle = UnifiedTypography.titleLarge;
        break;
      case HeadingLevel.h6:
        baseStyle = UnifiedTypography.titleMedium;
        break;
    }

    return AccessibleText(
      text,
      baseStyle: baseStyle,
      color: color,
      backgroundColor: backgroundColor,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      isHeading: true,
    );
  }
}

enum HeadingLevel { h1, h2, h3, h4, h5, h6 }

/// Accessible Body Text Widget
class AccessibleBodyText extends StatelessWidget {
  final String text;
  final BodySize size;
  final Color? color;
  final Color? backgroundColor;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const AccessibleBodyText(
    this.text, {
    super.key,
    this.size = BodySize.medium,
    this.color,
    this.backgroundColor,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    TextStyle baseStyle;
    switch (size) {
      case BodySize.large:
        baseStyle = UnifiedTypography.bodyLarge;
        break;
      case BodySize.medium:
        baseStyle = UnifiedTypography.bodyMedium;
        break;
      case BodySize.small:
        baseStyle = UnifiedTypography.bodySmall;
        break;
    }

    return AccessibleText(
      text,
      baseStyle: baseStyle,
      color: color,
      backgroundColor: backgroundColor,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

enum BodySize { large, medium, small }

/// Accessible Chat Message Text Widget
class AccessibleChatText extends StatelessWidget {
  final String text;
  final bool isMe;
  final Color? backgroundColor;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const AccessibleChatText(
    this.text, {
    super.key,
    required this.isMe,
    this.backgroundColor,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final style = TypographyHelper.accessibleChatMessage(
      context,
      isMe: isMe,
      backgroundColor: backgroundColor,
    );

    return Text(
      text,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}




