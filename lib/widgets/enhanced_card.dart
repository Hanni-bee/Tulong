import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../constants/app_spacing.dart';

class EnhancedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final CardVariant variant;
  final CardSize size;
  final bool isElevated;
  final bool isInteractive;
  final VoidCallback? onTap;
  final Color? accentColor;
  final String? title;
  final String? subtitle;
  final Widget? header;
  final Widget? footer;
  final bool isLoading;

  const EnhancedCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.variant = CardVariant.defaultCard,
    this.size = CardSize.medium,
    this.isElevated = true,
    this.isInteractive = false,
    this.onTap,
    this.accentColor,
    this.title,
    this.subtitle,
    this.header,
    this.footer,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final cardStyle = _getCardStyle();
    
    Widget cardContent = Container(
      margin: margin ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        gradient: cardStyle.gradient,
        color: cardStyle.backgroundColor,
        borderRadius: BorderRadius.circular(cardStyle.borderRadius),
        border: cardStyle.border,
        boxShadow: isElevated ? cardStyle.shadows : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isInteractive ? onTap : null,
          borderRadius: BorderRadius.circular(cardStyle.borderRadius),
          child: Container(
            padding: padding ?? _getPadding(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                if (header != null || title != null) ...[
                  _buildHeader(),
                  const SizedBox(height: AppSpacing.md),
                ],
                
                // Content
                if (isLoading)
                  _buildLoadingContent()
                else
                  child,
                
                // Footer
                if (footer != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  footer!,
                ],
              ],
            ),
          ),
        ),
      ),
    );

    return cardContent;
  }

  Widget _buildHeader() {
    if (header != null) return header!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Text(
            title!,
            style: AppTypography.headlineSmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle!,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLoadingContent() {
    return SizedBox(
      height: 120, // Increased for better loading content display
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  accentColor ?? AppColors.primaryRed,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Loading...',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _CardStyle _getCardStyle() {
    switch (variant) {
      case CardVariant.defaultCard:
        return _CardStyle(
          gradient: AppColors.cardGlassGradient,
          backgroundColor: null,
          border: Border.all(
            color: AppColors.glassBorder,
            width: 1,
          ),
          borderRadius: AppSpacing.radiusXl,
          shadows: [
            const BoxShadow(
              color: AppColors.redShadow,
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
            BoxShadow(
              color: AppColors.white.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        );
      case CardVariant.accentCard:
        return _CardStyle(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (accentColor ?? AppColors.primaryRed).withOpacity(0.1),
              (accentColor ?? AppColors.primaryRed).withOpacity(0.05),
            ],
          ),
          backgroundColor: null,
          border: Border.all(
            color: (accentColor ?? AppColors.primaryRed).withOpacity(0.3),
            width: 1,
          ),
          borderRadius: AppSpacing.radiusXl,
          shadows: [
            BoxShadow(
              color: (accentColor ?? AppColors.primaryRed).withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        );
      case CardVariant.flatCard:
        return _CardStyle(
          gradient: null,
          backgroundColor: AppColors.white,
          border: Border.all(
            color: AppColors.lightGray,
            width: 1,
          ),
          borderRadius: AppSpacing.radiusLg,
          shadows: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        );
      case CardVariant.glassCard:
        return _CardStyle(
          gradient: AppColors.premiumGlassGradient,
          backgroundColor: null,
          border: Border.all(
            color: AppColors.glassBorder,
            width: 1.5,
          ),
          borderRadius: AppSpacing.radiusXxl,
          shadows: [
            BoxShadow(
              color: AppColors.white.withOpacity(0.2),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
            const BoxShadow(
              color: AppColors.redShadow,
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
        );
    }
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case CardSize.small:
        return const EdgeInsets.all(AppSpacing.md);
      case CardSize.medium:
        return const EdgeInsets.all(AppSpacing.lg);
      case CardSize.large:
        return const EdgeInsets.all(AppSpacing.xl);
    }
  }
}

enum CardVariant { defaultCard, accentCard, flatCard, glassCard }
enum CardSize { small, medium, large }

class _CardStyle {
  final LinearGradient? gradient;
  final Color? backgroundColor;
  final Border? border;
  final double borderRadius;
  final List<BoxShadow> shadows;

  _CardStyle({
    this.gradient,
    this.backgroundColor,
    this.border,
    required this.borderRadius,
    required this.shadows,
  });
}
