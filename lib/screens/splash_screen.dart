import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../providers/auth_provider.dart';
import '../utils/responsive_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _disasterController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  
  int _currentDisasterIndex = 0;
  final List<String> _disasterGifs = [
    'assets/gifs/disasters/emergency.gif',
    'assets/gifs/disasters/fire.gif',
    'assets/gifs/disasters/earthquake.gif',
    'assets/gifs/disasters/flood.gif',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _disasterController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    

    _animationController.forward();
    _startDisasterAnimation();
    _navigateToNext();
  }

  void _startDisasterAnimation() {
    _disasterController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _currentDisasterIndex = (_currentDisasterIndex + 1) % _disasterGifs.length;
        });
        _disasterController.reset();
        _disasterController.forward();
      }
    });
    _disasterController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _disasterController.dispose();
    super.dispose();
  }

  Future<void> _navigateToNext() async {
    await Future.delayed(const Duration(seconds: 4));
    if (mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Add a small delay to ensure session is fully loaded
      await Future.delayed(const Duration(milliseconds: 500));
      
      print('Splash Screen - Checking authentication status');
      print('Is Authenticated: ${authProvider.isAuthenticated}');
      print('User Email: ${authProvider.userEmail}');
      print('User Name: ${authProvider.userName}');
      
      if (authProvider.isAuthenticated && authProvider.userEmail != null) {
        // Check if user has completed tutorial
        final prefs = await SharedPreferences.getInstance();
        final tutorialCompleted = prefs.getBool('tutorial_completed') ?? false;
        
        // Check if user is truly new (created after tutorial implementation)
        final isNewUser = await authProvider.isNewUser();
        
        print('Tutorial completed: $tutorialCompleted');
        print('Is new user: $isNewUser');
        print('User email: ${authProvider.userEmail}');
        print('Decision: ${tutorialCompleted || !isNewUser ? "Go to main" : "Show tutorial"}');
        
        if (tutorialCompleted || !isNewUser) {
          // Existing user or tutorial already completed
          print('Navigating to main screen');
          Navigator.of(context).pushReplacementNamed('/main');
        } else {
          // New user who hasn't completed tutorial
          print('Navigating to tutorial screen for new user');
          Navigator.of(context).pushReplacementNamed('/tutorial');
        }
      } else {
        print('Navigating to sign-in screen');
        Navigator.of(context).pushReplacementNamed('/signin');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: AppColors.backgroundLight,
        ),
        child: Stack(
          children: [
            // Animated background particles
            ...List.generate(8, (index) => _buildFloatingParticle(index)),
            // Main content
            Center(
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Enhanced Logo with Multiple Animation Layers
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer glow ring
                          Container(
                            width: ResponsiveHelper.isMobile(context) ? 200 : 240,
                            height: ResponsiveHelper.isMobile(context) ? 200 : 240,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.primaryRed.withOpacity(0.1),
                                  AppColors.primaryRed.withOpacity(0.05),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.7, 1.0],
                              ),
                            ),
                          )
                              .animate()
                              .scale(
                                begin: const Offset(0.0, 0.0),
                                end: const Offset(1.0, 1.0),
                                duration: 1500.ms,
                                curve: Curves.easeOutCubic,
                              )
                              .then()
                              .shimmer(
                                duration: 3000.ms,
                                color: AppColors.primaryRed.withOpacity(0.2),
                              ),
                          
                          // Main logo container
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Container(
                                  width: ResponsiveHelper.isMobile(context) ? 160 : 200,
                                  height: ResponsiveHelper.isMobile(context) ? 160 : 200,
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    borderRadius: BorderRadius.circular(50),
                                    boxShadow: [
                                      // Enhanced neumorphic shadows
                                      BoxShadow(
                                        color: AppColors.primaryRed.withOpacity(0.4),
                                        blurRadius: 40,
                                        offset: const Offset(12, 12),
                                      ),
                                      BoxShadow(
                                        color: AppColors.white.withOpacity(0.9),
                                        blurRadius: 40,
                                        offset: const Offset(-12, -12),
                                      ),
                                      // Inner glow
                                      BoxShadow(
                                        color: AppColors.primaryRed.withOpacity(0.15),
                                        blurRadius: 30,
                                        offset: const Offset(0, 0),
                                        spreadRadius: -8,
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(50),
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Image.asset(
                                        'assets/images/app_logo (3).png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                              .animate()
                              .scale(
                                begin: const Offset(0.0, 0.0),
                                end: const Offset(1.0, 1.0),
                                duration: 1200.ms,
                                curve: Curves.elasticOut,
                              )
                              .then()
                              .shimmer(
                                duration: 2000.ms,
                                color: AppColors.primaryRed.withOpacity(0.4),
                              ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // Disaster Animation Background
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryRed.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Disaster GIF
                            Positioned.fill(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 500),
                                child: Container(
                                  key: ValueKey(_currentDisasterIndex),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                  ),
                                  child: ClipOval(
                                    child: Image.asset(
                                      _disasterGifs[_currentDisasterIndex],
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: AppColors.primaryRed.withOpacity(0.1),
                                          child: Icon(
                                            Icons.warning,
                                            size: 60,
                                            color: AppColors.primaryRed,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            
                            // Overlay gradient for better visibility
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.3),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(
                            duration: 1000.ms,
                            delay: 800.ms,
                          )
                          .scale(
                            begin: const Offset(0.5, 0.5),
                            end: const Offset(1.0, 1.0),
                            duration: 1000.ms,
                            delay: 800.ms,
                            curve: Curves.elasticOut,
                          )
                          .then()
                          .shimmer(
                            duration: 1500.ms,
                            color: AppColors.primaryRed.withOpacity(0.3),
                          ),

                      const SizedBox(height: 20),

                      // Modern App Name
                      Text(
                        AppStrings.appName,
                        style: TextStyle(
                          fontSize: ResponsiveHelper.getResponsiveFontSize(context, 42),
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: 3.0,
                          shadows: [
                            Shadow(
                              color: AppColors.primaryRed.withOpacity(0.2),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(
                            duration: 1000.ms,
                            delay: 600.ms,
                          )
                          .slideY(
                            begin: 0.3,
                            end: 0,
                            duration: 1000.ms,
                            delay: 600.ms,
                            curve: Curves.easeOutCubic,
                          )
                          .then()
                          .shimmer(
                            duration: 1500.ms,
                            color: AppColors.primaryRed.withOpacity(0.4),
                          ),

                      const SizedBox(height: 16),

                      // Modern Tagline
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          AppStrings.appTagline,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.0,
                            height: 1.5,
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(
                            duration: 1200.ms,
                            delay: 1000.ms,
                          )
                          .slideY(
                            begin: 0.2,
                            end: 0,
                            duration: 1200.ms,
                            delay: 1000.ms,
                            curve: Curves.easeOutCubic,
                          ),

                      const SizedBox(height: 80),

                      // Enhanced Loading Indicator with Multiple Rings
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer rotating ring
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primaryRed.withOpacity(0.2),
                                width: 2,
                              ),
                            ),
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primaryRed.withOpacity(0.3),
                              ),
                              strokeWidth: 2,
                            ),
                          )
                              .animate(
                                onPlay: (controller) => controller.repeat(),
                              )
                              .rotate(
                                duration: 2000.ms,
                                curve: Curves.linear,
                              ),
                          
                          // Main loading indicator
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryRed.withOpacity(0.3),
                                  blurRadius: 25,
                                  offset: const Offset(8, 8),
                                ),
                                BoxShadow(
                                  color: AppColors.white.withOpacity(0.9),
                                  blurRadius: 25,
                                  offset: const Offset(-8, -8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: SizedBox(
                                width: 30,
                                height: 30,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryRed),
                                  strokeWidth: 3,
                                ),
                              ),
                            ),
                          )
                              .animate()
                              .fadeIn(
                                duration: 800.ms,
                                delay: 1600.ms,
                              )
                              .scale(
                                begin: const Offset(0.8, 0.8),
                                end: const Offset(1.0, 1.0),
                                duration: 800.ms,
                                delay: 1600.ms,
                                curve: Curves.elasticOut,
                              ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Enhanced Loading Text with Typewriter Effect
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          final progress = _animationController.value;
                          final text = 'Initializing Emergency Network...';
                          final visibleLength = (text.length * progress).round();
                          final visibleText = text.substring(0, visibleLength.clamp(0, text.length));
                          
                          return Text(
                            visibleText,
                            style: const TextStyle(
                              fontSize: 18,
                              color: AppColors.primaryRed,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              shadows: [
                                Shadow(
                                  color: Colors.white,
                                  blurRadius: 2,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          );
                        },
                      )
                          .animate()
                          .fadeIn(
                            duration: 800.ms,
                            delay: 1200.ms,
                          )
                          .slideY(
                            begin: 0.2,
                            end: 0,
                            duration: 800.ms,
                            delay: 1200.ms,
                            curve: Curves.easeOutCubic,
                          ),

                      const SizedBox(height: 60),

                      // Modern Version Info
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryRed.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(2, 2),
                            ),
                            BoxShadow(
                              color: AppColors.white.withOpacity(0.8),
                              blurRadius: 10,
                              offset: const Offset(-2, -2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Version 1.0.0',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(
                            duration: 500.ms,
                            delay: 2200.ms,
                          )
                          .scale(
                            begin: const Offset(0.9, 0.9),
                            end: const Offset(1.0, 1.0),
                            duration: 500.ms,
                            delay: 2200.ms,
                            curve: Curves.easeOutCubic,
                          ),
                    ],
                  ),
                ),
                );
              },
            ),
            ),
          ],
        ),
      ),
    );
  }

  // Floating particle animation
  Widget _buildFloatingParticle(int index) {
    return Positioned(
      left: (index * 50.0) % MediaQuery.of(context).size.width,
      top: (index * 80.0) % MediaQuery.of(context).size.height,
      child: Container(
        width: 4 + (index % 3) * 2,
        height: 4 + (index % 3) * 2,
        decoration: BoxDecoration(
          color: AppColors.primaryRed.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
      )
          .animate(
            onPlay: (controller) => controller.repeat(),
          )
          .fadeIn(
            duration: (1000 + index * 200).ms,
            delay: (index * 300).ms,
          )
          .then()
          .fadeOut(
            duration: (1000 + index * 200).ms,
          )
          .then()
          .moveY(
            begin: 0,
            end: -100,
            duration: (2000 + index * 500).ms,
            curve: Curves.easeInOut,
          ),
    );
  }
}