import 'package:firebase_database/firebase_database.dart';

class FirebaseRealtimeTest {
  static final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Test method to add sample user data to Realtime Database
  static Future<void> addTestUser() async {
    try {
      final userData = {
        'FirstName': 'Juan',
        'LastName': 'Dela Cruz',
        'Email': 'juan.delacruz@example.com',
        'Address': '123 Main Street, Barangay San Antonio',
        'Region': 'NCR',
        'City': 'Quezon City',
        'Barangay': 'San Antonio',
        'ZipCode': '1105',
        'Password': 'password123', // Note: Don't store plain passwords in production
        'createdAt': ServerValue.timestamp,
        'isOnline': true,
        'lastSeen': ServerValue.timestamp,
      };

      // Store in Realtime Database
      await _database.ref('users/test_user_123').set(userData);
      
      print('✅ Test user data added to Firebase Realtime Database');
      print('📊 Data structure in Firebase:');
      print('   /users/test_user_123/');
      userData.forEach((key, value) {
        print('     $key: $value');
      });
    } catch (e) {
      print('❌ Error adding test user: $e');
    }
  }

  // Test method to add sample message data
  static Future<void> addTestMessage() async {
    try {
      final messageData = {
        'message': 'Hello! This is a test message.',
        'senderId': 'test_user_123',
        'senderName': 'Juan Dela Cruz',
        'timestamp': ServerValue.timestamp,
        'type': 'text',
        'imageUrl': null,
      };

      // Store in Realtime Database
      await _database.ref('chats/global_chat/messages/test_message_123').set(messageData);
      
      print('✅ Test message added to Firebase Realtime Database');
      print('📊 Data structure in Firebase:');
      print('   /chats/global_chat/messages/test_message_123/');
      messageData.forEach((key, value) {
        print('     $key: $value');
      });
    } catch (e) {
      print('❌ Error adding test message: $e');
    }
  }

  // Test method to add sample emergency alert
  static Future<void> addTestEmergencyAlert() async {
    try {
      final alertData = {
        'message': 'Emergency! Need help at location.',
        'location': 'Quezon City, NCR',
        'userId': 'test_user_123',
        'timestamp': ServerValue.timestamp,
        'type': 'emergency',
        'status': 'active',
      };

      // Store in Realtime Database
      await _database.ref('emergency_alerts/test_alert_123').set(alertData);
      
      print('✅ Test emergency alert added to Firebase Realtime Database');
      print('📊 Data structure in Firebase:');
      print('   /emergency_alerts/test_alert_123/');
      alertData.forEach((key, value) {
        print('     $key: $value');
      });
    } catch (e) {
      print('❌ Error adding test emergency alert: $e');
    }
  }

  // Test method to read user data from Realtime Database
  static Future<void> readTestUser() async {
    try {
      final snapshot = await _database.ref('users/test_user_123').get();
      if (snapshot.exists) {
        print('✅ Test user data retrieved from Firebase Realtime Database:');
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        data.forEach((key, value) {
          print('   $key: $value');
        });
      } else {
        print('❌ No test user data found');
      }
    } catch (e) {
      print('❌ Error reading test user: $e');
    }
  }

  // Test method to listen to real-time changes
  static Stream<DatabaseEvent> listenToUsers() {
    return _database.ref('users').onValue;
  }

  // Test method to listen to messages
  static Stream<DatabaseEvent> listenToMessages() {
    return _database.ref('chats/global_chat/messages').onValue;
  }

  // Test method to listen to emergency alerts
  static Stream<DatabaseEvent> listenToEmergencyAlerts() {
    return _database.ref('emergency_alerts').onValue;
  }

  // Test method to update user data
  static Future<void> updateTestUser() async {
    try {
      await _database.ref('users/test_user_123').update({
        'isOnline': false,
        'lastSeen': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
      });
      print('✅ Test user data updated in Firebase Realtime Database');
    } catch (e) {
      print('❌ Error updating test user: $e');
    }
  }

  // Test method to delete user data
  static Future<void> deleteTestUser() async {
    try {
      await _database.ref('users/test_user_123').remove();
      print('✅ Test user data deleted from Firebase Realtime Database');
    } catch (e) {
      print('❌ Error deleting test user: $e');
    }
  }

  // Test method to show Firebase Realtime Database structure
  static void showDatabaseStructure() {
    print('🔥 Firebase Realtime Database Structure:');
    print('');
    print('📁 /users/');
    print('   └── /{userId}/');
    print('       ├── FirstName: "Juan"');
    print('       ├── LastName: "Dela Cruz"');
    print('       ├── Email: "juan@example.com"');
    print('       ├── Address: "123 Main Street"');
    print('       ├── Region: "NCR"');
    print('       ├── City: "Quezon City"');
    print('       ├── Barangay: "San Antonio"');
    print('       ├── ZipCode: "1105"');
    print('       ├── Password: "hashed_password"');
    print('       ├── createdAt: timestamp');
    print('       ├── isOnline: true');
    print('       └── lastSeen: timestamp');
    print('');
    print('📁 /chats/');
    print('   └── /{chatId}/');
    print('       └── /messages/');
    print('           └── /{messageId}/');
    print('               ├── message: "Hello!"');
    print('               ├── senderId: "user123"');
    print('               ├── senderName: "Juan Dela Cruz"');
    print('               ├── timestamp: timestamp');
    print('               ├── type: "text"');
    print('               └── imageUrl: null');
    print('');
    print('📁 /emergency_alerts/');
    print('   └── /{alertId}/');
    print('       ├── message: "Emergency!"');
    print('       ├── location: "Quezon City"');
    print('       ├── userId: "user123"');
    print('       ├── timestamp: timestamp');
    print('       ├── type: "emergency"');
    print('       └── status: "active"');
  }
}
