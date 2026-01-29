import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sqlite_service.dart';

class TwoFactorAuthService {
  static final TwoFactorAuthService _instance = TwoFactorAuthService._internal();
  factory TwoFactorAuthService() => _instance;
  TwoFactorAuthService._internal();

  // Generate a 6-digit verification code
  String _generateVerificationCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // Store verification code with expiration (5 minutes)
  Future<void> _storeVerificationCode(String email, String code) async {
    final prefs = await SharedPreferences.getInstance();
    final expiryTime = DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch;
    
    await prefs.setString('2fa_code', code);
    await prefs.setString('2fa_email', email);
    await prefs.setInt('2fa_expiry', expiryTime);
  }

  // Get stored verification code
  Future<Map<String, dynamic>?> _getStoredVerificationCode() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('2fa_code');
    final email = prefs.getString('2fa_email');
    final expiry = prefs.getInt('2fa_expiry');

    if (code == null || email == null || expiry == null) {
      return null;
    }

    // Check if code has expired
    if (DateTime.now().millisecondsSinceEpoch > expiry) {
      await _clearStoredVerificationCode();
      return null;
    }

    return {
      'code': code,
      'email': email,
      'expiry': expiry,
    };
  }

  // Clear stored verification code
  Future<void> _clearStoredVerificationCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('2fa_code');
    await prefs.remove('2fa_email');
    await prefs.remove('2fa_expiry');
  }

  // Send verification code via email only
  Future<bool> sendVerificationCode(String email) async {
    try {
      final code = _generateVerificationCode();
      await _storeVerificationCode(email, code);

      // Simulate email sending
      print('📧 Email verification code sent to $email: $code');
      // In production, integrate with email service like SendGrid, AWS SES, etc.
      // await emailService.sendVerificationCode(email, code);

      return true;
    } catch (e) {
      print('Error sending verification code: $e');
      return false;
    }
  }

  // Verify the entered code
  Future<bool> verifyCode(String enteredCode) async {
    try {
      final storedData = await _getStoredVerificationCode();
      
      if (storedData == null) {
        print('No verification code found or code expired');
        return false;
      }

      final isValid = storedData['code'] == enteredCode;
      
      if (isValid) {
        await _clearStoredVerificationCode();
      }

      return isValid;
    } catch (e) {
      print('Error verifying code: $e');
      return false;
    }
  }

  // Check if user has 2FA enabled (offline-only - stored in SharedPreferences)
  Future<bool> isTwoFactorEnabled(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('2fa_enabled_$userId') ?? false;
    } catch (e) {
      print('Error checking 2FA status: $e');
      return false;
    }
  }

  // Enable 2FA for user (offline-only)
  Future<bool> enableTwoFactor(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('2fa_enabled_$userId', true);
      await prefs.setInt('2fa_enabled_at_$userId', DateTime.now().millisecondsSinceEpoch);
      return true;
    } catch (e) {
      print('Error enabling 2FA: $e');
      return false;
    }
  }

  // Disable 2FA for user (offline-only)
  Future<bool> disableTwoFactor(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('2fa_enabled_$userId', false);
      await prefs.setInt('2fa_disabled_at_$userId', DateTime.now().millisecondsSinceEpoch);
      return true;
    } catch (e) {
      print('Error disabling 2FA: $e');
      return false;
    }
  }

  // Get remaining time for verification code
  Future<int> getRemainingTime() async {
    try {
      final storedData = await _getStoredVerificationCode();
      
      if (storedData == null) {
        return 0;
      }

      final expiry = storedData['expiry'] as int;
      final remaining = expiry - DateTime.now().millisecondsSinceEpoch;
      
      return remaining > 0 ? (remaining / 1000).round() : 0;
    } catch (e) {
      print('Error getting remaining time: $e');
      return 0;
    }
  }

  // Complete 2FA verification (offline-only)
  Future<bool> completeTwoFactorSignIn({
    required String email,
    required String password,
    required String verificationCode,
  }) async {
    try {
      // First verify the code
      final isCodeValid = await verifyCode(verificationCode);
      
      if (!isCodeValid) {
        throw Exception('Invalid verification code');
      }

      // Store 2FA verification status (offline-only)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_2fa_verification_$email', DateTime.now().millisecondsSinceEpoch);
      await prefs.setInt('last_login_$email', DateTime.now().millisecondsSinceEpoch);

      return true;
    } catch (e) {
      print('Error completing 2FA sign in: $e');
      rethrow;
    }
  }

  // Send recovery code for account recovery
  Future<bool> sendRecoveryCode(String email) async {
    try {
      // For now, just send the verification code without checking if user exists
      // This is a simplified approach that works with current Firebase Auth API
      return await sendVerificationCode(email);
    } catch (e) {
      print('Error sending recovery code: $e');
      rethrow;
    }
  }

  // Verify recovery code and allow password reset
  Future<bool> verifyRecoveryCode(String code) async {
    try {
      final isValid = await verifyCode(code);
      
      if (isValid) {
        // Store flag that recovery is verified
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('recovery_verified', true);
        await prefs.setInt('recovery_expiry', DateTime.now().add(const Duration(minutes: 10)).millisecondsSinceEpoch);
      }

      return isValid;
    } catch (e) {
      print('Error verifying recovery code: $e');
      return false;
    }
  }

  // Check if recovery is verified
  Future<bool> isRecoveryVerified() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final verified = prefs.getBool('recovery_verified') ?? false;
      final expiry = prefs.getInt('recovery_expiry') ?? 0;

      if (!verified || DateTime.now().millisecondsSinceEpoch > expiry) {
        return false;
      }

      return true;
    } catch (e) {
      print('Error checking recovery verification: $e');
      return false;
    }
  }

  // Clear recovery verification
  Future<void> clearRecoveryVerification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('recovery_verified');
      await prefs.remove('recovery_expiry');
    } catch (e) {
      print('Error clearing recovery verification: $e');
    }
  }

  // Reset password after recovery verification (offline-only)
  Future<bool> resetPassword(String newPassword) async {
    try {
      final isVerified = await isRecoveryVerified();
      
      if (!isVerified) {
        throw Exception('Recovery not verified');
      }

      // Get the email from stored verification data
      final storedData = await _getStoredVerificationCode();
      if (storedData == null) {
        throw Exception('No recovery session found');
      }

      final email = storedData['email'] as String;
      
      // Hash the new password
      final bytes = utf8.encode(newPassword);
      final digest = sha256.convert(bytes);
      final hashedPassword = digest.toString();

      // Update password in SQLite (offline-only)
      final sqliteService = SQLiteService();
      final existingUser = await sqliteService.getUserByEmail(email);
      
      if (existingUser != null) {
        await sqliteService.updateUser(existingUser['id'], {
          'password': hashedPassword,
        });
        print('✅ Password updated in SQLite for: $email');
      }
      
      // Clear recovery verification
      await clearRecoveryVerification();
      
      return true;
    } catch (e) {
      print('Error resetting password: $e');
      rethrow;
    }
  }

  // Update password after reset (offline-only)
  Future<bool> updatePasswordAfterReset({
    required String email,
    required String newPassword,
  }) async {
    try {
      // Hash the new password
      final bytes = utf8.encode(newPassword);
      final digest = sha256.convert(bytes);
      final hashedPassword = digest.toString();

      // Update password in SQLite (offline-only)
      final sqliteService = SQLiteService();
      final existingUser = await sqliteService.getUserByEmail(email);
      
      if (existingUser != null) {
        await sqliteService.updateUser(existingUser['id'], {
          'password': hashedPassword,
        });
        print('✅ Password updated in SQLite for: $email');
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error updating password after reset: $e');
      rethrow;
    }
  }
}
