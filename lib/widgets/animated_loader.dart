import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../constants/app_colors.dart';

class AnimatedLoader extends StatelessWidget {
  final String? message;
  final double? size;
  final Color? color;
  final bool showMessage;

  const AnimatedLoader({
    super.key,
    this.message,
    this.size,
    this.color,
    this.showMessage = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Lottie Animation
        Container(
          width: size ?? 120,
          height: size ?? 120,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Lottie.asset(
            'assets/lottie/loading.json',
            width: size ?? 120,
            height: size ?? 120,
            fit: BoxFit.contain,
          ),
        ),
        
        if (showMessage && message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: TextStyle(
              color: color ?? AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class SuccessAnimation extends StatelessWidget {
  final String? message;
  final VoidCallback? onComplete;

  const SuccessAnimation({
    super.key,
    this.message,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Lottie.asset(
            'assets/lottie/success.json',
            width: 120,
            height: 120,
            fit: BoxFit.contain,
            onLoaded: (composition) {
              // Auto-complete after animation
              Future.delayed(const Duration(seconds: 2), () {
                onComplete?.call();
              });
            },
          ),
        ),
        
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: const TextStyle(
              color: AppColors.success,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class ErrorAnimation extends StatelessWidget {
  final String? message;
  final VoidCallback? onComplete;

  const ErrorAnimation({
    super.key,
    this.message,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Lottie.asset(
            'assets/lottie/error.json',
            width: 120,
            height: 120,
            fit: BoxFit.contain,
            onLoaded: (composition) {
              // Auto-complete after animation
              Future.delayed(const Duration(seconds: 2), () {
                onComplete?.call();
              });
            },
          ),
        ),
        
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: const TextStyle(
              color: AppColors.error,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class EmptyStateAnimation extends StatelessWidget {
  final String? message;
  final String? subtitle;
  final VoidCallback? onAction;
  final String? actionText;

  const EmptyStateAnimation({
    super.key,
    this.message,
    this.subtitle,
    this.onAction,
    this.actionText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: AppColors.mediumGray.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Lottie.asset(
            'assets/lottie/empty.json',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
          ),
        ),
        
        if (message != null) ...[
          const SizedBox(height: 24),
          Text(
            message!,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        
        if (onAction != null && actionText != null) ...[
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(actionText!),
          ),
        ],
      ],
    );
  }
}
