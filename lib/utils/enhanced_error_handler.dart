import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

/// Error categories for better error handling
enum ErrorCategory {
  network,
  bluetooth,
  authentication,
  server,
  firebase,
  local,
  unknown,
}

/// Error severity levels
enum ErrorSeverity {
  low,      // Informational, can continue
  medium,   // Warning, may affect functionality
  high,     // Critical, blocks functionality
}

/// Enhanced error model
class AppError {
  final ErrorCategory category;
  final ErrorSeverity severity;
  final String userMessage;
  final String? technicalMessage;
  final String? recoveryAction;
  final bool canRetry;
  final bool canGoOffline;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  AppError({
    required this.category,
    required this.severity,
    required this.userMessage,
    this.technicalMessage,
    this.recoveryAction,
    this.canRetry = true,
    this.canGoOffline = false,
    DateTime? timestamp,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from exception
  factory AppError.fromException(
    dynamic exception, {
    ErrorCategory? category,
    String? customMessage,
    Map<String, dynamic>? metadata,
  }) {
    final errorString = exception.toString().toLowerCase();
    
    // Determine category if not provided
    final detectedCategory = category ?? _detectCategory(errorString);
    
    // Generate user-friendly message
    final userMessage = customMessage ?? _generateUserMessage(
      detectedCategory,
      errorString,
    );
    
    // Determine severity
    final severity = _determineSeverity(detectedCategory, errorString);
    
    // Determine recovery options
    final canRetry = _canRetry(detectedCategory, errorString);
    final canGoOffline = _canGoOffline(detectedCategory);
    
    return AppError(
      category: detectedCategory,
      severity: severity,
      userMessage: userMessage,
      technicalMessage: exception.toString(),
      recoveryAction: _getRecoveryAction(detectedCategory),
      canRetry: canRetry,
      canGoOffline: canGoOffline,
      metadata: metadata,
    );
  }

  static ErrorCategory _detectCategory(String errorString) {
    if (errorString.contains('network') || 
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('internet')) {
      return ErrorCategory.network;
    }
    if (errorString.contains('bluetooth') || 
        errorString.contains('device') ||
        errorString.contains('pair')) {
      return ErrorCategory.bluetooth;
    }
    if (errorString.contains('auth') || 
        errorString.contains('login') ||
        errorString.contains('password') ||
        errorString.contains('unauthorized')) {
      return ErrorCategory.authentication;
    }
    if (errorString.contains('firebase') || 
        errorString.contains('database') ||
        errorString.contains('realtime')) {
      return ErrorCategory.firebase;
    }
    if (errorString.contains('server') || 
        errorString.contains('500') ||
        errorString.contains('503')) {
      return ErrorCategory.server;
    }
    return ErrorCategory.unknown;
  }

  static String _generateUserMessage(ErrorCategory category, String errorString) {
    switch (category) {
      case ErrorCategory.network:
        if (errorString.contains('timeout')) {
          return 'Connection timed out. Please check your internet connection.';
        }
        if (errorString.contains('no internet') || errorString.contains('offline')) {
          return 'No internet connection. Please check your network settings.';
        }
        return 'Network error. Please check your connection and try again.';
      
      case ErrorCategory.bluetooth:
        if (errorString.contains('not found') || errorString.contains('unavailable')) {
          return 'Bluetooth device not found. Make sure it\'s powered on and in range.';
        }
        if (errorString.contains('pair') || errorString.contains('bond')) {
          return 'Failed to connect to device. Please try pairing again.';
        }
        if (errorString.contains('permission')) {
          return 'Bluetooth permission required. Please enable it in settings.';
        }
        return 'Bluetooth connection failed. Please try again.';
      
      case ErrorCategory.authentication:
        if (errorString.contains('wrong') || errorString.contains('invalid')) {
          return 'Incorrect username or password. Please try again.';
        }
        if (errorString.contains('expired') || errorString.contains('token')) {
          return 'Your session has expired. Please log in again.';
        }
        if (errorString.contains('not found') || errorString.contains('user')) {
          return 'Account not found. Please check your username.';
        }
        return 'Authentication failed. Please try again.';
      
      case ErrorCategory.firebase:
        if (errorString.contains('permission') || errorString.contains('denied')) {
          return 'Access denied. Please check your account permissions.';
        }
        if (errorString.contains('billing')) {
          return 'Service temporarily unavailable. Please try again later.';
        }
        return 'Sync error. Your data will be saved locally.';
      
      case ErrorCategory.server:
        return 'Server error. Please try again in a moment.';
      
      case ErrorCategory.local:
        return 'Local error occurred. Please try again.';
      
      case ErrorCategory.unknown:
        return 'Something went wrong. Please try again.';
    }
  }

  static ErrorSeverity _determineSeverity(ErrorCategory category, String errorString) {
    switch (category) {
      case ErrorCategory.network:
        return errorString.contains('offline') || errorString.contains('no internet')
            ? ErrorSeverity.medium
            : ErrorSeverity.low;
      
      case ErrorCategory.bluetooth:
        return ErrorSeverity.medium;
      
      case ErrorCategory.authentication:
        return ErrorSeverity.high;
      
      case ErrorCategory.firebase:
        return errorString.contains('billing') ? ErrorSeverity.high : ErrorSeverity.medium;
      
      case ErrorCategory.server:
        return ErrorSeverity.high;
      
      default:
        return ErrorSeverity.medium;
    }
  }

  static bool _canRetry(ErrorCategory category, String errorString) {
    // Don't retry authentication errors immediately (user needs to fix input)
    if (category == ErrorCategory.authentication && 
        (errorString.contains('wrong') || errorString.contains('invalid'))) {
      return false;
    }
    return true;
  }

  static bool _canGoOffline(ErrorCategory category) {
    return category == ErrorCategory.network || 
           category == ErrorCategory.firebase ||
           category == ErrorCategory.server;
  }

  static String? _getRecoveryAction(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.network:
        return 'Check your internet connection';
      case ErrorCategory.bluetooth:
        return 'Check device is powered on and in range';
      case ErrorCategory.authentication:
        return 'Verify your credentials';
      case ErrorCategory.firebase:
        return 'Data will sync when connection is restored';
      default:
        return null;
    }
  }
}

/// Auto-retry configuration
class RetryConfig {
  final int maxRetries;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;
  final bool Function(AppError)? shouldRetry;

