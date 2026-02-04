import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../constants/app_colors.dart';
import '../../utils/theme_colors.dart';
import '../../constants/unified_typography.dart';
import '../../services/biometric_service.dart';
import '../../services/sqlite_service.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

/// Biometric verification screen shown after registration form submission
/// This screen verifies the user's identity using device biometrics
/// After successful verification, user data is saved immediately
class BiometricVerificationScreen extends StatefulWidget {
  final Map<String, dynamic> registrationData;

  const BiometricVerificationScreen({
    super.key,
    required this.registrationData,
  });

  @override
  State<BiometricVerificationScreen> createState() => _BiometricVerificationScreenState();
}

class _BiometricVerificationScreenState extends State<BiometricVerificationScreen> {
  final BiometricService _biometricService = BiometricService();
  bool _isVerifying = false;
  bool _isVerified = false;
  bool _isSaving = false;
  bool _hasSavedUser = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _isDeviceSupported = false;
  bool _hasEnrolledBiometrics = false;
  List<BiometricType> _availableBiometrics = [];
  String? _generatedUid; // Store generated UID for display

  @override
  void initState() {
    super.initState();
    _checkBiometricSupport();
  }

  Future<void> _checkBiometricSupport() async {
    try {
      final isSupported = await _biometricService.isDeviceSupported();
      final hasEnrolled = await _biometricService.hasEnrolledBiometrics();
      final available = await _biometricService.getAvailableBiometrics();

      // Filter to only show fingerprint (remove face recognition)
      final fingerprintOnly = available.where((type) => type == BiometricType.fingerprint).toList();

      if (mounted) {
        setState(() {
          _isDeviceSupported = isSupported;
          _hasEnrolledBiometrics = hasEnrolled;
          _availableBiometrics = fingerprintOnly; // Only fingerprint
        });
      }
    } catch (e) {
      print('Error checking biometric support: $e');
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    if (_isVerifying || _isVerified) return;

    setState(() {
      _isVerifying = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      // Check if device supports biometrics and has enrolled biometrics
      if (!_isDeviceSupported || !_hasEnrolledBiometrics) {
        throw Exception('Fingerprint is not set up. Please set up fingerprint in device settings.');
      }

      // Perform biometric authentication (fingerprint only)
      // The OS will show fingerprint dialog if available
      final success = await _biometricService.authenticate(
        reason: 'Verify your identity using fingerprint',
      );

      if (success) {
        // Authentication successful - ONLY mark verified (do not save yet)
        if (mounted) {
          setState(() {
            _isVerified = true;
            _isVerifying = false;
            // Prepare UID to be used later when user taps Proceed
            _generatedUid ??= _generateUid();
          });

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification Complete!'),
              backgroundColor: AppColors.success,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Authentication failed or cancelled
        if (mounted) {
          setState(() {
            _isVerifying = false;
            _hasError = true;
            _errorMessage = 'Fingerprint verification failed or was cancelled. Please try again.';
          });
        }
      }
    } catch (e) {
      print('❌ Biometric authentication error: $e');
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _hasError = true;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  /// Generate unique UID for new user
  String _generateUid() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final micros = DateTime.now().microsecondsSinceEpoch;
    final randomStr = List.generate(12, (i) => chars[(timestamp + micros + i) % chars.length]).join();
    return randomStr;
  }

  /// Save user data immediately after successful biometric verification
  /// This happens automatically - no button press needed
  Future<bool> _saveUserData() async {
    final data = widget.registrationData;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Guard: never save unless biometric verification succeeded
    if (!_isVerified) return false;

    // Validate required fields (should already be valid from sign-up form)
    if (data['firstName'] == null || data['firstName'].toString().isEmpty) {
      return false;
    }
    if (data['lastName'] == null || data['lastName'].toString().isEmpty) {
      return false;
    }
    if (data['username'] == null || data['username'].toString().isEmpty) {
      return false;
    }
    if (data['hashedPassword'] == null || data['hashedPassword'].toString().isEmpty) {
      return false;
    }

      // Check if all required address fields are filled
      final address = data['address']?.toString().trim() ?? '';
      final region = data['region']?.toString().trim() ?? '';
      final province = data['province']?.toString().trim() ?? '';
      final city = data['city']?.toString().trim() ?? '';
      final barangay = data['barangay']?.toString().trim() ?? '';
      
      // Address setup is complete if all required fields are filled
      final isAddressComplete = address.isNotEmpty &&
          region.isNotEmpty &&
          province.isNotEmpty &&
          city.isNotEmpty &&
          barangay.isNotEmpty;

    // Use UID prepared at verification time; fallback if needed
    _generatedUid ??= _generateUid();

      // Prepare user data for SQLite (primary, offline-first)
      final suffix = data['suffix']?.toString();
      final userData = {
        'uid': _generatedUid, // PRIMARY KEY
        'first_name': data['firstName'].toString(),
        'last_name': data['lastName'].toString(),
        'suffix': suffix != null && suffix.isNotEmpty ? suffix : null,
        'username': data['username'].toString(),
        'street': address,
        'region': region,
        'province': province,
        'city': city,
        'barangay': barangay,
        'password': data['hashedPassword'].toString(),
        'is_online': 0,
        'account_status': 'active',
        'created_at': now,
        'last_seen': now,
        'is_synced': 0,
        'address_setup_completed': isAddressComplete ? 1 : 0,
        'is_verified': 1, // Biometric verification completed
      };

    print('💾 Saving user data to SQLite: ${userData['username']} with UID: $_generatedUid');

    final sqliteService = SQLiteService();
    int? userId;
    Map<String, dynamic>? savedUser;

    // Save to SQLite (ONLY here, after biometric success)
    try {
      userId = await sqliteService.insertUser(userData);
      print('✅ User saved to SQLite (UID: $_generatedUid, id: $userId)');
    } catch (e) {
      // If insert failed (e.g., unique constraint because a previous attempt already inserted),
      // treat as success if the user already exists in SQLite.
      print('⚠️ Insert failed, checking for existing user: $e');
      savedUser = await sqliteService.getUserByUsername(data['username'].toString());
      if (savedUser == null) {
        return false; // true insert failure
      }
    }

    // Load saved user (best-effort; do not fail the flow if lookup is flaky)
    savedUser ??= await sqliteService.getUserByUsername(data['username'].toString());
    savedUser ??= Map<String, dynamic>.from(userData);
    if ((savedUser['id'] == null || savedUser['id'].toString().isEmpty) && userId != null) {
      savedUser['id'] = userId;
    }
      
      // Build full name
      final fullName = suffix != null && suffix.isNotEmpty
          ? '${data['firstName']} ${data['lastName']} $suffix'
          : '${data['firstName']} ${data['lastName']}';
      
    // Save profile/session data (non-fatal if it fails)
    try {
      final prefs = await SharedPreferences.getInstance();
      if (savedUser['uid'] != null) {
        await prefs.setString('session_uid', savedUser['uid'].toString());
        print('✅ UID saved to SharedPreferences: ${savedUser['uid']}');
      }
      if (savedUser['id'] != null) {
        await prefs.setInt('session_user_id', savedUser['id'] as int);
        print('✅ User ID saved to SharedPreferences: ${savedUser['id']}');
      }
      
      // Save all profile details to SharedPreferences (matching ESP32 variable names)
      await prefs.setString('profile_name', fullName.trim());
      await prefs.setString('profile_username', data['username'].toString());
      await prefs.setString('profile_street', address);
      await prefs.setString('profile_province', province);
      await prefs.setString('profile_city', city);
      await prefs.setString('profile_barangay', barangay);
      await prefs.setString('profile_suffix', suffix ?? '');
      print('✅ Profile data saved to SharedPreferences for ESP32 sync (new account)');
    } catch (e) {
      print('⚠️ Failed to save profile/session prefs (non-fatal): $e');
    }

    // Set authenticated state (non-fatal if it fails; user is still saved)
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.setAuthenticated(
        email: data['username'], // Parameter name is 'email' for compatibility, but it's actually username
        name: fullName.trim(),
      );
    } catch (e) {
      print('⚠️ Failed to set authenticated state (non-fatal): $e');
    }

    print('✅ User data saved and authenticated');
    return true;
  }

  Future<bool> _checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _proceedToTutorial() {
    // User must be verified before proceeding
    if (!_isVerified) return;

    // Save user exactly once when user taps Proceed
    if (_hasSavedUser) {
      Navigator.of(context).pushReplacementNamed('/');
      return;
    }

    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _hasError = false;
      _errorMessage = null;
    });

    () async {
      final didSave = await _saveUserData();

      if (!mounted) return;

      if (!didSave) {
        setState(() {
          _isSaving = false;
          _hasError = true;
          _errorMessage = 'Verification succeeded but failed to save user data. Please try again.';
        });
        return;
      }

      setState(() {
        _isSaving = false;
        _hasSavedUser = true;
      });

      Navigator.of(context).pushReplacementNamed('/');
    }();
  }

  // Removed _getBiometricTypeName - only fingerprint is used now

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.background(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _isVerified
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.primaryRed),
                onPressed: () => Navigator.of(context).pop(),
              ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: _isVerified
                      ? Colors.green.shade50
                      : AppColors.primaryRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isVerified ? Icons.check_circle : Icons.fingerprint,
                  size: 60,
                  color: _isVerified ? Colors.green : AppColors.primaryRed,
                ),
              )
                  .animate()
                  .scale(duration: 600.ms, curve: Curves.elasticOut),

              const SizedBox(height: 32),

              // Title
              Text(
                _isVerified ? 'Verification Complete' : 'Verify Your Identity',
                style: UnifiedTypography.displayMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 200.ms),

              const SizedBox(height: 16),

              // Description
              Text(
                _isVerified
                    ? 'Your account has been created successfully. You can now proceed to the app.'
                    : 'Use your device biometrics to verify that you are the user.',
                style: UnifiedTypography.bodyLarge.copyWith(
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 300.ms),

              // Show UID after successful verification
              if (_isVerified && _generatedUid != null) ...[
                const SizedBox(height: 16),
                Text(
                  'UID: $_generatedUid',
                  style: UnifiedTypography.bodySmall.copyWith(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 400.ms),
              ],

              const SizedBox(height: 40),

              // Biometric options (only show if not verified and device supports)
              if (!_isVerified && _isDeviceSupported && _hasEnrolledBiometrics) ...[
                // Show fingerprint button - OS will handle showing the right biometric dialog
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildBiometricButton(BiometricType.fingerprint),
                ),
              ],

              // Error message
              if (_hasError && _errorMessage != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Device not supported message
              if (!_isDeviceSupported) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This device does not support biometric authentication.',
                          style: TextStyle(color: Colors.orange.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // No biometrics enrolled message
              if (_isDeviceSupported && !_hasEnrolledBiometrics) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No fingerprint enrolled. Please set up fingerprint in device settings.',
                          style: TextStyle(color: Colors.orange.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 40),

              // Proceed button (only shown after verification)
              if (_isVerified) ...[
                ElevatedButton(
                  onPressed: _isSaving ? null : _proceedToTutorial,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Proceed',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .scale(duration: 400.ms),
              ],

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricButton(BiometricType type) {
    // Only show fingerprint button
    return ElevatedButton.icon(
      onPressed: _isVerifying ? null : _authenticateWithBiometrics,
      icon: _isVerifying
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.fingerprint),
      label: Text(_isVerifying ? 'Verifying...' : 'Use Fingerprint'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

