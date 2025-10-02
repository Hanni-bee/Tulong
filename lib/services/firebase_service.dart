import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../utils/input_validator.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // Firebase instances
  FirebaseAuth get auth => FirebaseAuth.instance;
  FirebaseDatabase get database => FirebaseDatabase.instance;
  FirebaseStorage get storage => FirebaseStorage.instance;
  FirebaseAnalytics get analytics => FirebaseAnalytics.instance;
  FirebaseMessaging get messaging => FirebaseMessaging.instance;
  
  // Google Sign-In - Android compatible implementation
  Future<UserCredential?> signInWithGoogle() async {
    try {
      print('🔐 Starting Google Sign-In process...');

      // Initialize Google Sign-In
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      // Sign out from Google first to ensure clean state
      await googleSignIn.signOut();
      await auth.signOut();

      print('✅ Cleared previous sessions');

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        print('❌ Google Sign-In was cancelled by user');
        return null;
      }

      print('✅ Google Sign-In successful: ${googleUser.email}');

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await auth.signInWithCredential(credential);

      if (userCredential.user == null) {
        print('❌ Firebase Google sign-in failed');
        return null;
      }

      print('✅ Firebase Google sign-in successful: ${userCredential.user!.email}');

      // Update user profile in database
      final user = userCredential.user!;
      final displayName = user.displayName ?? user.email?.split('@')[0] ?? 'User';
      final email = user.email ?? '';

      await database.ref('users/${user.uid}').update({
        'FirstName': displayName.split(' ')[0],
        'LastName': displayName.split(' ').length > 1 ? displayName.split(' ').sublist(1).join(' ') : '',
        'Email': email,
        'DisplayName': displayName,
        'PhotoURL': user.photoURL ?? '',
        'Provider': 'google',
        'isOnline': true,
        'lastSeen': ServerValue.timestamp,
        'signInMethod': 'google',
      });

      print('✅ User profile updated in database');

      // Log analytics
      await analytics.logLogin(loginMethod: 'google');

      print('🎉 Google Sign-In completed successfully');
      return userCredential;

    } catch (e) {
      print('❌ Google Sign-In error: $e');
      throw Exception('Google sign in failed: ${e.toString()}');
    }
  }

  // Current user
  User? get currentUser => auth.currentUser;

  // Hash password using SHA-256
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
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

  // Authentication methods
  Future<UserCredential?> signUpWithEmail({
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
      // Validate all input data
      final validationErrors = InputValidator.validateUserInput(
        email: email,
        password: password,
        confirmPassword: password, // For signup, password serves as confirmation
        firstName: firstName,
        lastName: lastName,
        address: address,
        region: region,
        city: city,
        barangay: barangay,
        zipCode: zipCode,
      );

      // Check for validation errors
      final errors = validationErrors.values.where((error) => error != null).toList();
      if (errors.isNotEmpty) {
        throw Exception('Validation failed: ${errors.join(', ')}');
      }

      // Sanitize inputs
      final sanitizedFirstName = InputValidator.sanitizeText(firstName);
      final sanitizedLastName = InputValidator.sanitizeText(lastName);
      final sanitizedAddress = InputValidator.sanitizeText(address);
      final sanitizedRegion = InputValidator.sanitizeText(region);
      final sanitizedCity = InputValidator.sanitizeText(city);
      final sanitizedBarangay = InputValidator.sanitizeText(barangay);

      final userCredential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Create user profile in Realtime Database
      if (userCredential.user != null) {
        await database.ref('users/${userCredential.user!.uid}').set({
          'FirstName': sanitizedFirstName,
          'LastName': sanitizedLastName,
          'Email': email.trim(),
          'Address': sanitizedAddress,
          'Region': sanitizedRegion,
          'City': sanitizedCity,
          'Barangay': sanitizedBarangay,
          'ZipCode': zipCode,
          'Password': _hashPassword(password), // Hash passwords for security
          'createdAt': ServerValue.timestamp,
          'isOnline': true,
          'lastSeen': ServerValue.timestamp,
        });

        // Log sign up event
        await analytics.logSignUp(signUpMethod: 'email');
      }

      return userCredential;
    } catch (e) {
      throw Exception('Sign up failed: ${e.toString()}');
    }
  }

  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // Validate inputs
      final emailError = InputValidator.validateEmail(email);
      if (emailError != null) {
        throw Exception(emailError);
      }

      if (password.isEmpty) {
        throw Exception('Password is required');
      }

      // Hash the provided password for comparison
      final hashedPassword = _hashPassword(password);

      // First verify the user exists and password matches in our database
      final userSnapshot = await database.ref('users').orderByChild('Email').equalTo(email.trim()).get();
      if (userSnapshot.exists) {
        final users = userSnapshot.value as Map;
        bool validUser = false;

        users.forEach((key, value) {
          final user = value as Map;
          if (user['Password'] == hashedPassword) {
            validUser = true;
          }
        });

        if (!validUser) {
          throw Exception('Invalid email or password');
        }
      } else {
        throw Exception('Invalid email or password');
      }

      final userCredential = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Update user online status
      if (userCredential.user != null) {
        await database.ref('users/${userCredential.user!.uid}').update({
          'isOnline': true,
          'lastSeen': ServerValue.timestamp,
        });

        // Log sign in event
        await analytics.logLogin(loginMethod: 'email');
      }

      return userCredential;
    } catch (e) {
      throw Exception('Sign in failed: ${e.toString()}');
    }
  }


  // Forgot Password - Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      // Validate email
      final emailError = InputValidator.validateEmail(email);
      if (emailError != null) {
        throw Exception(emailError);
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
      throw Exception('Failed to send password reset email: ${e.toString()}');
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
      // Update user offline status
      if (currentUser != null) {
        await database.ref('users/${currentUser!.uid}').update({
          'isOnline': false,
          'lastSeen': ServerValue.timestamp,
        });
      }

      // Sign out from Google Sign-In
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      
      // Sign out from Firebase
      await auth.signOut();
      await analytics.logEvent(name: 'user_sign_out');
    } catch (e) {
      throw Exception('Sign out failed: ${e.toString()}');
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
