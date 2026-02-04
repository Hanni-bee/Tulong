import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import 'providers/theme_provider.dart';
import 'services/simple_bluetooth_service.dart';
import 'services/hardware_service.dart';
import 'services/offline_auth_service.dart';
import 'services/notification_service.dart';
import 'services/offline_sync_service.dart';
import 'services/philippine_location_service.dart';
import 'services/app_initialization_service.dart';
import 'services/sqlite_service.dart';
import 'utils/enhanced_page_transitions.dart';
import 'utils/app_themes.dart';

void main() async {
  // Optimize app performance
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize unified data service (SQLite only - offline)
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
    final isInForeground = state == AppLifecycleState.resumed;
    NotificationService().setAppLifecycleState(isInForeground);
    debugPrint('📱 App lifecycle changed: $state (Foreground: $isInForeground)');
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..loadSession()),
        ChangeNotifierProvider(create: (_) => NetworkProvider()),
        ChangeNotifierProvider(create: (_) => PowerProvider()),
        ChangeNotifierProvider(create: (_) => SimpleBluetoothService()),
        ChangeNotifierProvider(create: (_) => HardwareService()..initialize()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        Provider(create: (_) => SQLiteService()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'T.U.L.O.N.G',
            debugShowCheckedModeBanner: false,
            theme: AppThemes.lightTheme,
            darkTheme: themeProvider.isAmoledBlack 
                ? AppThemes.darkAmoledTheme 
                : AppThemes.darkTheme,
            themeMode: themeProvider.materialThemeMode,
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
          );
        },
      ),
    );
  }
}
