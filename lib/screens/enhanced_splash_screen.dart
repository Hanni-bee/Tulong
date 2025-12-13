import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/auth_provider.dart';
import '../utils/neumorphic_utils.dart';
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
  late AnimationController _mainController;
  late AnimationController _logoController;
  late AnimationController _rippleController;
  late AnimationController _particleController;
  late AnimationController _textController;
  late AnimationController _breathingController;
  late AnimationController _glowController;

  late Animation<double> _logoScale;
  late Animation<double> _logoRotate;
  late Animation<double> _rippleScale;
  late Animation<double> _rippleOpacity;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
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
    // Main controller
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

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

    _logoRotate = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.easeInOut,
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

    // Particle animations
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    // Text animations
    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeIn,
      ),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: Curves.easeOutCubic,
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

    // Sequence: Logo -> Ripple -> Text
    await Future.delayed(const Duration(milliseconds: 300));
    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 600));
    _rippleController.repeat();

    await Future.delayed(const Duration(milliseconds: 800));
    _textController.forward();

    await Future.delayed(const Duration(milliseconds: 1000));
    _particleController.repeat();

    // Start breathing and glow after logo appears
    await Future.delayed(const Duration(milliseconds: 500));
    _breathingController.repeat(reverse: true);
    _glowController.repeat(reverse: true);

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
    if (mounted) {
      await PermissionHelper.requestAllPermissions(context);
    }
    
    await Future.delayed(const Duration(milliseconds: 300));
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    if (!mounted) return;

    HapticFeedback.mediumImpact();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await Future.delayed(const Duration(milliseconds: 300));

    if (authProvider.isAuthenticated && authProvider.userEmail != null) {
      // Check if tutorial is required for this user
      final tutorialRequired = await authProvider.isTutorialRequired();
      
      if (!tutorialRequired) {
        // User has completed tutorial, go to main app
        Navigator.of(context).pushReplacement(
          _createSmoothTransition('/main'),
        );
      } else {
        // User needs to complete tutorial
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
        // Enhanced fade with staggered timing
        final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: Interval(0.0, 0.75, curve: Curves.easeOut),
          ),
        );

        // Smooth slide from bottom with easing
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: Interval(0.15, 1.0, curve: Curves.easeOutCubic),
          ),
        );

        // Subtle scale for depth effect
        final scaleAnimation = Tween<double>(begin: 0.98, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: Interval(0.0, 0.85, curve: Curves.easeOut),
          ),
        );

        // Exiting splash screen - smooth fade out
        final exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
          CurvedAnimation(
            parent: secondaryAnimation,
            curve: Interval(0.0, 0.65, curve: Curves.easeIn),
          ),
        );

        final exitSlide = Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(0, -0.12),
        ).animate(
          CurvedAnimation(
            parent: secondaryAnimation,
            curve: Interval(0.0, 0.65, curve: Curves.easeIn),
          ),
        );

        final exitScale = Tween<double>(begin: 1.0, end: 0.96).animate(
          CurvedAnimation(
            parent: secondaryAnimation,
            curve: Interval(0.0, 0.65, curve: Curves.easeIn),
          ),
        );

        return Stack(
          children: [
            // Exiting splash screen
            FadeTransition(
              opacity: exitFade,
              child: SlideTransition(
                position: exitSlide,
                child: ScaleTransition(
                  scale: exitScale,
                  child: Container(color: AppColors.neumorphicBase),
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
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    _logoController.dispose();
    _rippleController.dispose();
    _particleController.dispose();
    _textController.dispose();
    _breathingController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.neumorphicBase,
      body: Stack(
        children: [
          // Animated background particles
          ...List.generate(15, (index) => _buildParticle(index, size)),

          // Main content
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),

                  // Logo with ripple effect
                  _buildAnimatedLogo(),

                  const SizedBox(height: 40),

                  // App name with animation
                  _buildAppName(),

                  const SizedBox(height: 12),

                  // Tagline
                  _buildTagline(),

                  const Spacer(),

                  // Progress section
                  if (_showProgress) _buildProgressSection(),

                  const SizedBox(height: 60),
                ],
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
            // Ripple effect 1
            Transform.scale(
              scale: _rippleScale.value,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryRed
                        .withOpacity(_rippleOpacity.value * 0.4),
                    width: 2,
                  ),
                ),
              ),
            ),

            // Ripple effect 2 (delayed)
            Transform.scale(
              scale: (_rippleScale.value - 0.5).clamp(0.0, 3.0),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryRed
                        .withOpacity(_rippleOpacity.value * 0.3),
                    width: 2,
                  ),
                ),
              ),
            ),

            // Enhanced pulsing glow effect
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryRed.withOpacity(glowOpacity),
                    blurRadius: 40 * breathingScale,
                    spreadRadius: 10 * breathingScale,
                  ),
                  BoxShadow(
                    color: AppColors.primaryRed.withOpacity(glowOpacity * 0.5),
                    blurRadius: 60 * breathingScale,
                    spreadRadius: 5 * breathingScale,
                  ),
                ],
              ),
            ),

            // Main logo container with neumorphic effect and breathing
            Transform.scale(
              scale: breathingScale,
              child: Transform.rotate(
                angle: _logoRotate.value * 0.1,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        AppColors.neumorphicBase,
                      ],
                    ),
                    boxShadow: [
                      ...NeumorphicUtils.getNeumorphicShadow(depth: 12),
                      BoxShadow(
                        color: AppColors.primaryRed.withOpacity(0.2 + glowOpacity * 0.2),
                        blurRadius: 20 * breathingScale,
                        spreadRadius: 5 * breathingScale,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: NeumorphicUtils.getModernGradient(),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Image.asset(
                        'assets/images/app_logo (3).png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAppName() {
    return SlideTransition(
      position: _textSlide,
      child: FadeTransition(
        opacity: _textFade,
        child: ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                AppColors.primaryRed,
                AppColors.primaryRedDark,
              ],
            ).createShader(bounds);
          },
          child: const Text(
            'T.U.L.O.N.G',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              letterSpacing: 4.0,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black12,
                  offset: Offset(0, 4),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTagline() {
    return FadeTransition(
      opacity: _textFade,
      child: const Text(
        'Disaster-Ready Communication',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    return Column(
      children: [
        // Status text with typewriter effect
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.5),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: Text(
            _statusText,
            key: ValueKey(_currentStep),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryRed,
              letterSpacing: 0.5,
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Modern progress bar
        Container(
          width: 200,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            boxShadow: NeumorphicUtils.getInnerShadow(depth: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Stack(
              children: [
                // Background
                Container(
                  color: AppColors.neumorphicBase,
                ),
                // Progress
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  width: 200 * _progress,
                  decoration: BoxDecoration(
                    gradient: NeumorphicUtils.getModernGradient(),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryRed.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Progress percentage
        AnimatedBuilder(
          animation: _mainController,
          builder: (context, child) {
            return Text(
              '${(_progress * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.5,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildParticle(int index, Size size) {
    final random = index * 37; // Pseudo-random
    final left = (random % size.width.toInt()).toDouble();

    return AnimatedBuilder(
      animation: _particleController,
      builder: (context, child) {
        final progress = (_particleController.value + (index / 15)) % 1.0;
        final top = size.height * progress;
        final opacity = (1.0 - progress) * 0.6;

        return Positioned(
          left: left,
          top: top,
          child: Container(
            width: 3 + (index % 4),
            height: 3 + (index % 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryRed.withOpacity(opacity),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryRed.withOpacity(opacity * 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

