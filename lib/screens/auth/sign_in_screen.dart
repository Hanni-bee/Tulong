import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../constants/app_colors.dart';
// import removed
import '../../providers/auth_provider.dart';
import '../../widgets/modern_responsive_layout.dart';
import 'sign_up_screen.dart';
import '../../services/offline_auth_service.dart';
import '../../services/biometric_service.dart';
import '../../services/sqlite_service.dart';
import '../../utils/input_validator.dart';
import '../../constants/unified_typography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController(); // Replaced email with username
  final _passwordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isQuickSignInLoading = false;
  String? _lastLoggedInUsername;
  final BiometricService _biometricService = BiometricService();

  @override
  void initState() {
    super.initState();
    _loadLastLoggedInUser();
  }

  @override
  void dispose() {
    _usernameController.dispose(); // Replaced email with username
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadLastLoggedInUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('session_username') ?? prefs.getString('session_email');
      if (username != null && username.isNotEmpty) {
        setState(() {
          _lastLoggedInUsername = username;
        });
      }
    } catch (e) {
      print('Error loading last logged in user: $e');
    }
  }

  Future<void> _quickSignInWithBiometric() async {
    if (_lastLoggedInUsername == null || _lastLoggedInUsername!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No previous login found. Please sign in manually.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isQuickSignInLoading = true;
    });

    try {
      // Check if device supports biometrics
      final isSupported = await _biometricService.isDeviceSupported();
      if (!isSupported) {
        throw Exception('Device does not support biometric authentication');
      }

      final hasBiometrics = await _biometricService.hasEnrolledBiometrics();
      if (!hasBiometrics) {
        throw Exception('No fingerprint enrolled. Please set up fingerprint in device settings.');
      }

      // Authenticate with fingerprint (no questions, instant)
      final didAuthenticate = await _biometricService.authenticate(
        reason: 'Quick sign in',
        useErrorDialogs: true,
        stickyAuth: true,
      );

      if (didAuthenticate) {
        // Get user from SQLite
        final sqliteService = SQLiteService();
        final user = await sqliteService.getUserByUsername(_lastLoggedInUsername!);
        
        if (user == null) {
          throw Exception('User not found');
        }

        // Update last seen - use UID if id is null
        final userId = user['id'];
        final userUid = user['uid']?.toString();
        
        if (userUid != null && userUid.isNotEmpty) {
          await sqliteService.updateUserByUid(userUid, {
            'last_seen': DateTime.now().millisecondsSinceEpoch,
            'is_online': 1,
          });
        } else if (userId != null) {
          await sqliteService.updateUser(userId, {
            'last_seen': DateTime.now().millisecondsSinceEpoch,
            'is_online': 1,
          });
        } else {
          print('⚠️ Warning: User has no id or uid, cannot update last_seen');
        }

        // Set authenticated state
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.setAuthenticated(
          email: _lastLoggedInUsername!,
          name: user['first_name'] != null 
              ? '${user['first_name']} ${user['last_name']}' 
              : _lastLoggedInUsername!,
        );

        // Small delay to ensure user model is loaded
        await Future.delayed(const Duration(milliseconds: 300));

        if (mounted) {
          // Navigate to main screen
          Navigator.of(context).pushReplacementNamed('/');
        }
      } else {
        throw Exception('Biometric authentication failed or was cancelled');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isQuickSignInLoading = false;
        });
      }
    }
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
      
      // Try offline SQLite first (offline-first approach)
      try {
        final user = await OfflineAuthService().signInOffline(username: username, password: password);
        await authProvider.setAuthenticated(
          email: username, // Using username as identifier
          name: user['first_name'] != null ? '${user['first_name']} ${user['last_name']}' : username,
        );
        // Small delay to ensure user model is loaded
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (_) {
        // Firebase sign-in removed (offline-only mode)
        // Authentication now handled through SQLite only
        throw Exception('Invalid username or password');
      }

      if (mounted) {
        // Go to tutorial first; tutorial flow will route to fill form
        Navigator.of(context).pushReplacementNamed('/');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: ModernResponsiveLayout(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Disaster-focused header
              _buildDisasterHeader(),
              
              const SizedBox(height: 40),
              
              // Login form
              _buildLoginForm(),
              
              const SizedBox(height: 30),
              
              // Sign up link
              _buildSignUpLink(),
            ],
          ),
        ),
      ),
  );
  }

  Widget _buildDisasterHeader() {
    return Column(
      children: [
        // T.U.L.O.N.G logo with neumorphic design
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
                color: AppColors.white.withOpacity(0.8),
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
        )
            .animate()
            .scale(
              duration: 800.ms,
              curve: Curves.elasticOut,
            ),
        
        const SizedBox(height: 20),
        
        Text(
          'T.U.L.O.N.G',
          style: UnifiedTypography.displayLarge,
        )
            .animate()
            .fadeIn(
              duration: 1000.ms,
              delay: 300.ms,
            )
            .slideY(
              begin: 0.3,
              end: 0,
              duration: 1000.ms,
              delay: 300.ms,
              curve: Curves.easeOutCubic,
            ),
        
        const SizedBox(height: 8),
        
        Text(
          'Disaster-Ready Communication',
          style: UnifiedTypography.buttonLarge,
        )
            .animate()
            .fadeIn(
              duration: 1000.ms,
              delay: 500.ms,
            )
            .slideY(
              begin: 0.3,
              end: 0,
              duration: 1000.ms,
              delay: 500.ms,
              curve: Curves.easeOutCubic,
            ),
      ],
  );
  }

  Widget _buildLoginForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Username field (replaced email)
            _buildModernTextField(
              controller: _usernameController,
              label: 'Username',
              hint: 'Enter your username',
              keyboardType: TextInputType.text,
              prefixIcon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your username';
                }
                return InputValidator.validateUsername(value);
              },
            ),
          
            const SizedBox(height: 20),
            
            // Password field
            _buildModernTextField(
              controller: _passwordController,
              label: 'Password',
              hint: 'Enter your password',
              obscureText: _obscurePassword,
              prefixIcon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
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
          
          const SizedBox(height: 30),
          
          // Sign in button (icon + text)
          GestureDetector(
            onTap: _isLoading ? null : _signIn,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 56,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.primaryRed,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 8)),
                  BoxShadow(color: Color(0x66FFFFFF), blurRadius: 8, offset: Offset(0, -2)),
                ],
              ),
              child: _isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                        ),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.login, color: AppColors.white),
                        SizedBox(width: 10),
                        Text(
                          'Sign In',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          // Quick Sign-In with Fingerprint (only show if there's a last logged in user)
          if (_lastLoggedInUsername != null && _lastLoggedInUsername!.isNotEmpty) ...[
            const SizedBox(height: 20),
            
            // Divider with "OR"
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 1,
                    color: AppColors.lightGray.withOpacity(0.3),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: AppColors.textSecondary.withOpacity(0.6),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 1,
                    color: AppColors.lightGray.withOpacity(0.3),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Quick Sign-In button with fingerprint icon
            GestureDetector(
              onTap: _isQuickSignInLoading ? null : _quickSignInWithBiometric,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 56,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primaryRed.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryRed.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _isQuickSignInLoading
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryRed),
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.fingerprint,
                            color: AppColors.primaryRed,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Quick Sign-In',
                            style: TextStyle(
                              color: AppColors.primaryRed,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpLink() {
    return Row(
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
  );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    IconData? prefixIcon,
    Widget? suffixIcon,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: UnifiedTypography.titleLarge,
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: AppColors.white.withOpacity(0.8),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
            border: Border.all(
              color: AppColors.lightGray.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: AppColors.mediumGray,
                fontSize: 16,
              ),
              prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: AppColors.mediumGray) : null,
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
  );
  }
}
