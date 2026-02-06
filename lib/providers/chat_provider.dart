import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/bluetooth_service.dart';
import '../services/voice_chat_extension.dart' as voice;
import '../services/sqlite_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/enhanced_error_handler.dart';
import '../services/notification_service.dart';
import '../widgets/modern_toast.dart';

class ChatProvider with ChangeNotifier {
  // Static instance for access from services without context
  static ChatProvider? _instance;
  static ChatProvider? get instance => _instance;
  
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
  
  // Track if local chat screen is currently visible
  bool _isLocalChatScreenVisible = false;
  
  // Message buffering with start/end markers
  String _incomingMessageBuffer = '';
  String? _bufferedMessageSenderUid;
  bool _isBufferingMessage = false;
  
  // Profile requests queued while voice is active (send after VOICE_END / VOICE_DONE)
  final List<String> _queuedProfileUids = [];
  
  // Auto-reconnect settings
  bool _isAutoReconnectEnabled = true;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  
  bool get isAutoReconnectEnabled => _isAutoReconnectEnabled;
  List<BluetoothDevice> get pairedDevices => _pairedDevices;
  BluetoothDevice? get selectedDevice => _selectedDevice;
  bool get isConnected => _isConnected;
  List<ChatMessage> get messages => _messages;
  
  /// Get pinned emergency messages (sorted by timestamp, newest first)
  List<ChatMessage> get pinnedEmergencyMessages {
    final pinned = _messages.where((msg) => msg.isPinned && msg.isEmergency).toList();
    // Sort by timestamp (newest first)
    pinned.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return pinned;
  }
  
  /// Unpin an emergency message
  void unpinEmergencyMessage(String messageId) {
    final index = _messages.indexWhere((msg) => msg.messageId == messageId);
    if (index != -1) {
      _messages[index] = _messages[index].copyWith(isPinned: false);
      notifyListeners();
    }
  }
  
  /// Auto-unpin emergency messages older than 1 hour
  void _autoUnpinOldEmergencies() {
    final now = DateTime.now();
    bool updated = false;
    
    for (int i = 0; i < _messages.length; i++) {
      final msg = _messages[i];
      if (msg.isPinned && msg.isEmergency) {
        final age = now.difference(msg.timestamp);
        if (age.inHours >= 1) {
          _messages[i] = msg.copyWith(isPinned: false);
          updated = true;
        }
      }
    }
    
    if (updated) {
      notifyListeners();
    }
  }
  List<String> get debugLogs => _debugLogs;
  bool get isConnecting => _isConnecting;
  bool get isLoadingMessages => _isLoadingMessages;
  bool get isRefreshingMessages => _isRefreshingMessages;
  bool get hasCachedMessages => _hasCachedMessages;
  bool get isTyping => _isTyping;
  String? get currentUserName => _currentUserName;
  
  /// Get unread message count (messages not from current user that are unread)
  int get unreadMessageCount {
    return _messages.where((msg) => !msg.isMe && !msg.isRead).length;
  }
  
