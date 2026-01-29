import '../../utils/enhanced_error_handler.dart';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble, ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../constants/app_colors.dart';
import '../../constants/unified_typography.dart';
import '../../providers/auth_provider.dart';
import '../../services/biometric_service.dart';
import '../../services/sqlite_service.dart';
import '../../utils/input_validator.dart';
import 'package:tulong_app/utils/haptic_helper.dart';

import '../../widgets/enhanced_text_field.dart';
import 'package:tulong_app/widgets/smart_loader.dart';

class ModernSignInScreen extends StatefulWidget {
  const ModernSignInScreen({super.key});

  @override
  State<ModernSignInScreen> createState() => _ModernSignInScreenState();
}

class _ModernSignInScreenState extends State<ModernSignInScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Logic & State
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  // Animation Controllers
  late AnimationController _entranceController;
  late AnimationController _keyboardController;
  late Animation<double> _headerScaleAnim;
  late Animation<double> _headerSlideAnim;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  // State Variables
  bool _isLoading = false;
  bool _isKeyboardVisible = false;
  bool _isQuickSignInLoading = false;
  String? _lastLoggedInUsername;
  final BiometricService _biometricService = BiometricService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 1. Entrance Animation
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    // 2. Keyboard/Sheet Animation (Snappier 250ms)
    _keyboardController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _headerScaleAnim = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _keyboardController, curve: Curves.easeInOut),
    );
    _headerSlideAnim = Tween<double>(begin: 0.0, end: -40.0).animate(
      CurvedAnimation(parent: _keyboardController, curve: Curves.easeInOut),
    );

    // 3. Error Shake
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shakeAnim = CurvedAnimation(
        parent: _shakeController, curve: Curves.easeInOutCubic);

    // Listeners
    _usernameFocusNode.addListener(_onFocusChange);
    _passwordFocusNode.addListener(_onFocusChange);

    _loadLastLoggedInUser();
  }

  // --- Backend Logic Preservation ---

  Future<void> _loadLastLoggedInUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var username = prefs.getString('session_username') ??
          prefs.getString('session_email');

      if (username == null || username.isEmpty) {
        final sqliteService = SQLiteService();
        final db = await sqliteService.database;
        final result = await db.query(
          'users',
          columns: ['username', 'last_seen'],
          where: 'last_seen IS NOT NULL',
          orderBy: 'last_seen DESC',
          limit: 1,
        );

        if (result.isNotEmpty) {
          username = result.first['username']?.toString();
        }
      }

      if (username != null && username.isNotEmpty) {
        setState(() {
          _lastLoggedInUsername = username;
        });
      }
    } catch (e) {
      debugPrint('Error loading last user: $e');
    }
  }

  Future<void> _quickSignInWithBiometric() async {
    if (_lastLoggedInUsername == null || _lastLoggedInUsername!.isEmpty) {
      EnhancedErrorHandler.showError(
        context,
        AppError(
          category: ErrorCategory.authentication,
          severity: ErrorSeverity.medium,
          userMessage: 'No previous login found. Please sign in manually.',
          canRetry: false,
        ),
      );
      return;
    }

    HapticHelper.medium();
    setState(() => _isQuickSignInLoading = true);

    try {
      final isSupported = await _biometricService.isDeviceSupported();
      if (!isSupported) {
        throw Exception('Device does not support biometric authentication');
      }

      final hasBiometrics = await _biometricService.hasEnrolledBiometrics();
      if (!hasBiometrics) {
        throw Exception('No fingerprint enrolled. Please check settings.');
      }

      final didAuthenticate = await _biometricService.authenticate(
        reason: 'Quick sign in',
        useErrorDialogs: true,
        stickyAuth: true,
      );

      if (didAuthenticate) {
        HapticHelper.success();
        final sqliteService = SQLiteService();
        final user =
            await sqliteService.getUserByUsername(_lastLoggedInUsername!);

        if (user == null) throw Exception('User not found locally');

        // Update local stats
        await sqliteService.updateUser(user['id'], {
          'last_seen': DateTime.now().millisecondsSinceEpoch,
          'is_online': 1,
        });

        // Set auth session
        if (!mounted) return;
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.setAuthenticated(
          email: _lastLoggedInUsername!,
          name: user['first_name'] != null
              ? '${user['first_name']} ${user['last_name']}'
              : _lastLoggedInUsername!,
        );

        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) await _navigateToHome();
      } else {
        throw Exception('Authentication cancelled');
      }
    } catch (e) {
      if (!mounted) return;
      EnhancedErrorHandler.showError(
        context,
        AppError.fromException(e, category: ErrorCategory.authentication),
        onRetry: _quickSignInWithBiometric,
      );
    } finally {
      if (mounted) setState(() => _isQuickSignInLoading = false);
    }
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      _doShake();
      HapticHelper.error();
      return;
    }

    HapticHelper.medium();
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final username = _usernameController.text.trim();
      final password = _passwordController.text;

      // 1. Try Offline Login
      final offlineSuccess =
          await authProvider.loginOffline(username, password);

      if (offlineSuccess) {
        HapticHelper.success();
        await Future.delayed(const Duration(milliseconds: 300));
      } else {
        // Firebase login removed (offline-only backend).
          throw Exception('Invalid username or password');
      }

      if (mounted) await _navigateToHome();
    } catch (e) {
      _doShake();
      HapticHelper.error();
      if (mounted) {
        EnhancedErrorHandler.showError(
          context,
          AppError.fromException(e, category: ErrorCategory.authentication),
          onRetry: _signIn,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Firebase sync removed (offline-only backend)

  // --- UI Logic ---

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final isVisible = bottom > 0.0;
    if (isVisible != _isKeyboardVisible) {
      setState(() => _isKeyboardVisible = isVisible);
      if (isVisible) {
        _keyboardController.forward();
      } else {
        _keyboardController.reverse();
      }
    }
  }

  void _onFocusChange() {
    final hasFocus = _usernameFocusNode.hasFocus || _passwordFocusNode.hasFocus;
    if (hasFocus && !_isKeyboardVisible) {
      _keyboardController.forward();
    } else if (!hasFocus && !_isKeyboardVisible) {
      _keyboardController.reverse();
    }
  }

  void _doShake() {
    _shakeController
        .forward(from: 0)
        .whenComplete(() => _shakeController.value = 0);
  }

  Future<void> _navigateToHome() async {
    // Preserve current app flow: go through home ('/') which leads into the splash/main routing.
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    _entranceController.dispose();
    _keyboardController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // --- Widget Building ---

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    
    // Responsive breakpoints
    final h = media.size.height;
    final isSmall = h < 700;
    
    // Dynamic layout values
    final double headerHeight = isSmall ? 180 : 260;
    final double pillHeight = 80;
    
    // Calculate sheet position
    final double normalTop = h * (isSmall ? 0.28 : 0.32);
    final double keyboardTop = media.padding.top + pillHeight + 16.0; 
    
    return Scaffold(
      backgroundColor: AppColors.primaryRed,
      resizeToAvoidBottomInset: false, 
      body: Stack(
        children: [
          // 1. Liquid Background
          const _LiquidBackground(),

          // 2. Animated Header
          AnimatedBuilder(
            animation: _keyboardController,
            builder: (context, _) {
              return Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: headerHeight,
                child: Transform.translate(
                  offset: Offset(0, _headerSlideAnim.value),
                  child: Transform.scale(
                    scale: _headerScaleAnim.value,
                    alignment: Alignment.topCenter,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          alignment: Alignment.topCenter,
                          children: <Widget>[
                            ...previousChildren,
                            if (currentChild != null) currentChild,
                          ],
                        );
                      },
                      transitionBuilder: (child, anim) {
                        final isPill = child.key == const ValueKey('pill');
                        return FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: Offset(0, isPill ? -0.2 : 0.2),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 0.8, end: 1.0).animate(anim),
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: _isKeyboardVisible
                          ? const _PillHeader(key: ValueKey('pill'))
                          : const _TallHeader(key: ValueKey('tall')),
                    ),
                  ),
                ),
              );
            },
          ),

          // 3. Form Sheet with Glassmorphism
          AnimatedBuilder(
            animation: _keyboardController,
            builder: (context, child) {
              final currentTop = lerpDouble(normalTop, keyboardTop, _keyboardController.value)!;
              return Positioned(
                top: currentTop,
                left: 0,
                right: 0,
                bottom: 0,
                child: child!,
              );
            },
            child: _Shake(
              anim: _shakeAnim,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha((0.9 * 255).round()),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                      border: Border.all(color: Colors.white.withAlpha((0.2 * 255).round()), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((0.1 * 255).round()),
                          blurRadius: 40,
                          offset: const Offset(0, -10),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(24, 32, 24, bottomInset + 32),
                      physics: const BouncingScrollPhysics(),
                      child: Form(
                        key: _formKey,
                        child: _buildFormContent(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fade(duration: 800.ms);
  }

  Widget _buildFormContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Welcome Text with Shimmer Entrance
        Column(
          children: [
            Text(
              'Welcome Back',
              textAlign: TextAlign.center,
              style: UnifiedTypography.headlineLarge.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to continue to T.U.L.O.N.G',
              textAlign: TextAlign.center,
              style: UnifiedTypography.bodyLarge.copyWith(
                color: AppColors.textSecondary.withAlpha((0.7 * 255).round()),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ).animate().fade(duration: 600.ms).slideY(begin: 0.2, end: 0, curve: Curves.easeOutBack),
        
        const SizedBox(height: 32),

        // Form Fields with Staggered Entrance
        ...[
          // Username
          EnhancedTextField(
            controller: _usernameController,
            focusNode: _usernameFocusNode,
            label: 'Username',
            hint: 'Enter your username',
            prefixIcon: Icons.person_outline,
            textInputAction: TextInputAction.next,
            validator: InputValidator.validateUsername,
          ),
          
          const SizedBox(height: 20),

          // Password
          EnhancedTextField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            label: 'Password',
            hint: 'Enter your password',
            prefixIcon: Icons.lock_outline,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _signIn(),
            validator: (v) => (v?.length ?? 0) < 6 ? 'Password must be 6+ chars' : null,
          ),

          // Forgot Password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                HapticHelper.light();
                Navigator.pushNamed(context, '/forgot-password');
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.primaryRed),
              child: Text(
                'Forgot Password?',
                style: UnifiedTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ].animate(interval: 100.ms).fade(duration: 500.ms).slideX(begin: -0.05, end: 0, curve: Curves.easeOutBack),
        
        const SizedBox(height: 12),

        // Primary Button with Pulse and Scale
        _buildPrimaryButton()
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .shimmer(delay: 2.seconds, duration: 1500.ms, color: Colors.white.withAlpha((0.2 * 255).round()))
          .animate()
          .scale(delay: 600.ms, curve: Curves.easeOutBack, duration: 600.ms),
        
        const SizedBox(height: 24),

        // Quick Sign In / Biometric (if available)
        if (_lastLoggedInUsername != null)
          _buildQuickSignInButton()
            .animate().fade(delay: 700.ms).slideY(begin: 0.2, end: 0),

        const SizedBox(height: 48),

        // Footer Link
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Don't have an account? ",
              style: UnifiedTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            GestureDetector(
              onTap: () {
                HapticHelper.medium();
                Navigator.pushNamed(context, '/signup');
              },
              child: Text(
                'Create Account',
                style: UnifiedTypography.bodyMedium.copyWith(
                  color: AppColors.primaryRed,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ).animate().fade(delay: 1.seconds),
      ],
    );
  }

  Widget _buildPrimaryButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryRed,
          foregroundColor: Colors.white,
          elevation: _isLoading ? 0 : 8,
          shadowColor: AppColors.primaryRed.withAlpha((0.4 * 255).round()),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SmartLoader.inline(color: Colors.white)
            : Text(
                'Sign In',
                style: UnifiedTypography.buttonLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
      ),
    );
  }

  Widget _buildQuickSignInButton() {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: _isQuickSignInLoading ? null : _quickSignInWithBiometric,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryRed,
          side: const BorderSide(color: AppColors.primaryRed, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isQuickSignInLoading)
              const SmartLoader.inline(color: AppColors.primaryRed)
            else ...[
              Text(
                'Quick Sign In',
                style: UnifiedTypography.buttonLarge.copyWith(
                  color: AppColors.primaryRed,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.fingerprint, size: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _TallHeader extends StatelessWidget {
  const _TallHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Breathing Logo
          Container(
            width: 90,
            height: 90,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.2 * 255).round()),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Image.asset('assets/images/app_logo (3).png'),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
           .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 2.seconds, curve: Curves.easeInOut),
          
          const SizedBox(height: 20),
          
          Text(
            'T.U.L.O.N.G',
            style: UnifiedTypography.displaySmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ).animate().shimmer(duration: 3.seconds, color: Colors.white.withAlpha((0.3 * 255).round())),
          
          const SizedBox(height: 4),
          
          Text(
            'OFFLINE EMERGENCY NETWORK',
            style: UnifiedTypography.labelSmall.copyWith(
              color: Colors.white.withAlpha((0.7 * 255).round()),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillHeader extends StatelessWidget {
  const _PillHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((0.9 * 255).round()),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: Colors.white.withAlpha((0.3 * 255).round()), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.1 * 255).round()),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withAlpha((0.1 * 255).round()),
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset('assets/images/app_logo (3).png', height: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'T.U.L.O.N.G',
                    style: UnifiedTypography.titleMedium.copyWith(
                      color: AppColors.primaryRed,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidBackground extends StatelessWidget {
  const _LiquidBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base Gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primaryDark,
              ],
            ),
          ),
        ),
        
        // Animated Orbs for Depth
        // Top Right Orb
        Positioned(
          top: -100,
          right: -50,
          child: _Orb(color: Colors.white.withAlpha((0.12 * 255).round()), size: 400),
        ).animate(onPlay: (c) => c.repeat(reverse: true))
         .moveY(begin: 0, end: 50, duration: 6.seconds, curve: Curves.easeInOut)
         .moveX(begin: 0, end: -30, duration: 4.seconds, curve: Curves.easeInOut),

        // Bottom Left Orb
        Positioned(
          bottom: 50,
          left: -100,
          child: _Orb(color: Colors.white.withAlpha((0.08 * 255).round()), size: 350),
        ).animate(onPlay: (c) => c.repeat(reverse: true))
         .moveY(begin: 0, end: -40, duration: 5.seconds, curve: Curves.easeInOut)
         .moveX(begin: 0, end: 60, duration: 7.seconds, curve: Curves.easeInOut),

        // Center Floating Orb (Small & Fast)
        Positioned(
          top: 200,
          left: 50,
          child: _Orb(color: Colors.white.withAlpha((0.05 * 255).round()), size: 150),
        ).animate(onPlay: (c) => c.repeat(reverse: true))
         .moveY(begin: 0, end: 100, duration: 3.seconds, curve: Curves.easeInOut),
        
        // Backdrop Blur for the orbs to feel soft
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(color: Colors.transparent),
          ),
        ),
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  const _Orb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _Shake extends StatelessWidget {
  const _Shake({required this.anim, required this.child});
  final Animation<double> anim;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        final dx = math.sin(anim.value * math.pi * 4) * 8;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}
