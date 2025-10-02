import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_service.dart';
import '../services/two_factor_auth_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _currentUser;
  String? _userEmail;
  String? _userName;
  bool _twoFactorEnabled = false;
  final Map<String, String> _registeredUsers = {}; // email -> password (demo)
  final TwoFactorAuthService _twoFactorService = TwoFactorAuthService();
  
  bool get isAuthenticated => _isAuthenticated;
  String? get currentUser => _currentUser;
  String? get userEmail => _userEmail;
  String? get userName => _userName;
  bool get hasSession => _isAuthenticated && _userEmail != null;
  bool get twoFactorEnabled => _twoFactorEnabled;

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('session_email');
    final name = prefs.getString('session_name');
    
    print('Loading session - Email: $email, Name: $name');
    
    if (email != null && email.isNotEmpty) {
      // Check if there's a different Google user currently signed in
      final firebaseService = FirebaseService();
      final currentFirebaseUser = firebaseService.currentUser;
      
      print('Cached email: $email');
      print('Current Firebase user: ${currentFirebaseUser?.email}');
      
      // If Firebase has a different user than what's cached, use Firebase user
      if (currentFirebaseUser != null && 
          currentFirebaseUser.email != email &&
          (currentFirebaseUser.email?.contains('@gmail.com') == true || 
           currentFirebaseUser.email?.contains('@googlemail.com') == true)) {
        
        print('Firebase user differs from cached user - using Firebase user');
        final displayName = currentFirebaseUser.displayName ?? 'Google User';
        final firebaseEmail = currentFirebaseUser.email ?? '';
        
        // Clear old cache and set new data
        await prefs.clear();
        _isAuthenticated = true;
        _currentUser = firebaseEmail;
        _userEmail = firebaseEmail;
        _userName = displayName;
        
        // Save new session data
        await prefs.setString('session_email', _userEmail!);
        await prefs.setString('session_name', _userName!);
        
        print('Updated to Firebase user - Name: $_userName, Email: $_userEmail');
      } else {
        // Use cached data - this ensures persistence even if Firebase user is null
        _isAuthenticated = true;
        _currentUser = email;
        _userEmail = email;
        _userName = name ?? email.split('@')[0];
        
        print('Using cached session data - Name: $_userName, Email: $_userEmail');
        
        // If this is a Google user, try to refresh their data from Firebase
        if (email.contains('@gmail.com') || email.contains('@googlemail.com')) {
          await _refreshGoogleUserData();
        }
      }
      
      notifyListeners();
    } else {
      print('No valid session found - user needs to sign in');
    }
  }

  Future<void> _refreshGoogleUserData() async {
    try {
      print('_refreshGoogleUserData called');
      final firebaseService = FirebaseService();
      final currentUser = firebaseService.currentUser;
      
      print('Current Firebase user: ${currentUser?.email}');
      print('Stored email: $_userEmail');
      
      if (currentUser != null && currentUser.email == _userEmail) {
        // Update with fresh Google user data
        final displayName = currentUser.displayName ?? _userName ?? 'Google User';
        final email = currentUser.email ?? _userEmail ?? '';
        
        print('Refreshing Google user data:');
        print('  - DisplayName: $displayName');
        print('  - Email: $email');
        
        _userName = displayName;
        _userEmail = email;
        
        // Update SharedPreferences with fresh data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('session_name', _userName!);
        await prefs.setString('session_email', _userEmail!);
        
        print('Google user data refreshed successfully - Name: $_userName, Email: $_userEmail');
      } else {
        print('No matching Firebase user found for refresh - keeping cached session');
        // Keep the cached session even if Firebase user is not available
        // This ensures persistence across app restarts
      }
    } catch (e) {
      print('Failed to refresh Google user data: $e - keeping cached session');
      // Keep the cached session even if refresh fails
    }
  }

  // Set authenticated user directly (used after real auth via Firebase/SQLite)
  Future<void> setAuthenticated({required String email, required String name}) async {
    _isAuthenticated = true;
    _currentUser = email;
    _userEmail = email;
    _userName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_email', _userEmail!);
    await prefs.setString('session_name', _userName!);
    print('Session saved - Name: $_userName, Email: $_userEmail');
    notifyListeners();
  }

  // Validate session persistence
  Future<bool> validateSession() async {
    if (!_isAuthenticated || _userEmail == null) {
      print('Session validation failed - not authenticated');
      return false;
    }
    
    final prefs = await SharedPreferences.getInstance();
    final cachedEmail = prefs.getString('session_email');
    final cachedName = prefs.getString('session_name');
    
    if (cachedEmail != _userEmail || cachedName != _userName) {
      print('Session validation failed - cached data mismatch');
      return false;
    }
    
    print('Session validation successful - Name: $_userName, Email: $_userEmail');
    return true;
  }

  // Force refresh user data from Firebase (useful for Google users)
  Future<void> refreshUserData() async {
    if (_isAuthenticated && _userEmail != null) {
      await _refreshGoogleUserData();
      notifyListeners();
    }
  }
  
  Future<void> signIn(String email, String password) async {
    // Validate only registered users
    final stored = _registeredUsers[email];
    if (stored == null || stored != password) {
      throw Exception('Account not found. Please sign up first.');
    }
    _isAuthenticated = true;
    _currentUser = email;
    _userEmail = email;
    _userName = email.split('@')[0];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_email', _userEmail!);
    await prefs.setString('session_name', _userName!);
    notifyListeners();
  }
  
  Future<void> signUp(String email, String password, String username) async {
    // Register and create session
    _registeredUsers[email] = password;
    _isAuthenticated = true;
    _currentUser = email;
    _userEmail = email;
    _userName = username.isNotEmpty ? username : email.split('@')[0];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_email', _userEmail!);
    await prefs.setString('session_name', _userName!);
    notifyListeners();
  }
  
  Future<void> signInWithGoogle() async {
    try {
      final firebaseService = FirebaseService();
      final userCredential = await firebaseService.signInWithGoogle();
      
      // Check if user cancelled or if sign-in failed
      if (userCredential?.user == null) {
        // User cancelled or sign-in failed - this is not an error
        print('Google Sign-In was cancelled or failed');
        return; // Don't throw an error, just return silently
      }
      
      // Sign-in was successful - get fresh user data from Firebase
      final user = userCredential!.user!;
      
      // Enhanced name extraction logic
      String displayName;
      if (user.displayName != null && user.displayName!.isNotEmpty) {
        displayName = user.displayName!;
      } else {
        // Extract name from email (e.g., "jvncobar@gmail.com" -> "Jvncobar")
        final emailPrefix = user.email?.split('@')[0] ?? 'user';
        displayName = emailPrefix[0].toUpperCase() + emailPrefix.substring(1);
      }
      
      final email = user.email ?? '';
      
      print('Google Sign-In successful - User: $displayName, Email: $email');
      
      // COMPLETELY CLEAR all previous session data
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear(); // Clear ALL stored preferences
      
      // Set fresh Google account data
      _isAuthenticated = true;
      _currentUser = email;
      _userEmail = email;
      _userName = displayName;
      
      // Save ONLY the new session data
      await prefs.setString('session_email', _userEmail!);
      await prefs.setString('session_name', _userName!);

      print('Google user data saved - Name: $_userName, Email: $_userEmail');
      print('All previous session data cleared');

      // Ensure state is updated synchronously
      notifyListeners();
    } catch (e) {
      // Only throw for actual errors, not cancellations
      print('Google Sign-In error: ${e.toString()}');
      throw Exception('Google sign in failed: ${e.toString()}');
    }
  }

  Future<void> signInWithTwoFactor(String email, String password, String verificationCode) async {
    try {
      final userCredential = await _twoFactorService.completeTwoFactorSignIn(
        email: email,
        password: password,
        verificationCode: verificationCode,
      );

      if (userCredential?.user != null) {
        final user = userCredential!.user!;
        final displayName = user.displayName ?? 'User';
        
        _isAuthenticated = true;
        _currentUser = email;
        _userEmail = email;
        _userName = displayName;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('session_email', _userEmail!);
        await prefs.setString('session_name', _userName!);
        notifyListeners();
        
        print('2FA Sign-In successful: $email');
      }
    } catch (e) {
      print('2FA Sign-In error: ${e.toString()}');
      throw Exception('Two-factor authentication failed: ${e.toString()}');
    }
  }

  Future<bool> checkTwoFactorRequired(String email) async {
    try {
      // For now, return false since we don't have a proper user UID yet
      // This will be fixed when we implement proper user lookup by email
      _twoFactorEnabled = false;
      return false;
    } catch (e) {
      print('Error checking 2FA status: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      // Sign out from Firebase/Google if authenticated
      if (_isAuthenticated) {
        final firebaseService = FirebaseService();
        await firebaseService.signOut();
      }
    } catch (e) {
      // Continue with local sign out even if Firebase sign out fails
      print('Firebase sign out error: $e');
    }
    
    _isAuthenticated = false;
    _currentUser = null;
    _userEmail = null;
    _userName = null;
    
    // COMPLETELY CLEAR all preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    print('Complete sign out - all data cleared');
    // Reset welcome banner so it shows again on next login
    await prefs.remove('has_seen_welcome_banner');
    notifyListeners();
  }
  
  void updateProfile(String name, String email) {
    _userName = name;
    _userEmail = email;
    notifyListeners();
  }
}
