import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sqlite_service.dart';
import '../providers/chat_provider.dart';

/// Unified data service that uses SQLite as primary database (offline-only)
/// All data operations go through this service to ensure consistency
class UnifiedDataService {
  static final UnifiedDataService _instance = UnifiedDataService._internal();
  factory UnifiedDataService() => _instance;
  UnifiedDataService._internal();

  final SQLiteService _sqliteService = SQLiteService();
  
  // Stream controllers for real-time updates
  final StreamController<Map<String, dynamic>> _userUpdateController = StreamController.broadcast();
  
  Stream<Map<String, dynamic>> get userUpdates => _userUpdateController.stream;
  
  /// Initialize the service
  Future<void> initialize() async {
    // Service initialized - no sync needed for offline-only app
  }
  
  // ========== USER OPERATIONS ==========
  
  /// Generate unique UID for new user
  String _generateUid() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final micros = DateTime.now().microsecondsSinceEpoch;
    final randomStr = List.generate(12, (i) => chars[(timestamp + micros + i) % chars.length]).join();
    return randomStr;
  }
  
  /// Create a new user (SQLite only - pure offline)
  Future<Map<String, dynamic>?> createUser({
    required String username, // Replaced email with username
    required String password,
    required String firstName,
    required String lastName,
    String? street,
    String? region,
    String? province,
    String? city,
    String? barangay,
  }) async {
    try {
      // Check if user already exists
      final existingUser = await _sqliteService.getUserByUsername(username);
      if (existingUser != null) {
        // If user exists, update their profile instead of creating new
        await updateUserProfileWithMap(username, {
          'street': street ?? '',
          'region': region ?? '',
          'province': province ?? '',
          'city': city ?? '',
          'barangay': barangay ?? '',
        });
        return existingUser;
      }
      
      final hashedPassword = password.isNotEmpty ? _hashPassword(password) : '';
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Generate unique UID for new user (PRIMARY KEY)
      final uid = _generateUid();
      
      // Create user in SQLite (primary) - UID as PRIMARY KEY
      final userData = {
        'uid': uid, // PRIMARY KEY
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'street': street ?? '',
        'region': region ?? '',
        'province': province ?? '',
        'city': city ?? '',
        'barangay': barangay ?? '',
        'password': hashedPassword,
        'is_online': 1,
        'account_status': 'active',
        'created_at': now,
        'last_seen': now,
        'is_synced': 0,
        'address_setup_completed': 0,
        'is_verified': 1, // Biometric verification completed
      };
      
      final userId = await _sqliteService.insertUser(userData);
      
      // Get the full user record from database to ensure id is captured
      final insertedUser = await _sqliteService.getUserByUsername(username);
      if (insertedUser != null) {
        // Ensure id is set in the returned data
        if (insertedUser['id'] == null && userId > 0) {
          insertedUser['id'] = userId;
        }
        print('✅ User created: $username with UID: $uid, ID: ${insertedUser['id']}');
        return insertedUser;
      }
      
      // Fallback: use userData with userId
      userData['id'] = userId;
      print('✅ User created: $username with UID: $uid, ID: $userId');
      return userData;
    } catch (e) {
      print('❌ Failed to create user: $e');
      return null;
    }
  }
  
  /// Get user by username (SQLite only - offline)
  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    try {
      // Get from SQLite (offline-only)
      final sqliteUser = await _sqliteService.getUserByUsername(username);
      return sqliteUser;
    } catch (e) {
      print('Failed to get user: $e');
      return null;
    }
  }
  
  // Legacy method for migration
  @Deprecated('Use getUserByUsername instead')
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    // Try username first (if email was migrated)
    final username = email.contains('@') ? email.split('@')[0] : email;
    return getUserByUsername(username);
  }
  
  /// Update user profile (SQLite first, then sync to Firebase)
  /// Always saves to SQLite first, then syncs to Firebase if online
  /// If offline, queues for sync when internet is detected
  Future<bool> updateUserProfile({
    required String username, // Replaced email with username
    required String firstName,
    required String lastName,
    String? street,
    String? region,
    String? province,
    String? city,
    String? barangay,
  }) async {
    try {
      // Get current user from SQLite
      final currentUser = await _sqliteService.getUserByUsername(username);
      if (currentUser == null) {
        throw Exception('User not found');
      }
      
      // STEP 1: Always update SQLite first (local storage)
      final updateData = {
        'first_name': firstName,
        'last_name': lastName,
        'street': street ?? '',
        'region': region ?? '',
        'province': province ?? '',
        'city': city ?? '',
        'barangay': barangay ?? '',
        'last_seen': DateTime.now().millisecondsSinceEpoch,
        'is_synced': 0, // Mark as unsynced - will be updated after Firebase sync
      };
      
      // Use UID if available (primary key), otherwise use username
      if (currentUser['uid'] != null && currentUser['uid'].toString().isNotEmpty) {
        await _sqliteService.updateUserByUid(currentUser['uid'].toString(), updateData);
      } else {
        await _sqliteService.updateUserByUsername(username, updateData);
      }
      print('✅ Profile updated in SQLite: $username');
      
      // Profile updated in SQLite (offline-only)
      
      // Notify listeners
      _userUpdateController.add({
        'username': username,
        'action': 'profile_updated',
        'data': updateData,
      });
      
      return true;
    } catch (e) {
      print('❌ Failed to update profile: $e');
      return false;
    }
  }

  /// Update user profile using a map of updates
  /// Always saves to SQLite first, then syncs to Firebase if online
  Future<bool> updateUserProfileWithMap(String username, Map<String, dynamic> updates) async {
    try {
      // Get current user from SQLite
      final currentUser = await _sqliteService.getUserByUsername(username);
      if (currentUser == null) {
        throw Exception('User not found');
      }
      
      // STEP 1: Always update SQLite first (local storage)
      final updateData = Map<String, dynamic>.from(updates);
      updateData['is_synced'] = 0; // Mark as unsynced
      updateData['last_seen'] = DateTime.now().millisecondsSinceEpoch;

      // Use UID if available (primary key), otherwise use username
      if (currentUser['uid'] != null && currentUser['uid'].toString().isNotEmpty) {
        await _sqliteService.updateUserByUid(currentUser['uid'].toString(), updateData);
      } else {
        // Fallback to username if UID not available
        await _sqliteService.updateUserByUsername(username, updateData);
      }
      print('✅ Profile updated in SQLite: $username');

      // Increment profile update count in database
      try {
        await _sqliteService.incrementProfileUpdateCount(username);
      } catch (e) {
        print('⚠️ Failed to increment profile update count: $e');
      }

      // Save updated profile data to SharedPreferences for ESP32 sync
      try {
        final prefs = await SharedPreferences.getInstance();
        final updatedUser = {...currentUser, ...updateData};
        
        // Build full name
        final firstName = updatedUser['first_name']?.toString() ?? '';
        final lastName = updatedUser['last_name']?.toString() ?? '';
        final suffix = updatedUser['suffix']?.toString() ?? '';
        final fullName = [firstName, lastName, suffix].where((s) => s.isNotEmpty).join(' ').trim();
        
        // Save all profile data to SharedPreferences (matching ESP32 variable names)
        await prefs.setString('profile_name', fullName.isNotEmpty ? fullName : (updatedUser['username']?.toString() ?? username));
        await prefs.setString('profile_username', updatedUser['username']?.toString() ?? username);
        await prefs.setString('profile_street', updatedUser['street']?.toString() ?? '');
        await prefs.setString('profile_province', updatedUser['province']?.toString() ?? '');
        await prefs.setString('profile_city', updatedUser['city']?.toString() ?? '');
        await prefs.setString('profile_barangay', updatedUser['barangay']?.toString() ?? '');
        await prefs.setString('profile_suffix', suffix);
        
        // UID should already be in SharedPreferences, but update if changed
        if (updatedUser.containsKey('uid') && updatedUser['uid'] != null) {
          await prefs.setString('session_uid', updatedUser['uid'].toString());
        }
        
        print('✅ Profile data saved to SharedPreferences for ESP32 sync');
      } catch (e) {
        print('⚠️ Failed to save profile to SharedPreferences: $e');
      }

      // Sync profile to ESP32 if connected (only if profile fields were updated)
      final profileFields = ['street', 'province', 'city', 'barangay', 'region', 'first_name', 'last_name', 'suffix', 'username'];
      final hasProfileUpdate = updates.keys.any((key) => profileFields.contains(key));
      if (hasProfileUpdate) {
        try {
          final chatProvider = ChatProvider.instance;
          if (chatProvider != null && chatProvider.isConnected) {
            await chatProvider.syncProfileToESP32();
          }
        } catch (e) {
          print('⚠️ Failed to sync profile to ESP32: $e');
        }
      }

      // Profile updated in SQLite (offline-only)
      
      return true;
    } catch (e) {
      print('❌ Exception in updateUserProfileWithMap: $e');
      rethrow;
    }
  }
  
  /// Authenticate user (SQLite only - offline)
  Future<Map<String, dynamic>?> authenticateUser(String username, String password) async {
    try {
      final hashedPassword = _hashPassword(password);
      
      // Get from SQLite (offline-only)
      final sqliteUser = await _sqliteService.getUserByUsername(username);
      if (sqliteUser != null && sqliteUser['password'] == hashedPassword) {
        // Update last seen - use UID if id is null
        final userId = sqliteUser['id'];
        final userUid = sqliteUser['uid']?.toString();
        
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
        
        // Ensure id is set in returned user
        if (sqliteUser['id'] == null && userUid != null) {
          // Try to get id from database
          final updatedUser = await _sqliteService.getUserByUsername(username);
          if (updatedUser != null && updatedUser['id'] != null) {
            sqliteUser['id'] = updatedUser['id'];
          }
        }
        
        return sqliteUser;
      }
      
      return null;
    } catch (e) {
      print('Authentication failed: $e');
      return null;
    }
  }
  
  /// Update user password
  Future<bool> updatePassword(String username, String newPassword) async {
    try {
      final hashedPassword = _hashPassword(newPassword);
      
      // Get current user
      final currentUser = await _sqliteService.getUserByUsername(username);
      if (currentUser == null) {
        throw Exception('User not found');
      }
      
      // Update SQLite first
      if (currentUser['uid'] != null && currentUser['uid'].toString().isNotEmpty) {
        await _sqliteService.updateUserByUid(currentUser['uid'].toString(), {
          'password': hashedPassword,
          'last_seen': DateTime.now().millisecondsSinceEpoch,
          'is_synced': 0,
        });
      } else {
        await _sqliteService.updateUserByUsername(username, {
          'password': hashedPassword,
          'last_seen': DateTime.now().millisecondsSinceEpoch,
          'is_synced': 0,
        });
      }
      
      // Password updated in SQLite (offline-only)
      
      print('✅ Password updated: $username');
      return true;
    } catch (e) {
      print('❌ Failed to update password: $e');
      return false;
    }
  }
  
  /// Mark address setup as completed
  Future<bool> markAddressSetupCompleted(String username) async {
    try {
      final currentUser = await _sqliteService.getUserByUsername(username);
      if (currentUser == null) {
        throw Exception('User not found');
      }
      
      // Update SQLite first
      if (currentUser['uid'] != null && currentUser['uid'].toString().isNotEmpty) {
        await _sqliteService.updateUserByUid(currentUser['uid'].toString(), {
          'address_setup_completed': 1,
          'last_seen': DateTime.now().millisecondsSinceEpoch,
          'is_synced': 0,
        });
      } else {
        await _sqliteService.updateUserByUsername(username, {
          'address_setup_completed': 1,
          'last_seen': DateTime.now().millisecondsSinceEpoch,
          'is_synced': 0,
        });
      }
      
      // Address setup completed in SQLite (offline-only)
      
      print('✅ Address setup completed: $username');
      return true;
    } catch (e) {
      print('❌ Failed to mark address setup completed: $e');
      return false;
    }
  }
  
  /// Logout user (clear session, keep SQLite data)
  Future<void> logoutUser(String username) async {
    try {
      // Update last seen in SQLite
      final currentUser = await _sqliteService.getUserByUsername(username);
      if (currentUser != null) {
        if (currentUser['uid'] != null && currentUser['uid'].toString().isNotEmpty) {
          await _sqliteService.updateUserByUid(currentUser['uid'].toString(), {
            'is_online': 0,
            'last_seen': DateTime.now().millisecondsSinceEpoch,
          });
        } else {
          await _sqliteService.updateUserByUsername(username, {
            'is_online': 0,
            'last_seen': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }
      
      // Logout completed in SQLite (offline-only)
      
      print('✅ User logged out: $username');
    } catch (e) {
      print('❌ Logout failed: $e');
    }
  }
  
  /// Hash password using SHA-256
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// Dispose resources
  void dispose() {
    _userUpdateController.close();
  }
}
