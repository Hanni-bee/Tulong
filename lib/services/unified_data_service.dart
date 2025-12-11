import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'sqlite_service.dart';
import 'firebase_service.dart';

/// Unified data service that uses SQLite as primary database and Firebase as backup
/// All data operations go through this service to ensure consistency
class UnifiedDataService {
  static final UnifiedDataService _instance = UnifiedDataService._internal();
  factory UnifiedDataService() => _instance;
  UnifiedDataService._internal();

  final SQLiteService _sqliteService = SQLiteService();
  final FirebaseService _firebaseService = FirebaseService();
  final Connectivity _connectivity = Connectivity();
  
  // Stream controllers for real-time updates
  final StreamController<bool> _connectionStatusController = StreamController.broadcast();
  final StreamController<Map<String, dynamic>> _userUpdateController = StreamController.broadcast();
  
  Stream<bool> get connectionStatus => _connectionStatusController.stream;
  Stream<Map<String, dynamic>> get userUpdates => _userUpdateController.stream;
  
  bool _isOnline = false;
  Timer? _syncTimer;
  
  /// Initialize the service
  Future<void> initialize() async {
    _monitorConnectivity();
    _startPeriodicSync();
  }
  
  /// Monitor internet connectivity
  /// Automatically syncs when internet is detected
  Future<void> _monitorConnectivity() async {
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final wasOnline = _isOnline;
      _isOnline = results.any((result) => result != ConnectivityResult.none);
      
      if (_isOnline != wasOnline) {
        _connectionStatusController.add(_isOnline);
        print('🌐 Network status changed: ${_isOnline ? "ONLINE" : "OFFLINE"}');
        
        // When internet is detected, automatically sync pending updates
        if (_isOnline && !wasOnline) {
          print('🔄 Internet detected - starting automatic sync...');
          _performSync();
        }
      }
    });
    
    // Check initial connectivity
    final results = await _connectivity.checkConnectivity();
    _isOnline = results.any((result) => result != ConnectivityResult.none);
    _connectionStatusController.add(_isOnline);
    
    // If online at startup, sync immediately
    if (_isOnline) {
      print('🌐 Online at startup - syncing pending updates...');
      _performSync();
    }
  }
  
  /// Start periodic sync when online
  void _startPeriodicSync() {
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_isOnline) {
        _performSync();
      }
    });
  }
  
  /// Perform sync from SQLite to Firebase
  Future<void> _performSync() async {
    if (!_isOnline) return;
    
    try {
      // Sync users
      await _syncUsers();
      // Sync messages
      await _syncMessages();
      // Sync emergency alerts
      await _syncEmergencyAlerts();
    } catch (e) {
      print('Sync error: $e');
    }
  }
  
  /// Sync users from SQLite to Firebase
  /// Automatically called when internet is detected
  Future<void> _syncUsers() async {
    if (!_isOnline) return;
    
    final unsyncedUsers = await _sqliteService.getUnsyncedUsers();
    
    if (unsyncedUsers.isEmpty) {
      print('✅ No unsynced users to sync');
      return;
    }
    
    print('🔄 Syncing ${unsyncedUsers.length} unsynced user(s) to Firebase...');
    
    for (final user in unsyncedUsers) {
      try {
        final firebaseUid = user['firebase_uid'];
        if (firebaseUid == null) {
          print('⚠️ Skipping user ${user['email']} - no Firebase UID');
          continue;
        }
        
        // Convert SQLite data to Firebase format
        final firebaseData = _convertUserToFirebaseFormat(user);
        
        // Update Firebase Realtime Database using UID
        await _firebaseService.database.ref('users/$firebaseUid').update(firebaseData);
        
        // Mark as synced in SQLite
        await _sqliteService.markUserAsSynced(user['id'], firebaseUid);
        
        print('✅ Synced user: ${user['email']} (UID: $firebaseUid)');
      } catch (e) {
        print('❌ Failed to sync user ${user['email']}: $e');
        // Keep in queue for retry
      }
    }
    
    // Also process sync queue
    await _processSyncQueue();
  }
  
  /// Process sync queue for profile updates
  Future<void> _processSyncQueue() async {
    if (!_isOnline) return;
    
    try {
      final queueItems = await _sqliteService.getSyncQueue();
      final userUpdates = queueItems.where((item) => item['table_name'] == 'users').toList();
      
      if (userUpdates.isEmpty) return;
      
      print('🔄 Processing ${userUpdates.length} queued profile update(s)...');
      
      for (final item in userUpdates) {
        try {
          final userId = item['record_id'];
          final user = await _sqliteService.getUserById(userId);
          
          if (user == null) {
            await _sqliteService.removeFromSyncQueue(item['id']);
            continue;
          }
          
          final firebaseUid = user['firebase_uid'];
          if (firebaseUid == null) {
            print('⚠️ Skipping queued update - no Firebase UID');
            await _sqliteService.removeFromSyncQueue(item['id']);
            continue;
          }
          
          // Convert to Firebase format and update
          final firebaseData = _convertUserToFirebaseFormat(user);
          await _firebaseService.database.ref('users/$firebaseUid').update(firebaseData);
          
          // Mark as synced and remove from queue
          await _sqliteService.markUserAsSynced(userId, firebaseUid);
          await _sqliteService.removeFromSyncQueue(item['id']);
          
          print('✅ Processed queued profile update for: ${user['email']}');
        } catch (e) {
          print('❌ Failed to process queued update: $e');
          // Keep in queue for retry
        }
      }
    } catch (e) {
      print('❌ Error processing sync queue: $e');
    }
  }
  
  /// Sync messages from SQLite to Firebase
  Future<void> _syncMessages() async {
    final unsyncedMessages = await _sqliteService.getUnsyncedMessages();
    
    for (final message in unsyncedMessages) {
      try {
        final firebaseData = _convertMessageToFirebaseFormat(message);
        final messageRef = _firebaseService.database.ref('chats/${message['chat_id']}/messages').push();
        await messageRef.set(firebaseData);
        
        await _sqliteService.markMessageAsSynced(message['id'], messageRef.key!);
        print('✅ Synced message: ${message['id']}');
      } catch (e) {
        print('❌ Failed to sync message ${message['id']}: $e');
      }
    }
  }
  
  /// Sync emergency alerts from SQLite to Firebase
  Future<void> _syncEmergencyAlerts() async {
    final unsyncedAlerts = await _sqliteService.getUnsyncedAlerts();
    
    for (final alert in unsyncedAlerts) {
      try {
        final firebaseData = _convertAlertToFirebaseFormat(alert);
        final alertRef = _firebaseService.database.ref('emergency_alerts').push();
        await alertRef.set(firebaseData);
        
        await _sqliteService.markAlertAsSynced(alert['id'], alertRef.key!);
        print('✅ Synced alert: ${alert['id']}');
      } catch (e) {
        print('❌ Failed to sync alert ${alert['id']}: $e');
      }
    }
  }
  
  /// Convert SQLite user data to Firebase format
  Map<String, dynamic> _convertUserToFirebaseFormat(Map<String, dynamic> sqliteUser) {
    return {
      'FirstName': sqliteUser['first_name'],
      'LastName': sqliteUser['last_name'],
      'Username': sqliteUser['username'] ?? sqliteUser['email'], // Support migration
      'Phone': sqliteUser['phone'],
      'Address': sqliteUser['street'],
      'Region': sqliteUser['region'],
      'Province': sqliteUser['province'],
      'City': sqliteUser['city'],
      'Barangay': sqliteUser['barangay'],
      
      'Password': sqliteUser['password'],
      'isOnline': sqliteUser['is_online'] == 1,
      'accountStatus': sqliteUser['account_status'],
      'createdAt': sqliteUser['created_at'],
      'lastSeen': sqliteUser['last_seen'],
      'isVerified': sqliteUser['is_verified'] == 1,
      'addressSetupCompleted': sqliteUser['address_setup_completed'] == 1,
    };
  }

  /// Convert Firebase user data to SQLite format
  Map<String, dynamic> _convertUserToSQLiteFormat(Map<String, dynamic> firebaseUser) {
    return {
      'first_name': firebaseUser['FirstName'] ?? '',
      'last_name': firebaseUser['LastName'] ?? '',
      'username': firebaseUser['Username'] ?? firebaseUser['Email'] ?? '', // Support migration
      'phone': firebaseUser['Phone'],
      'street': firebaseUser['Address'] ?? '',
      'region': firebaseUser['Region'] ?? '',
      'province': firebaseUser['Province'] ?? '',
      'city': firebaseUser['City'] ?? '',
      'barangay': firebaseUser['Barangay'] ?? '',
      
      'password': firebaseUser['Password'],
      'is_online': (firebaseUser['isOnline'] ?? false) ? 1 : 0,
      'account_status': firebaseUser['accountStatus'] ?? 'active',
      'created_at': firebaseUser['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
      'last_seen': firebaseUser['lastSeen'],
      'is_verified': (firebaseUser['isVerified'] ?? false) ? 1 : 0,
      'address_setup_completed': (firebaseUser['addressSetupCompleted'] ?? false) ? 1 : 0,
    };
  }
  
  /// Convert SQLite message data to Firebase format
  Map<String, dynamic> _convertMessageToFirebaseFormat(Map<String, dynamic> sqliteMessage) {
    return {
      'message': sqliteMessage['message'],
      'senderId': sqliteMessage['sender_id'],
      'senderName': sqliteMessage['sender_name'],
      'timestamp': sqliteMessage['timestamp'],
      'type': sqliteMessage['message_type'],
      'imageUrl': sqliteMessage['image_url'],
    };
  }
  
  /// Convert SQLite alert data to Firebase format
  Map<String, dynamic> _convertAlertToFirebaseFormat(Map<String, dynamic> sqliteAlert) {
    return {
      'message': sqliteAlert['message'],
      'location': sqliteAlert['location'],
      'userId': sqliteAlert['user_id'],
      'timestamp': sqliteAlert['timestamp'],
      'status': sqliteAlert['status'],
    };
  }
  
  // ========== USER OPERATIONS ==========
  
  /// Create a new user (SQLite first, then sync to Firebase)
  Future<Map<String, dynamic>?> createUser({
    required String username,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
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
          'phone': phone,
        });
        return existingUser;
      }
      
      final hashedPassword = password.isNotEmpty ? _hashPassword(password) : '';
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Create user in SQLite (primary) - ALL FIELDS INCLUDED
      final userData = {
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
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
        'is_synced': 0, // Will sync when online
        'address_setup_completed': 0,
        'is_verified': 0, // Will be set to 1 after SMS OTP verification
      };
      
      final userId = await _sqliteService.insertUser(userData);
      userData['id'] = userId;
      
      // Try to sync to Firebase if online
      if (_isOnline) {
        try {
          final firebaseData = _convertUserToFirebaseFormat(userData);
          await _firebaseService.database.ref('users/$username').set(firebaseData);
          
          // Mark as synced
          await _sqliteService.markUserAsSynced(userId, username);
          userData['is_synced'] = 1;
          userData['firebase_uid'] = username;
        } catch (e) {
          print('Firebase sync failed for new user: $e');
          // User is still created in SQLite, will sync later
        }
      }
      
      print('✅ User created: $username');
      return userData;
    } catch (e) {
      print('❌ Failed to create user: $e');
      return null;
    }
  }
  
  /// Get user by username (SQLite first, fallback to Firebase)
  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    try {
      // Try SQLite first (offline-first)
      final sqliteUser = await _sqliteService.getUserByUsername(username);
      if (sqliteUser != null) {
        return sqliteUser;
      }
      
      // If not found in SQLite and online, try Firebase
      if (_isOnline) {
        try {
          final snapshot = await _firebaseService.database.ref('users/$username').get();
          if (snapshot.exists) {
            final firebaseUser = Map<String, dynamic>.from(snapshot.value as Map);
            final sqliteUser = _convertUserToSQLiteFormat(firebaseUser);
            
            // Save to SQLite for offline access
            await _sqliteService.insertUser(sqliteUser);
            
            return sqliteUser;
          }
        } catch (e) {
          print('Firebase lookup failed: $e');
        }
      }
      
      return null;
    } catch (e) {
      print('Failed to get user: $e');
      return null;
    }
  }

  // Legacy method for migration support
  @Deprecated('Use getUserByUsername instead')
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    return getUserByUsername(email);
  }
  
  /// Update user profile (SQLite first, then sync to Firebase)
  /// Always saves to SQLite first, then syncs to Firebase if online
  /// If offline, queues for sync when internet is detected
  Future<bool> updateUserProfile({
    required String username,
    required String firstName,
    required String lastName,
    String? phone,
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
        'phone': phone,
        'street': street ?? '',
        'region': region ?? '',
        'province': province ?? '',
        'city': city ?? '',
        'barangay': barangay ?? '',
        'last_seen': DateTime.now().millisecondsSinceEpoch,
        'is_synced': 0, // Mark as unsynced - will be updated after Firebase sync
      };
      
      await _sqliteService.updateUser(currentUser['id'], updateData);
      print('✅ Profile updated in SQLite: $username');
      
      // STEP 2: Sync to Firebase if online
      final firebaseUid = currentUser['firebase_uid'];
      if (_isOnline && firebaseUid != null) {
        try {
          // Convert to Firebase format
          final firebaseData = _convertUserToFirebaseFormat({
            ...currentUser,
            ...updateData,
          });
          
          // Update Firebase Realtime Database using UID
          await _firebaseService.database.ref('users/$firebaseUid').update(firebaseData);
          
          // Mark as synced in SQLite
          await _sqliteService.markUserAsSynced(currentUser['id'], firebaseUid);
          print('✅ Profile synced to Firebase: $username (UID: $firebaseUid)');
        } catch (e) {
          print('⚠️ Firebase sync failed for profile update: $e');
          print('   Profile is saved locally and will sync when online');
          // Add to sync queue for retry
          await _sqliteService.addToSyncQueue(
            tableName: 'users',
            recordId: currentUser['id'],
            operation: 'update',
            data: updateData,
          );
        }
      } else if (!_isOnline) {
        // STEP 3: If offline, add to sync queue for later
        print('📴 Offline mode - profile update queued for sync');
        await _sqliteService.addToSyncQueue(
          tableName: 'users',
          recordId: currentUser['id'],
          operation: 'update',
          data: updateData,
        );
      } else if (firebaseUid == null) {
        print('⚠️ No Firebase UID - profile saved locally only');
      }
      
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

      await _sqliteService.updateUser(currentUser['id'], updateData);
      print('✅ Profile updated in SQLite: $username');

      // STEP 2: Sync to Firebase if online
      final firebaseUid = currentUser['firebase_uid'];
      if (_isOnline && firebaseUid != null) {
        try {
          final firebaseUpdates = _convertUserToFirebaseFormat({
            ...currentUser,
            ...updateData,
          });
          await _firebaseService.database.ref('users/$firebaseUid').update(firebaseUpdates);
          await _sqliteService.markUserAsSynced(currentUser['id'], firebaseUid);
          print('✅ Profile synced to Firebase: $username (UID: $firebaseUid)');
        } catch (e) {
          print('⚠️ Firebase sync failed: $e');
          // Add to sync queue for retry
          await _sqliteService.addToSyncQueue(
            tableName: 'users',
            recordId: currentUser['id'],
            operation: 'update',
            data: updateData,
          );
        }
      } else if (!_isOnline) {
        // STEP 3: If offline, queue for later sync
        print('📴 Offline mode - profile update queued for sync');
        await _sqliteService.addToSyncQueue(
          tableName: 'users',
          recordId: currentUser['id'],
          operation: 'update',
          data: updateData,
        );
      }
      
      return true;
    } catch (e) {
      print('❌ Exception in updateUserProfileWithMap: $e');
      rethrow;
    }
  }
  
  /// Authenticate user (SQLite first, fallback to Firebase)
  Future<Map<String, dynamic>?> authenticateUser(String username, String password) async {
    try {
      final hashedPassword = _hashPassword(password);
      
      // Try SQLite first
      final sqliteUser = await _sqliteService.getUserByUsername(username);
      if (sqliteUser != null && sqliteUser['password'] == hashedPassword) {
        // Update last seen
        await _sqliteService.updateUser(sqliteUser['id'], {
          'last_seen': DateTime.now().millisecondsSinceEpoch,
          'is_online': 1,
        });
        
        return sqliteUser;
      }
      
      // If not found in SQLite and online, try Firebase
      if (_isOnline) {
        try {
          final snapshot = await _firebaseService.database.ref('users/$username').get();
          if (snapshot.exists) {
            final firebaseUser = Map<String, dynamic>.from(snapshot.value as Map);
            if (firebaseUser['Password'] == hashedPassword) {
              final sqliteUser = _convertUserToSQLiteFormat(firebaseUser);
              
              // Save to SQLite for offline access
              await _sqliteService.insertUser(sqliteUser);
              
              return sqliteUser;
            }
          }
        } catch (e) {
          print('Firebase authentication failed: $e');
        }
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
      await _sqliteService.updateUser(currentUser['id'], {
        'password': hashedPassword,
        'last_seen': DateTime.now().millisecondsSinceEpoch,
        'is_synced': 0,
      });
      
      // Try to sync to Firebase if online
      final firebaseUid = currentUser['firebase_uid'] ?? username;
      if (_isOnline) {
        try {
          await _firebaseService.database.ref('users/$firebaseUid').update({
            'Password': hashedPassword,
            'lastSeen': DateTime.now().millisecondsSinceEpoch,
          });
          
          await _sqliteService.markUserAsSynced(currentUser['id'], firebaseUid);
        } catch (e) {
          print('Firebase password sync failed: $e');
        }
      }
      
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
      await _sqliteService.updateUser(currentUser['id'], {
        'address_setup_completed': 1,
        'last_seen': DateTime.now().millisecondsSinceEpoch,
        'is_synced': 0,
      });
      
      // Try to sync to Firebase if online
      final firebaseUid = currentUser['firebase_uid'] ?? username;
      if (_isOnline) {
        try {
          await _firebaseService.database.ref('users/$firebaseUid').update({
            'addressSetupCompleted': true,
            'lastSeen': DateTime.now().millisecondsSinceEpoch,
          });
          
          await _sqliteService.markUserAsSynced(currentUser['id'], firebaseUid);
        } catch (e) {
          print('Firebase address setup sync failed: $e');
        }
      }
      
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
        await _sqliteService.updateUser(currentUser['id'], {
          'is_online': 0,
          'last_seen': DateTime.now().millisecondsSinceEpoch,
        });
      }
      
      // Try to update Firebase if online
      final firebaseUid = currentUser?['firebase_uid'] ?? username;
      if (_isOnline) {
        try {
          await _firebaseService.database.ref('users/$firebaseUid').update({
            'isOnline': false,
            'lastSeen': DateTime.now().millisecondsSinceEpoch,
          });
        } catch (e) {
          print('Firebase logout sync failed: $e');
        }
      }
      
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
  
  /// Get connection status
  bool get isOnline => _isOnline;
  
  /// Force sync now
  Future<void> forceSync() async {
    if (_isOnline) {
      await _performSync();
    }
  }
  
  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
    _connectionStatusController.close();
    _userUpdateController.close();
  }
}
