import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

/// Service for handling biometric authentication (fingerprint/Face ID)
/// Works 100% offline - uses device-native biometrics only
class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if device supports biometrics
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (e) {
      print('Error checking biometric support: $e');
      return false;
    }
  }

  /// Check if device has biometrics enrolled
  Future<bool> hasEnrolledBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      print('Error checking enrolled biometrics: $e');
      return false;
    }
  }

  /// Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      print('Error getting available biometrics: $e');
      return [];
    }
  }

  /// Authenticate using biometrics
  /// Returns true if authentication succeeds, false otherwise
  Future<bool> authenticate({
    String reason = 'Verify that you are the user',
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    try {
      // First check if device supports biometrics
      final isSupported = await isDeviceSupported();
      if (!isSupported) {
        throw Exception('Device does not support biometric authentication');
      }

      // Check if biometrics are enrolled
      final hasBiometrics = await hasEnrolledBiometrics();
      if (!hasBiometrics) {
        throw Exception('No fingerprint enrolled on this device. Please set up fingerprint in device settings.');
      }

      // Perform authentication - local_auth will handle fingerprint/face detection
      // We don't need to check specific biometric type here as the OS will handle it
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: true, // Only use biometrics, no fallback to PIN/password
        ),
      );

      return didAuthenticate;
    } on PlatformException catch (e) {
      print('Biometric authentication error: $e');
      if (e.code == 'NotAvailable') {
        throw Exception('Biometric authentication is not available on this device');
      } else if (e.code == 'NotEnrolled') {
        throw Exception('No fingerprint enrolled. Please set up fingerprint in device settings.');
      } else if (e.code == 'LockedOut') {
        throw Exception('Biometric authentication is locked. Please try again later.');
      } else if (e.code == 'PermanentlyLockedOut') {
        throw Exception('Biometric authentication is permanently locked. Please use device settings to unlock.');
      }
      throw Exception('Biometric authentication failed: ${e.message}');
    } catch (e) {
      print('Unexpected biometric error: $e');
      throw Exception('Biometric authentication failed: ${e.toString()}');
    }
  }

  /// Stop authentication (if in progress)
  Future<void> stopAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } catch (e) {
      print('Error stopping authentication: $e');
    }
  }
}

