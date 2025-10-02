const express = require('express');
const EmergencyAlert = require('../models/EmergencyAlert');
const User = require('../models/User');
const NotificationService = require('../services/notification');
const logger = require('../utils/logger');

const router = express.Router();

// Send emergency alert
router.post('/alert', async (req, res) => {
  try {
    const { message, location, alertType = 'general', priority = 'medium' } = req.body;
    const userId = req.user.userId;
    const user = await User.findById(userId);

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User not found'
      });
    }

    // Create emergency alert
    const alert = new EmergencyAlert({
      message,
      location,
      alertType,
      priority,
      userId,
      senderName: `${user.firstName} ${user.lastName}`,
      timestamp: new Date(),
      status: 'active',
      isResolved: false
    });

    await alert.save();

    // Get all online users for broadcasting
    const onlineUsers = await User.find({ isOnline: true }).select('_id email firstName lastName');
    
    // Send push notifications to all online users
    const notificationData = {
      title: `🚨 Emergency Alert - ${alertType.toUpperCase()}`,
      body: message,
      data: {
        alertId: alert._id,
        senderName: alert.senderName,
        location,
        priority,
        timestamp: alert.timestamp
      }
    };

    // Broadcast to all online users
    for (const user of onlineUsers) {
      if (user._id.toString() !== userId) {
        await NotificationService.sendPushNotification(user._id, notificationData);
      }
    }

    // Emit to WebSocket clients
    req.app.get('io').emit('emergencyAlert', {
      id: alert._id,
      message: alert.message,
      location: alert.location,
      alertType: alert.alertType,
      priority: alert.priority,
      senderName: alert.senderName,
      timestamp: alert.timestamp,
      status: alert.status
    });

    logger.info(`Emergency alert sent by ${alert.senderName}: ${message}`);

    res.status(201).json({
      success: true,
      message: 'Emergency alert sent successfully',
      data: {
        id: alert._id,
        message: alert.message,
        location: alert.location,
        alertType: alert.alertType,
        priority: alert.priority,
        senderName: alert.senderName,
        timestamp: alert.timestamp,
        status: alert.status
      }
    });

  } catch (error) {
    logger.error('Send emergency alert error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Get emergency alerts
router.get('/alerts', async (req, res) => {
  try {
    const { page = 1, limit = 20, status = 'active', priority } = req.query;
    const skip = (page - 1) * limit;

    const filter = { status };
    if (priority) {
      filter.priority = priority;
    }

    const alerts = await EmergencyAlert.find(filter)
      .sort({ timestamp: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .lean();

    logger.info(`Retrieved ${alerts.length} emergency alerts`);

    res.json({
      success: true,
      data: {
        alerts,
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total: await EmergencyAlert.countDocuments(filter)
        }
      }
    });

  } catch (error) {
    logger.error('Get emergency alerts error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Get alert by ID
router.get('/alert/:alertId', async (req, res) => {
  try {
    const { alertId } = req.params;

    const alert = await EmergencyAlert.findById(alertId);
    if (!alert) {
      return res.status(404).json({
        success: false,
        message: 'Emergency alert not found'
      });
    }

    res.json({
      success: true,
      data: { alert }
    });

  } catch (error) {
    logger.error('Get emergency alert error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Update alert status
router.put('/alert/:alertId/status', async (req, res) => {
  try {
    const { alertId } = req.params;
    const { status, resolution } = req.body;
    const userId = req.user.userId;

    const alert = await EmergencyAlert.findById(alertId);
    if (!alert) {
      return res.status(404).json({
        success: false,
        message: 'Emergency alert not found'
      });
    }

    // Check if user is authorized to update this alert
    // In production, implement proper authorization logic
    if (alert.userId !== userId) {
      return res.status(403).json({
        success: false,
        message: 'Unauthorized to update this alert'
      });
    }

    alert.status = status;
    if (status === 'resolved') {
      alert.isResolved = true;
      alert.resolvedAt = new Date();
      alert.resolution = resolution;
    }

    await alert.save();

    // Emit status update to WebSocket clients
    req.app.get('io').emit('alertStatusUpdate', {
      alertId: alert._id,
      status: alert.status,
      isResolved: alert.isResolved,
      resolvedAt: alert.resolvedAt
    });

    logger.info(`Alert ${alertId} status updated to ${status} by user ${userId}`);

    res.json({
      success: true,
      message: 'Alert status updated successfully',
      data: {
        id: alert._id,
        status: alert.status,
        isResolved: alert.isResolved,
        resolvedAt: alert.resolvedAt,
        resolution: alert.resolution
      }
    });

  } catch (error) {
    logger.error('Update alert status error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Get user's alerts
router.get('/my-alerts', async (req, res) => {
  try {
    const userId = req.user.userId;
    const { page = 1, limit = 20 } = req.query;
    const skip = (page - 1) * limit;

    const alerts = await EmergencyAlert.find({ userId })
      .sort({ timestamp: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .lean();

    logger.info(`Retrieved ${alerts.length} alerts for user ${userId}`);

    res.json({
      success: true,
      data: {
        alerts,
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total: await EmergencyAlert.countDocuments({ userId })
        }
      }
    });

  } catch (error) {
    logger.error('Get user alerts error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Get emergency statistics
router.get('/stats', async (req, res) => {
  try {
    const stats = await EmergencyAlert.aggregate([
      {
        $group: {
          _id: null,
          totalAlerts: { $sum: 1 },
          activeAlerts: {
            $sum: { $cond: [{ $eq: ['$status', 'active'] }, 1, 0] }
          },
          resolvedAlerts: {
            $sum: { $cond: [{ $eq: ['$isResolved', true] }, 1, 0] }
          },
          highPriorityAlerts: {
            $sum: { $cond: [{ $eq: ['$priority', 'high'] }, 1, 0] }
          },
          mediumPriorityAlerts: {
            $sum: { $cond: [{ $eq: ['$priority', 'medium'] }, 1, 0] }
          },
          lowPriorityAlerts: {
            $sum: { $cond: [{ $eq: ['$priority', 'low'] }, 1, 0] }
          }
        }
      }
    ]);

    const alertTypes = await EmergencyAlert.aggregate([
      {
        $group: {
          _id: '$alertType',
          count: { $sum: 1 }
        }
      },
      { $sort: { count: -1 } }
    ]);

    logger.info('Emergency statistics retrieved');

    res.json({
      success: true,
      data: {
        stats: stats[0] || {
          totalAlerts: 0,
          activeAlerts: 0,
          resolvedAlerts: 0,
          highPriorityAlerts: 0,
          mediumPriorityAlerts: 0,
          lowPriorityAlerts: 0
        },
        alertTypes
      }
    });

  } catch (error) {
    logger.error('Get emergency stats error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

module.exports = router;
