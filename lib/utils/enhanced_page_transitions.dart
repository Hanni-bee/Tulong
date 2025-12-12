import 'package:flutter/material.dart';

/// Enhanced Page Transition System
/// 
/// Provides:
/// - Smoother transition curves
/// - Context-aware transitions (different for modals vs pages)
/// - Shared element transitions (hero animations)
/// - Faster transitions for quick actions
class EnhancedPageTransitions {
  // ============================================================================
  // TRANSITION DURATIONS
  // ============================================================================

  /// Standard page transition duration (300ms)
  static const Duration standardDuration = Duration(milliseconds: 300);

  /// Fast transition duration for quick actions (200ms)
  static const Duration fastDuration = Duration(milliseconds: 200);

  /// Slow transition duration for important screens (400ms)
  static const Duration slowDuration = Duration(milliseconds: 400);

  /// Modal transition duration (350ms)
  static const Duration modalDuration = Duration(milliseconds: 350);

  /// Bottom sheet transition duration (300ms)
  static const Duration bottomSheetDuration = Duration(milliseconds: 300);

  /// Hero animation duration (500ms)
  static const Duration heroDuration = Duration(milliseconds: 500);

  // ============================================================================
  // TRANSITION CURVES
  // ============================================================================

  /// Standard transition curve (smooth easeOutCubic)
  static const Curve standardCurve = Curves.easeOutCubic;

  /// Fast transition curve (easeOutQuart for snappier feel)
  static const Curve fastCurve = Curves.easeOutQuart;

  /// Smooth transition curve (easeOutExpo for very smooth)
  static const Curve smoothCurve = Curves.easeOutExpo;

  /// Modal transition curve (easeInOutCubic)
  static const Curve modalCurve = Curves.easeInOutCubic;

  /// Bottom sheet curve (easeOutBack for slight bounce)
  static const Curve bottomSheetCurve = Curves.easeOutBack;

  // ============================================================================
  // PAGE TRANSITIONS
  // ============================================================================

  /// Standard page transition (slide from right with fade)
  static Route<T> standard<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: standardDuration,
      reverseTransitionDuration: standardDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Slide animation
        final slideTween = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: standardCurve));

        // Fade animation
        final fadeTween = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: standardCurve));

        return SlideTransition(
          position: animation.drive(slideTween),
          child: FadeTransition(
            opacity: animation.drive(fadeTween),
            child: child,
          ),
        );
      },
    );
  }

  /// Fast page transition for quick actions
  static Route<T> fast<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: fastDuration,
      reverseTransitionDuration: fastDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slideTween = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: fastCurve));

        return SlideTransition(
          position: animation.drive(slideTween),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  /// Smooth page transition with scale
  static Route<T> smooth<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: slowDuration,
      reverseTransitionDuration: standardDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Slide animation
        final slideTween = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: smoothCurve));

        // Scale animation
        final scaleTween = Tween<double>(
          begin: 0.95,
          end: 1.0,
        ).chain(CurveTween(curve: smoothCurve));

        // Fade animation
        final fadeTween = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: smoothCurve));

        return SlideTransition(
          position: animation.drive(slideTween),
          child: ScaleTransition(
            scale: animation.drive(scaleTween),
            child: FadeTransition(
              opacity: animation.drive(fadeTween),
              child: child,
            ),
          ),
        );
      },
    );
  }

  // ============================================================================
  // MODAL TRANSITIONS
  // ============================================================================

  /// Modal transition (scale + fade from center)
  static Route<T> modal<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: modalDuration,
      reverseTransitionDuration: standardDuration,
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Scale animation
        final scaleTween = Tween<double>(
          begin: 0.8,
          end: 1.0,
        ).chain(CurveTween(curve: modalCurve));

        // Fade animation
        final fadeTween = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: modalCurve));

        return ScaleTransition(
          scale: animation.drive(scaleTween),
          child: FadeTransition(
            opacity: animation.drive(fadeTween),
            child: child,
          ),
        );
      },
    );
  }

  /// Bottom sheet transition (slide from bottom)
  static Route<T> bottomSheet<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: bottomSheetDuration,
      reverseTransitionDuration: fastDuration,
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Slide from bottom
        final slideTween = Tween<Offset>(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: bottomSheetCurve));

        // Fade animation
        final fadeTween = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: bottomSheetCurve));

        return SlideTransition(
          position: animation.drive(slideTween),
          child: FadeTransition(
            opacity: animation.drive(fadeTween),
            child: child,
          ),
        );
      },
    );
  }

  // ============================================================================
  // HERO TRANSITIONS (Shared Element)
  // ============================================================================

  /// Hero transition with shared element
  static Route<T> hero<T>(Widget page, {required String heroTag}) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: heroDuration,
      reverseTransitionDuration: heroDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Hero animation
        return Hero(
          tag: heroTag,
          flightShuttleBuilder: (
            BuildContext flightContext,
            Animation<double> animation,
            HeroFlightDirection flightDirection,
            BuildContext fromHeroContext,
            BuildContext toHeroContext,
          ) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: child,
        );
      },
    );
  }

  /// Hero transition with slide and fade
  static Route<T> heroWithSlide<T>(Widget page, {required String heroTag}) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: heroDuration,
      reverseTransitionDuration: heroDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Slide animation
        final slideTween = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: smoothCurve));

        // Fade animation
        final fadeTween = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: smoothCurve));

        return Hero(
          tag: heroTag,
          child: SlideTransition(
            position: animation.drive(slideTween),
            child: FadeTransition(
              opacity: animation.drive(fadeTween),
              child: child,
            ),
          ),
        );
      },
    );
  }

  // ============================================================================
  // CONTEXT-AWARE TRANSITIONS
  // ============================================================================

  /// Get appropriate transition based on context
  static Route<T> contextAware<T>(
    Widget page, {
    TransitionContext context = TransitionContext.page,
    String? heroTag,
    bool isQuickAction = false,
  }) {
    if (heroTag != null) {
      return heroWithSlide<T>(page, heroTag: heroTag);
    }

    switch (context) {
      case TransitionContext.page:
        return isQuickAction ? fast<T>(page) : standard<T>(page);
      case TransitionContext.modal:
        return modal<T>(page);
      case TransitionContext.bottomSheet:
        return bottomSheet<T>(page);
      case TransitionContext.smooth:
        return smooth<T>(page);
    }
  }
}

