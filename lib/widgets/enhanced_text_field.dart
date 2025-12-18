import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final bool showCharacterCount;
  final int? maxLength;
  final bool enableSearch;
  final VoidCallback? onSearch;
  final bool enableClear;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final AutovalidateMode autovalidateMode;
  final bool showPasswordStrength;
  final bool floatingLabel;
  final Color? accentColor;
  final bool enableAnimations;
  final Duration animationDuration;

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
    this.showCharacterCount = false,
    this.maxLength,
    this.enableSearch = false,
    this.onSearch,
    this.enableClear = false,
    this.focusNode,
    this.textInputAction,
    this.inputFormatters,
    this.autovalidateMode = AutovalidateMode.onUserInteraction,
    this.showPasswordStrength = false,
    this.floatingLabel = false,
    this.accentColor,
    this.enableAnimations = true,
    this.animationDuration = const Duration(milliseconds: 200),
  });

  @override
  State<EnhancedTextField> createState() => _EnhancedTextFieldState();
}

enum InputVariant { filled, outlined, underlined, ghost, neumorphic, emergency }
enum InputSize { small, medium, large }

class _EnhancedTextFieldState extends State<EnhancedTextField> with TickerProviderStateMixin {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late AnimationController _animationController;
  late AnimationController _shakeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _borderAnimation;
  late Animation<Offset> _shakeAnimation;

