import 'package:flutter/material.dart';

/// Prototype Animation Utilities
/// Based on React Framer Motion prototype specifications
class PrototypeAnimations {
  // Timing constants from prototype
  static const Duration pageEntryDuration = Duration(milliseconds: 300);
  static const Duration pageExitDuration = Duration(milliseconds: 200);
  static const Duration floatingBarDuration = Duration(milliseconds: 400);
  static const Duration cardStaggerDuration = Duration(milliseconds: 300);
  static const Duration buttonTapDuration = Duration(milliseconds: 100);
  static const Duration buttonHoverDuration = Duration(milliseconds: 200);
  static const Duration navTransitionDuration = Duration(milliseconds: 400);
  static const Duration iconWobbleDuration = Duration(milliseconds: 500);
  static const Duration pulseEffectDuration = Duration(milliseconds: 2000);
  static const Duration scanningRotationDuration = Duration(milliseconds: 2000);
  static const int staggerDelayIncrement = 100; // ms between each item

  // Curves from prototype
  static const Curve pageEntryCurve = Curves.easeOut;
  static const Curve pageExitCurve = Curves.easeIn;
  static const Curve buttonTapCurve = Curves.easeInOut;
  static const Curve buttonHoverCurve = Curves.easeOut;

  // Spring animation parameters (for nav transitions and icon wobble)
  static const double springStiffness = 400.0;
  static const double springDamping = 30.0;

  /// Page entry animation (slide up + fade)
  static Animation<Offset> createPageEntrySlide(TickerProvider vsync) {
    return Tween<Offset>(
      begin: const Offset(0, 0.02), // 20px = ~0.02 in normalized coordinates
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: AnimationController(
        duration: pageEntryDuration,
        vsync: vsync,
      ),
      curve: pageEntryCurve,
    ));
  }

  /// Page entry fade animation
  static Animation<double> createPageEntryFade(TickerProvider vsync) {
    return Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: AnimationController(
        duration: pageEntryDuration,
        vsync: vsync,
      ),
      curve: pageEntryCurve,
    ));
  }

  /// Floating bar entry animation
  static Animation<Offset> createFloatingBarEntry(
    TickerProvider vsync,
    bool isTopBar,
  ) {
    return Tween<Offset>(
      begin: Offset(0, isTopBar ? -0.05 : 0.05), // -20px top, +20px bottom
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: AnimationController(
        duration: floatingBarDuration,
        vsync: vsync,
      ),
      curve: pageEntryCurve,
    ));
  }

  /// Card stagger animation (slide from left + fade)
  static Animation<Offset> createCardStaggerSlide(
    TickerProvider vsync,
    int index,
  ) {
    final delay = index * staggerDelayIncrement;
    final controller = AnimationController(
      duration: cardStaggerDuration,
      vsync: vsync,
    );
    
    Future.delayed(Duration(milliseconds: delay), () {
      controller.forward();
    });

    return Tween<Offset>(
      begin: const Offset(-0.05, 0), // -20px left
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: pageEntryCurve,
    ));
  }

  /// Card stagger fade animation
  static Animation<double> createCardStaggerFade(
    TickerProvider vsync,
    int index,
  ) {
    final delay = index * staggerDelayIncrement;
    final controller = AnimationController(
      duration: cardStaggerDuration,
      vsync: vsync,
    );
    
    Future.delayed(Duration(milliseconds: delay), () {
      controller.forward();
    });

    return Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: pageEntryCurve,
    ));
  }

  /// Button tap animation (scale to 0.95)
  static Animation<double> createButtonTapScale(TickerProvider vsync) {
    return Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: AnimationController(
        duration: buttonTapDuration,
        vsync: vsync,
      ),
      curve: buttonTapCurve,
    ));
  }

  /// Button hover animation (scale to 1.05 + lift)
  static Animation<double> createButtonHoverScale(TickerProvider vsync) {
    return Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: AnimationController(
        duration: buttonHoverDuration,
        vsync: vsync,
      ),
      curve: buttonHoverCurve,
    ));
  }

  /// Button hover lift animation (y: -5px)
  static Animation<Offset> createButtonHoverLift(TickerProvider vsync) {
    return Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -0.01), // -5px ≈ -0.01
    ).animate(CurvedAnimation(
      parent: AnimationController(
        duration: buttonHoverDuration,
        vsync: vsync,
      ),
      curve: buttonHoverCurve,
    ));
  }

  /// Pulse animation (for glow effects)
  static Animation<double> createPulseAnimation(TickerProvider vsync) {
    final controller = AnimationController(
      duration: pulseEffectDuration,
      vsync: vsync,
    )..repeat(reverse: true);

    return Tween<double>(
      begin: 0.5,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.easeInOut,
    ));
  }

  /// Scanning rotation animation (0 to 360 degrees)
  static Animation<double> createScanningRotation(TickerProvider vsync) {
    final controller = AnimationController(
      duration: scanningRotationDuration,
      vsync: vsync,
    )..repeat();

    return Tween<double>(
      begin: 0.0,
      end: 2 * 3.14159, // 360 degrees in radians
    ).animate(CurvedAnimation(
      parent: controller,
      curve: Curves.linear,
    ));
  }

  /// Icon wobble animation (scale + rotate: [0, -10, 10, 0])
  static Animation<double> createIconWobbleScale(TickerProvider vsync) {
    return TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.05), weight: 1),
    ]).animate(CurvedAnimation(
      parent: AnimationController(
        duration: iconWobbleDuration,
        vsync: vsync,
      ),
      curve: Curves.easeInOut,
    ));
  }

  /// Icon wobble rotation
  static Animation<double> createIconWobbleRotate(TickerProvider vsync) {
    return TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -0.1745), // -10 degrees
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -0.1745, end: 0.1745), // 10 degrees
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.1745, end: 0.0), // back to 0
        weight: 1,
      ),
    ]).animate(CurvedAnimation(
      parent: AnimationController(
        duration: iconWobbleDuration,
        vsync: vsync,
      ),
      curve: Curves.easeInOut,
    ));
  }
}

