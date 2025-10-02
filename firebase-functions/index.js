const functions = require('firebase-functions');
const admin = require('firebase-admin');
const express = require('express');
const cors = require('cors');

// Initialize Firebase Admin (only if not already initialized)
if (!admin.apps.length) {
  admin.initializeApp();
}

const app = express();
app.use(cors({ origin: true }));

// Enhanced User Management
exports.createUserProfile = functions.auth.user().onCreate(async (user) => {
  try {
    const userProfile = {
      uid: user.uid,
      email: user.email,
      displayName: user.displayName || '',
      photoURL: user.photoURL || '',
      isOnline: true,
      lastSeen: admin.database.ServerValue.TIMESTAMP,
      createdAt: admin.database.ServerValue.TIMESTAMP,
      role: 'user',
      isVerified: false,
      preferences: {
        notifications: {
          email: true,
          push: true,
          emergency: true
        },
        privacy: {
          showLocation: false,
          showOnlineStatus: true
        }
      }
    };

    await admin.database().ref(`users/${user.uid}`).set(userProfile);
    console.log('User profile created:', user.uid);
  } catch (error) {
    console.error('Error creating user profile:', error);
  }
});

// Enhanced Messaging with Auto-moderation
exports.processMessage = functions.database.ref('/chats/{chatId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const message = snapshot.val();
    const { chatId, messageId } = context.params;

    // Add message metadata
    const enhancedMessage = {
      ...message,
      processedAt: admin.database.ServerValue.TIMESTAMP,
      isModerated: false,
      priority: message.messageType === 'emergency' ? 'high' : 'normal'
    };

    await snapshot.ref.update(enhancedMessage);

    // Send push notifications for emergency messages
    if (message.messageType === 'emergency') {
      await sendEmergencyNotification(chatId, message);
    }

    return null;
  });

// Emergency Alert Broadcasting
exports.broadcastEmergencyAlert = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { message, location, priority, alertType } = data;
  const userId = context.auth.uid;

  // Get user info
  const userSnapshot = await admin.database().ref(`users/${userId}`).once('value');
  const user = userSnapshot.val();

  if (!user) {
    throw new functions.https.HttpsError('not-found', 'User not found');
  }

  // Create emergency alert
  const alertData = {
    message,
    location,
    priority: priority || 'medium',
    alertType: alertType || 'general',
    senderId: userId,
    senderName: user.displayName || user.email,
    timestamp: admin.database.ServerValue.TIMESTAMP,
    status: 'active',
    isResolved: false,
    acknowledgments: {},
    responseTeam: {}
  };

  // Save to database
  const alertRef = await admin.database().ref('emergency_alerts').push(alertData);

  // Get all online users
  const usersSnapshot = await admin.database().ref('users')
    .orderByChild('isOnline')
    .equalTo(true)
    .once('value');

  const onlineUsers = usersSnapshot.val() || {};
  const userIds = Object.keys(onlineUsers);

  // Send push notifications to all online users
  if (userIds.length > 0) {
    await sendBulkPushNotification(userIds, {
      title: `🚨 Emergency Alert - ${alertType.toUpperCase()}`,
      body: message,
      data: {
        alertId: alertRef.key,
        priority,
        location,
        type: 'emergency_alert'
      }
    });
  }

  return { alertId: alertRef.key, recipients: userIds.length };
});

// Auto-sync offline data when user comes online
exports.syncOfflineData = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const userId = context.auth.uid;
  const { offlineMessages, offlineAlerts } = data;

  const batch = [];

  // Sync offline messages
  if (offlineMessages && offlineMessages.length > 0) {
    for (const message of offlineMessages) {
      const messageRef = admin.database().ref('chats').child(message.chatId).child('messages').push();
      batch.push(messageRef.set({
        ...message,
        syncedAt: admin.database.ServerValue.TIMESTAMP,
        isOfflineSync: true
      }));
    }
  }

  // Sync offline alerts
  if (offlineAlerts && offlineAlerts.length > 0) {
    for (const alert of offlineAlerts) {
      const alertRef = admin.database().ref('emergency_alerts').push();
      batch.push(alertRef.set({
        ...alert,
        syncedAt: admin.database.ServerValue.TIMESTAMP,
        isOfflineSync: true
      }));
    }
  }

  await Promise.all(batch);
  return { synced: batch.length };
});

// Analytics and Reporting
exports.generateAnalytics = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const user = await admin.auth().getUser(context.auth.uid);
  if (!user.customClaims || user.customClaims.role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const { startDate, endDate } = data;
  
  // Get analytics data
  const analytics = await generateAnalyticsData(startDate, endDate);
  
  return analytics;
});

// Helper Functions
async function sendEmergencyNotification(chatId, message) {
  try {
    // Get chat participants
    const chatSnapshot = await admin.database().ref(`chats/${chatId}/participants`).once('value');
    const participants = chatSnapshot.val() || {};
    
    const userIds = Object.keys(participants);
    
    if (userIds.length > 0) {
      await sendBulkPushNotification(userIds, {
        title: '🚨 Emergency Message',
        body: message.message,
        data: {
          chatId,
          messageId: message.id,
          type: 'emergency_message'
        }
      });
    }
  } catch (error) {
    console.error('Error sending emergency notification:', error);
  }
}

async function sendBulkPushNotification(userIds, notification) {
  try {
    // Get FCM tokens for users
    const tokens = [];
    for (const userId of userIds) {
      const userSnapshot = await admin.database().ref(`users/${userId}/fcmToken`).once('value');
      const token = userSnapshot.val();
      if (token) {
        tokens.push(token);
      }
    }

    if (tokens.length > 0) {
      const message = {
        notification: {
          title: notification.title,
          body: notification.body
        },
        data: notification.data,
        tokens: tokens
      };

      await admin.messaging().sendMulticast(message);
    }
  } catch (error) {
    console.error('Error sending bulk push notification:', error);
  }
}

async function generateAnalyticsData(startDate, endDate) {
  // Implementation for analytics data generation
  return {
    totalUsers: 0,
    activeUsers: 0,
    messagesSent: 0,
    emergencyAlerts: 0,
    // ... more analytics
  };
}

// HTTP API endpoints
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

app.get('/users/online', async (req, res) => {
  try {
    const snapshot = await admin.database().ref('users')
      .orderByChild('isOnline')
      .equalTo(true)
      .once('value');
    
    const onlineUsers = snapshot.val() || {};
    res.json({ 
      success: true, 
      count: Object.keys(onlineUsers).length,
      users: onlineUsers 
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

app.get('/emergency/stats', async (req, res) => {
  try {
    const snapshot = await admin.database().ref('emergency_alerts').once('value');
    const alerts = snapshot.val() || {};
    
    const stats = {
      total: Object.keys(alerts).length,
      active: Object.values(alerts).filter(alert => alert.status === 'active').length,
      resolved: Object.values(alerts).filter(alert => alert.isResolved).length
    };
    
    res.json({ success: true, stats });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

exports.api = functions.https.onRequest(app);
