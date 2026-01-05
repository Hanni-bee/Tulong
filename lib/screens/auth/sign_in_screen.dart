import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../constants/app_colors.dart';
// import removed
import '../../providers/auth_provider.dart';
import '../../widgets/modern_responsive_layout.dart';
import 'sign_up_screen.dart';
import '../../services/firebase_service.dart';
import '../../services/offline_auth_service.dart';
import '../constants/unified_typography.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
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
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      try {
        // Try Firebase first (online)
        final firebaseUser = await FirebaseService().signInWithEmail(email: email, password: password);
        if (firebaseUser?.user != null) {
          await authProvider.setAuthenticated(email: email, name: email.split('@')[0]);
        } else {
          throw Exception('Firebase sign-in returned no user');
        }
      } catch (_) {
        // Fallback to offline SQLite
        final user = await OfflineAuthService().signInOffline(email: email, password: password);
        await authProvider.setAuthenticated(email: email, name: user['first_name'] != null ? '${user['first_name']} ${user['last_name']}' : email.split('@')[0]);
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

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signInWithGoogle();

      if (mounted) {
        // Go to tutorial first; tutorial flow will route to fill form
        Navigator.of(context).pushReplacementNamed('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign In failed: ${e.toString()}'),
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
        
        const Text(
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
        
        const Text(
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
            // Email field
            _buildModernTextField(
              controller: _emailController,
              label: 'Email',
              hint: 'Enter your email',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.email_outlined,
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
              child: const Row(
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
          
          const SizedBox(height: 20),
          
          // Google sign in button (simplified)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _signInWithGoogle,
              icon: const Icon(Icons.g_mobiledata, size: 24, color: AppColors.textPrimary),
              label: const Text(
                'Continue with Google',
                style: UnifiedTypography.titleLarge,
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.borderColor, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                backgroundColor: Colors.white,
              ),
            ),
          ),
        ],
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
          style: const UnifiedTypography.titleLarge,
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
