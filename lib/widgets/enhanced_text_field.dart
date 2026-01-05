import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui' show ImageFilter;
import '../constants/app_colors.dart';
import '../constants/unified_typography.dart';
import '../utils/haptic_helper.dart';

class EnhancedTextField extends StatefulWidget {
  final String label;
  final String hint;
  final IconData prefixIcon;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool isPassword;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;

  const EnhancedTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    required this.controller,
    this.focusNode,
    this.isPassword = false,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.onFieldSubmitted,
    this.enabled = true,
  });

  @override
  State<EnhancedTextField> createState() => _EnhancedTextFieldState();
}

class _EnhancedTextFieldState extends State<EnhancedTextField>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late FocusNode _internalFocusNode;
  
  bool _obscureText = true;
  bool _isValid = false;
  String? _errorText;
  bool _isHovered = false;

  FocusNode get _focusNode => widget.focusNode ?? _internalFocusNode;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
    _internalFocusNode = FocusNode();
    
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnim = Tween<double>(begin: 0.98, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    
    _focusNode.addListener(_onFocusChanged);
    widget.controller.addListener(_validate);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    widget.controller.removeListener(_validate);
    _internalFocusNode.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _animController.forward();
      HapticHelper.light();
    } else {
      _animController.reverse();
    }
    setState(() {});
  }

  void _validate() {
    final text = widget.controller.text;
    bool isValid = false;
    
    if (widget.validator != null) {
      isValid = widget.validator!(text) == null && text.isNotEmpty;
    } else {
      isValid = text.isNotEmpty;
    }

    if (isValid != _isValid) {
      setState(() {
        _isValid = isValid;
        if (isValid) _errorText = null;
      });
      if (isValid) HapticHelper.selection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFocused = _focusNode.hasFocus;
    final hasText = widget.controller.text.isNotEmpty;
    final hasError = _errorText != null;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Premium Label
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Text(
                widget.label.toUpperCase(),
                style: UnifiedTypography.labelMedium.copyWith(
                  color: hasError 
                      ? AppColors.error 
                      : isFocused 
                          ? AppColors.primaryRed 
                          : AppColors.textSecondary.withOpacity(0.7),
                  fontWeight: isFocused ? FontWeight.w900 : FontWeight.w700,
                  letterSpacing: 1.2,
                  fontSize: 11,
                ),
              ).animate(target: isFocused ? 1 : 0).tint(color: AppColors.primaryRed),
              const Spacer(),
              if (_isValid)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: AppColors.online,
                ).animate().scale(curve: Curves.easeOutBack).fade()
              else if (hasError)
                const Icon(
                  Icons.error_rounded,
                  size: 16,
                  color: AppColors.error,
                ).animate().shake(duration: 400.ms),
            ],
          ),
        ),
        
        // Input Field Container with Glassmorphism
        MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: ScaleTransition(
            scale: _scaleAnim,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutQuart,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(isFocused ? 1.0 : 0.9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: hasError 
                      ? AppColors.error.withOpacity(0.5)
                      : isFocused 
                          ? AppColors.primaryRed 
                          : _isHovered 
                              ? AppColors.textSecondary.withOpacity(0.3)
                              : AppColors.textSecondary.withOpacity(0.1),
                  width: isFocused ? 1.5 : 1.0,
                ),
                boxShadow: [
                  if (isFocused)
                    BoxShadow(
                      color: AppColors.primaryRed.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                      spreadRadius: -2,
                    )
                  else if (_isHovered)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  else
                    BoxShadow(
                      color: Colors.black.withOpacity(0.01),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: TextFormField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    obscureText: widget.isPassword && _obscureText,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.textInputAction,
                    onFieldSubmitted: widget.onFieldSubmitted,
                    enabled: widget.enabled,
                    style: UnifiedTypography.bodyLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: widget.isPassword && _obscureText ? 2.0 : 0.0,
                    ),
                    validator: (value) {
                      final result = widget.validator?.call(value);
                      setState(() {
                        _errorText = result;
                      });
                      if (result != null) HapticHelper.error();
                      return null; // Handle error text manually for modernization
                    },
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      hintStyle: UnifiedTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary.withOpacity(0.3),
                        letterSpacing: 0,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      prefixIcon: Icon(
                        widget.prefixIcon,
                        color: hasError 
                            ? AppColors.error.withOpacity(0.7)
                            : isFocused 
                                ? AppColors.primaryRed 
                                : AppColors.textSecondary.withOpacity(0.4),
                        size: 22,
                      ).animate(target: isFocused ? 1 : 0).scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
                      suffixIcon: widget.isPassword
                          ? IconButton(
                              icon: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: ScaleTransition(scale: anim, child: child)),
                                child: Icon(
                                  _obscureText ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                  key: ValueKey(_obscureText),
                                  color: isFocused ? AppColors.primaryRed : AppColors.textSecondary.withOpacity(0.4),
                                  size: 20,
                                ),
                              ),
                              onPressed: () {
                                HapticHelper.light();
                                setState(() {
                                  _obscureText = !_obscureText;
                                });
                              },
                            )
                          : (hasText && isFocused
                              ? IconButton(
                                  icon: const Icon(Icons.cancel_rounded, size: 20),
                                  color: AppColors.textSecondary.withOpacity(0.4),
                                  onPressed: () {
                                    HapticHelper.medium();
                                    widget.controller.clear();
                                  },
                                )
                              : null),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Modern Animated Error Message
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.error),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _errorText!,
                    style: UnifiedTypography.bodySmall.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ).animate().slideY(begin: -0.5, end: 0, curve: Curves.easeOut).fade(),
          ),
      ],
    );
  }
}

