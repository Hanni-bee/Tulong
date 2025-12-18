import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import '../services/bluetooth_service.dart';
import '../services/voice_chat_extension.dart' as voice;
import '../services/notification_service.dart';
import '../constants/app_colors.dart';

class ChatProvider with ChangeNotifier {
  final BluetoothService _bluetoothService = BluetoothService();
  final voice.VoiceChatExtension _voiceExtension = voice.VoiceChatExtension();
  
  List<BluetoothDevice> _pairedDevices = [];
  BluetoothDevice? _selectedDevice;
  bool _isConnected = false;
  final List<ChatMessage> _messages = [];
  final List<String> _debugLogs = [];
  bool _isConnecting = false;
  
  // New UI tracking states
  bool _isLoadingMessages = false;
  bool _isRefreshingMessages = false;
  bool _isLocalChatScreenVisible = false;
  bool _isTyping = false;
  
  // Connected users on the channel (extracted from messages)
  final Set<String> _connectedUsers = {};
  String? _currentUserName;

  List<BluetoothDevice> get pairedDevices => _pairedDevices;
  BluetoothDevice? get selectedDevice => _selectedDevice;
  bool get isConnected => _isConnected;
  List<ChatMessage> get messages => _messages;
  List<String> get debugLogs => _debugLogs;
  bool get isConnecting => _isConnecting;
  
  // Getters for UI
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isRefreshingMessages => _isRefreshingMessages;
  bool get isTyping => _isTyping;
  String? get currentUserName => _currentUserName;
  
  int get unreadMessageCount => _messages.where((m) => !m.isMe && !m.isRead).length;
  
  List<ChatMessage> get pinnedEmergencyMessages => 
      _messages.where((m) => m.isPinned && m.isEmergency).toList();
  
  bool get hasCachedMessages => _messages.isNotEmpty;
  
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
  
  /// Set visibility of the local chat screen to handle read receipts
  void setLocalChatScreenVisible(bool visible) {
    _isLocalChatScreenVisible = visible;
    if (visible) {
      markAllMessagesAsRead();
    }
    notifyListeners();
  }
  
