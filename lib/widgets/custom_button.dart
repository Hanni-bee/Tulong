import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

enum ButtonVariant { primary, secondary, outline, ghost, danger }
enum ButtonSize { small, medium, large }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double height;
  final IconData? icon;
  final ButtonVariant variant;
  final ButtonSize size;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height = 56,
    this.icon,
    this.variant = ButtonVariant.primary,
    this.size = ButtonSize.large,
  });

  @override
  Widget build(BuildContext context) {
    final buttonHeight = _getButtonHeight();
    final buttonPadding = _getButtonPadding();
    final buttonStyle = _getButtonStyle();
    
    return Container(
      width: width ?? double.infinity,
      height: buttonHeight,
      decoration: BoxDecoration(
        gradient: buttonStyle.gradient,
        color: buttonStyle.backgroundColor,
        borderRadius: BorderRadius.circular(buttonStyle.borderRadius),
        border: buttonStyle.border,
        boxShadow: buttonStyle.shadows,
      ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            borderRadius: BorderRadius.circular(buttonStyle.borderRadius),
            splashColor: buttonStyle.textColor.withOpacity(0.1),
            highlightColor: buttonStyle.textColor.withOpacity(0.05),
          child: Container(
            padding: buttonPadding,
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(buttonStyle.textColor),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(
                            icon, 
                            size: buttonStyle.iconSize,
                            color: buttonStyle.textColor,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Flexible(
                          child: Text(
                            text,
                            style: TextStyle(
                              fontSize: buttonStyle.fontSize,
                              fontWeight: buttonStyle.fontWeight,
                              color: buttonStyle.textColor,
                              letterSpacing: buttonStyle.letterSpacing,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  double _getButtonHeight() {
    switch (size) {
      case ButtonSize.small:
        return 40;
      case ButtonSize.medium:
        return 48;
      case ButtonSize.large:
        return height;
    }
  }

  EdgeInsets _getButtonPadding() {
    switch (size) {
      case ButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 8);
      case ButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 12);
      case ButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    }
  }

  _ButtonStyle _getButtonStyle() {
    switch (variant) {
      case ButtonVariant.primary:
        return _ButtonStyle(
          gradient: AppColors.premiumRedGradient,
          backgroundColor: null,
          textColor: AppColors.white,
          border: Border.all(color: AppColors.white.withOpacity(0.2), width: 1),
          borderRadius: AppSpacing.radiusXl,
          shadows: [
            BoxShadow(
              color: AppColors.primaryRed.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: AppColors.white.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
          fontSize: size == ButtonSize.small ? 14 : size == ButtonSize.medium ? 16 : 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          iconSize: size == ButtonSize.small ? 16 : size == ButtonSize.medium ? 18 : 20,
        );
      case ButtonVariant.secondary:
        return _ButtonStyle(
          gradient: null,
          backgroundColor: AppColors.lightGray,
          textColor: AppColors.textPrimary,
          border: Border.all(color: AppColors.mediumGray, width: 1),
          borderRadius: AppSpacing.radiusXl,
          shadows: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          fontSize: size == ButtonSize.small ? 14 : size == ButtonSize.medium ? 16 : 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          iconSize: size == ButtonSize.small ? 16 : size == ButtonSize.medium ? 18 : 20,
        );
      case ButtonVariant.outline:
        return _ButtonStyle(
          gradient: null,
          backgroundColor: Colors.transparent,
          textColor: AppColors.primaryRed,
          border: Border.all(color: AppColors.primaryRed, width: 2),
          borderRadius: AppSpacing.radiusXl,
          shadows: [],
          fontSize: size == ButtonSize.small ? 14 : size == ButtonSize.medium ? 16 : 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          iconSize: size == ButtonSize.small ? 16 : size == ButtonSize.medium ? 18 : 20,
        );
      case ButtonVariant.ghost:
        return _ButtonStyle(
          gradient: null,
          backgroundColor: Colors.transparent,
          textColor: AppColors.primaryRed,
          border: null,
          borderRadius: AppSpacing.radiusXl,
          shadows: [],
          fontSize: size == ButtonSize.small ? 14 : size == ButtonSize.medium ? 16 : 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          iconSize: size == ButtonSize.small ? 16 : size == ButtonSize.medium ? 18 : 20,
        );
      case ButtonVariant.danger:
        return _ButtonStyle(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.error, AppColors.error.withOpacity(0.8)],
          ),
          backgroundColor: null,
          textColor: AppColors.white,
          border: Border.all(color: AppColors.white.withOpacity(0.2), width: 1),
          borderRadius: AppSpacing.radiusXl,
          shadows: [
            BoxShadow(
              color: AppColors.error.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          fontSize: size == ButtonSize.small ? 14 : size == ButtonSize.medium ? 16 : 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          iconSize: size == ButtonSize.small ? 16 : size == ButtonSize.medium ? 18 : 20,
        );
    }
  }
}

class _ButtonStyle {
  final LinearGradient? gradient;
  final Color? backgroundColor;
  final Color textColor;
  final Border? border;
  final double borderRadius;
  final List<BoxShadow> shadows;
  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;
  final double iconSize;

  _ButtonStyle({
    this.gradient,
    this.backgroundColor,
    required this.textColor,
    this.border,
    required this.borderRadius,
    required this.shadows,
    required this.fontSize,
    required this.fontWeight,
    required this.letterSpacing,
    required this.iconSize,
  });
}
