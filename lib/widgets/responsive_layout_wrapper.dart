import 'package:flutter/material.dart';
import '../utils/responsive_helper.dart';

class ResponsiveLayoutWrapper extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool enableSafeArea;
  final bool enableScroll;

  const ResponsiveLayoutWrapper({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.enableSafeArea = true,
    this.enableScroll = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = child;

    // Add responsive padding
    if (padding != null) {
      content = Padding(
        padding: padding!,
        child: content,
      );
    } else {
      content = Padding(
        padding: ResponsiveHelper.getResponsiveEdgeInsets(context),
        child: content,
      );
    }

    // Add responsive margin
    if (margin != null) {
      content = Container(
        margin: margin!,
        child: content,
      );
    }

    // Add safe area if enabled
    if (enableSafeArea) {
      content = SafeArea(
        child: content,
      );
    }

    // Add scroll if enabled
    if (enableScroll) {
      content = ResponsiveScrollView(
        child: content,
      );
    }

    return content;
  }
}

class ResponsiveColumn extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final double? spacing;

  const ResponsiveColumn({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    final responsiveSpacing = spacing ?? ResponsiveHelper.getResponsiveSpacing(context);
    
    return Column(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: children
          .expand((child) => [
                child,
                if (child != children.last) SizedBox(height: responsiveSpacing),
              ])
          .toList(),
    );
  }
}

class ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;
  final double? spacing;

  const ResponsiveRow({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.mainAxisSize = MainAxisSize.max,
    this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    final responsiveSpacing = spacing ?? ResponsiveHelper.getResponsiveSpacing(context);
    
    return Row(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: mainAxisSize,
      children: children
          .expand((child) => [
                child,
                if (child != children.last) SizedBox(width: responsiveSpacing),
              ])
          .toList(),
    );
  }
}

class ResponsiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Decoration? decoration;
  final double? elevation;
  final double? borderRadius;

  const ResponsiveCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.decoration,
    this.elevation,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: elevation ?? ResponsiveHelper.getResponsiveElevation(context),
      margin: margin ?? ResponsiveHelper.getResponsiveMargin(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          borderRadius ?? ResponsiveHelper.getResponsiveBorderRadius(context),
        ),
      ),
      color: color,
      child: Container(
        decoration: decoration,
        child: Padding(
          padding: padding ?? ResponsiveHelper.getResponsiveEdgeInsets(context),
          child: child,
        ),
      ),
    );
  }
}

class ResponsiveButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final bool isOutlined;

  const ResponsiveButton({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.height,
    this.padding,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonHeight = height ?? ResponsiveHelper.getResponsiveButtonHeight(context);
    final buttonPadding = padding ?? EdgeInsets.symmetric(
      horizontal: ResponsiveHelper.getResponsivePadding(context),
      vertical: ResponsiveHelper.getResponsiveSpacing(context) * 0.5,
    );

    if (isOutlined) {
      return SizedBox(
        height: buttonHeight,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: icon != null ? Icon(icon) : const SizedBox.shrink(),
          label: ResponsiveText(
            text,
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            padding: buttonPadding,
            side: BorderSide(
              color: backgroundColor ?? Theme.of(context).primaryColor,
              width: 2,
            ),
            foregroundColor: foregroundColor ?? backgroundColor ?? Theme.of(context).primaryColor,
          ),
        ),
      );
    } else {
      return SizedBox(
        height: buttonHeight,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: icon != null ? Icon(icon) : const SizedBox.shrink(),
          label: ResponsiveText(
            text,
            style: TextStyle(
              fontSize: ResponsiveHelper.getResponsiveFontSize(context, 16),
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor ?? Theme.of(context).primaryColor,
            foregroundColor: foregroundColor ?? Colors.white,
            padding: buttonPadding,
            elevation: ResponsiveHelper.getResponsiveElevation(context),
          ),
        ),
      );
    }
  }
}
