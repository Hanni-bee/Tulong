import 'package:firebase_database/firebase_database.dart';

class FirebaseTestService {
  static final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Test method to add sample user data
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

      await _database.ref('users/test_user_123').set(userData);
      print('✅ Test user data added to Firebase Realtime Database');
      print('📊 Data structure:');
      userData.forEach((key, value) {
        print('   $key: $value');
      });
    } catch (e) {
      print('❌ Error adding test user: $e');
    }
  }

  // Test method to read user data
  static Future<void> readTestUser() async {
    try {
      final snapshot = await _database.ref('users/test_user_123').get();
      if (snapshot.exists) {
        print('✅ Test user data retrieved from Firebase:');
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

  // Test method to update user data
  static Future<void> updateTestUser() async {
    try {
      await _database.ref('users/test_user_123').update({
        'isOnline': false,
        'lastSeen': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
      });
      print('✅ Test user data updated in Firebase');
    } catch (e) {
      print('❌ Error updating test user: $e');
    }
  }

  // Test method to delete user data
  static Future<void> deleteTestUser() async {
    try {
      await _database.ref('users/test_user_123').remove();
      print('✅ Test user data deleted from Firebase');
    } catch (e) {
      print('❌ Error deleting test user: $e');
    }
  }
}
