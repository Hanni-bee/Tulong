import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/haptic_helper.dart';

/// Centralized error handling service that provides user-friendly
/// error messages and recovery actions.
class ErrorHandlerService {
  /// Map technical errors to user-friendly messages
  static UserFriendlyError mapError(dynamic error, {String? context}) {
    final errorString = error.toString().toLowerCase();

    // Network errors
    if (errorString.contains('socket') ||
        errorString.contains('network') ||
        errorString.contains('connection')) {
      return UserFriendlyError(
        title: 'Connection Problem',
        message: 'Check your internet connection and try again.',
        icon: Icons.wifi_off,
        canRetry: true,
        hasOfflineMode: true,
        errorType: ErrorType.network,
      );
    }

    // Timeout errors
    if (errorString.contains('timeout')) {
      return UserFriendlyError(
        title: 'Request Timed Out',
        message: 'The request took too long. Please try again.',
        icon: Icons.timer_off,
        canRetry: true,
        errorType: ErrorType.timeout,
      );
    }

    // Firebase errors
    if (errorString.contains('firebase')) {
      if (errorString.contains('permission')) {
        return UserFriendlyError(
          title: 'Permission Denied',
          message: 'You don\'t have permission to perform this action.',
          icon: Icons.lock,
          canRetry: false,
          errorType: ErrorType.permission,
        );
      }
      return UserFriendlyError(
        title: 'Sync Error',
        message: 'Couldn\'t sync your data. Changes saved locally.',
        icon: Icons.cloud_off,
        canRetry: true,
        hasOfflineMode: true,
        errorType: ErrorType.sync,
      );
    }

    // Authentication errors
    if (errorString.contains('auth') || errorString.contains('login')) {
      return UserFriendlyError(
        title: 'Authentication Failed',
        message: 'Please check your credentials and try again.',
        icon: Icons.person_off,
        canRetry: true,
        errorType: ErrorType.auth,
      );
    }

    // Bluetooth errors
    if (errorString.contains('bluetooth')) {
      return UserFriendlyError(
        title: 'Bluetooth Error',
        message: 'Make sure Bluetooth is turned on and the device is nearby.',
        icon: Icons.bluetooth_disabled,
        canRetry: true,
        errorType: ErrorType.bluetooth,
      );
    }

    // File/Storage errors
    if (errorString.contains('file') ||
        errorString.contains('storage') ||
        errorString.contains('permission denied')) {
      return UserFriendlyError(
        title: 'Storage Error',
        message: 'Couldn\'t access storage. Check app permissions.',
        icon: Icons.storage,
        canRetry: false,
        errorType: ErrorType.storage,
      );
    }

    // Database errors
    if (errorString.contains('database') || errorString.contains('sql')) {
      return UserFriendlyError(
        title: 'Data Error',
        message: 'Problem accessing local data. Try restarting the app.',
        icon: Icons.storage,
        canRetry: true,
        errorType: ErrorType.database,
      );
    }

    // Generic error
    return UserFriendlyError(
      title: 'Something Went Wrong',
      message: context != null
          ? 'Couldn\'t $context. Please try again.'
          : 'An unexpected error occurred. Please try again.',
      icon: Icons.error_outline,
      canRetry: true,
      errorType: ErrorType.unknown,
    );
  }

  /// Show error dialog with recovery options
  static Future<ErrorAction?> showErrorDialog(
    BuildContext context,
    dynamic error, {
    String? errorContext,
    VoidCallback? onRetry,
    VoidCallback? onOffline,
    VoidCallback? onSupport,
  }) async {
    final friendlyError = mapError(error, context: errorContext);

    // Trigger error haptic feedback
    HapticHelper.error();

    return showDialog<ErrorAction>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          friendlyError.icon,
          color: AppColors.error,
          size: 48,
        ),
        title: Text(
          friendlyError.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              friendlyError.message,
              textAlign: TextAlign.center,
            ),
            if (friendlyError.technicalDetails != null) ...[
              const SizedBox(height: 16),
              ExpansionTile(
                title: const Text('Technical Details'),
                children: [
                  Text(
                    friendlyError.technicalDetails!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          // Cancel button
          TextButton(
            onPressed: () => Navigator.of(context).pop(ErrorAction.cancel),
            child: const Text('Cancel'),
          ),

          // Offline mode button
          if (friendlyError.hasOfflineMode && onOffline != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(ErrorAction.offline);
                onOffline();
              },
              child: const Text('Continue Offline'),
            ),

          // Support button
          if (onSupport != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(ErrorAction.support);
                onSupport();
              },
              child: const Text('Get Help'),
            ),

          // Retry button
          if (friendlyError.canRetry && onRetry != null)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(ErrorAction.retry);
                onRetry();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
              ),
              child: const Text('Try Again'),
            ),
        ],
      ),
    );
  }

  /// Show error snackbar (less intrusive than dialog)
  static void showErrorSnackbar(
    BuildContext context,
    dynamic error, {
    String? errorContext,
    VoidCallback? onRetry,
  }) {
    final friendlyError = mapError(error, context: errorContext);

    HapticHelper.error();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(friendlyError.icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    friendlyError.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(friendlyError.message),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 4),
        action: onRetry != null && friendlyError.canRetry
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: onRetry,
              )
            : null,
      ),
    );
  }
}

/// User-friendly error representation
class UserFriendlyError {
  final String title;
  final String message;
  final IconData icon;
  final bool canRetry;
  final bool hasOfflineMode;
  final ErrorType errorType;
  final String? technicalDetails;

  UserFriendlyError({
    required this.title,
    required this.message,
    required this.icon,
    this.canRetry = true,
    this.hasOfflineMode = false,
    required this.errorType,
    this.technicalDetails,
  });
}

/// Types of errors for categorization
enum ErrorType {
  network,
  timeout,
  auth,
  permission,
  sync,
  bluetooth,
  storage,
  database,
  unknown,
}

/// Actions user can take after error
enum ErrorAction {
  retry,
  cancel,
  offline,
  support,
}

