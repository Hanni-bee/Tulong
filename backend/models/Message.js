const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema({
  chatId: {
    type: String,
    required: true,
    index: true
  },
  message: {
    type: String,
    required: true,
    trim: true
  },
  senderId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true
  },
  senderName: {
    type: String,
    required: true,
    trim: true
  },
  imageUrl: {
    type: String,
    default: null
  },
  messageType: {
    type: String,
    enum: ['text', 'image', 'file', 'location', 'emergency'],
    default: 'text'
  },
  timestamp: {
    type: Date,
    default: Date.now,
    index: true
  },
  isRead: {
    type: Boolean,
    default: false
  },
  readBy: [{
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User'
    },
    readAt: {
      type: Date,
      default: Date.now
    }
  }],
  editedAt: {
    type: Date,
    default: null
  },
  isEdited: {
    type: Boolean,
    default: false
  },
  isDeleted: {
    type: Boolean,
    default: false
  },
  deletedAt: {
    type: Date,
    default: null
  },
  replyTo: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Message',
    default: null
  },
  metadata: {
    type: Map,
    of: mongoose.Schema.Types.Mixed,
    default: {}
  }
}, {
  timestamps: true
});

// Indexes for better performance
messageSchema.index({ chatId: 1, timestamp: -1 });
messageSchema.index({ senderId: 1, timestamp: -1 });
messageSchema.index({ isRead: 1 });
messageSchema.index({ messageType: 1 });
messageSchema.index({ isDeleted: 1 });

// Virtual for formatted timestamp
messageSchema.virtual('formattedTimestamp').get(function() {
  return this.timestamp.toISOString();
});

// Method to mark as read by user
messageSchema.methods.markAsRead = function(userId) {
  const existingRead = this.readBy.find(read => read.userId.toString() === userId.toString());
  
  if (!existingRead) {
    this.readBy.push({
      userId,
      readAt: new Date()
    });
    this.isRead = this.readBy.length > 0;
    return this.save();
  }
  
  return Promise.resolve(this);
};

// Method to mark as unread
messageSchema.methods.markAsUnread = function(userId) {
  this.readBy = this.readBy.filter(read => read.userId.toString() !== userId.toString());
  this.isRead = this.readBy.length > 0;
  return this.save();
};

// Method to soft delete
messageSchema.methods.softDelete = function() {
  this.isDeleted = true;
  this.deletedAt = new Date();
  return this.save();
};

// Method to edit message
messageSchema.methods.editMessage = function(newMessage) {
  this.message = newMessage;
  this.isEdited = true;
  this.editedAt = new Date();
  return this.save();
};

// Static method to get unread count for user
messageSchema.statics.getUnreadCount = function(chatId, userId) {
  return this.countDocuments({
    chatId,
    senderId: { $ne: userId },
    isRead: false,
    isDeleted: false
  });
};

// Static method to get messages for chat with pagination
messageSchema.statics.getChatMessages = function(chatId, page = 1, limit = 50) {
  const skip = (page - 1) * limit;
  
  return this.find({
    chatId,
    isDeleted: false
  })
  .sort({ timestamp: -1 })
  .populate('senderId', 'firstName lastName')
  .skip(skip)
  .limit(parseInt(limit));
};

// Static method to search messages
messageSchema.statics.searchMessages = function(query, chatId = null, userId = null) {
  const searchFilter = {
    message: { $regex: query, $options: 'i' },
    isDeleted: false
  };
  
  if (chatId) {
    searchFilter.chatId = chatId;
  }
  
  if (userId) {
    searchFilter.senderId = userId;
  }
  
  return this.find(searchFilter)
    .sort({ timestamp: -1 })
    .populate('senderId', 'firstName lastName')
    .limit(100);
};

// Pre-save middleware to update timestamp
messageSchema.pre('save', function(next) {
  if (this.isNew) {
    this.timestamp = new Date();
  }
  next();
});

module.exports = mongoose.model('Message', messageSchema);
