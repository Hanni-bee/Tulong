const express = require('express');
const Message = require('../models/Message');
const User = require('../models/User');
const logger = require('../utils/logger');

const router = express.Router();

// Send message
router.post('/send', async (req, res) => {
  try {
    const { chatId, message, senderId, senderName, imageUrl, messageType = 'text' } = req.body;
    const userId = req.user.userId;

    // Verify sender
    if (senderId !== userId) {
      return res.status(403).json({
        success: false,
        message: 'Unauthorized to send message as this user'
      });
    }

    // Create message
    const newMessage = new Message({
      chatId,
      message,
      senderId,
      senderName,
      imageUrl,
      messageType,
      timestamp: new Date(),
      isRead: false
    });

    await newMessage.save();

    // Emit to WebSocket clients
    req.app.get('io').to(chatId).emit('newMessage', {
      id: newMessage._id,
      chatId: newMessage.chatId,
      message: newMessage.message,
      senderId: newMessage.senderId,
      senderName: newMessage.senderName,
      imageUrl: newMessage.imageUrl,
      messageType: newMessage.messageType,
      timestamp: newMessage.timestamp,
      isRead: newMessage.isRead
    });

    logger.info(`Message sent in chat ${chatId} by ${senderName}`);

    res.status(201).json({
      success: true,
      message: 'Message sent successfully',
      data: {
        id: newMessage._id,
        chatId: newMessage.chatId,
        message: newMessage.message,
        senderId: newMessage.senderId,
        senderName: newMessage.senderName,
        imageUrl: newMessage.imageUrl,
        messageType: newMessage.messageType,
        timestamp: newMessage.timestamp,
        isRead: newMessage.isRead
      }
    });

  } catch (error) {
    logger.error('Send message error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Get messages for a chat
router.get('/chat/:chatId', async (req, res) => {
  try {
    const { chatId } = req.params;
    const { page = 1, limit = 50 } = req.query;
    const userId = req.user.userId;

    // Check if user has access to this chat
    // For now, we'll allow access to all chats
    // In production, implement proper chat access control

    const skip = (page - 1) * limit;
    
    const messages = await Message.find({ chatId })
      .sort({ timestamp: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .lean();

    // Mark messages as read for this user
    await Message.updateMany(
      { 
        chatId, 
        senderId: { $ne: userId },
        isRead: false 
      },
      { isRead: true }
    );

    logger.info(`Retrieved ${messages.length} messages for chat ${chatId}`);

    res.json({
      success: true,
      data: {
        messages: messages.reverse(), // Return in chronological order
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total: await Message.countDocuments({ chatId })
        }
      }
    });

  } catch (error) {
    logger.error('Get messages error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Get user's chats
router.get('/chats', async (req, res) => {
  try {
    const userId = req.user.userId;

    // Get all unique chat IDs where user has sent or received messages
    const userChats = await Message.aggregate([
      {
        $match: {
          $or: [
            { senderId: userId },
            { chatId: { $regex: `.*${userId}.*` } } // For direct messages
          ]
        }
      },
      {
        $group: {
          _id: '$chatId',
          lastMessage: { $last: '$message' },
          lastSender: { $last: '$senderName' },
          lastTimestamp: { $last: '$timestamp' },
          unreadCount: {
            $sum: {
              $cond: [
                { $and: [{ $ne: ['$senderId', userId] }, { $eq: ['$isRead', false] }] },
                1,
                0
              ]
            }
          }
        }
      },
      {
        $sort: { lastTimestamp: -1 }
      }
    ]);

    logger.info(`Retrieved ${userChats.length} chats for user ${userId}`);

    res.json({
      success: true,
      data: {
        chats: userChats
      }
    });

  } catch (error) {
    logger.error('Get chats error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Mark messages as read
router.put('/read/:chatId', async (req, res) => {
  try {
    const { chatId } = req.params;
    const userId = req.user.userId;

    await Message.updateMany(
      { 
        chatId, 
        senderId: { $ne: userId },
        isRead: false 
      },
      { isRead: true }
    );

    logger.info(`Marked messages as read in chat ${chatId} for user ${userId}`);

    res.json({
      success: true,
      message: 'Messages marked as read'
    });

  } catch (error) {
    logger.error('Mark messages as read error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Delete message
router.delete('/:messageId', async (req, res) => {
  try {
    const { messageId } = req.params;
    const userId = req.user.userId;

    const message = await Message.findById(messageId);
    if (!message) {
      return res.status(404).json({
        success: false,
        message: 'Message not found'
      });
    }

    // Check if user is the sender
    if (message.senderId !== userId) {
      return res.status(403).json({
        success: false,
        message: 'Unauthorized to delete this message'
      });
    }

    await Message.findByIdAndDelete(messageId);

    // Emit deletion to WebSocket clients
    req.app.get('io').to(message.chatId).emit('messageDeleted', {
      messageId,
      chatId: message.chatId
    });

    logger.info(`Message ${messageId} deleted by user ${userId}`);

    res.json({
      success: true,
      message: 'Message deleted successfully'
    });

  } catch (error) {
    logger.error('Delete message error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

// Search messages
router.get('/search', async (req, res) => {
  try {
    const { query, chatId, page = 1, limit = 20 } = req.query;
    const userId = req.user.userId;

    if (!query) {
      return res.status(400).json({
        success: false,
        message: 'Search query is required'
      });
    }

    const skip = (page - 1) * limit;
    
    const searchFilter = {
      message: { $regex: query, $options: 'i' },
      ...(chatId && { chatId })
    };

    const messages = await Message.find(searchFilter)
      .sort({ timestamp: -1 })
      .skip(skip)
      .limit(parseInt(limit))
      .lean();

    logger.info(`Search results for "${query}": ${messages.length} messages`);

    res.json({
      success: true,
      data: {
        messages,
        pagination: {
          page: parseInt(page),
          limit: parseInt(limit),
          total: await Message.countDocuments(searchFilter)
        }
      }
    });

  } catch (error) {
    logger.error('Search messages error:', error);
    res.status(500).json({
      success: false,
      message: 'Internal server error'
    });
  }
});

module.exports = router;
