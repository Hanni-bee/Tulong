import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// Helper class for retry logic with exponential backoff
/// 
/// Example usage:
/// ```dart
/// final result = await RetryHelper.withRetry(
///   operation: () => apiService.fetchData(),
///   maxAttempts: 3,
/// );
/// ```
class RetryHelper {
  /// Execute an operation with automatic retry on failure
  /// 
  /// [operation] - The async operation to execute
  /// [maxAttempts] - Maximum number of retry attempts (default: 3)
  /// [initialDelay] - Initial delay before first retry (default: 1 second)
  /// [maxDelay] - Maximum delay between retries (default: 30 seconds)
  /// [onRetry] - Callback executed before each retry with attempt number
  /// 
  /// Returns the result of the operation
  /// Throws the last exception if all attempts fail
  static Future<T> withRetry<T>({
    required Future<T> Function() operation,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
    Duration maxDelay = const Duration(seconds: 30),
    void Function(int attempt, Duration delay)? onRetry,
  }) async {
    int attempt = 0;
    
    while (true) {
      try {
        attempt++;
        debugPrint('🔄 Attempt $attempt of $maxAttempts');
        return await operation();
      } catch (e) {
        if (attempt >= maxAttempts) {
          debugPrint('❌ All $maxAttempts attempts failed. Last error: $e');
          rethrow;
        }

        // Calculate exponential backoff delay
        final exponentialDelay = initialDelay * math.pow(2, attempt - 1);
        final delay = exponentialDelay > maxDelay ? maxDelay : exponentialDelay;

        debugPrint('⚠️ Attempt $attempt failed. Retrying in ${delay.inSeconds}s... Error: $e');

        // Notify callback
        onRetry?.call(attempt, delay);

        // Wait before next retry
        await Future.delayed(delay);
      }
    }
  }

  /// Execute an operation with retry, but only for specific exceptions
  /// 
  /// [operation] - The async operation to execute
  /// [shouldRetry] - Function to determine if the exception is retryable
  /// Other parameters same as [withRetry]
  static Future<T> withConditionalRetry<T>({
    required Future<T> Function() operation,
    required bool Function(dynamic error) shouldRetry,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
    Duration maxDelay = const Duration(seconds: 30),
    void Function(int attempt, Duration delay)? onRetry,
  }) async {
    int attempt = 0;

    while (true) {
      try {
        attempt++;
        return await operation();
      } catch (e) {
        // Check if we should retry this error
        if (!shouldRetry(e)) {
          debugPrint('❌ Non-retryable error: $e');
          rethrow;
        }

        if (attempt >= maxAttempts) {
          debugPrint('❌ All $maxAttempts attempts failed. Last error: $e');
          rethrow;
        }

        final exponentialDelay = initialDelay * math.pow(2, attempt - 1);
        final delay = exponentialDelay > maxDelay ? maxDelay : exponentialDelay;

        debugPrint('⚠️ Retryable error on attempt $attempt. Retrying in ${delay.inSeconds}s...');

        onRetry?.call(attempt, delay);
        await Future.delayed(delay);
      }
    }
  }

  /// Check if an error is a network error (commonly retryable)
  static bool isNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('socket') ||
        errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('failed host lookup');
  }

  /// Check if an error is a timeout error
  static bool isTimeoutError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('timeout');
  }
}

