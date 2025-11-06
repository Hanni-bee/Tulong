const logger = require('../utils/logger');

module.exports = (err, req, res, next) => {
  logger.error(`Unhandled error on ${req.method} ${req.originalUrl}: ${err.stack || err.message}`);

  const status = err.status || err.statusCode || 500;
  const response = {
    success: false,
    message: err.message || 'Internal server error'
  };

  if (process.env.NODE_ENV !== 'production' && err.stack) {
    response.stack = err.stack;
  }

  res.status(status).json(response);
};



