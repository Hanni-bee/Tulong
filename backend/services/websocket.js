const logger = require('../utils/logger');

class WebSocketService {
  constructor() {
    this.io = null;
    this.connectedUsers = new Map();
  }

  initialize(io) {
    this.io = io;
    this.setupEventHandlers();
    logger.info('WebSocket service initialized');
  }

  setupEventHandlers() {
    this.io.on('connection', (socket) => {
      logger.info(`Client connected: ${socket.id}`);

      // Handle user authentication
      socket.on('authenticate', (data) => {
        const { userId, userInfo } = data;
        this.connectedUsers.set(socket.id, {
          userId,
          userInfo,
          socketId: socket.id,
          connectedAt: new Date()
        });
        
        // Join user to their personal room
        socket.join(`user_${userId}`);
        
        // Join user to general rooms
        socket.join('general');
        socket.join('emergency_alerts');
        
        logger.info(`User ${userId} authenticated and joined rooms`);
        
        // Notify other users that this user is online
        socket.broadcast.emit('userOnline', {
          userId,
          userInfo,
          timestamp: new Date()
        });
      });

      // Handle joining chat rooms
      socket.on('joinChat', (data) => {
        const { chatId } = data;
        socket.join(`chat_${chatId}`);
        logger.info(`User joined chat: ${chatId}`);
      });

      // Handle leaving chat rooms
      socket.on('leaveChat', (data) => {
        const { chatId } = data;
        socket.leave(`chat_${chatId}`);
        logger.info(`User left chat: ${chatId}`);
      });

      // Handle typing indicators
      socket.on('typing', (data) => {
        const { chatId, userId, isTyping } = data;
        socket.to(`chat_${chatId}`).emit('userTyping', {
          userId,
          isTyping,
          timestamp: new Date()
        });
      });

      // Handle message read receipts
      socket.on('messageRead', (data) => {
        const { messageId, chatId, userId } = data;
        socket.to(`chat_${chatId}`).emit('messageReadReceipt', {
          messageId,
          userId,
          readAt: new Date()
        });
      });

      // Handle location sharing
      socket.on('shareLocation', (data) => {
        const { chatId, userId, location } = data;
        socket.to(`chat_${chatId}`).emit('locationShared', {
          userId,
          location,
          timestamp: new Date()
        });
      });

      // Handle emergency alert acknowledgment
      socket.on('acknowledgeAlert', (data) => {
        const { alertId, userId, userName } = data;
        this.io.emit('alertAcknowledged', {
          alertId,
          userId,
          userName,
          acknowledgedAt: new Date()
        });
      });

      // Handle user status updates
      socket.on('updateStatus', (data) => {
        const { userId, status, location } = data;
        const userInfo = this.connectedUsers.get(socket.id);
        if (userInfo) {
          userInfo.status = status;
          userInfo.location = location;
          userInfo.lastUpdate = new Date();
        }
        
        this.io.emit('userStatusUpdate', {
          userId,
          status,
          location,
          timestamp: new Date()
        });
      });

      // Handle disconnect
      socket.on('disconnect', () => {
        const userInfo = this.connectedUsers.get(socket.id);
        if (userInfo) {
          const { userId } = userInfo;
          
          // Notify other users that this user is offline
          this.io.emit('userOffline', {
            userId,
            timestamp: new Date()
          });
          
          this.connectedUsers.delete(socket.id);
          logger.info(`User ${userId} disconnected`);
        }
      });

      // Handle ping/pong for connection health
      socket.on('ping', () => {
        socket.emit('pong', { timestamp: new Date() });
      });
    });
  }

  // Send message to specific chat
  sendToChat(chatId, event, data) {
    this.io.to(`chat_${chatId}`).emit(event, data);
  }

  // Send message to specific user
  sendToUser(userId, event, data) {
    this.io.to(`user_${userId}`).emit(event, data);
  }

  // Send emergency alert to all users
  broadcastEmergencyAlert(alertData) {
    this.io.emit('emergencyAlert', alertData);
  }

  // Send message to all connected users
  broadcastToAll(event, data) {
    this.io.emit(event, data);
  }

  // Get connected users count
  getConnectedUsersCount() {
    return this.connectedUsers.size;
  }

  // Get connected users list
  getConnectedUsers() {
    return Array.from(this.connectedUsers.values());
  }

  // Check if user is connected
  isUserConnected(userId) {
    return Array.from(this.connectedUsers.values()).some(user => user.userId === userId);
  }

  // Get user's socket ID
  getUserSocketId(userId) {
    const user = Array.from(this.connectedUsers.values()).find(user => user.userId === userId);
    return user ? user.socketId : null;
  }

  // Send notification to user
  sendNotification(userId, notification) {
    this.sendToUser(userId, 'notification', notification);
  }

  // Send system message
  sendSystemMessage(chatId, message) {
    this.sendToChat(chatId, 'systemMessage', {
      message,
      timestamp: new Date(),
      type: 'system'
    });
  }

  // Handle chat room management
  createChatRoom(chatId, participants) {
    participants.forEach(userId => {
      const socketId = this.getUserSocketId(userId);
      if (socketId) {
        this.io.sockets.sockets.get(socketId)?.join(`chat_${chatId}`);
      }
    });
  }

  // Handle chat room cleanup
  deleteChatRoom(chatId) {
    this.io.to(`chat_${chatId}`).emit('chatDeleted', { chatId });
  }

  // Get room participants
  getRoomParticipants(chatId) {
    const room = this.io.sockets.adapter.rooms.get(`chat_${chatId}`);
    if (!room) return [];
    
    return Array.from(room).map(socketId => {
      const userInfo = this.connectedUsers.get(socketId);
      return userInfo ? userInfo.userId : null;
    }).filter(Boolean);
  }
}

module.exports = new WebSocketService();