/// Standard Animations Mixin
/// Provides common animation patterns for screens
/// Requires TickerProviderStateMixin (can use SingleTickerProviderStateMixin)
mixin StandardAnimations on TickerProviderStateMixin {
  late AnimationController _pageEntryController;
  late Animation<double> _pageEntryFade;
  late Animation<Offset> _pageEntrySlide;

  /// Initialize standard page entry animations
  void initStandardAnimations() {
    _pageEntryController = AnimationController(
      duration: PrototypeAnimations.pageEntryDuration,
      vsync: this,
    );

    _pageEntryFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pageEntryController,
        curve: PrototypeAnimations.pageEntryCurve,
      ),
    );

    _pageEntrySlide = Tween<Offset>(
      begin: const Offset(0, 0.02),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _pageEntryController,
        curve: PrototypeAnimations.pageEntryCurve,
      ),
    );

    // Start animation on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      startEntryAnimation();
    });
  }

  /// Start the entry animation
  void startEntryAnimation() {
    _pageEntryController.forward();
  }

  /// Dispose animations
  @override
  void dispose() {
    _pageEntryController.dispose();
    super.dispose();
  }

  /// Wrap content with page entry animations
  Widget buildWithEntryAnimation(Widget child) {
    return FadeTransition(
      opacity: _pageEntryFade,
      child: SlideTransition(
        position: _pageEntrySlide,
        child: child,
      ),
    );
  }
}

/// Staggered List Animation Helper
class StaggeredListAnimations {
  final TickerProvider vsync;
  final List<AnimationController> _controllers = [];
  final List<Animation<double>> _fadeAnimations = [];
  final List<Animation<Offset>> _slideAnimations = [];

  StaggeredListAnimations({
    required this.vsync,
    required int itemCount,
  }) {
    for (int i = 0; i < itemCount; i++) {
      final delay = i * PrototypeAnimations.staggerDelayIncrement;
      final controller = AnimationController(
        duration: PrototypeAnimations.cardStaggerDuration,
        vsync: vsync,
      );

      final fadeAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: PrototypeAnimations.pageEntryCurve,
      ));

      final slideAnimation = Tween<Offset>(
        begin: const Offset(-0.05, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: PrototypeAnimations.pageEntryCurve,
      ));

      _controllers.add(controller);
      _fadeAnimations.add(fadeAnimation);
      _slideAnimations.add(slideAnimation);

      // Start with delay
      Future.delayed(Duration(milliseconds: delay), () {
        if (!controller.isAnimating && controller.status != AnimationStatus.completed) {
          controller.forward();
        }
      });
    }
  }

  Animation<double> fade(int index) => _fadeAnimations[index];
  Animation<Offset> slide(int index) => _slideAnimations[index];

  void replay() {
    for (int i = 0; i < _controllers.length; i++) {
      final delay = i * PrototypeAnimations.staggerDelayIncrement;
      _controllers[i].reset();
      Future.delayed(Duration(milliseconds: delay), () {
        if (_controllers[i].status != AnimationStatus.completed) {
          _controllers[i].forward();
        }
      });
    }
  }

  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
  }

  Widget buildAnimatedItem(int index, Widget child) {
    if (index >= _fadeAnimations.length || index >= _slideAnimations.length) {
      return child;
    }
    return FadeTransition(
      opacity: _fadeAnimations[index],
      child: SlideTransition(
        position: _slideAnimations[index],
        child: child,
      ),
    );
  }
}

