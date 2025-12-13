import 'package:flutter/material.dart';

/// Context-Aware Page Transition System
/// 
/// Provides different transitions based on context:
/// - Modals: Fade + scale
/// - Bottom sheets: Slide from bottom with bounce
/// - Pages: Slide + fade
/// - Quick actions: Fast slide
/// - Hero transitions: Shared element animations
class ContextAwareTransitions {
  // ============================================================================
  // DURATIONS
  // ============================================================================
  
  static const Duration quickActionDuration = Duration(milliseconds: 200);
  static const Duration standardPageDuration = Duration(milliseconds: 300);
  static const Duration modalDuration = Duration(milliseconds: 350);
  static const Duration bottomSheetDuration = Duration(milliseconds: 400);
  static const Duration heroDuration = Duration(milliseconds: 500);
  
  // ============================================================================
  // CURVES
  // ============================================================================
  
  static const Curve quickActionCurve = Curves.easeOutQuart;
  static const Curve standardPageCurve = Curves.easeOutCubic;
  static const Curve modalCurve = Curves.easeInOutCubic;
  static const Curve bottomSheetCurve = Curves.easeOutBack;
  static const Curve heroCurve = Curves.easeInOutCubic;
  
  // ============================================================================
  // MODAL TRANSITIONS
  // ============================================================================
  
  /// Modal transition - fade + scale (centered)
  static Route<T> modal<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: modalDuration,
      reverseTransitionDuration: modalDuration,
      opaque: false,
      barrierDismissible: true,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Fade
        final fadeAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: modalCurve));
        
        // Scale
        final scaleAnimation = Tween<double>(
          begin: 0.9,
          end: 1.0,
        ).chain(CurveTween(curve: modalCurve));
        
        return FadeTransition(
          opacity: animation.drive(fadeAnimation),
          child: ScaleTransition(
            scale: animation.drive(scaleAnimation),
            child: child,
          ),
        );
      },
    );
  }
  
  // ============================================================================
  // BOTTOM SHEET TRANSITIONS
  // ============================================================================
  
  /// Bottom sheet transition - slide from bottom with slight bounce
  static Route<T> bottomSheet<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: bottomSheetDuration,
      reverseTransitionDuration: const Duration(milliseconds: 300),
      opaque: false,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Slide from bottom
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: bottomSheetCurve));
        
        // Fade
        final fadeAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut));
        
        return SlideTransition(
          position: animation.drive(slideAnimation),
          child: FadeTransition(
            opacity: animation.drive(fadeAnimation),
            child: child,
          ),
        );
      },
    );
  }
  
  // ============================================================================
  // PAGE TRANSITIONS
  // ============================================================================
  
  /// Standard page transition - slide from right + fade
  static Route<T> page<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: standardPageDuration,
      reverseTransitionDuration: standardPageDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Slide from right
        final slideAnimation = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: standardPageCurve));
        
        // Fade
        final fadeAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: standardPageCurve));
        
        // Combine slide and fade for entering page
        return SlideTransition(
          position: animation.drive(slideAnimation),
          child: FadeTransition(
            opacity: animation.drive(fadeAnimation),
            child: child,
          ),
        );
      },
    );
  }
  
  // ============================================================================
  // QUICK ACTION TRANSITIONS
  // ============================================================================
  
  /// Quick action transition - fast slide (for quick actions)
  static Route<T> quickAction<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: quickActionDuration,
      reverseTransitionDuration: quickActionDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slideAnimation = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: quickActionCurve));
        
        return SlideTransition(
          position: animation.drive(slideAnimation),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }
  
  // ============================================================================
  // HERO TRANSITIONS
  // ============================================================================
  
  /// Hero transition - shared element animation
  static Route<T> hero<T>(Widget page, {required String heroTag}) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: heroDuration,
      reverseTransitionDuration: heroDuration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return Hero(
          tag: heroTag,
          transitionOnUserGestures: true,
          flightShuttleBuilder: (
            BuildContext flightContext,
            Animation<double> animation,
            HeroFlightDirection flightDirection,
            BuildContext fromHeroContext,
            BuildContext toHeroContext,
          ) {
            final hero = flightDirection == HeroFlightDirection.push
                ? toHeroContext.widget
                : fromHeroContext.widget;
            
            return DefaultTextStyle(
              style: DefaultTextStyle.of(toHeroContext).style,
              child: Material(
                color: Colors.transparent,
                child: hero,
              ),
            );
          },
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }
  
  // ============================================================================
  // UTILITY EXTENSIONS
  // ============================================================================
}

/// Extension methods for BuildContext to use context-aware transitions
extension ContextAwareNavigation on BuildContext {
  /// Navigate with modal transition
  Future<T?> pushModal<T>(Widget page) {
    return Navigator.of(this).push<T>(
      ContextAwareTransitions.modal<T>(page),
    );
  }
  
  /// Navigate with bottom sheet transition
  Future<T?> pushBottomSheet<T>(Widget page) {
    return Navigator.of(this).push<T>(
      ContextAwareTransitions.bottomSheet<T>(page),
    );
  }
  
  /// Navigate with standard page transition
  Future<T?> pushPage<T>(Widget page) {
    return Navigator.of(this).push<T>(
      ContextAwareTransitions.page<T>(page),
    );
  }
  
  /// Navigate with quick action transition
  Future<T?> pushQuickAction<T>(Widget page) {
    return Navigator.of(this).push<T>(
      ContextAwareTransitions.quickAction<T>(page),
    );
  }
  
  /// Navigate with hero transition
  Future<T?> pushHero<T>(Widget page, {required String heroTag}) {
    return Navigator.of(this).push<T>(
      ContextAwareTransitions.hero<T>(page, heroTag: heroTag),
    );
  }
}

/// Enhanced showModalBottomSheet with context-aware transition
Future<T?> showContextAwareBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useRootNavigator = false,
  Color? backgroundColor,
  double? elevation,
  ShapeBorder? shape,
  Clip? clipBehavior,
  Color? barrierColor,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useSafeArea = false,
  AnimationController? transitionAnimationController,
  Offset? anchorPoint,
  String? barrierLabel,
  bool showDragHandle = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    isScrollControlled: isScrollControlled,
    useRootNavigator: useRootNavigator,
    backgroundColor: backgroundColor ?? Colors.transparent,
    elevation: elevation,
    shape: shape ?? const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    clipBehavior: clipBehavior,
    barrierColor: barrierColor ?? Colors.black54,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useSafeArea: useSafeArea,
    transitionAnimationController: transitionAnimationController,
    anchorPoint: anchorPoint,
    barrierLabel: barrierLabel,
    showDragHandle: showDragHandle,
    routeSettings: const RouteSettings(),
  );
}