  const RetryConfig({
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 30),
    this.shouldRetry,
  });

  Duration getDelay(int attempt) {
    final delay = initialDelay * pow(backoffMultiplier, attempt);
    return delay > maxDelay ? maxDelay : delay;
  }
}

/// Enhanced error handler with auto-retry and recovery
class EnhancedErrorHandler {
  static final Map<String, int> _retryCounts = {};
  static final Map<String, Timer> _retryTimers = {};

  /// Handle error with auto-retry
  static Future<T?> handleWithRetry<T>({
    required Future<T> Function() operation,
    required BuildContext context,
    String? operationId,
    RetryConfig? config,
    void Function(AppError)? onError,
    void Function()? onRetry,
    void Function()? onSuccess,
  }) async {
    final retryConfig = config ?? const RetryConfig();
    final opId = operationId ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    int attempt = 0;
    
    while (attempt <= retryConfig.maxRetries) {
      try {
        final result = await operation();
        
        // Success - clear retry count
        _retryCounts.remove(opId);
        _retryTimers[opId]?.cancel();
        _retryTimers.remove(opId);
        
        onSuccess?.call();
        return result;
      } catch (e) {
        final error = AppError.fromException(e);
        
        // Check if should retry
        final shouldRetry = retryConfig.shouldRetry?.call(error) ?? error.canRetry;
        
        if (!shouldRetry || attempt >= retryConfig.maxRetries) {
          // No more retries - show error
          _retryCounts.remove(opId);
          _retryTimers[opId]?.cancel();
          _retryTimers.remove(opId);
          
          onError?.call(error);
          showError(context, error);
          rethrow;
        }
        
        // Schedule retry
        attempt++;
        _retryCounts[opId] = attempt;
        
        final delay = retryConfig.getDelay(attempt - 1);
        
        if (onRetry != null) {
          onRetry();
        } else {
          // Show retry notification
          _showRetryNotification(context, error, attempt, retryConfig.maxRetries, delay);
        }
        
        await Future.delayed(delay);
      }
    }
    
    return null;
  }

  /// Show error with recovery options
  static void showError(BuildContext context, AppError error, {
    VoidCallback? onRetry,
    VoidCallback? onGoOffline,
    VoidCallback? onDismiss,
  }) {
    HapticFeedback.mediumImpact();
    
    // Show error snackbar or dialog based on severity
    if (error.severity == ErrorSeverity.high) {
      _showErrorDialog(context, error, onRetry: onRetry, onGoOffline: onGoOffline);
    } else {
      _showErrorSnackBar(context, error, onRetry: onRetry, onGoOffline: onGoOffline);
    }
  }

