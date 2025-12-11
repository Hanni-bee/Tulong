import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/input_validator.dart';
import '../models/user_model.dart';
import 'sqlite_service.dart';


class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();
  
  // Global debug logs list
  static List<String> debugLogs = [];
  
  // Add debug log method
  void _addDebugLog(String message) {
    debugLogs.add('${DateTime.now().toString().substring(11, 19)}: $message');
    // Keep only last 100 logs
    if (debugLogs.length > 100) {
      debugLogs.removeAt(0);
    }
  }

  // Firebase instances
  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseDatabase get database => FirebaseDatabase.instance;
  FirebaseStorage get storage => FirebaseStorage.instance;
  FirebaseAnalytics get analytics => FirebaseAnalytics.instance;
  FirebaseMessaging get messaging => FirebaseMessaging.instance;
  
  // SQLite service for offline functionality
  final SQLiteService _sqliteService = SQLiteService();
  
  // SMS OTP Verification - Send verification code to phone
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(UserCredential userCredential) onVerificationCompleted,
    required Function(String error) onVerificationFailed,
    required Function(String error) onCodeAutoRetrievalTimeout,
  }) async {
    try {
      await auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            final userCredential = await auth.signInWithCredential(credential);
            onVerificationCompleted(userCredential);
          } catch (e) {
            onVerificationFailed(e.toString());
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          onVerificationFailed(e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          onCodeAutoRetrievalTimeout('Code auto-retrieval timeout');
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      onVerificationFailed(e.toString());
    }
  }

  // Verify SMS OTP code
  Future<UserCredential?> signInWithPhoneNumber({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      
      final userCredential = await auth.signInWithCredential(credential);
      return userCredential;
    } catch (e) {
      print('❌ SMS OTP verification failed: $e');
      return null;
    }
  }

  // SSO removed - deprecated
  @Deprecated('SSO removed - use username + password authentication')
  Future<UserCredential?> signInWithGoogle() async {
    // SSO removed - Google Sign-In no longer supported
    print('⚠️ Google Sign-In is no longer supported. Please use username + password authentication.');
    return null;
  }

  // Current user
  User? get currentUser => auth.currentUser;

  // Helper method to save user to SQLite for offline access
  Future<void> _saveUserToSQLite({
    String? email, // Legacy support
    String? username,
    required String firstName,
    required String lastName,
    String? phone,
    required String address,
    required String region,
    String? province,
    required String city,
    required String barangay,
    required String hashedPassword,
    String? firebaseUid,
  }) async {
    try {
      // Use username if provided, otherwise fallback to email for migration
      final userIdentifier = username ?? email ?? '';
      if (userIdentifier.isEmpty) {
        throw Exception('Username or email is required');
      }
      
      // Check if user already exists in SQLite
      final existingUser = username != null 
          ? await _sqliteService.getUserByUsername(username)
          : await _sqliteService.getUserByEmail(email ?? '');
      
      if (existingUser != null) {
        // Update existing user
        await _sqliteService.updateUser(existingUser['id'], {
          'firebase_uid': firebaseUid,
          if (username != null) 'username': username,
          'first_name': firstName,
          'last_name': lastName,
          'phone': phone,
          'street': address, // SQLite uses 'street' column
          'region': region,
          'province': province,
          'city': city,
          'barangay': barangay,
          'password': hashedPassword,
          'is_online': 1,
          'account_status': 'active',
          'last_seen': DateTime.now().millisecondsSinceEpoch,
          'is_synced': firebaseUid != null ? 1 : 0,
          'sync_timestamp': firebaseUid != null ? DateTime.now().millisecondsSinceEpoch : null,
          'is_verified': 0, // Will be set to 1 after SMS OTP verification
        });
        print('SQLite user updated: ${username ?? email}');
      } else {
        // Create new user
        await _sqliteService.insertUser({
          'firebase_uid': firebaseUid,
          'username': username ?? email ?? '',
          'first_name': firstName,
          'last_name': lastName,
          'phone': phone,
          'street': address, // SQLite uses 'street' column
          'region': region,
          'province': province,
          'city': city,
          'barangay': barangay,
          'password': hashedPassword,
          'is_online': 1,
          'account_status': 'active',
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'last_seen': DateTime.now().millisecondsSinceEpoch,
          'is_synced': firebaseUid != null ? 1 : 0,
          'sync_timestamp': firebaseUid != null ? DateTime.now().millisecondsSinceEpoch : null,
          'address_setup_completed': 0,
          'is_verified': 0, // Will be set to 1 after SMS OTP verification
        });
        print('SQLite user created: ${username ?? email}');
      }
    } catch (e) {
      print('Error saving user to SQLite: $e');
    }
  }

  // Helper method to update password in SQLite database
  Future<void> _updatePasswordInSQLite({
    String? email, // Legacy support
    String? username,
    required String hashedPassword,
  }) async {
    try {
      final userIdentifier = username ?? email ?? '';
      if (userIdentifier.isEmpty) {
        throw Exception('Username or email is required');
      }
      
      print('🔍 Looking for user in SQLite: $userIdentifier');
      _addDebugLog('🔍 Looking for user in SQLite: $userIdentifier');
      
      // Get existing user from SQLite
      final existingUser = username != null
          ? await _sqliteService.getUserByUsername(username)
          : await _sqliteService.getUserByEmail(email ?? '');
      
      if (existingUser != null) {
        print('✅ User found in SQLite with ID: ${existingUser['id']}');
        print('🔍 Old SQLite password: ${existingUser['password']}');
        print('🔍 New password hash: $hashedPassword');
        _addDebugLog('✅ User found in SQLite with ID: ${existingUser['id']}');
        _addDebugLog('🔍 Old SQLite password: ${existingUser['password']}');
        _addDebugLog('🔍 New password hash: $hashedPassword');
        
        // Update password for the user
        await _sqliteService.updateUser(existingUser['id'], {
          'password': hashedPassword,
          'sync_timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        
        print('✅ SQLite password updated for: $userIdentifier');
        _addDebugLog('✅ SQLite password updated for: $userIdentifier');
      } else {
        print('❌ User not found in SQLite: $userIdentifier');
        _addDebugLog('❌ User not found in SQLite: $userIdentifier');
        throw Exception('User not found in local database');
      }
    } catch (e) {
      print('❌ Error updating password in SQLite: $e');
      _addDebugLog('❌ Error updating password in SQLite: $e');
      rethrow;
    }
  }

  // Sync password after email reset (call this when user logs in after password reset)
  Future<void> syncPasswordAfterReset() async {
    try {
      if (currentUser == null) {
        throw Exception('No user is currently signed in');
      }

      final email = currentUser!.email!;
      
      // Get the current Firebase Auth password (this is the new password set via email reset)
      // We need to get this from the user's current session
      final userSnapshot = await database.ref('users').orderByChild('Email').equalTo(email).get();
      
      if (userSnapshot.exists) {
        final users = userSnapshot.value as Map;
        String? userUid;
        
        users.forEach((key, value) {
          final user = value as Map;
          if (user['Email'] == email) {
            userUid = key;
          }
        });

        if (userUid != null) {
          // The issue is we can't get the actual password from Firebase Auth
          // So we need to prompt the user to enter their new password
          print('⚠️ Password reset detected. User needs to enter new password to sync.');
          throw Exception('Please enter your new password to complete the sync');
        }
      }
    } catch (e) {
      print('❌ Error syncing password after reset: $e');
      rethrow;
    }
  }

  // Update password in all systems after email reset
  Future<void> updatePasswordAfterEmailReset({
    required String newPassword,
  }) async {
    try {
      if (currentUser == null) {
        throw Exception('No user is currently signed in');
      }

      final email = currentUser!.email!;
      final hashedPassword = _hashPassword(newPassword);
      
      // Update password in Firebase Realtime Database
      await database.ref('users/${currentUser!.uid}').update({
        'Password': hashedPassword,
      });
      
      // Update password in SQLite
      await _updatePasswordInSQLite(
        email: email,
        hashedPassword: hashedPassword,
      );
      
      print('✅ Password synced after email reset for: $email');
    } catch (e) {
      print('❌ Error updating password after email reset: $e');
      throw Exception('Failed to sync password: ${e.toString()}');
    }
  }

  // Hash password using SHA-256
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Public method to hash password (for use in other services)
  String hashPassword(String password) {
    return _hashPassword(password);
  }

  // Generate a secure temporary password for hybrid accounts
  String _generateSecurePassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*';
    final random = Random();
    final password = List.generate(12, (index) => chars[random.nextInt(chars.length)]).join();
    
    // Ensure password meets complexity requirements
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasNumbers = password.contains(RegExp(r'[0-9]'));
    final hasSpecial = password.contains(RegExp(r'[!@#$%^&*]'));
    
    if (hasUppercase && hasLowercase && hasNumbers && hasSpecial) {
      return password;
    } else {
      // Fallback: ensure at least one of each type
      final upper = chars.substring(26, 52)[random.nextInt(26)];
      final lower = chars.substring(0, 26)[random.nextInt(26)];
      final number = chars.substring(52, 62)[random.nextInt(10)];
      final special = chars.substring(62)[random.nextInt(8)];
      
      return password.substring(0, 8) + upper + lower + number + special;
    }
  }

  // Create database entry for existing Firebase Auth user
  Future<void> _createDatabaseEntryForExistingUser(User user, String email, String password) async {
    try {
      print('🔧 Creating database entry for existing Firebase Auth user: $email');
      _addDebugLog('🔧 Creating database entry for existing Firebase Auth user: $email');
      
      final hashedPassword = _hashPassword(password);
      final displayName = user.displayName ?? user.email?.split('@')[0] ?? 'User';
      
      // Check if this is a Google user trying to add email/password access
      final isGoogleUser = user.providerData.any((provider) => provider.providerId == 'google.com');
      
      // Create entry in Firebase Realtime Database
      await database.ref('users/${user.uid}').set({
        'FirstName': displayName.split(' ')[0],
        'LastName': displayName.split(' ').length > 1 ? displayName.split(' ').sublist(1).join(' ') : '',
        'Email': email,
        'DisplayName': displayName,
        'PhotoURL': user.photoURL ?? '',
        'Provider': isGoogleUser ? 'google' : 'email',
        'Password': hashedPassword,
        'isOnline': true,
        'lastSeen': ServerValue.timestamp,
        'signInMethod': isGoogleUser ? 'google' : 'email',
        'hasEmailPassword': true, // User now has email/password access
        'createdAt': ServerValue.timestamp,
      });

      // Save to SQLite
      await _saveUserToSQLite(
        email: email,
        firstName: displayName.split(' ')[0],
        lastName: displayName.split(' ').length > 1 ? displayName.split(' ').sublist(1).join(' ') : '',
        address: '',
        region: '',
        city: '',
        barangay: '',
        
        hashedPassword: hashedPassword,
        firebaseUid: user.uid,
      );

      print('✅ Database entry created for existing user: $email');
      _addDebugLog('✅ Database entry created for existing user: $email');
    } catch (e) {
      print('❌ Error creating database entry: $e');
      _addDebugLog('❌ Error creating database entry: $e');
      rethrow;
    }
  }


  // Initialize Firebase
  static Future<void> initialize() async {
    try {
      print('Initializing Firebase...');
      await Firebase.initializeApp();
      print('Firebase initialized successfully');

      // Firebase initialization completed
      print('✅ Firebase services initialized successfully');

    } catch (e) {
      print('Firebase initialization failed: $e');
      rethrow;
    }
  }

  // Create user with username (no Firebase Auth email - just database entry)
  Future<bool> createUserWithUsername({
    required String username,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
    required String address,
    required String region,
    String? province,
    required String city,
    required String barangay,
    String? firebaseUid, // Optional Firebase UID if user was verified via SMS OTP
  }) async {
    try {
      // Validate all input data
      print('🔍 Validating signup data...');
      print('   Region value: "$region" (length: ${region.length})');
      print('   Region bytes: ${region.codeUnits}');
      
      final validationErrors = InputValidator.validateUserInput(
        username: username,
        password: password,
        confirmPassword: password, // For signup, password serves as confirmation
        firstName: firstName,
        lastName: lastName,
        address: address,
        region: region,
        city: city,
        barangay: barangay,
      );

      // Check for validation errors
      final errors = validationErrors.values.where((error) => error != null).toList();
      if (errors.isNotEmpty) {
        print('❌ Validation errors found: $errors');
        throw Exception('Validation failed: ${errors.join(', ')}');
      }
      print('✅ All validations passed');

      // Sanitize inputs
      final sanitizedFirstName = InputValidator.sanitizeText(firstName);
      final sanitizedLastName = InputValidator.sanitizeText(lastName);
      final sanitizedAddress = InputValidator.sanitizeText(address);
      final sanitizedRegion = InputValidator.sanitizeText(region);
      final sanitizedCity = InputValidator.sanitizeText(city);
      final sanitizedBarangay = InputValidator.sanitizeText(barangay);

      final sanitizedProvince = province != null ? InputValidator.sanitizeText(province) : '';
      final userUid = firebaseUid ?? username; // Use Firebase UID if available, otherwise use username as key

        final userData = {
          'FirstName': sanitizedFirstName,
          'LastName': sanitizedLastName,
          'Username': username.trim(),
          'Phone': phone ?? '',  // Ensure phone is saved
          'Address': sanitizedAddress,
          'Region': sanitizedRegion,
          'Province': sanitizedProvince,
          'City': sanitizedCity,
          'Barangay': sanitizedBarangay,
          
          'Password': _hashPassword(password), // Hash passwords for security
          'createdAt': ServerValue.timestamp,
          'isOnline': true,
          'lastSeen': ServerValue.timestamp,
          'isVerified': false, // Will be set to true after SMS OTP verification
        };

        print('🔥 Saving to Firebase Realtime Database:');
        print('   UID: $userUid');
        print('   Username: ${username.trim()}');
        print('   Phone: ${phone ?? 'N/A'}');

        try {
          // Save to Firebase Realtime Database using username as key
          final userRef = database.ref('users/$userUid');
          await userRef.set(userData);
          
          print('✅ User data saved to Firebase Realtime Database at users/$userUid');
          _addDebugLog('✅ User data saved to Firebase Realtime Database at users/$userUid');
          
          // Verify the save immediately
          await Future.delayed(const Duration(milliseconds: 500));
          final verifySnapshot = await userRef.get();
          
          if (verifySnapshot.exists) {
            final savedData = verifySnapshot.value as Map<dynamic, dynamic>;
            print('✅ VERIFIED: User data exists in Firebase Realtime Database');
            print('   Saved Username: ${savedData['Username']}');
            print('   Saved Phone: ${savedData['Phone']}');
            print('   Saved FirstName: ${savedData['FirstName']}');
            print('   Saved LastName: ${savedData['LastName']}');
            _addDebugLog('✅ VERIFIED: User data exists in Firebase Realtime Database');
          } else {
            print('❌ ERROR: User data not found after save - verification failed');
            _addDebugLog('❌ ERROR: User data not found after save - verification failed');
            throw Exception('User data verification failed - data not found in database');
          }
          
        } catch (firebaseError) {
          print('❌ CRITICAL ERROR saving to Firebase Realtime Database: $firebaseError');
          print('❌ Error type: ${firebaseError.runtimeType}');
          print('❌ Error details: ${firebaseError.toString()}');
          _addDebugLog('❌ CRITICAL ERROR saving to Firebase Realtime Database: $firebaseError');
          
          // Re-throw to fail the signup if Firebase save fails
          rethrow;
        }

        // Save user to SQLite for offline access
        await _saveUserToSQLite(
          username: username.trim(),
          firstName: sanitizedFirstName,
          lastName: sanitizedLastName,
          phone: phone,
          address: sanitizedAddress,
          region: sanitizedRegion,
          province: sanitizedProvince,
          city: sanitizedCity,
          barangay: sanitizedBarangay,
          
          hashedPassword: _hashPassword(password),
          firebaseUid: userUid,
        );

        // Mark user as new for tutorial purposes
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_created_at_${username.trim()}', DateTime.now().millisecondsSinceEpoch.toString());
        print('New user marked for tutorial: ${username.trim()}');

        // Log sign up event
        await analytics.logSignUp(signUpMethod: 'username');

      return true;
    } catch (e) {
      throw Exception('Sign up failed: ${e.toString()}');
    }
  }

  // Authenticate user by username (database lookup, not Firebase Auth email)
  Future<Map<String, dynamic>?> authenticateUserByUsername({
    required String username,
    required String password,
  }) async {
    try {
      // Validate inputs
      final usernameError = InputValidator.validateUsername(username);
      if (usernameError != null) {
        throw Exception(usernameError);
      }

      if (password.isEmpty) {
        throw Exception('Password is required');
      }

      print('🔐 Starting username/password authentication for: ${username.trim()}');
      _addDebugLog('🔐 Starting username/password authentication for: ${username.trim()}');

      // Look up user in Firebase Realtime Database by username
      final hashedPassword = _hashPassword(password);
      
      // Query Firebase for user by username
      final userSnapshot = await database.ref('users').orderByChild('Username').equalTo(username.trim()).get();
      
      if (!userSnapshot.exists || userSnapshot.value == null) {
        print('❌ User not found: ${username.trim()}');
        _addDebugLog('❌ User not found: ${username.trim()}');
        throw Exception('Invalid username or password');
      }

      // Get user data
      final users = userSnapshot.value as Map<dynamic, dynamic>;
      final userEntry = users.values.first as Map<dynamic, dynamic>;
      final userUid = users.keys.first as String;
      
      // Verify password
      if (userEntry['Password'] != hashedPassword) {
        print('❌ Invalid password for user: ${username.trim()}');
        _addDebugLog('❌ Invalid password for user: ${username.trim()}');
        throw Exception('Invalid username or password');
      }

      // Update last seen
      await database.ref('users/$userUid').update({
        'lastSeen': ServerValue.timestamp,
        'isOnline': true,
      });

      print('✅ Username/password authentication successful');
      _addDebugLog('✅ Username/password authentication successful');

      // Return user data as Map
      return {
        'uid': userUid,
        ...userEntry.map((key, value) => MapEntry(key.toString(), value)),
      };
    } catch (e) {
      print('❌ Authentication failed: $e');
      _addDebugLog('❌ Authentication failed: $e');
      throw Exception('Authentication failed: ${e.toString()}');
    }
  }


  // Forgot Password - DEPRECATED (email auth removed)
  @Deprecated('Email auth removed - password reset not supported with username auth')
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      // Validate email
      final emailError = InputValidator.validateEmail(email);
      if (emailError != null) {
        throw Exception(emailError);
      }

      // Check if user exists in our database to determine account type
      print('🔍 Checking user account type for: ${email.trim()}');
      _addDebugLog('🔍 Checking user account type for: ${email.trim()}');
      
      final userSnapshot = await database.ref('users').orderByChild('Email').equalTo(email.trim()).get();
      
      if (userSnapshot.exists) {
        final users = userSnapshot.value as Map;
        Map<String, dynamic>? userData;
        
        // Find the user data
        users.forEach((key, value) {
          final user = value as Map<String, dynamic>;
          if (user['Email'] == email.trim()) {
            userData = user;
          }
        });
        
        if (userData != null) {
          final provider = userData!['Provider'] as String?;
          final signInMethod = userData!['signInMethod'] as String?;
          final hasEmailPassword = userData!['hasEmailPassword'] as bool?;
          
          print('🔍 User account info:');
          print('  - Provider: $provider');
          print('  - Sign-in method: $signInMethod');
          print('  - Has email password: $hasEmailPassword');
          _addDebugLog('🔍 User account info:');
          _addDebugLog('  - Provider: $provider');
          _addDebugLog('  - Sign-in method: $signInMethod');
          _addDebugLog('  - Has email password: $hasEmailPassword');
          
          // Check if this is a pure Google SSO account (no password access)
          if ((provider == 'google' || signInMethod == 'google') && hasEmailPassword != true) {
            print('❌ Pure Google SSO account detected - cannot send password reset');
            _addDebugLog('❌ Pure Google SSO account detected - cannot send password reset');
            throw Exception('This account is managed by Google. To reset your password, please use Google\'s password recovery service.');
          }
          
          // User has password access (either pure email/password or hybrid account)
          print('✅ Account has password access - sending reset email');
          _addDebugLog('✅ Account has password access - sending reset email');
        } else {
          print('❌ User data not found in database');
          _addDebugLog('❌ User data not found in database');
          throw Exception('User account not found.');
        }
      } else {
        print('⚠️ User not found in database - attempting to send reset email anyway');
        _addDebugLog('⚠️ User not found in database - attempting to send reset email anyway');
      }

      // Send password reset email
      await auth.sendPasswordResetEmail(email: email.trim());
      
      // Log password reset request
      await analytics.logEvent(
        name: 'password_reset_requested',
        parameters: {'email_domain': email.split('@').last},
      );
      
      print('✅ Password reset email sent to: $email');
    } catch (e) {
      print('❌ Password reset failed: $e');
      _addDebugLog('❌ Password reset failed: $e');
      throw Exception('Failed to send password reset email: ${e.toString()}');
    }
  }

  // Check if user has a temporary password and needs to change it
  Future<bool> hasTemporaryPassword() async {
    try {
      if (currentUser == null) return false;
      
      final userSnapshot = await database.ref('users/${currentUser!.uid}').get();
      if (userSnapshot.exists) {
        final userData = userSnapshot.value as Map<String, dynamic>;
        return userData['tempPasswordGenerated'] == true;
      }
      return false;
    } catch (e) {
      print('Error checking temporary password status: $e');
      return false;
    }
  }

  // Change temporary password to a user-defined password
  Future<void> changeTemporaryPassword(String newPassword) async {
    try {
      if (currentUser == null) {
        throw Exception('No user is currently signed in');
      }

      final user = currentUser!;
      final email = user.email!;
      
      print('🔧 Changing temporary password for: $email');
      _addDebugLog('🔧 Changing temporary password for: $email');

      // Validate new password
      final passwordError = InputValidator.validatePassword(newPassword);
      if (passwordError != null) {
        throw Exception(passwordError);
      }

      // Update password in Firebase Auth
      await user.updatePassword(newPassword);
      
      // Hash the new password
      final hashedPassword = _hashPassword(newPassword);

      // Update the user's record in Firebase Realtime Database
      await database.ref('users/${user.uid}').update({
        'Password': hashedPassword,
        'tempPasswordGenerated': false, // Mark as no longer temporary
        'passwordChangedAt': ServerValue.timestamp,
      });

      // Update the local SQLite database
      await _updatePasswordInSQLite(
        email: email,
        hashedPassword: hashedPassword,
      );

      // Log analytics event
      await analytics.logEvent(
        name: 'temporary_password_changed',
        parameters: {'email_domain': email.split('@').last},
      );

      print('✅ Temporary password successfully changed for: $email');
      _addDebugLog('✅ Temporary password successfully changed for: $email');
      
    } catch (e) {
      print('❌ Failed to change temporary password: $e');
      _addDebugLog('❌ Failed to change temporary password: $e');
      throw Exception('Failed to change temporary password: ${e.toString()}');
    }
  }

  // Add password to Google account (Hybrid Account pattern)
  Future<void> addPasswordToGoogleAccount(String newPassword) async {
    try {
      // Check if user is currently signed in
      if (currentUser == null) {
        throw Exception('No user is currently signed in');
      }

      final user = currentUser!;
      final email = user.email!;
      
      print('🔧 Adding password to Google account for: $email');
      _addDebugLog('🔧 Adding password to Google account for: $email');

      // Validate new password
      final passwordError = InputValidator.validatePassword(newPassword);
      if (passwordError != null) {
        throw Exception(passwordError);
      }

      // Create a new credential using the new password
      final credential = EmailAuthProvider.credential(
        email: email,
        password: newPassword,
      );

      // Link this new credential to the currently signed-in Google user
      await user.linkWithCredential(credential);
      
      print('✅ Password credential linked to Google account');
      _addDebugLog('✅ Password credential linked to Google account');

      // Hash the new password for storage
      final hashedPassword = _hashPassword(newPassword);

      // Update the user's record in Firebase Realtime Database
      await database.ref('users/${user.uid}').update({
        'Password': hashedPassword,
        'hasEmailPassword': true,
        'signInMethod': 'multi', // Mark as multi-provider account
        'isMultiProvider': true,
        'updatedAt': ServerValue.timestamp,
      });

      // Update the local SQLite database with the new hashed password
      await _updatePasswordInSQLite(
        email: email,
        hashedPassword: hashedPassword,
      );

      // Log analytics event
      await analytics.logEvent(
        name: 'password_added_to_google_account',
        parameters: {'email_domain': email.split('@').last},
      );

      print('✅ Password successfully added to Google account for: $email');
      _addDebugLog('✅ Password successfully added to Google account for: $email');
      
    } catch (e) {
      print('❌ Failed to add password to Google account: $e');
      _addDebugLog('❌ Failed to add password to Google account: $e');
      
      // Handle specific Firebase Auth errors
      if (e.toString().contains('credential-already-in-use')) {
        throw Exception('This email is already associated with a password account. Please use email/password login instead.');
      } else if (e.toString().contains('invalid-credential')) {
        throw Exception('Invalid credential. Please try again.');
      } else {
        throw Exception('Failed to add password to Google account: ${e.toString()}');
      }
    }
  }

  // Change Password (for authenticated users)
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      if (currentUser == null) {
        throw Exception('No user is currently signed in');
      }

      // Validate new password
      final passwordError = InputValidator.validatePassword(newPassword);
      if (passwordError != null) {
        throw Exception(passwordError);
      }

      // Re-authenticate user with current password
      final credential = EmailAuthProvider.credential(
        email: currentUser!.email!,
        password: currentPassword,
      );
      
      await currentUser!.reauthenticateWithCredential(credential);
      
      // Update password
      await currentUser!.updatePassword(newPassword);
      
      // Update password hash in database
      final hashedPassword = _hashPassword(newPassword);
      await database.ref('users/${currentUser!.uid}').update({
        'Password': hashedPassword,
      });
      
      // Update password in SQLite database
      await _updatePasswordInSQLite(
        email: currentUser!.email!,
        hashedPassword: hashedPassword,
      );
      
      // Log password change
      await analytics.logEvent(name: 'password_changed');
      
      print('✅ Password changed successfully');
    } catch (e) {
      print('❌ Password change failed: $e');
      throw Exception('Failed to change password: ${e.toString()}');
    }
  }

  Future<void> signOut() async {
    try {
      // Update user offline status (only if online)
      if (currentUser != null) {
        try {
          await database.ref('users/${currentUser!.uid}').update({
            'isOnline': false,
            'lastSeen': ServerValue.timestamp,
          });
        } catch (e) {
          print('Failed to update online status (offline): $e');
          // Continue with sign out even if database update fails
        }
      }

      // Sign out from Firebase
      await auth.signOut();
      await analytics.logEvent(name: 'user_sign_out');
    } catch (e) {
      print('Firebase sign out error: $e');
      // Don't throw exception - allow local sign out to continue
    }
  }

  // Realtime Database methods for messaging
  Future<void> sendMessage({
    required String chatId,
    required String message,
    required String senderId,
    required String senderName,
    String? imageUrl,
  }) async {
    try {
      final messageData = {
        'message': message,
        'senderId': senderId,
        'senderName': senderName,
        'timestamp': ServerValue.timestamp,
        'imageUrl': imageUrl,
        'type': imageUrl != null ? 'image' : 'text',
      };

      await database.ref('chats/$chatId/messages').push().set(messageData);
      
      // Log message sent event
      await analytics.logEvent(
        name: 'message_sent',
        parameters: {
          'chat_type': chatId == 'global' ? 'global' : 'private',
        },
      );
    } catch (e) {
      throw Exception('Failed to send message: ${e.toString()}');
    }
  }

  // Get messages stream
  Stream<DatabaseEvent> getMessagesStream(String chatId) {
    return database.ref('chats/$chatId/messages').onValue;
  }

  // Upload file to Firebase Storage
  Future<String> uploadFile({
    required String filePath,
    required String fileName,
    required String folder,
  }) async {
    try {
      final ref = storage.ref().child('$folder/$fileName');
      final uploadTask = await ref.putFile(File(filePath));
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      // Log file upload event
      await analytics.logEvent(
        name: 'file_uploaded',
        parameters: {
          'file_type': fileName.split('.').last,
          'folder': folder,
        },
      );
      
      return downloadUrl;
    } catch (e) {
      throw Exception('File upload failed: ${e.toString()}');
    }
  }

  // Get user data from Realtime Database
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final snapshot = await database.ref('users/$userId').get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user data: ${e.toString()}');
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    try {
      await database.ref('users/$userId').update(data);
    } catch (e) {
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  // Update UserModel profile (for address setup)
  Future<void> updateUserModelProfile(UserModel user) async {
    try {
      final data = user.toMap();
      // Remove id from data as it's the key
      data.remove('id');
      
      await database.ref('users/${user.id}').update(data);
      _addDebugLog('✅ User profile updated: ${user.name}');
    } catch (e) {
      _addDebugLog('❌ Failed to update user profile: ${e.toString()}');
      throw Exception('Failed to update profile: ${e.toString()}');
    }
  }

  // Get online users
  Stream<DatabaseEvent> getOnlineUsers() {
    return database.ref('users').orderByChild('isOnline').equalTo(true).onValue;
  }

  // Setup push notifications
  Future<void> setupPushNotifications() async {
    try {
      // Request permission
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Get FCM token
        final token = await messaging.getToken();
        print('FCM Token: $token');

        // Save token to user document
        if (currentUser != null) {
          await database.ref('users/${currentUser!.uid}').update({
            'fcmToken': token,
          });
        }

        // Log notification permission granted
        await analytics.logEvent(name: 'notification_permission_granted');
      }
    } catch (e) {
      throw Exception('Push notification setup failed: ${e.toString()}');
    }
  }

  // Send emergency alert with enhanced features
  Future<String> sendEmergencyAlert({
    required String message,
    required String location,
    required String userId,
    String priority = 'medium',
    String alertType = 'general',
    Map<String, dynamic>? coordinates,
    List<String>? tags,
  }) async {
    try {
      final alertData = {
        'message': message,
        'location': location,
        'userId': userId,
        'priority': priority,
        'alertType': alertType,
        'coordinates': coordinates,
        'tags': tags,
        'timestamp': ServerValue.timestamp,
        'type': 'emergency',
        'status': 'active',
        'isResolved': false,
        'acknowledgments': {},
        'responseTeam': {},
        'updates': [],
        'media': [],
      };

      final alertRef = database.ref('emergency_alerts').push();
      await alertRef.set(alertData);
      
      // Log emergency alert
      await analytics.logEvent(
        name: 'emergency_alert_sent',
        parameters: {
          'location': location,
          'priority': priority,
          'alertType': alertType,
        },
      );
      
      return alertRef.key!;
    } catch (e) {
      throw Exception('Failed to send emergency alert: ${e.toString()}');
    }
  }

  // Get emergency alerts
  Stream<DatabaseEvent> getEmergencyAlerts() {
    return database.ref('emergency_alerts').onValue;
  }

  // Enhanced user management methods (removed duplicate)

  // Get user profile with enhanced data
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final snapshot = await database.ref('users/$userId').get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user profile: ${e.toString()}');
    }
  }

  // Enhanced messaging with moderation
  Future<void> sendMessageWithModeration({
    required String chatId,
    required String message,
    required String senderId,
    required String senderName,
    String? imageUrl,
    String messageType = 'text',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final messageData = {
        'message': message,
        'senderId': senderId,
        'senderName': senderName,
        'timestamp': ServerValue.timestamp,
        'imageUrl': imageUrl,
        'type': messageType,
        'metadata': metadata ?? {},
        'isModerated': false,
        'priority': messageType == 'emergency' ? 'high' : 'normal',
        'processedAt': ServerValue.timestamp,
      };

      await database.ref('chats/$chatId/messages').push().set(messageData);
      
      // Log message sent event
      await analytics.logEvent(
        name: 'message_sent',
        parameters: {
          'chat_type': chatId == 'global' ? 'global' : 'private',
          'message_type': messageType,
        },
      );
    } catch (e) {
      throw Exception('Failed to send message: ${e.toString()}');
    }
  }

  // Acknowledge emergency alert
  Future<void> acknowledgeEmergencyAlert({
    required String alertId,
    required String userId,
    required String userName,
  }) async {
    try {
      await database.ref('emergency_alerts/$alertId/acknowledgments/$userId').set({
        'userId': userId,
        'userName': userName,
        'acknowledgedAt': ServerValue.timestamp,
      });

      // Log acknowledgment
      await analytics.logEvent(
        name: 'emergency_alert_acknowledged',
        parameters: {
          'alert_id': alertId,
        },
      );
    } catch (e) {
      throw Exception('Failed to acknowledge alert: ${e.toString()}');
    }
  }

  // Update alert status
  Future<void> updateAlertStatus({
    required String alertId,
    required String status,
    String? resolution,
    String? updatedBy,
  }) async {
    try {
      final updateData = {
        'status': status,
        'updatedAt': ServerValue.timestamp,
        'updatedBy': updatedBy,
      };

      if (status == 'resolved') {
        updateData['isResolved'] = true;
        updateData['resolvedAt'] = ServerValue.timestamp;
        updateData['resolution'] = resolution;
      }

      await database.ref('emergency_alerts/$alertId').update(updateData);

      // Log status update
      await analytics.logEvent(
        name: 'alert_status_updated',
        parameters: {
          'alert_id': alertId,
          'status': status,
        },
      );
    } catch (e) {
      throw Exception('Failed to update alert status: ${e.toString()}');
    }
  }

  // Get analytics data
  Future<Map<String, dynamic>> getAnalyticsData({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // This would typically call a Cloud Function
      // For now, return basic analytics
      final usersSnapshot = await database.ref('users').get();
      final messagesSnapshot = await database.ref('chats').get();
      final alertsSnapshot = await database.ref('emergency_alerts').get();

      final users = usersSnapshot.value as Map? ?? {};
      final messages = messagesSnapshot.value as Map? ?? {};
      final alerts = alertsSnapshot.value as Map? ?? {};

      return {
        'totalUsers': users.length,
        'onlineUsers': users.values.where((user) => user['isOnline'] == true).length,
        'totalMessages': _countMessages(messages),
        'totalAlerts': alerts.length,
        'activeAlerts': alerts.values.where((alert) => alert['status'] == 'active').length,
        'generatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw Exception('Failed to get analytics: ${e.toString()}');
    }
  }

  // Helper method to count messages
  int _countMessages(Map messages) {
    int count = 0;
    messages.forEach((chatId, chatData) {
      if (chatData is Map && chatData['messages'] is Map) {
        count += (chatData['messages'] as Map).length;
      }
    });
    return count;
  }

  // Enhanced file upload with metadata
  Future<String> uploadFileWithMetadata({
    required String filePath,
    required String fileName,
    required String folder,
    Map<String, dynamic>? metadata,
    String? userId,
  }) async {
    try {
      final ref = storage.ref().child('$folder/$fileName');
      final uploadTask = await ref.putFile(File(filePath));
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      // Store file metadata in database
      if (metadata != null) {
        await database.ref('files/$folder/$fileName').set({
          'url': downloadUrl,
          'fileName': fileName,
          'folder': folder,
          'uploadedBy': userId,
          'uploadedAt': ServerValue.timestamp,
          'metadata': metadata,
        });
      }
      
      // Log file upload event
      await analytics.logEvent(
        name: 'file_uploaded',
        parameters: {
          'file_type': fileName.split('.').last,
          'folder': folder,
        },
      );
      
      return downloadUrl;
    } catch (e) {
      throw Exception('File upload failed: ${e.toString()}');
    }
  }

  // Get online users list (enhanced version)
  Future<List<Map<String, dynamic>>> getOnlineUsersList() async {
    try {
      final snapshot = await database.ref('users')
          .orderByChild('isOnline')
          .equalTo(true)
          .get();
      
      if (snapshot.exists) {
        final users = snapshot.value as Map;
        return users.entries.map((entry) {
          final userData = entry.value as Map<String, dynamic>;
          return {
            'id': entry.key,
            ...userData,
          };
        }).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Failed to get online users: ${e.toString()}');
    }
  }

  // Search users
  Future<List<Map<String, dynamic>>> searchUsers({
    required String query,
    String? region,
    String? city,
  }) async {
    try {
      final snapshot = await database.ref('users').get();
      if (!snapshot.exists) return [];

      final users = snapshot.value as Map;
      final results = <Map<String, dynamic>>[];

      users.forEach((userId, userData) {
        final user = userData as Map<String, dynamic>;
        final fullName = '${user['FirstName']} ${user['LastName']}'.toLowerCase();
        final email = user['Email']?.toString().toLowerCase() ?? '';
        final userRegion = user['Region']?.toString() ?? '';
        final userCity = user['City']?.toString() ?? '';

        bool matchesQuery = fullName.contains(query.toLowerCase()) ||
            email.contains(query.toLowerCase());
        
        bool matchesLocation = (region == null || userRegion.contains(region)) &&
            (city == null || userCity.contains(city));

        if (matchesQuery && matchesLocation) {
          results.add({
            'id': userId,
            ...user,
          });
        }
      });

      return results;
    } catch (e) {
      throw Exception('Failed to search users: ${e.toString()}');
    }
  }
}
