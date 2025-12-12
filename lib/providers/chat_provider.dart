import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/bluetooth_service.dart';
import '../services/voice_chat_extension.dart' as voice;
// import '../services/sqlite_service.dart'; // Reserved for future cached message loading
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/enhanced_error_handler.dart';
import '../services/notification_service.dart';

class ChatProvider with ChangeNotifier {
  final BluetoothService _bluetoothService = BluetoothService();
  final voice.VoiceChatExtension _voiceExtension = voice.VoiceChatExtension();
  
  List<BluetoothDevice> _pairedDevices = [];
  BluetoothDevice? _selectedDevice;
  bool _isConnected = false;
  final List<ChatMessage> _messages = [];
  final List<String> _debugLogs = [];
  bool _isConnecting = false;
  
  // Loading states
  bool _isLoadingMessages = false;
  bool _isRefreshingMessages = false;
  bool _hasCachedMessages = false;
  final bool _isTyping = false;
  
  // Connected users on the channel (extracted from messages)
  final Set<String> _connectedUsers = {};
  String? _currentUserName;

  List<BluetoothDevice> get pairedDevices => _pairedDevices;
  BluetoothDevice? get selectedDevice => _selectedDevice;
  bool get isConnected => _isConnected;
  List<ChatMessage> get messages => _messages;
  List<String> get debugLogs => _debugLogs;
  bool get isConnecting => _isConnecting;
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isRefreshingMessages => _isRefreshingMessages;
  bool get hasCachedMessages => _hasCachedMessages;
  bool get isTyping => _isTyping;
  String? get currentUserName => _currentUserName;
  
  // Get connected users including current user
  List<String> get connectedUsers {
    final allUsers = <String>{..._connectedUsers};
    if (_currentUserName != null && _currentUserName!.isNotEmpty) {
      allUsers.add(_currentUserName!);
    }
    return allUsers.toList()..sort();
  }
  
  // Count includes current user
  int get connectedUsersCount {
    int count = _connectedUsers.length;
    if (_currentUserName != null && _currentUserName!.isNotEmpty) {
      count += 1;
    }
    return count;
  }
  
  // Check if a user is the current user
  bool isCurrentUser(String user) {
    return _currentUserName != null && user == _currentUserName;
  }
  
  // Voice extension getters
  voice.VoiceChatExtension get voiceExtension => _voiceExtension;
  bool get isRecording => _voiceExtension.isRecording;
  bool get isPlaying => _voiceExtension.isPlaying;

  StreamSubscription<String>? _messageSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<String>? _debugSubscription;

  ChatProvider() {
    _init();
  }

  void _init() {
    _messageSubscription = _bluetoothService.messageStream.listen((message) {
      _processIncomingMessage(message);
    });

    _connectionSubscription = _bluetoothService.connectionStream.listen((connected) {
      _isConnected = connected;
      notifyListeners();
    });

    _debugSubscription = _bluetoothService.debugStream.listen((log) {
      _debugLogs.add('${DateTime.now().toString().substring(11, 19)}: $log');
      if (_debugLogs.length > 100) {
        _debugLogs.removeAt(0);
      }
      notifyListeners();
    });

    // Listen to voice extension debug stream
    _voiceExtension.debugStream.listen((log) {
      _debugLogs.add('${DateTime.now().toString().substring(11, 19)}: [VOICE] $log');
      if (_debugLogs.length > 100) {
        _debugLogs.removeAt(0);
      }
      notifyListeners();
    });
  }

  Future<void> loadPairedDevices() async {
    _pairedDevices = await _bluetoothService.getPairedDevices();
    notifyListeners();
  }

