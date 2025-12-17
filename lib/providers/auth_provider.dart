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
  String? _userUsername; // Replaced _userEmail with _userUsername
  String? _userName;
  bool _twoFactorEnabled = false;
  UserModel? _currentUserModel;
  String? _emergencyMessage;
  List<String> _emergencyMessages = [];
  int? _defaultEmergencyMessageIndex;
  final Map<String, String> _registeredUsers = {}; // username -> password (demo)
  final TwoFactorAuthService _twoFactorService = TwoFactorAuthService();
  final SQLiteService _sqliteService = SQLiteService();
  final UnifiedDataService _unifiedDataService = UnifiedDataService();
  
  bool get isAuthenticated => _isAuthenticated;
  String? get currentUser => _currentUser;
  String? get userUsername => _userUsername; // Replaced userEmail with userUsername
  String? get userName => _userName;
  UserModel? get currentUserModel => _currentUserModel;
  bool get hasSession => _isAuthenticated && _userUsername != null;
  bool get twoFactorEnabled => _twoFactorEnabled;
  String? get emergencyMessage => _emergencyMessage;
  List<String> get emergencyMessages => List.unmodifiable(_emergencyMessages);
  int? get defaultEmergencyMessageIndex => _defaultEmergencyMessageIndex;

  // Legacy getter for migration
  @Deprecated('Use userUsername instead')
  String? get userEmail => _userUsername;

  // Method to update current user model
  void updateUser(UserModel user) {
    _currentUserModel = user;
    _currentUser = user.id;
    _userUsername = user.username; // Replaced email with username
    _userName = user.name;
    
    notifyListeners();
  }

  // Helper method to parse timestamp from various formats
  int _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return 0;
    
    try {
      int ts = 0;
      
      // Handle different types
      if (timestamp is int) {
        ts = timestamp;
      } else if (timestamp is String) {
        ts = int.tryParse(timestamp) ?? 0;
      } else if (timestamp is double) {
        ts = timestamp.toInt();
      } else {
        return 0;
      }
      
      // If timestamp is less than a reasonable date (year 2000 in milliseconds),
      // it's likely in seconds, so convert to milliseconds
      if (ts > 0 && ts < 946684800000) { // Jan 1, 2000 in milliseconds
        ts = ts * 1000;
      }
      
      return ts;
    } catch (e) {
      print('Error parsing timestamp: $e');
      return 0;
    }
  }

  // Method to load user data and create UserModel
  Future<void> loadUserModel() async {
    if (_userUsername == null) return;
    
    try {
      print('Loading UserModel for: $_userUsername');
      
      // First try to get user data from SQLite
      final sqliteUser = await _sqliteService.getUserByUsername(_userUsername!);
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
          id: sqliteUser['id']?.toString() ?? _userUsername!,
          name: fullName.isNotEmpty ? fullName : (_userName ?? 'User'),
          username: sqliteUser['username']?.toString() ?? _userUsername!, // Replaced email with username
          street: sqliteUser['street']?.toString() ?? '',
          region: sqliteUser['region']?.toString() ?? '',
          barangay: sqliteUser['barangay']?.toString() ?? '',
          city: finalCity,
          province: finalProvince,
          phoneNumber: sqliteUser['phone_number']?.toString() ?? sqliteUser['phone']?.toString(),
          addressSetupCompleted: (sqliteUser['address_setup_completed'] ?? 0) == 1,
          isOnline: (sqliteUser['is_online'] ?? 0) == 1,
          createdAt: _parseTimestamp(sqliteUser['created_at'] ?? 0),
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
      
      // Try to get user by username
      Map<dynamic, dynamic>? userEntry;
      
      try {
        final userSnapshot = await firebaseService.database.ref('users/$_userUsername').get();
        if (userSnapshot.exists) {
          print('Found user in Firebase by Username');
          userEntry = userSnapshot.value as Map<dynamic, dynamic>;
        }
      } catch (e) {
        print('Error getting user by Username: $e');
      }
      
      if (userEntry != null) {
        // Combine first and last name for Firebase (handle both PascalCase and camelCase)
        final firstName = userEntry['FirstName']?.toString() ?? userEntry['firstName']?.toString() ?? '';
        final lastName = userEntry['LastName']?.toString() ?? userEntry['lastName']?.toString() ?? '';
        final fullName = '$firstName $lastName'.trim();
        
        final userModel = UserModel(
          id: userEntry['ID']?.toString() ?? userEntry['id']?.toString() ?? _userUsername!,
          name: fullName.isNotEmpty ? fullName : (userEntry['Name']?.toString() ?? userEntry['name']?.toString() ?? userEntry['DisplayName']?.toString() ?? _userName ?? 'User'),
          username: userEntry['Username']?.toString() ?? userEntry['username']?.toString() ?? userEntry['Email']?.toString() ?? _userUsername!, // Support migration
          street: userEntry['Street']?.toString() ?? userEntry['street']?.toString() ?? userEntry['Address']?.toString() ?? userEntry['address']?.toString() ?? '',
          region: userEntry['Region']?.toString() ?? userEntry['region']?.toString() ?? '',
          barangay: userEntry['Barangay']?.toString() ?? userEntry['barangay']?.toString() ?? '',
          city: userEntry['City']?.toString() ?? userEntry['city']?.toString() ?? '',
          province: userEntry['Province']?.toString() ?? userEntry['province']?.toString() ?? '',
          phoneNumber: userEntry['PhoneNumber']?.toString() ?? userEntry['phoneNumber']?.toString() ?? userEntry['phone']?.toString(),
          addressSetupCompleted: userEntry['AddressSetupCompleted'] == true || userEntry['addressSetupCompleted'] == true,
          isOnline: userEntry['IsOnline'] == true || userEntry['isOnline'] == true,
          createdAt: _parseTimestamp(userEntry['createdAt'] ?? userEntry['CreatedAt'] ?? 0),
        );
        
        _currentUserModel = userModel;
        print('UserModel created from Firebase data: ${userModel.toString()}');
        notifyListeners();
        return;
      }
      
      // If not found in either, create a basic UserModel with available data
      print('User not found in SQLite or Firebase, creating basic UserModel');
      final userModel = UserModel(
        id: _userUsername!,
        name: _userName ?? 'User',
        username: _userUsername!, // Replaced email with username
        addressSetupCompleted: false,
      );
      
      _currentUserModel = userModel;
      print('Basic UserModel created: ${userModel.toString()}');
      notifyListeners();
      
    } catch (e) {
      print('Error loading UserModel: $e');
      // Create a fallback UserModel
      final userModel = UserModel(
        id: _userUsername!,
        name: _userName ?? 'User',
        username: _userUsername!, // Replaced email with username
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
    return !_currentUserModel!.addressSetupCompleted;
  }

  // Check if tutorial is required for current user
  Future<bool> isTutorialRequired() async {
    if (_userUsername == null) return false;
    final prefs = await SharedPreferences.getInstance();
    final hasCompletedTutorial = prefs.getBool('tutorial_completed_$_userUsername') ?? false;
    return !hasCompletedTutorial;
  }

  // Mark tutorial as completed
  Future<void> markTutorialCompleted() async {
    if (_userUsername == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_completed_$_userUsername', true);
    print('Tutorial marked as completed for: $_userUsername');
  }

  // Mark address setup as completed using UnifiedDataService
  Future<void> markAddressSetupCompleted() async {
    if (_userUsername == null) return;
    
    try {
      final success = await _unifiedDataService.markAddressSetupCompleted(_userUsername!);
      
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('address_setup_completed_$_userUsername', true);
        
        // Update current user model
        if (_currentUserModel != null) {
          _currentUserModel = _currentUserModel!.copyWith(addressSetupCompleted: true);
          notifyListeners();
        }
        
        print('✅ Address setup marked as completed for: $_userUsername');
      } else {
        throw Exception('Failed to mark address setup as completed');
      }
    } catch (e) {
      print('❌ Error marking address setup completed: $e');
      throw Exception('Failed to mark address setup as completed: $e');
    }
  }

  // Helper method to update SQLite user password
  Future<void> _updateSQLiteUserPassword(String username, String hashedPassword) async {
    try {
      final sqliteUser = await _sqliteService.getUserByUsername(username);
      if (sqliteUser != null) {
        await _sqliteService.updateUser(sqliteUser['id'], {
          'password': hashedPassword,
          'last_seen': DateTime.now().millisecondsSinceEpoch,
        });
        print('SQLite user password updated for: $username');
      } else {
        // Create new user entry in SQLite if not exists
        await _sqliteService.insertUser({
          'username': username,
          'first_name': _userName?.split(' ').first ?? 'User',
          'last_name': _userName?.split(' ').skip(1).join(' ') ?? '',
          'password': hashedPassword,
          'street': '',
          'region': '',
          'city': '',
          'barangay': '',
          'is_online': 1,
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'last_seen': DateTime.now().millisecondsSinceEpoch,
          'is_synced': 0,
          'is_verified': 1,
        });
        print('New SQLite user created for: $username');
      }
    } catch (e) {
      print('Error updating SQLite user password: $e');
    }
  }

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('session_username') ?? prefs.getString('session_email'); // Support migration
    final name = prefs.getString('session_name');
    
    print('Loading session - Username: $username, Name: $name');
    
    // Check if this is a fresh app start (no session data)
    if (username == null || username.isEmpty) {
      print('No session data found - user not logged in');
      return;
    }
    
    if (username.isNotEmpty) {
      // Use cached data - this ensures persistence
      _isAuthenticated = true;
      _currentUser = username;
      _userUsername = username; // Replaced _userEmail with _userUsername
      _userName = name ?? username;
      
      print('Using cached session data - Name: $_userName, Username: $_userUsername');
      
      // Load emergency message(s) scoped to this user
      try {
        if (_userUsername != null) {
          _emergencyMessage = prefs.getString('emergency_message_${_userUsername!}');
          // Load multiple messages list (JSON-encoded list)
          final rawList = prefs.getString('emergency_messages_${_userUsername!}');
          if (rawList != null && rawList.isNotEmpty) {
            final decoded = jsonDecode(rawList);
            if (decoded is List) {
              _emergencyMessages = decoded.map((e) => e.toString()).toList();
            }
          }
          _defaultEmergencyMessageIndex = prefs.getInt('emergency_message_default_index_${_userUsername!}');
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
    if (_userUsername != null) {
      await prefs.setString('emergency_message_${_userUsername!}', message);
    }
    if (_userUsername != null) {
      try {
        await _unifiedDataService.updateUserProfileWithMap(_userUsername!, {
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
    if (_userUsername == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('emergency_messages_${_userUsername!}', jsonEncode(_emergencyMessages));
    if (_defaultEmergencyMessageIndex != null) {
      await prefs.setInt('emergency_message_default_index_${_userUsername!}', _defaultEmergencyMessageIndex!);
    } else {
      await prefs.remove('emergency_message_default_index_${_userUsername!}');
    }
    // Keep single message key in sync for legacy readers
    if (_emergencyMessage != null) {
      await prefs.setString('emergency_message_${_userUsername!}', _emergencyMessage!);
    } else {
      await prefs.remove('emergency_message_${_userUsername!}');
    }
  }

  // Set authenticated user directly (used after real auth via Firebase/SQLite)
  Future<void> setAuthenticated({required String email, required String name}) async {
    // Note: 'email' parameter name kept for compatibility, but it's actually username now
    _isAuthenticated = true;
    _currentUser = email; // This is actually username
    _userUsername = email; // Replaced _userEmail with _userUsername
    _userName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_username', _userUsername!); // New key
    await prefs.setString('session_email', _userUsername!); // Keep for migration
    await prefs.setString('session_name', _userName!);
    print('Session saved - Name: $_userName, Username: $_userUsername');
    
    // Load user model immediately after authentication to ensure profile data is available
    await loadUserModel();
    
    notifyListeners();
  }

  // Validate session persistence
  Future<bool> validateSession() async {
    if (!_isAuthenticated || _userUsername == null) {
      print('Session validation failed - not authenticated');
      return false;
    }
    
    final prefs = await SharedPreferences.getInstance();
    final cachedUsername = prefs.getString('session_username') ?? prefs.getString('session_email');
    final cachedName = prefs.getString('session_name');
    
    if (cachedUsername != _userUsername || cachedName != _userName) {
      print('Session validation failed - cached data mismatch');
      return false;
    }
    
    print('Session validation successful - Name: $_userName, Username: $_userUsername');
    return true;
  }
  
  // Legacy methods - DEPRECATED
  @Deprecated('Use loginOffline instead')
  Future<void> signIn(String email, String password) async {
    // This method is deprecated - use loginOffline with username instead
    throw Exception('This method is deprecated. Use loginOffline with username instead.');
  }
  
  @Deprecated('Use biometric verification screen for registration')
  Future<void> signUp(String email, String password, String username) async {
    // This method is deprecated - registration now uses biometric verification
    throw Exception('This method is deprecated. Registration now uses biometric verification screen.');
  }
  
  @Deprecated('Google Sign-In is no longer supported')
  Future<void> signInWithGoogle() async {
    throw Exception('Google Sign-In is no longer supported. Please use username + password authentication.');
  }

  @Deprecated('Two-factor authentication is no longer supported')
  Future<void> signInWithTwoFactor(String email, String password, String verificationCode) async {
    throw Exception('Two-factor authentication is no longer supported.');
  }

  @Deprecated('Two-factor authentication is no longer supported')
  Future<bool> checkTwoFactorRequired(String email) async {
    return false;
  }

  Future<void> signOut() async {
    try {
      // Use unified data service for logout
      if (_isAuthenticated && _userUsername != null) {
        await _unifiedDataService.logoutUser(_userUsername!);
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
    _userUsername = null; // Replaced _userEmail with _userUsername
    _userName = null;
    _emergencyMessage = null;
    
    // Clear only session preferences, keep SQLite data intact
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_username');
    await prefs.remove('session_email'); // Keep for migration cleanup
    await prefs.remove('session_name');
    await prefs.remove('current_user');
    await prefs.remove('address_setup_completed');
    
    print('✅ Sign out complete - session cleared, SQLite data preserved');
    notifyListeners();
  }
  
  void updateProfile(String name, String username) {
    _userName = name;
    _userUsername = username; // Replaced email with username
    notifyListeners();
  }
  
  // Verify current password for sign-up accounts
  Future<bool> verifyCurrentPassword(String password) async {
    if (_userUsername == null) return false;
    
    try {
      final hashedPassword = _hashPassword(password);
      
      // First check SQLite (offline)
      final sqliteUser = await _sqliteService.getUserByUsername(_userUsername!);
      if (sqliteUser != null && sqliteUser['password'] == hashedPassword) {
        print('Password verified from SQLite (offline)');
        return true;
      }
      
      // If not found in SQLite, check Firebase (online)
      final firebaseService = FirebaseService();
      final userSnapshot = await firebaseService.database.ref('users/$_userUsername').get();
      
      if (userSnapshot.exists) {
        final user = userSnapshot.value as Map;
        if (user['Password'] == hashedPassword) {
          print('Password verified from Firebase (online)');
          // Update SQLite with the verified password for offline access
          await _updateSQLiteUserPassword(_userUsername!, hashedPassword);
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('Error verifying password: $e');
      // Fallback to SQLite only if Firebase fails
      try {
        final sqliteUser = await _sqliteService.getUserByUsername(_userUsername!);
        return sqliteUser != null && sqliteUser['password'] == _hashPassword(password);
      } catch (sqliteError) {
        print('SQLite fallback also failed: $sqliteError');
        return false;
      }
    }
  }
  
  // Update password using UnifiedDataService
  Future<void> updatePassword(String newPassword) async {
    if (_userUsername == null) return;
    
    try {
      final success = await _unifiedDataService.updatePassword(_userUsername!, newPassword);
      
      if (success) {
        print('✅ Password updated successfully: $_userUsername');
      } else {
        throw Exception('Failed to update password');
      }
    } catch (e) {
      print('❌ Error updating password: $e');
      throw Exception('Failed to update password: $e');
    }
  }
  
  // Unified login method using UnifiedDataService
  Future<bool> loginOffline(String username, String password) async {
    try {
      final userData = await _unifiedDataService.authenticateUser(username, password);
      
      if (userData != null) {
        // Update user session
        _isAuthenticated = true;
        _userUsername = username; // Replaced email with username
        _userName = '${userData['first_name']} ${userData['last_name']}'.trim();
        
        // Save session
        await _saveSession(username, _userName!);
        
        // Load user model immediately after authentication to ensure profile data is available
        await loadUserModel();
        
        notifyListeners();
        print('✅ Login successful for: $username');
        return true;
      }
      
      return false;
    } catch (e) {
      print('❌ Login failed: $e');
      return false;
    }
  }
  
  // Unified signup method using UnifiedDataService (deprecated - use biometric verification screen)
  @Deprecated('Use biometric verification screen for registration')
  Future<Map<String, dynamic>?> signupOffline({
    required String username, // Replaced email with username
    required String password,
    required String firstName,
    required String lastName,
    required String address,
    required String region,
    required String province,
    required String city,
    required String barangay,
  }) async {
    try {
      // Use unified data service for consistent data handling
      final userData = await _unifiedDataService.createUser(
        username: username, // Replaced email with username
        password: password,
        firstName: firstName,
        lastName: lastName,
        street: address,
        region: region,
        province: province,
        city: city,
        barangay: barangay,
      );
      
      if (userData != null) {
        // Update user session
        _isAuthenticated = true;
        _userUsername = username; // Replaced email with username
        _userName = '$firstName $lastName';
        
        // Save session
        await _saveSession(username, _userName!);
        
        notifyListeners();
        print('✅ Signup successful for: $username');
        
        return userData;
      }
      
      return null;
    } catch (e) {
      print('❌ Signup failed: $e');
      return null;
    }
  }
  
  // Hash password using SHA-256
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  // Save session to SharedPreferences
  Future<void> _saveSession(String username, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_username', username); // New key
    await prefs.setString('session_email', username); // Keep for migration
    await prefs.setString('session_name', name);
    
    // Check if this is a new user (first time signing in)
    final existingUserCreatedAt = prefs.getString('user_created_at_$username');
    if (existingUserCreatedAt == null) {
      await prefs.setString('user_created_at_$username', DateTime.now().millisecondsSinceEpoch.toString());
      print('New user detected: $username');
    } else {
      print('Existing user: $username');
    }
    
    print('Session saved: $username');
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
    if (_userUsername == null) {
      print('❌ No user username - not a new user');
      return false;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check if user has completed tutorial
      final tutorialCompleted = prefs.getBool('tutorial_completed_$_userUsername') ?? false;
      print('🔍 Tutorial completed: $tutorialCompleted');
      
      // If tutorial is completed, user is not new
      if (tutorialCompleted) {
        print('❌ Tutorial already completed - not a new user');
        return false;
      }
      
      // Check if user has a creation timestamp
      final userCreatedAtStr = prefs.getString('user_created_at_$_userUsername');
      print('🔍 User creation timestamp: $userCreatedAtStr');
      
      if (userCreatedAtStr == null) {
        // No creation timestamp means this is an existing user from before tutorial implementation
        print('❌ No creation timestamp - existing user');
        return false;
      }
      
      // User has creation timestamp and tutorial not completed = new user
      print('✅ User $_userUsername is new (has creation timestamp, tutorial not completed)');
      return true;
    } catch (e) {
      print('❌ Error checking if user is new: $e');
      return false; // Default to existing user if error
    }
  }
  
  // Mark user as synced with Firebase
  Future<void> markUserAsSynced(String username) async {
    try {
      final sqliteUser = await _sqliteService.getUserByUsername(username);
      if (sqliteUser != null) {
        await _sqliteService.updateUser(sqliteUser['id'], {
          'is_synced': 1,
          'last_seen': DateTime.now().millisecondsSinceEpoch,
        });
        print('User marked as synced: $username');
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
    required String province,
    required String region,
    required String city,
    required String barangay,
  }) async {
    if (_userUsername == null) return;
    
    try {
      final fullName = '$firstName $lastName';
      
      // Use unified data service for consistent data handling
      final success = await _unifiedDataService.updateUserProfile(
        username: _userUsername!, // Replaced email with username
        firstName: firstName,
        lastName: lastName,
        street: address,
        region: region,
        city: city,
        barangay: barangay,
        province: province,
      );
      
      if (success) {
        // Update local state
        _userName = fullName;
        // Reload user model to get updated data
        await loadUserModel();
        notifyListeners();
        print('✅ Profile updated: $_userUsername');
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
          final username = user['username'] ?? user['email']; // Support migration
          await firebaseService.database.ref('users/$username').update({
            'FirstName': user['first_name'],
            'LastName': user['last_name'],
            'Username': username,
            'Address': user['street'] ?? user['address'],
            'Region': user['region'],
            'Province': user['province'] ?? '',
            'City': user['city'],
            'Barangay': user['barangay'],
            'lastSeen': DateTime.now().millisecondsSinceEpoch,
          });
          
          // Mark as synced
          await _sqliteService.updateUser(user['id'], {
            'firebase_uid': username,
            'is_synced': 1,
            'sync_timestamp': DateTime.now().millisecondsSinceEpoch,
            'last_seen': DateTime.now().millisecondsSinceEpoch,
          });
          print('Synced user: $username');
        } catch (e) {
          final username = user['username'] ?? user['email'];
          print('Failed to sync user $username: $e');
          // Continue with next user
        }
      }
    } catch (e) {
      print('Error during background sync: $e');
    }
  }
}
