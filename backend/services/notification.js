const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
const logger = require('../utils/logger');

class NotificationService {
  constructor() {
    this.firebaseApp = null;
    this.emailTransporter = null;
  }

  async initialize() {
    try {
      // Initialize Firebase Admin SDK
      if (!admin.apps.length) {
        const serviceAccount = {
          type: "service_account",
          project_id: process.env.FIREBASE_PROJECT_ID,
          private_key_id: process.env.FIREBASE_PRIVATE_KEY_ID,
          private_key: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
          client_email: process.env.FIREBASE_CLIENT_EMAIL,
          client_id: process.env.FIREBASE_CLIENT_ID,
          auth_uri: "https://accounts.google.com/o/oauth2/auth",
          token_uri: "https://oauth2.googleapis.com/token",
          auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
          client_x509_cert_url: `https://www.googleapis.com/robot/v1/metadata/x509/${process.env.FIREBASE_CLIENT_EMAIL}`
        };

        this.firebaseApp = admin.initializeApp({
          credential: admin.credential.cert(serviceAccount),
          projectId: process.env.FIREBASE_PROJECT_ID
        });
      }

      // Initialize email transporter
      this.emailTransporter = nodemailer.createTransporter({
        host: process.env.SMTP_HOST,
        port: process.env.SMTP_PORT,
        secure: process.env.SMTP_SECURE === 'true',
        auth: {
          user: process.env.SMTP_USER,
          pass: process.env.SMTP_PASS
        }
      });

      logger.info('Notification service initialized successfully');
    } catch (error) {
      logger.error('Failed to initialize notification service:', error);
      throw error;
    }
  }

  // Send push notification to specific user
  async sendPushNotification(userId, notificationData) {
    try {
      const { title, body, data = {}, imageUrl } = notificationData;

      const message = {
        notification: {
          title,
          body,
          imageUrl
        },
        data: {
          ...data,
          timestamp: new Date().toISOString()
        },
        topic: `user_${userId}`,
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK'
          }
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1
            }
          }
        }
      };

      const response = await admin.messaging().send(message);
      logger.info(`Push notification sent to user ${userId}: ${response}`);
      
      return response;
    } catch (error) {
      logger.error(`Failed to send push notification to user ${userId}:`, error);
      throw error;
    }
  }

  // Send push notification to multiple users
  async sendBulkPushNotification(userIds, notificationData) {
    try {
      const { title, body, data = {}, imageUrl } = notificationData;

      const messages = userIds.map(userId => ({
        notification: {
          title,
          body,
          imageUrl
        },
        data: {
          ...data,
          timestamp: new Date().toISOString()
        },
        topic: `user_${userId}`,
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK'
          }
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1
            }
          }
        }
      }));

      const response = await admin.messaging().sendAll(messages);
      logger.info(`Bulk push notifications sent to ${userIds.length} users: ${response.successCount} successful, ${response.failureCount} failed`);
      
      return response;
    } catch (error) {
      logger.error('Failed to send bulk push notifications:', error);
      throw error;
    }
  }

  // Send push notification to all users
  async broadcastPushNotification(notificationData) {
    try {
      const { title, body, data = {}, imageUrl } = notificationData;

      const message = {
        notification: {
          title,
          body,
          imageUrl
        },
        data: {
          ...data,
          timestamp: new Date().toISOString()
        },
        topic: 'all_users',
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK'
          }
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1
            }
          }
        }
      };

      const response = await admin.messaging().send(message);
      logger.info(`Broadcast push notification sent: ${response}`);
      
      return response;
    } catch (error) {
      logger.error('Failed to send broadcast push notification:', error);
      throw error;
    }
  }

  // Send email notification
  async sendEmailNotification(email, subject, htmlContent, textContent) {
    try {
      const mailOptions = {
        from: process.env.SMTP_FROM || process.env.SMTP_USER,
        to: email,
        subject,
        html: htmlContent,
        text: textContent
      };

      const response = await this.emailTransporter.sendMail(mailOptions);
      logger.info(`Email sent to ${email}: ${response.messageId}`);
      
      return response;
    } catch (error) {
      logger.error(`Failed to send email to ${email}:`, error);
      throw error;
    }
  }

  // Send emergency alert notification
  async sendEmergencyAlert(alertData, recipients) {
    try {
      const { message, location, priority, alertType } = alertData;
      
      const notificationData = {
        title: `🚨 Emergency Alert - ${alertType.toUpperCase()}`,
        body: `${message}\nLocation: ${location}`,
        data: {
          type: 'emergency_alert',
          alertId: alertData.id,
          priority,
          location,
          timestamp: new Date().toISOString()
        }
      };

      // Send push notifications
      if (recipients.length > 0) {
        await this.sendBulkPushNotification(recipients, notificationData);
      }

      // Send email notifications for critical alerts
      if (priority === 'critical' || priority === 'high') {
        const emailPromises = recipients.map(async (userId) => {
          // Get user email from database (you'll need to implement this)
          // const user = await User.findById(userId);
          // if (user && user.email) {
          //   await this.sendEmailNotification(
          //     user.email,
          //     notificationData.title,
          //     `<h2>Emergency Alert</h2><p>${message}</p><p><strong>Location:</strong> ${location}</p>`,
          //     `${notificationData.title}\n\n${message}\nLocation: ${location}`
          //   );
          // }
        });
        
        await Promise.all(emailPromises);
      }

      logger.info(`Emergency alert notifications sent to ${recipients.length} recipients`);
    } catch (error) {
      logger.error('Failed to send emergency alert notifications:', error);
      throw error;
    }
  }

  // Send message notification
  async sendMessageNotification(recipientId, senderName, message, chatId) {
    try {
      const notificationData = {
        title: `New message from ${senderName}`,
        body: message,
        data: {
          type: 'message',
          chatId,
          senderName,
          timestamp: new Date().toISOString()
        }
      };

      await this.sendPushNotification(recipientId, notificationData);
    } catch (error) {
      logger.error(`Failed to send message notification to user ${recipientId}:`, error);
      throw error;
    }
  }

  // Send system notification
  async sendSystemNotification(userId, title, message, type = 'info') {
    try {
      const notificationData = {
        title,
        body: message,
        data: {
          type: 'system',
          notificationType: type,
          timestamp: new Date().toISOString()
        }
      };

      await this.sendPushNotification(userId, notificationData);
    } catch (error) {
      logger.error(`Failed to send system notification to user ${userId}:`, error);
      throw error;
    }
  }

  // Send welcome notification
  async sendWelcomeNotification(userId, userName) {
    try {
      const notificationData = {
        title: 'Welcome to T.U.L.O.N.G!',
        body: `Hello ${userName}, you're now connected to the emergency communication network.`,
        data: {
          type: 'welcome',
          timestamp: new Date().toISOString()
        }
      };

      await this.sendPushNotification(userId, notificationData);
    } catch (error) {
      logger.error(`Failed to send welcome notification to user ${userId}:`, error);
      throw error;
    }
  }

  // Get notification statistics
  async getNotificationStats() {
    try {
      // This would typically query your database for notification statistics
      // For now, return mock data
      return {
        totalSent: 0,
        successfulDeliveries: 0,
        failedDeliveries: 0,
        lastSent: null
      };
    } catch (error) {
      logger.error('Failed to get notification statistics:', error);
      throw error;
    }
  }
}

module.exports = new NotificationService();
