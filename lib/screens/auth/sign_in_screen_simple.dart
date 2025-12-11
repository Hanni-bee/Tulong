import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../utils/input_validator.dart';
import 'sign_up_screen.dart';
import '../../constants/unified_typography.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final username = _usernameController.text.trim();
      final password = _passwordController.text;
      
      // Check if user has 2FA enabled
      final requiresTwoFactor = await authProvider.checkTwoFactorRequired(username);
      
      if (requiresTwoFactor) {
        // Navigate to 2FA verification screen
        if (mounted) {
          Navigator.of(context).pushNamed(
            '/two-factor-verification',
            arguments: {
              'username': username,
              'password': password,
              'isRecovery': false,
            },
          );
        }
      } else {
        // Regular sign-in without 2FA
        // Try SQLite first (offline-first approach)
        final offlineSuccess = await authProvider.loginOffline(username, password);
        
        if (offlineSuccess) {
          // Offline login successful
          print('Offline login successful for: $username');
          
          // Small delay to ensure user model is loaded before navigating
          await Future.delayed(const Duration(milliseconds: 300));
          
          // Try to sync with Firebase in background (non-blocking)
          _attemptFirebaseSync(username, password);
        } else {
          // Try Firebase as backup (online)
          try {
            final firebaseUser = await FirebaseService().authenticateUserByUsername(username: username, password: password);
            if (firebaseUser != null) {
              // Get user name from Firebase data
              final firstName = firebaseUser['FirstName'] ?? '';
              final lastName = firebaseUser['LastName'] ?? '';
              final displayName = '$firstName $lastName'.trim();
              
              await authProvider.setAuthenticated(username: username, name: displayName.isNotEmpty ? displayName : username);
              print('Online login successful for: $username');
              
              // Small delay to ensure user model is loaded
              await Future.delayed(const Duration(milliseconds: 300));
            } else {
              throw Exception('Firebase authentication returned no user');
            }
          } catch (firebaseError) {
            print('Both offline and online login failed for: $username');
            throw Exception('Invalid username or password');
          }
        }

        if (mounted) {
          // Navigate to splash screen to handle tutorial logic
          Navigator.of(context).pushReplacementNamed('/');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // SSO removed - deprecated
  @Deprecated('SSO removed')
  Future<void> _signInWithGoogle() async {
    // SSO removed
    return;
  }

  // Attempt Firebase sync in background (non-blocking)
  void _attemptFirebaseSync(String username, String password) async {
    try {
      print('Attempting Firebase sync for: $username');
      
      final firebaseService = FirebaseService();
      final userData = await firebaseService.authenticateUserByUsername(username: username, password: password);
      
      if (userData != null) {
        final firstName = userData['FirstName'] ?? '';
        final lastName = userData['LastName'] ?? '';
        final displayName = '$firstName $lastName'.trim();
        
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.setAuthenticated(username: username, name: displayName.isNotEmpty ? displayName : username);
        print('Firebase sync successful for: $username');
      }
    } catch (e) {
      print('Firebase sync failed (non-critical): $e');
      // Don't show error to user - offline mode is acceptable
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 100),
              
              // App Logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryRed.withOpacity(0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.8),
                      blurRadius: 24,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/app_logo (3).png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              Text(
                'T.U.L.O.N.G',
                style: UnifiedTypography.displayLarge,
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Disaster-Ready Communication',
                style: UnifiedTypography.buttonLarge,
              ),
              
              const SizedBox(height: 40),
              
              // Login Form
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Email field
                      TextFormField(
                        controller: _usernameController,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.none,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          hintText: 'Enter your username',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your username';
                          }
                          // Use InputValidator for username validation
                          final error = InputValidator.validateUsername(value);
                          return error;
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Password field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter your password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Forgot password link
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Navigator.of(context).pushNamed('/forgot-password');
                          },
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: AppColors.primaryRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      
                      // Sign in button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _signIn,
                          icon: _isLoading 
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.login, color: Colors.white),
                          label: Text(
                            _isLoading ? 'Signing In...' : 'Sign In',
                            style: UnifiedTypography.titleLarge,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryRed,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 8,
                            shadowColor: AppColors.primaryRed.withOpacity(0.3),
                          ),
                        ),
                      ),
                      
                      // SSO removed - Google sign in button removed
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Sign up link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SignUpScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        color: AppColors.primaryRed,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