  /// Mark all messages as read
  void markAllMessagesAsRead() {
    bool changed = false;
    for (var message in _messages) {
      if (!message.isMe && !message.isRead) {
        message.isRead = true;
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// Simulate loading messages (could be from SQLite in future)
  Future<void> loadMessages() async {
    if (_isLoadingMessages) return;
    
    _isLoadingMessages = true;
    notifyListeners();
    
    // Simulate minor delay for loading
    await Future.delayed(const Duration(milliseconds: 500));
    
    _isLoadingMessages = false;
    notifyListeners();
  }

  /// Smart refresh for the chat screen
  Future<void> smartRefresh() async {
    if (_isRefreshingMessages) return;
    
    _isRefreshingMessages = true;
    notifyListeners();
    
    // Check connection and refresh devices
    await loadPairedDevices();
    await Future.delayed(const Duration(seconds: 1));
    
    _isRefreshingMessages = false;
    notifyListeners();
  }
  
  /// Unpin an emergency message
  void unpinEmergencyMessage(String messageId) {
    final index = _messages.indexWhere((m) => m.messageId == messageId);
    if (index != -1) {
      _messages[index].isPinned = false;
      notifyListeners();
    }
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

  Future<bool> connectToDevice(BluetoothDevice device) async {
    _isConnecting = true;
    notifyListeners();
    try {
      bool success = await _bluetoothService.connectToDevice(device);
      if (success) {
        _selectedDevice = device;
        _isConnected = true;
        // Get current user name from database/storage
        await _updateCurrentUserNameFromDatabase();
      }
      return success;
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }
  
  /// Update current user name from database/storage (signup information)
  Future<void> _updateCurrentUserNameFromDatabase() async {
    try {
      // Get user email from AuthProvider if available
      // Since we don't have direct access to AuthProvider here,
      // we'll rely on setCurrentUserName() being called from UI
      // But we can try to get from SQLite if we have the email
      
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

  Future<void> disconnect() async {
    await _bluetoothService.disconnect();
    _selectedDevice = null;
    _isConnected = false;
    _connectedUsers.clear(); // Clear connected users on disconnect

    notifyListeners();
  }

  Future<bool> sendMessage(String text) async {
    if (text.trim().isEmpty) return false;

    ChatMessage message = ChatMessage(
      messageId: _generateId(),
      text: text.trim(),
      isMe: true,
      timestamp: DateTime.now(),
      status: voice.MessageStatus.sending,
      type: voice.MessageType.text,
      isRead: true,
    );

    _addMessage(message.text, true, message: message);
    bool success = await _bluetoothService.sendMessage(text);
    
    if (success) {
      message.status = voice.MessageStatus.sent;
    } else {
      message.status = voice.MessageStatus.failed;
    }
    
    notifyListeners();
    return success;
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
      messageId: _generateId(),
      text: '🎤 Voice message',
      isMe: isMe,
      timestamp: DateTime.now(),
      status: isMe ? voice.MessageStatus.sent : voice.MessageStatus.received,
      type: voice.MessageType.voice,
      voiceMessage: voiceMessage,
      senderName: senderName,
      isRead: isMe || _isLocalChatScreenVisible,
    );

    _messages.add(chatMessage);
    addStructuredDebug({
      'source': 'CHAT',
      'event': 'Voice message added to chat',
      'metrics': {'totalMessages': _messages.length, 'voiceSize': voiceMessage.formattedSize}
    });
    notifyListeners();
    
    // Show notification for incoming voice messages (when app is in background)
    if (!isMe) {
      _showVoiceMessageNotification(chatMessage, senderName);
    }
  }
  
  /// Show notification for incoming voice messages
  Future<void> _showVoiceMessageNotification(ChatMessage message, String? senderName) async {
    try {
      final notificationService = NotificationService();
      final sender = senderName ?? 'Unknown User';
      final duration = message.voiceMessage?.formattedDuration ?? 'Voice message';
      
      await notificationService.showMessageNotification(
        sender: sender,
        message: '🎤 $duration',
        payload: jsonEncode({
          'type': 'voice_message',
          'messageId': message.messageId,
          'senderName': sender,
          'timestamp': message.timestamp.toIso8601String(),
        }),
      );
    } catch (e) {
      // Silently fail - notifications are not critical
      debugPrint('Failed to show voice message notification: $e');
    }
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
      messageId: _generateId(),
      text: '🎤 Voice message',
      isMe: true,
      timestamp: DateTime.now(),
      status: voice.MessageStatus.sending,
      type: voice.MessageType.voice,
      voiceMessage: voiceMessage,
      isRead: true,
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
      final isEmergency = text.toUpperCase().contains('EMERGENCY') || 
                         text.toUpperCase().contains('HELP') ||
                         text.toUpperCase().contains('SOS');
                         
      message = ChatMessage(
        messageId: _generateId(),
        text: text,
        isMe: isMe,
        timestamp: DateTime.now(),
        status: isMe ? voice.MessageStatus.sent : voice.MessageStatus.delivered,
        type: voice.MessageType.text,
        senderName: senderName,
        isRead: isMe || _isLocalChatScreenVisible,
        isEmergency: isEmergency,
        isPinned: isEmergency,
      );
    } else if (!isMe && senderName != null) {
      // Update sender name if provided
      message = ChatMessage(
        messageId: message.messageId,
        text: message.text,
        isMe: message.isMe,
        timestamp: message.timestamp,
        status: message.status,
        type: message.type,
        voiceMessage: message.voiceMessage,
        senderName: senderName,
        isRead: message.isRead,
        isEmergency: message.isEmergency,
        isPinned: message.isPinned,
      );
    }
    
    _messages.add(message);
    notifyListeners();
    
    // Show notification for incoming messages (when app is in background)
    if (!isMe) {
      _showMessageNotification(message);
    }
  }
  
  /// Show notification for incoming messages
  Future<void> _showMessageNotification(ChatMessage message) async {
    try {
      final notificationService = NotificationService();
      
      // Determine sender name
      final senderName = message.senderName ?? 'Unknown User';
      
      // Truncate message for notification (max 100 chars)
      final messagePreview = message.text.length > 100 
          ? '${message.text.substring(0, 100)}...' 
          : message.text;
      
      // Show emergency notification with high priority
      if (message.isEmergency) {
        await notificationService.showEmergencyAlert(
          title: '🚨 Emergency Alert from $senderName',
          body: messagePreview,
          payload: jsonEncode({
            'type': 'emergency_message',
            'messageId': message.messageId,
            'senderName': senderName,
            'message': message.text,
            'timestamp': message.timestamp.toIso8601String(),
          }),
          color: AppColors.primaryRed,
        );
      } else {
        // Show regular message notification
        await notificationService.showMessageNotification(
          sender: senderName,
          message: messagePreview,
          payload: jsonEncode({
            'type': 'local_chat_message',
            'messageId': message.messageId,
            'senderName': senderName,
            'message': message.text,
            'timestamp': message.timestamp.toIso8601String(),
          }),
        );
      }
    } catch (e) {
      // Silently fail - notifications are not critical
      debugPrint('Failed to show message notification: $e');
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

  /// Generate a unique message ID
  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${(1000 + (9999 - 1000) * (DateTime.now().microsecond / 1000000)).round()}';
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
  final String messageId;
  final String text;
  final bool isMe;
  final DateTime timestamp;
  voice.MessageStatus status;
  final voice.MessageType type;
  final voice.VoiceMessage? voiceMessage;
  final String? senderName;
  bool isRead;
  final bool isEmergency;
  bool isPinned;

  ChatMessage({
    required this.messageId,
    required this.text,
    required this.isMe,
    required this.timestamp,
    this.status = voice.MessageStatus.sent,
    this.type = voice.MessageType.text,
    this.voiceMessage,
    this.senderName,
    this.isRead = false,
    this.isEmergency = false,
    this.isPinned = false,
  });
}

// voice.MessageStatus is defined in voice_chat_extension.dart


