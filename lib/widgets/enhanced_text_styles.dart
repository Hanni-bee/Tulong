import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class EnhancedTextStyles {
  // Headers
  static const TextStyle pageTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.8,
    height: 1.2,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
    height: 1.3,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
    height: 1.3,
  );

  // Body Text
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
    height: 1.4,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    letterSpacing: 0.0,
    height: 1.4,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    letterSpacing: 0.1,
    height: 1.4,
  );

  // Labels & Captions
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.0,
    height: 1.3,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    letterSpacing: 0.1,
    height: 1.3,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    letterSpacing: 0.2,
    height: 1.3,
  );

  // Special Text
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

  // Button Text
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

  // Navigation
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
}

// Enhanced Text Widget with automatic style application
class EnhancedText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final Color? color;

  const EnhancedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style?.copyWith(color: color ?? style?.color),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

// Predefined text widgets for common use cases
class PageTitle extends EnhancedText {
  const PageTitle(String text, {super.key, super.textAlign, super.maxLines, super.overflow, super.color})
      : super(text, style: EnhancedTextStyles.pageTitle);
}

class SectionTitle extends EnhancedText {
  const SectionTitle(String text, {super.key, super.textAlign, super.maxLines, super.overflow, super.color})
      : super(text, style: EnhancedTextStyles.sectionTitle);
}

class CardTitle extends EnhancedText {
  const CardTitle(String text, {super.key, super.textAlign, super.maxLines, super.overflow, super.color})
      : super(text, style: EnhancedTextStyles.cardTitle);
}

class BodyText extends EnhancedText {
  const BodyText(String text, {super.key, super.textAlign, super.maxLines, super.overflow, super.color})
      : super(text, style: EnhancedTextStyles.bodyMedium);
}

class LabelText extends EnhancedText {
  const LabelText(String text, {super.key, super.textAlign, super.maxLines, super.overflow, super.color})
      : super(text, style: EnhancedTextStyles.labelLarge);
}

class CaptionText extends EnhancedText {
  const CaptionText(String text, {super.key, super.textAlign, super.maxLines, super.overflow, super.color})
      : super(text, style: EnhancedTextStyles.caption);
}

class AccentText extends EnhancedText {
  const AccentText(String text, {super.key, super.textAlign, super.maxLines, super.overflow})
      : super(text, style: EnhancedTextStyles.accentText);
}
