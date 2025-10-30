import 'package:flutter/material.dart';

class EnhancedShadows {
  EnhancedShadows._();

  static const List<BoxShadow> buttonLight = [];

  static const List<BoxShadow> buttonMedium = [];

  static const List<BoxShadow> buttonStrong = [];

  static const List<BoxShadow> cardLight = [];
}

class LightCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadiusGeometry borderRadius;
  final Color backgroundColor;

  const LightCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.backgroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        boxShadow: const [],
      ),
      child: child,
    );
  }
}

 