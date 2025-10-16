import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'constants/app_typography.dart';
import 'screens/enhanced_splash_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/modern_sign_in_screen.dart';
import 'screens/auth/sign_in_screen_simple.dart';
import 'screens/auth/sign_up_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/auth/two_factor_verification_screen.dart';
import 'screens/interactive_tutorial_screen.dart';
import 'screens/tutorial_walkthrough_screen.dart';
import 'screens/disaster_demo_screen.dart';
import 'screens/setup/address_setup_screen.dart';
import 'screens/update_profile_screen.dart';
import 'screens/main_navigation.dart';
import 'providers/auth_provider.dart';
import 'providers/network_provider.dart';
import 'providers/power_provider.dart';
import 'utils/performance_optimizer.dart';
import 'services/firebase_service.dart';
import 'services/offline_auth_service.dart';
import 'services/notification_service.dart';
import 'services/offline_sync_service.dart';
import 'services/philippine_location_service.dart';
import 'config/page_transition_config.dart';

void main() async {
  // Optimize app performance
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await FirebaseService.initialize();
  
  // Initialize Offline Services
  await OfflineAuthService().initialize();
  
  // Initialize notification service
  await NotificationService().initialize();
  
  // Initialize offline sync service
  await OfflineSyncService().initialize();

  // Initialize Philippine location service (loads once at startup)
  await PhilippineLocationService.instance.initialize();

  // Clear image cache on startup
  PerformanceOptimizer.clearImageCache();
  
  runApp(const TulongApp());
}

class TulongApp extends StatelessWidget {
  const TulongApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..loadSession()),
        ChangeNotifierProvider(create: (_) => NetworkProvider()),
        ChangeNotifierProvider(create: (_) => PowerProvider()),
      ],
      child: MaterialApp(
        title: 'T.U.L.O.N.G',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: CustomPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              TargetPlatform.linux: CustomPageTransitionsBuilder(),
              TargetPlatform.macOS: CustomPageTransitionsBuilder(),
              TargetPlatform.windows: CustomPageTransitionsBuilder(),
            },
          ),
          primarySwatch: Colors.red,
          primaryColor: const Color(0xFFD32F2F),
          scaffoldBackgroundColor: const Color(0xFFF5F5F5),
          textTheme: TextTheme(
            // Display styles
            displayLarge: AppTypography.displayLarge,
            displayMedium: AppTypography.displayMedium,
            displaySmall: AppTypography.displaySmall,
            
            // Headline styles
            headlineLarge: AppTypography.headlineLarge,
            headlineMedium: AppTypography.headlineMedium,
            headlineSmall: AppTypography.headlineSmall,
            
            // Title styles
            titleLarge: AppTypography.titleLarge,
            titleMedium: AppTypography.titleMedium,
            titleSmall: AppTypography.titleSmall,
            
            // Body styles
            bodyLarge: AppTypography.bodyLarge,
            bodyMedium: AppTypography.bodyMedium,
            bodySmall: AppTypography.bodySmall,
            
            // Label styles
            labelLarge: AppTypography.labelLarge,
            labelMedium: AppTypography.labelMedium,
            labelSmall: AppTypography.labelSmall,
          ),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFD32F2F),
            brightness: Brightness.light,
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: const Color(0xFFF5F5F5),
            foregroundColor: const Color(0xFF2E3A59),
            elevation: 0,
            centerTitle: true,
            titleTextStyle: AppTypography.sectionTitle.copyWith(
              color: const Color(0xFF2E3A59),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              textStyle: AppTypography.buttonText,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
              elevation: 8,
              shadowColor: const Color(0xFFD32F2F).withOpacity(0.4),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFD32F2F),
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 20,
            ),
          ),
          cardTheme: const CardThemeData(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            color: Colors.white,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFFD32F2F),
            foregroundColor: Colors.white,
            elevation: 8,
          ),
        ),
        home: const EnhancedSplashScreen(),
        routes: {
          '/splash': (context) => const SplashScreen(), // Old splash (fallback)
          '/signin': (context) => const ModernSignInScreen(), // New modern sign-in
          '/signin-simple': (context) => const SignInScreen(), // Old sign-in (fallback)
          '/signup': (context) => const SignUpScreen(),
          '/forgot-password': (context) => const ForgotPasswordScreen(),
          '/reset-password': (context) => const ResetPasswordScreen(),
          '/two-factor-verification': (context) {
            final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
            return TwoFactorVerificationScreen(
              email: args['email'],
              password: args['password'],
              isRecovery: args['isRecovery'] ?? false,
            );
          },
          '/tutorial': (context) => const InteractiveTutorialScreen(), // New interactive tutorial
          '/tutorial-old': (context) => const TutorialWalkthroughScreen(), // Old tutorial (fallback)
          '/address-setup': (context) => const AddressSetupScreen(), // Address setup for Google Auth users
          '/update-profile': (context) => const UpdateProfileScreen(), // Update profile with address
          '/disaster-demo': (context) => const DisasterDemoScreen(),
          '/main': (context) => const MainNavigation(),
        },
      ),
    );
  }
}