  /// Show error snackbar
  static void _showErrorSnackBar(
    BuildContext context,
    AppError error, {
    VoidCallback? onRetry,
    VoidCallback? onGoOffline,
  }) {
    final actions = <Widget>[];
    
    if (error.canRetry && (onRetry != null || error.category != ErrorCategory.authentication)) {
      actions.add(
        TextButton(
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            onRetry?.call();
          },
          child: const Text('Retry'),
        ),
      );
    }
    
    if (error.canGoOffline && onGoOffline != null) {
      actions.add(
        TextButton(
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            onGoOffline();
          },
          child: const Text('Go Offline'),
        ),
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _getErrorIcon(error.category),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    error.userMessage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (error.recoveryAction != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      error.recoveryAction!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        backgroundColor: _getErrorColor(error.severity),
        duration: Duration(seconds: error.severity == ErrorSeverity.high ? 5 : 3),
        action: actions.isNotEmpty
            ? SnackBarAction(
                label: actions.length == 1 ? 'Action' : 'More',
                textColor: Colors.white,
                onPressed: () {
                  // Show action sheet
                  _showErrorActions(context, error, onRetry: onRetry, onGoOffline: onGoOffline);
                },
              )
            : null,
      ),
    );
  }

  /// Show error dialog for high severity errors
  static void _showErrorDialog(
    BuildContext context,
    AppError error, {
    VoidCallback? onRetry,
    VoidCallback? onGoOffline,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getErrorColor(error.severity).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getErrorIcon(error.category),
                color: _getErrorColor(error.severity),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _getErrorTitle(error.category),
                style: AppTypography.headlineSmall.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error.userMessage,
              style: AppTypography.bodyLarge,
            ),
            if (error.recoveryAction != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.info.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 18, color: AppColors.info),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error.recoveryAction!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.info,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (error.canGoOffline && onGoOffline != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onGoOffline();
              },
              child: const Text('Go Offline'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Dismiss'),
          ),
          if (error.canRetry && (onRetry != null || error.category != ErrorCategory.authentication))
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _getErrorColor(error.severity),
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  /// Show error actions sheet
  static void _showErrorActions(
    BuildContext context,
    AppError error, {
    VoidCallback? onRetry,
    VoidCallback? onGoOffline,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.lightGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (error.canRetry && (onRetry != null || error.category != ErrorCategory.authentication))
              ListTile(
                leading: const Icon(Icons.refresh, color: AppColors.primaryRed),
                title: const Text('Retry'),
                onTap: () {
                  Navigator.pop(context);
                  onRetry?.call();
                },
              ),
            if (error.canGoOffline && onGoOffline != null)
              ListTile(
                leading: const Icon(Icons.cloud_off, color: AppColors.info),
                title: const Text('Continue Offline'),
                onTap: () {
                  Navigator.pop(context);
                  onGoOffline();
                },
              ),
            ListTile(
              leading: const Icon(Icons.help_outline, color: AppColors.textSecondary),
              title: const Text('Get Help'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Open help/support
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Show retry notification
  static void _showRetryNotification(
    BuildContext context,
    AppError error,
    int attempt,
    int maxRetries,
    Duration delay,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Retrying... ($attempt/$maxRetries)',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.info,
        duration: delay,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static IconData _getErrorIcon(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.network:
        return Icons.wifi_off;
      case ErrorCategory.bluetooth:
        return Icons.bluetooth_disabled;
      case ErrorCategory.authentication:
        return Icons.lock_outline;
      case ErrorCategory.firebase:
        return Icons.cloud_off;
      case ErrorCategory.server:
        return Icons.error_outline;
      default:
        return Icons.warning_outlined;
    }
  }

  static Color _getErrorColor(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.low:
        return AppColors.warning;
      case ErrorSeverity.medium:
        return AppColors.info;
      case ErrorSeverity.high:
        return AppColors.error;
    }
  }

  static String _getErrorTitle(ErrorCategory category) {
    switch (category) {
      case ErrorCategory.network:
        return 'Connection Error';
      case ErrorCategory.bluetooth:
        return 'Bluetooth Error';
      case ErrorCategory.authentication:
        return 'Authentication Error';
      case ErrorCategory.firebase:
        return 'Sync Error';
      case ErrorCategory.server:
        return 'Server Error';
      default:
        return 'Error';
    }
  }
}

/// Offline mode indicator widget
class OfflineModeIndicator extends StatelessWidget {
  final bool isOffline;
  final VoidCallback? onTap;

  const OfflineModeIndicator({
    super.key,
    required this.isOffline,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOffline) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.warning,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'Offline Mode',
              style: AppTypography.bodySmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.info_outline,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}


