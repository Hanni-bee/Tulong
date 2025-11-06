import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../constants/soft_ui_design.dart';
import '../services/simple_bluetooth_service.dart';
import '../controllers/voice_controller.dart';
import '../widgets/unified_top_bar.dart';
import '../widgets/special_animations.dart';
import '../widgets/bluetooth_radar_modal.dart';
import '../widgets/connected_users_modal.dart';

/// ESP32 LoRa Chat Screen - Ultra Simple Version
/// No animations, no pop-ups, no complex status tracking
class ESP32LoRaChatScreen extends StatefulWidget {
  const ESP32LoRaChatScreen({super.key});

  @override
  State<ESP32LoRaChatScreen> createState() => _ESP32LoRaChatScreenState();
}

class _ESP32LoRaChatScreenState extends State<ESP32LoRaChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _messages = [];
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _messagesListSubscription;
  StreamSubscription<Map<String, dynamic>>? _voiceFrameSubscription;
  
  bool _isSending = false;
  bool _isRecording = false;
  bool _isPlaying = false;
  
  late VoiceController _voiceController;

  @override
  void initState() {
    super.initState();
    _voiceController = VoiceController();
    _initializeESP32Service();
    _setupMessageStreams();
    _setupVoiceStreams();
  }

  void _initializeESP32Service() async {
    final esp32Service = Provider.of<SimpleBluetoothService>(context, listen: false);
    await esp32Service.initialize();
    
    if (!esp32Service.isConnected) {
      await esp32Service.connectToESP32();
    }
    
    // Initialize voice controller
    await _voiceController.initialize();
  }

  void _setupMessageStreams() {
    final esp32Service = Provider.of<SimpleBluetoothService>(context, listen: false);
    
    // Listen for incoming messages
    _messageSubscription = esp32Service.messageStream.listen((message) {
      _handleIncomingMessage(message);
      
      // Handle voice messages from ESP32
      if (message['type'] == 'voice_message') {
        _voiceController.handleVoiceMessage(message);
      }
    });
    
    // Listen to the canonical message list from the service
    _messagesListSubscription = esp32Service.messagesStream.listen((list) {
      setState(() {
        _messages = list;
      });
      _scrollToBottom();
    });
  }

  void _setupVoiceStreams() {
    // Listen for voice frames from voice controller
    _voiceFrameSubscription = _voiceController.voiceFrameStream.listen((frame) {
      _sendVoiceFrame(frame);
    });
    
    // Listen for recording state
    _voiceController.recordingStream.listen((recording) {
      setState(() {
        _isRecording = recording;
      });
      
      // Send V2 protocol markers
      final esp32Service = Provider.of<SimpleBluetoothService>(context, listen: false);
      if (recording) {
        // Send <VOICE_START> when recording starts
        esp32Service.sendRawMessage('<VOICE_START>');
      } else {
        // Send <VOICE_END> when recording stops
        esp32Service.sendRawMessage('<VOICE_END>');
      }
    });
    
    // Listen for playing state
    _voiceController.playingStream.listen((playing) {
      setState(() {
        _isPlaying = playing;
      });
    });
    
    // Listen for voice errors
    _voiceController.errorStream.listen((error) {
      _showSimpleMessage('Voice error: $error');
    });
  }

  void _handleIncomingMessage(Map<String, dynamic> message) {
    // Check if it's a voice message
    if (message['type'] == 'voice_message' && message['data_b64_pcm16le'] != null) {
      final String base64Data = message['data_b64_pcm16le'];
      
      // Play the voice message
      _voiceController.playBase64Pcm(base64Data);
      
      // Also display it in chat UI
      message['isLocal'] = false;
      message['message'] = '🎤 Voice message';  // Display text for voice
      setState(() {
        _messages.add(message);
      });
      _scrollToBottom();
      return;
    }
    
    // Regular text message
    message['isLocal'] = false;
    setState(() {
      _messages.add(message);
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  void _sendVoiceFrame(Map<String, dynamic> frame) {
    final esp32Service = Provider.of<SimpleBluetoothService>(context, listen: false);
    
    if (!esp32Service.isConnected) {
      _showSimpleMessage('Not connected to ESP32');
      return;
    }
    
    // Send voice frame via ESP32 service - ESP32 compatible format
    final Map<String, dynamic> voiceMessage = {
      'messageId': frame['messageId'],
      'pcm16leb64': frame['pcm16leb64'],  // Direct ESP32 format
    };
    
    // Send via the existing Bluetooth service
    esp32Service.sendMessage(voiceMessage);
  }

  void _startPTT() {
    _voiceController.startPTT();
    HapticFeedback.mediumImpact();
  }

  void _stopPTT() {
    _voiceController.stopPTT();
    HapticFeedback.lightImpact();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;
    
    final esp32Service = Provider.of<SimpleBluetoothService>(context, listen: false);
    
    if (!esp32Service.isConnected) {
      _showSimpleMessage('Not connected to ESP32');
      return;
    }
    
    if (!esp32Service.isAuthenticated) {
      _showSimpleMessage('Authenticating...');
      return;
    }
    
    setState(() => _isSending = true);
    
    try {
      // Add message to local list immediately
      final localMessage = {
        'type': 'group',
        'sender_name': esp32Service.userName,
        'sender_id': esp32Service.esp32NodeId,
        'receiver_id': 'all',
        'message': message,
        'timestamp': DateTime.now().toString(),
        'isLocal': true,
      };
      
      setState(() {
        _messages.add(localMessage);
      });
      
      _messageController.clear();
      _scrollToBottom();
      
      // Send via ESP32
      await esp32Service.sendGroupMessage(message);
      
    } catch (e) {
      _showSimpleMessage('Failed to send: $e');
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _showSimpleMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Unified top bar
            Consumer<SimpleBluetoothService>(
              builder: (context, esp32Service, child) {
                return TopBarConfigs.loraTopBar(
                  status: esp32Service.isConnected ? 'Connected' : 'Disconnected',
                  onBluetoothTap: () {
                    // Bluetooth icon - ESP32 Device Scanner Modal (list of devices to connect)
                    showDialog(
                      context: context,
                      barrierDismissible: true,
                      barrierColor: Colors.black54,
                      builder: (context) => const ConnectedUsersModal(),
                    );
                  },
                  onConnectedTap: () {
                    // Connected status badge - Radar Modal (shows connected users from chat)
                    if (esp32Service.isConnected) {
                      showDialog(
                        context: context,
                        barrierDismissible: true,
                        barrierColor: Colors.black54,
                        builder: (context) => const BluetoothRadarModal(),
                      );
                    } else {
                      // If not connected, show message
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please connect to an ESP32 device first'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                );
              },
            ),
            // Accent line handled by UnifiedTopBar; remove local duplicate
            
            Expanded(child: _buildMessagesList()),
            _buildSimpleMessageInput(),
          ],
        ),
      ),
    );
  }


  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
      return EmptyStateEntrance(
        iconWidget: Icon(
          Icons.chat_bubble_outline,
          size: 64,
          color: AppColors.lightGray,
        ),
        textWidget: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No messages yet',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.mediumGray,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a conversation using ESP32 LoRa!',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.lightGray,
              ),
            ),
          ],
        ),
        accentColor: AppColors.online,
      );
    }
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        return _buildSimpleMessageBubble(_messages[index]);
      },
    );
  }

  Widget _buildSimpleMessageBubble(Map<String, dynamic> message) {
    final isLocal = message['isLocal'] == true;
    final senderName = message['sender_name'] ?? 'Unknown';
    final messageText = message['message'] ?? '';
    final timestamp = message['timestamp'] ?? '';
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isLocal ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isLocal) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryRed.withOpacity(0.1),
              child: Text(
                senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.primaryRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isLocal ? AppColors.primaryRed : Colors.white,
                borderRadius: BorderRadius.circular(20).copyWith(
                  bottomLeft: isLocal ? const Radius.circular(20) : const Radius.circular(4),
                  bottomRight: isLocal ? const Radius.circular(4) : const Radius.circular(20),
                ),
                border: Border.all(
                  color: isLocal 
                      ? Colors.white.withOpacity(0.2)
                      : AppColors.lightGray.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isLocal)
                    Text(
                      senderName,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.mediumGray,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (!isLocal) const SizedBox(height: 4),
                  Text(
                    messageText,
                    style: AppTypography.bodyMedium.copyWith(
                      color: isLocal ? Colors.white : AppColors.darkGray,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(timestamp),
                    style: AppTypography.bodySmall.copyWith(
                      color: isLocal ? Colors.white70 : AppColors.lightGray,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isLocal) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryRed.withOpacity(0.1),
              child: Text(
                'Me',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.primaryRed,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inMinutes < 1) {
        return 'now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h';
      } else {
        return '${dateTime.day}/${dateTime.month}';
      }
    } catch (e) {
      return 'now';
    }
  }

  Widget _buildSimpleMessageInput() {
    return Container(
      decoration: SoftUIDesign.cardDecoration(
        backgroundColor: Colors.white,
        borderRadius: 0,
        elevation: 3.0,
        borderColor: AppColors.lightGray.withOpacity(0.3),
        showBorder: true,
      ).copyWith(
        borderRadius: null, // Remove top border radius for seamless connection
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Voice status indicator
              if (_isRecording || _isPlaying)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: SoftUIDesign.cardDecoration(
                    backgroundColor: _isRecording ? AppColors.error.withOpacity(0.08) : AppColors.success.withOpacity(0.08),
                    borderRadius: SoftUIDesign.buttonBorderRadius,
                    elevation: 2.0,
                    borderColor: _isRecording ? AppColors.error.withOpacity(0.3) : AppColors.success.withOpacity(0.3),
                    showBorder: true,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isRecording ? Icons.mic : Icons.volume_up,
                        color: _isRecording ? AppColors.error : AppColors.success,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isRecording ? 'Recording...' : 'Playing...',
                        style: AppTypography.bodySmall.copyWith(
                          color: _isRecording ? AppColors.error : AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Input row
              Row(
                children: [
                  // PTT Button
                  GestureDetector(
                    onTapDown: (_) => _startPTT(),
                    onTapUp: (_) => _stopPTT(),
                    onTapCancel: () => _stopPTT(),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: SoftUIDesign.buttonDecoration(
                        backgroundColor: _isRecording ? AppColors.error : AppColors.online,
                        borderRadius: 24.0,
                        shadowColor: _isRecording ? AppColors.error : AppColors.online,
                      ),
                      child: Icon(
                        _isRecording ? Icons.mic : Icons.mic_none,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Text input
                  Expanded(
                    child: Container(
                      decoration: SoftUIDesign.cardDecoration(
                        backgroundColor: AppColors.white,
                        borderRadius: 24.0,
                        elevation: 2.0,
                        borderColor: AppColors.lightGray.withOpacity(0.3),
                        showBorder: true,
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Send button
                  GestureDetector(
                    onTap: _isSending ? null : _sendMessage,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _isSending ? AppColors.lightGray : AppColors.primaryRed,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: _isSending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageSubscription?.cancel();
    _messagesListSubscription?.cancel();
    _voiceFrameSubscription?.cancel();
    _voiceController.dispose();
    super.dispose();
  }
}