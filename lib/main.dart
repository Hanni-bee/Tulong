import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/sign_in_screen_simple.dart';
import 'screens/auth/sign_up_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/auth/two_factor_verification_screen.dart';
import 'screens/tutorial_walkthrough_screen.dart';
import 'screens/disaster_demo_screen.dart';
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
          primarySwatch: Colors.red,
          primaryColor: const Color(0xFFD32F2F),
          scaffoldBackgroundColor: const Color(0xFFF8F9FA),
          textTheme: GoogleFonts.interTextTheme(),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFD32F2F),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
              elevation: 0,
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          ),
        ),
        home: const SplashScreen(),
        routes: {
          '/signin': (context) => const SignInScreen(),
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
          '/tutorial': (context) => const TutorialWalkthroughScreen(),
          '/disaster-demo': (context) => const DisasterDemoScreen(),
          '/main': (context) => const MainNavigation(),
        },
      ),
    );
  }
}
