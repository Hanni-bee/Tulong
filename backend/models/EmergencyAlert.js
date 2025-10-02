const mongoose = require('mongoose');

const emergencyAlertSchema = new mongoose.Schema({
  message: {
    type: String,
    required: true,
    trim: true
  },
  location: {
    type: String,
    required: true,
    trim: true
  },
  alertType: {
    type: String,
    enum: ['general', 'fire', 'flood', 'earthquake', 'medical', 'security', 'weather', 'other'],
    default: 'general'
  },
  priority: {
    type: String,
    enum: ['low', 'medium', 'high', 'critical'],
    default: 'medium'
  },
  userId: {
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
  timestamp: {
    type: Date,
    default: Date.now,
    index: true
  },
  status: {
    type: String,
    enum: ['active', 'acknowledged', 'in_progress', 'resolved', 'cancelled'],
    default: 'active',
    index: true
  },
  isResolved: {
    type: Boolean,
    default: false,
    index: true
  },
  resolvedAt: {
    type: Date,
    default: null
  },
  resolvedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
  },
  resolution: {
    type: String,
    default: null
  },
  coordinates: {
    latitude: {
      type: Number,
      default: null
    },
    longitude: {
      type: Number,
      default: null
    }
  },
  affectedArea: {
    type: String,
    default: null
  },
  estimatedImpact: {
    type: String,
    enum: ['minimal', 'moderate', 'severe', 'critical'],
    default: null
  },
  responseTeam: [{
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User'
    },
    name: String,
    role: String,
    assignedAt: {
      type: Date,
      default: Date.now
    }
  }],
  acknowledgments: [{
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User'
    },
    name: String,
    acknowledgedAt: {
      type: Date,
      default: Date.now
    }
  }],
  updates: [{
    message: String,
    updatedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User'
    },
    updatedByName: String,
    timestamp: {
      type: Date,
      default: Date.now
    }
  }],
  media: [{
    url: String,
    type: {
      type: String,
      enum: ['image', 'video', 'audio', 'document']
    },
    uploadedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User'
    },
    uploadedAt: {
      type: Date,
      default: Date.now
    }
  }],
  tags: [{
    type: String,
    trim: true
  }],
  metadata: {
    type: Map,
    of: mongoose.Schema.Types.Mixed,
    default: {}
  }
}, {
  timestamps: true
});

// Indexes for better performance
emergencyAlertSchema.index({ status: 1, timestamp: -1 });
emergencyAlertSchema.index({ priority: 1, timestamp: -1 });
emergencyAlertSchema.index({ alertType: 1 });
emergencyAlertSchema.index({ isResolved: 1 });
emergencyAlertSchema.index({ userId: 1, timestamp: -1 });
emergencyAlertSchema.index({ 'coordinates.latitude': 1, 'coordinates.longitude': 1 });

// Virtual for formatted timestamp
emergencyAlertSchema.virtual('formattedTimestamp').get(function() {
  return this.timestamp.toISOString();
});

// Virtual for duration since creation
emergencyAlertSchema.virtual('duration').get(function() {
  return Date.now() - this.timestamp.getTime();
});

// Method to acknowledge alert
emergencyAlertSchema.methods.acknowledge = function(userId, userName) {
  const existingAck = this.acknowledgments.find(ack => ack.userId.toString() === userId.toString());
  
  if (!existingAck) {
    this.acknowledgments.push({
      userId,
      name: userName,
      acknowledgedAt: new Date()
    });
    
    if (this.status === 'active') {
      this.status = 'acknowledged';
    }
    
    return this.save();
  }
  
  return Promise.resolve(this);
};

// Method to assign response team member
emergencyAlertSchema.methods.assignTeamMember = function(userId, name, role) {
  const existingMember = this.responseTeam.find(member => member.userId.toString() === userId.toString());
  
  if (!existingMember) {
    this.responseTeam.push({
      userId,
      name,
      role,
      assignedAt: new Date()
    });
    
    if (this.status === 'acknowledged') {
      this.status = 'in_progress';
    }
    
    return this.save();
  }
  
  return Promise.resolve(this);
};

// Method to add update
emergencyAlertSchema.methods.addUpdate = function(message, updatedBy, updatedByName) {
  this.updates.push({
    message,
    updatedBy,
    updatedByName,
    timestamp: new Date()
  });
  
  return this.save();
};

// Method to resolve alert
emergencyAlertSchema.methods.resolve = function(resolvedBy, resolution) {
  this.status = 'resolved';
  this.isResolved = true;
  this.resolvedAt = new Date();
  this.resolvedBy = resolvedBy;
  this.resolution = resolution;
  
  return this.save();
};

// Method to add media
emergencyAlertSchema.methods.addMedia = function(url, type, uploadedBy) {
  this.media.push({
    url,
    type,
    uploadedBy,
    uploadedAt: new Date()
  });
  
  return this.save();
};

// Static method to get active alerts
emergencyAlertSchema.statics.getActiveAlerts = function() {
  return this.find({
    status: { $in: ['active', 'acknowledged', 'in_progress'] },
    isResolved: false
  }).sort({ priority: -1, timestamp: -1 });
};

// Static method to get alerts by location
emergencyAlertSchema.statics.getAlertsByLocation = function(latitude, longitude, radius = 10) {
  return this.find({
    'coordinates.latitude': {
      $gte: latitude - (radius / 111), // Rough conversion: 1 degree ≈ 111 km
      $lte: latitude + (radius / 111)
    },
    'coordinates.longitude': {
      $gte: longitude - (radius / 111),
      $lte: longitude + (radius / 111)
    },
    isResolved: false
  }).sort({ timestamp: -1 });
};

// Static method to get alert statistics
emergencyAlertSchema.statics.getStatistics = function() {
  return this.aggregate([
    {
      $group: {
        _id: null,
        totalAlerts: { $sum: 1 },
        activeAlerts: {
          $sum: { $cond: [{ $in: ['$status', ['active', 'acknowledged', 'in_progress']] }, 1, 0] }
        },
        resolvedAlerts: {
          $sum: { $cond: [{ $eq: ['$isResolved', true] }, 1, 0] }
        },
        highPriorityAlerts: {
          $sum: { $cond: [{ $eq: ['$priority', 'high'] }, 1, 0] }
        },
        criticalPriorityAlerts: {
          $sum: { $cond: [{ $eq: ['$priority', 'critical'] }, 1, 0] }
        }
      }
    }
  ]);
};

// Pre-save middleware
emergencyAlertSchema.pre('save', function(next) {
  if (this.isNew) {
    this.timestamp = new Date();
  }
  next();
});

module.exports = mongoose.model('EmergencyAlert', emergencyAlertSchema);