  Future<bool> connectToDevice(BluetoothDevice device, {BuildContext? context}) async {
    _isConnecting = true;
    notifyListeners();
    try {
      bool success = await _bluetoothService.connectToDevice(device);
      if (success) {
        _selectedDevice = device;
        _isConnected = true;
        // Get current user name from database/storage
        await _updateCurrentUserNameFromDatabase();
      } else if (context != null) {
        // Show error if connection failed
        final error = AppError(
          category: ErrorCategory.bluetooth,
          severity: ErrorSeverity.medium,
          userMessage: 'Failed to connect to device. Please try again.',
          canRetry: true,
        );
        EnhancedErrorHandler.showError(
          context,
          error,
          onRetry: () => connectToDevice(device, context: context),
        );
      }
      return success;
    } catch (e) {
      if (context != null) {
        final error = AppError.fromException(
          e,
          category: ErrorCategory.bluetooth,
        );
        EnhancedErrorHandler.showError(
          context,
          error,
          onRetry: () => connectToDevice(device, context: context),
        );
      }
      return false;
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }
  
  /// Update current user name from database/storage (signup information)
  Future<void> _updateCurrentUserNameFromDatabase() async {
    try {
      // Try to get from SQLite database first (where signup info is stored)
      // For now, the UI will call setCurrentUserName() with the correct name
      // from the database, so this method is mainly for future use
    } catch (e) {
      // Ignore if database not available
      print('Error updating user name from database: $e');
    }
  }
  
  /// Set current user name (called from UI)
  void setCurrentUserName(String? userName) {
    _currentUserName = userName;
    notifyListeners();
  }
  
  /// Load messages with progressive loading (show cached first, then refresh)
  Future<void> loadMessages({bool forceRefresh = false}) async {
    // Check network state for smart loading
    final connectivity = Connectivity();
    final connectivityResults = await connectivity.checkConnectivity();
    final isOnline = connectivityResults.any((result) => result != ConnectivityResult.none);
    
    // If not forcing refresh and we have cached messages, show them immediately
    if (!forceRefresh && _messages.isNotEmpty) {
      _hasCachedMessages = true;
      notifyListeners();
      // Refresh in background if online
      if (isOnline) {
        _refreshMessagesInBackground();
      }
      return;
    }
    
    // Initial load - show cached messages first if available
    if (!forceRefresh) {
      await _loadCachedMessages();
    }
    
    // Set loading state
    if (forceRefresh) {
      _isRefreshingMessages = true;
    } else {
      _isLoadingMessages = true;
    }
    notifyListeners();
    
    try {
      // If online, try to fetch new messages
      if (isOnline) {
        await _fetchMessagesFromNetwork();
      } else {
        // Offline mode - only use cached messages
        if (_messages.isEmpty) {
          await _loadCachedMessages();
        }
      }
    } catch (e) {
      print('Error loading messages: $e');
      // Fallback to cached messages on error
      if (_messages.isEmpty) {
        await _loadCachedMessages();
      }
    } finally {
      _isLoadingMessages = false;
      _isRefreshingMessages = false;
      notifyListeners();
    }
  }
  
  /// Load cached messages from SQLite
  Future<void> _loadCachedMessages() async {
    try {
      // Load messages from local database
      // For now, we'll use the existing messages list
      // In a full implementation, you'd load from SQLite here
      // Example: final cached = await SQLiteService().getMessagesByChatId('local_chat');
      _hasCachedMessages = _messages.isNotEmpty;
      notifyListeners();
    } catch (e) {
      print('Error loading cached messages: $e');
    }
  }
  
  /// Fetch messages from network (Bluetooth/ESP32)
  Future<void> _fetchMessagesFromNetwork() async {
    // In a real implementation, this would fetch from network
    // For now, messages come through the Bluetooth stream
    // This method is a placeholder for future network sync
    await Future.delayed(const Duration(milliseconds: 500));
  }
  
  /// Refresh messages in background (progressive loading)
  Future<void> _refreshMessagesInBackground() async {
    try {
      final connectivity = Connectivity();
      final connectivityResults = await connectivity.checkConnectivity();
      final isOnline = connectivityResults.any((result) => result != ConnectivityResult.none);
      
      if (isOnline) {
        _isRefreshingMessages = true;
        notifyListeners();
        
        await _fetchMessagesFromNetwork();
        
        _isRefreshingMessages = false;
        notifyListeners();
      }
    } catch (e) {
      print('Error refreshing messages: $e');
      _isRefreshingMessages = false;
      notifyListeners();
    }
  }
  
  /// Smart refresh - only refresh if online and not already refreshing
  Future<void> smartRefresh() async {
    if (_isRefreshingMessages) return;
    
    final connectivity = Connectivity();
    final connectivityResults = await connectivity.checkConnectivity();
    final isOnline = connectivityResults.any((result) => result != ConnectivityResult.none);
    
    if (isOnline) {
      await loadMessages(forceRefresh: true);
    } else {
      // Offline - just reload cached messages
      await _loadCachedMessages();
    }
  }

  Future<void> disconnect() async {
    await _bluetoothService.disconnect();
    _selectedDevice = null;
    _isConnected = false;
    _connectedUsers.clear(); // Clear connected users on disconnect
    notifyListeners();
  }

  Future<bool> sendMessage(String text, {BuildContext? context}) async {
    if (text.trim().isEmpty) return false;

    ChatMessage message = ChatMessage(
      text: text.trim(),
      isMe: true,
      timestamp: DateTime.now(),
      status: voice.MessageStatus.sending,
      type: voice.MessageType.text,
    );

    _addMessage(message.text, true, message: message);
    
    try {
      bool success = await _bluetoothService.sendMessage(text);
      
      if (success) {
        message.status = voice.MessageStatus.sent;
      } else {
        message.status = voice.MessageStatus.failed;
        if (context != null) {
          final error = AppError(
            category: ErrorCategory.bluetooth,
            severity: ErrorSeverity.medium,
            userMessage: 'Failed to send message. Please try again.',
            canRetry: true,
          );
          EnhancedErrorHandler.showError(
            context,
            error,
            onRetry: () => sendMessage(text, context: context),
          );
        }
      }
      
      notifyListeners();
      return success;
    } catch (e) {
      message.status = voice.MessageStatus.failed;
      notifyListeners();
      
      if (context != null) {
        final error = AppError.fromException(
          e,
          category: ErrorCategory.bluetooth,
        );
        EnhancedErrorHandler.showError(
          context,
          error,
          onRetry: () => sendMessage(text, context: context),
        );
      }
      return false;
    }
  }

  /// Process incoming message and handle voice messages
  void _processIncomingMessage(String data) {
    addStructuredDebug({
      'source': 'CHAT',
      'event': 'Processing incoming data',
      'metrics': {'dataLength': data.length}
    });
    
    final messages = _voiceExtension.processIncomingData(data);
    
    addStructuredDebug({
      'source': 'CHAT',
      'event': 'Processed messages',
      'metrics': {'messageCount': messages.length}
    });
    
    for (final message in messages) {
      if (message.startsWith('VOICE_MESSAGE:')) {
        // Extract the Base64 data from the voice message marker
        final base64Audio = message.substring(14); // Remove 'VOICE_MESSAGE:' prefix
        
        // Validate Base64 data
        if (base64Audio.isEmpty) {
          addStructuredDebug({
            'source': 'CHAT',
            'event': 'Voice message rejected - empty data',
            'metrics': {}
          });
          continue;
        }
        if (!_isValidBase64(base64Audio)) {
          addStructuredDebug({
            'source': 'CHAT',
            'event': 'Voice message rejected - invalid Base64',
            'metrics': {'length': base64Audio.length}
          });
          continue;
        }
        
        addStructuredDebug({
          'source': 'CHAT',
          'event': 'Creating voice message',
          'metrics': {'base64Length': base64Audio.length}
        });
        // Try to extract sender name from previous messages or connected users
        String? senderName;
        // For now, we'll extract from message context if available
        _addVoiceMessage(base64Audio, false, senderName: senderName);
      } else if (message.startsWith('<VOICE_START>') || message.startsWith('<VOICE_END>')) {
        // Voice markers, handled by voice extension
        continue;
      } else if (message.startsWith('From A:') || message.startsWith('From B:')) {
        // Extract sender info from ESP32 messages
        final parts = message.split(':');
        if (parts.length >= 2) {
          final sender = parts[0].replaceAll('From', '').trim();
          final messageText = parts.sublist(1).join(':').trim();
          _addConnectedUser(sender);
          _addMessage(messageText, false, senderName: sender);
        } else {
          _addMessage(message, false);
        }
      } else {
        // Regular text message - try to extract user info
        String? extractedSender = _extractUserFromMessage(message);
        _addMessage(message, false, senderName: extractedSender);
      }
    }
  }
  
  /// Extract and track user from message, returns sender name if found
  String? _extractUserFromMessage(String message) {
    // Try to parse JSON messages that might contain sender info
    try {
      final jsonData = json.decode(message);
      if (jsonData is Map) {
        final senderName = jsonData['sender_name'] as String?;
        final senderId = jsonData['sender_id'] as String?;
        if (senderName != null && senderName.isNotEmpty) {
          _addConnectedUser(senderName);
          return senderName;
        } else if (senderId != null && senderId.isNotEmpty) {
          _addConnectedUser(senderId);
          return senderId;
        }
      }
    } catch (e) {
      // Not JSON, ignore
    }
    return null;
  }
  
  /// Add connected user to the list
  void _addConnectedUser(String user) {
    if (user.isNotEmpty && user != 'Me' && user != 'ESP') {
      _connectedUsers.add(user);
      notifyListeners();
    }
  }
  
  /// Manually add a connected user (for testing or ESP32 sync)
  void addConnectedUser(String user) {
    _addConnectedUser(user);
  }
  
  /// Remove a connected user
  void removeConnectedUser(String user) {
    _connectedUsers.remove(user);
    notifyListeners();
  }
  
  /// Clear all connected users
  void clearConnectedUsers() {
    _connectedUsers.clear();
    notifyListeners();
  }

  /// Add voice message to chat
  void _addVoiceMessage(String base64Audio, bool isMe, {String? senderName}) {
    addStructuredDebug({
      'source': 'CHAT',
      'event': 'Adding voice message',
      'metrics': {'base64Length': base64Audio.length, 'isMe': isMe}
    });
    
    // Calculate duration for voice messages
    Duration? messageDuration;
    if (isMe) {
      // For sent messages, use recording duration
      messageDuration = _voiceExtension.getRecordingDuration();
    } else {
      // For received messages, estimate duration from file size (Base64 encoded AAC at 128kbps)
      try {
        final bytes = base64Decode(base64Audio);
        // Correct estimation: Base64 encoded AAC at 128kbps ≈ 21.3KB per second
        final estimatedSeconds = bytes.length / 21333.0;
        messageDuration = Duration(milliseconds: (estimatedSeconds * 1000).round());
      } catch (e) {
        messageDuration = null;
      }
    }
    
    final voiceMessage = voice.VoiceMessage.fromBase64(
      base64Audio: base64Audio,
      isMe: isMe,
      status: isMe ? voice.MessageStatus.sent : voice.MessageStatus.received,
      duration: messageDuration,
    );

    final chatMessage = ChatMessage(
      text: '🎤 Voice message',
      isMe: isMe,
      timestamp: DateTime.now(),
      status: isMe ? voice.MessageStatus.sent : voice.MessageStatus.received,
      type: voice.MessageType.voice,
      voiceMessage: voiceMessage,
      senderName: senderName,
    );

    _messages.add(chatMessage);
    addStructuredDebug({
      'source': 'CHAT',
      'event': 'Voice message added to chat',
      'metrics': {'totalMessages': _messages.length, 'voiceSize': voiceMessage.formattedSize}
    });
    notifyListeners();
  }

  /// Start recording voice message
  Future<bool> startRecording() async {
    return await _voiceExtension.startRecording();
  }

  /// Stop recording and send voice message with structured logging
  Future<bool> stopRecordingAndSend() async {
    final recordingPath = await _voiceExtension.stopRecording();
    if (recordingPath == null) {
      addStructuredDebug({
        'source': 'VOICE',
        'event': 'Recording failed or retrying',
        'metrics': {
          'isRetrying': _voiceExtension.isRetrying,
        }
      });
      return false;
    }

    addStructuredDebug({
      'source': 'VOICE',
      'event': 'Recording completed',
      'metrics': {
        'filePath': recordingPath,
      }
    });

    // Convert to Base64
    final base64Audio = await _voiceExtension.audioFileToBase64(recordingPath);
    if (base64Audio == null) {
      addStructuredDebug({
        'source': 'VOICE',
        'event': 'Base64 encoding failed',
        'metrics': {'filePath': recordingPath}
      });
      return false;
    }

    addStructuredDebug({
      'source': 'VOICE',
      'event': 'Base64 encoding completed',
      'metrics': {
        'base64Length': base64Audio.length,
        'estimatedSizeKB': (base64Audio.length * 3 / 4 / 1024).toStringAsFixed(1),
      }
    });

    // Calculate recording duration
    final recordingDuration = _voiceExtension.getRecordingDuration();
    
    // Create voice message
    final voiceMessage = voice.VoiceMessage.fromBase64(
      base64Audio: base64Audio,
      isMe: true,
      status: voice.MessageStatus.sending,
      duration: recordingDuration,
    );

    // Add to messages
    final chatMessage = ChatMessage(
      text: '🎤 Voice message',
      isMe: true,
      timestamp: DateTime.now(),
      status: voice.MessageStatus.sending,
      type: voice.MessageType.voice,
      voiceMessage: voiceMessage,
    );

    _messages.add(chatMessage);
    notifyListeners();

    // Send over Bluetooth
    final success = await _voiceExtension.sendVoiceMessage(
      base64Audio,
      (chunk) => _bluetoothService.sendMessage(chunk),
    );

    if (success) {
      chatMessage.status = voice.MessageStatus.sent;
      voiceMessage.status = voice.MessageStatus.sent;
      addStructuredDebug({
        'source': 'VOICE',
        'event': 'Voice message sent successfully',
        'metrics': {
          'base64Length': base64Audio.length,
          'chunkCount': (base64Audio.length / 28).ceil(),
        }
      });
    } else {
      chatMessage.status = voice.MessageStatus.failed;
      voiceMessage.status = voice.MessageStatus.failed;
      addStructuredDebug({
        'source': 'VOICE',
        'event': 'Voice message send failed',
        'metrics': {'base64Length': base64Audio.length}
      });
    }

    notifyListeners();
    return success;
  }

  /// Play voice message
  Future<bool> playVoiceMessage(voice.VoiceMessage voiceMessage) async {
    return await _voiceExtension.playVoiceMessage(voiceMessage.base64Audio);
  }

  /// Stop current playback
  Future<void> stopPlayback() async {
    await _voiceExtension.stopPlayback();
  }

  void _addMessage(String text, bool isMe, {String? senderName, ChatMessage? message}) {
    if (message == null) {
      message = ChatMessage(
        text: text,
        isMe: isMe,
        timestamp: DateTime.now(),
        status: isMe ? voice.MessageStatus.sent : voice.MessageStatus.delivered,
        type: voice.MessageType.text,
        senderName: senderName,
      );
    } else if (!isMe && senderName != null) {
      // Update sender name if provided
      message = ChatMessage(
        text: message.text,
        isMe: message.isMe,
        timestamp: message.timestamp,
        status: message.status,
        type: message.type,
        voiceMessage: message.voiceMessage,
        senderName: senderName,
      );
    }
    
    // Add message to list (real-time from ESP32)
    _messages.add(message);
    
    // Show notification for received messages (not from current user)
    if (!isMe) {
      _showMessageNotification(message, senderName);
    }
    
    // Clear loading states when real-time messages arrive (indicates connection is working)
    if (_isLoadingMessages && _messages.isNotEmpty) {
      _isLoadingMessages = false;
    }
    
    // Mark as having messages (for cached state)
    _hasCachedMessages = true;
    
    notifyListeners();
  }
  
  Future<void> _showMessageNotification(ChatMessage message, String? senderName) async {
    try {
      // Check notification settings
      final prefs = await SharedPreferences.getInstance();
      final messageNotificationsEnabled = prefs.getBool('notification_messages') ?? true;
      
      if (!messageNotificationsEnabled) {
        return;
      }
      
      // Get current user to avoid notifying for own messages
      final currentUserEmail = prefs.getString('user_email') ?? '';
      final currentUserName = prefs.getString('user_name') ?? '';
      
      // Don't notify if sender is current user
      if (senderName == currentUserName || senderName == currentUserEmail) {
        return;
      }
      
      // Show notification
      final displayName = senderName ?? 'Unknown User';
      final messageText = message.text;
      
      // Handle voice messages
      if (message.type == voice.MessageType.voice && message.voiceMessage != null) {
        await NotificationService().showMessageNotification(
          sender: displayName,
          message: 'Voice message',
          payload: jsonEncode({
            'type': 'message',
            'chatType': 'local',
            'senderName': displayName,
            'messageType': 'voice',
            'timestamp': message.timestamp.toIso8601String(),
          }),
        );
      } else {
        await NotificationService().showMessageNotification(
          sender: displayName,
          message: messageText,
          payload: jsonEncode({
            'type': 'message',
            'chatType': 'local',
            'senderName': displayName,
            'message': messageText,
            'timestamp': message.timestamp.toIso8601String(),
          }),
        );
      }
    } catch (e) {
      print('Error showing message notification: $e');
    }
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }

  void clearDebugLogs() {
    _debugLogs.clear();
    notifyListeners();
  }

  /// Add structured debug log with rich telemetry
  void addStructuredDebug(Map<String, dynamic> payload) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = {
      'timestamp': timestamp,
      'source': payload['source'] ?? 'unknown',
      'event': payload['event'] ?? 'unknown',
      'metrics': payload['metrics'] ?? {},
      ...payload,
    };
    
    final logString = '[${logEntry['source']}] ${logEntry['event']}';
    if (logEntry['metrics'].isNotEmpty) {
      final metrics = logEntry['metrics'] as Map<String, dynamic>;
      final metricsStr = metrics.entries
          .map((e) => '${e.key}=${e.value}')
          .join(', ');
      _debugLogs.add('$logString ($metricsStr)');
    } else {
      _debugLogs.add(logString);
    }
    
    if (_debugLogs.length > 100) {
      _debugLogs.removeAt(0);
    }
    notifyListeners();
  }

  /// Validate Base64 string format
  bool _isValidBase64(String str) {
    if (str.isEmpty) return false;
    // Check if string contains only valid Base64 characters
    final base64Pattern = RegExp(r'^[A-Za-z0-9+/]*={0,2}$');
    return base64Pattern.hasMatch(str);
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    _debugSubscription?.cancel();
    _bluetoothService.dispose();
    _voiceExtension.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final bool isMe;
  final DateTime timestamp;
  voice.MessageStatus status;
  final voice.MessageType type;
  final voice.VoiceMessage? voiceMessage;
  final String? senderName; // Sender's name for received messages

  ChatMessage({
    required this.text,
    required this.isMe,
    required this.timestamp,
    this.status = voice.MessageStatus.sent,
    this.type = voice.MessageType.text,
    this.voiceMessage,
    this.senderName,
  });
}

// voice.MessageStatus is defined in voice_chat_extension.dart

