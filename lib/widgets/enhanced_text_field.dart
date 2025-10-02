import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../constants/app_spacing.dart';

class EnhancedTextField extends StatefulWidget {
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
  final bool isRequired;
  final String? helperText;
  final String? errorText;
  final InputVariant variant;
  final InputSize size;

  const EnhancedTextField({
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
    this.isRequired = false,
    this.helperText,
    this.errorText,
    this.variant = InputVariant.filled,
    this.size = InputSize.large,
  });

  @override
  State<EnhancedTextField> createState() => _EnhancedTextFieldState();
}

enum InputVariant { filled, outlined, underlined, ghost }
enum InputSize { small, medium, large }

class _EnhancedTextFieldState extends State<EnhancedTextField> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final inputStyle = _getInputStyle();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        if (widget.label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: RichText(
              text: TextSpan(
                text: widget.label,
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.textPrimary,
                ),
                children: widget.isRequired
                    ? [
                        TextSpan(
                          text: ' *',
                          style: AppTypography.labelLarge.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ]
                    : [],
              ),
            ),
          ),
        
        // Input Field
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: inputStyle.gradient,
            color: inputStyle.backgroundColor,
            borderRadius: BorderRadius.circular(inputStyle.borderRadius),
            border: inputStyle.border,
            boxShadow: _isFocused ? inputStyle.focusedShadows : inputStyle.shadows,
          ),
          child: Focus(
            onFocusChange: (hasFocus) {
              setState(() {
                _isFocused = hasFocus;
              });
            },
            child: TextFormField(
              controller: widget.controller,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              validator: widget.validator,
              onChanged: widget.onChanged,
              maxLines: widget.maxLines,
              enabled: widget.enabled,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: widget.hint,
                prefixIcon: widget.prefixIcon != null
                    ? Icon(
                        widget.prefixIcon,
                        color: _isFocused ? AppColors.primaryRed : AppColors.mediumGray,
                        size: inputStyle.iconSize,
                      )
                    : null,
                suffixIcon: widget.suffixIcon,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: inputStyle.padding,
                hintStyle: AppTypography.bodyLarge.copyWith(
                  color: AppColors.mediumGray,
                ),
                helperText: widget.helperText,
                helperStyle: AppTypography.captionText.copyWith(
                  color: AppColors.textSecondary,
                ),
                errorText: widget.errorText,
                errorStyle: AppTypography.captionText.copyWith(
                  color: AppColors.error,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  _InputStyle _getInputStyle() {
    switch (widget.variant) {
      case InputVariant.filled:
        return _InputStyle(
          gradient: AppColors.premiumGlassGradient,
          backgroundColor: null,
          border: Border.all(
            color: _isFocused ? AppColors.primaryRed : AppColors.glassBorder,
            width: _isFocused ? 2 : 1.5,
          ),
          borderRadius: AppSpacing.radiusXl,
          shadows: [
            const BoxShadow(
              color: AppColors.redShadow,
              blurRadius: 15,
              offset: Offset(0, 6),
            ),
            BoxShadow(
              color: AppColors.white.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
          focusedShadows: [
            BoxShadow(
              color: AppColors.primaryRed.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: AppColors.white.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
          padding: _getPadding(),
          iconSize: _getIconSize(),
        );
      case InputVariant.outlined:
        return _InputStyle(
          gradient: null,
          backgroundColor: Colors.transparent,
          border: Border.all(
            color: _isFocused ? AppColors.primaryRed : AppColors.mediumGray,
            width: _isFocused ? 2 : 1,
          ),
          borderRadius: AppSpacing.radiusLg,
          shadows: [],
          focusedShadows: [
            BoxShadow(
              color: AppColors.primaryRed.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          padding: _getPadding(),
          iconSize: _getIconSize(),
        );
      case InputVariant.underlined:
        return _InputStyle(
          gradient: null,
          backgroundColor: Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: _isFocused ? AppColors.primaryRed : AppColors.mediumGray,
              width: _isFocused ? 2 : 1,
            ),
          ),
          borderRadius: 0,
          shadows: [],
          focusedShadows: [],
          padding: _getPadding(),
          iconSize: _getIconSize(),
        );
      case InputVariant.ghost:
        return _InputStyle(
          gradient: null,
          backgroundColor: AppColors.ultraLightGray,
          border: null,
          borderRadius: AppSpacing.radiusLg,
          shadows: [],
          focusedShadows: [
            BoxShadow(
              color: AppColors.primaryRed.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          padding: _getPadding(),
          iconSize: _getIconSize(),
        );
    }
  }

  EdgeInsets _getPadding() {
    switch (widget.size) {
      case InputSize.small:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      case InputSize.medium:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
      case InputSize.large:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 16);
    }
  }

  double _getIconSize() {
    switch (widget.size) {
      case InputSize.small:
        return 18;
      case InputSize.medium:
        return 20;
      case InputSize.large:
        return 22;
    }
  }
}

class _InputStyle {
  final LinearGradient? gradient;
  final Color? backgroundColor;
  final Border? border;
  final double borderRadius;
  final List<BoxShadow> shadows;
  final List<BoxShadow> focusedShadows;
  final EdgeInsets padding;
  final double iconSize;

  _InputStyle({
    this.gradient,
    this.backgroundColor,
    this.border,
    required this.borderRadius,
    required this.shadows,
    required this.focusedShadows,
    required this.padding,
    required this.iconSize,
  });
}
