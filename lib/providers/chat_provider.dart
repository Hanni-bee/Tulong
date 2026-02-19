import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/bluetooth_service.dart';
import '../services/voice_chat_extension.dart' as voice;
import '../services/sqlite_service.dart';
import '../services/user_status_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/enhanced_error_handler.dart';
import '../services/notification_service.dart';
import '../widgets/modern_toast.dart';
import '../constants/storage_keys.dart';
import '../models/emergency_type.dart';
import '../utils/emergency_message_parser.dart';

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
  
  // ----- Message capture state machine (Bluetooth SPP line parser) -----
  // CAPTURE mode: after <MSG_START:uid[:msgId]> we buffer body lines until <MSG_END>.
  // Only on <MSG_END> do we append ONE chat item (and dedup by msgId).
  String _incomingMessageBuffer = '';
  String? _bufferedMessageSenderUid;
  String? _bufferedMessageMsgId;  // From <MSG_START:uid:msgId> for dedup; null if legacy <MSG_START:uid>
  bool _isBufferingMessage = false;
  Timer? _captureTimeoutTimer;    // If no <MSG_END> within ~2s, flush anyway (best-effort)
  static const Duration _captureTimeoutDuration = Duration(milliseconds: 2000);
  final Set<String> _displayedIncomingMsgIds = {};  // Dedup: do not show same msgId twice (status updates still apply to outgoing)
  /// Message IDs received while chat screen was not visible; send SEEN when user opens chat.
  final Set<String> _pendingSeenMsgIds = {};

  // Debounce: batch appends to avoid UI jitter (single append still goes through timer)
  final List<ChatMessage> _pendingIncomingMessages = [];
  final List<String?> _pendingIncomingMsgIds = [];
  Timer? _appendDebounceTimer;
  static const Duration _appendDebounceDuration = Duration(milliseconds: 80);

  void _scheduleDebouncedAppend() {
    _appendDebounceTimer?.cancel();
    _appendDebounceTimer = Timer(_appendDebounceDuration, () {
      _flushPendingAppends();
    });
  }

  void _flushPendingAppends() {
    _appendDebounceTimer?.cancel();
    if (_pendingIncomingMessages.isEmpty) return;
    final idsToSendSeen = <String>[];
    for (int i = 0; i < _pendingIncomingMessages.length; i++) {
      final msg = _pendingIncomingMessages[i];
      _messages.add(msg);
      if (!msg.isSystem) unawaited(_persistMessageToCache(msg));
      final msgId = i < _pendingIncomingMsgIds.length ? _pendingIncomingMsgIds[i] : null;
      if (msgId != null && msgId.isNotEmpty) {
        _displayedIncomingMsgIds.add(msgId);
        if (_isLocalChatScreenVisible) {
          idsToSendSeen.add(msgId);
        } else {
          _pendingSeenMsgIds.add(msgId);
        }
      }
      if (!msg.isMe) _showMessageNotification(msg, msg.senderName);
    }
    _pendingIncomingMessages.clear();
    _pendingIncomingMsgIds.clear();
    _hasCachedMessages = true;
    if (_isLoadingMessages && _messages.isNotEmpty) _isLoadingMessages = false;
    notifyListeners();
    // SEEN only when chat screen is visible and after UI has rendered (receiver phone drives SEEN)
    if (idsToSendSeen.isNotEmpty) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        for (final id in idsToSendSeen) _sendSeenToEsp32(id);
      });
    }
  }

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
      // Send SEEN for messages that were received while chat was not visible (now displayed)
      if (_pendingSeenMsgIds.isNotEmpty) {
        final toSend = _pendingSeenMsgIds.toList();
        _pendingSeenMsgIds.clear();
        SchedulerBinding.instance.addPostFrameCallback((_) {
          for (final id in toSend) _sendSeenToEsp32(id);
        });
      }
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
  StreamSubscription<bool>? _playingSubscription;
  
  // Track currently playing voice message ID
  String? _currentlyPlayingVoiceMessageId;
  String? get currentlyPlayingVoiceMessageId => _currentlyPlayingVoiceMessageId;
  
  // Check if a specific voice message is currently playing
  bool isVoiceMessagePlaying(String voiceMessageId) {
    return _currentlyPlayingVoiceMessageId == voiceMessageId && isPlaying;
  }

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
      final trimmed = message.trim();
      if (trimmed.isEmpty) return;
      print('BT_RX_LINE: $trimmed');
      // JSON status events (msg_sent, msg_retry, msg_seen, msg_timeout) must NOT create chat items
      try {
        final jsonData = json.decode(trimmed);
        if (jsonData is Map<String, dynamic>) {
          final cmd = jsonData['command']?.toString() ?? '';
          if (cmd == 'msg_sent' || cmd == 'msg_retry' || cmd == 'msg_seen' || cmd == 'msg_timeout') {
            _handleJsonStatusEvent(cmd, jsonData);
            return;
          }
          _processIncomingMapMessage(jsonData);
          return;
        }
      } catch (e) {
        // Not JSON, process as regular string message
      }
      _processIncomingMessage(trimmed).catchError((error) {
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
    
    // Listen to voice playback completion to clear currently playing ID
    _playingSubscription = _voiceExtension.playingStream.listen((isPlaying) {
      if (!isPlaying) {
        _currentlyPlayingVoiceMessageId = null;
        notifyListeners();
      }
    });

    // Load message cache from SQLite on startup so pinned history survives app kill
    unawaited(_loadCachedMessages());
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
      // On refresh, reload from SQLite for current channel so list is backed by full retention
      if (forceRefresh) {
        await _loadCachedMessages();
      }
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
  
  /// Load cached messages from SQLite from all channels, merged by timestamp.
  /// Retains full chat UI: everything that was on screen (all channels + channel notifs).
  Future<void> _loadCachedMessages() async {
    try {
      final sqlite = SQLiteService();
      final rows = await sqlite.getMessagesFromAllChannels();
      final List<ChatMessage> loaded = [];
      for (final row in rows) {
        final isMe = (row['sender_id']?.toString() ?? '') == 'me' ||
            (row['sender_id']?.toString() ?? '').isEmpty;
        final rowType = row['type']?.toString() ?? row['message_type']?.toString() ?? 'text';
        final timestamp = DateTime.fromMillisecondsSinceEpoch(
          (row['timestamp'] as int?) ?? 0,
        );
        if (rowType == 'system') {
          loaded.add(ChatMessage(
            text: row['message']?.toString() ?? '',
            isMe: false,
            timestamp: timestamp,
            status: voice.MessageStatus.delivered,
            type: voice.MessageType.text,
            isSystem: true,
            isRead: true,
          ));
          continue;
        }
        final isPinned = (row['is_pinned'] as int?) == 1;
        final severityLevelStr = row['severity_level']?.toString();
        final emergencyTypeStr = row['emergency_type']?.toString();
        final SeverityLevel? severityLevel = severityLevelStr != null && severityLevelStr.isNotEmpty
            ? SeverityLevel.fromString(severityLevelStr)
            : null;
        final EmergencyType? emergencyType = emergencyTypeStr != null && emergencyTypeStr.isNotEmpty
            ? EmergencyType.fromString(emergencyTypeStr)
            : null;
        final isEmergency = rowType == 'SOS' || rowType == 'AI';

        if (rowType == 'voice') {
          final voicePath = row['voice_file_path']?.toString();
          if (voicePath != null && voicePath.isNotEmpty) {
            final file = File(voicePath);
            if (await file.exists()) {
              final bytes = await file.readAsBytes();
              final base64Audio = base64Encode(bytes);
              final vm = voice.VoiceMessage.fromBase64(
                base64Audio: base64Audio,
                isMe: isMe,
                status: voice.MessageStatus.delivered,
              );
              loaded.add(ChatMessage(
                text: '🎤 Voice message',
                isMe: isMe,
                timestamp: timestamp,
                status: voice.MessageStatus.delivered,
                type: voice.MessageType.voice,
                voiceMessage: vm,
                senderName: isMe ? null : (row['sender_name']?.toString()),
                isRead: true,
              ));
            }
          }
        } else {
          loaded.add(ChatMessage(
            text: row['message']?.toString() ?? '',
            isMe: isMe,
            timestamp: timestamp,
            status: voice.MessageStatus.delivered,
            type: voice.MessageType.text,
            senderName: isMe ? null : (row['sender_name']?.toString()),
            senderUid: isMe ? null : (row['sender_id']?.toString()),
            isEmergency: isEmergency,
            isPinned: isPinned,
            severityLevel: severityLevel,
            emergencyType: emergencyType,
            isRead: true,
          ));
        }
      }
      _messages.clear();
      _messages.addAll(loaded);
      _hasCachedMessages = _messages.isNotEmpty;
      if (loaded.isNotEmpty) _isLoadingMessages = false;
      notifyListeners();
    } catch (e) {
      print('Error loading cached messages: $e');
    }
  }

  /// Persist a single message to SQLite cache (write-through). Includes system messages (channel notif).
  /// Stores type (text/voice/SOS/AI/system) for full local retention of everything on chat UI.
  Future<void> _persistMessageToCache(ChatMessage msg, {String? voiceFilePath}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final channelIndex = prefs.getInt(_rfChannelPrefKey) ?? 0;
      final channelNum = (channelIndex + 1).clamp(1, 5);
      final chatId = 'local_channel_$channelNum';
      String rowType;
      String senderId;
      String senderName;
      String messageType;
      if (msg.isSystem) {
        rowType = 'system';
        senderId = 'system';
        senderName = '';
        messageType = 'text';
      } else {
        senderId = msg.isMe ? 'me' : (msg.senderUid ?? msg.senderName ?? '');
        senderName = msg.isMe ? (_currentUserName ?? 'Me') : (msg.senderName ?? '');
        messageType = msg.type == voice.MessageType.voice ? 'voice' : 'text';
        if (msg.type == voice.MessageType.voice) {
          rowType = 'voice';
        } else if (msg.emergencyType != null) {
          rowType = 'AI';
        } else if (msg.isEmergency) {
          rowType = 'SOS';
        } else {
          rowType = 'text';
        }
      }
      final data = <String, dynamic>{
        'chat_id': chatId,
        'message': msg.text,
        'sender_id': senderId,
        'sender_name': senderName,
        'timestamp': msg.timestamp.millisecondsSinceEpoch,
        'message_type': messageType,
        'channel': channelNum,
        'type': rowType,
        'is_pinned': msg.isPinned ? 1 : 0,
      };
      if (!msg.isSystem) {
        data['severity_level'] = msg.severityLevel?.name;
        data['emergency_type'] = msg.emergencyType?.name;
      }
      if (voiceFilePath != null && voiceFilePath.isNotEmpty) {
        data['voice_file_path'] = voiceFilePath;
      }
      await SQLiteService().insertMessage(data);
    } catch (e) {
      print('Error persisting message to cache: $e');
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

  /// SharedPreferences key for RF channel index (0-4). Must match modern_home_screen.dart.
  static const String _rfChannelPrefKey = 'rf_channel_index';

  /// Send RF channel to ESP32 (only when connected). Call when user selects Channel 1–5 (RF 108, 100, 104, 112, 120).
  Future<void> setRfChannel(int rfChannelValue) async {
    if (!_bluetoothService.isConnected) return;
    try {
      final payload = '${jsonEncode({'command': 'set_rf_channel', 'rf_channel': rfChannelValue})}\n';
      await _bluetoothService.sendMessage(payload);
    } catch (e) {
      print('Error sending set_rf_channel: $e');
    }
  }

  /// Add a local-only system message to the chat (e.g. "You are now in Channel X"). Call when user switches RF channel.
  void addChannelSwitchNotification(int channelNumber) {
    final msg = ChatMessage(
      text: 'You are now in Channel $channelNumber',
      isMe: false,
      timestamp: DateTime.now(),
      status: voice.MessageStatus.delivered,
      type: voice.MessageType.text,
      isSystem: true,
    );
    _messages.add(msg);
    _hasCachedMessages = true;
    unawaited(_persistMessageToCache(msg));
    notifyListeners();
  }

  Future<bool> sendMessage(
    String text, {
    BuildContext? context,
    SeverityLevel? severityLevel,
    EmergencyType? emergencyType,
  }) async {
    if (text.trim().isEmpty) return false;

    if (severityLevel != null || emergencyType != null) {
      addStructuredDebug({
        'source': 'CHAT',
        'event': 'Sending severity message',
        'metrics': {
          'severity': severityLevel?.name,
          'emergencyType': emergencyType?.name,
          'textLength': text.length,
        },
      });
    }

    ChatMessage message = ChatMessage(
      text: text.trim(),
      isMe: true,
      timestamp: DateTime.now(),
      status: voice.MessageStatus.sending,
      type: voice.MessageType.text,
      severityLevel: severityLevel,
      emergencyType: emergencyType,
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

      final success = await _bluetoothService.sendMessage(text);
      if (!success) {
        message.status = voice.MessageStatus.failed;
        if (context != null) {
          ModernToastManager.show(
            context,
            message: 'Message failed to send. Please try again.',
            type: ToastType.error,
          );
        }
        notifyListeners();
      }
      // On success: leave status as sending; ESP32 will send msg_sent with message_id and we update then
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

  /// Handle JSON status events from ESP32. Do NOT create chat items; only update existing outgoing message status.
  /// msg_sent -> set messageId on last sending message and status "Sent (pending seen)"; msg_retry -> keep Sending, log only; msg_seen -> "Seen"; msg_timeout -> "Unconfirmed".
  void _handleJsonStatusEvent(String command, Map<String, dynamic> data) {
    final messageId = data['message_id']?.toString();
    if (messageId == null || messageId.isEmpty) return;

    if (command == 'msg_sent') {
      _assignMessageIdToLastSendingAndSetStatus(messageId, voice.MessageStatus.sent);
      return;
    }
    if (command == 'msg_retry') {
      final count = data['count'];
      // Keep "Sending…"; log retry count in debug only (do not spam UI)
      addStructuredDebug({
        'source': 'CHAT',
        'event': 'msg_retry',
        'metrics': {'message_id': messageId, 'count': count},
      });
      return;
    }
    if (command == 'msg_seen') {
      _updateOutgoingStatusByMessageId(messageId, voice.MessageStatus.received);
      return;
    }
    if (command == 'msg_timeout') {
      _updateOutgoingStatusByMessageId(messageId, voice.MessageStatus.unconfirmed);
      return;
    }
  }

  void _assignMessageIdToLastSendingAndSetStatus(String messageId, voice.MessageStatus status) {
    for (int i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (m.isMe && m.status == voice.MessageStatus.sending) {
        _messages[i] = m.copyWith(messageId: messageId, status: status);
        notifyListeners();
        return;
      }
    }
  }

  void _updateOutgoingStatusByMessageId(String messageId, voice.MessageStatus status) {
    final idx = _messages.indexWhere((m) => m.isMe && m.messageId == messageId);
    if (idx == -1) return;
    _messages[idx] = _messages[idx].copyWith(status: status);
    notifyListeners();
  }

  /// Send SEEN to ESP32 so it can forward over RF and stop sender retry. Called only after message is displayed (post-frame).
  /// Sends exactly: {"command":"send_seen","message_id":"<rfMsgId>"}\n
  void _sendSeenToEsp32(String rfMsgId) {
    if (rfMsgId.isEmpty) return;
    if (!_bluetoothService.isConnected) return;
    try {
      final payload = '${jsonEncode({'command': 'send_seen', 'message_id': rfMsgId})}\n';
      _bluetoothService.sendMessage(payload);
      print('BT_SEEN: send_seen message_id=$rfMsgId');
    } catch (e) {
      print('BT_SEEN: Error sending send_seen: $e');
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
      
      // If message has emergency_detection metadata (from Emergency Detection page), pass type/severity so UI shows "From Emergency Detection"
      SeverityLevel? severityLevel;
      EmergencyType? emergencyType;
      final detection = EmergencyMessageParser.parseFromMessageData(rawDataWithSource);
      if (detection != null) {
        severityLevel = detection.severity;
        emergencyType = detection.type;
      }
      
      // Add message with emergency flag and rawData (and optional detection metadata for badge)
      _addMessage(messageText, false, senderName: senderName, isEmergency: isEmergency, rawData: rawDataWithSource, severityLevel: severityLevel, emergencyType: emergencyType);
      
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

  /// Process incoming message and handle voice messages.
  /// State machine: IDLE | CAPTURE (buffering body until <MSG_END>). Only append ONE chat item on <MSG_END>; never append partial chunks.
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
        final base64Audio = message.substring(14);
        if (base64Audio.isEmpty) {
          addStructuredDebug({'source': 'CHAT', 'event': 'Voice message rejected - empty data', 'metrics': {}});
          continue;
        }
        if (!_isValidBase64(base64Audio)) {
          addStructuredDebug({'source': 'CHAT', 'event': 'Voice message rejected - invalid Base64', 'metrics': {'length': base64Audio.length}});
          continue;
        }
        addStructuredDebug({'source': 'CHAT', 'event': 'Creating voice message', 'metrics': {'base64Length': base64Audio.length}});
        String? senderName;
        _addVoiceMessage(base64Audio, false, senderName: senderName);
        _processQueuedProfileRequests();
      } else if (message.startsWith('<VOICE_START>') || message.startsWith('<VOICE_END>')) {
        continue;
      } else if (message.startsWith('<MSG_START:')) {
        await _flushBufferedMessage();
        _captureTimeoutTimer?.cancel();
        // Parse <MSG_START:uid:msgId> (preferred) or <MSG_START:uid> or <MSG_START:uidSOS>
        final closeBracket = message.indexOf('>');
        if (closeBracket > 0) {
          final inside = message.substring(11, closeBracket).trim();
          final lastColon = inside.lastIndexOf(':');
          if (lastColon >= 0) {
            _bufferedMessageSenderUid = inside.substring(0, lastColon).trim();
            final afterColon = inside.substring(lastColon + 1).trim();
            _bufferedMessageMsgId = afterColon.isEmpty ? null : afterColon;
          } else {
            _bufferedMessageSenderUid = inside;
            _bufferedMessageMsgId = null;
          }
        } else {
          _bufferedMessageSenderUid = 'UNKNOWN';
          _bufferedMessageMsgId = null;
        }
        _incomingMessageBuffer = '';
        _isBufferingMessage = true;
        print('BT_RX: Message start UID=${_bufferedMessageSenderUid} msgId=${_bufferedMessageMsgId}');
        _captureTimeoutTimer = Timer(_captureTimeoutDuration, () {
          if (_isBufferingMessage) {
            print('BT_RX: Capture timeout - flushing buffer');
            _flushBufferedMessage();
          }
        });
        if (_bufferedMessageSenderUid != null && _bufferedMessageSenderUid != 'UNKNOWN' && !_voiceExtension.isVoiceActive) {
          _isUidKnown(_bufferedMessageSenderUid!).then((isKnown) {
            if (!isKnown) {
              print('BT_PROFILE: Unknown UID detected: ${_bufferedMessageSenderUid} - Requesting profile');
              _requestProfileFromESP32(_bufferedMessageSenderUid!);
            }
          });
        }
        addStructuredDebug({'source': 'CHAT', 'event': 'Message buffering started', 'metrics': {'uid': _bufferedMessageSenderUid, 'msgId': _bufferedMessageMsgId}});
        continue;
      } else if (message == '<MSG_END>') {
        _captureTimeoutTimer?.cancel();
        _captureTimeoutTimer = null;
        await _flushBufferedMessage();
        continue;
      } else if (_isBufferingMessage) {
        if (_incomingMessageBuffer.isNotEmpty) _incomingMessageBuffer += '\n';
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
        
        // Regular text message - try to extract user info and optional Emergency Detection metadata
        String? extractedSender = _extractUserFromMessage(message);
        SeverityLevel? severityLevel;
        EmergencyType? emergencyType;
        if (EmergencyMessageParser.isEmergencyMessage(message)) {
          final detection = EmergencyMessageParser.parseFromMessage(message);
          if (detection != null) {
            severityLevel = detection.severity;
            emergencyType = detection.type;
          }
        }
        _addMessage(message, false, senderName: extractedSender, severityLevel: severityLevel, emergencyType: emergencyType);
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

  /// Send SOS over ESP32 (same RF frame as hardware button). Use when connected via BluetoothService.
  /// Call from home screen after long-press + confirmation.
  Future<void> sendSosAlert({
    required String message,
    required String severity,
    required int timestampMs,
  }) async {
    if (!_bluetoothService.isConnected) {
      print('BT_SOS: Cannot send SOS: Not connected');
      return;
    }
    try {
      final payload = jsonEncode({
        'command': 'send_sos',
        'message': message,
        'severity': severity,
        'timestamp_ms': timestampMs,
      });
      await _bluetoothService.sendMessage(payload);
      _addMessage(message, true, isEmergency: true);
      addStructuredDebug({
        'source': 'CHAT',
        'event': 'SOS alert sent (same format as ESP32 button)',
        'metrics': {'len': message.length},
      });
    } catch (e) {
      print('BT_SOS: Error sending SOS: $e');
      rethrow;
    }
  }

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

  /// Flush buffered message and display it. Dedup by msgId; append via debounced list so only ONE chat item is added.
  Future<void> _flushBufferedMessage() async {
    if (!_isBufferingMessage || _incomingMessageBuffer.isEmpty) {
      _isBufferingMessage = false;
      _incomingMessageBuffer = '';
      _bufferedMessageSenderUid = null;
      _bufferedMessageMsgId = null;
      return;
    }

    final msgIdForDedup = _bufferedMessageMsgId;

    // Clean the message buffer - remove any MSG_END tags and header so header never appears in UI
    String completeMessage = _incomingMessageBuffer
        .replaceAll('<MSG_END>', '')
        .replaceAll('&lt;MSG_END&gt;', '')
        .replaceFirst(RegExp(r'<MSG_START:[^>]*>'), '') // strip header if it leaked into body
        .trim();
    final senderUid = _bufferedMessageSenderUid;

    // Clear buffer and capture state
    _incomingMessageBuffer = '';
    _bufferedMessageSenderUid = null;
    _bufferedMessageMsgId = null;
    _isBufferingMessage = false;

    // Dedup: if we already displayed this msgId, do not append duplicate — send SEEN only when chat is visible
    if (msgIdForDedup != null && msgIdForDedup.isNotEmpty && _displayedIncomingMsgIds.contains(msgIdForDedup)) {
      print('BT_RX: Dedup skip msgId=$msgIdForDedup');
      if (_isLocalChatScreenVisible) {
        SchedulerBinding.instance.addPostFrameCallback((_) => _sendSeenToEsp32(msgIdForDedup!));
      } else {
        _pendingSeenMsgIds.add(msgIdForDedup!);
      }
      return;
    }
    if (completeMessage.isEmpty) return;
    
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

    // Parse emergency detection from message body so receiver gets same metadata as sender (severity, type, styling)
    SeverityLevel? severityLevel;
    EmergencyType? emergencyType;
    bool isEmergencyFromDetection = false;
    if (EmergencyMessageParser.isEmergencyMessage(completeMessage)) {
      final detection = EmergencyMessageParser.parseFromMessage(completeMessage);
      if (detection != null) {
        severityLevel = detection.severity;
        emergencyType = detection.type;
        isEmergencyFromDetection = true;
      }
    }

    // Store RF msgId on ChatMessage for normal chat; SOS/legacy without msgId use null (do not generate local IDs for SEEN)
    final chatMsg = ChatMessage(
      text: completeMessage,
      isMe: false,
      timestamp: DateTime.now(),
      status: voice.MessageStatus.delivered,
      type: voice.MessageType.text,
      senderName: displayName,
      senderUid: actualUid,
      isRead: _isLocalChatScreenVisible,
      isEmergency: isSosFromHardware || isEmergencyFromDetection,
      isPinned: isSosFromHardware,
      messageId: isSosFromHardware ? null : msgIdForDedup,
      rawData: rawDataForHardwareSos,
      severityLevel: severityLevel,
      emergencyType: emergencyType,
    );
    _pendingIncomingMessages.add(chatMsg);
    _pendingIncomingMsgIds.add(msgIdForDedup);
    _scheduleDebouncedAppend();

    print('BT_RX: Complete message queued (${completeMessage.length} chars) from UID: $senderUid, Name: $senderName');
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
    // Persist voice to cache: save base64 to file then persist row with path
    unawaited(_saveVoiceToCache(chatMessage));
  }

  /// Save voice message to app storage and persist row to SQLite (path in voice_file_path).
  Future<void> _saveVoiceToCache(ChatMessage chatMessage) async {
    if (chatMessage.voiceMessage == null) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final voiceDir = Directory(path.join(dir.path, 'voice_messages'));
      if (!await voiceDir.exists()) await voiceDir.create(recursive: true);
      final name = 'voice_${chatMessage.timestamp.millisecondsSinceEpoch}.aac';
      final filePath = path.join(voiceDir.path, name);
      final bytes = base64Decode(chatMessage.voiceMessage!.base64Audio);
      await File(filePath).writeAsBytes(bytes);
      await _persistMessageToCache(chatMessage, voiceFilePath: filePath);
    } catch (e) {
      print('Error saving voice to cache: $e');
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
      text: '🎤 Voice message',
      isMe: true,
      timestamp: DateTime.now(),
      status: voice.MessageStatus.sending,
      type: voice.MessageType.voice,
      voiceMessage: voiceMessage,
    );

    _messages.add(chatMessage);
    notifyListeners();
    unawaited(_persistMessageToCache(chatMessage, voiceFilePath: recordingPath));

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
    // Stop any currently playing message first
    if (_currentlyPlayingVoiceMessageId != null && isPlaying) {
      await stopPlayback();
    }
    
    // Set the currently playing voice message ID
    _currentlyPlayingVoiceMessageId = voiceMessage.id;
    
    final success = await _voiceExtension.playVoiceMessage(voiceMessage.base64Audio);
    
    if (!success) {
      _currentlyPlayingVoiceMessageId = null;
    }
    
    notifyListeners();
    return success;
  }

  /// Stop current playback
  Future<void> stopPlayback() async {
    await _voiceExtension.stopPlayback();
    _currentlyPlayingVoiceMessageId = null;
    notifyListeners();
  }

  void _addMessage(String text, bool isMe, {
    String? senderName,
    String? senderUid,
    ChatMessage? message,
    bool isEmergency = false,
    Map<String, dynamic>? rawData,
    SeverityLevel? severityLevel,
    EmergencyType? emergencyType,
  }) {
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
        isPinned: isEmergency && !isMe, // Auto-pin emergency messages ONLY for received messages (not sender's own messages)
        messageId: messageId, // Unique ID for unpinning
        rawData: rawData, // Store raw data for source detection
        severityLevel: severityLevel, // From Emergency Detection (AI) so receivers see "From Emergency Detection"
        emergencyType: emergencyType,
      );
    } else if (!isMe && (senderName != null || senderUid != null)) {
      // Update sender name/UID if provided; only mark as read if screen is visible and message wasn't already read
      message = message.copyWith(
        senderName: senderName ?? message.senderName,
        senderUid: senderUid ?? message.senderUid,
        isRead: message.isRead || (_isLocalChatScreenVisible && !message.isRead),
      );
    } else if (!message.isMe) {
      // For existing incoming messages, only mark as read if screen is visible AND message wasn't already read
      message = message.copyWith(
        isRead: message.isRead || (_isLocalChatScreenVisible && !message.isRead),
      );
    }
    
    // Add message to list (real-time from ESP32)
    _messages.add(message);
    
    // Persist to SQLite cache (write-through); skip system messages
    if (!message.isSystem) {
      unawaited(_persistMessageToCache(message));
    }
    
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
      // Check notification settings (emergency/SOS use emergency setting for their types)
      final prefs = await SharedPreferences.getInstance();
      final messageNotificationsEnabled = prefs.getBool('notification_messages') ?? true;
      final emergencyNotificationsEnabled = prefs.getBool('notification_emergency') ?? true;
      
      // Get current user to avoid notifying for own messages
      final currentUserEmail = prefs.getString('user_email') ?? '';
      final currentUserName = prefs.getString('user_name') ?? '';
      
      if (senderName == currentUserName || senderName == currentUserEmail) {
        return;
      }
      
      final displayName = senderName ?? 'Unknown User';
      final messageText = message.text;
      final stableId = NotificationService.stableNotificationId(
        message.messageId ?? '${displayName}_${message.timestamp.millisecondsSinceEpoch}',
      );
      
      // Emergency from Emergency Detection (scan) – distinct styling
      if (message.emergencyType != null && message.emergencyType!.isRealEmergency) {
        if (!emergencyNotificationsEnabled) return;
        final title = 'Emergency: ${message.emergencyType!.label}';
        await NotificationService().showEmergencyAlert(
          title: title,
          body: messageText,
          stableId: stableId,
          payload: jsonEncode({
            'type': 'emergency',
            'chatType': 'local',
            'senderName': displayName,
            'message': messageText,
            'emergencyType': message.emergencyType!.name,
            'timestamp': message.timestamp.toIso8601String(),
          }),
        );
        return;
      }
      
      // SOS (hardware/home hold-to-send) – distinct styling
      if (message.isEmergency) {
        if (!emergencyNotificationsEnabled) return;
        await NotificationService().showSosNotification(
          title: 'SOS Alert',
          body: messageText,
          stableId: stableId,
          payload: jsonEncode({
            'type': 'sos',
            'chatType': 'local',
            'senderName': displayName,
            'message': messageText,
            'timestamp': message.timestamp.toIso8601String(),
          }),
        );
        return;
      }
      
      // Normal chat message
      if (!messageNotificationsEnabled) return;
      if (message.type == voice.MessageType.voice && message.voiceMessage != null) {
        await NotificationService().showMessageNotification(
          sender: displayName,
          message: 'Voice message',
          stableId: stableId,
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
          stableId: stableId,
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

      // Retrieve AI severity and timestamp (same keys as detection pipeline)
      final severity = prefs.getString(StorageKeys.userCurrentStatus)?.trim();
      final timestampMs = prefs.getInt(StorageKeys.userStatusLastUpdated);
      final severityValue = (severity != null && severity.isNotEmpty)
          ? severity.toUpperCase()
          : 'LOW';
      final timestampValue = (timestampMs != null && timestampMs > 0)
          ? timestampMs
          : DateTime.now().millisecondsSinceEpoch;

      final sosJson = jsonEncode({
        "command": "sync_sos",
        "message": sosMessage,
        "severity": severityValue,
        "timestamp_ms": timestampValue,
      });

      print('BT_SYNC: Sending SOS message (severity=$severityValue, timestamp_ms=$timestampValue): $sosJson');
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

        // Derive severity/timestamp for test payloads (same rules as real sync)
        String severity = 'noEmergency';
        int timestampMs = DateTime.now().millisecondsSinceEpoch;
        try {
          final status = await UserStatusService.instance.getCurrentStatus();
          if (status != null) {
            severity = (status['severity'] as String?) ?? severity;
            final ts = status['last_updated_timestamp'] as int?;
            if (ts != null && ts > 0) {
              timestampMs = ts;
            }
          }
        } catch (e) {
          print('BT_SYNC: Error deriving status for TEST payloads: $e');
        }

        // Send test profile data
        final testProfileJson = jsonEncode({
          "command": "sync_profile",
          "name": "TEST USER",
          "username": "test",
          "uid": "",
          "suffix": "",
          "street": "123",
          "province": "NCR",
          "city": "Manila",
          "barangay": "1",
          "severity": severity,
          "timestamp_ms": timestampMs,
        });

        print('BT_SYNC: Sending TEST profile data: $testProfileJson');
        await _bluetoothService.sendMessage(testProfileJson);
        print('BT_SYNC: TEST profile data sent successfully');

        // Send test SOS message
        final testSosJson = jsonEncode({
          "command": "sync_sos",
          "message": "TEST SOS",
          "severity": severity,
          "timestamp_ms": timestampMs,
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

      // Derive severity + timestamp_ms from current user status:
      // - severity: prefer SharedPreferences user_current_status (via UserStatusService)
      // - timestamp_ms: prefer latest detection timestamp; fallback to now
      String severity = 'noEmergency';
      int timestampMs = DateTime.now().millisecondsSinceEpoch;
      try {
        final status = await UserStatusService.instance.getCurrentStatus();
        if (status != null) {
          severity = (status['severity'] as String?) ?? severity;
          final ts = status['last_updated_timestamp'] as int?;
          if (ts != null && ts > 0) {
            timestampMs = ts;
          }
        }
      } catch (e) {
        print('BT_SYNC: Error deriving status for profile/SOS sync: $e');
      }

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
        "severity": severity,
        "timestamp_ms": timestampMs,
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
        "severity": severity,
        "timestamp_ms": timestampMs,
      });

      print('BT_SYNC: Sending SOS message (severity=$severity, timestamp_ms=$timestampMs): $sosJson');
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
    _playingSubscription?.cancel();
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
  final SeverityLevel? severityLevel; // Severity level for AI-detected emergencies (for unique UI styling)
  final EmergencyType? emergencyType; // Emergency type for AI-detected emergencies
  final bool isSystem; // Local-only system line (e.g. "You are now in Channel X")

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
    this.rawData, // Raw data for message (e.g., for SOS source)
    this.severityLevel, // Severity level for styling
    this.emergencyType, // Emergency type
    this.isSystem = false, // Default to false for normal messages
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
    SeverityLevel? severityLevel,
    EmergencyType? emergencyType,
    bool? isSystem,
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
      severityLevel: severityLevel ?? this.severityLevel,
      emergencyType: emergencyType ?? this.emergencyType,
      isSystem: isSystem ?? this.isSystem,
    );
  }
}

// voice.MessageStatus is defined in voice_chat_extension.dart


