import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:io';
import '../services/firebase_service.dart';
import '../services/sqlite_service.dart';
import '../services/unified_data_service.dart';
import '../services/two_factor_auth_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _currentUser;
  String? _userEmail;
  String? _userName;
  bool _twoFactorEnabled = false;
  UserModel? _currentUserModel;
  String? _emergencyMessage;
  List<String> _emergencyMessages = [];
  int? _defaultEmergencyMessageIndex;
  final Map<String, String> _registeredUsers = {}; // email -> password (demo)
  final TwoFactorAuthService _twoFactorService = TwoFactorAuthService();
  final SQLiteService _sqliteService = SQLiteService();
  final UnifiedDataService _unifiedDataService = UnifiedDataService();
  
  bool get isAuthenticated => _isAuthenticated;
  String? get currentUser => _currentUser;
  String? get userEmail => _userEmail;
  String? get userName => _userName;
  UserModel? get currentUserModel => _currentUserModel;
  bool get hasSession => _isAuthenticated && _userEmail != null;
  bool get twoFactorEnabled => _twoFactorEnabled;
  String? get emergencyMessage => _emergencyMessage;
  List<String> get emergencyMessages => List.unmodifiable(_emergencyMessages);
  int? get defaultEmergencyMessageIndex => _defaultEmergencyMessageIndex;

  // Method to update current user model
  void updateUser(UserModel user) {
    _currentUserModel = user;
    _currentUser = user.id;
    _userEmail = user.email;
    _userName = user.name;
    
    notifyListeners();
  }

  // Method to load user data and create UserModel
  Future<void> loadUserModel() async {
    if (_userEmail == null) return;
    
    try {
      print('Loading UserModel for: $_userEmail');
      
      // First try to get user data from SQLite
      final sqliteUser = await _sqliteService.getUserByEmail(_userEmail!);
      if (sqliteUser != null) {
        print('Found user in SQLite: ${sqliteUser.toString()}');
        
        // Combine first and last name
        final firstName = sqliteUser['first_name']?.toString() ?? '';
        final lastName = sqliteUser['last_name']?.toString() ?? '';
        final fullName = '$firstName $lastName'.trim();
        
        // Handle legacy data where province might be stored in city field
        final province = sqliteUser['province']?.toString() ?? '';
        final city = sqliteUser['city']?.toString() ?? '';
        
        // If province is empty but city has data, it might be legacy data
        final finalProvince = province.isNotEmpty ? province : city;
        final finalCity = city.isNotEmpty ? city : '';
        
        final userModel = UserModel(
          id: sqliteUser['id']?.toString() ?? _userEmail!,
          name: fullName.isNotEmpty ? fullName : (_userName ?? 'User'),
          email: sqliteUser['email']?.toString() ?? _userEmail!,
          phone: sqliteUser['phone']?.toString(),
          street: sqliteUser['street']?.toString() ?? '', // Fixed: was 'address'
          region: sqliteUser['region']?.toString() ?? '',
          barangay: sqliteUser['barangay']?.toString() ?? '',
          city: finalCity,
          province: finalProvince,
          addressSetupCompleted: (sqliteUser['address_setup_completed'] ?? 0) == 1,
          isGoogleAuth: false,
          isOnline: (sqliteUser['is_online'] ?? 0) == 1,
          createdAt: sqliteUser['created_at']?.toInt() ?? 0,
        );
        
        _currentUserModel = userModel;
        if (sqliteUser.containsKey('emergency_message') &&
            (sqliteUser['emergency_message']?.toString().isNotEmpty ?? false)) {
          _emergencyMessage = sqliteUser['emergency_message'].toString();
        }
        print('UserModel created from SQLite data: ${userModel.toString()}');
        notifyListeners();
        return;
      }
      
      // If not found in SQLite, try Firebase
      final firebaseService = FirebaseService();
      final userSnapshot = await firebaseService.database.ref('users').orderByChild('Email').equalTo(_userEmail!).get();
      
      if (userSnapshot.exists) {
        print('Found user in Firebase');
        final userData = userSnapshot.value as Map<dynamic, dynamic>;
        final userEntry = userData.values.first as Map<dynamic, dynamic>;
        
        // Combine first and last name for Firebase
        final firstName = userEntry['FirstName']?.toString() ?? '';
        final lastName = userEntry['LastName']?.toString() ?? '';
        final fullName = '$firstName $lastName'.trim();
        
        final userModel = UserModel(
          id: userEntry['ID']?.toString() ?? _userEmail!,
          name: fullName.isNotEmpty ? fullName : (userEntry['Name']?.toString() ?? _userName ?? 'User'),
          email: userEntry['Email']?.toString() ?? _userEmail!,
          phone: userEntry['Phone']?.toString(),
          street: userEntry['Street']?.toString() ?? userEntry['Address']?.toString() ?? '',
          region: userEntry['Region']?.toString() ?? '',
          barangay: userEntry['Barangay']?.toString() ?? '',
          city: userEntry['City']?.toString() ?? '',
          province: userEntry['Province']?.toString() ?? '',
          addressSetupCompleted: userEntry['AddressSetupCompleted'] == true,
          isGoogleAuth: userEntry['IsGoogleAuth'] == true,
          isOnline: userEntry['IsOnline'] == true,
          createdAt: userEntry['CreatedAt']?.toInt() ?? 0,
        );
        
        _currentUserModel = userModel;
        print('UserModel created from Firebase data: ${userModel.toString()}');
        notifyListeners();
        return;
      }
      
      // If not found in either, create a basic UserModel with available data
      print('User not found in SQLite or Firebase, creating basic UserModel');
      final userModel = UserModel(
        id: _userEmail!,
        name: _userName ?? 'User',
        email: _userEmail!,
        isGoogleAuth: _userEmail!.contains('@gmail.com') || _userEmail!.contains('@googlemail.com'),
        addressSetupCompleted: false,
      );
      
      _currentUserModel = userModel;
      print('Basic UserModel created: ${userModel.toString()}');
      notifyListeners();
      
    } catch (e) {
      print('Error loading UserModel: $e');
      // Create a fallback UserModel
      final userModel = UserModel(
        id: _userEmail!,
        name: _userName ?? 'User',
        email: _userEmail!,
        isGoogleAuth: _userEmail!.contains('@gmail.com') || _userEmail!.contains('@googlemail.com'),
        addressSetupCompleted: false,
      );
      
      _currentUserModel = userModel;
      print('Fallback UserModel created: ${userModel.toString()}');
      notifyListeners();
    }
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

  // Mark address setup as completed using UnifiedDataService
  Future<void> markAddressSetupCompleted() async {
    if (_userEmail == null) return;
    
    try {
      final success = await _unifiedDataService.markAddressSetupCompleted(_userEmail!);
      
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('address_setup_completed_$_userEmail', true);
        
        // Update current user model
        if (_currentUserModel != null) {
          _currentUserModel = _currentUserModel!.copyWith(addressSetupCompleted: true);
          notifyListeners();
        }
        
        print('✅ Address setup marked as completed for: $_userEmail');
      } else {
        throw Exception('Failed to mark address setup as completed');
      }
    } catch (e) {
      print('❌ Error marking address setup completed: $e');
      throw Exception('Failed to mark address setup as completed: $e');
    }
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
      
      // Load emergency message(s) scoped to this user after we have _userEmail
      try {
        if (_userEmail != null) {
          _emergencyMessage = prefs.getString('emergency_message_${_userEmail!}');
          // Load multiple messages list (JSON-encoded list)
          final rawList = prefs.getString('emergency_messages_${_userEmail!}');
          if (rawList != null && rawList.isNotEmpty) {
            final decoded = jsonDecode(rawList);
            if (decoded is List) {
              _emergencyMessages = decoded.map((e) => e.toString()).toList();
            }
          }
          _defaultEmergencyMessageIndex = prefs.getInt('emergency_message_default_index_${_userEmail!}');
          // Ensure default exists
          if (_defaultEmergencyMessageIndex != null && (_defaultEmergencyMessageIndex! < 0 || _defaultEmergencyMessageIndex! >= _emergencyMessages.length)) {
            _defaultEmergencyMessageIndex = null;
          }
        }
      } catch (_) {}

      notifyListeners();
      
      // Load UserModel after setting basic session data
      await loadUserModel();
    } else {
      print('No valid session found - user needs to sign in');
    }
  }

  // Emergency message persistence
  Future<void> setEmergencyMessage(String message) async {
    _emergencyMessage = message;
    final prefs = await SharedPreferences.getInstance();
    if (_userEmail != null) {
      await prefs.setString('emergency_message_${_userEmail!}', message);
    }
    if (_userEmail != null) {
      try {
        await _unifiedDataService.updateUserProfileWithMap(_userEmail!, {
          'emergency_message': message,
        });
      } catch (_) {}
    }
    notifyListeners();
  }

  // Multiple emergency messages CRUD (per-user)
  Future<void> addEmergencyMessage(String message, {bool makeDefault = false}) async {
    if (message.trim().isEmpty) return;
    _emergencyMessages.add(message.trim());
    if (makeDefault || _defaultEmergencyMessageIndex == null) {
      _defaultEmergencyMessageIndex = _emergencyMessages.length - 1;
      _emergencyMessage = _emergencyMessages[_defaultEmergencyMessageIndex!];
    }
    await _persistEmergencyMessages();
    notifyListeners();
  }

  Future<void> updateEmergencyMessage(int index, String message) async {
    if (index < 0 || index >= _emergencyMessages.length) return;
    _emergencyMessages[index] = message.trim();
    if (_defaultEmergencyMessageIndex == index) {
      _emergencyMessage = _emergencyMessages[index];
    }
    await _persistEmergencyMessages();
    notifyListeners();
  }

  Future<void> deleteEmergencyMessage(int index) async {
    if (index < 0 || index >= _emergencyMessages.length) return;
    _emergencyMessages.removeAt(index);
    if (_defaultEmergencyMessageIndex != null) {
      if (_emergencyMessages.isEmpty) {
        _defaultEmergencyMessageIndex = null;
        _emergencyMessage = null;
      } else if (index <= _defaultEmergencyMessageIndex!) {
        _defaultEmergencyMessageIndex = (_defaultEmergencyMessageIndex! - 1).clamp(0, _emergencyMessages.length - 1);
        _emergencyMessage = _emergencyMessages[_defaultEmergencyMessageIndex!];
      }
    }
    await _persistEmergencyMessages();
    notifyListeners();
  }

  Future<void> setDefaultEmergencyMessage(int index) async {
    if (index < 0 || index >= _emergencyMessages.length) return;
    _defaultEmergencyMessageIndex = index;
    _emergencyMessage = _emergencyMessages[index];
    await _persistEmergencyMessages();
    notifyListeners();
  }

  Future<void> _persistEmergencyMessages() async {
    if (_userEmail == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('emergency_messages_${_userEmail!}', jsonEncode(_emergencyMessages));
    if (_defaultEmergencyMessageIndex != null) {
      await prefs.setInt('emergency_message_default_index_${_userEmail!}', _defaultEmergencyMessageIndex!);
    } else {
      await prefs.remove('emergency_message_default_index_${_userEmail!}');
    }
    // Keep single message key in sync for legacy readers
    if (_emergencyMessage != null) {
      await prefs.setString('emergency_message_${_userEmail!}', _emergencyMessage!);
    } else {
      await prefs.remove('emergency_message_${_userEmail!}');
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
    
    // Load UserModel after setting basic session data
    await loadUserModel();
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
    
    // Load UserModel after setting basic session data
    await loadUserModel();
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
        
        // Load UserModel after setting basic session data
        await loadUserModel();
        
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
      // Use unified data service for logout
      if (_isAuthenticated && _userEmail != null) {
        await _unifiedDataService.logoutUser(_userEmail!);
      }
      
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
    _emergencyMessage = null;
    
    // Clear only session preferences, keep SQLite data intact
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_email');
    await prefs.remove('session_name');
    await prefs.remove('current_user');
    await prefs.remove('is_google_auth');
    await prefs.remove('address_setup_completed');
    
    print('✅ Sign out complete - session cleared, SQLite data preserved');
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
  
  // Update password using UnifiedDataService
  Future<void> updatePassword(String newPassword) async {
    if (_userEmail == null) return;
    
    try {
      final success = await _unifiedDataService.updatePassword(_userEmail!, newPassword);
      
      if (success) {
        print('✅ Password updated successfully: $_userEmail');
      } else {
        throw Exception('Failed to update password');
      }
    } catch (e) {
      print('❌ Error updating password: $e');
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
  
  // Unified login method using UnifiedDataService
  Future<bool> loginOffline(String email, String password) async {
    try {
      final userData = await _unifiedDataService.authenticateUser(email, password);
      
      if (userData != null) {
        // Update user session
        _isAuthenticated = true;
        _userEmail = email;
        _userName = '${userData['first_name']} ${userData['last_name']}'.trim();
        
        // Save session
        await _saveSession(email, _userName!);
        
        notifyListeners();
        print('✅ Login successful for: $email');
        return true;
      }
      
      return false;
    } catch (e) {
      print('❌ Login failed: $e');
      return false;
    }
  }
  
  // Unified signup method using UnifiedDataService
  Future<Map<String, dynamic>?> signupOffline({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
    required String address,
    required String region,
    required String province,
    required String city,
    required String barangay,
  }) async {
    try {
      // Use unified data service for consistent data handling
      final userData = await _unifiedDataService.createUser(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        street: address,
        region: region,
        province: province,
        city: city,
        barangay: barangay,
        
      );
      
      if (userData != null) {
        // Update user session
        _isAuthenticated = true;
        _userEmail = email;
        _userName = '$firstName $lastName';
        
        // Save session
        await _saveSession(email, _userName!);
        
        notifyListeners();
        print('✅ Signup successful for: $email');
        
        return userData;
      }
      
      return null;
    } catch (e) {
      print('❌ Signup failed: $e');
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
  
  // Update user profile using UnifiedDataService
  Future<void> updateUserProfile({
    required String firstName,
    required String lastName,
    required String address,
    required String phone,
    required String province,
    required String region,
    required String city,
    required String barangay,
  }) async {
    if (_userEmail == null) return;
    
    try {
      final fullName = '$firstName $lastName';
      
      // Use unified data service for consistent data handling
      final success = await _unifiedDataService.updateUserProfile(
        email: _userEmail!,
        firstName: firstName,
        lastName: lastName,
        street: address,
        region: region,
        city: city,
        barangay: barangay,
        province: province,
        phone: phone,
      );
      
      if (success) {
        // Update local state
        _userName = fullName;
        // Reload user model to get updated data
        await loadUserModel();
        notifyListeners();
        print('✅ Profile updated: $_userEmail');
      } else {
        throw Exception('Failed to update profile');
      }
      
    } catch (e) {
      print('❌ Error updating user profile: $e');
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
