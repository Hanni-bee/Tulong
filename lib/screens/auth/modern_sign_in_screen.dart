import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart'; // Material motion (SharedAxis/FadeThrough)

import '../../constants/app_colors.dart';
import '../../constants/unified_typography.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../utils/input_validator.dart';
import '../../constants/soft_ui_design.dart';
import '../../utils/prototype_animations.dart';
import '../../utils/animation_controller.dart' as AppAnim;

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
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  late AnimationController _routeFadeController;
  late Animation<double> _routeFadeAnimation;

  // Keyboard + sheet motion
  late AnimationController _keyboardAnimationController;
  late Animation<double> _formTopPct; // 0.35 -> 0.05
  late Animation<double> _headerOpacityAnimation; // 1..0.65

  // Shake for errors
  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  bool _obscurePassword = true;
  bool _isLoading = false;
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

    _routeFadeController = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _routeFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _routeFadeController, curve: kEnter),
    );

    _keyboardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _formTopPct = Tween<double>(begin: 0.35, end: 0.05).animate(
      CurvedAnimation(parent: _keyboardAnimationController, curve: kEmphasized),
    );

    _headerOpacityAnimation =
        Tween<double>(begin: 1.0, end: 0.65).animate(CurvedAnimation(
      parent: _keyboardAnimationController,
      curve: const Interval(0.0, 0.9, curve: kEmphasized),
    ));

    _usernameFocusNode.addListener(_onFocusChange);
    _passwordFocusNode.addListener(_onFocusChange);

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _shakeAnim = CurvedAnimation(parent: _shakeController, curve: Curves.linear);
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
    final hasFocus = _usernameFocusNode.hasFocus || _passwordFocusNode.hasFocus;
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
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.removeListener(_onFocusChange);
    _passwordFocusNode.removeListener(_onFocusChange);
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _routeFadeController.dispose();
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
      final username = _usernameController.text.trim();
      final password = _passwordController.text;

      final requiresTwoFactor =
          await authProvider.checkTwoFactorRequired(username);

      if (requiresTwoFactor) {
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
        // Offline-first login
        final offlineSuccess =
            await authProvider.loginOffline(username, password);

        if (offlineSuccess) {
          // Small delay to ensure data is loaded before navigating
          await Future.delayed(const Duration(milliseconds: 300));
          _attemptFirebaseSync(username, password);
        } else {
          try {
            final firebaseUser = await FirebaseService()
                .authenticateUserByUsername(username: username, password: password);
            if (firebaseUser != null) {
              final firstName = firebaseUser['FirstName'] ?? '';
              final lastName = firebaseUser['LastName'] ?? '';
              final displayName = '$firstName $lastName'.trim();
              
              await authProvider.setAuthenticated(
                username: username,
                name: displayName.isNotEmpty ? displayName : username,
              );
              // Small delay to ensure user model is loaded
              await Future.delayed(const Duration(milliseconds: 300));
            } else {
              throw Exception('Invalid username or password');
            }
          } catch (_) {
            throw Exception('Invalid username or password');
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

  // SSO removed - deprecated
  @Deprecated('SSO removed')
  Future<void> _signInWithGoogle() async {
    // SSO removed
    return;
  }

  // Legacy method - removed
  void _attemptFirebaseSync(String username, String password) async {
    try {
      final firebaseService = FirebaseService();
      final userData = await firebaseService.authenticateUserByUsername(username: username, password: password);
      
      if (userData != null && mounted) {
        final firstName = userData['FirstName'] ?? '';
        final lastName = userData['LastName'] ?? '';
        final displayName = '$firstName $lastName'.trim();
        
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.setAuthenticated(username: username, name: displayName.isNotEmpty ? displayName : username);
      }
    } catch (e) {
      print('Firebase sync failed (non-critical): $e');
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
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // SSO removed - Google sign-in button removed

  Widget _buildUsernameSignInButton(double height) {
    return FilledButton.icon(
      onPressed: _isLoading ? null : _signIn,
      style: FilledButton.styleFrom(
        minimumSize: Size.fromHeight(height),
        animationDuration: const Duration(milliseconds: 200),
        backgroundColor: const Color(0xFFFF3B3B),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SoftUIDesign.buttonBorderRadius),
        ),
      ),
      icon: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : const Icon(Icons.login),
      label: Text(
        _isLoading ? 'Signing In...' : 'Sign In',
        style: UnifiedTypography.buttonLarge.copyWith(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
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
                      final isShort = totalHeight < 760;
                      final isSmall = totalHeight < 700;
                      final isTiny = totalHeight < 620;
                      final isUltraTiny = totalHeight < 560;

                      final logoSize = isUltraTiny
                          ? 70.0
                          : (isTiny
                              ? 75.0
                              : (isSmall
                                  ? 80.0
                                  : (isShort ? 85.0 : 90.0)));
                      final headerBottomPad = isUltraTiny
                          ? 16.0
                          : (isTiny ? 20.0 : (isSmall ? 28.0 : (isShort ? 32.0 : 48.0)));
                      final titleSize = isUltraTiny
                          ? 20.0
                          : (isTiny ? 22.0 : (isSmall ? 24.0 : (isShort ? 26.0 : 28.0)));
                      final subtitleSize =
                          isUltraTiny ? 11.0 : (isTiny ? 12.0 : (isShort ? 13.0 : 14.0));
                      final verticalGap =
                          isUltraTiny ? 6.0 : (isTiny ? 8.0 : (isShort ? 10.0 : 16.0));
                      final controlHeight =
                          isUltraTiny ? 42.0 : (isTiny ? 44.0 : (isShort ? 46.0 : 48.0));

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
                                    final opacity = _headerOpacityAnimation.value;
                                    final compress = 1.0 -
                                        ((opacity - 0.65) / 0.35)
                                            .clamp(0.0, 1.0);
                                    final scale = (1.0 - (compress * 0.35))
                                        .clamp(0.65, 1.0);
                                    final translateY = -15.0 * compress;

                                    return Opacity(
                                      opacity: opacity.clamp(0.65, 1.0),
                                      child: Transform.scale(
                                        scale: scale,
                                        alignment: Alignment.topCenter,
                                        child: Transform.translate(
                                          offset: Offset(0, translateY),
                                          child: AnimatedSwitcher(
                                            duration: const Duration(milliseconds: 250),
                                            switchInCurve: kEnter,
                                            switchOutCurve: kExit,
                                            transitionBuilder: (child, anim) =>
                                                FadeTransition(
                                                  opacity: anim,
                                                  child: ScaleTransition(
                                                    scale: anim,
                                                    child: child,
                                                  ),
                                                ),
                                            child: _isKeyboardVisible
                                                ? _PillHeader(
                                                    key: const ValueKey('pill'),
                                                    logoSize: logoSize * 0.8,
                                                    titleSize: titleSize * 0.85,
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
                              const double kTopBreathing = 12.0;      // small red band above the sheet
                              final double minTopWhenKeyboard =
                                  media.padding.top + kPillVisualHeight + kTopBreathing;

                              // choose top based on state:
                              final double targetTop = _isKeyboardVisible
                                  ? math.max(animatedTop, minTopWhenKeyboard)
                                  : animatedTop;

                              return AnimatedPositioned(
                                duration: const Duration(milliseconds: 350),
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
                                                  fontSize:
                                                      isUltraTiny ? 20 : (isTiny ? 21 : 22),
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              SizedBox(
                                                  height:
                                                      isUltraTiny ? 8 : (isTiny ? 10 : 12)),
                                              Text(
                                                'Sign in to continue',
                                                textAlign: TextAlign.center,
                                                style:
                                                    UnifiedTypography.bodyMedium.copyWith(
                                                  fontSize: isUltraTiny ? 13 : 14,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                              SizedBox(
                                                height: isUltraTiny
                                                    ? 12
                                                    : (isTiny
                                                        ? 16
                                                        : (isShort ? 18 : 20)),
                                              ),

                                              // Username field
                                              _buildTextField(
                                                controller: _usernameController,
                                                focusNode: _usernameFocusNode,
                                                label: 'Username',
                                                hint: 'Enter your username',
                                                icon: Icons.person_outline,
                                                keyboardType: TextInputType.text,
                                                autofillHints: const [
                                                  AutofillHints.username,
                                                ],
                                                enableSuggestions: false,
                                                autocorrect: false,
                                                validator: (value) {
                                                  return InputValidator.validateUsername(value);
                                                },
                                              ),
                                              SizedBox(
                                                height: isUltraTiny
                                                    ? 12
                                                    : (isTiny
                                                        ? 14
                                                        : (isShort ? 16 : 18)),
                                              ),

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
                                                suffixIcon: GestureDetector(
                                                  onLongPressStart: (_) => setState(
                                                      () => _obscurePassword = false),
                                                  onLongPressEnd: (_) => setState(
                                                      () => _obscurePassword = true),
                                                  child: Icon(
                                                    _obscurePassword
                                                        ? Icons.visibility_off_outlined
                                                        : Icons.visibility_outlined,
                                                    color: AppColors.mediumGray,
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

                                              SizedBox(
                                                height: isUltraTiny
                                                    ? 8
                                                    : (isTiny
                                                        ? 10
                                                        : (isShort ? 12 : 12)),
                                              ),

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
                                                            horizontal: 8, vertical: 4),
                                                    minimumSize: Size.zero,
                                                    tapTargetSize:
                                                        MaterialTapTargetSize.shrinkWrap,
                                                  ),
                                                  child: Text(
                                                    'Forgot Password?',
                                                    style: UnifiedTypography.labelMedium
                                                        .copyWith(
                                                      color: AppColors.primaryRed,
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              SizedBox(
                                                height: isUltraTiny
                                                    ? 12
                                                    : (isTiny
                                                        ? 14
                                                        : (isShort ? 16 : 18)),
                                              ),

                                              _buildUsernameSignInButton(controlHeight),

                                              SizedBox(
                                                height: isUltraTiny
                                                    ? 8
                                                    : (isTiny
                                                        ? 10
                                                        : (isShort ? 12 : 14)),
                                              ),

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
                                                                milliseconds: 300),
                                                        reverseTransitionDuration:
                                                            const Duration(
                                                                milliseconds: 250),
                                                        transitionsBuilder: (context,
                                                            animation,
                                                            secondaryAnimation,
                                                            child) {
                                                          return SharedAxisTransition(
                                                            animation: animation,
                                                            secondaryAnimation:
                                                                secondaryAnimation,
                                                            transitionType:
                                                                SharedAxisTransitionType
                                                                    .horizontal,
                                                            fillColor: Colors.transparent,
                                                            child: child,
                                                          );
                                                        },
                                                      ),
                                                    );
                                                  },
                                                  style: TextButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                            horizontal: 16, vertical: 12),
                                                    minimumSize: const Size(120, 44),
                                                    tapTargetSize:
                                                        MaterialTapTargetSize.shrinkWrap,
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
                                                                "Don't have an account? "),
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

                                              SizedBox(
                                                height: isUltraTiny
                                                    ? 12
                                                    : (isTiny
                                                        ? 14
                                                        : (isShort ? 16 : 18)),
                                              ),

                                              // Divider
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Container(
                                                      height: 1,
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          begin:
                                                              Alignment.centerLeft,
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
                                                  Padding(
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 12),
                                                    child: Text(
                                                      'OR',
                                                      style: UnifiedTypography
                                                          .labelMedium
                                                          .copyWith(
                                                        color: AppColors.mediumGray,
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: isTiny ? 10 : 11,
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

                                              SizedBox(
                                                height: isUltraTiny
                                                    ? 12
                                                    : (isTiny
                                                        ? 14
                                                        : (isShort ? 16 : 18)),
                                              ),

                                              // SSO removed - Google sign-in button removed
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
    try {
      await _routeFadeController.forward();
    } catch (_) {}

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
        try {
          _routeFadeController.value = 0.0;
        } catch (_) {}
        return;
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => routeWidget!,
        transitionDuration: AppAnim.AppAnimationController.slowAnimation, // ~600ms
        reverseTransitionDuration: PrototypeAnimations.floatingBarDuration, // ~400ms
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = AppAnim.AppAnimationController.smoothCurve;

          var fadeAnimation = Tween(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: curve),
          );

          var scaleAnimation = Tween(begin: 0.95, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: curve),
          );

          var slideAnimation =
              Tween(begin: const Offset(0, 0.08), end: Offset.zero)
                  .animate(CurvedAnimation(parent: animation, curve: curve));

          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(
              position: slideAnimation,
              child: ScaleTransition(
                scale: scaleAnimation,
                child: child,
              ),
            ),
          );
        },
      ),
    );

    try {
      _routeFadeController.value = 0.0;
    } catch (_) {}
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
      borderSide: const BorderSide(color: Colors.transparent, width: 0),
    );
    return Focus(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: kEnter,
        transform: Matrix4.identity()
          ..translate(0.0, (focusNode?.hasFocus ?? false) ? -2.0 : 0.0),
        decoration: BoxDecoration(
          boxShadow: (focusNode?.hasFocus ?? false)
              ? [BoxShadow(blurRadius: 12, spreadRadius: 1, color: Colors.black12)]
              : [],
          borderRadius: BorderRadius.circular(12),
        ),
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
            labelText: label,
            hintText: hint,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 8.0, right: 6.0),
              child: Icon(icon, color: AppColors.textSecondary),
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: baseBorder,
            border: baseBorder,
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primaryRed, width: 2.0),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.error, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.error, width: 2.0),
            ),
            labelStyle: UnifiedTypography.formLabel.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            hintStyle: UnifiedTypography.formHint.copyWith(
              color: AppColors.textSecondary,
            ),
            errorStyle: UnifiedTypography.errorText.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------- Decorative & Headers ---------------------

class _DecorCircles extends StatelessWidget {
  const _DecorCircles();

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    Widget circle(double size, List<double> stops) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white.withOpacity(stops[0]),
                Colors.white.withOpacity(stops[1]),
                Colors.transparent,
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
        );

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: Stack(
          children: [
            Positioned(top: -100, right: -100, child: circle(250, [0.15, 0.08, 0.0])),
            Positioned(top: 80, left: -50, child: circle(180, [0.12, 0.05, 0.0])),
            Positioned(top: h * 0.25, left: 30, child: circle(140, [0.10, 0.04, 0.0])),
            Positioned(top: h * 0.4, right: -30, child: circle(160, [0.12, 0.05, 0.0])),
            Positioned(top: h * 0.5, left: h * 0.15, child: circle(120, [0.10, 0.04, 0.0])),
            Positioned(top: 150, left: h * 0.3, child: circle(100, [0.08, 0.03, 0.0])),
          ],
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
  });

  final double logoSize;
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(50),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LogoSized(size: logoSize * 1.2),
            const SizedBox(width: 20),
            Text(
              'T.U.L.O.N.G',
              style: UnifiedTypography.displayMedium.copyWith(
                color: AppColors.primaryRed,
                fontSize: titleSize * 1.25,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
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
