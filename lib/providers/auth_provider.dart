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
  String? _username;
  String? _userName; // Display name (first + last)
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
  String? get username => _username;
  String? get userName => _userName; // Display name
  // Legacy getter for migration support
  @Deprecated('Use username instead')
  String? get userEmail => _username;
  UserModel? get currentUserModel => _currentUserModel;
  bool get hasSession => _isAuthenticated && _username != null;
  bool get twoFactorEnabled => _twoFactorEnabled;
  String? get emergencyMessage => _emergencyMessage;
  List<String> get emergencyMessages => List.unmodifiable(_emergencyMessages);
  int? get defaultEmergencyMessageIndex => _defaultEmergencyMessageIndex;

  // Method to update current user model
  void updateUser(UserModel user) {
    _currentUserModel = user;
    _currentUser = user.id;
    _username = user.username;
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
    if (_username == null) return;
    
    try {
      print('Loading UserModel for: $_username');
      
      // First try to get user data from SQLite
      final sqliteUser = await _sqliteService.getUserByUsername(_username!);
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
          id: sqliteUser['id']?.toString() ?? _username!,
          name: fullName.isNotEmpty ? fullName : (_userName ?? 'User'),
          username: sqliteUser['username']?.toString() ?? _username!,
          phone: sqliteUser['phone']?.toString(),
          street: sqliteUser['street']?.toString() ?? '', // Fixed: was 'address'
          region: sqliteUser['region']?.toString() ?? '',
          barangay: sqliteUser['barangay']?.toString() ?? '',
          city: finalCity,
          province: finalProvince,
          addressSetupCompleted: (sqliteUser['address_setup_completed'] ?? 0) == 1,
          isVerified: (sqliteUser['is_verified'] ?? 0) == 1,
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
      String? userUid;
      
      try {
        final userSnapshot = await firebaseService.database.ref('users').orderByChild('Username').equalTo(_username!).get();
        if (userSnapshot.exists) {
          print('Found user in Firebase by Username');
          final userData = userSnapshot.value as Map<dynamic, dynamic>;
          userUid = userData.keys.first as String;
          userEntry = userData.values.first as Map<dynamic, dynamic>;
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
          id: userEntry['ID']?.toString() ?? userEntry['id']?.toString() ?? userUid ?? _username!,
          name: fullName.isNotEmpty ? fullName : (userEntry['Name']?.toString() ?? userEntry['name']?.toString() ?? userEntry['DisplayName']?.toString() ?? _userName ?? 'User'),
          username: userEntry['Username']?.toString() ?? userEntry['username']?.toString() ?? _username!,
          phone: userEntry['Phone']?.toString() ?? userEntry['phone']?.toString(),
          street: userEntry['Street']?.toString() ?? userEntry['street']?.toString() ?? userEntry['Address']?.toString() ?? userEntry['address']?.toString() ?? '',
          region: userEntry['Region']?.toString() ?? userEntry['region']?.toString() ?? '',
          barangay: userEntry['Barangay']?.toString() ?? userEntry['barangay']?.toString() ?? '',
          city: userEntry['City']?.toString() ?? userEntry['city']?.toString() ?? '',
          province: userEntry['Province']?.toString() ?? userEntry['province']?.toString() ?? '',
          addressSetupCompleted: userEntry['AddressSetupCompleted'] == true || userEntry['addressSetupCompleted'] == true,
          isVerified: userEntry['isVerified'] == true || userEntry['IsVerified'] == true,
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
        id: _username!,
        name: _userName ?? 'User',
        username: _username!,
        addressSetupCompleted: false,
        isVerified: false,
      );
      
      _currentUserModel = userModel;
      print('Basic UserModel created: ${userModel.toString()}');
      notifyListeners();
      
    } catch (e) {
      print('Error loading UserModel: $e');
      // Create a fallback UserModel
      final userModel = UserModel(
        id: _username!,
        name: _userName ?? 'User',
        username: _username!,
        addressSetupCompleted: false,
        isVerified: false,
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
    if (_username == null) return false;
    final prefs = await SharedPreferences.getInstance();
    final hasCompletedTutorial = prefs.getBool('tutorial_completed_$_username') ?? false;
    return !hasCompletedTutorial;
  }

  // Mark tutorial as completed
  Future<void> markTutorialCompleted() async {
    if (_username == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_completed_$_username', true);
    print('Tutorial marked as completed for: $_username');
  }

  // Mark address setup as completed using UnifiedDataService
  Future<void> markAddressSetupCompleted() async {
    if (_username == null) return;
    
    try {
      final success = await _unifiedDataService.markAddressSetupCompleted(_username!);
      
      if (success) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('address_setup_completed_$_username', true);
        
        // Update current user model
        if (_currentUserModel != null) {
          _currentUserModel = _currentUserModel!.copyWith(addressSetupCompleted: true);
          notifyListeners();
        }
        
        print('✅ Address setup marked as completed for: $_username');
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
        });
        print('New SQLite user created for: $username');
      }
    } catch (e) {
      print('Error updating SQLite user password: $e');
    }
  }

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    // Support both legacy email and new username session keys
    final username = prefs.getString('session_username') ?? prefs.getString('session_email');
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
      _username = username;
      _userName = name ?? username;
      
      print('Using cached session data - Name: $_userName, Username: $_username');
      
      // Load emergency message(s) scoped to this user after we have _username
      try {
        if (_username != null) {
          _emergencyMessage = prefs.getString('emergency_message_${_username!}');
          // Load multiple messages list (JSON-encoded list)
          final rawList = prefs.getString('emergency_messages_${_username!}');
          if (rawList != null && rawList.isNotEmpty) {
            final decoded = jsonDecode(rawList);
            if (decoded is List) {
              _emergencyMessages = decoded.map((e) => e.toString()).toList();
            }
          }
          _defaultEmergencyMessageIndex = prefs.getInt('emergency_message_default_index_${_username!}');
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
    if (_username != null) {
      await prefs.setString('emergency_message_${_username!}', message);
    }
    if (_username != null) {
      try {
        await _unifiedDataService.updateUserProfileWithMap(_username!, {
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
    if (_username == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('emergency_messages_${_username!}', jsonEncode(_emergencyMessages));
    if (_defaultEmergencyMessageIndex != null) {
      await prefs.setInt('emergency_message_default_index_${_username!}', _defaultEmergencyMessageIndex!);
    } else {
      await prefs.remove('emergency_message_default_index_${_username!}');
    }
    // Keep single message key in sync for legacy readers
    if (_emergencyMessage != null) {
      await prefs.setString('emergency_message_${_username!}', _emergencyMessage!);
    } else {
      await prefs.remove('emergency_message_${_username!}');
    }
  }

  // SSO removed - deprecated
  @Deprecated('SSO removed')
  Future<void> _refreshGoogleUserData() async {
    // SSO removed - no longer needed
    return;
  }

  // Set authenticated user directly (used after real auth via Firebase/SQLite)
  Future<void> setAuthenticated({required String username, required String name}) async {
    _isAuthenticated = true;
    _currentUser = username;
    _username = username;
    _userName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_username', _username!);
    await prefs.setString('session_name', _userName!);
    // Keep legacy session_email for migration support
    await prefs.setString('session_email', _username!);
    print('Session saved - Name: $_userName, Username: $_username');
    
    // Load user model immediately after authentication to ensure profile data is available
    await loadUserModel();
    
    notifyListeners();
  }

  // Validate session persistence
  Future<bool> validateSession() async {
    if (!_isAuthenticated || _username == null) {
      print('Session validation failed - not authenticated');
      return false;
    }
    
    final prefs = await SharedPreferences.getInstance();
    final cachedUsername = prefs.getString('session_username') ?? prefs.getString('session_email');
    final cachedName = prefs.getString('session_name');
    
    if (cachedUsername != _username || cachedName != _userName) {
      print('Session validation failed - cached data mismatch');
      return false;
    }
    
    print('Session validation successful - Name: $_userName, Username: $_username');
    return true;
  }

  // Force refresh user data from Firebase
  Future<void> refreshUserData() async {
    if (_isAuthenticated && _username != null) {
      await loadUserModel();
      notifyListeners();
    }
  }
  
  Future<void> signIn(String username, String password) async {
    // Validate only registered users
    final stored = _registeredUsers[username];
    if (stored == null || stored != password) {
      throw Exception('Account not found. Please sign up first.');
    }
    _isAuthenticated = true;
    _currentUser = username;
    _username = username;
    _userName = username;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_username', _username!);
    await prefs.setString('session_name', _userName!);
    await prefs.setString('session_email', _username!); // Legacy support
    notifyListeners();
    
    // Load UserModel after setting basic session data
    await loadUserModel();
  }
  
  Future<void> signUp(String username, String password, String displayName) async {
    // Register and create session
    _registeredUsers[username] = password;
    _isAuthenticated = true;
    _currentUser = username;
    _username = username;
    _userName = displayName.isNotEmpty ? displayName : username;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_username', _username!);
    await prefs.setString('session_name', _userName!);
    await prefs.setString('session_email', _username!); // Legacy support
    notifyListeners();
    
    // Load UserModel after setting basic session data
    await loadUserModel();
  }
  
  // SSO removed - deprecated
  @Deprecated('SSO removed - use username + password authentication')
  Future<void> signInWithGoogle() async {
    // SSO removed
    return;
  }

  // 2FA removed - deprecated
  @Deprecated('2FA not implemented for username auth')
  Future<void> signInWithTwoFactor(String username, String password, String verificationCode) async {
    // 2FA not implemented
    throw Exception('Two-factor authentication not implemented');
  }

  Future<bool> checkTwoFactorRequired(String username) async {
    try {
      // 2FA not implemented for username auth
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
      if (_isAuthenticated && _username != null) {
        await _unifiedDataService.logoutUser(_username!);
      }
      
      // Sign out from Firebase if authenticated
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
    _username = null;
    _userName = null;
    _emergencyMessage = null;
    
    // Clear only session preferences, keep SQLite data intact
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_username');
    await prefs.remove('session_email'); // Legacy
    await prefs.remove('session_name');
    await prefs.remove('current_user');
    await prefs.remove('address_setup_completed');
    
    print('✅ Sign out complete - session cleared, SQLite data preserved');
    notifyListeners();
  }
  
  void updateProfile(String name, String username) {
    _userName = name;
    _username = username;
    notifyListeners();
  }
  
  // Verify current password for sign-up accounts
  Future<bool> verifyCurrentPassword(String password) async {
    if (_username == null) return false;
    
    try {
      final hashedPassword = _hashPassword(password);
      
      // First check SQLite (offline)
      final sqliteUser = await _sqliteService.getUserByUsername(_username!);
      if (sqliteUser != null && sqliteUser['password'] == hashedPassword) {
        print('Password verified from SQLite (offline)');
        return true;
      }
      
      // If not found in SQLite, check Firebase (online)
      final firebaseService = FirebaseService();
      final userSnapshot = await firebaseService.database.ref('users').orderByChild('Username').equalTo(_username!).get();
      
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
          await _updateSQLiteUserPassword(_username!, hashedPassword);
        }
        
        return validPassword;
      }
      
      return false;
    } catch (e) {
      print('Error verifying password: $e');
      // Fallback to SQLite only if Firebase fails
      try {
        final sqliteUser = await _sqliteService.getUserByUsername(_username!);
        return sqliteUser != null && sqliteUser['password'] == _hashPassword(password);
      } catch (sqliteError) {
        print('SQLite fallback also failed: $sqliteError');
        return false;
      }
    }
  }
  
  // Update password using UnifiedDataService
  Future<void> updatePassword(String newPassword) async {
    if (_username == null) return;
    
    try {
      final success = await _unifiedDataService.updatePassword(_username!, newPassword);
      
      if (success) {
        print('✅ Password updated successfully: $_username');
      } else {
        throw Exception('Failed to update password');
      }
    } catch (e) {
      print('❌ Error updating password: $e');
      throw Exception('Failed to update password: $e');
    }
  }
  
  // SSO removed - deprecated
  // SSO removed - deprecated
  @Deprecated('SSO removed - use username + password authentication')
  Future<void> createPasswordForGoogleAccount(String password) async {
    // SSO removed
    return;
  }
  
  // SSO removed - deprecated
  @Deprecated('SSO removed')
  Future<bool> get hasPasswordSet async {
    // SSO removed - always return false
    return false;
  }
  
  // Unified login method using UnifiedDataService
  Future<bool> loginOffline(String username, String password) async {
    try {
      final userData = await _unifiedDataService.authenticateUser(username, password);
      
      if (userData != null) {
        // Update user session
        _isAuthenticated = true;
        _username = username;
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
  
  // Unified signup method using UnifiedDataService
  Future<Map<String, dynamic>?> signupOffline({
    required String username,
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
        username: username,
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
        _username = username;
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
  
  // SSO removed - deprecated
  @Deprecated('SSO removed')
  bool get isGmailSSO {
    return false; // SSO removed
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
    await prefs.setString('session_username', username);
    await prefs.setString('session_name', name);
    // Keep legacy session_email for migration support
    await prefs.setString('session_email', username);
    
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
    if (_username == null) {
      print('❌ No username - not a new user');
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
      final userCreatedAtStr = prefs.getString('user_created_at_$_username');
      print('🔍 User creation timestamp: $userCreatedAtStr');
      
      if (userCreatedAtStr == null) {
        // No creation timestamp means this is an existing user from before tutorial implementation
        print('❌ No creation timestamp - existing user');
        return false;
      }
      
      // User has creation timestamp and tutorial not completed = new user
      print('✅ User $_username is new (has creation timestamp, tutorial not completed)');
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
    required String phone,
    required String province,
    required String region,
    required String city,
    required String barangay,
  }) async {
    if (_username == null) return;
    
    try {
      final fullName = '$firstName $lastName';
      
      // Use unified data service for consistent data handling
      final success = await _unifiedDataService.updateUserProfile(
        username: _username!,
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
        print('✅ Profile updated: $_username');
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
          final username = user['username'] ?? user['firebase_uid'] ?? '';
          if (username.isNotEmpty) {
            await firebaseService.database.ref('users/$username').update({
              'FirstName': user['first_name'],
              'LastName': user['last_name'],
              'Username': username,
              'Address': user['street'] ?? user['address'] ?? '',
              'Region': user['region'],
              'City': user['city'],
              'Barangay': user['barangay'],
              'lastSeen': DateTime.now().millisecondsSinceEpoch,
            });
            
            // Mark as synced
            await _sqliteService.updateUser(user['id'], {
              'is_synced': 1,
              'last_seen': DateTime.now().millisecondsSinceEpoch,
            });
            print('Synced user: $username');
          }
        } catch (e) {
          print('Failed to sync user ${user['username'] ?? user['id']}: $e');
          // Continue with next user
        }
      }
    } catch (e) {
      print('Error during background sync: $e');
    }
  }
}
