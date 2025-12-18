import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

class EnhancedInput extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final int? maxLines;
  final int? maxLength;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;
  final FocusNode? focusNode;
  final bool autoFocus;

  const EnhancedInput({
    super.key,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.maxLength,
    this.prefixIcon,
    this.suffixIcon,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.inputFormatters,
    this.focusNode,
    this.autoFocus = false,
  });

  @override
  State<EnhancedInput> createState() => _EnhancedInputState();
}

class _EnhancedInputState extends State<EnhancedInput>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);

    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });

    if (_isFocused) {
      _controller.forward();
      HapticFeedback.lightImpact();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;
    final borderColor = hasError 
        ? AppColors.error 
        : _isFocused 
            ? AppColors.primaryRed 
            : AppColors.lightGray;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTypography.labelMedium.copyWith(
              color: hasError 
                  ? AppColors.error 
                  : _isFocused 
                      ? AppColors.primaryRed 
                      : AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Input field
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: _isFocused
                    ? [
                        BoxShadow(
                          color: AppColors.primaryRed.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                          spreadRadius: 0,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                          spreadRadius: 0,
                        ),
                      ],
              ),
              child: TextFormField(
                controller: widget.controller,
                focusNode: _focusNode,
                keyboardType: widget.keyboardType,
                obscureText: widget.obscureText,
                enabled: widget.enabled,
                readOnly: widget.readOnly,
                maxLines: widget.maxLines,
                maxLength: widget.maxLength,
                onTap: widget.onTap,
                onChanged: widget.onChanged,
                onFieldSubmitted: widget.onSubmitted,
                validator: widget.validator,
                inputFormatters: widget.inputFormatters,
                autofocus: widget.autoFocus,
                style: AppTypography.bodyMedium.copyWith(
                  color: widget.enabled 
                      ? AppColors.textPrimary 
                      : AppColors.textSecondary,
                ),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary.withOpacity(0.7),
                  ),
                  prefixIcon: widget.prefixIcon,
                  suffixIcon: widget.suffixIcon,
                  filled: true,
                  fillColor: widget.enabled 
                      ? Colors.white 
                      : AppColors.ultraLightGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: borderColor,
                      width: _isFocused ? 2 : 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: borderColor,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.primaryRed,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.error,
                      width: 1,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.error,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  counterStyle: AppTypography.captionText.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            );
          },
        ),

        // Helper text or error text
        if (widget.helperText != null || widget.errorText != null) ...[
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: hasError
                ? Text(
                    widget.errorText!,
                    key: const ValueKey('error'),
                    style: AppTypography.captionText.copyWith(
                      color: AppColors.error,
                    ),
                  )
                : widget.helperText != null
                    ? Text(
                        widget.helperText!,
                        key: const ValueKey('helper'),
                        style: AppTypography.captionText.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      )
                    : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }
}

// Specialized input variants
class SearchInput extends StatelessWidget {
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool showClearButton;

  const SearchInput({
    super.key,
    this.hint,
    this.controller,
    this.onChanged,
    this.onClear,
    this.showClearButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return EnhancedInput(
      hint: hint ?? 'Search...',
      controller: controller,
      onChanged: onChanged,
      prefixIcon: Icon(
        Icons.search,
        color: AppColors.textSecondary,
        size: 20,
      ),
      suffixIcon: showClearButton && 
                  controller != null && 
                  controller!.text.isNotEmpty
          ? IconButton(
              icon: Icon(
                Icons.clear,
                color: AppColors.textSecondary,
                size: 20,
              ),
              onPressed: () {
                controller?.clear();
                onClear?.call();
              },
            )
          : null,
    );
  }
}

class PasswordInput extends StatefulWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final FormFieldValidator<String>? validator;
  final bool showStrength;

  const PasswordInput({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.validator,
    this.showStrength = false,
  });

  @override
  State<PasswordInput> createState() => _PasswordInputState();
}

class _PasswordInputState extends State<PasswordInput> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return EnhancedInput(
      label: widget.label,
      hint: widget.hint ?? 'Enter password',
      controller: widget.controller,
      obscureText: _obscureText,
      validator: widget.validator,
      prefixIcon: Icon(
        Icons.lock_outline,
        color: AppColors.textSecondary,
        size: 20,
      ),
      suffixIcon: IconButton(
        icon: Icon(
          _obscureText ? Icons.visibility : Icons.visibility_off,
          color: AppColors.textSecondary,
          size: 20,
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
      ),
    );
  }
}
