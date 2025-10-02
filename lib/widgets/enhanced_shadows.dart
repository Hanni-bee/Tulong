import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class EnhancedShadows {
  // Subtle shadows for cards
  static List<BoxShadow> get cardLight => [
    BoxShadow(
      color: AppColors.primaryRed.withOpacity(0.02),
      blurRadius: 8,
      offset: const Offset(0, 2),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.02),
      blurRadius: 16,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get cardMedium => [
    BoxShadow(
      color: AppColors.primaryRed.withOpacity(0.04),
      blurRadius: 12,
      offset: const Offset(0, 3),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 24,
      offset: const Offset(0, 6),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get cardStrong => [
    BoxShadow(
      color: AppColors.primaryRed.withOpacity(0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 32,
      offset: const Offset(0, 8),
      spreadRadius: 0,
    ),
  ];

  // Button shadows
  static List<BoxShadow> get buttonLight => [
    BoxShadow(
      color: AppColors.primaryRed.withOpacity(0.15),
      blurRadius: 8,
      offset: const Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get buttonMedium => [
    BoxShadow(
      color: AppColors.primaryRed.withOpacity(0.2),
      blurRadius: 12,
      offset: const Offset(0, 3),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get buttonStrong => [
    BoxShadow(
      color: AppColors.primaryRed.withOpacity(0.25),
      blurRadius: 16,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  // Floating element shadows
  static List<BoxShadow> get floatingLight => [
    BoxShadow(
      color: AppColors.primaryRed.withOpacity(0.03),
      blurRadius: 20,
      offset: const Offset(0, 5),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.03),
      blurRadius: 40,
      offset: const Offset(0, 10),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get floatingMedium => [
    BoxShadow(
      color: AppColors.primaryRed.withOpacity(0.05),
      blurRadius: 30,
      offset: const Offset(0, 8),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 60,
      offset: const Offset(0, 16),
      spreadRadius: 0,
    ),
  ];

  // Navigation shadows
  static List<BoxShadow> get navigation => [
    BoxShadow(
      color: AppColors.primaryRed.withOpacity(0.04),
      blurRadius: 16,
      offset: const Offset(0, -2),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 32,
      offset: const Offset(0, -4),
      spreadRadius: 0,
    ),
  ];

  // App bar shadows
  static List<BoxShadow> get appBar => [
    BoxShadow(
      color: AppColors.primaryRed.withOpacity(0.03),
      blurRadius: 12,
      offset: const Offset(0, 2),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.03),
      blurRadius: 24,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  // Interactive element shadows (for hover/press states)
  static List<BoxShadow> get interactivePressed => [
    BoxShadow(
      color: AppColors.primaryRed.withOpacity(0.1),
      blurRadius: 4,
      offset: const Offset(0, 1),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get interactiveHover => [
    BoxShadow(
      color: AppColors.primaryRed.withOpacity(0.08),
      blurRadius: 8,
      offset: const Offset(0, 2),
      spreadRadius: 0,
    ),
  ];

  // Special shadows for emphasis
  static List<BoxShadow> get emphasis => [
    BoxShadow(
      color: AppColors.primaryRed.withOpacity(0.1),
      blurRadius: 20,
      offset: const Offset(0, 6),
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 40,
      offset: const Offset(0, 12),
      spreadRadius: 0,
    ),
  ];

  // Text shadows for better readability
  static List<Shadow> get textLight => [
    Shadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static List<Shadow> get textMedium => [
    Shadow(
      color: Colors.black.withOpacity(0.15),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static List<Shadow> get textStrong => [
    Shadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 6,
      offset: const Offset(0, 3),
    ),
  ];
}

// Helper class for applying shadows consistently
class ShadowedContainer extends StatelessWidget {
  final Widget child;
  final List<BoxShadow> shadows;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final Border? border;

  const ShadowedContainer({
    super.key,
    required this.child,
    required this.shadows,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderRadius,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.white,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        border: border,
        boxShadow: shadows,
      ),
      child: child,
    );
  }
}

// Predefined shadowed containers
class LightCard extends ShadowedContainer {
  const LightCard({
    super.key,
    required super.child,
    super.padding,
    super.margin,
    super.backgroundColor,
    super.borderRadius,
    super.border,
  }) : super(shadows: EnhancedShadows.cardLight);
}

class MediumCard extends ShadowedContainer {
  const MediumCard({
    super.key,
    required super.child,
    super.padding,
    super.margin,
    super.backgroundColor,
    super.borderRadius,
    super.border,
  }) : super(shadows: EnhancedShadows.cardMedium);
}

class StrongCard extends ShadowedContainer {
  const StrongCard({
    super.key,
    required super.child,
    super.padding,
    super.margin,
    super.backgroundColor,
    super.borderRadius,
    super.border,
  }) : super(shadows: EnhancedShadows.cardStrong);
}

class FloatingCard extends ShadowedContainer {
  const FloatingCard({
    super.key,
    required super.child,
    super.padding,
    super.margin,
    super.backgroundColor,
    super.borderRadius,
    super.border,
  }) : super(shadows: EnhancedShadows.floatingMedium);
}
