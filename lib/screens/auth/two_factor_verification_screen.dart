import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/two_factor_auth_service.dart';
import '../../widgets/modern_loading_indicator.dart';

class TwoFactorVerificationScreen extends StatefulWidget {
  final String email;
  final String password;
  final bool isRecovery;

  const TwoFactorVerificationScreen({
    super.key,
    required this.email,
    required this.password,
    this.isRecovery = false,
  });

  @override
  State<TwoFactorVerificationScreen> createState() => _TwoFactorVerificationScreenState();
}

class _TwoFactorVerificationScreenState extends State<TwoFactorVerificationScreen> {
  final _codeController = TextEditingController();
  final _twoFactorService = TwoFactorAuthService();
  
  bool _isLoading = false;
  bool _isResending = false;
  int _remainingTime = 0;
  int _attempts = 0;
  final int _maxAttempts = 3;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _sendInitialCode();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        final remaining = await _twoFactorService.getRemainingTime();
        setState(() {
          _remainingTime = remaining;
        });
        return remaining > 0;
      }
      return false;
    });
  }

  Future<void> _sendInitialCode() async {
    setState(() => _isLoading = true);
    
    try {
      final success = await _twoFactorService.sendVerificationCode(
        widget.email,
      );
      
      if (!success) {
        if (mounted) {
          _showErrorSnackBar('Failed to send verification code. Please try again.');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendCode() async {
    setState(() => _isResending = true);
    
    try {
      final success = await _twoFactorService.sendVerificationCode(
        widget.email,
      );
      
      if (success) {
        if (mounted) {
          _showSuccessSnackBar('Verification code sent successfully!');
        }
      } else {
        if (mounted) {
          _showErrorSnackBar('Failed to resend verification code.');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.length != 6) {
      _showErrorSnackBar('Please enter a valid 6-digit code');
      return;
    }

    setState(() => _isLoading = true);

    try {
      bool isVerified;
      
      if (widget.isRecovery) {
        isVerified = await _twoFactorService.verifyRecoveryCode(_codeController.text);
      } else {
        isVerified = await _twoFactorService.verifyCode(_codeController.text);
      }

      if (isVerified) {
        if (widget.isRecovery) {
          // Navigate to password reset screen
          if (mounted) {
            Navigator.of(context).pushReplacementNamed('/reset-password');
          }
        } else {
          // Complete 2FA sign in
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          await authProvider.signInWithTwoFactor(
            widget.email,
            widget.password,
            _codeController.text,
          );

          if (mounted) {
            // Navigate to splash screen to handle tutorial logic
            Navigator.of(context).pushReplacementNamed('/');
          }
        }
      } else {
        setState(() => _attempts++);
        
        if (_attempts >= _maxAttempts) {
          _showErrorSnackBar('Too many failed attempts. Please try again later.');
          if (mounted) {
            Navigator.of(context).pop();
          }
        } else {
          _showErrorSnackBar('Invalid verification code. ${_maxAttempts - _attempts} attempts remaining.');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Verification failed: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            
            // Header
            const Text(
              'Two-Factor Authentication',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            
            const SizedBox(height: 12),
            
            Text(
              widget.isRecovery 
                  ? 'We\'ve sent a verification code to your email to help you recover your account.'
                  : 'We\'ve sent a 6-digit verification code to your email address.',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              widget.email,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryRed,
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Verification code input
            Text(
              'Enter verification code',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            
            const SizedBox(height: 12),
            
            TextFormField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                hintText: '000000',
                hintStyle: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                  color: Colors.grey.withOpacity(0.5),
                ),
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.primaryRed, width: 2),
                ),
                filled: true,
                fillColor: AppColors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onChanged: (value) {
                if (value.length == 6) {
                  _verifyCode();
                }
              },
            ),
            
            const SizedBox(height: 24),
            
            // Timer
            if (_remainingTime > 0)
              Center(
                child: Text(
                  'Code expires in ${_remainingTime}s',
                  style: TextStyle(
                    fontSize: 14,
                    color: _remainingTime < 60 ? Colors.red : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            
            const SizedBox(height: 32),
            
            // Verify button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const ModernLoadingIndicator(color: Colors.white)
                    : const Text(
                        'Verify Code',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Resend code button
            Center(
              child: TextButton(
                onPressed: _isResending || _remainingTime > 0 ? null : _resendCode,
                child: _isResending
                    ? const Text('Sending...')
                    : Text(
                        'Resend code',
                        style: TextStyle(
                          color: _remainingTime > 0 
                              ? Colors.grey 
                              : AppColors.primaryRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Help text
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Check your email inbox and spam folder. The code will expire in 5 minutes.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
