import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/standardized_spacing.dart';

/// Standardized Card Widget
/// 
/// Provides consistent card spacing and layout across the app
class StandardizedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double? elevation;
  final BorderRadius? borderRadius;
  final Border? border;
  final VoidCallback? onTap;

  const StandardizedCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.elevation,
    this.borderRadius,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin ?? StandardizedSpacing.cardMargin(context),
      padding: padding ?? StandardizedSpacing.cardPadding(context),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.white,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        border: border,
        boxShadow: elevation != null
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: elevation!,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: borderRadius ?? BorderRadius.circular(12),
        child: card,
      );
    }

    return card;
  }
}

/// Standardized List Item Widget
/// 
/// Provides consistent list item spacing and layout
class StandardizedListItem extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;

  const StandardizedListItem({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final item = Container(
      margin: margin ?? EdgeInsets.only(
        bottom: StandardizedSpacing.listItemSpacing(context),
      ),
      padding: padding ?? StandardizedSpacing.listItemPadding(context),
      color: backgroundColor,
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        child: item,
      );
    }

    return item;
  }
}

/// Standardized Form Field Container
/// 
/// Provides consistent form field spacing and layout
class StandardizedFormField extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const StandardizedFormField({
    super.key,
    required this.child,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? EdgeInsets.only(
        bottom: StandardizedSpacing.formFieldSpacing(context),
      ),
      padding: padding ?? StandardizedSpacing.formFieldPadding(context),
      child: child,
    );
  }
}




