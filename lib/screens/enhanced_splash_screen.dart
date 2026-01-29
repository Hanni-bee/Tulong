import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:ui' show ImageFilter;
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_colors.dart';
import '../constants/unified_typography.dart';
import '../providers/auth_provider.dart';
import '../utils/permission_helper.dart';
import 'auth/modern_sign_in_screen.dart';
import 'interactive_tutorial_screen.dart';
import 'main_navigation.dart';

class EnhancedSplashScreen extends StatefulWidget {
  const EnhancedSplashScreen({super.key});

  @override
  State<EnhancedSplashScreen> createState() => _EnhancedSplashScreenState();
}

class _EnhancedSplashScreenState extends State<EnhancedSplashScreen>
    with TickerProviderStateMixin {
  // Animation Controllers
  late AnimationController _logoController;
  late AnimationController _rippleController;
  late AnimationController _breathingController;
  late AnimationController _glowController;

  // Animations
  late Animation<double> _logoScale;
  late Animation<double> _rippleScale;
  late Animation<double> _rippleOpacity;
  late Animation<double> _breathingScale;
  late Animation<double> _glowPulse;

  bool _showProgress = false;
  double _progress = 0.0;
  String _statusText = 'Initializing...';

  final List<String> _loadingSteps = [
    'Initializing Emergency Network...',
    'Loading Disaster Protocols...',
    'Connecting to Community...',
    'Securing Your Data...',
    'Ready!',
  ];

  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _startAnimationSequence();
    _simulateLoading();
  }

  void _initializeAnimations() {
    // Logo animations
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.elasticOut,
      ),
    );

    // Ripple effect
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _rippleScale = Tween<double>(begin: 0.0, end: 3.0).animate(
      CurvedAnimation(
        parent: _rippleController,
        curve: Curves.easeOut,
      ),
    );

    _rippleOpacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(
        parent: _rippleController,
        curve: Curves.easeOut,
      ),
    );

    // Breathing animation for logo
    _breathingController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _breathingScale = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(
        parent: _breathingController,
        curve: Curves.easeInOut,
      ),
    );

    // Glow pulse animation
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat(reverse: true);

    _glowPulse = Tween<double>(begin: 0.3, end: 0.5).animate(
      CurvedAnimation(
        parent: _glowController,
        curve: Curves.easeInOut,
      ),
    );
  }

  void _startAnimationSequence() async {
    // Haptic feedback
    HapticFeedback.mediumImpact();

    await Future.delayed(const Duration(milliseconds: 300));
    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 600));
    _rippleController.repeat();

    await Future.delayed(const Duration(milliseconds: 800));
    // Text animations are now handled by flutter_animate in build

    setState(() {
      _showProgress = true;
    });
  }

  void _simulateLoading() async {
    for (int i = 0; i < _loadingSteps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        setState(() {
          _currentStep = i;
          _statusText = _loadingSteps[i];
          _progress = (i + 1) / _loadingSteps.length;
        });
        HapticFeedback.selectionClick();
      }
    }

    // Request permissions before navigating
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
      await PermissionHelper.requestAllPermissions(context);
    
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    await _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    if (!mounted) return;

    HapticFeedback.mediumImpact();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    if (authProvider.isAuthenticated && authProvider.userUsername != null) {
      final tutorialRequired = await authProvider.isTutorialRequired();
      if (!mounted) return;
      
      if (!tutorialRequired) {
        Navigator.of(context).pushReplacement(
          _createSmoothTransition('/main'),
        );
      } else {
        Navigator.of(context).pushReplacement(
          _createSmoothTransition('/tutorial'),
        );
      }
    } else {
      Navigator.of(context).pushReplacement(
        _createSmoothTransition('/signin'),
      );
    }
  }

  PageRouteBuilder _createSmoothTransition(String route) {
    Widget targetScreen;
    switch (route) {
      case '/signin':
        targetScreen = const ModernSignInScreen();
        break;
      case '/main':
        targetScreen = const MainNavigation();
        break;
      case '/tutorial':
        targetScreen = const InteractiveTutorialScreen();
        break;
      default:
        targetScreen = const ModernSignInScreen();
    }

    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
      transitionDuration: const Duration(milliseconds: 900),
      reverseTransitionDuration: const Duration(milliseconds: 600),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
          ),
        );

        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0.15, 1.0, curve: Curves.easeOutCubic),
          ),
        );

        final scaleAnimation = Tween<double>(begin: 0.98, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0.0, 0.85, curve: Curves.easeOut),
          ),
        );

        final exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
          CurvedAnimation(
            parent: secondaryAnimation,
            curve: const Interval(0.0, 0.65, curve: Curves.easeIn),
          ),
        );

        return Stack(
          children: [
            FadeTransition(
              opacity: exitFade,
              child: Container(color: Colors.white),
            ),
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
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _rippleController.dispose();
    _breathingController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Premium Liquid Background
          const _SplashBackground(),

          // 2. Main content
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),

                  // Logo with enhanced pulsing aura
                  _buildAnimatedLogo(),

                  const Spacer(flex: 1),

                  // Branding section
                  _buildBranding(),

                  const Spacer(flex: 3),

                  // Progress section with Glassmorphism
                  if (_showProgress) 
                    _buildProgressSection()
                      .animate()
                      .fade(duration: 800.ms, curve: Curves.easeOut)
                      .slideY(begin: 0.2, end: 0, duration: 800.ms, curve: Curves.easeOutCubic),

                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranding() {
    final letters = 'T.U.L.O.N.G.'.split('');
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // App name with individual letter staggered animation
          ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                colors: [
                  AppColors.primaryRed,
                  AppColors.primaryRedDark,
                ],
              ).createShader(bounds);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: letters.asMap().entries.map((entry) {
                return Text(
                  entry.value,
                  style: UnifiedTypography.displayLarge.copyWith(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: entry.key == letters.length - 1 ? 0 : 3.0,
                    color: Colors.white,
                  ),
                ).animate()
                 .fade(delay: (entry.key * 80).ms, duration: 600.ms)
                 .slideY(begin: 0.3, end: 0, delay: (entry.key * 80).ms, curve: Curves.easeOutBack);
              }).toList(),
            ),
          ).animate()
           .shimmer(delay: 2.seconds, duration: 2.seconds, color: Colors.white.withAlpha((0.4 * 255).round())),

          const SizedBox(height: 16),

          // Tagline with dynamic letter spacing entrance
          Text(
            'Disaster-Ready Communication',
            textAlign: TextAlign.center,
            style: UnifiedTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary.withAlpha((0.6 * 255).round()),
              letterSpacing: 1.0,
            ),
          ).animate()
           .fade(delay: 1.seconds, duration: 1.seconds)
           .slideY(begin: 0.2, end: 0)
           .custom(
             begin: 0,
             end: 1.0,
             duration: 1500.ms,
             builder: (context, value, child) => Text(
               'Disaster-Ready Communication',
               textAlign: TextAlign.center,
               style: UnifiedTypography.bodyLarge.copyWith(
                 fontWeight: FontWeight.w700,
                 color: AppColors.textPrimary.withAlpha((0.6 * 255).round()),
                 letterSpacing: 1.0 + (1.0 * (1 - value)), // Spacing settles into place
               ),
             ),
           ),
        ],
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _logoController,
        _rippleController,
        _breathingController,
        _glowController,
      ]),
      builder: (context, child) {
        final breathingScale = _logoScale.value * _breathingScale.value;
        final glowOpacity = _glowPulse.value * _logoScale.value;
        
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer Layered Pulsing Aura (Matching the image)
            // Layer 1: Widest soft glow
            Container(
              width: 240 * breathingScale,
              height: 240 * breathingScale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryRed.withAlpha(((glowOpacity * 0.2).clamp(0.0, 1.0) * 255).round()),
                    blurRadius: 60,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),

            // Layer 2: Medium concentrated glow
            Container(
              width: 180 * breathingScale,
              height: 180 * breathingScale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryRed.withAlpha(((glowOpacity * 0.4).clamp(0.0, 1.0) * 255).round()),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),

            // Ripples
            ...List.generate(2, (i) {
              final rippleProgress = (_rippleScale.value - (i * 0.5)).clamp(0.0, 3.0);
              return Transform.scale(
                scale: rippleProgress,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryRed.withAlpha((((_rippleOpacity.value * (0.4 - (i * 0.1))).clamp(0.0, 1.0)) * 255).round()),
                      width: 1.5,
                    ),
                  ),
                ),
              );
            }),

            // Main Logo with Neumorphic Shell
            Transform.scale(
              scale: breathingScale,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.12 * 255).round()),
                      blurRadius: 25,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: AppColors.primaryRed.withAlpha((((0.4 + glowOpacity * 0.3)).clamp(0.0, 1.0) * 255).round()),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(10), // Slightly more padding
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryRed,
                        AppColors.primaryRedDark,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Image.asset(
                        'assets/images/app_logo (3).png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true))
              .shimmer(delay: 3.seconds, duration: 2.seconds, color: Colors.white.withAlpha((0.3 * 255).round())),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProgressSection() {
    return Container(
      width: 280, // Slightly wider for better text fit
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.7 * 255).round()),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha((0.4 * 255).round()), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.05 * 255).round()),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Status text
              SizedBox(
                height: 20,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _statusText,
                    key: ValueKey(_currentStep),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: UnifiedTypography.labelMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryRed,
                      letterSpacing: 0.2,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Progress bar
              Stack(
                children: [
                  Container(
                    height: 6,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withAlpha((0.1 * 255).round()),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        height: 6,
                        width: constraints.maxWidth * _progress,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.primaryRed,
                              AppColors.primaryRedDark,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryRed.withAlpha((0.4 * 255).round()),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      );
                    }
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

class _SplashBackground extends StatelessWidget {
  const _SplashBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Clean white base
        Container(color: Colors.white),

        // Extremely soft liquid orbs
        Positioned(
          top: -150,
          right: -100,
          child: _Orb(
            color: AppColors.primaryRed.withAlpha((0.04 * 255).round()), // Even softer
            size: 500,
          ),
        ).animate(onPlay: (c) => c.repeat(reverse: true))
         .moveY(begin: 0, end: 100, duration: 8.seconds, curve: Curves.easeInOut),

        Positioned(
          bottom: -100,
          left: -150,
          child: _Orb(
            color: AppColors.primaryRed.withAlpha((0.03 * 255).round()), // Even softer
            size: 600,
          ),
        ).animate(onPlay: (c) => c.repeat(reverse: true))
         .moveX(begin: 0, end: 150, duration: 10.seconds, curve: Curves.easeInOut),
        
        // Background particles - Network theme
        ...List.generate(15, (index) {
          final top = (index * 67) % 800;
          final left = (index * 123) % 400;
          return Positioned(
            top: top.toDouble(),
            left: left.toDouble(),
            child: Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryRed.withAlpha((0.08 * 255).round()),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
             .fade(begin: 0.1, end: 0.4, duration: 3.seconds)
             .scale(begin: const Offset(0.5, 0.5), end: const Offset(1.2, 1.2)),
          );
        }),

        // Soft global blur
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(color: Colors.transparent),
          ),
        ),

        // Premium Grain Texture Overlay
        Positioned.fill(
          child: Opacity(
            opacity: 0.02,
            child: Image.network(
              'https://www.transparenttextures.com/patterns/p6.png', // Fine grain texture
              repeat: ImageRepeat.repeat,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
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