  /// Set local chat screen visibility (called when screen is opened/closed)
  void setLocalChatScreenVisible(bool isVisible) {
    _isLocalChatScreenVisible = isVisible;
    if (isVisible) {
      // Mark all messages as read when screen becomes visible
      markAllMessagesAsRead();
    }
  }
  
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
    _instance = this; // Store static instance
    _init();
    // Auto-unpin old emergencies every 5 minutes
    Timer.periodic(const Duration(minutes: 5), (_) {
      _autoUnpinOldEmergencies();
    });
  }

  void _init() {
    _messageSubscription = _bluetoothService.messageStream.listen((message) {
      print('BT_RX_LINE: $message');
      // Try to parse as JSON first (for SimpleBluetoothService messages)
      try {
        final jsonData = json.decode(message);
        if (jsonData is Map<String, dynamic>) {
          _processIncomingMapMessage(jsonData);
          return;
        }
      } catch (e) {
        // Not JSON, process as regular string message
      }
      // Process as regular string message (async, but don't await in stream)
      _processIncomingMessage(message).catchError((error) {
        print('Error processing incoming message: $error');
      });
    });

    _connectionSubscription = _bluetoothService.connectionStream.listen((connected) async {
      print('BT_CONN: $connected');
      _isConnected = connected;
      
      if (!connected && _selectedDevice != null && _isAutoReconnectEnabled) {
        // Only auto-reconnect if we didn't explicitly disconnect
        _startAutoReconnect();
      } else if (connected) {
        // Successfully connected, reset attempts and timer
        _reconnectAttempts = 0;
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        
        // Trigger data sync to ESP32 flash memory
        print('BT_CONN: Connection established, triggering sync...');
        _triggerDataSync();
      }
      
      notifyListeners();
    });

    _debugSubscription = _bluetoothService.debugStream.listen((log) {
      print('BT_DEBUG: $log');
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
  
  /// Mark all messages as read (called when user views the chat screen)
  void markAllMessagesAsRead() {
    bool hasChanges = false;
    for (int i = 0; i < _messages.length; i++) {
      if (!_messages[i].isRead && !_messages[i].isMe) {
        _messages[i] = _messages[i].copyWith(isRead: true);
        hasChanges = true;
      }
    }
    if (hasChanges) {
      notifyListeners();
    }
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
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _bluetoothService.disconnect();
    // Keep _selectedDevice so we can show "Reconnect" option in the UI
    // Only clear it when connecting to a different device or explicitly clearing
    _isConnected = false;
    _connectedUsers.clear(); // Clear connected users on disconnect
    notifyListeners();
  }
  
  /// Toggle auto-reconnect
  void setAutoReconnectEnabled(bool enabled) {
    _isAutoReconnectEnabled = enabled;
    if (!enabled) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    }
    notifyListeners();
  }

  /// Start auto-reconnect sequence
  void _startAutoReconnect() {
    if (_reconnectTimer != null || _isConnecting) return;
    
    addStructuredDebug({
      'source': 'BLUETOOTH',
      'event': 'Auto-reconnect sequence started',
      'metrics': {'device': _selectedDevice?.name}
    });

    _reconnectTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (_isConnected || !_isAutoReconnectEnabled || _reconnectAttempts >= maxReconnectAttempts) {
        timer.cancel();
        _reconnectTimer = null;
        if (_reconnectAttempts >= maxReconnectAttempts) {
          addStructuredDebug({
            'source': 'BLUETOOTH',
            'event': 'Auto-reconnect failed - max attempts reached',
          });
        }
        return;
      }
      
      _reconnectAttempts++;
      addStructuredDebug({
        'source': 'BLUETOOTH',
        'event': 'Auto-reconnect attempt',
        'metrics': {'attempt': _reconnectAttempts, 'device': _selectedDevice?.name}
      });
      
      if (_selectedDevice != null) {
        await connectToDevice(_selectedDevice!);
      }
    });
  }

  /// Clear selected device (for when user explicitly wants to remove selection)
  void clearSelectedDevice() {
    _selectedDevice = null;
    _isConnected = false;
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
      if (!_bluetoothService.isConnected) {
        message.status = voice.MessageStatus.failed;
        notifyListeners();
        
        if (context != null) {
          ModernToastManager.show(
            context,
            message: '⚠️ ESP32 Not Connected. Please connect to a device via Home Screen to send messages.',
            type: ToastType.warning,
            duration: const Duration(seconds: 5),
          );
        }
        return false;
      }

      bool success = await _bluetoothService.sendMessage(text);
      
      if (success) {
        message.status = voice.MessageStatus.sent;
      } else {
        message.status = voice.MessageStatus.failed;
        if (context != null) {
          ModernToastManager.show(
            context,
            message: 'Message failed to send. Please try again.',
            type: ToastType.error,
          );
        }
      }
      
      notifyListeners();
      return success;
    } catch (e) {
      message.status = voice.MessageStatus.failed;
      notifyListeners();
      
      if (context != null) {
        ModernToastManager.show(
          context,
          message: 'Error: ${e.toString()}',
          type: ToastType.error,
        );
      }
      return false;
    }
  }

  /// Process incoming Map message (JSON format from ESP32)
  /// Handles: profile_response (save to cache), profile_queued, SOS/emergency map messages.
  void _processIncomingMapMessage(Map<String, dynamic> data) {
    try {
      // profile_response: save to cache first; later when message comes we check UID in cache before requesting
      if (data['command'] == 'profile_response') {
        final profileData = data['data'] as Map<String, dynamic>?;
        if (profileData != null) {
          _saveProfileFromESP32(profileData);
          print('BT_PROFILE: profile_response received -> saved to cache (UID=${profileData['uid']})');
        }
        return;
      }
      // profile_queued: ESP32 deferred get_profile due to voice; it may send profile after voice ends
      if (data['command'] == 'profile_queued' && data['reason'] == 'voice_active') {
        print('BT_PROFILE: profile_queued (voice_active) — ESP32 will send profile after voice ends');
        addStructuredDebug({
          'source': 'CHAT',
          'event': 'Profile request queued by ESP32 (voice active)',
          'metrics': {},
        });
        return;
      }

      final messageText = data['message'] ?? '';
      final senderName = data['sender_name'] ?? 'Unknown';
      // Check for emergency flag - this includes messages from home page SOS button
      final isEmergency = data['is_emergency'] == true || data['isEmergency'] == true;
      
      if (messageText.isEmpty) return;
      
      // Add connected user if sender name is available
      if (senderName != 'Unknown') {
        _addConnectedUser(senderName);
      }
      
      // Prepare rawData with source for SOS detection
      final rawDataWithSource = Map<String, dynamic>.from(data);
      if (isEmergency && !rawDataWithSource.containsKey('source')) {
        rawDataWithSource['source'] = 'sos';
      }
      
      // Add message with emergency flag and rawData
      // Messages from home page SOS button (isEmergency: true) will be auto-pinned here
      _addMessage(messageText, false, senderName: senderName, isEmergency: isEmergency, rawData: rawDataWithSource);
      
      // Trigger haptic feedback and sound for emergency messages
      if (isEmergency) {
        HapticFeedback.heavyImpact();
        // Emergency messages should be more noticeable
        addStructuredDebug({
          'source': 'EMERGENCY',
          'event': 'Emergency message received',
          'metrics': {'sender': senderName, 'message': messageText.substring(0, messageText.length > 50 ? 50 : messageText.length)}
        });
      }
    } catch (e) {
      addStructuredDebug({
        'source': 'CHAT',
        'event': 'Error processing map message',
        'metrics': {'error': e.toString()}
      });
    }
  }

  /// Process incoming message and handle voice messages
  Future<void> _processIncomingMessage(String data) async {
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
        // Voice RX ended: process any profile requests queued during voice
        _processQueuedProfileRequests();
      } else if (message.startsWith('<VOICE_START>') || message.startsWith('<VOICE_END>')) {
        // Voice markers, handled by voice extension
        continue;
      } else if (message.startsWith('<MSG_START:')) {
        // New message started - flush previous if any
        await _flushBufferedMessage();
        
        // Extract UID from start marker: <MSG_START:UID>
        final uidMatch = RegExp(r'<MSG_START:(.+?)>').firstMatch(message);
        if (uidMatch != null) {
          final uid = uidMatch.group(1);
          if (uid != null && uid.isNotEmpty) {
            _bufferedMessageSenderUid = uid;
            _incomingMessageBuffer = '';
            _isBufferingMessage = true;
            print('BT_RX: Message start from UID: $uid');
            print('BT_RX: RECV_MSG_HEADER_UID=$uid'); // log: kaninong UID yung narereceive as msg header
            
            // Defer profile lookup until after VOICE_END if voice is active (never during voice stream)
            if (!_voiceExtension.isVoiceActive) {
              _isUidKnown(uid).then((isKnown) {
                if (!isKnown) {
                  print('BT_PROFILE: Unknown UID detected: $uid - Requesting profile');
                  _requestProfileFromESP32(uid);
                }
              });
            }
          }
          
          addStructuredDebug({
            'source': 'CHAT',
            'event': 'Message buffering started',
            'metrics': {'uid': uid}
          });
        }
        // Header line never appears in UI — skip adding it as message
        continue;
      } else if (message == '<MSG_END>') {
        // Message complete - flush buffer
        await _flushBufferedMessage();
        continue; // End marker never appears in UI
      } else if (_isBufferingMessage) {
        // Continuation fragment - append to buffer
        _incomingMessageBuffer += message;
      } else if (message.startsWith('From A:') || message.startsWith('From B:')) {
        // Extract sender info from ESP32 messages (legacy format)
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
        // Try to parse as JSON (for profile responses and other commands)
        try {
          final jsonData = json.decode(message);
          if (jsonData is Map<String, dynamic>) {
            // Check if it's a profile response (matches ESP32 format)
            if (jsonData.containsKey('command') && jsonData['command'] == 'profile_response') {
              final profileData = jsonData['data'] as Map<String, dynamic>?;
              if (profileData != null) {
                _saveProfileFromESP32(profileData);
                return; // Don't add as message
              }
            }
          }
        } catch (e) {
          // Not JSON, continue normal processing
        }
        
        // Regular text message - try to extract user info
        String? extractedSender = _extractUserFromMessage(message);
        _addMessage(message, false, senderName: extractedSender);
      }
    }
  }
  
  /// Check if UID is known (cached or in SQLite)
  Future<bool> _isUidKnown(String uid) async {
    if (uid.isEmpty || uid == 'UNKNOWN') return false;
    
    final prefs = await SharedPreferences.getInstance();
    // Check cache first
    final knownUid = prefs.getString('known_uid_$uid');
    if (knownUid != null && knownUid == 'true') {
      return true;
    }
    
    // Check SQLite
    try {
      final sqliteService = SQLiteService();
      final users = await sqliteService.getAllUsers();
      final hasUid = users.any((user) => user['uid']?.toString() == uid);
      if (hasUid) {
        // Cache it
        await prefs.setString('known_uid_$uid', 'true');
        return true;
      }
    } catch (e) {
      print('Error checking UID in SQLite: $e');
    }
    
    return false;
  }

  /// Request profile from ESP32 (public for modal tap-to-fetch).
  Future<void> requestProfileFromESP32(String uid) => _requestProfileFromESP32(uid);

  /// Request profile from ESP32. Queues request if voice is active (sends after voice ends).
  Future<void> _requestProfileFromESP32(String uid) async {
    if (!_bluetoothService.isConnected) {
      print('BT_PROFILE: Cannot request profile: Not connected');
      return;
    }
    if (uid.isEmpty || uid == 'UNKNOWN') return;

    // Critical: never send get_profile during active voice stream
    if (_voiceExtension.isVoiceActive) {
      if (!_queuedProfileUids.contains(uid)) {
        _queuedProfileUids.add(uid);
        print('BT_PROFILE: Voice active — queued profile request for uid=$uid');
        addStructuredDebug({
          'source': 'CHAT',
          'event': 'Profile request queued (voice active)',
          'metrics': {'uid': uid},
        });
      }
      return;
    }

    try {
      final requestJson = jsonEncode({
        'command': 'get_profile',
        'target_uid': uid,
        'force_rf': true,
      });
      print('BT_PROFILE: Requesting profile for target_uid: $uid (force_rf=true)');
      await _bluetoothService.sendMessage(requestJson);
      addStructuredDebug({
        'source': 'CHAT',
        'event': 'Profile request sent',
        'metrics': {'uid': uid},
      });
    } catch (e) {
      print('BT_PROFILE: Error requesting profile: $e');
    }
  }

  /// Send any profile requests that were queued while voice was active. Call after VOICE_END (RX) or VOICE_DONE (TX).
  Future<void> _processQueuedProfileRequests() async {
    if (_queuedProfileUids.isEmpty || _voiceExtension.isVoiceActive) return;
    final toSend = List<String>.from(_queuedProfileUids);
    _queuedProfileUids.clear();
    for (final uid in toSend) {
      if (_voiceExtension.isVoiceActive) {
        _queuedProfileUids.add(uid);
        return;
      }
      try {
        final requestJson = jsonEncode({
          'command': 'get_profile',
          'target_uid': uid,
          'force_rf': true,
        });
        await _bluetoothService.sendMessage(requestJson);
        print('BT_PROFILE: Sent queued profile request for uid=$uid');
      } catch (e) {
        print('BT_PROFILE: Error sending queued profile request: $e');
      }
    }
  }

  /// Save profile data from ESP32 response
  Future<void> _saveProfileFromESP32(Map<String, dynamic> profileData) async {
    try {
      final uid = profileData['uid']?.toString() ?? '';
      if (uid.isEmpty) {
        print('BT_PROFILE: Cannot save profile: No UID');
        return;
      }
      
      // Mark UID as known in cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('known_uid_$uid', 'true');
      
      // Extract profile fields (matches ESP32 format)
      final name = profileData['name']?.toString() ?? '';
      final username = profileData['username']?.toString() ?? '';
      final street = profileData['street']?.toString() ?? '';
      final province = profileData['province']?.toString() ?? '';
      final city = profileData['city']?.toString() ?? '';
      final barangay = profileData['barangay']?.toString() ?? '';
      final suffix = profileData['suffix']?.toString() ?? '';
      
      // Parse name into first_name, last_name
      String firstName = '';
      String lastName = '';
      if (name.isNotEmpty) {
        final nameParts = name.trim().split(' ');
        if (nameParts.length >= 2) {
          firstName = nameParts[0];
          // Check if last part is suffix
          if (suffix.isNotEmpty && nameParts.last.toLowerCase() == suffix.toLowerCase()) {
            lastName = nameParts.sublist(1, nameParts.length - 1).join(' ');
          } else {
            lastName = nameParts.sublist(1).join(' ');
          }
        } else {
          firstName = name;
        }
      }
      
      // Save to SharedPreferences (per UID for multi-user support)
      await prefs.setString('profile_name_$uid', name);
      await prefs.setString('profile_username_$uid', username);
      await prefs.setString('profile_street_$uid', street);
      await prefs.setString('profile_province_$uid', province);
      await prefs.setString('profile_city_$uid', city);
      await prefs.setString('profile_barangay_$uid', barangay);
      await prefs.setString('profile_suffix_$uid', suffix);
      
      // Save to SQLite
      try {
        final sqliteService = SQLiteService();
        
        // Check if user exists by UID
        final users = await sqliteService.getAllUsers();
        final existingUser = users.firstWhere(
          (user) => user['uid']?.toString() == uid,
          orElse: () => {},
        );
        
        if (existingUser.isNotEmpty) {
          // Update existing user
          await sqliteService.updateUser(existingUser['id'], {
            'first_name': firstName,
            'last_name': lastName,
            'username': username,
            'street': street,
            'province': province,
            'city': city,
            'barangay': barangay,
            'suffix': suffix,
            'uid': uid,
          });
          print('BT_PROFILE: Updated user in SQLite for UID: $uid');
        } else {
          // Create new user (if username is available)
          if (username.isNotEmpty) {
            await sqliteService.insertUser({
              'uid': uid,
              'first_name': firstName,
              'last_name': lastName,
              'username': username,
              'street': street,
              'province': province,
              'city': city,
              'barangay': barangay,
              'suffix': suffix,
              'created_at': DateTime.now().millisecondsSinceEpoch,
              'is_synced': 0,
              'address_setup_completed': 1,
            });
            print('BT_PROFILE: Created new user in SQLite for UID: $uid');
          }
        }
      } catch (e) {
        print('BT_PROFILE: Error saving to SQLite: $e');
      }
      
      print('BT_PROFILE: Profile saved for UID: $uid');
      addStructuredDebug({
        'source': 'CHAT',
        'event': 'Profile saved from ESP32',
        'metrics': {'uid': uid, 'name': name}
      });

      // Override "Unknown" in chat UI: any message with this UID that shows Unknown gets the real name
      final displayName = name.isNotEmpty ? name : 'Unknown';
      bool updated = false;
      for (int i = 0; i < _messages.length; i++) {
        final msg = _messages[i];
        if (msg.senderUid == uid &&
            !msg.isMe &&
            (msg.senderName == null || msg.senderName!.isEmpty || msg.senderName == 'Unknown')) {
          _messages[i] = msg.copyWith(senderName: displayName);
          updated = true;
        }
      }
      if (updated) {
        print('BT_PROFILE: Overrode Unknown with name for UID: $uid in chat UI');
        notifyListeners();
      }
    } catch (e) {
      print('BT_PROFILE: Error saving profile: $e');
    }
  }

  /// Flush buffered message and display it
  Future<void> _flushBufferedMessage() async {
    if (!_isBufferingMessage || _incomingMessageBuffer.isEmpty) {
      _isBufferingMessage = false;
      _incomingMessageBuffer = '';
      _bufferedMessageSenderUid = null;
      return;
    }
    
    // Clean the message buffer - remove any MSG_END tags and header so header never appears in UI
    String completeMessage = _incomingMessageBuffer
        .replaceAll('<MSG_END>', '')
        .replaceAll('&lt;MSG_END&gt;', '')
        .replaceFirst(RegExp(r'<MSG_START:[^>]*>'), '') // strip header if it leaked into body
        .trim();
    final senderUid = _bufferedMessageSenderUid;
    
    // Clear buffer
    _incomingMessageBuffer = '';
    _bufferedMessageSenderUid = null;
    _isBufferingMessage = false;
    
    // Check if this is an SOS message from hardware physical button
    // ESP32 sends: <MSG_START:UIDSOS> + message + <MSG_END>
    // ONLY pin based on WHERE it came from (UIDSOS), NOT based on message content
    final isSosFromHardware = senderUid != null && 
                               (senderUid.toUpperCase().contains('SOS') || 
                                senderUid.toUpperCase().endsWith('SOS'));
    
    // Note: Home page SOS button messages are sent with isEmergency: true flag in JSON format
    // They are handled by _processIncomingMapMessage() which already pins them
    // This path (_flushBufferedMessage) handles hardware SOS button (UIDSOS format)
    
    // Get cached name from UID (extract actual UID if it's UIDSOS format)
    String? senderName;
    String? actualUid = senderUid;
    
    // If UID contains SOS, extract the actual UID part (e.g., "UIDSOS" -> try to get name from cache)
    // For SOS messages, we still want to show the sender's name if available
    if (senderUid != null && senderUid != 'UNKNOWN') {
      // Try to extract actual UID (remove SOS suffix if present)
      if (isSosFromHardware && senderUid.length > 3) {
        // Try to find the actual UID (might be embedded in the SOS UID)
        // For now, we'll use the full UID but mark as emergency
        actualUid = senderUid;
      }
      
      // Get cached name (synchronous lookup from SharedPreferences)
      final prefs = await SharedPreferences.getInstance();
      final cachedName = prefs.getString('profile_name_$actualUid');
      
      if (cachedName != null && cachedName.isNotEmpty) {
        senderName = cachedName;
      } else {
        // Fallback: try SQLite
        try {
          final sqliteService = SQLiteService();
          final users = await sqliteService.getAllUsers();
          final user = users.firstWhere(
            (user) => user['uid']?.toString() == actualUid,
            orElse: () => {},
          );
          
          if (user.isNotEmpty) {
            final firstName = user['first_name']?.toString() ?? '';
            final lastName = user['last_name']?.toString() ?? '';
            final suffix = user['suffix']?.toString() ?? '';
            
            senderName = [firstName, lastName, suffix]
                .where((s) => s.isNotEmpty)
                .join(' ')
                .trim();
            
            if (senderName.isNotEmpty) {
              // Cache it for future use
              await prefs.setString('profile_name_$actualUid', senderName);
            } else {
              senderName = 'Unknown'; // Display profile details only, never UID
            }
          } else {
            senderName = 'Unknown'; // Display profile details only, never UID
          }
        } catch (e) {
          print('Error getting cached name from UID: $e');
          senderName = 'Unknown'; // Display profile details only, never UID
        }
      }
      
      if (senderName != null && senderName.isNotEmpty) {
        _addConnectedUser(senderName);
      }
    }
    
    // Display the complete message with emergency flag ONLY if from hardware SOS button (UIDSOS).
    // UI shows profile details (name) only, never UID. Store senderUid for tap-to-profile.
    final displayName = (senderName != null && senderName.isNotEmpty && senderName != 'Unknown')
        ? senderName!
        : 'Unknown';
    // Profile we display is sender's. If Unknown: request sender's profile → goes to other nodes (RF);
    // the node that has this UID (the sender) will send profile back when it receives the request.
    if (displayName == 'Unknown' && actualUid != null && actualUid.isNotEmpty && actualUid != 'UNKNOWN') {
      print('BT_PROFILE: Requesting sender profile uid=$actualUid (request to other nodes; sender node will send info)');
      _requestProfileFromESP32(actualUid);
    }
    final rawDataForHardwareSos = isSosFromHardware ? {'source': 'sos'} : null;
    _addMessage(completeMessage, false, senderName: displayName, senderUid: actualUid, isEmergency: isSosFromHardware, rawData: rawDataForHardwareSos);
    
    print('BT_RX: Complete message displayed (${completeMessage.length} chars) from UID: $senderUid, Name: $senderName');
    print('BT_RX: RECV_MSG_HEADER_UID=$senderUid'); // log: kaninong UID yung narereceive as msg header (on display)
    addStructuredDebug({
      'source': 'CHAT',
      'event': 'Complete message displayed',
      'metrics': {'length': completeMessage.length, 'uid': senderUid, 'name': senderName}
    });
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

    // For incoming voice messages (!isMe), mark as read only if chat screen is visible
    final shouldMarkAsRead = isMe || _isLocalChatScreenVisible;
    
    final chatMessage = ChatMessage(
      text: '🎤 Voice message',
      isMe: isMe,
      timestamp: DateTime.now(),
      status: isMe ? voice.MessageStatus.sent : voice.MessageStatus.received,
      type: voice.MessageType.voice,
      voiceMessage: voiceMessage,
      senderName: senderName,
      isRead: shouldMarkAsRead,
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

    // Send over Bluetooth (waits for VOICE_READY, then chunks, then VOICE_DONE)
    final success = await _voiceExtension.sendVoiceMessage(
      base64Audio,
      (chunk) => _bluetoothService.sendMessage(chunk),
    );
    // Voice TX ended: process any profile requests queued during voice
    _processQueuedProfileRequests();

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

  void _addMessage(String text, bool isMe, {String? senderName, String? senderUid, ChatMessage? message, bool isEmergency = false, Map<String, dynamic>? rawData}) {
    if (message == null) {
      // For incoming messages (!isMe), mark as read only if chat screen is visible
      // For outgoing messages (isMe), always mark as read
      final shouldMarkAsRead = isMe || _isLocalChatScreenVisible;
      
      // Generate unique message ID for emergency messages
      final messageId = isEmergency ? '${DateTime.now().millisecondsSinceEpoch}_${senderName ?? senderUid ?? 'unknown'}' : null;
      
      message = ChatMessage(
        text: text,
        isMe: isMe,
        timestamp: DateTime.now(),
        status: isMe ? voice.MessageStatus.sent : voice.MessageStatus.delivered,
        type: voice.MessageType.text,
        senderName: senderName,
        senderUid: senderUid,
        isRead: shouldMarkAsRead, // Mark as read if sent by user or if screen is visible
        isEmergency: isEmergency, // Set emergency flag (from hardware SOS button OR home page SOS button)
        isPinned: isEmergency, // Auto-pin emergency messages (from hardware OR home page SOS button)
        messageId: messageId, // Unique ID for unpinning
        rawData: rawData, // Store raw data for source detection
      );
    } else if (!isMe && (senderName != null || senderUid != null)) {
      // Update sender name/UID if provided, preserve isRead status
      message = message.copyWith(
        senderName: senderName ?? message.senderName,
        senderUid: senderUid ?? message.senderUid,
        isRead: message.isRead || _isLocalChatScreenVisible, // Mark as read if screen is visible
      );
    } else if (!message.isMe) {
      // For existing incoming messages, update isRead based on screen visibility
      message = message.copyWith(
        isRead: message.isRead || _isLocalChatScreenVisible,
      );
    }
    
    // Add message to list (real-time from ESP32)
    _messages.add(message);
    
    // Notify listeners to update badge count
    notifyListeners();
    
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

  /// Sync profile data to ESP32 flash memory (public method)
  /// Can be called when profile is updated while connected
  Future<void> syncProfileToESP32() async {
    if (!_bluetoothService.isConnected) {
      print('BT_SYNC: Cannot sync profile: Not connected');
      return;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('session_username') ?? prefs.getString('session_email');
      
      if (username == null || username.isEmpty) {
        print('BT_SYNC: Cannot sync profile: No user logged in');
        return;
      }
      
      print('BT_SYNC: Syncing profile for user: $username');
      
      // Get UID - fetch from SQLite/Firebase if not in SharedPreferences
      String uid = prefs.getString('session_uid') ?? "";
      
      if (uid.isEmpty) {
        print('BT_SYNC: UID not in SharedPreferences, fetching from database...');
        
        // Try SQLite first
        try {
          final sqliteService = SQLiteService();
          final sqliteUser = await sqliteService.getUserByUsername(username);
          if (sqliteUser != null && sqliteUser.containsKey('uid') && sqliteUser['uid'] != null) {
            uid = sqliteUser['uid'].toString();
            await prefs.setString('session_uid', uid);
            print('BT_SYNC: UID fetched from SQLite: $uid');
          }
        } catch (e) {
          print('BT_SYNC: Error fetching UID from SQLite: $e');
        }
        
        // Firebase UID fetch removed (offline-only mode)
        
        // If still empty, cannot sync
        if (uid.isEmpty) {
          print('BT_SYNC_ERR: Cannot sync profile: UID not found in database');
          print('BT_SYNC_ERR: Please ensure user has UID in database before syncing');
          return;
        }
      }
      
      // Get all profile data from SharedPreferences (matching ESP32 variable names)
      final name = prefs.getString('profile_name') ?? prefs.getString('session_name') ?? username;
      final profileUsername = prefs.getString('profile_username') ?? username;
      final street = prefs.getString('profile_street') ?? "";
      final province = prefs.getString('profile_province') ?? "";
      final city = prefs.getString('profile_city') ?? "";
      final barangay = prefs.getString('profile_barangay') ?? "";
      final suffix = prefs.getString('profile_suffix') ?? "";
      
      print('BT_SYNC: Profile data from SharedPreferences:');
      print('  name: $name');
      print('  username: $profileUsername');
      print('  street: $street');
      print('  province: $province');
      print('  city: $city');
      print('  barangay: $barangay');
      print('  uid: $uid');
      print('  suffix: $suffix');
      
      // Build profile JSON (flat structure as expected by ESP32)
      // Variable names must match ESP32 extractJsonValue() calls exactly
      final profileJson = jsonEncode({
        "command": "sync_profile",
        "name": name,
        "username": profileUsername,
        "uid": uid,
        "suffix": suffix,
        "street": street,
        "province": province,
        "city": city,
        "barangay": barangay,
      });
      
      print('BT_SYNC: Sending profile data: $profileJson');
      await _bluetoothService.sendMessage(profileJson);
      print('BT_SYNC: Profile data sent successfully');
    } catch (e) {
      print('BT_SYNC: Error syncing profile: $e');
    }
  }

  /// Sync SOS message to ESP32 flash memory (public method)
  /// Can be called when SOS message is updated while connected
  Future<void> syncSosToESP32() async {
    if (!_bluetoothService.isConnected) {
      print('BT_SYNC: Cannot sync SOS: Not connected');
      return;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('session_username') ?? prefs.getString('session_email');
      
      if (username == null || username.isEmpty) {
        print('BT_SYNC: Cannot sync SOS: No user logged in');
        return;
      }
      
      print('BT_SYNC: Syncing SOS for user: $username');
      
      // Get SOS message from SharedPreferences
      final sosMessage = prefs.getString('emergency_message_$username') ?? 
                        'I need help. Please contact me immediately.';
      
      final sosJson = jsonEncode({
        "command": "sync_sos",
        "message": sosMessage,
      });
      
      print('BT_SYNC: Sending SOS message: $sosJson');
      await _bluetoothService.sendMessage(sosJson);
      print('BT_SYNC: SOS message sent successfully');
    } catch (e) {
      print('BT_SYNC: Error syncing SOS: $e');
    }
  }

  /// Trigger data sync to ESP32 flash memory when connection is established
  /// Reads user data from SharedPreferences and SQLite (not AuthProvider instance)
  Future<void> _triggerDataSync() async {
    if (!_bluetoothService.isConnected) {
      print('BT_SYNC: Cannot sync: Not connected');
      return;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Get username from SharedPreferences
      final username = prefs.getString('session_username') ?? prefs.getString('session_email');
      
      // Option A: Allow sync even without logged-in user (temporary test)
      if (username == null || username.isEmpty) {
        print('BT_SYNC: No user logged in — sending TEST payloads');
        _debugLogs.add('BT_SYNC: No user logged in — sending TEST payloads');
        notifyListeners();
        
        // Send test profile data
        final testProfileJson = jsonEncode({
          "command": "sync_profile",
          "name": "TEST USER",
          "username": "test",
          "street": "123",
          "province": "NCR",
          "city": "Manila",
          "barangay": "1"
        });
        
        print('BT_SYNC: Sending TEST profile data: $testProfileJson');
        await _bluetoothService.sendMessage(testProfileJson);
        print('BT_SYNC: TEST profile data sent successfully');
        
        // Send test SOS message
        final testSosJson = jsonEncode({
          "command": "sync_sos",
          "message": "TEST SOS"
        });
        
        print('BT_SYNC: Sending TEST SOS message: $testSosJson');
        await _bluetoothService.sendMessage(testSosJson);
        print('BT_SYNC: TEST SOS message sent successfully');
        
        print('BT_SYNC: TEST sync completed successfully');
        return;
      }
      
      print('BT_SYNC: Starting sync for user: $username');
      
      // Get all profile data from SharedPreferences (matching ESP32 variable names)
      final name = prefs.getString('profile_name') ?? prefs.getString('session_name') ?? username;
      final profileUsername = prefs.getString('profile_username') ?? username;
      final street = prefs.getString('profile_street') ?? "";
      final province = prefs.getString('profile_province') ?? "";
      final city = prefs.getString('profile_city') ?? "";
      final barangay = prefs.getString('profile_barangay') ?? "";
      final uid = prefs.getString('session_uid') ?? "";
      final suffix = prefs.getString('profile_suffix') ?? "";
      
      print('BT_SYNC: Profile data from SharedPreferences:');
      print('  name: $name');
      print('  username: $profileUsername');
      print('  street: $street');
      print('  province: $province');
      print('  city: $city');
      print('  barangay: $barangay');
      print('  uid: $uid');
      print('  suffix: $suffix');
      
      // Build profile JSON (flat structure as expected by ESP32)
      // Variable names must match ESP32 extractJsonValue() calls exactly
      final profileJson = jsonEncode({
        "command": "sync_profile",
        "name": name,
        "username": profileUsername,
        "uid": uid,
        "suffix": suffix,
        "street": street,
        "province": province,
        "city": city,
        "barangay": barangay,
      });
      
      print('BT_SYNC: Sending profile data: $profileJson');
      await _bluetoothService.sendMessage(profileJson);
      print('BT_SYNC: Profile data sent successfully');
      
      // Get SOS message from SharedPreferences
      final sosMessage = prefs.getString('emergency_message_$username') ?? 
                        'I need help. Please contact me immediately.';
      
      final sosJson = jsonEncode({
        "command": "sync_sos",
        "message": sosMessage,
      });
      
      print('BT_SYNC: Sending SOS message: $sosJson');
      await _bluetoothService.sendMessage(sosJson);
      print('BT_SYNC: SOS message sent successfully');
      
      print('BT_SYNC: Sync completed successfully');
    } catch (e) {
      print('BT_SYNC: Error during sync: $e');
      _debugLogs.add('BT_SYNC: Error during sync: $e');
      notifyListeners();
    }
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
  final String? senderUid;   // Sender's UID (from <MSG_START:UID>) for received messages
  bool isRead; // Track if message has been read
  final bool isEmergency; // Flag to indicate emergency message from SOS ring
  bool isPinned; // Flag to indicate pinned emergency message
  final String? messageId; // Unique ID for message (for unpinning)
  final Map<String, dynamic>? rawData; // Raw message data for source detection

  ChatMessage({
    required this.text,
    required this.isMe,
    required this.timestamp,
    this.status = voice.MessageStatus.sent,
    this.type = voice.MessageType.text,
    this.voiceMessage,
    this.senderName,
    this.senderUid,
    this.isRead = false, // Default to unread for incoming messages
    this.isEmergency = false, // Default to false for normal messages
    this.isPinned = false, // Default to false, emergency messages auto-pin
    this.messageId,
    this.rawData,
  });
  
  ChatMessage copyWith({
    String? text,
    bool? isMe,
    DateTime? timestamp,
    voice.MessageStatus? status,
    voice.MessageType? type,
    voice.VoiceMessage? voiceMessage,
    String? senderName,
    String? senderUid,
    bool? isRead,
    bool? isEmergency,
    bool? isPinned,
    String? messageId,
    Map<String, dynamic>? rawData,
  }) {
    return ChatMessage(
      text: text ?? this.text,
      isMe: isMe ?? this.isMe,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      type: type ?? this.type,
      voiceMessage: voiceMessage ?? this.voiceMessage,
      senderName: senderName ?? this.senderName,
      senderUid: senderUid ?? this.senderUid,
      isRead: isRead ?? this.isRead,
      isEmergency: isEmergency ?? this.isEmergency,
      isPinned: isPinned ?? this.isPinned,
      messageId: messageId ?? this.messageId,
      rawData: rawData ?? this.rawData,
    );
  }
}

// voice.MessageStatus is defined in voice_chat_extension.dart


