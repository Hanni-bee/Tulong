import 'package:flutter/material.dart';

class NavigationHelper {
  /// Safe navigation that prevents blank screens
  static Future<T?> safePush<T extends Object?>(
    BuildContext context,
    Widget page, {
    bool maintainState = true,
    bool fullscreenDialog = false,
  }) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute<T>(
        builder: (context) => page,
        maintainState: maintainState,
        fullscreenDialog: fullscreenDialog,
      ),
    );
  }

  /// Safe push replacement that prevents blank screens
  static Future<T?> safePushReplacement<T extends Object?, TO extends Object?>(
    BuildContext context,
    Widget page, {
    bool maintainState = true,
    bool fullscreenDialog = false,
  }) {
    return Navigator.of(context).pushReplacement<T, TO>(
      MaterialPageRoute<T>(
        builder: (context) => page,
        maintainState: maintainState,
        fullscreenDialog: fullscreenDialog,
      ),
    );
  }

  /// Safe pop that checks if can pop
  static void safePop<T extends Object?>(BuildContext context, [T? result]) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop<T>(result);
    }
  }

  /// Pop to home screen safely
  static void popToHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Pop to specific route safely
  static void popUntilRoute(BuildContext context, String routeName) {
    Navigator.of(context).popUntil(ModalRoute.withName(routeName));
  }

  /// Check if navigation is safe
  static bool canPop(BuildContext context) {
    return Navigator.of(context).canPop();
  }

  /// Get current route name
  static String? getCurrentRouteName(BuildContext context) {
    return ModalRoute.of(context)?.settings.name;
  }

  /// Navigate with animation
  static Future<T?> pushWithAnimation<T extends Object?>(
    BuildContext context,
    Widget page, {
    RouteTransitionsBuilder? transitionBuilder,
    Duration transitionDuration = const Duration(milliseconds: 300),
  }) {
    return Navigator.of(context).push<T>(
      PageRouteBuilder<T>(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: transitionDuration,
        transitionsBuilder: transitionBuilder ??
            (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: animation.drive(
                  Tween<Offset>(
                    begin: const Offset(1.0, 0.0),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeInOut)),
                ),
                child: child,
              );
            },
      ),
    );
  }
}
