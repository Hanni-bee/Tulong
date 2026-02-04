import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode enum supporting Light, Dark, AMOLED Black, and System
enum AppThemeMode {
  light,
  dark,
  darkAmoled,
  system,
}

/// Theme Provider for managing app theme state
/// Supports 3+ theme modes: Light, Dark, AMOLED Black, and System
class ThemeProvider extends ChangeNotifier {
  static const String _themeModeKey = 'app_theme_mode';
  
  AppThemeMode _themeMode = AppThemeMode.light;
  
  ThemeProvider() {
    _loadThemeMode();
  }
  
  /// Get current theme mode
  AppThemeMode get themeMode => _themeMode;
  
  /// Get Material ThemeMode (for MaterialApp)
  ThemeMode get materialThemeMode {
    switch (_themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.darkAmoled:
        return ThemeMode.dark; // Will use darkAmoledTheme in MaterialApp
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
  
  /// Check if currently using AMOLED black mode
  bool get isAmoledBlack => _themeMode == AppThemeMode.darkAmoled;
  
  /// Check if currently using dark mode (either standard or AMOLED)
  bool get isDarkMode => _themeMode == AppThemeMode.dark || _themeMode == AppThemeMode.darkAmoled;
  
  /// Set theme mode
  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_themeMode == mode) return;
    
    _themeMode = mode;
    await _saveThemeMode();
    notifyListeners();
  }
  
  /// Toggle between light and dark modes (cycles: light -> dark -> darkAmoled -> light)
  Future<void> toggleTheme() async {
    switch (_themeMode) {
      case AppThemeMode.light:
        await setThemeMode(AppThemeMode.dark);
        break;
      case AppThemeMode.dark:
        await setThemeMode(AppThemeMode.darkAmoled);
        break;
      case AppThemeMode.darkAmoled:
        await setThemeMode(AppThemeMode.light);
        break;
      case AppThemeMode.system:
        await setThemeMode(AppThemeMode.light);
        break;
    }
  }
  
  /// Load theme mode from SharedPreferences
  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_themeModeKey);
      
      if (savedMode != null) {
        _themeMode = AppThemeMode.values.firstWhere(
          (mode) => mode.toString() == 'AppThemeMode.$savedMode',
          orElse: () => AppThemeMode.light,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading theme mode: $e');
      _themeMode = AppThemeMode.light;
    }
  }
  
  /// Save theme mode to SharedPreferences
  Future<void> _saveThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, _themeMode.name);
    } catch (e) {
      debugPrint('Error saving theme mode: $e');
    }
  }
  
  /// Get theme name for display
  String getThemeName() {
    switch (_themeMode) {
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.darkAmoled:
        return 'AMOLED Black';
      case AppThemeMode.system:
        return 'System';
    }
  }
  
  /// Get theme icon for display
  IconData getThemeIcon() {
    switch (_themeMode) {
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
      case AppThemeMode.darkAmoled:
        return Icons.brightness_2;
      case AppThemeMode.system:
        return Icons.phone_android;
    }
  }
}
