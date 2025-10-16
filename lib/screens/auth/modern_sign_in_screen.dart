import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../utils/neumorphic_utils.dart';
import '../../widgets/modern_gradient_button.dart';
import '../../widgets/enhanced_neumorphic_card.dart';
import 'sign_up_screen.dart';

class ModernSignInScreen extends StatefulWidget {
  const ModernSignInScreen({super.key});

  @override
  State<ModernSignInScreen> createState() => _ModernSignInScreenState();
}

class _ModernSignInScreenState extends State<ModernSignInScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // Check if user has 2FA enabled
      final requiresTwoFactor =
          await authProvider.checkTwoFactorRequired(email);

      if (requiresTwoFactor) {
        // Navigate to 2FA verification screen
        if (mounted) {
          Navigator.of(context).pushNamed(
            '/two-factor-verification',
            arguments: {
              'email': email,
              'password': password,
              'isRecovery': false,
            },
          );
        }
      } else {
        // Regular sign-in without 2FA
        // Try SQLite first (offline-first approach)
        final offlineSuccess =
            await authProvider.loginOffline(email, password);

        if (offlineSuccess) {
          // Offline login successful - attempt Firebase sync if online
          _attemptFirebaseSync(email, password);
        } else {
          // Try Firebase as backup (online)
          try {
            final firebaseUser = await FirebaseService()
                .signInWithEmail(email: email, password: password);
            if (firebaseUser?.user != null) {
              await authProvider.setAuthenticated(
                  email: email, name: email.split('@')[0]);
            } else {
              throw Exception('Firebase sign-in returned no user');
            }
          } catch (firebaseError) {
            throw Exception('Invalid email or password');
          }
        }

        if (mounted) {
          // Navigate to splash screen to handle tutorial logic
          Navigator.of(context).pushReplacementNamed('/');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    // Don't set loading immediately - let Google UI show
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      print('🔐 Starting Google Sign-In from UI...');
      
      // Call Google sign-in
      await authProvider.signInWithGoogle();

      // Small delay to ensure state updates
      await Future.delayed(const Duration(milliseconds: 200));

      if (mounted) {
        final updatedAuthProvider =
            Provider.of<AuthProvider>(context, listen: false);

        print('✅ Checking auth status: ${updatedAuthProvider.isAuthenticated}');
        print('✅ Current user: ${updatedAuthProvider.currentUser}');

        if (updatedAuthProvider.isAuthenticated &&
            updatedAuthProvider.currentUser != null) {
          // Success! Navigate to home
          print('✅ Navigating to home...');
          Navigator.of(context).pushReplacementNamed('/');
        } else {
          // User cancelled or failed
          print('❌ Google Sign-In cancelled or failed');
          _showErrorSnackbar(
              'Google Sign-In was cancelled. Please try again.');
        }
      }
    } catch (e) {
      print('❌ Google Sign-In exception: ${e.toString()}');
      if (mounted) {
        _showErrorSnackbar('Google Sign-In error: ${e.toString()}');
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neumorphicBase,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),

                    // App Logo with Neumorphic Design
                    _buildLogo(),

                    const SizedBox(height: 32),

                    // Title
                    const Text(
                      'T.U.L.O.N.G',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryRed,
                        letterSpacing: 2.0,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Disaster-Ready Communication',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Login Form Card
                    EnhancedNeumorphicCard(
                      padding: const EdgeInsets.all(24),
                      borderRadius: 24,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // Email Field
                            _buildTextField(
                              controller: _emailController,
                              label: 'Email',
                              hint: 'Enter your email',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!value.contains('@')) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 20),

                            // Password Field
                            _buildTextField(
                              controller: _passwordController,
                              label: 'Password',
                              hint: 'Enter your password',
                              icon: Icons.lock_outline,
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: AppColors.mediumGray,
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

                            const SizedBox(height: 16),

                            // Forgot Password Link
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.of(context)
                                      .pushNamed('/forgot-password');
                                },
                                child: const Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    color: AppColors.primaryRed,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Sign In Button
                            ModernGradientButton(
                              text: 'Sign In',
                              icon: Icons.login,
                              onPressed: _isLoading ? null : _signIn,
                              isLoading: _isLoading,
                              height: 56,
                              borderRadius: 16,
                            ),

                            const SizedBox(height: 20),

                            // Divider
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.centerLeft,
                                        end: Alignment.centerRight,
                                        colors: [
                                          Colors.transparent,
                                          AppColors.mediumGray
                                              .withOpacity(0.3),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'OR',
                                    style: TextStyle(
                                      color: AppColors.mediumGray,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.centerRight,
                                        end: Alignment.centerLeft,
                                        colors: [
                                          Colors.transparent,
                                          AppColors.mediumGray
                                              .withOpacity(0.3),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Google Sign In Button
                            ModernOutlinedButton(
                              text: 'Continue with Google',
                              icon: Icons.g_mobiledata,
                              onPressed: _signInWithGoogle,  // Always enabled
                              borderColor: AppColors.mediumGray,
                              textColor: AppColors.darkGray,
                              height: 56,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Sign Up Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
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
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: NeumorphicUtils.getNeumorphicShadow(depth: 12),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: NeumorphicUtils.getModernGradient(),
          borderRadius: BorderRadius.circular(28),
        ),
        padding: const EdgeInsets.all(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/images/app_logo (3).png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: NeumorphicUtils.getInnerShadow(depth: 2),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.primaryRed),
          suffixIcon: suffixIcon,
          labelStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
          hintStyle: TextStyle(
            color: AppColors.textSecondary.withOpacity(0.5),
            fontWeight: FontWeight.w500,
          ),
          filled: true,
          fillColor: AppColors.neumorphicBase,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: AppColors.primaryRed,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: AppColors.error,
              width: 2,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: AppColors.error,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 20,
          ),
        ),
      ),
    );
  }

  // Attempt Firebase sync in background (non-blocking)
  void _attemptFirebaseSync(String email, String password) async {
    try {
      final firebaseService = FirebaseService();
      final userCredential =
          await firebaseService.signInWithEmail(email: email, password: password);

      if (userCredential?.user != null) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.setAuthenticated(
            email: email, name: email.split('@')[0]);
        await authProvider.markUserAsSynced(email);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Account synced with server'),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white),
                SizedBox(width: 12),
                Text('Using offline mode - will sync when online'),
              ],
            ),
            backgroundColor: AppColors.info,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }
}

