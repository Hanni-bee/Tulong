import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import 'screens/esp32_auth_screen.dart';
import 'screens/esp32_device_scanner.dart';
import 'screens/main_navigation.dart';
import 'providers/auth_provider.dart';
import 'providers/network_provider.dart';
import 'providers/power_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/notification_provider.dart';
import 'services/simple_bluetooth_service.dart';
import 'services/hardware_service.dart';
import 'services/firebase_service.dart';
import 'services/offline_auth_service.dart';
import 'services/notification_service.dart';
import 'services/offline_sync_service.dart';
import 'services/philippine_location_service.dart';
import 'services/app_initialization_service.dart';
import 'services/sqlite_service.dart';
import 'utils/enhanced_page_transitions.dart';

void main() async {
  // Optimize app performance
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await FirebaseService.initialize();
  
  // Initialize unified data service (SQLite + Firebase sync)
  await AppInitializationService().initialize();
  
  // Initialize Offline Services
  await OfflineAuthService().initialize();
  
  // Initialize notification service
  await NotificationService().initialize();
  
  // Initialize offline sync service
  await OfflineSyncService().initialize();

  // Initialize Philippine location service (loads once at startup)
  await PhilippineLocationService.instance.initialize();

  // Clear image cache on startup - commented out to improve transition performance for cached images
  // PerformanceOptimizer.clearImageCache();
  
  runApp(const TulongApp());
}

class TulongApp extends StatefulWidget {
  const TulongApp({super.key});

  @override
  State<TulongApp> createState() => _TulongAppState();
}

class _TulongAppState extends State<TulongApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Assume app starts in foreground
    NotificationService().setAppLifecycleState(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Update notification service with app state
    // Only show notifications when app is in background (paused, inactive, or detached)
    final isInForeground = state == AppLifecycleState.resumed;
    NotificationService().setAppLifecycleState(isInForeground);
    debugPrint('📱 App lifecycle changed: $state (Foreground: $isInForeground)');
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..loadSession()),
        ChangeNotifierProvider(create: (_) => NetworkProvider()),
        ChangeNotifierProvider(create: (_) => PowerProvider()),
        ChangeNotifierProvider(create: (_) => SimpleBluetoothService()),
        ChangeNotifierProvider(create: (_) => HardwareService()..initialize()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        Provider(create: (_) => SQLiteService()),
      ],
      child: MaterialApp(
        title: 'T.U.L.O.N.G',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          splashFactory: InkRipple.splashFactory,
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: EnhancedPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              TargetPlatform.linux: EnhancedPageTransitionsBuilder(),
              TargetPlatform.macOS: EnhancedPageTransitionsBuilder(),
              TargetPlatform.windows: EnhancedPageTransitionsBuilder(),
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
          colorScheme: ColorScheme.light(
            primary: const Color(0xFFD32F2F),
            secondary: const Color(0xFF2C2C2C),
            surface: Colors.white,
            error: const Color(0xFFD32F2F),
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: const Color(0xFF1A1A1A),
            onError: Colors.white,
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
                borderRadius: BorderRadius.circular(12), // Soft UI standard
              ),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              elevation: 0, // Using custom shadows instead
              shadowColor: Colors.transparent,
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE0E0E0),
                width: 1.0,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE0E0E0),
                width: 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFD32F2F),
                width: 2.0,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFEF5350),
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFEF5350),
                width: 2.0,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
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
            elevation: 0,
          ),
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: Colors.white,
          ), dialogTheme: DialogThemeData(backgroundColor: Colors.white),
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
          '/esp32-auth': (context) => const ESP32AuthScreen(), // ESP32 Bluetooth authentication
          '/esp32-scanner': (context) => const ESP32DeviceScanner(), // ESP32 device scanner with pairing
          '/disaster-demo': (context) => const DisasterDemoScreen(),
          '/main': (context) => const MainNavigation(),
        },
      ),
    );
  }
}
