import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../constants/soft_ui_design.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../services/voice_chat_extension.dart' as voice;
import '../widgets/unified_top_bar.dart';
import '../widgets/connected_users_list_modal.dart';
import '../widgets/sender_info_modal.dart';
import '../widgets/enhanced_skeleton_loaders.dart';
import '../widgets/enhanced_empty_state.dart';
import '../widgets/accessible_text.dart';

/// Local Chat Screen - Polished UI with Working Backend
class LocalChatScreen extends StatefulWidget {
  const LocalChatScreen({super.key});

  @override
  State<LocalChatScreen> createState() => _LocalChatScreenState();
}

class _LocalChatScreenState extends State<LocalChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _debugScrollController = ScrollController();
  
  bool _isDebugConsoleVisible = false;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final chatProvider = context.read<ChatProvider>();
      
      // Load paired devices
      chatProvider.loadPairedDevices();
      
      // Load messages with progressive loading (shows cached first)
      chatProvider.loadMessages();
      
      // Set current user name from database/storage (signup information)
      final authProvider = context.read<AuthProvider>();
      String? userName;
      
      // First, try to get from UserModel (loaded from database)
      if (authProvider.currentUserModel != null) {
        userName = authProvider.currentUserModel!.name;
      }
      
      // If UserModel not loaded yet, try to load it
      if (userName == null || userName.isEmpty) {
        await authProvider.loadUserModel();
        if (authProvider.currentUserModel != null) {
          userName = authProvider.currentUserModel!.name;
        }
      }
      
      // Fallback to userName from AuthProvider (from SharedPreferences)
      if (userName == null || userName.isEmpty) {
        userName = authProvider.userName;
      }
      
      // Final fallback to email prefix
      if (userName == null || userName.isEmpty) {
        userName = authProvider.userEmail?.split('@')[0] ?? 'Me';
      }
      
      chatProvider.setCurrentUserName(userName);
    });
    
    // Listen to voice extension recording state
    context.read<ChatProvider>().voiceExtension.recordingStream.listen((isRecording) {
      if (mounted) {
        setState(() {
          _isRecording = isRecording;
        });
      }
    });
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isNotEmpty) {
      final messageText = _messageController.text;
      _messageController.clear();
      
      final success = await context.read<ChatProvider>().sendMessage(
        messageText,
        context: context,
      );
      
      if (success && mounted) {
        // Show subtle success feedback (not full screen animation for messages)
        HapticFeedback.lightImpact();
        // Message appears in chat, so no need for full animation
        // Just haptic feedback is enough for message sending
      }
      
      _scrollToBottom();
    }
  }

  Future<void> _startRecording() async {
    final provider = context.read<ChatProvider>();
    if (provider.isConnected) {
      final success = await provider.startRecording();
      if (success) {
        setState(() {
          _isRecording = true;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _stopRecording() async {
    if (_isRecording) {
      final provider = context.read<ChatProvider>();
      await provider.stopRecordingAndSend();
      setState(() {
        _isRecording = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _playVoiceMessage(voice.VoiceMessage voiceMessage) async {
    final provider = context.read<ChatProvider>();
    await provider.playVoiceMessage(voiceMessage);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showConnectedUsersModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => const ConnectedUsersListModal(),
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
            Consumer<ChatProvider>(
              builder: (context, provider, child) {
                final statusText = provider.isConnected 
                    ? 'Connected${provider.connectedUsersCount > 0 ? ' (${provider.connectedUsersCount})' : ''}'
                    : 'Disconnected';
                return TopBarConfigs.localChatTopBar(
                  status: statusText,
                  onBluetoothTap: null, // Removed - now on home screen
                  onConnectedTap: () {
                    if (provider.isConnected) {
                      _showConnectedUsersModal();
                    }
                    // Removed radar modal - now on home screen
                  },
                  onRefresh: () => provider.smartRefresh(),
                );
              },
            ),
            
            // Messages area
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, provider, child) {
                  // Show loading skeleton if initial load
                  if (provider.isLoadingMessages && provider.messages.isEmpty) {
                    return const SkeletonMessageList(itemCount: 5);
                  }
                  
                  // Show empty state if no messages
                  if (provider.messages.isEmpty) {
                    return EmptyStatePresets.noMessages(
                      onStartChatting: provider.isConnected
                          ? () {
                              // Focus on message input
                              FocusScope.of(context).requestFocus(FocusNode());
                            }
                          : null,
                      onConnectDevice: !provider.isConnected
                          ? () {
                              // Show paired devices modal
                              _showConnectedUsersModal();
                            }
                          : null,
                    );
                  }
                  
                  // Show messages with refresh indicator overlay
                  return Stack(
                    children: [
                      ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: provider.messages.length + (provider.isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          // Show typing indicator at the end
                          if (index == provider.messages.length && provider.isTyping) {
                            return _buildTypingIndicator();
                          }
                          
                          final message = provider.messages[index];
                          // Auto-scroll to bottom when new messages arrive
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_scrollController.hasClients && index == provider.messages.length - 1) {
                              _scrollController.animateTo(
                                _scrollController.position.maxScrollExtent,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                              );
                            }
                          });
                          return _buildMessageBubble(message);
                        },
                      ),
                      // Refresh indicator overlay (only show if refreshing, not when receiving real-time messages)
                      if (provider.isRefreshingMessages && !provider.isConnected)
                        Positioned(
                          top: 16,
                          left: 0,
                          right: 0,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.info.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  provider.hasCachedMessages 
                                      ? 'Refreshing...' 
                                      : 'Loading...',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),

            // Debug console
            if (_isDebugConsoleVisible)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  border: const Border(top: BorderSide(color: Colors.grey)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        border: const Border(bottom: BorderSide(color: Colors.grey)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Debug Console',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  context.read<ChatProvider>().clearDebugLogs();
                                },
                                icon: const Icon(Icons.clear, color: Colors.white, size: 20),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _isDebugConsoleVisible = false;
                                  });
                                },
                                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Consumer<ChatProvider>(
                        builder: (context, provider, child) {
                          return ListView.builder(
                            controller: _debugScrollController,
                            padding: const EdgeInsets.all(8),
                            itemCount: provider.debugLogs.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  provider.debugLogs[index],
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

            // Message input area
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: _buildMessageBubbleContent(message),
          ),
        );
      },
    );
  }

  Widget _buildMessageBubbleContent(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: message.isMe 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        children: [
          if (!message.isMe) ...[
            GestureDetector(
              onTap: message.senderName != null && message.senderName!.isNotEmpty
                  ? () {
                      _showSenderInfoModal(message.senderName!);
                    }
                  : null,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primaryRed.withOpacity(0.1),
                child: Text(
                  message.senderName?.isNotEmpty == true 
                      ? (message.senderName![0].toUpperCase())
                      : 'ESP',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: message.isMe ? AppColors.primaryRed : Colors.white,
              borderRadius: BorderRadius.circular(20).copyWith(
                bottomLeft: message.isMe ? const Radius.circular(20) : const Radius.circular(4),
                bottomRight: message.isMe ? const Radius.circular(4) : const Radius.circular(20),
              ),
              border: Border.all(
                color: message.isMe 
                    ? Colors.white.withOpacity(0.2)
                    : AppColors.lightGray.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Message content
                if (message.type == voice.MessageType.voice && message.voiceMessage != null)
                  _buildVoiceMessageContent(message.voiceMessage!)
                else
                  AccessibleChatText(
                    message.text,
                    isMe: message.isMe,
                    backgroundColor: message.isMe
                        ? AppColors.primaryRed
                        : AppColors.white,
                    maxLines: null,
                  ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatDateTime(message.timestamp),
                      style: AppTypography.bodySmall.copyWith(
                        color: message.isMe ? Colors.white70 : AppColors.lightGray,
                      ),
                    ),
                    if (message.isMe) ...[
                      const SizedBox(width: 8),
                      _buildMessageStatus(message.status),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (message.isMe) ...[
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

  Widget _buildVoiceMessageContent(voice.VoiceMessage voiceMessage) {
    return GestureDetector(
      onTap: () => _playVoiceMessage(voiceMessage),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primaryRed.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_arrow,
              color: AppColors.primaryRed,
              size: 20,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voice Message',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${voiceMessage.formattedSize} • ${voiceMessage.formattedDuration}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.primaryRed.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showSenderInfoModal(String senderName) {
    showDialog(
      context: context,
      builder: (context) => SenderInfoModal(senderName: senderName),
    );
  }

  Widget _buildMessageStatus(voice.MessageStatus status) {
    IconData icon;
    Color color;
    
    switch (status) {
      case voice.MessageStatus.sending:
        icon = Icons.access_time;
        color = Colors.white70;
        break;
      case voice.MessageStatus.sent:
        icon = Icons.check;
        color = Colors.white70;
        break;
      case voice.MessageStatus.delivered:
        icon = Icons.done_all;
        color = Colors.white70;
        break;
      case voice.MessageStatus.received:
        icon = Icons.done_all;
        color = Colors.blue[300]!;
        break;
      case voice.MessageStatus.failed:
        icon = Icons.error;
        color = Colors.red[300]!;
        break;
    }
    
    return Icon(icon, color: color, size: 16);
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (messageDate == today) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${DateFormat('HH:mm').format(dateTime)}';
    } else {
      return DateFormat('MMM dd, HH:mm').format(dateTime);
    }
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primaryRed.withOpacity(0.1),
            child: Text(
              'ESP',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.primaryRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20).copyWith(
                bottomLeft: const Radius.circular(4),
              ),
              border: Border.all(
                color: AppColors.lightGray.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDot(0),
                const SizedBox(width: 4),
                _buildTypingDot(1),
                const SizedBox(width: 4),
                _buildTypingDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeInOut,
      onEnd: () {
        if (mounted) {
          setState(() {});
        }
      },
      builder: (context, value, child) {
        final delay = index * 0.2;
        final adjustedValue = ((value + delay) % 1.0);
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.primaryRed.withOpacity(0.3 + (adjustedValue * 0.7)),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return Container(
      decoration: SoftUIDesign.cardDecoration(
        backgroundColor: Colors.white,
        borderRadius: 0,
        elevation: 3.0,
        borderColor: AppColors.lightGray.withOpacity(0.3),
        showBorder: true,
      ).copyWith(
        borderRadius: null,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Voice status indicator
              Consumer<ChatProvider>(
                builder: (context, provider, child) {
                  if (provider.isRecording || provider.isPlaying) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: SoftUIDesign.cardDecoration(
                        backgroundColor: provider.isRecording ? AppColors.error.withOpacity(0.08) : AppColors.success.withOpacity(0.08),
                        borderRadius: SoftUIDesign.buttonBorderRadius,
                        elevation: 2.0,
                        borderColor: provider.isRecording ? AppColors.error.withOpacity(0.3) : AppColors.success.withOpacity(0.3),
                        showBorder: true,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            provider.isRecording ? Icons.mic : Icons.volume_up,
                            color: provider.isRecording ? AppColors.error : AppColors.success,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            provider.isRecording ? 'Recording...' : 'Playing...',
                            style: AppTypography.bodySmall.copyWith(
                              color: provider.isRecording ? AppColors.error : AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              
              // Input row
              Row(
                children: [
                  // Voice recording button
                  GestureDetector(
                    onTapDown: (_) => _startRecording(),
                    onTapUp: (_) => _stopRecording(),
                    onTapCancel: () => _stopRecording(),
                    child: Consumer<ChatProvider>(
                      builder: (context, provider, child) {
                        return Container(
                          width: 48,
                          height: 48,
                          decoration: SoftUIDesign.buttonDecoration(
                            backgroundColor: provider.isRecording ? AppColors.error : AppColors.online,
                            borderRadius: 24.0,
                            shadowColor: provider.isRecording ? AppColors.error : AppColors.online,
                          ),
                          child: Icon(
                            provider.isRecording ? Icons.stop : Icons.mic,
                            color: Colors.white,
                            size: 20,
                          ),
                        );
                      },
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
                    onTap: _sendMessage,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
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
    _debugScrollController.dispose();
    super.dispose();
  }
}

/// Device Selection Dialog with Polished UI
class _DeviceSelectionDialog extends StatefulWidget {
  @override
  State<_DeviceSelectionDialog> createState() => _DeviceSelectionDialogState();
}

class _DeviceSelectionDialogState extends State<_DeviceSelectionDialog> {
  bool _showAllDevices = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadPairedDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color cyanBlue = Color(0xFF3498DB);
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.maxFinite,
        height: 600,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Consumer<ChatProvider>(
          builder: (context, provider, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Modern Header with Gradient
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cyanBlue,
                        cyanBlue.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.bluetooth,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bluetooth Devices',
                              style: AppTypography.headlineSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Select an ESP32 device to connect',
                              style: AppTypography.bodySmall.copyWith(
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                
                // Connection Status Card
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: provider.isConnected 
                          ? cyanBlue.withOpacity(0.1) 
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: provider.isConnected 
                            ? cyanBlue.withOpacity(0.3) 
                            : Colors.grey.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: provider.isConnected 
                                ? cyanBlue.withOpacity(0.2) 
                                : Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            provider.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                            color: provider.isConnected ? cyanBlue : Colors.grey,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                provider.isConnected 
                                    ? 'Connected' 
                                    : 'Not Connected',
                                style: AppTypography.bodyLarge.copyWith(
                                  color: provider.isConnected ? cyanBlue : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                provider.isConnected 
                                    ? 'Device: ${provider.selectedDevice?.name ?? "ESP32"}' 
                                    : 'No device connected',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.mediumGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Refresh button and title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Paired Devices',
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkGray,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: provider.isConnecting ? null : () {
                          provider.loadPairedDevices();
                        },
                        icon: provider.isConnecting 
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.refresh, size: 18),
                        label: Text(provider.isConnecting ? 'Connecting...' : 'Refresh'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cyanBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Device list
                Expanded(
                  child: provider.pairedDevices.isEmpty
                      ? Center(
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.bluetooth_searching,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'No paired devices found',
                                  style: AppTypography.headlineSmall.copyWith(
                                    color: AppColors.darkGray,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Please pair with ESP32 device first',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.mediumGray,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      : Column(
                          children: [
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(8),
                                  itemCount: _showAllDevices 
                                      ? provider.pairedDevices.length 
                                      : (provider.pairedDevices.length > 5 ? 5 : provider.pairedDevices.length),
                                  itemBuilder: (context, index) {
                                    final device = provider.pairedDevices[index];
                                    final isSelected = provider.selectedDevice?.address == device.address;
                                    final isConnected = provider.isConnected && isSelected;
                                    
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isConnected 
                                              ? cyanBlue.withOpacity(0.5) 
                                              : (isSelected 
                                                  ? cyanBlue.withOpacity(0.3) 
                                                  : Colors.grey.withOpacity(0.2)),
                                          width: isConnected || isSelected ? 1.5 : 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        leading: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: isConnected
                                                  ? [cyanBlue, cyanBlue.withOpacity(0.7)]
                                                  : [Colors.grey.withOpacity(0.3), Colors.grey.withOpacity(0.1)],
                                            ),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                                            color: isConnected ? Colors.white : AppColors.mediumGray,
                                            size: 24,
                                          ),
                                        ),
                                        title: Text(
                                          device.name ?? 'Unknown Device',
                                          style: AppTypography.bodyMedium.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.darkGray,
                                          ),
                                        ),
                                        subtitle: Text(
                                          device.address,
                                          style: AppTypography.bodySmall.copyWith(
                                            color: AppColors.mediumGray,
                                          ),
                                        ),
                                        trailing: isConnected
                                            ? ElevatedButton(
                                                onPressed: () {
                                                  provider.disconnect();
                                                  Navigator.pop(context);
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                                child: const Text('Disconnect'),
                                              )
                                            : ElevatedButton(
                                                onPressed: provider.isConnecting ? null : () async {
                                                  bool success = await provider.connectToDevice(device, context: context);
                                                  if (success && mounted) {
                                                    Navigator.pop(context);
                                                  }
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: cyanBlue,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                                child: Text(provider.isConnecting ? 'Connecting...' : 'Connect'),
                                              ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            
                            // Show more button
                            if (!_showAllDevices && provider.pairedDevices.length > 5) ...[
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _showAllDevices = true;
                                    });
                                  },
                                  icon: const Icon(Icons.expand_more, color: cyanBlue),
                                  label: Text(
                                    'Show more (${provider.pairedDevices.length - 5} more devices)',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: cyanBlue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            
                            // Show less button
                            if (_showAllDevices && provider.pairedDevices.length > 5) ...[
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _showAllDevices = false;
                                    });
                                  },
                                  icon: const Icon(Icons.expand_less, color: cyanBlue),
                                  label: Text(
                                    'Show less',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: cyanBlue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
                
                // Close button
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: AppTypography.bodyMedium.copyWith(
                          color: cyanBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}


