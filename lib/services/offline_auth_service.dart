import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sqlite_service.dart';

class OfflineAuthService {
  static final OfflineAuthService _instance = OfflineAuthService._internal();
  factory OfflineAuthService() => _instance;
  OfflineAuthService._internal();

  final SQLiteService _sqliteService = SQLiteService();

  // Current user
  Map<String, dynamic>? _currentUser;
  Map<String, dynamic>? get currentUser => _currentUser;

  // Initialize offline auth
  Future<void> initialize() async {
    await _sqliteService.database;
  }

  // Offline sign up (deprecated - use biometric verification screen instead)
  @Deprecated('Use biometric verification screen for registration')
  Future<Map<String, dynamic>> signUpOffline({
    required String firstName,
    required String lastName,
    required String username, // Replaced email with username
    required String address,
    required String region,
    required String city,
    required String barangay,
    required String password,
  }) async {
    try {
      // Check if user already exists
      final existingUser = await _sqliteService.getUserByUsername(username);
      if (existingUser != null) {
        throw Exception('User with this username already exists');
      }

      // Hash password
      final hashedPassword = _hashPassword(password);

      // Create user data
      final userData = {
        'first_name': firstName,
        'last_name': lastName,
        'username': username, // Replaced email with username
        'street': address,
        'region': region,
        'city': city,
        'barangay': barangay,
        'password': hashedPassword,
        'is_online': 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'is_synced': 0,
        'is_verified': 1, // Biometric verification completed
      };

      // Save to SQLite
      final userId = await _sqliteService.insertUser(userData);
      
      // Get the created user
      final user = await _sqliteService.getUserById(userId);
      if (user != null) {
        _currentUser = user;
        await _saveCurrentUser(user);
        
        // User saved to SQLite (offline-only)
        
        return user;
      } else {
        throw Exception('Failed to create user');
      }
    } catch (e) {
      throw Exception('Sign up failed: ${e.toString()}');
    }
  }

  // Offline sign in
  Future<Map<String, dynamic>> signInOffline({
    required String username, // Replaced email with username
    required String password,
  }) async {
    try {
      // Get user from SQLite
      final user = await _sqliteService.getUserByUsername(username);
      if (user == null) {
        throw Exception('User not found');
      }

      // Verify password
      final hashedPassword = _hashPassword(password);
      if (user['password'] != hashedPassword) {
        throw Exception('Invalid password');
      }

      // Update last seen - use UID if id is null
      final userId = user['id'];
      final userUid = user['uid']?.toString();
      
      if (userUid != null && userUid.isNotEmpty) {
        await _sqliteService.updateUserByUid(userUid, {
          'last_seen': DateTime.now().millisecondsSinceEpoch,
          'is_online': 1,
        });
      } else if (userId != null) {
        await _sqliteService.updateUser(userId, {
          'last_seen': DateTime.now().millisecondsSinceEpoch,
          'is_online': 1,
        });
      } else {
        print('⚠️ Warning: User has no id or uid, cannot update last_seen');
      }
      
      // Ensure id is set in user object
      if (user['id'] == null && userUid != null) {
        // Try to get id from database
        final updatedUser = await _sqliteService.getUserByUsername(username);
        if (updatedUser != null && updatedUser['id'] != null) {
          user['id'] = updatedUser['id'];
        }
      }

      _currentUser = user;
      await _saveCurrentUser(user);
      
      return user;
    } catch (e) {
      throw Exception('Sign in failed: ${e.toString()}');
    }
  }

  // Sign out
  Future<void> signOut() async {
    if (_currentUser != null) {
      // Update user offline status - use UID if id is null
      final userId = _currentUser!['id'];
      final userUid = _currentUser!['uid']?.toString();
      
      if (userUid != null && userUid.isNotEmpty) {
        await _sqliteService.updateUserByUid(userUid, {
          'is_online': 0,
          'last_seen': DateTime.now().millisecondsSinceEpoch,
        });
      } else if (userId != null) {
        await _sqliteService.updateUser(userId, {
          'is_online': 0,
          'last_seen': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        print('⚠️ Warning: User has no id or uid, cannot update offline status');
      }
    }
    
    _currentUser = null;
    await _clearCurrentUser();
  }

  // Hash password
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Save current user to SharedPreferences
  Future<void> _saveCurrentUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user', jsonEncode(user));
  }

  // Get current user from SharedPreferences
  Future<Map<String, dynamic>?> _getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('current_user');
    if (userString != null) {
      return Map<String, dynamic>.from(jsonDecode(userString));
    }
    return null;
  }

  // Clear current user from SharedPreferences
  Future<void> _clearCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
  }


  // Check if user is signed in
  Future<bool> isSignedIn() async {
    if (_currentUser != null) return true;
    
    final user = await _getCurrentUser();
    if (user != null) {
      _currentUser = user;
      return true;
    }
    
    return false;
  }

  // Get current user ID
  int? get currentUserId => _currentUser?['id'];

  // Get current user username
  String? get currentUserUsername => _currentUser?['username'];
  
  // Legacy method for migration
  @Deprecated('Use currentUserUsername instead')
  String? get currentUserEmail => _currentUser?['username'];

  // Get current user name
  String? get currentUserName => '${_currentUser?['first_name']} ${_currentUser?['last_name']}';
}
