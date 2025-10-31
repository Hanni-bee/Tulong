import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../constants/app_colors.dart';
import '../../constants/unified_typography.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../constants/soft_ui_design.dart';
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
          // After SSO, go to Tutorial first (splash handles next steps)
          print('✅ Google Sign-In successful. Navigating to tutorial (/) ...');
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
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return GestureDetector(
      onTap: _signInWithGoogle,
      child: Container(
          height: 50,
          decoration: SoftUIDesign.cardDecoration(
            backgroundColor: Colors.white,
            borderRadius: SoftUIDesign.buttonBorderRadius,
            elevation: 2.0,
            borderColor: AppColors.lightGray.withOpacity(0.3),
            showBorder: true,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Google Logo - Local SVG for offline support
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFDADCE0), width: 0.5),
                ),
                child: SvgPicture.string(
                  '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/><path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/><path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/><path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/></svg>',
                  width: 20,
                  height: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Continue with Google',
                style: TextStyle(
                  color: Color(0xFF3C4043),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
      ),
    );
  }

  Widget _buildEmailSignInButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _signIn,
      child: Container(
        height: 50,
        decoration: SoftUIDesign.buttonDecoration(
          backgroundColor: AppColors.primaryRed,
          borderRadius: SoftUIDesign.buttonBorderRadius,
          shadowColor: AppColors.primaryRed,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.login,
              size: 22,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            if (_isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white,
                  ),
                ),
              )
            else
              const Text(
                'Sign In',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Subtle background overlay
          SoftUIDesign.buildScreenBackgroundOverlay(
            accentColor: AppColors.primaryRed,
            intensity: 0.01,
          ),
          
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 20),

                      // App Logo with Neumorphic Design
                      _buildLogo(),

                      const SizedBox(height: 20),

                      // Title
                      Text(
                        'T.U.L.O.N.G',
                        style: UnifiedTypography.displayLarge.copyWith(
                          color: AppColors.primary,
                          letterSpacing: 2.0,
                          fontSize: 32,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'Disaster-Ready Communication',
                        style: UnifiedTypography.bodyLarge.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Login Form Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: SoftUIDesign.cardDecoration(
                          backgroundColor: AppColors.white,
                          borderRadius: SoftUIDesign.cardBorderRadius,
                          elevation: 4.0,
                          borderColor: AppColors.lightGray.withOpacity(0.3),
                          showBorder: true,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
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

                              const SizedBox(height: 16),

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

                              const SizedBox(height: 12),

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
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Sign In Button
                              _buildEmailSignInButton(),

                              const SizedBox(height: 16),

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
                                    padding: EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(
                                      'OR',
                                      style: TextStyle(
                                        color: AppColors.mediumGray,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
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

                              const SizedBox(height: 16),

                              // Google Sign In Button
                              _buildGoogleSignInButton(),
                            ],
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Sign Up Link - Always visible at bottom
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom > 0
                              ? 16
                              : 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account? ",
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
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
                                  color: AppColors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 100,
      height: 100,
      decoration: SoftUIDesign.cardDecoration(
        backgroundColor: AppColors.white,
        borderRadius: 28,
        elevation: 6.0,
        borderColor: AppColors.primaryRed.withOpacity(0.2),
        showBorder: true,
      ),
      padding: const EdgeInsets.all(18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          'assets/images/app_logo (3).png',
          fit: BoxFit.contain,
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
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: UnifiedTypography.formInput,
      decoration: SoftUIDesign.inputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primaryRed),
        suffixIcon: suffixIcon,
        isFocused: false,
        hasError: false,
      ).copyWith(
        labelStyle: UnifiedTypography.formLabel.copyWith(
          color: AppColors.textSecondary,
        ),
        hintStyle: UnifiedTypography.formHint.copyWith(
          color: AppColors.textSecondary.withOpacity(0.5),
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
                  Icon(Icons.wifi_off, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Using offline mode - will sync when online'),
                  ),
                ],
              ),
              backgroundColor: AppColors.info,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 3),
            ),
          );
        }
    }
  }
}