// ============================================================================
// ENUMS
// ============================================================================

enum TransitionContext {
  page,
  modal,
  bottomSheet,
  smooth,
}

// ============================================================================
// NAVIGATION EXTENSIONS
// ============================================================================

extension EnhancedNavigation on BuildContext {
  /// Navigate with standard transition
  Future<T?> pushStandard<T>(Widget page) {
    return Navigator.of(this).push<T>(
      EnhancedPageTransitions.standard<T>(page),
    );
  }

  /// Navigate with fast transition (quick actions)
  Future<T?> pushFast<T>(Widget page) {
    return Navigator.of(this).push<T>(
      EnhancedPageTransitions.fast<T>(page),
    );
  }

  /// Navigate with smooth transition
  Future<T?> pushSmooth<T>(Widget page) {
    return Navigator.of(this).push<T>(
      EnhancedPageTransitions.smooth<T>(page),
    );
  }

  /// Show modal with transition
  Future<T?> showModal<T>(Widget page) {
    return Navigator.of(this).push<T>(
      EnhancedPageTransitions.modal<T>(page),
    );
  }

  /// Show bottom sheet with transition
  Future<T?> showBottomSheet<T>(Widget page) {
    return Navigator.of(this).push<T>(
      EnhancedPageTransitions.bottomSheet<T>(page),
    );
  }

  /// Navigate with hero transition
  Future<T?> pushHero<T>(Widget page, {required String heroTag}) {
    return Navigator.of(this).push<T>(
      EnhancedPageTransitions.heroWithSlide<T>(page, heroTag: heroTag),
    );
  }

  /// Navigate with context-aware transition
  Future<T?> pushContextAware<T>(
    Widget page, {
    TransitionContext context = TransitionContext.page,
    String? heroTag,
    bool isQuickAction = false,
  }) {
    return Navigator.of(this).push<T>(
      EnhancedPageTransitions.contextAware<T>(
        page,
        context: context,
        heroTag: heroTag,
        isQuickAction: isQuickAction,
      ),
    );
  }
}

// ============================================================================
// GLOBAL PAGE TRANSITIONS BUILDER
// ============================================================================

/// Enhanced page transitions builder for global theme
class EnhancedPageTransitionsBuilder extends PageTransitionsBuilder {
  const EnhancedPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Determine transition type based on route settings
    final isModal = route.fullscreenDialog;
    final arguments = route.settings.arguments;
    final isBottomSheet = arguments is Map && arguments['isBottomSheet'] == true;
    final isQuickAction = arguments is Map && arguments['isQuickAction'] == true;
    final heroTag = arguments is Map ? arguments['heroTag'] as String? : null;

    if (heroTag != null) {
      return Hero(
        tag: heroTag,
        child: _buildStandardTransition(animation, child),
      );
    }

    if (isModal) {
      return _buildModalTransition(animation, child);
    }

    if (isBottomSheet) {
      return _buildBottomSheetTransition(animation, child);
    }

    if (isQuickAction) {
      return _buildFastTransition(animation, child);
    }

    return _buildStandardTransition(animation, child);
  }

  Widget _buildStandardTransition(Animation<double> animation, Widget child) {
    final slideTween = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).chain(CurveTween(curve: EnhancedPageTransitions.standardCurve));

    final fadeTween = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).chain(CurveTween(curve: EnhancedPageTransitions.standardCurve));

    return SlideTransition(
      position: animation.drive(slideTween),
      child: FadeTransition(
        opacity: animation.drive(fadeTween),
        child: child,
      ),
    );
  }

  Widget _buildFastTransition(Animation<double> animation, Widget child) {
    final slideTween = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).chain(CurveTween(curve: EnhancedPageTransitions.fastCurve));

    return SlideTransition(
      position: animation.drive(slideTween),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }

  Widget _buildModalTransition(Animation<double> animation, Widget child) {
    final scaleTween = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).chain(CurveTween(curve: EnhancedPageTransitions.modalCurve));

    final fadeTween = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).chain(CurveTween(curve: EnhancedPageTransitions.modalCurve));

    return ScaleTransition(
      scale: animation.drive(scaleTween),
      child: FadeTransition(
        opacity: animation.drive(fadeTween),
        child: child,
      ),
    );
  }

  Widget _buildBottomSheetTransition(Animation<double> animation, Widget child) {
    final slideTween = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).chain(CurveTween(curve: EnhancedPageTransitions.bottomSheetCurve));

    final fadeTween = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).chain(CurveTween(curve: EnhancedPageTransitions.bottomSheetCurve));

    return SlideTransition(
      position: animation.drive(slideTween),
      child: FadeTransition(
        opacity: animation.drive(fadeTween),
        child: child,
      ),
    );
  }
}

