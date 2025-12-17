import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sqlite_service.dart';
import 'firebase_service.dart';
import 'network_service.dart';

class OfflineAuthService {
  static final OfflineAuthService _instance = OfflineAuthService._internal();
  factory OfflineAuthService() => _instance;
  OfflineAuthService._internal();

  final SQLiteService _sqliteService = SQLiteService();
  final FirebaseService _firebaseService = FirebaseService();
  final NetworkService _networkService = NetworkService();

  // Current user
  Map<String, dynamic>? _currentUser;
  Map<String, dynamic>? get currentUser => _currentUser;

  // Initialize offline auth
  Future<void> initialize() async {
    await _sqliteService.database;
    await _networkService.initialize();
    
    // Listen to network changes for auto-sync
    _networkService.connectionStream.listen((isConnected) {
      if (isConnected) {
        _autoSyncToFirebase();
      }
    });
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
        
        // Try to sync to Firebase if online
        if (await _networkService.isOnline()) {
          _syncUserToFirebase(user);
        } else {
          // Add to sync queue for later
          await _sqliteService.addToSyncQueue(
            tableName: 'users',
            recordId: userId,
            operation: 'create',
            data: userData,
          );
        }
        
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

      // Update last seen
      await _sqliteService.updateUser(user['id'], {
        'last_seen': DateTime.now().millisecondsSinceEpoch,
        'is_online': 1,
      });

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
      // Update user offline status
      await _sqliteService.updateUser(_currentUser!['id'], {
        'is_online': 0,
        'last_seen': DateTime.now().millisecondsSinceEpoch,
      });
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

  // Auto-sync to Firebase when connection is restored
  Future<void> _autoSyncToFirebase() async {
    try {
      print('🔄 Auto-syncing offline data to Firebase...');
      
      // Sync unsynced users
      final unsyncedUsers = await _sqliteService.getUnsyncedUsers();
      for (final user in unsyncedUsers) {
        await _syncUserToFirebase(user);
      }
      
      // Sync unsynced messages
      final unsyncedMessages = await _sqliteService.getUnsyncedMessages();
      for (final message in unsyncedMessages) {
        await _syncMessageToFirebase(message);
      }
      
      // Sync unsynced alerts
      final unsyncedAlerts = await _sqliteService.getUnsyncedAlerts();
      for (final alert in unsyncedAlerts) {
        await _syncAlertToFirebase(alert);
      }
      
      print('✅ Auto-sync completed');
    } catch (e) {
      print('❌ Auto-sync failed: $e');
    }
  }

  // Sync user to Firebase
  Future<void> _syncUserToFirebase(Map<String, dynamic> user) async {
    try {
      if (await _networkService.isOnline()) {
        // Sync to Firebase using username as key
        final username = user['username'] ?? user['email']; // Support migration
        if (username != null) {
          // Update user data in Firebase
          await _firebaseService.database.ref('users/$username').set({
            'FirstName': user['first_name'],
            'LastName': user['last_name'],
            'Username': username,
            'Address': user['street'] ?? user['address'],
            'Region': user['region'],
            'Province': user['province'] ?? '',
            'City': user['city'],
            'Barangay': user['barangay'],
            'Password': user['password'],
            'createdAt': user['created_at'],
            'isOnline': user['is_online'] == 1,
            'lastSeen': user['last_seen'],
            'isVerified': user['is_verified'] == 1,
          });

          // Mark as synced in SQLite
          await _sqliteService.updateUser(user['id'], {
            'firebase_uid': username,
            'is_synced': 1,
            'sync_timestamp': DateTime.now().millisecondsSinceEpoch,
          });
          
          print('✅ User synced to Firebase: $username');
        }
      }
    } catch (e) {
      print('❌ Failed to sync user to Firebase: $e');
    }
  }

  // Sync message to Firebase
  Future<void> _syncMessageToFirebase(Map<String, dynamic> message) async {
    try {
      if (await _networkService.isOnline()) {
        final messageData = {
          'message': message['message'],
          'senderId': message['sender_id'],
          'senderName': message['sender_name'],
          'timestamp': message['timestamp'],
          'imageUrl': message['image_url'],
          'type': message['message_type'],
        };

        final ref = _firebaseService.database.ref('chats/${message['chat_id']}/messages').push();
        await ref.set(messageData);
        
        // Mark as synced
        await _sqliteService.markMessageAsSynced(message['id'], ref.key!);
        
        print('✅ Message synced to Firebase');
      }
    } catch (e) {
      print('❌ Failed to sync message to Firebase: $e');
    }
  }

  // Sync alert to Firebase
  Future<void> _syncAlertToFirebase(Map<String, dynamic> alert) async {
    try {
      if (await _networkService.isOnline()) {
        final alertData = {
          'message': alert['message'],
          'location': alert['location'],
          'userId': alert['user_id'],
          'timestamp': alert['timestamp'],
          'type': 'emergency',
          'status': alert['status'],
        };

        final ref = _firebaseService.database.ref('emergency_alerts').push();
        await ref.set(alertData);
        
        // Mark as synced
        await _sqliteService.markAlertAsSynced(alert['id'], ref.key!);
        
        print('✅ Alert synced to Firebase');
      }
    } catch (e) {
      print('❌ Failed to sync alert to Firebase: $e');
    }
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
