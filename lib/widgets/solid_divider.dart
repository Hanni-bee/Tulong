import 'package:flutter/material.dart';

class SolidDivider extends StatelessWidget {
  final double indent;
  final double endIndent;
  final Color color;

  const SolidDivider({
    super.key,
    this.indent = 0,
    this.endIndent = 0,
    this.color = const Color(0xFFE6E6E6),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsetsDirectional.only(start: indent, end: endIndent),
      height: 1,
      color: color,
    );
  }
}
