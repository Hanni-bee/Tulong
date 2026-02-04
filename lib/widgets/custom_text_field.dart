import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/unified_typography.dart';
import '../constants/soft_ui_design.dart';
import '../utils/theme_colors.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final int? maxLines;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefixText;
  final AutovalidateMode? autovalidateMode;

  const CustomTextField({
    super.key,
    this.controller,
    required this.label,
    required this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.enabled = true,
    this.inputFormatters,
    this.prefixText,
    this.autovalidateMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: SoftUIDesign.cardDecoration(
        context: context,
        backgroundColor: ThemeColors.surface(context),
        borderRadius: SoftUIDesign.inputBorderRadius,
        elevation: 2.0,
        borderColor: ThemeColors.border(context).withOpacity(0.5),
        showBorder: true,
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        autovalidateMode: autovalidateMode,
        onChanged: onChanged,
        maxLines: maxLines,
        enabled: enabled,
        inputFormatters: inputFormatters,
        style: UnifiedTypography.formInput.copyWith(
          color: ThemeColors.textPrimary(context),
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixText: prefixText,
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: ThemeColors.primary(context))
              : null,
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SoftUIDesign.inputBorderRadius),
            borderSide: BorderSide(
              color: ThemeColors.border(context).withOpacity(0.5),
              width: 1.0,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SoftUIDesign.inputBorderRadius),
            borderSide: BorderSide(
              color: ThemeColors.border(context).withOpacity(0.5),
              width: 1.0,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SoftUIDesign.inputBorderRadius),
            borderSide: BorderSide(color: ThemeColors.primary(context), width: 2.0),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SoftUIDesign.inputBorderRadius),
            borderSide: BorderSide(color: ThemeColors.error(context), width: 2.0),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SoftUIDesign.inputBorderRadius),
            borderSide: BorderSide(color: ThemeColors.error(context), width: 2.0),
          ),
          filled: true,
          fillColor: enabled ? Colors.transparent : ThemeColors.textTertiary(context).withOpacity(0.1),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SoftUIDesign.inputBorderRadius),
            borderSide: BorderSide(
              color: ThemeColors.border(context).withOpacity(0.5),
              width: 1.0,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: UnifiedTypography.formLabel.copyWith(
            color: enabled ? ThemeColors.textSecondary(context) : ThemeColors.textTertiary(context),
          ),
          hintStyle: UnifiedTypography.formHint.copyWith(
            color: ThemeColors.textTertiary(context), // Consistent readable hint in light/dark
          ),
        ),
      ),
    );
  }
}