  bool _isFocused = false;
  bool _hasError = false;
  bool _showPassword = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();

    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _borderAnimation = Tween<double>(
      begin: 1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _shakeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.05, 0.0),
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));

    _focusNode.addListener(_onFocusChanged);
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _animationController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
      if (_isFocused && widget.enableAnimations) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _onTextChanged() {
    setState(() {});
    widget.onChanged?.call(_controller.text);
  }

  void _togglePasswordVisibility() {
    setState(() {
      _showPassword = !_showPassword;
    });
  }

  void _clearText() {
    _controller.clear();
    setState(() {});
  }

  void _performSearch() {
    widget.onSearch?.call();
  }

  void _showError(String error) {
    setState(() {
      _errorText = error;
      _hasError = true;
    });
    _shakeController.forward().then((_) {
      _shakeController.reverse();
    });
  }

  void _clearError() {
    setState(() {
      _errorText = null;
      _hasError = false;
    });
  }
  @override
  Widget build(BuildContext context) {
    final inputStyle = _getInputStyle();

    return AnimatedBuilder(
      animation: Listenable.merge([_animationController, _shakeController]),
      builder: (context, child) {
        return Transform.translate(
          offset: _shakeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label
                if (widget.floatingLabel || widget.label.isNotEmpty) ...[
                  _buildLabel(),
                  const SizedBox(height: AppSpacing.xs),
                ],

                // Input field
                Container(
                  decoration: _getContainerDecoration(),
                  child: TextFormField(
                    controller: _controller,
                    focusNode: _focusNode,
                    decoration: _getInputDecoration(),
                    obscureText: widget.obscureText && !_showPassword,
                    keyboardType: widget.keyboardType,
                    validator: widget.validator,
                    onChanged: (value) {
                      _onTextChanged();
                      if (widget.validator != null) {
                        final error = widget.validator!(value);
                        if (error != null) {
                          _showError(error);
                        } else {
                          _clearError();
                        }
                      }
                    },
                    maxLines: widget.maxLines,
                    enabled: widget.enabled,
                    maxLength: widget.maxLength,
                    textInputAction: widget.textInputAction,
                    inputFormatters: widget.inputFormatters,
                    autovalidateMode: widget.autovalidateMode,
                  ),
                ),

                // Helper text, error text, or character count
                _buildBottomContent(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLabel() {
    final accentColor = widget.accentColor ?? AppColors.primaryRed;

    return AnimatedDefaultTextStyle(
      duration: widget.animationDuration,
      style: _isFocused || _controller.text.isNotEmpty
        ? AppTypography.labelMedium.copyWith(
            color: accentColor,
            fontWeight: FontWeight.w600,
          )
        : AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
      child: Row(
        children: [
          Text(widget.label),
          if (widget.isRequired) ...[
            const SizedBox(width: 4),
            Text('*', style: TextStyle(color: accentColor)),
          ],
        ],
      ),
    );
  }

  BoxDecoration _getContainerDecoration() {
    final accentColor = widget.accentColor ?? AppColors.primaryRed;

    switch (widget.variant) {
      case InputVariant.filled:
        return BoxDecoration(
          color: _hasError
            ? AppColors.error.withOpacity(0.05)
            : AppColors.white,
          borderRadius: BorderRadius.circular(_getBorderRadius()),
          border: Border.all(
            color: _hasError
              ? AppColors.error
              : _isFocused
                ? accentColor
                : AppColors.borderColor,
            width: _isFocused ? _borderAnimation.value : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        );

      case InputVariant.outlined:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(_getBorderRadius()),
          border: Border.all(
            color: _hasError
              ? AppColors.error
              : _isFocused
                ? accentColor
                : AppColors.borderColor,
            width: _isFocused ? _borderAnimation.value : 1.0,
          ),
        );

      case InputVariant.underlined:
        return BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: _hasError
                ? AppColors.error
                : _isFocused
                  ? accentColor
                  : AppColors.borderColor,
              width: _isFocused ? _borderAnimation.value : 1.0,
            ),
          ),
        );

      case InputVariant.ghost:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(_getBorderRadius()),
          border: Border.all(
            color: Colors.transparent,
            width: 0,
          ),
        );

      case InputVariant.neumorphic:
        return BoxDecoration(
          color: _hasError
            ? AppColors.error.withOpacity(0.05)
            : AppColors.white,
          borderRadius: BorderRadius.circular(_getBorderRadius()),
          border: null,
          boxShadow: [
            BoxShadow(
              color: AppColors.neumorphicDark.withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(5, 5),
            ),
            BoxShadow(
              color: AppColors.neumorphicLight,
              blurRadius: 15,
              offset: const Offset(-5, -5),
            ),
          ],
        );

      case InputVariant.emergency:
        return BoxDecoration(
          color: _hasError
            ? AppColors.error.withOpacity(0.1)
            : AppColors.criticalBackground,
          borderRadius: BorderRadius.circular(_getBorderRadius()),
          border: Border.all(
            color: _hasError
              ? AppColors.error
              : _isFocused
                ? AppColors.emergencyRed
                : AppColors.emergencyRed.withOpacity(0.5),
            width: _isFocused ? 2.5 : 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.emergencyRed.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        );
    }
  }

  InputDecoration _getInputDecoration() {
    final accentColor = widget.accentColor ?? AppColors.primaryRed;

    return InputDecoration(
      hintText: widget.hint,
      hintStyle: AppTypography.bodyMedium.copyWith(
        color: AppColors.textSecondary,
      ),
      prefixIcon: widget.prefixIcon != null
        ? Icon(
            widget.prefixIcon,
            color: _isFocused ? accentColor : AppColors.textSecondary,
            size: _getIconSize(),
          )
        : null,
      suffixIcon: _buildSuffixIcon(),
      border: InputBorder.none,
      contentPadding: _getContentPadding(),
      counterText: '',
      errorText: _errorText,
    );
  }

  Widget? _buildSuffixIcon() {
    final accentColor = widget.accentColor ?? AppColors.primaryRed;
    final icons = <Widget>[];

    // Password visibility toggle
    if (widget.obscureText) {
      icons.add(
        IconButton(
          icon: Icon(
            _showPassword ? Icons.visibility : Icons.visibility_off,
            color: _isFocused ? accentColor : AppColors.textSecondary,
            size: _getIconSize(),
          ),
          onPressed: _togglePasswordVisibility,
          splashRadius: 20,
        ),
      );
    }

    // Clear button
    if (widget.enableClear && _controller.text.isNotEmpty) {
      icons.add(
        IconButton(
          icon: Icon(
            Icons.clear,
            color: _isFocused ? accentColor : AppColors.textSecondary,
            size: _getIconSize(),
          ),
          onPressed: _clearText,
          splashRadius: 20,
        ),
      );
    }

    // Search button
    if (widget.enableSearch) {
      icons.add(
        IconButton(
          icon: Icon(
            Icons.search,
            color: _isFocused ? accentColor : AppColors.textSecondary,
            size: _getIconSize(),
          ),
          onPressed: _performSearch,
          splashRadius: 20,
        ),
      );
    }

    // Custom suffix icon
    if (widget.suffixIcon != null) {
      icons.add(widget.suffixIcon!);
    }

    return icons.isNotEmpty
      ? Row(
          mainAxisSize: MainAxisSize.min,
          children: icons,
        )
      : null;
  }

  Widget _buildBottomContent() {
    final children = <Widget>[];

    // Error text
    if (_hasError && _errorText != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            _errorText!,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.error,
            ),
          ),
        ),
      );
    }
    // Helper text
    else if (widget.helperText != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            widget.helperText!,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    // Character count
    if (widget.showCharacterCount && widget.maxLength != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            '${_controller.text.length}/${widget.maxLength}',
            style: AppTypography.bodySmall.copyWith(
              color: _controller.text.length > widget.maxLength!
                ? AppColors.error
                : AppColors.textSecondary,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      );
    }

    // Password strength indicator
    if (widget.showPasswordStrength && widget.obscureText) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: _buildPasswordStrengthIndicator(),
        ),
      );
    }

    return Column(children: children);
  }

  Widget _buildPasswordStrengthIndicator() {
    final password = _controller.text;
    final strength = _calculatePasswordStrength(password);

    return Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: strength,
            backgroundColor: AppColors.lightGray,
            valueColor: AlwaysStoppedAnimation<Color>(
              _getStrengthColor(strength),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          _getStrengthText(strength),
          style: AppTypography.bodySmall.copyWith(
            color: _getStrengthColor(strength),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  double _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0.0;

    double strength = 0.0;

    // Length check
    if (password.length >= 8) strength += 0.25;
    if (password.length >= 12) strength += 0.15;

    // Character variety
    if (password.contains(RegExp(r'[a-z]'))) strength += 0.1;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.1;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.1;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.1;

    // Bonus for longer passwords with complexity
    if (password.length >= 16 && strength > 0.6) strength += 0.2;

    return strength.clamp(0.0, 1.0);
  }

  Color _getStrengthColor(double strength) {
    if (strength < 0.3) return AppColors.error;
    if (strength < 0.6) return AppColors.warning;
    if (strength < 0.8) return AppColors.info;
    return AppColors.success;
  }

  String _getStrengthText(double strength) {
    if (strength < 0.3) return 'Weak';
    if (strength < 0.6) return 'Fair';
    if (strength < 0.8) return 'Good';
    return 'Strong';
  }

  double _getBorderRadius() {
    switch (widget.variant) {
      case InputVariant.filled:
      case InputVariant.outlined:
      case InputVariant.ghost:
      case InputVariant.neumorphic:
      case InputVariant.emergency:
        return AppSpacing.radiusLg;
      case InputVariant.underlined:
        return 0;
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

  EdgeInsets _getContentPadding() {
    final basePadding = EdgeInsets.symmetric(
      horizontal: _getHorizontalPadding(),
      vertical: _getVerticalPadding(),
    );

    if (widget.prefixIcon != null || _buildSuffixIcon() != null) {
      return basePadding;
    }

    return basePadding;
  }

  double _getHorizontalPadding() {
    switch (widget.size) {
      case InputSize.small:
        return AppSpacing.md;
      case InputSize.medium:
        return AppSpacing.lg;
      case InputSize.large:
        return AppSpacing.xl;
    }
  }

  double _getVerticalPadding() {
    switch (widget.size) {
      case InputSize.small:
        return 12;
      case InputSize.medium:
        return 16;
      case InputSize.large:
        return 20;
    }
  }

  _InputStyle _getInputStyle() {
    switch (widget.variant) {
      case InputVariant.filled:
        return _InputStyle(
          backgroundColor: _hasError ? AppColors.error.withOpacity(0.05) : AppColors.white,
        );
      case InputVariant.outlined:
        return _InputStyle(
          backgroundColor: Colors.transparent,
        );
      case InputVariant.underlined:
        return _InputStyle(
          backgroundColor: Colors.transparent,
        );
      case InputVariant.ghost:
        return _InputStyle(
          backgroundColor: Colors.transparent,
        );
      case InputVariant.neumorphic:
        return _InputStyle(
          backgroundColor: _hasError ? AppColors.error.withOpacity(0.05) : AppColors.white,
        );

      case InputVariant.emergency:
        return _InputStyle(
          backgroundColor: _hasError ? AppColors.error.withOpacity(0.1) : AppColors.criticalBackground,
        );
    }
  }
}

enum InputState { normal, focused, error, disabled, loading }

class _InputStyle {
  final Color? backgroundColor;

  _InputStyle({
    this.backgroundColor,
  });
}
