# T.U.L.O.N.G Backend API Server

A comprehensive backend API server for the T.U.L.O.N.G disaster communication system.

## 🚀 Features

### Core Functionality
- **User Authentication & Authorization** - JWT-based auth with role management
- **Real-time Messaging** - WebSocket support for instant communication
- **Emergency Alerts** - Critical alert broadcasting system
- **File Upload & Storage** - Cloudinary integration for media handling
- **Push Notifications** - Firebase Cloud Messaging integration
- **Location Services** - Geographic data management
- **Analytics & Reporting** - Usage statistics and insights

### Technical Features
- **RESTful API** - Clean, documented endpoints
- **WebSocket Support** - Real-time bidirectional communication
- **Database Integration** - MongoDB with Mongoose ODM
- **Security** - Helmet, CORS, rate limiting, input validation
- **Logging** - Winston-based structured logging
- **Error Handling** - Comprehensive error management
- **Testing** - Jest test suite included

## 📋 Prerequisites

- Node.js (v16 or higher)
- MongoDB (v4.4 or higher)
- Redis (optional, for caching)
- Firebase project (for push notifications)
- Cloudinary account (for file storage)

## 🛠️ Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd backend
   ```

2. **Install dependencies**
   ```bash
   npm install
   ```

3. **Environment setup**
   ```bash
   cp env.example .env
   # Edit .env with your configuration
   ```

4. **Start the server**
   ```bash
   # Development
   npm run dev
   
   # Production
   npm start
   ```

## 🔧 Configuration

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `NODE_ENV` | Environment (development/production) | Yes |
| `PORT` | Server port | Yes |
| `MONGODB_URI` | MongoDB connection string | Yes |
| `JWT_SECRET` | JWT signing secret | Yes |
| `FIREBASE_PROJECT_ID` | Firebase project ID | Yes |
| `SMTP_HOST` | Email server host | Yes |
| `CLOUDINARY_CLOUD_NAME` | Cloudinary cloud name | Yes |

### Database Setup

1. **MongoDB Collections**
   - `users` - User profiles and authentication
   - `messages` - Chat messages and communication
   - `emergencyalerts` - Emergency alerts and notifications
   - `locations` - Geographic data and regions

2. **Indexes**
   - Automatic indexes created for performance
   - Custom indexes for search and filtering

## 📚 API Documentation

### Authentication Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Register new user |
| POST | `/api/auth/login` | User login |
| POST | `/api/auth/logout` | User logout |
| GET | `/api/auth/verify` | Verify JWT token |

### Message Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/messages/send` | Send message |
| GET | `/api/messages/chat/:chatId` | Get chat messages |
| GET | `/api/messages/chats` | Get user's chats |
| PUT | `/api/messages/read/:chatId` | Mark messages as read |
| DELETE | `/api/messages/:messageId` | Delete message |
| GET | `/api/messages/search` | Search messages |

### Emergency Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/emergency/alert` | Send emergency alert |
| GET | `/api/emergency/alerts` | Get emergency alerts |
| GET | `/api/emergency/alert/:alertId` | Get specific alert |
| PUT | `/api/emergency/alert/:alertId/status` | Update alert status |
| GET | `/api/emergency/my-alerts` | Get user's alerts |
| GET | `/api/emergency/stats` | Get emergency statistics |

### User Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/users/profile` | Get user profile |
| PUT | `/api/users/profile` | Update user profile |
| GET | `/api/users/online` | Get online users |
| GET | `/api/users/search` | Search users |
| PUT | `/api/users/status` | Update user status |

## 🔌 WebSocket Events

### Client to Server

| Event | Data | Description |
|-------|------|-------------|
| `authenticate` | `{userId, userInfo}` | Authenticate user |
| `joinChat` | `{chatId}` | Join chat room |
| `leaveChat` | `{chatId}` | Leave chat room |
| `typing` | `{chatId, userId, isTyping}` | Typing indicator |
| `messageRead` | `{messageId, chatId, userId}` | Message read receipt |
| `shareLocation` | `{chatId, userId, location}` | Share location |
| `acknowledgeAlert` | `{alertId, userId, userName}` | Acknowledge alert |
| `updateStatus` | `{userId, status, location}` | Update user status |

### Server to Client

| Event | Data | Description |
|-------|------|-------------|
| `newMessage` | Message object | New message received |
| `messageDeleted` | `{messageId, chatId}` | Message deleted |
| `userTyping` | `{userId, isTyping}` | User typing indicator |
| `messageReadReceipt` | `{messageId, userId, readAt}` | Message read receipt |
| `locationShared` | `{userId, location}` | Location shared |
| `emergencyAlert` | Alert object | Emergency alert broadcast |
| `alertAcknowledged` | `{alertId, userId, userName}` | Alert acknowledged |
| `userOnline` | `{userId, userInfo}` | User came online |
| `userOffline` | `{userId}` | User went offline |
| `userStatusUpdate` | `{userId, status, location}` | User status updated |

## 🧪 Testing

```bash
# Run all tests
npm test

# Run tests with coverage
npm run test:coverage

# Run specific test file
npm test -- --testNamePattern="auth"
```

## 📊 Monitoring

### Health Check
```bash
curl http://localhost:5000/health
```

### Logs
- Application logs: `logs/app.log`
- Error logs: `logs/error.log`
- Access logs: `logs/access.log`

## 🔒 Security

### Implemented Security Measures
- **Helmet** - Security headers
- **CORS** - Cross-origin resource sharing
- **Rate Limiting** - Request rate limiting
- **Input Validation** - Request validation
- **JWT Authentication** - Secure token-based auth
- **Password Hashing** - bcrypt password hashing
- **SQL Injection Prevention** - Parameterized queries

### Security Best Practices
- Environment variables for sensitive data
- Regular security updates
- Input sanitization
- Rate limiting per IP
- JWT token expiration
- Secure password requirements

## 🚀 Deployment

### Docker Deployment
```bash
# Build image
docker build -t tulong-backend .

# Run container
docker run -p 5000:5000 tulong-backend
```

### Production Checklist
- [ ] Environment variables configured
- [ ] Database connection secured
- [ ] SSL certificates installed
- [ ] Firewall configured
- [ ] Monitoring setup
- [ ] Backup strategy implemented
- [ ] Log rotation configured

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For support and questions:
- Create an issue in the repository
- Contact the development team
- Check the documentation

## 🔄 Version History

- **v1.0.0** - Initial release with core functionality
- **v1.1.0** - Added WebSocket support
- **v1.2.0** - Added emergency alert system
- **v1.3.0** - Added file upload and media support
- **v1.4.0** - Added analytics and reporting
