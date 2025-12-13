import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

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
import '../enhanced_splash_screen.dart';
import '../interactive_tutorial_screen.dart';
import '../main_navigation.dart';

class ModernSignInScreen extends StatefulWidget {
  const ModernSignInScreen({super.key});

  @override
  State<ModernSignInScreen> createState() => _ModernSignInScreenState();
}

class _ModernSignInScreenState extends State<ModernSignInScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;


  // Keyboard + sheet motion
  late AnimationController _keyboardAnimationController;
  late Animation<double> _formTopPct; // 0.35 -> 0.05
  late Animation<double> _headerOpacityAnimation; // 1..0.65

  // Shake for errors
  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isKeyboardVisible = false;

  // Material 3 motion curves
  static const kEmphasized = Curves.easeInOutCubicEmphasized;
  static const kEnter = Curves.easeOutCubic;
  static const kExit = Curves.easeInCubic;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: kEnter),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, .3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: kEnter));


    _keyboardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _formTopPct = Tween<double>(begin: 0.35, end: 0.05).animate(
      CurvedAnimation(
        parent: _keyboardAnimationController,
        curve: Curves.easeInOutCubicEmphasized,
      ),
    );

    _headerOpacityAnimation =
        Tween<double>(begin: 1.0, end: 0.7).animate(CurvedAnimation(
      parent: _keyboardAnimationController,
      curve: const Interval(0.0, 0.85, curve: Curves.easeInOutCubic),
    ));

    _emailFocusNode.addListener(_onFocusChange);
    _passwordFocusNode.addListener(_onFocusChange);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _shakeAnim = CurvedAnimation(parent: _shakeController, curve: Curves.easeOutCubic);
  }

  // Reliable keyboard detection
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    if (!mounted) return;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final visible = bottomInset > 0.0;
    if (visible != _isKeyboardVisible) {
      setState(() => _isKeyboardVisible = visible);
      if (visible) {
        _keyboardAnimationController.forward();
      } else {
        _keyboardAnimationController.reverse();
      }
    }
  }

  void _onFocusChange() {
    final hasFocus = _emailFocusNode.hasFocus || _passwordFocusNode.hasFocus;
    if (hasFocus) {
      if (!_keyboardAnimationController.isAnimating ||
          _keyboardAnimationController.value < 1.0) {
        _keyboardAnimationController.forward();
      }
    } else if (!_isKeyboardVisible) {
      if (!_keyboardAnimationController.isAnimating ||
          _keyboardAnimationController.value > 0.0) {
        _keyboardAnimationController.reverse();
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.removeListener(_onFocusChange);
    _passwordFocusNode.removeListener(_onFocusChange);
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _keyboardAnimationController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    // validate; shake if not valid
    if (!_formKey.currentState!.validate()) {
      _doShake();
      HapticFeedback.lightImpact();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      final requiresTwoFactor =
          await authProvider.checkTwoFactorRequired(email);

      if (requiresTwoFactor) {
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
        // Offline-first login
        final offlineSuccess =
            await authProvider.loginOffline(email, password);

        if (offlineSuccess) {
          // Small delay to ensure data is loaded before navigating
          await Future.delayed(const Duration(milliseconds: 300));
          _attemptFirebaseSync(email, password);
        } else {
          try {
            final firebaseUser = await FirebaseService()
                .signInWithEmail(email: email, password: password);
            if (firebaseUser?.user != null) {
              await authProvider.setAuthenticated(
                email: email,
                name: email.split('@')[0],
              );
              // Small delay to ensure user model is loaded
              await Future.delayed(const Duration(milliseconds: 300));
            } else {
              throw Exception('Invalid email or password');
            }
          } catch (_) {
            throw Exception('Invalid email or password');
          }
        }

        if (mounted) {
          await _playRouteFadeAndNavigate('/');
        }
      }
    } catch (e) {
      _doShake();
      if (mounted) _showErrorSnackbar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _doShake() {
    if (_shakeController.isAnimating) return;
    _shakeController.forward(from: 0).whenComplete(() => _shakeController.value = 0);
  }

  Future<void> _signInWithGoogle() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signInWithGoogle();
      await Future.delayed(const Duration(milliseconds: 200));

      if (!mounted) return;
      final updated = Provider.of<AuthProvider>(context, listen: false);

      if (updated.isAuthenticated && updated.currentUser != null) {
        await _playRouteFadeAndNavigate('/');
      } else {
        _showErrorSnackbar('Google Sign-In was cancelled. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Google Sign-In error: ${e.toString()}');
      }
    }
  }

  void _showErrorSnackbar(String message) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final truncatedMessage = message.length > 100 
        ? '${message.substring(0, 97)}...' 
        : message;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                truncatedMessage,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                if (message.contains('email') || message.contains('password')) {
                  _signIn();
                } else if (message.contains('Google')) {
                  _signInWithGoogle();
                }
              },
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: keyboardInset > 0 ? keyboardInset + 16 : 16,
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _buildGoogleSignInButton(double height) {
    final textSize = (height * 0.4).clamp(14.0, 18.0); // Scale text with button height
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isGoogleLoading ? null : _signInWithGoogle,
          borderRadius: BorderRadius.circular(SoftUIDesign.buttonBorderRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isGoogleLoading
                    ? [
                        AppColors.white.withOpacity(0.7),
                        AppColors.white.withOpacity(0.65),
                      ]
                    : [
                        AppColors.white,
                        AppColors.white.withOpacity(0.95),
                      ],
              ),
              borderRadius: BorderRadius.circular(SoftUIDesign.buttonBorderRadius),
              border: Border.all(
                color: _isGoogleLoading
                    ? const Color(0xFFE0E3E7).withOpacity(0.5)
                    : const Color(0xFFE0E3E7),
                width: 1.5,
              ),
              boxShadow: _isGoogleLoading
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                        spreadRadius: 0,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.5),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                        spreadRadius: 0,
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isGoogleLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1F1F1F)),
                    ),
                  )
                else
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: AppColors.white,
                      border: Border.all(color: const Color(0xFFDADCE0), width: 0.5),
                    ),
                    child: SvgPicture.string(
                      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/><path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/><path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/><path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/></svg>',
                      width: 20,
                      height: 20,
                    ),
                  ),
                const SizedBox(width: 12),
                Text(
                  _isGoogleLoading ? 'Signing in...' : 'Continue with Google',
                  style: UnifiedTypography.buttonMedium.copyWith(
                    color: const Color(0xFF1F1F1F), // Darker for better contrast (WCAG AA)
                    fontSize: textSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailSignInButton(double height) {
    final textSize = (height * 0.4).clamp(14.0, 18.0); // Scale text with button height
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : () {
            HapticFeedback.mediumImpact();
            _signIn();
          },
          borderRadius: BorderRadius.circular(SoftUIDesign.buttonBorderRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isLoading
                    ? [
                        const Color(0xFFFF3B3B).withOpacity(0.6),
                        const Color(0xFFD90E0E).withOpacity(0.6),
                      ]
                    : [
                        const Color(0xFFFF3B3B),
                        const Color(0xFFD90E0E),
                      ],
              ),
              borderRadius: BorderRadius.circular(SoftUIDesign.buttonBorderRadius),
              boxShadow: _isLoading
                  ? [
                      // Keep subtle shadow in loading state
                      BoxShadow(
                        color: const Color(0xFFFF3B3B).withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                        spreadRadius: 0,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: const Color(0xFFFF3B3B).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                        spreadRadius: 0,
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  Icon(Icons.login, color: Colors.white, size: textSize * 1.2),
                const SizedBox(width: 12),
                Text(
                  _isLoading ? 'Signing In...' : 'Sign In',
                  style: UnifiedTypography.buttonLarge.copyWith(
                    color: Colors.white,
                    fontSize: textSize,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppColors.primaryRed,
      // We control the movement; prevents double layout shifts
      resizeToAvoidBottomInset: false,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFF3B3B), Color(0xFFD90E0E)],
              ),
            ),
            child: Stack(
              children: [
                const _DecorCircles(),

                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final totalHeight = constraints.maxHeight;
                      // Simplified breakpoints: small < 700, medium < 900, large >= 900
                      final isSmall = totalHeight < 700;
                      final isMedium = totalHeight < 900;
                      
                      // Spacing helper using 8px base scale (8, 16, 24, 32)
                      double spacing(double small, double medium, double large) {
                        return isSmall ? small : (isMedium ? medium : large);
                      }

                      final logoSize = spacing(75.0, 85.0, 90.0);
                      final headerBottomPad = spacing(24.0, 32.0, 48.0);
                      final titleSize = spacing(22.0, 24.0, 28.0);
                      final subtitleSize = spacing(13.0, 14.0, 16.0);
                      final verticalGap = spacing(8.0, 12.0, 16.0);
                      final controlHeight = spacing(44.0, 46.0, 48.0);

                      return Stack(
                        children: [
                          // Header area (Tall <-> Pill)
                          Positioned.fill(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AnimatedBuilder(
                                  animation: _keyboardAnimationController,
                                  builder: (context, _) {
                                    final progress = _keyboardAnimationController.value;
                                    final opacity = _headerOpacityAnimation.value;
                                    
                                    // Smooth compression calculation
                                    final compress = 1.0 - ((opacity - 0.7) / 0.3).clamp(0.0, 1.0);
                                    
                                    // Smoother scale transition
                                    final scale = 1.0 - (compress * 0.3);
                                    
                                    // Smoother vertical translation
                                    final translateY = -20.0 * compress * (1 - progress * 0.3);

                                    return Opacity(
                                      opacity: opacity.clamp(0.7, 1.0),
                                      child: Transform.scale(
                                        scale: scale.clamp(0.7, 1.0),
                                        alignment: Alignment.topCenter,
                                        child: Transform.translate(
                                          offset: Offset(0, translateY),
                                          child: AnimatedSwitcher(
                                            duration: const Duration(milliseconds: 400),
                                            reverseDuration: const Duration(milliseconds: 350),
                                            switchInCurve: Curves.easeOutCubic,
                                            switchOutCurve: Curves.easeInCubic,
                                            transitionBuilder: (child, anim) {
                                              return FadeTransition(
                                                opacity: CurvedAnimation(
                                                  parent: anim,
                                                  curve: Curves.easeInOut,
                                                ),
                                                child: ScaleTransition(
                                                  scale: CurvedAnimation(
                                                    parent: anim,
                                                    curve: Interval(0.0, 1.0, curve: Curves.easeOutBack),
                                                  ),
                                                  alignment: Alignment.topCenter,
                                                  child: child,
                                                ),
                                              );
                                            },
                                            child: _isKeyboardVisible
                                                ? _PillHeader(
                                                    key: const ValueKey('pill'),
                                                    logoSize: logoSize * 0.9,
                                                    titleSize: titleSize * 0.85,
                                                    subtitleSize: subtitleSize * 0.75,
                                                  )
                                                : _TallHeader(
                                                    key: const ValueKey('tall'),
                                                    logoSize: logoSize,
                                                    titleSize: titleSize,
                                                    subtitleSize: subtitleSize,
                                                    bottomPadding: headerBottomPad,
                                                    gap: verticalGap,
                                                  ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const Spacer(),
                              ],
                            ),
                          ),

                          // ==== WHITE SHEET — sits below the red header (with fixed clearance when KB up) ====
                          AnimatedBuilder(
                            animation: _keyboardAnimationController,
                            builder: (context, _) {
                              final media = MediaQuery.of(context);
                              final h = media.size.height;
                              final liftT = _keyboardAnimationController.value;

                              // how high the sheet would normally be (35% -> 5%)
                              final animatedTop = h * _formTopPct.value;

                              // when keyboard is visible, keep some red header visible above the sheet:
                              // safe area + pill height + breathing space.
                              const double kPillVisualHeight = 72.0; // approx height of pill header
                              const double kTopBreathing = 20.0;      // breathing space above the sheet
                              final double minTopWhenKeyboard =
                                  media.padding.top + kPillVisualHeight + kTopBreathing;

                              // choose top based on state: ensure minimum breathing space when keyboard is visible
                              final double targetTop = _isKeyboardVisible
                                  ? math.max(animatedTop, minTopWhenKeyboard)
                                  : animatedTop;

                              return AnimatedPositioned(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOutCubicEmphasized,
                                top: targetTop,
                                left: 0,
                                right: 0,
                                // keep it floating above the keyboard; no red strip at the bottom.
                                bottom: keyboardInset,
                                child: _Shake(
                                  anim: _shakeAnim,
                                  child: Material(
                                    elevation: lerpDouble(2, 6, liftT)!,
                                    color: AppColors.white,
                                    clipBehavior: Clip.antiAlias,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(
                                          lerpDouble(40, 25, liftT)!,
                                        ),
                                      ),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: lerpDouble(28, 18, liftT)!,
                                      ),
                                      child: SingleChildScrollView(
                                        physics: const AlwaysScrollableScrollPhysics(),
                                        keyboardDismissBehavior:
                                            ScrollViewKeyboardDismissBehavior.onDrag,
                                        padding: EdgeInsets.only(
                                          bottom: keyboardInset + 20,
                                        ),
                                        child: Form(
                                          key: _formKey,
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Text(
                                                'Welcome Back',
                                                textAlign: TextAlign.center,
                                                style: UnifiedTypography.headlineLarge
                                                    .copyWith(
                                                  fontSize: spacing(22.0, 24.0, 26.0),
                                                  color: AppColors.textPrimary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              SizedBox(height: spacing(8.0, 10.0, 12.0)),
                                              Text(
                                                'Sign in to continue',
                                                textAlign: TextAlign.center,
                                                style:
                                                    UnifiedTypography.bodyMedium.copyWith(
                                                  fontSize: spacing(15.0, 15.0, 16.0),
                                                  color: AppColors.textSecondary,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              SizedBox(height: spacing(16.0, 18.0, 20.0)),

                                              // Email — Autofill + suggestions
                                              _buildTextField(
                                                controller: _emailController,
                                                focusNode: _emailFocusNode,
                                                label: 'Email Address',
                                                hint: 'Enter your email',
                                                icon: Icons.email_outlined,
                                                keyboardType: TextInputType.emailAddress,
                                                autofillHints: const [
                                                  AutofillHints.username,
                                                  AutofillHints.email
                                                ],
                                                enableSuggestions: true,
                                                autocorrect: false,
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
                                              SizedBox(height: spacing(16.0, 18.0, 20.0)),

                                              // Password — press & hold to peek + autofill
                                              _buildTextField(
                                                controller: _passwordController,
                                                focusNode: _passwordFocusNode,
                                                label: 'Password',
                                                hint: 'Enter your password',
                                                icon: Icons.lock_outline,
                                                obscureText: _obscurePassword,
                                                autofillHints: const [
                                                  AutofillHints.password
                                                ],
                                                enableSuggestions: false,
                                                autocorrect: false,
                                                // press & hold to peek
                                                suffixIcon: Tooltip(
                                                  message: 'Tap to toggle, long-press to peek',
                                                  child: Semantics(
                                                    label: _obscurePassword 
                                                        ? 'Show password' 
                                                        : 'Hide password',
                                                    hint: 'Long press to temporarily reveal password',
                                                    child: GestureDetector(
                                                      onTap: () {
                                                        HapticFeedback.lightImpact();
                                                        setState(() {
                                                          _obscurePassword = !_obscurePassword;
                                                        });
                                                      },
                                                      onLongPressStart: (_) => setState(
                                                          () => _obscurePassword = false),
                                                      onLongPressEnd: (_) => setState(
                                                          () => _obscurePassword = true),
                                                      child: AnimatedSwitcher(
                                                        duration: const Duration(milliseconds: 300),
                                                        transitionBuilder: (child, animation) {
                                                          return ScaleTransition(
                                                            scale: animation,
                                                            child: RotationTransition(
                                                              turns: Tween<double>(begin: 0.0, end: 0.5).animate(animation),
                                                              child: FadeTransition(
                                                                opacity: animation,
                                                                child: child,
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                        child: Icon(
                                                          _obscurePassword
                                                              ? Icons.visibility_off_outlined
                                                              : Icons.visibility_outlined,
                                                          key: ValueKey(_obscurePassword),
                                                          color: AppColors.mediumGray,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
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

                                              SizedBox(height: spacing(8.0, 10.0, 12.0)),

                                              Align(
                                                alignment: Alignment.centerRight,
                                                child: TextButton(
                                                  onPressed: () {
                                                    HapticFeedback.lightImpact();
                                                    Navigator.of(context)
                                                        .pushNamed('/forgot-password');
                                                  },
                                                  style: TextButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                            horizontal: 12, vertical: 8),
                                                    minimumSize: const Size(44, 44),
                                                    tapTargetSize:
                                                        MaterialTapTargetSize.shrinkWrap,
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        'Forgot Password?',
                                                        style: UnifiedTypography.labelMedium
                                                            .copyWith(
                                                          color: AppColors.primaryRed,
                                                          fontWeight: FontWeight.w700,
                                                          fontSize: 14,
                                                          decoration: TextDecoration.underline,
                                                          decorationColor: AppColors.primaryRed.withOpacity(0.5),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Icon(
                                                        Icons.arrow_forward_ios,
                                                        size: 12,
                                                        color: AppColors.primaryRed,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              SizedBox(height: spacing(16.0, 18.0, 20.0)),

                                              _buildEmailSignInButton(controlHeight),

                                              SizedBox(height: spacing(12.0, 14.0, 16.0)),

                                              Center(
                                                child: TextButton(
                                                  onPressed: () {
                                                    HapticFeedback.selectionClick();
                                                    Navigator.of(context).push(
                                                      PageRouteBuilder(
                                                        pageBuilder: (context, animation,
                                                                secondaryAnimation) =>
                                                            const SignUpScreen(),
                                                        transitionDuration:
                                                            const Duration(
                                                                milliseconds: 500),
                                                        reverseTransitionDuration:
                                                            const Duration(
                                                                milliseconds: 400),
                                                        transitionsBuilder: (context,
                                                            animation,
                                                            secondaryAnimation,
                                                            child) {
                                                          // Horizontal slide transition
                                                          final slideAnimation = Tween<Offset>(
                                                            begin: const Offset(1.0, 0),
                                                            end: Offset.zero,
                                                          ).animate(
                                                            CurvedAnimation(
                                                              parent: animation,
                                                              curve: Curves.easeOutCubic,
                                                            ),
                                                          );

                                                          // Fade transition
                                                          final fadeAnimation = Tween<double>(
                                                            begin: 0.0,
                                                            end: 1.0,
                                                          ).animate(
                                                            CurvedAnimation(
                                                              parent: animation,
                                                              curve: Interval(0.0, 0.7, curve: Curves.easeOut),
                                                            ),
                                                          );

                                                          // Exiting sign-in screen
                                                          final exitFade = Tween<double>(
                                                            begin: 1.0,
                                                            end: 0.0,
                                                          ).animate(
                                                            CurvedAnimation(
                                                              parent: secondaryAnimation,
                                                              curve: Interval(0.0, 0.6, curve: Curves.easeIn),
                                                            ),
                                                          );

                                                          final exitSlide = Tween<Offset>(
                                                            begin: Offset.zero,
                                                            end: const Offset(-0.3, 0),
                                                          ).animate(
                                                            CurvedAnimation(
                                                              parent: secondaryAnimation,
                                                              curve: Interval(0.0, 0.6, curve: Curves.easeIn),
                                                            ),
                                                          );

                                                          return Stack(
                                                            children: [
                                                              // Exiting sign-in screen
                                                              FadeTransition(
                                                                opacity: exitFade,
                                                                child: SlideTransition(
                                                                  position: exitSlide,
                                                                  child: Container(color: AppColors.primaryRed),
                                                                ),
                                                              ),
                                                              // Entering sign-up screen
                                                              FadeTransition(
                                                                opacity: fadeAnimation,
                                                                child: SlideTransition(
                                                                  position: slideAnimation,
                                                                  child: child,
                                                                ),
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      ),
                                                    );
                                                  },
                                                  style: TextButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                            horizontal: 20, vertical: 12),
                                                    minimumSize: const Size(140, 44),
                                                    tapTargetSize:
                                                        MaterialTapTargetSize.shrinkWrap,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                      side: BorderSide(
                                                        color: AppColors.primaryRed.withOpacity(0.2),
                                                        width: 1,
                                                      ),
                                                    ),
                                                  ),
                                                  child: RichText(
                                                    text: TextSpan(
                                                      style: UnifiedTypography.bodyMedium
                                                          .copyWith(
                                                        color:
                                                            AppColors.textSecondary,
                                                      ),
                                                      children: [
                                                        const TextSpan(
                                                            text:
                                                                "New user? "),
                                                        TextSpan(
                                                          text: 'Sign Up',
                                                          style: UnifiedTypography
                                                              .bodyMedium
                                                              .copyWith(
                                                            color:
                                                                AppColors.primaryRed,
                                                            fontWeight:
                                                                FontWeight.w800,
                                                            letterSpacing: 0.3,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),

                                              SizedBox(height: spacing(16.0, 18.0, 20.0)),

                                              // Divider
                                              SizedBox(height: spacing(20.0, 20.0, 24.0)),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Container(
                                                      height: 1,
                                                      color: AppColors.mediumGray.withOpacity(0.3),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 16),
                                                    child: Text(
                                                      'OR',
                                                      style: UnifiedTypography
                                                          .labelMedium
                                                          .copyWith(
                                                        color: AppColors.mediumGray,
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Container(
                                                      height: 1,
                                                      color: AppColors.mediumGray.withOpacity(0.3),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: spacing(20.0, 20.0, 24.0)),

                                              _buildGoogleSignInButton(controlHeight),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _playRouteFadeAndNavigate(String route) async {
    if (!mounted) return;

    Widget? routeWidget;
    switch (route) {
      case '/':
        routeWidget = const EnhancedSplashScreen();
        break;
      case '/tutorial':
        routeWidget = const InteractiveTutorialScreen();
        break;
      case '/main':
        routeWidget = const MainNavigation();
        break;
      default:
        Navigator.of(context).pushReplacementNamed(route);
        return;
    }

    // Smooth transition with success feedback
    HapticFeedback.mediumImpact();
    
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => routeWidget!,
        transitionDuration: const Duration(milliseconds: 700),
        reverseTransitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = Curves.easeInOutCubic;

          // Enhanced fade animation with staggered timing
          final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: Interval(0.0, 0.85, curve: curve),
            ),
          );

          // Smooth horizontal slide animation
          final slideAnimation = Tween<Offset>(
            begin: const Offset(1.0, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Interval(0.1, 1.0, curve: curve),
            ),
          );

          // Subtle scale for depth
          final scaleAnimation = Tween<double>(begin: 0.97, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: Interval(0.0, 0.9, curve: curve),
            ),
          );

          // Exiting sign-in screen - smooth fade out
          final exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
            CurvedAnimation(
              parent: secondaryAnimation,
              curve: Interval(0.0, 0.7, curve: Curves.easeIn),
            ),
          );

          final exitSlide = Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(-0.25, 0),
          ).animate(
            CurvedAnimation(
              parent: secondaryAnimation,
              curve: Interval(0.0, 0.7, curve: Curves.easeIn),
            ),
          );

          final exitScale = Tween<double>(begin: 1.0, end: 0.95).animate(
            CurvedAnimation(
              parent: secondaryAnimation,
              curve: Interval(0.0, 0.7, curve: Curves.easeIn),
            ),
          );

          return Stack(
            children: [
              // Exiting sign-in screen
              FadeTransition(
                opacity: exitFade,
                child: SlideTransition(
                  position: exitSlide,
                  child: ScaleTransition(
                    scale: exitScale,
                    child: Container(color: AppColors.primaryRed),
                  ),
                ),
              ),
              // Entering new screen
              FadeTransition(
                opacity: fadeAnimation,
                child: SlideTransition(
                  position: slideAnimation,
                  child: ScaleTransition(
                    scale: scaleAnimation,
                    child: child,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Sub-widgets -----------------------------------------------------------

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    FocusNode? focusNode,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    List<String>? autofillHints,
    bool enableSuggestions = true,
    bool autocorrect = true,
  }) {
    final baseBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: AppColors.lightGray.withOpacity(0.4),
        width: 1.0,
      ),
    );
    
    return Focus(
      onFocusChange: (hasFocus) {
        if (hasFocus) {
          HapticFeedback.selectionClick();
        }
      },
      child: AnimatedBuilder(
        animation: focusNode ?? FocusNode(),
        builder: (context, child) {
          final hasFocus = focusNode?.hasFocus ?? false;
          final hasValue = controller.text.isNotEmpty;
          final isValid = validator == null || validator(controller.text) == null;
          
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            transform: Matrix4.identity()
              ..translate(0.0, hasFocus ? -4.0 : 0.0),
            decoration: BoxDecoration(
              boxShadow: hasFocus
                  ? [
                      // Inner glow (appears first)
                      BoxShadow(
                        color: AppColors.primaryRed.withOpacity(0.2),
                        blurRadius: 12,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                      // Outer shadow (appears after)
                      BoxShadow(
                        color: AppColors.primaryRed.withOpacity(0.15),
                        blurRadius: 16,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Semantics(
              label: label,
              hint: hint,
              value: controller.text.isEmpty ? null : controller.text,
              onTap: () => focusNode?.requestFocus(),
              child: TextFormField(
                controller: controller,
                focusNode: focusNode,
                obscureText: obscureText,
                keyboardType: keyboardType,
                textInputAction:
                    obscureText ? TextInputAction.done : TextInputAction.next,
                onFieldSubmitted: (_) {
                  if (!obscureText) {
                    FocusScope.of(context).nextFocus();
                  } else {
                    _signIn();
                  }
                },
                validator: validator,
                style: UnifiedTypography.formInput.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                autovalidateMode: AutovalidateMode.onUserInteraction,
                autofillHints: autofillHints,
                enableSuggestions: enableSuggestions,
                autocorrect: autocorrect,
                smartDashesType: SmartDashesType.disabled,
              decoration: InputDecoration(
                labelText: validator != null ? '$label *' : label,
                hintText: hint,
                prefixIcon: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8.0, right: 6.0),
                    child: Icon(
                      icon,
                      color: hasFocus
                          ? AppColors.primaryRed
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                suffixIcon: suffixIcon != null
                    ? AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: suffixIcon,
                      )
                    : (hasValue && isValid)
                        ? Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: TweenAnimationBuilder<double>(
                              key: ValueKey('check_${hasValue && isValid}'),
                              tween: Tween<double>(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutBack,
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: 0.6 + (0.4 * value),
                                  child: Opacity(
                                    opacity: value,
                                    child: Icon(
                                      Icons.check_circle,
                                      color: AppColors.success,
                                      size: 20,
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        : null,
                filled: true,
                fillColor: AppColors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                enabledBorder: baseBorder,
                border: baseBorder,
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.primaryRed,
                    width: 2.0,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.primaryRed,
                    width: 1.5,
                  ),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.primaryRed,
                    width: 2.0,
                  ),
                ),
                labelStyle: UnifiedTypography.formLabel.copyWith(
                  color: hasFocus
                      ? AppColors.primaryRed
                      : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                hintStyle: UnifiedTypography.formHint.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
                errorStyle: UnifiedTypography.errorText.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              ),
            ),
          );
        },
      ),
    );
  }

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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Using offline mode - will sync when online')),
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

// --------------------- Decorative & Headers ---------------------

class _DecorCircles extends StatefulWidget {
  const _DecorCircles();

  @override
  State<_DecorCircles> createState() => _DecorCirclesState();
}

class _DecorCirclesState extends State<_DecorCircles> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final bgBrightness = Theme.of(context).brightness == Brightness.dark ? 0.1 : 0.15;
    
    Widget circle(double size, List<double> stops, {Offset offset = Offset.zero}) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final scale = _pulseAnimation.value;
          return Positioned(
            top: offset.dy,
            left: offset.dx,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(stops[0] * bgBrightness),
                      Colors.white.withOpacity(stops[1] * bgBrightness),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return Positioned.fill(
      child: Semantics(
        label: 'Decorative background elements',
        excludeSemantics: true,
        child: IgnorePointer(
          ignoring: true,
          child: Stack(
            children: [
              circle(250, [1.0, 0.5], offset: const Offset(-100, -100)),
              circle(180, [0.8, 0.4], offset: Offset(-50, 80)),
              circle(160, [0.7, 0.35], offset: Offset(-30, h * 0.4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TallHeader extends StatelessWidget {
  const _TallHeader({
    super.key,
    required this.logoSize,
    required this.titleSize,
    required this.subtitleSize,
    required this.bottomPadding,
    required this.gap,
  });

  final double logoSize;
  final double titleSize;
  final double subtitleSize;
  final double bottomPadding;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 28, 24, bottomPadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          Center(child: _LogoSized(size: logoSize)),
          SizedBox(height: gap),
          Text(
            'T.U.L.O.N.G',
            textAlign: TextAlign.center,
            style: UnifiedTypography.displayMedium.copyWith(
              color: Colors.white,
              fontSize: titleSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Transmission Unit for Localized Offline Network Generation',
            textAlign: TextAlign.center,
            style: UnifiedTypography.bodySmall.copyWith(
              color: Colors.white70,
              fontSize: subtitleSize,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillHeader extends StatelessWidget {
  const _PillHeader({
    super.key,
    required this.logoSize,
    required this.titleSize,
    required this.subtitleSize,
  });

  final double logoSize;
  final double titleSize;
  final double subtitleSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 16,
              offset: const Offset(0, 8),
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LogoSized(size: logoSize),
                const SizedBox(width: 16),
                Text(
                  'T.U.L.O.N.G',
                  style: UnifiedTypography.displayMedium.copyWith(
                    color: AppColors.primaryRed,
                    fontSize: titleSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Transmission Unit for Localized Offline Network Generation',
              textAlign: TextAlign.center,
              style: UnifiedTypography.bodySmall.copyWith(
                color: AppColors.primaryRed.withOpacity(0.6),
                fontSize: subtitleSize,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoSized extends StatelessWidget {
  const _LogoSized({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.white, Color(0xFFFFE7E8)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
        ),
        padding: const EdgeInsets.all(14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.asset(
            'assets/images/app_logo (3).png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

/// Simple shake wrapper used for the form/sheet.
/// It moves the child horizontally a few pixels when [_shakeController] is driven.
class _Shake extends StatelessWidget {
  const _Shake({required this.anim, required this.child});
  final Animation<double> anim;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (context, _) {
        // -8..+8 px oscillation
        final dx = math.sin(anim.value * math.pi * 4) * 8;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}
