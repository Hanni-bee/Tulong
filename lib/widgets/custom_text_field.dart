import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/unified_typography.dart';
import '../constants/soft_ui_design.dart';

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
        backgroundColor: Colors.white,
        borderRadius: SoftUIDesign.inputBorderRadius,
        elevation: 2.0,
        borderColor: AppColors.lightGray.withOpacity(0.3),
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
        style: UnifiedTypography.formInput,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixText: prefixText,
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, color: AppColors.primary)
              : null,
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SoftUIDesign.inputBorderRadius),
            borderSide: BorderSide(
              color: AppColors.lightGray.withOpacity(0.3),
              width: 1.0,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SoftUIDesign.inputBorderRadius),
            borderSide: BorderSide(
              color: AppColors.lightGray.withOpacity(0.3),
              width: 1.0,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SoftUIDesign.inputBorderRadius),
            borderSide: const BorderSide(color: AppColors.primaryRed, width: 2.0),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SoftUIDesign.inputBorderRadius),
            borderSide: const BorderSide(color: AppColors.error, width: 2.0),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SoftUIDesign.inputBorderRadius),
            borderSide: const BorderSide(color: AppColors.error, width: 2.0),
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: UnifiedTypography.formLabel,
          hintStyle: UnifiedTypography.formHint,
        ),
      ),
    );
  }
}
