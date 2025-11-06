const mongoose = require('mongoose');
const logger = require('../utils/logger');

class DatabaseService {
  async connect() {
    const uri = process.env.MONGODB_URI;
    if (!uri) {
      logger.warn('MONGODB_URI not set. Skipping MongoDB connection.');
      return;
    }

    try {
      await mongoose.connect(uri, {
        serverSelectionTimeoutMS: 10000
      });
      logger.info('MongoDB connected');
    } catch (err) {
      logger.error('MongoDB connection error:', err);
      throw err;
    }
  }

  async disconnect() {
    try {
      await mongoose.disconnect();
      logger.info('MongoDB disconnected');
    } catch (err) {
      logger.error('MongoDB disconnection error:', err);
    }
  }
}

module.exports = new DatabaseService();







