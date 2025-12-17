import 'package:flutter/material.dart';
import '../constants/app_spacing.dart';
import 'responsive_spacing.dart';

/// Standardized Spacing System
/// 
/// Provides consistent spacing across the entire app:
/// - Standardized padding/margin system
/// - Consistent card spacing
/// - Better use of whitespace
/// - Responsive spacing for different screen sizes
class StandardizedSpacing {
  // ============================================================================
  // SCREEN SPACING
  // ============================================================================

  /// Standard screen padding
  static EdgeInsets screenPadding(BuildContext context) {
    return ResponsiveSpacing.getResponsivePadding(
      context,
      all: AppSpacing.md,
    );
  }

  /// Screen horizontal padding
  static EdgeInsets screenHorizontalPadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: ResponsiveSpacing.getResponsiveSpacing(
        context,
        xs: AppSpacing.sm,
        sm: AppSpacing.md,
        md: AppSpacing.lg,
      ),
    );
  }

  /// Screen vertical padding
  static EdgeInsets screenVerticalPadding(BuildContext context) {
    return EdgeInsets.symmetric(
      vertical: ResponsiveSpacing.getResponsiveSpacing(
        context,
        xs: AppSpacing.sm,
        sm: AppSpacing.md,
        md: AppSpacing.lg,
      ),
    );
  }

  // ============================================================================
  // CARD SPACING
  // ============================================================================

  /// Standard card padding
  static EdgeInsets cardPadding(BuildContext context) {
    return EdgeInsets.all(
      ResponsiveSpacing.getResponsiveSpacing(
        context,
        xs: AppSpacing.sm,
        sm: AppSpacing.md,
        md: AppSpacing.lg,
      ),
    );
  }

  /// Card horizontal padding
  static EdgeInsets cardHorizontalPadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: ResponsiveSpacing.getResponsiveSpacing(
        context,
        xs: AppSpacing.sm,
        sm: AppSpacing.md,
        md: AppSpacing.lg,
      ),
    );
  }

  /// Card vertical padding
  static EdgeInsets cardVerticalPadding(BuildContext context) {
    return EdgeInsets.symmetric(
      vertical: ResponsiveSpacing.getResponsiveSpacing(
        context,
        xs: AppSpacing.sm,
        sm: AppSpacing.md,
        md: AppSpacing.lg,
      ),
    );
  }

  /// Card margin (spacing between cards)
  static EdgeInsets cardMargin(BuildContext context) {
    return EdgeInsets.all(
      ResponsiveSpacing.getResponsiveSpacing(
        context,
        xs: AppSpacing.xs,
        sm: AppSpacing.sm,
        md: AppSpacing.md,
      ),
    );
  }

  /// Card bottom margin (for stacked cards)
  static EdgeInsets cardBottomMargin(BuildContext context) {
    return EdgeInsets.only(
      bottom: ResponsiveSpacing.getResponsiveSpacing(
        context,
        xs: AppSpacing.sm,
        sm: AppSpacing.md,
        md: AppSpacing.lg,
      ),
    );
  }

  // ============================================================================
  // LIST ITEM SPACING
  // ============================================================================

  /// Standard list item padding
  static EdgeInsets listItemPadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: ResponsiveSpacing.getResponsiveSpacing(
        context,
        xs: AppSpacing.sm,
        sm: AppSpacing.md,
        md: AppSpacing.lg,
      ),
      vertical: ResponsiveSpacing.getResponsiveSpacing(
        context,
        xs: AppSpacing.xs,
        sm: AppSpacing.sm,
        md: AppSpacing.md,
      ),
    );
  }

  /// List item spacing (between items)
  static double listItemSpacing(BuildContext context) {
    return ResponsiveSpacing.getResponsiveSpacing(
      context,
      xs: AppSpacing.xs,
      sm: AppSpacing.sm,
      md: AppSpacing.md,
    );
  }

  /// List section spacing (between sections)
  static double listSectionSpacing(BuildContext context) {
    return ResponsiveSpacing.getResponsiveSpacing(
      context,
      xs: AppSpacing.md,
      sm: AppSpacing.lg,
      md: AppSpacing.xl,
    );
  }

  // ============================================================================
  // FORM FIELD SPACING
  // ============================================================================

  /// Form field padding
  static EdgeInsets formFieldPadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: ResponsiveSpacing.getResponsiveSpacing(
        context,
        xs: AppSpacing.sm,
        sm: AppSpacing.md,
        md: AppSpacing.lg,
      ),
      vertical: ResponsiveSpacing.getResponsiveSpacing(
        context,
        xs: AppSpacing.xs,
        sm: AppSpacing.sm,
        md: AppSpacing.md,
      ),
    );
  }

  /// Form field spacing (between fields)
  static double formFieldSpacing(BuildContext context) {
    return ResponsiveSpacing.getResponsiveSpacing(
      context,
      xs: AppSpacing.sm,
      sm: AppSpacing.md,
      md: AppSpacing.lg,
    );
  }

  /// Form section spacing (between form sections)
  static double formSectionSpacing(BuildContext context) {
    return ResponsiveSpacing.getResponsiveSpacing(
      context,
      xs: AppSpacing.lg,
      sm: AppSpacing.xl,
      md: AppSpacing.xxl,
    );
  }

  // ============================================================================
  // BUTTON SPACING
  // ============================================================================

  /// Standard button padding
  static EdgeInsets buttonPadding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: ResponsiveSpacing.getResponsiveSpacing(
        context,
        xs: AppSpacing.md,
        sm: AppSpacing.lg,
        md: AppSpacing.xl,
      ),
      vertical: ResponsiveSpacing.getResponsiveSpacing(
        context,
        xs: AppSpacing.sm,
        sm: AppSpacing.md,
        md: AppSpacing.lg,
      ),
    );
  }

  /// Button spacing (between buttons)
  static double buttonSpacing(BuildContext context) {
    return ResponsiveSpacing.getResponsiveSpacing(
      context,
      xs: AppSpacing.sm,
      sm: AppSpacing.md,
      md: AppSpacing.lg,
    );
  }

  // ============================================================================
  // WHITESPACE HELPERS
  // ============================================================================

  /// Small gap (for tight spacing)
  static SizedBox smallGap(BuildContext context) {
    return SizedBox(
      height: ResponsiveSpacing.getResponsiveSpacing(
        context,
        xs: AppSpacing.xs,
        sm: AppSpacing.sm,
        md: AppSpacing.sm,
      ),
    );
  }

  /// Medium gap (standard spacing)
  static SizedBox mediumGap(BuildContext context) {
    return SizedBox(
      height: ResponsiveSpacing.getResponsiveSpacing(
        context,
        xs: AppSpacing.sm,
        sm: AppSpacing.md,
        md: AppSpacing.md,
      ),
    );
  }

  /// Large gap (section spacing)
  static SizedBox largeGap(BuildContext context) {
    return SizedBox(
      height: ResponsiveSpacing.getResponsiveSpacing(
        context,
        xs: AppSpacing.md,
        sm: AppSpacing.lg,
        md: AppSpacing.xl,
      ),
    );
  }

  /// Extra large gap (major section spacing)
  static SizedBox extraLargeGap(BuildContext context) {
    return SizedBox(
      height: ResponsiveSpacing.getResponsiveSpacing(
        context,
        xs: AppSpacing.lg,
        sm: AppSpacing.xl,
        md: AppSpacing.xxl,
      ),
    );
  }

  /// Horizontal small gap
  static SizedBox horizontalSmallGap(BuildContext context) {
    return SizedBox(
      width: ResponsiveSpacing.getResponsiveSpacing(
        context,
        xs: AppSpacing.xs,
        sm: AppSpacing.sm,
        md: AppSpacing.sm,
      ),
    );
  }

  /// Horizontal medium gap
  static SizedBox horizontalMediumGap(BuildContext context) {
    return SizedBox(
      width: ResponsiveSpacing.getResponsiveSpacing(
        context,
        xs: AppSpacing.sm,
        sm: AppSpacing.md,
        md: AppSpacing.md,
      ),
    );
  }

  /// Horizontal large gap
  static SizedBox horizontalLargeGap(BuildContext context) {
    return SizedBox(
      width: ResponsiveSpacing.getResponsiveSpacing(
        context,
        xs: AppSpacing.md,
        sm: AppSpacing.lg,
        md: AppSpacing.xl,
      ),
    );
  }

  // ============================================================================
  // GRID SPACING
  // ============================================================================

  /// Grid spacing (between grid items)
  static double gridSpacing(BuildContext context) {
    return ResponsiveSpacing.getResponsiveSpacing(
      context,
      xs: AppSpacing.xs,
      sm: AppSpacing.sm,
      md: AppSpacing.md,
    );
  }

  /// Grid cross axis spacing
  static double gridCrossAxisSpacing(BuildContext context) {
    return ResponsiveSpacing.getResponsiveSpacing(
      context,
      xs: AppSpacing.xs,
      sm: AppSpacing.sm,
      md: AppSpacing.md,
    );
  }

  /// Grid main axis spacing
  static double gridMainAxisSpacing(BuildContext context) {
    return ResponsiveSpacing.getResponsiveSpacing(
      context,
      xs: AppSpacing.sm,
      sm: AppSpacing.md,
      md: AppSpacing.lg,
    );
  }
}

/// Extension for easy spacing access
extension SpacingExtension on BuildContext {
  /// Get standardized screen padding
  EdgeInsets get screenPadding => StandardizedSpacing.screenPadding(this);

  /// Get standardized card padding
  EdgeInsets get cardPadding => StandardizedSpacing.cardPadding(this);

  /// Get standardized list item padding
  EdgeInsets get listItemPadding => StandardizedSpacing.listItemPadding(this);

  /// Get standardized form field padding
  EdgeInsets get formFieldPadding => StandardizedSpacing.formFieldPadding(this);

  /// Get standardized button padding
  EdgeInsets get buttonPadding => StandardizedSpacing.buttonPadding(this);

  /// Small gap widget
  Widget get smallGap => StandardizedSpacing.smallGap(this);

  /// Medium gap widget
  Widget get mediumGap => StandardizedSpacing.mediumGap(this);

  /// Large gap widget
  Widget get largeGap => StandardizedSpacing.largeGap(this);

  /// Extra large gap widget
  Widget get extraLargeGap => StandardizedSpacing.extraLargeGap(this);
}



