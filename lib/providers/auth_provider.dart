import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:io';
import '../services/firebase_service.dart';
import '../services/sqlite_service.dart';
import '../services/two_factor_auth_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _currentUser;
  String? _userEmail;
  String? _userName;
  bool _twoFactorEnabled = false;
  UserModel? _currentUserModel;
  final Map<String, String> _registeredUsers = {}; // email -> password (demo)
  final TwoFactorAuthService _twoFactorService = TwoFactorAuthService();
  final SQLiteService _sqliteService = SQLiteService();
  
  bool get isAuthenticated => _isAuthenticated;
  String? get currentUser => _currentUser;
  String? get userEmail => _userEmail;
  String? get userName => _userName;
  UserModel? get currentUserModel => _currentUserModel;
  bool get hasSession => _isAuthenticated && _userEmail != null;
  bool get twoFactorEnabled => _twoFactorEnabled;

  // Method to update current user model
  void updateUser(UserModel user) {
    _currentUserModel = user;
    _currentUser = user.id;
    _userEmail = user.email;
    _userName = user.name;
    notifyListeners();
  }

  // Check if address setup is required for current user
  bool get isAddressSetupRequired {
    if (_currentUserModel == null) return false;
    return _currentUserModel!.isGoogleAuth && !_currentUserModel!.addressSetupCompleted;
  }

  // Check if tutorial is required for current user
  Future<bool> isTutorialRequired() async {
    if (_userEmail == null) return false;
    final prefs = await SharedPreferences.getInstance();
    final hasCompletedTutorial = prefs.getBool('tutorial_completed_$_userEmail') ?? false;
    return !hasCompletedTutorial;
  }

  // Mark tutorial as completed
  Future<void> markTutorialCompleted() async {
    if (_userEmail == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_completed_$_userEmail', true);
    print('Tutorial marked as completed for: $_userEmail');
  }

  // Mark address setup as completed
  Future<void> markAddressSetupCompleted() async {
    if (_userEmail == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('address_setup_completed_$_userEmail', true);
    
    // Update current user model
    if (_currentUserModel != null) {
      _currentUserModel = _currentUserModel!.copyWith(addressSetupCompleted: true);
      notifyListeners();
    }
    
    print('Address setup marked as completed for: $_userEmail');
  }

  // Helper method to update SQLite user password
  Future<void> _updateSQLiteUserPassword(String email, String hashedPassword) async {
    try {
      final sqliteUser = await _sqliteService.getUserByEmail(email);
      if (sqliteUser != null) {
        await _sqliteService.updateUser(sqliteUser['id'], {
          'password': hashedPassword,
          'last_seen': DateTime.now().millisecondsSinceEpoch,
        });
        print('SQLite user password updated for: $email');
      } else {
        // Create new user entry in SQLite if not exists
        await _sqliteService.insertUser({
          'email': email,
          'first_name': _userName?.split(' ').first ?? 'User',
          'last_name': _userName?.split(' ').skip(1).join(' ') ?? '',
          'password': hashedPassword,
          'address': '',
          'region': '',
          'city': '',
          'barangay': '',
          'zip_code': '',
          'is_online': 1,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'last_seen': DateTime.now().millisecondsSinceEpoch,
          'is_synced': 0,
        });
        print('New SQLite user created for: $email');
      }
    } catch (e) {
      print('Error updating SQLite user password: $e');
    }
  }

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('session_email');
    final name = prefs.getString('session_name');
    
    print('Loading session - Email: $email, Name: $name');
    
    // Check if this is a fresh app start (no session data)
    if (email == null || email.isEmpty) {
      print('No session data found - user not logged in');
      return;
    }
    
    if (email.isNotEmpty) {
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
      
      final prefs = await SharedPreferences.getInstance();
      
      // Check if this is a returning user
      final isReturningUser = prefs.containsKey('user_created_at_$email');
      final hasCompletedTutorial = prefs.getBool('tutorial_completed_$email') ?? false;
      final hasCompletedAddressSetup = prefs.getBool('address_setup_completed_$email') ?? false;
      
      print('User detection - Email: $email');
      print('Is returning user: $isReturningUser');
      print('Has completed tutorial: $hasCompletedTutorial');
      print('Has completed address setup: $hasCompletedAddressSetup');
      
      // Create UserModel for Google Auth user
      final userModel = UserModel(
        id: user.uid,
        name: displayName,
        email: email,
        avatar: user.photoURL,
        isGoogleAuth: true,
        addressSetupCompleted: hasCompletedAddressSetup,
      );

      // Set Google account data
      _isAuthenticated = true;
      _currentUser = user.uid;
      _userEmail = email;
      _userName = displayName;
      _currentUserModel = userModel;
      
      // Save session data
      await prefs.setString('session_email', _userEmail!);
      await prefs.setString('session_name', _userName!);
      await prefs.setBool('is_google_auth', true);
      await prefs.setBool('address_setup_completed', hasCompletedAddressSetup);
      
      // Only set creation timestamp for new users
      if (!isReturningUser) {
        await prefs.setString('user_created_at_$email', DateTime.now().millisecondsSinceEpoch.toString());
        print('New user timestamp set for tutorial: $email');
      } else {
        print('Returning user detected - preserving existing data');
      }

      print('Google user data saved - Name: $_userName, Email: $_userEmail');
      print('Google Auth user created - Address setup required: ${!userModel.addressSetupCompleted}');

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
    
    // Clear local authentication state
    _isAuthenticated = false;
    _currentUser = null;
    _userEmail = null;
    _userName = null;
    
    // Clear only session preferences, keep SQLite data intact
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_email');
    await prefs.remove('session_name');
    await prefs.remove('current_user');
    await prefs.remove('is_google_auth');
    await prefs.remove('address_setup_completed');
    
    print('Sign out complete - session cleared, SQLite data preserved');
    notifyListeners();
  }
  
  void updateProfile(String name, String email) {
    _userName = name;
    _userEmail = email;
    notifyListeners();
  }
  
  // Verify current password for sign-up accounts
  Future<bool> verifyCurrentPassword(String password) async {
    if (_userEmail == null) return false;
    
    try {
      final hashedPassword = _hashPassword(password);
      
      // First check SQLite (offline)
      final sqliteUser = await _sqliteService.getUserByEmail(_userEmail!);
      if (sqliteUser != null && sqliteUser['password'] == hashedPassword) {
        print('Password verified from SQLite (offline)');
        return true;
      }
      
      // If not found in SQLite, check Firebase (online)
      final firebaseService = FirebaseService();
      final userSnapshot = await firebaseService.database.ref('users').orderByChild('Email').equalTo(_userEmail!).get();
      
      if (userSnapshot.exists) {
        final users = userSnapshot.value as Map;
        bool validPassword = false;
        
        users.forEach((key, value) {
          final user = value as Map;
          if (user['Password'] == hashedPassword) {
            validPassword = true;
          }
        });
        
        if (validPassword) {
          print('Password verified from Firebase (online)');
          // Update SQLite with the verified password for offline access
          await _updateSQLiteUserPassword(_userEmail!, hashedPassword);
        }
        
        return validPassword;
      }
      
      return false;
    } catch (e) {
      print('Error verifying password: $e');
      // Fallback to SQLite only if Firebase fails
      try {
        final sqliteUser = await _sqliteService.getUserByEmail(_userEmail!);
        return sqliteUser != null && sqliteUser['password'] == _hashPassword(password);
      } catch (sqliteError) {
        print('SQLite fallback also failed: $sqliteError');
        return false;
      }
    }
  }
  
  // Update password for sign-up accounts
  Future<void> updatePassword(String newPassword) async {
    if (_userEmail == null) return;
    
    try {
      final hashedPassword = _hashPassword(newPassword);
      final isOnline = await _isConnected();
      
      // Update SQLite first (offline) - this always works
      await _updateSQLiteUserPassword(_userEmail!, hashedPassword);
      
      // Try to update Firebase (online)
      if (isOnline) {
        try {
          final firebaseService = FirebaseService();
          final userSnapshot = await firebaseService.database.ref('users').orderByChild('Email').equalTo(_userEmail!).get();
          
          if (userSnapshot.exists) {
            final users = userSnapshot.value as Map;
            String? userKey;
            
            users.forEach((key, value) {
              final user = value as Map;
              if (user['Email'] == _userEmail) {
                userKey = key;
              }
            });
            
            if (userKey != null) {
              await firebaseService.database.ref('users/$userKey').update({
                'Password': hashedPassword,
              });
              print('Password updated in Firebase for: $_userEmail');
            }
          }
        } catch (firebaseError) {
          print('Firebase update failed, but SQLite updated successfully: $firebaseError');
          // Don't throw error here - SQLite update succeeded
        }
      } else {
        print('Offline mode: Password updated in SQLite only');
      }
      
      print('Password updated successfully (SQLite confirmed)');
    } catch (e) {
      print('Error updating password: $e');
      throw Exception('Failed to update password: $e');
    }
  }
  
  // Create password for Google SSO accounts
  Future<void> createPasswordForGoogleAccount(String password) async {
    if (_userEmail == null || !isGmailSSO) return;
    
    try {
      final hashedPassword = _hashPassword(password);
      final isOnline = await _isConnected();
      
      // Update SQLite first (offline) - this always works
      await _updateSQLiteUserPassword(_userEmail!, hashedPassword);
      
      // Try to update Firebase (online)
      if (isOnline) {
        print('Online detected - attempting Firebase sync for Google account: $_userEmail');
        try {
          final firebaseService = FirebaseService();
          final userSnapshot = await firebaseService.database.ref('users').orderByChild('Email').equalTo(_userEmail!).get();
          
          if (userSnapshot.exists) {
            // User exists, update password
            final users = userSnapshot.value as Map;
            String? userKey;
            
            users.forEach((key, value) {
              final user = value as Map;
              if (user['Email'] == _userEmail) {
                userKey = key;
              }
            });
            
            if (userKey != null) {
              await firebaseService.database.ref('users/$userKey').update({
                'Password': hashedPassword,
              });
              print('✅ Password created/updated in Firebase for Google account: $_userEmail');
            } else {
              print('❌ User key not found in Firebase for: $_userEmail');
            }
          } else {
            // User doesn't exist, create new user entry
            final newUserRef = firebaseService.database.ref('users').push();
            await newUserRef.set({
              'Email': _userEmail!,
              'FirstName': _userName?.split(' ').first ?? 'Google',
              'LastName': _userName?.split(' ').skip(1).join(' ') ?? 'User',
              'Password': hashedPassword,
              'createdAt': DateTime.now().millisecondsSinceEpoch,
              'isOnline': true,
              'lastSeen': DateTime.now().millisecondsSinceEpoch,
              'isGoogleAccount': true,
            });
            print('✅ New Google user created in Firebase: $_userEmail');
          }
        } catch (firebaseError) {
          print('❌ Firebase update failed for Google account: $firebaseError');
          // Don't throw error here - SQLite update succeeded
        }
      } else {
        print('❌ Offline mode: Password created in SQLite only');
      }
      
      print('Password created successfully (SQLite confirmed)');
    } catch (e) {
      print('Error creating password for Google account: $e');
      throw Exception('Failed to create password: $e');
    }
  }
  
  // Check if Google account has a password set
  Future<bool> get hasPasswordSet async {
    if (_userEmail == null) return false;
    
    try {
      // First check SQLite (offline)
      final sqliteUser = await _sqliteService.getUserByEmail(_userEmail!);
      if (sqliteUser != null && sqliteUser['password'] != null && sqliteUser['password'].toString().isNotEmpty) {
        print('Password found in SQLite (offline)');
        return true;
      }
      
      // If not found in SQLite, check Firebase (online)
      final firebaseService = FirebaseService();
      final userSnapshot = await firebaseService.database.ref('users').orderByChild('Email').equalTo(_userEmail!).get();
      
      if (userSnapshot.exists) {
        final users = userSnapshot.value as Map;
        bool hasPassword = false;
        
        users.forEach((key, value) {
          final user = value as Map;
          if (user['Email'] == _userEmail && user['Password'] != null) {
            hasPassword = true;
          }
        });
        
        if (hasPassword) {
          print('Password found in Firebase (online)');
          // Update SQLite with the password for offline access
          final firebaseUser = users.values.first as Map;
          await _updateSQLiteUserPassword(_userEmail!, firebaseUser['Password']);
        }
        
        return hasPassword;
      }
      
      return false;
    } catch (e) {
      print('Error checking password status: $e');
      // Fallback to SQLite only if Firebase fails
      try {
        final sqliteUser = await _sqliteService.getUserByEmail(_userEmail!);
        return sqliteUser != null && sqliteUser['password'] != null && sqliteUser['password'].toString().isNotEmpty;
      } catch (sqliteError) {
        print('SQLite fallback also failed: $sqliteError');
        return false;
      }
    }
  }
  
  // Offline login method
  Future<bool> loginOffline(String email, String password) async {
    try {
      final hashedPassword = _hashPassword(password);
      final sqliteUser = await _sqliteService.getUserByEmail(email);
      
      if (sqliteUser != null && sqliteUser['password'] == hashedPassword) {
        // Update user session
        _isAuthenticated = true;
        _userEmail = email;
        _userName = '${sqliteUser['first_name']} ${sqliteUser['last_name']}'.trim();
        
        // Update last seen
        await _sqliteService.updateUser(sqliteUser['id'], {
          'last_seen': DateTime.now().millisecondsSinceEpoch,
          'is_online': 1,
        });
        
        // Save session
        await _saveSession(email, _userName!);
        
        notifyListeners();
        print('Offline login successful for: $email');
        return true;
      }
      
      return false;
    } catch (e) {
      print('Offline login failed: $e');
      return false;
    }
  }
  
  // Offline signup method
  Future<Map<String, dynamic>?> signupOffline({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String address,
    required String region,
    required String city,
    required String barangay,
    required String zipCode,
  }) async {
    try {
      // Check if user already exists
      final existingUser = await _sqliteService.getUserByEmail(email);
      if (existingUser != null) {
        throw Exception('User already exists');
      }
      
      final hashedPassword = _hashPassword(password);
      
      // Create user in SQLite
      final userId = await _sqliteService.insertUser({
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'password': hashedPassword,
        'address': address,
        'region': region,
        'city': city,
        'barangay': barangay,
        'zip_code': zipCode,
        'is_online': 1,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'last_seen': DateTime.now().millisecondsSinceEpoch,
        'is_synced': 0, // Will sync when online
      });
      
      // Update user session
      _isAuthenticated = true;
      _userEmail = email;
      _userName = '$firstName $lastName';
      
      // Save session
      await _saveSession(email, _userName!);
      
      notifyListeners();
      print('Offline signup successful for: $email');
      
      // Return user data
      return {
        'id': userId,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'address': address,
        'region': region,
        'city': city,
        'barangay': barangay,
        'zip_code': zipCode,
      };
    } catch (e) {
      print('Offline signup failed: $e');
      return null;
    }
  }
  
  // Check if user is using Gmail SSO
  bool get isGmailSSO {
    return _userEmail?.contains('@gmail.com') == true || 
           _userEmail?.contains('@googlemail.com') == true;
  }
  
  // Hash password using SHA-256
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  // Save session to SharedPreferences
  Future<void> _saveSession(String email, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_email', email);
    await prefs.setString('session_name', name);
    
    // Check if this is a new user (first time signing in)
    final existingUserCreatedAt = prefs.getString('user_created_at_$email');
    if (existingUserCreatedAt == null) {
      await prefs.setString('user_created_at_$email', DateTime.now().millisecondsSinceEpoch.toString());
      print('New user detected: $email');
    } else {
      print('Existing user: $email');
    }
    
    print('Session saved: $email');
  }
  
  // Check internet connectivity
  Future<bool> _isConnected() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  // Check if user is truly new (created after tutorial implementation)
  Future<bool> isNewUser() async {
    if (_userEmail == null) {
      print('❌ No user email - not a new user');
      return false;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if user has completed tutorial
      final tutorialCompleted = prefs.getBool('tutorial_completed') ?? false;
      print('🔍 Tutorial completed: $tutorialCompleted');
      
      // If tutorial is completed, user is not new
      if (tutorialCompleted) {
        print('❌ Tutorial already completed - not a new user');
        return false;
      }
      
      // Check if user has a creation timestamp
      final userCreatedAtStr = prefs.getString('user_created_at_$_userEmail');
      print('🔍 User creation timestamp: $userCreatedAtStr');
      
      if (userCreatedAtStr == null) {
        // No creation timestamp means this is an existing user from before tutorial implementation
        print('❌ No creation timestamp - existing user');
        return false;
      }
      
      // User has creation timestamp and tutorial not completed = new user
      print('✅ User $_userEmail is new (has creation timestamp, tutorial not completed)');
      return true;
    } catch (e) {
      print('❌ Error checking if user is new: $e');
      return false; // Default to existing user if error
    }
  }
  
  // Mark user as synced with Firebase
  Future<void> markUserAsSynced(String email) async {
    try {
      final sqliteUser = await _sqliteService.getUserByEmail(email);
      if (sqliteUser != null) {
        await _sqliteService.updateUser(sqliteUser['id'], {
          'is_synced': 1,
          'last_seen': DateTime.now().millisecondsSinceEpoch,
        });
        print('User marked as synced: $email');
      }
    } catch (e) {
      print('Error marking user as synced: $e');
    }
  }
  
  // Update user profile in both Firebase and SQLite
  Future<void> updateUserProfile({
    required String firstName,
    required String lastName,
    required String address,
    required String region,
    required String city,
    required String barangay,
  }) async {
    if (_userEmail == null) return;
    
    try {
      final fullName = '$firstName $lastName';
      
      // Update SQLite first (offline-first approach)
      final sqliteUser = await _sqliteService.getUserByEmail(_userEmail!);
      if (sqliteUser != null) {
        await _sqliteService.updateUser(sqliteUser['id'], {
          'first_name': firstName,
          'last_name': lastName,
          'address': address,
          'region': region,
          'city': city,
          'barangay': barangay,
          'last_seen': DateTime.now().millisecondsSinceEpoch,
        });
        print('✅ User profile updated in SQLite: $_userEmail');
      }
      
      // Update Firebase (online)
      if (await _isConnected()) {
        try {
          final firebaseService = FirebaseService();
          await firebaseService.updateUserProfile(
            userId: sqliteUser?['firebase_uid'] ?? _userEmail!,
            data: {
              'FirstName': firstName,
              'LastName': lastName,
              'Address': address,
              'Region': region,
              'City': city,
              'Barangay': barangay,
              'lastSeen': DateTime.now().millisecondsSinceEpoch,
            },
          );
          print('✅ User profile updated in Firebase: $_userEmail');
        } catch (firebaseError) {
          print('❌ Firebase update failed: $firebaseError');
          // Don't throw error - SQLite update succeeded
        }
      } else {
        print('❌ Offline mode: Profile updated in SQLite only');
      }
      
      // Update local state
      _userName = fullName;
      notifyListeners();
      
    } catch (e) {
      print('Error updating user profile: $e');
      throw Exception('Failed to update profile: $e');
    }
  }
  
  // Sync offline users with Firebase when online
  Future<void> syncOfflineUsers() async {
    try {
      if (!await _isConnected()) {
        print('No internet connection - skipping sync');
        return;
      }
      
      final unsyncedUsers = await _sqliteService.getUnsyncedUsers();
      print('Found ${unsyncedUsers.length} unsynced users');
      
      for (final user in unsyncedUsers) {
        try {
          // Update user data in Firebase (no password verification needed)
          final firebaseService = FirebaseService();
          await firebaseService.updateUserProfile(
            userId: user['firebase_uid'] ?? user['email'], // Use Firebase UID if available, fallback to email
            data: {
              'FirstName': user['first_name'],
              'LastName': user['last_name'],
              'Email': user['email'],
              'Address': user['address'],
              'Region': user['region'],
              'City': user['city'],
              'Barangay': user['barangay'],
              'ZipCode': user['zip_code'],
              'lastSeen': DateTime.now().millisecondsSinceEpoch,
            },
          );
          
          // Mark as synced
          await _sqliteService.updateUser(user['id'], {
            'is_synced': 1,
            'last_seen': DateTime.now().millisecondsSinceEpoch,
          });
          print('Synced user: ${user['email']}');
        } catch (e) {
          print('Failed to sync user ${user['email']}: $e');
          // Continue with next user
        }
      }
    } catch (e) {
      print('Error during background sync: $e');
    }
  }
}
