import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart' as record;
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../constants/soft_ui_design.dart';
import '../services/simple_bluetooth_service.dart';
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

class _ESP32LoRaChatScreenState extends State<ESP32LoRaChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _messages = [];
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _messagesListSubscription;
  
  bool _isSending = false;
  
  // Voice recording state
  final record.AudioRecorder _recorder = record.AudioRecorder();
  bool _isRecording = false;
  String? _recordedFilePath;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late AnimationController _waveAnimationController;

  @override
  void initState() {
    super.initState();
    _waveAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _initializeESP32Service();
    _setupMessageStreams();
  }

  void _initializeESP32Service() async {
    final esp32Service = Provider.of<SimpleBluetoothService>(context, listen: false);
    await esp32Service.initialize();
    
    if (!esp32Service.isConnected) {
      await esp32Service.connectToESP32();
    }
  }

  void _setupMessageStreams() {
    final esp32Service = Provider.of<SimpleBluetoothService>(context, listen: false);
    
    // Listen for incoming messages
    _messageSubscription = esp32Service.messageStream.listen((message) {
      _handleIncomingMessage(message);
    });
    
    // Listen to the canonical message list from the service
    _messagesListSubscription = esp32Service.messagesStream.listen((list) {
      setState(() {
        // Update messages from service list
        _messages = list;
        
        // Check if any incoming messages match ones we sent (for seen status)
        final esp32Service2 = Provider.of<SimpleBluetoothService>(context, listen: false);
        for (var msg in list) {
          if (msg['sender_name']?.toString() == esp32Service2.userName && 
              msg['isLocal'] != true &&
              msg['message']?.toString().isNotEmpty == true) {
            // This is our message being echoed back - find local version and mark as seen
            final localIndex = _messages.indexWhere((m) => 
              m['message'] == msg['message'] && 
              m['isLocal'] == true &&
              m['sender_name'] == msg['sender_name'] &&
              (m['status'] == 'sent' || m['status'] == 'sending')
            );
            if (localIndex >= 0) {
              _messages[localIndex]['status'] = 'seen';
            }
          }
        }
      });
      _scrollToBottom();
    });
  }

  void _handleIncomingMessage(Map<String, dynamic> message) {
    message['isLocal'] = false;
    
    final messageText = message['message']?.toString() ?? '';
    final senderName = message['sender_name']?.toString() ?? '';
    final esp32Service = Provider.of<SimpleBluetoothService>(context, listen: false);
    
    // If this message is from us (meaning it was forwarded back via NRF24L01), it means someone else saw it
    if (senderName == esp32Service.userName && messageText.isNotEmpty) {
      // Find the local message we sent and mark it as seen
      setState(() {
        final index = _messages.indexWhere((m) => 
          m['message'] == messageText && 
          m['isLocal'] == true &&
          m['sender_name'] == senderName &&
          (m['status'] == 'sent' || m['status'] == 'sending')
        );
        if (index >= 0) {
          _messages[index]['status'] = 'seen';
          // Don't add this as a new message since it's our own message being echoed back
          _scrollToBottom();
          return;
        }
      });
    }
    
    // This is a new message from someone else
    setState(() {
      _messages.add(message);
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      // Use smooth animation for better UX
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
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
    
    // Generate unique message ID
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    
    try {
      // Add message to local list immediately with "sending" status
      final localMessage = {
        'type': 'group',
        'sender_name': esp32Service.userName,
        'sender_id': esp32Service.esp32NodeId,
        'receiver_id': 'all',
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
        'id': messageId,
        'isLocal': true,
        'status': 'sending',  // Initial status: sending
      };
      
      setState(() {
        _messages.add(localMessage);
      });
      
      _messageController.clear();
      _scrollToBottom();
      
      // Send via ESP32
      await esp32Service.sendGroupMessage(message);
      
      // Update status to "sent" after successful send
      setState(() {
        final index = _messages.indexWhere((m) => m['id'] == messageId);
        if (index >= 0) {
          _messages[index]['status'] = 'sent';
        }
      });
      
    } catch (e) {
      _showSimpleMessage('Failed to send: $e');
      // Update status to failed if error
      setState(() {
        final index = _messages.indexWhere((m) => m['id'] == messageId);
        if (index >= 0) {
          _messages[index]['status'] = 'failed';
        }
      });
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

  Future<void> _startRecording() async {
    if (await _recorder.hasPermission()) {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        record.RecordConfig(
          encoder: record.AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );
      setState(() {
        _isRecording = true;
      });
      _waveAnimationController.repeat();
    }
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    if (path != null) {
      final file = File(path);
      
      // Read file bytes and print first 10 bytes
      final bytes = await file.readAsBytes();
      print(bytes.take(10).toList()); // e.g. [0, 0, 0, 32, 102, 116, 121, 112, ...]
      
      final size = (await file.length() / 1024).toStringAsFixed(1);
      
      // Get duration using audioplayers
      String duration = "0";
      try {
        await _audioPlayer.setSource(DeviceFileSource(path));
        final durationObj = await _audioPlayer.getDuration();
        if (durationObj != null) {
          duration = durationObj.inSeconds.toStringAsFixed(1);
        }
      } catch (e) {
        // If duration cannot be retrieved, default to "0"
        duration = "0";
      }

      setState(() {
        _recordedFilePath = path;
        _isRecording = false;
      });
      _waveAnimationController.stop();
      _waveAnimationController.reset();

      setState(() {
        _messages.add({
          'type': 'voice',
          'filePath': path,
          'duration': duration,
          'fileSize': size,
          'sender_name': Provider.of<SimpleBluetoothService>(context, listen: false).userName,
          'isLocal': true,
          'timestamp': DateTime.now().toIso8601String(),
          'status': 'sent',
        });
      });

      _scrollToBottom();
    }
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
                final connectedCount = esp32Service.connectedUsers.length;
                final status = esp32Service.isConnected 
                    ? (connectedCount > 0 ? 'Connected ($connectedCount)' : 'Connected')
                    : 'Disconnected';
                
                return TopBarConfigs.loraTopBar(
                  status: status,
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
    // Check if this is a voice message
    if (message['type'] == 'voice') {
      return _buildVoiceMessageBubble(message);
    }
    
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
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(timestamp),
                        style: AppTypography.bodySmall.copyWith(
                          color: isLocal ? Colors.white70 : AppColors.lightGray,
                          fontSize: 11,
                        ),
                      ),
                      if (isLocal) ...[
                        const SizedBox(width: 4),
                        _buildMessageStatus(message),
                      ],
                    ],
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

  Widget _buildMessageStatus(Map<String, dynamic> message) {
    final status = message['status']?.toString() ?? 'sent';
    
    switch (status) {
      case 'sending':
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
          ),
        );
      case 'sent':
        return Icon(
          Icons.done,
          size: 14,
          color: Colors.white70,
        );
      case 'seen':
        return Icon(
          Icons.done_all,
          size: 14,
          color: Colors.white,
        );
      case 'failed':
        return Icon(
          Icons.error_outline,
          size: 14,
          color: Colors.red[300],
        );
      default:
        return Icon(
          Icons.done,
          size: 14,
          color: Colors.white70,
        );
    }
  }

  Widget _buildVoiceMessageBubble(Map<String, dynamic> message) {
    final isLocal = message['isLocal'] == true;
    final filePath = message['filePath'];
    final duration = message['duration'];
    final size = message['fileSize'];

    return Align(
      alignment: isLocal ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isLocal ? AppColors.primaryRed : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLocal ? Colors.white.withOpacity(0.3) : AppColors.lightGray,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.play_arrow_rounded,
                color: isLocal ? Colors.white : AppColors.primaryRed,
              ),
              onPressed: () => _audioPlayer.play(DeviceFileSource(filePath)),
            ),
            Text(
              '$duration s • $size KB',
              style: AppTypography.bodySmall.copyWith(
                color: isLocal ? Colors.white70 : AppColors.darkGray,
              ),
            ),
          ],
        ),
      ),
    );
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
          child: Row(
            children: [
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

              // Mic button with wave animation
              GestureDetector(
                onLongPressStart: (_) => _startRecording(),
                onLongPressEnd: (_) => _stopRecording(),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _isRecording ? Colors.redAccent : Colors.green,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: _isRecording
                      ? _buildWaveAnimation()
                      : const Icon(
                          Icons.mic_rounded,
                          color: Colors.white,
                          size: 20,
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
        ),
      ),
    );
  }

  Widget _buildWaveAnimation() {
    return AnimatedBuilder(
      animation: _waveAnimationController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final animationValue = (_waveAnimationController.value + delay) % 1.0;
            final height = 8 + (animationValue < 0.5 
                ? animationValue * 12 
                : (1 - animationValue) * 12);
            
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 3,
              height: height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }

  @override
  void dispose() {
    _waveAnimationController.dispose();
    _recorder.dispose();
    _audioPlayer.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _messageSubscription?.cancel();
    _messagesListSubscription?.cancel();
    super.dispose();
  }
}