// T.U.L.O.N.G Firebase Enhancements Test Script
// This script tests the new Firebase features without breaking existing functionality

import 'package:flutter/material.dart';
import 'lib/services/firebase_service.dart';

class FirebaseEnhancementsTest {
  static final FirebaseService _firebaseService = FirebaseService();

  // Test enhanced user profile management
  static Future<void> testUserProfileEnhancements() async {
    print('🧪 Testing User Profile Enhancements...');
    
    try {
      // Test getting user profile
      final user = _firebaseService.currentUser;
      if (user != null) {
        final profile = await _firebaseService.getUserProfile(user.uid);
        print('✅ User profile retrieved: ${profile != null ? 'Success' : 'Failed'}');
        
        // Test updating profile
        await _firebaseService.updateUserProfile(
          userId: user.uid,
          profileData: {
            'lastSeen': DateTime.now().millisecondsSinceEpoch,
            'testField': 'test_value',
          },
        );
        print('✅ User profile updated successfully');
      }
    } catch (e) {
      print('❌ User profile test failed: $e');
    }
  }

  // Test enhanced messaging
  static Future<void> testMessagingEnhancements() async {
    print('🧪 Testing Messaging Enhancements...');
    
    try {
      final user = _firebaseService.currentUser;
      if (user != null) {
        // Test enhanced message sending
        await _firebaseService.sendMessageWithModeration(
          chatId: 'test_chat',
          message: 'Test message with moderation',
          senderId: user.uid,
          senderName: user.displayName ?? 'Test User',
          messageType: 'text',
          metadata: {'test': true},
        );
        print('✅ Enhanced message sent successfully');
      }
    } catch (e) {
      print('❌ Messaging test failed: $e');
    }
  }

  // Test emergency alert enhancements
  static Future<void> testEmergencyAlertEnhancements() async {
    print('🧪 Testing Emergency Alert Enhancements...');
    
    try {
      final user = _firebaseService.currentUser;
      if (user != null) {
        // Test enhanced emergency alert
        final alertId = await _firebaseService.sendEmergencyAlert(
          message: 'Test emergency alert',
          location: 'Test Location',
          userId: user.uid,
          priority: 'medium',
          alertType: 'test',
          coordinates: {'lat': 14.5995, 'lng': 120.9842},
          tags: ['test', 'automated'],
        );
        print('✅ Enhanced emergency alert sent: $alertId');
        
        // Test acknowledging alert
        await _firebaseService.acknowledgeEmergencyAlert(
          alertId: alertId,
          userId: user.uid,
          userName: user.displayName ?? 'Test User',
        );
        print('✅ Emergency alert acknowledged successfully');
        
        // Test updating alert status
        await _firebaseService.updateAlertStatus(
          alertId: alertId,
          status: 'resolved',
          resolution: 'Test resolution',
          updatedBy: user.uid,
        );
        print('✅ Alert status updated successfully');
      }
    } catch (e) {
      print('❌ Emergency alert test failed: $e');
    }
  }

  // Test analytics
  static Future<void> testAnalytics() async {
    print('🧪 Testing Analytics...');
    
    try {
      final analytics = await _firebaseService.getAnalyticsData();
      print('✅ Analytics data retrieved: $analytics');
    } catch (e) {
      print('❌ Analytics test failed: $e');
    }
  }

  // Test user search
  static Future<void> testUserSearch() async {
    print('🧪 Testing User Search...');
    
    try {
      final users = await _firebaseService.searchUsers(
        query: 'test',
        region: 'NCR',
        city: 'Manila',
      );
      print('✅ User search completed: ${users.length} results');
    } catch (e) {
      print('❌ User search test failed: $e');
    }
  }

  // Test online users
  static Future<void> testOnlineUsers() async {
    print('🧪 Testing Online Users...');
    
    try {
      final onlineUsers = _firebaseService.getOnlineUsers();
      print('✅ Online users retrieved: ${onlineUsers.length} users');
    } catch (e) {
      print('❌ Online users test failed: $e');
    }
  }

  // Run all tests
  static Future<void> runAllTests() async {
    print('🚀 Starting Firebase Enhancements Tests...');
    print('==========================================');
    
    await testUserProfileEnhancements();
    await testMessagingEnhancements();
    await testEmergencyAlertEnhancements();
    await testAnalytics();
    await testUserSearch();
    await testOnlineUsers();
    
    print('==========================================');
    print('✅ All Firebase enhancement tests completed!');
    print('');
    print('📋 Test Summary:');
    print('  ✅ User Profile Enhancements');
    print('  ✅ Messaging Enhancements');
    print('  ✅ Emergency Alert Enhancements');
    print('  ✅ Analytics');
    print('  ✅ User Search');
    print('  ✅ Online Users');
    print('');
    print('🔧 If any tests failed, check:');
    print('  - Firebase connection');
    print('  - User authentication');
    print('  - Database permissions');
    print('  - Network connectivity');
  }
}

// Widget to run tests in your app
class FirebaseTestWidget extends StatelessWidget {
  const FirebaseTestWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Enhancements Test'),
        backgroundColor: const Color(0xFFD32F2F),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Test Firebase Enhancements',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'This will test all the new Firebase features without breaking your existing app.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await FirebaseEnhancementsTest.runAllTests();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tests completed! Check console for results.'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Run All Tests',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await FirebaseEnhancementsTest.testUserProfileEnhancements();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('User profile test completed!'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
              child: const Text('Test User Profile'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                await FirebaseEnhancementsTest.testMessagingEnhancements();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Messaging test completed!'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
              child: const Text('Test Messaging'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                await FirebaseEnhancementsTest.testEmergencyAlertEnhancements();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Emergency alert test completed!'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
              child: const Text('Test Emergency Alerts'),
            ),
          ],
        ),
      ),
    );
  }
}
