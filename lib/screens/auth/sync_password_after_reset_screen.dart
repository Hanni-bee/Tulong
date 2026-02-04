import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../utils/theme_colors.dart';
import '../../services/two_factor_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SyncPasswordAfterResetScreen extends StatefulWidget {
  const SyncPasswordAfterResetScreen({super.key});

  @override
  State<SyncPasswordAfterResetScreen> createState() => _SyncPasswordAfterResetScreenState();
}

class _SyncPasswordAfterResetScreenState extends State<SyncPasswordAfterResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _syncPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final twoFactorService = TwoFactorAuthService();
        final prefs = await SharedPreferences.getInstance();
        final email = prefs.getString('2fa_email');
        
        if (email == null) {
          throw Exception('No recovery session found. Please start password reset again.');
        }
        
        // Update password using TwoFactorAuthService (offline-only)
        await twoFactorService.updatePasswordAfterReset(
          email: email,
          newPassword: _passwordController.text,
        );
        
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password synced successfully! You can now log in with your new password.'),
              backgroundColor: AppColors.online,
            ),
          );
          
          // Navigate back to sign in screen
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to sync password: ${e.toString()}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.background(context),
      appBar: AppBar(
        title: const Text(
          'Sync Password',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        automaticallyImplyLeading: false, // Prevent back button
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.warning,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.sync,
                          size: 40,
                          color: ThemeColors.surface(context),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Password Reset Detected',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: ThemeColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please enter your new password to sync it with your account',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: ThemeColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Password field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    hintText: 'Enter your new password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        color: AppColors.mediumGray,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: const OutlineInputBorder(),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.primaryRed),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your new password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 30),
                
                // Info box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.warning,
                      width: 1,
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Why is this needed?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'After resetting your password via email, we need to sync the new password with your local account data to ensure you can log in properly.',
                        style: TextStyle(
                          fontSize: 12,
                          color: ThemeColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Sync button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _syncPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundcolor: ThemeColors.surface(context),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            color: ThemeColors.surface(context),
                            strokeWidth: 2,
                          )
                        : const Text(
                            'Sync Password',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
