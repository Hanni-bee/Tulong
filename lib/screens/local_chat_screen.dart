import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../constants/soft_ui_design.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../services/voice_chat_extension.dart' as voice;
import '../utils/app_time_format.dart';
import '../utils/address_encoder.dart';
import '../widgets/unified_top_bar.dart';
import '../widgets/connected_users_list_modal.dart';
import '../widgets/sender_info_modal.dart';
import '../widgets/enhanced_skeleton_loaders.dart';
import '../widgets/enhanced_empty_state.dart';
import '../widgets/accessible_text.dart';
import '../widgets/enhanced_message_status.dart';
import '../widgets/enhanced_voice_message_view.dart';
import '../widgets/elite_liquid_background.dart';

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
  bool _isMicPressed = false;
  bool _markReadScheduled = false;

  static const Duration _pinnedRetention = Duration(days: 1);
  Timer? _pinnedRefreshTimer;

  bool _isSosEmergencyMessage(ChatMessage message) {
    if (!message.isEmergency) return false;
    final source = message.rawData?['source']?.toString();
    if (source == 'sos') return true;
    // Fallback heuristic for older/legacy SOS payloads
    return message.isMe && message.text.contains('🚨');
  }

  List<ChatMessage> _getSosEmergencyHistory(List<ChatMessage> messages) {
    final now = DateTime.now();
    final list = messages
        .where((m) => _isSosEmergencyMessage(m) && now.difference(m.timestamp) < _pinnedRetention)
        .toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  Widget _buildTopBarActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    String? tooltip,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: tooltip ?? '',
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Keep pinned banner/history time-window accurate while the screen stays open.
    _pinnedRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
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

      // If user opens Local Chat and they are already at the bottom, clear unread immediately.
      _maybeMarkAllAsRead();
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
      
      final authProvider = context.read<AuthProvider>();
      final addr = AddressEncoder.fromUser(authProvider.currentUserModel);
      final addressToSend = addr.fullAddress.isNotEmpty ? addr.fullAddress : null;
      
      final Map<String, dynamic>? additionalData = addressToSend != null 
          ? {'sender_address': addressToSend} 
          : null;

      final success = await context.read<ChatProvider>().sendMessage(
        messageText,
        additionalData: additionalData,
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
    if (!provider.isConnected) {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connect to ESP32 to send voice messages.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final success = await provider.startRecording();
    if (!mounted) return;

    if (success) {
      setState(() {
        _isRecording = true;
      });
      _scrollToBottom();

      // Fix press/release race: if the user already released before start completed,
      // stop immediately and send what we captured (if any).
      if (!_isMicPressed) {
        await _stopRecording(force: true);
      }
    } else {
      // Most common reason is mic permission denied (or recorder init failure).
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is required to record.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _stopRecording({bool force = false}) async {
    final provider = context.read<ChatProvider>();
    final shouldStop = force || _isRecording || provider.isRecording;
    if (!shouldStop) return;

    await provider.stopRecordingAndSend();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
    });
    _scrollToBottom();
  }

  Future<void> _playVoiceMessage(voice.VoiceMessage voiceMessage) async {
    final provider = context.read<ChatProvider>();
    // Stop any currently playing message first
    if (provider.isPlaying) {
      await provider.stopPlayback();
    }
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

  void _showPinnedEmergencyDetails(ChatMessage message) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottomInset = MediaQuery.viewInsetsOf(ctx).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.lightGray.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.error.withOpacity(0.25)),
                        ),
                        child: const Icon(Icons.sos_rounded, color: AppColors.error, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pinned Emergency',
                              style: AppTypography.titleMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDateTime(message.timestamp),
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(ctx).height * 0.45,
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        message.text,
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: message.text));
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Copied emergency message'),
                                  behavior: SnackBarBehavior.floating,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: BorderSide(color: AppColors.lightGray.withOpacity(0.6)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.copy_all_rounded, size: 18),
                          label: const Text('Copy'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPinnedHistoryModal() {
    final provider = context.read<ChatProvider>();
    final items = _getSosEmergencyHistory(provider.messages);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.lightGray.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.error.withOpacity(0.22)),
                      ),
                      child: const Icon(Icons.push_pin_rounded, color: AppColors.error, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pinned SOS History',
                            style: AppTypography.titleMedium.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${items.length} alert${items.length == 1 ? '' : 's'}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Text(
                      'No pinned SOS messages yet.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(ctx).height * 0.55,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 16,
                        color: AppColors.lightGray.withOpacity(0.45),
                      ),
                      itemBuilder: (ctx2, i) {
                        final m = items[i];
                        return InkWell(
                          onTap: () {
                            Navigator.of(ctx).pop();
                            // After the sheet closes, show full details.
                            Future.delayed(const Duration(milliseconds: 150), () {
                              if (mounted) _showPinnedEmergencyDetails(m);
                            });
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: AppColors.error.withOpacity(0.10),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.error.withOpacity(0.22)),
                                  ),
                                  child: const Icon(Icons.sos_rounded, color: AppColors.error, size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _formatDateTime(m.timestamp),
                                              style: AppTypography.bodySmall.copyWith(
                                                color: AppColors.textSecondary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        m.text,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.bodyMedium.copyWith(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w700,
                                          height: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  void _onScroll() {
    _maybeMarkAllAsRead();
  }

  void _maybeMarkAllAsRead() {
    if (!mounted) return;
    if (_markReadScheduled) return;

    _markReadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markReadScheduled = false;
      if (!mounted) return;
      if (!_scrollController.hasClients) return;

      final provider = context.read<ChatProvider>();

      // Only clear when Local Chat tab is active/visible.
      if (!provider.isLocalChatScreenVisible) return;
      if (provider.unreadMessageCount <= 0) return;

      // "Seen" rule: user must be at (or very near) the bottom.
      const thresholdPx = 56.0;
      final pos = _scrollController.position;
      final atBottom = (pos.maxScrollExtent - pos.pixels) <= thresholdPx;
      if (!atBottom) return;

      provider.markAllMessagesAsRead();
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
    final isKeyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 20;
    final isPushedRoute = ModalRoute.of(context)?.canPop ?? false;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // When this screen is pushed as a standalone route (e.g., via Home quick action),
          // provide the same light app background so we don't render over a black canvas.
          if (isPushedRoute) const EliteLiquidBackground(isLight: true),
          SafeArea(
            bottom: true,
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
                  onBluetoothTap: () {
                    if (provider.isConnected) {
                      _showConnectedUsersModal();
                    }
                    // Removed radar modal - now on home screen
                  },
                  onConnectedTap: provider.isConnected ? () {
                    _showConnectedUsersModal();
                  } : null,
                  additionalActions: [
                    _buildTopBarActionButton(
                      icon: Icons.push_pin_rounded,
                      color: AppColors.error,
                      tooltip: 'Pinned SOS history',
                      onPressed: _showPinnedHistoryModal,
                    ),
                  ],
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
                    final emptyStatePadding = EdgeInsets.fromLTRB(
                      32,
                      isKeyboardVisible ? 24 : 48,
                      32,
                      isKeyboardVisible ? 20 : 48,
                    );
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
                      padding: emptyStatePadding,
                      scrollable: isKeyboardVisible, // idle: no scrolling; keyboard up: allow if needed
                    );
                  }
                  
                  // Find the latest SOS emergency message if it's within the last hour (pinned banner source)
                  final now = DateTime.now();
                  ChatMessage? latestEmergency;
                  for (final m in provider.messages.reversed) {
                    if (!_isSosEmergencyMessage(m)) continue;
                    if (now.difference(m.timestamp) >= _pinnedRetention) continue;
                    latestEmergency = m;
                    break;
                  }
                  final hasActiveEmergency = latestEmergency != null;

                  // Show messages with refresh indicator overlay
                  return Column(
                    children: [
                      // Pinned Emergency Alert
                      if (hasActiveEmergency)
                        _buildPinnedEmergencyAlert(latestEmergency),
                        
                      Expanded(
                        child: Stack(
                          children: [
                            ListView.builder(
                              controller: _scrollController,
                              padding: EdgeInsets.only(
                                top: 16,
                                left: 16,
                                right: 16,
                                bottom: 160, // clearance for input bar
                              ),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildMessageInput(),
              ),
            ),
              ],
            ),
          ),
        ],
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
    final isEmergency = message.isEmergency;
    final location = _extractSosLocation(message);
    
    return Container(
      margin: EdgeInsets.only(bottom: isEmergency ? 16 : 12),
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
              child: Container(
                decoration: isEmergency ? BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.error.withOpacity(0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ) : null,
                child: CircleAvatar(
                  radius: isEmergency ? 18 : 16,
                  backgroundColor: isEmergency 
                      ? AppColors.error.withOpacity(0.2)
                      : AppColors.primaryRed.withOpacity(0.1),
                  child: isEmergency
                      ? const Icon(
                          Icons.emergency,
                          color: AppColors.error,
                          size: 20,
                        )
                      : Text(
                          message.senderName?.isNotEmpty == true 
                              ? (message.senderName![0].toUpperCase())
                              : 'ESP',
                          style: AppTypography.bodySmall.copyWith(
                            color: isEmergency ? AppColors.error : AppColors.primaryRed,
                            fontWeight: FontWeight.bold,
                          ),
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20).copyWith(
                bottomLeft: message.isMe ? const Radius.circular(20) : const Radius.circular(4),
                bottomRight: message.isMe ? const Radius.circular(4) : const Radius.circular(20),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: !message.isMe && !isEmergency ? 12 : 0, 
                  sigmaY: !message.isMe && !isEmergency ? 12 : 0
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isEmergency ? 18 : 16,
                    vertical: isEmergency ? 14 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: isEmergency
                        ? (message.isMe ? AppColors.error : AppColors.error.withOpacity(0.1))
                        : (message.isMe ? AppColors.primaryRed : Colors.white.withOpacity(0.82)),
                    borderRadius: BorderRadius.circular(20).copyWith(
                      bottomLeft: message.isMe ? const Radius.circular(20) : const Radius.circular(4),
                      bottomRight: message.isMe ? const Radius.circular(4) : const Radius.circular(20),
                    ),
                    border: Border.all(
                      color: isEmergency
                          ? AppColors.error.withOpacity(0.8)
                          : (message.isMe 
                              ? Colors.white.withOpacity(0.2)
                              : Colors.white.withOpacity(0.4)),
                      width: isEmergency ? 2.5 : 1.5,
                    ),
                    boxShadow: isEmergency ? [
                      BoxShadow(
                        color: AppColors.error.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ] : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Emergency badge
                      if (isEmergency) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.sos_rounded,
                              color: AppColors.error,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'EMERGENCY ALERT',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Message content
                      if (message.type == voice.MessageType.voice && message.voiceMessage != null)
                        _buildVoiceMessageContent(message.voiceMessage!, message.timestamp.millisecondsSinceEpoch.toString(), message.isMe)
                      else
                        isEmergency
                            ? Text(
                                location.displayText,
                                style: AppTypography.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: message.isMe ? Colors.white : AppColors.error,
                                ),
                              )
                            : AccessibleChatText(
                                location.displayText,
                                isMe: message.isMe,
                                backgroundColor: message.isMe
                                    ? AppColors.primaryRed
                                    : Colors.transparent, // Let bubble background show through
                                maxLines: null,
                              ),
                      if (location.shouldShowCard) ...[
                        const SizedBox(height: 10),
                        _buildSosLocationCard(
                          full: location.fullAddress!,
                          code: location.code,
                          isMe: message.isMe,
                          isEmergency: isEmergency,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatDateTime(message.timestamp),
                            style: AppTypography.bodySmall.copyWith(
                              color: isEmergency
                                  ? (message.isMe ? Colors.white70 : AppColors.error.withOpacity(0.8))
                                  : (message.isMe ? Colors.white70 : AppColors.textSecondary.withOpacity(0.7)),
                            ),
                          ),
                          if (message.isMe) ...[
                            const SizedBox(width: 8),
                            _buildMessageStatus(message.status, message.isRead),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (message.isMe) ...[
            const SizedBox(width: 8),
            Container(
              decoration: isEmergency ? BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.error.withOpacity(0.5),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ) : null,
              child: CircleAvatar(
                radius: isEmergency ? 18 : 16,
                backgroundColor: isEmergency
                    ? AppColors.error.withOpacity(0.2)
                    : AppColors.primaryRed.withOpacity(0.1),
                child: isEmergency
                    ? const Icon(
                        Icons.emergency,
                        color: AppColors.error,
                        size: 20,
                      )
                    : Text(
                        'Me',
                        style: AppTypography.bodySmall.copyWith(
                          color: isEmergency ? AppColors.error : AppColors.primaryRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  ({String displayText, String? fullAddress, String? code, bool shouldShowCard})
      _extractSosLocation(ChatMessage message) {
    final raw = message.rawData;
    final fullFromMeta = raw?['location_full']?.toString().trim();
    final codeFromMeta = raw?['location_code']?.toString().trim();

    String? full = (fullFromMeta != null && fullFromMeta.isNotEmpty) ? fullFromMeta : null;
    String? code = (codeFromMeta != null && codeFromMeta.isNotEmpty) ? codeFromMeta : null;

    // Backward-compatible fallback: parse a trailing "📍 ..." line if metadata is missing.
    // This keeps older clients useful, while still preferring metadata when available.
    if (full == null) {
      final lines = message.text.split('\n');
      final idx = lines.lastIndexWhere((l) => l.trimLeft().startsWith('📍'));
      if (idx != -1) {
        final candidate = lines[idx].replaceFirst(RegExp(r'^\s*📍\s*'), '').trim();
        if (candidate.isNotEmpty) {
          full = candidate;
        }
      }
    }

    // If we have a "real" location (metadata or parsed), show the card for emergency SOS style messages.
    final shouldShow = message.isEmergency && full != null && full.isNotEmpty;

    // If we're showing the card, remove the 📍 line from the visible message text to avoid duplication.
    var display = message.text;
    if (shouldShow && display.contains('📍')) {
      final lines = display.split('\n');
      final filtered = <String>[];
      var removed = false;
      for (final l in lines) {
        final isPinLine = !removed && l.trimLeft().startsWith('📍');
        if (isPinLine) {
          removed = true;
          continue;
        }
        filtered.add(l);
      }
      display = filtered.join('\n').trim();
      if (display.isEmpty) display = message.text; // safety fallback
    }

    return (
      displayText: display,
      fullAddress: full,
      code: code,
      shouldShowCard: shouldShow,
    );
  }

  Widget _buildSosLocationCard({
    required String full,
    required String? code,
    required bool isMe,
    required bool isEmergency,
  }) {
    final bg = isEmergency
        ? (isMe ? Colors.white.withOpacity(0.12) : AppColors.error.withOpacity(0.08))
        : (isMe ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.05));

    final border = isEmergency
        ? (isMe ? Colors.white.withOpacity(0.22) : AppColors.error.withOpacity(0.22))
        : Colors.white.withOpacity(0.18);

    final titleColor = isEmergency
        ? (isMe ? Colors.white.withOpacity(0.95) : AppColors.error.withOpacity(0.95))
        : (isMe ? Colors.white.withOpacity(0.95) : AppColors.textPrimary);

    final textColor = isEmergency
        ? (isMe ? Colors.white.withOpacity(0.90) : AppColors.textPrimary)
        : (isMe ? Colors.white.withOpacity(0.90) : AppColors.textPrimary);

    Future<void> copy(String v, String label) async {
      await Clipboard.setData(ClipboardData(text: v));
      if (!mounted) return;
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label copied'),
          duration: const Duration(milliseconds: 1200),
        ),
      );
    }

    return GestureDetector(
      onTap: () => copy(full, 'Address'),
      onLongPress: code != null && code.trim().isNotEmpty ? () => copy(code.trim(), 'Location code') : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 16,
                  color: isEmergency
                      ? (isMe ? Colors.white.withOpacity(0.95) : AppColors.error)
                      : titleColor,
                ),
                const SizedBox(width: 6),
                Text(
                  'Location',
                  style: AppTypography.bodySmall.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(
                    Icons.copy_all_rounded,
                    size: 16,
                    color: titleColor.withOpacity(0.9),
                  ),
                  onPressed: () => copy(full, 'Address'),
                  tooltip: 'Copy address',
                ),
              ],
            ),
            Text(
              full,
              style: AppTypography.bodySmall.copyWith(
                color: textColor,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            if (code != null && code.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isMe ? Colors.black.withOpacity(0.08) : Colors.white.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isMe ? Colors.white.withOpacity(0.18) : AppColors.error.withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: Text(
                  code.trim(),
                  style: AppTypography.bodySmall.copyWith(
                    color: isMe ? Colors.white.withOpacity(0.92) : AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceMessageContent(voice.VoiceMessage voiceMessage, String messageId, bool isMe) {
    final provider = context.watch<ChatProvider>();
    // For now, we'll use a simple check - if any voice message is playing
    // TODO: Add message ID tracking in ChatProvider for more accurate tracking
    final isPlaying = provider.isPlaying;
    
    return EnhancedVoiceMessageView(
      voiceMessage: voiceMessage,
      isMe: isMe,
      isPlaying: isPlaying,
      currentPosition: null, // TODO: Add position tracking if needed
      onPlay: () => _playVoiceMessage(voiceMessage),
      onPause: () => provider.stopPlayback(),
    );
  }

  void _showSenderInfoModal(String senderName) {
    showDialog(
      context: context,
      builder: (context) => SenderInfoModal(senderName: senderName),
    );
  }

  Widget _buildMessageStatus(voice.MessageStatus status, bool isRead) {
    return EnhancedMessageStatus(
      status: status,
      isRead: isRead,
      onRetry: status == voice.MessageStatus.failed
          ? () {
              // TODO: Implement retry logic for failed messages
              // You can access the message from the parent widget if needed
            }
          : null,
      iconColor: Colors.white70,
      size: 16.0,
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (messageDate == today) {
      return AppTimeFormat.time(dateTime);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${AppTimeFormat.time(dateTime)}';
    } else {
      return AppTimeFormat.monthDayTime(dateTime);
    }
  }

  Widget _buildPinnedEmergencyAlert(ChatMessage message) {
    return GestureDetector(
      onTap: () => _showPinnedEmergencyDetails(message),
      child: Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.error.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Decorative background pattern
            Positioned(
              right: -20,
              top: -20,
              child: Icon(
                Icons.sos_rounded,
                size: 100,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ).animate(onPlay: (c) => c.repeat(reverse: true))
                   .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 1.seconds),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'PINNED EMERGENCY',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _formatDateTime(message.timestamp),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    ).animate().slideY(begin: -0.2, end: 0, curve: Curves.easeOutBack).fade();
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
      // Bottom input panel (kept subtle because the nav is floating)
      child: SafeArea(
        top: false,
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                          if (provider.isRecording) ...[
                            const Icon(
                              Icons.mic_rounded,
                              color: AppColors.error,
                              size: 16,
                            ),
                            const SizedBox(width: 10),
                            _MiniWaveform(
                              stream: provider.voiceExtension.inputLevelStream,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 10),
                          ] else ...[
                            const Icon(Icons.volume_up, color: AppColors.success, size: 16),
                            const SizedBox(width: 8),
                          ],
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

              // Sending voice progress (UI only; driven by VoiceChatExtension chunk loop)
              StreamBuilder<bool>(
                stream: context.read<ChatProvider>().voiceExtension.sendingStream,
                initialData: false,
                builder: (context, snapshot) {
                  final isSending = snapshot.data ?? false;
                  if (!isSending) return const SizedBox.shrink();

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: SoftUIDesign.cardDecoration(
                      backgroundColor: AppColors.primaryRed.withOpacity(0.06),
                      borderRadius: SoftUIDesign.buttonBorderRadius,
                      elevation: 2.0,
                      borderColor: AppColors.primaryRed.withOpacity(0.22),
                      showBorder: true,
                    ),
                    child: StreamBuilder<double>(
                      stream: context.read<ChatProvider>().voiceExtension.sendingProgressStream,
                      initialData: 0.0,
                      builder: (context, pSnap) {
                        final progress = (pSnap.data ?? 0.0).clamp(0.0, 1.0);
                        final pct = (progress * 100).round();
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.upload_rounded, color: AppColors.primaryRed, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Sending voice… $pct%',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.primaryRed,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                backgroundColor: AppColors.primaryRed.withOpacity(0.12),
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryRed),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
              
              // Input row
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  // Less glass: lower blur, more solid surface
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.98),
                          Colors.white.withOpacity(0.94),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withOpacity(0.55), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                          spreadRadius: -6,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Voice recording button (kept hold behavior)
                        Consumer<ChatProvider>(
                          builder: (context, provider, _) {
                            final isRec = provider.isRecording;
                            final color = isRec ? AppColors.error : AppColors.online;
                            final canRecord = provider.isConnected;
                            return GestureDetector(
                              onTapDown: (_) {
                                _isMicPressed = true;
                                if (canRecord) {
                                  _startRecording();
                                } else {
                                  _startRecording(); // shows snackbar feedback
                                }
                              },
                              onTapUp: (_) async {
                                _isMicPressed = false;
                                await _stopRecording(force: true);
                              },
                              onTapCancel: () async {
                                _isMicPressed = false;
                                await _stopRecording(force: true);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      color.withOpacity(canRecord ? 0.95 : 0.45),
                                      color.withOpacity(canRecord ? 0.75 : 0.35),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withOpacity(canRecord ? 0.25 : 0.10),
                                      blurRadius: 16,
                                      offset: const Offset(0, 8),
                                      spreadRadius: -6,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isRec ? Icons.stop_rounded : Icons.mic_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(width: 10),

                        // Text input
                        Expanded(
                          child: Container(
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.98),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.lightGray.withOpacity(0.35),
                                width: 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: TextField(
                              controller: _messageController,
                              decoration: InputDecoration(
                                hintText: 'Type a message...',
                                hintStyle: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textSecondary.withOpacity(0.55),
                                  fontWeight: FontWeight.w600,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        // Send button (visual enabled/disabled without changing logic)
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _messageController,
                          builder: (context, value, _) {
                            final hasText = value.text.trim().isNotEmpty;
                            final base = AppColors.primaryRed;
                            return GestureDetector(
                              onTap: _sendMessage,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      base.withOpacity(hasText ? 0.98 : 0.55),
                                      base.withOpacity(hasText ? 0.82 : 0.45),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: base.withOpacity(hasText ? 0.28 : 0.12),
                                      blurRadius: 16,
                                      offset: const Offset(0, 8),
                                      spreadRadius: -6,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _pinnedRefreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _debugScrollController.dispose();
    super.dispose();
  }

}

class _MiniWaveform extends StatelessWidget {
  final Stream<double> stream;
  final Color color;
  const _MiniWaveform({required this.stream, required this.color});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: stream,
      initialData: 0.0,
      builder: (context, snapshot) {
        final v = (snapshot.data ?? 0.0).clamp(0.0, 1.0);
        // Create a pleasing "wave" by phase shifting bars
        final bars = <double>[
          (v * 0.70).clamp(0.0, 1.0),
          (v * 0.90).clamp(0.0, 1.0),
          (v * 1.10).clamp(0.0, 1.0),
          (v * 0.95).clamp(0.0, 1.0),
          (v * 0.75).clamp(0.0, 1.0),
        ];

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: bars.map((t) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                curve: Curves.easeOutCubic,
                width: 3.5,
                height: 6 + 14 * t,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

/// Device Selection Dialog with Polished UI
class _DeviceSelectionDialog extends StatefulWidget {
  @override
  State<_DeviceSelectionDialog> createState() => _DeviceSelectionDialogState();
}

class _DeviceSelectionDialogState extends State<_DeviceSelectionDialog> {
  bool _showAllDevices = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadPairedDevices();
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  List<dynamic> _filterPairedDevices(List<dynamic> devices) {
    if (_searchQuery.isEmpty) return devices;
    return devices.where((device) {
      try {
        final name = (device?.name ?? '').toString().toLowerCase();
        final address = (device?.address ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || address.contains(query);
      } catch (e) {
        return false;
      }
    }).toList();
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
                                    : (provider.selectedDevice != null
                                        ? 'Disconnected'
                                        : 'Not Connected'),
                                style: AppTypography.bodyLarge.copyWith(
                                  color: provider.isConnected 
                                      ? cyanBlue 
                                      : (provider.selectedDevice != null 
                                          ? Colors.orange 
                                          : Colors.grey),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                provider.isConnected 
                                    ? 'Device: ${provider.selectedDevice?.name ?? "ESP32"}' 
                                    : (provider.selectedDevice != null
                                        ? 'Disconnected from ${provider.selectedDevice?.name ?? "ESP32"}\nTap "Reconnect" to connect again'
                                        : 'No device connected'),
                                style: AppTypography.bodySmall.copyWith(
                                  color: provider.isConnected 
                                      ? AppColors.mediumGray 
                                      : (provider.selectedDevice != null 
                                          ? Colors.orange.shade700 
                                          : AppColors.mediumGray),
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
                      ElevatedButton(
                        onPressed: provider.isConnecting ? null : () {
                          provider.loadPairedDevices();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cyanBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(provider.isConnecting ? 'Connecting...' : 'Refresh'),
                            const SizedBox(width: 8),
                            if (provider.isConnecting)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            else
                              const Icon(Icons.refresh, size: 18),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Search Bar
                if (provider.pairedDevices.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search paired devices...',
                        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                },
                                color: AppColors.textSecondary,
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.backgroundLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.lightGray),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.lightGray),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: cyanBlue, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                if (provider.pairedDevices.isNotEmpty) const SizedBox(height: 16),
                
                // Device list
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final filteredDevices = _filterPairedDevices(provider.pairedDevices);
                      
                      if (filteredDevices.isEmpty && _searchQuery.isNotEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 64,
                                  color: Colors.grey.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No devices match "$_searchQuery"',
                                  style: AppTypography.bodyLarge.copyWith(
                                    color: AppColors.mediumGray,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      if (provider.pairedDevices.isEmpty) {
                        return Center(
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
                        );
                      }
                      
                      return Column(
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
                                      ? filteredDevices.length 
                                      : (filteredDevices.length > 5 ? 5 : filteredDevices.length),
                                  itemBuilder: (context, index) {
                                    final device = filteredDevices[index];
                                    final isSelected = provider.selectedDevice?.address == device.address;
                                    final isConnected = provider.isConnected && isSelected;
                                    final wasDisconnected = isSelected && !provider.isConnected; // Previously connected but now disconnected
                                    
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isConnected 
                                              ? cyanBlue.withOpacity(0.5) 
                                              : (wasDisconnected 
                                                  ? Colors.orange.withOpacity(0.4) // Orange border for disconnected devices
                                                  : (isSelected 
                                                      ? cyanBlue.withOpacity(0.3) 
                                                      : Colors.grey.withOpacity(0.2))),
                                          width: isConnected || wasDisconnected || isSelected ? 1.5 : 1,
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
                                                  : (wasDisconnected
                                                      ? [Colors.orange.withOpacity(0.3), Colors.orange.withOpacity(0.1)]
                                                      : [Colors.grey.withOpacity(0.3), Colors.grey.withOpacity(0.1)]),
                                            ),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            isConnected 
                                                ? Icons.bluetooth_connected 
                                                : (wasDisconnected ? Icons.bluetooth_disabled : Icons.bluetooth),
                                            color: isConnected 
                                                ? Colors.white 
                                                : (wasDisconnected ? Colors.orange : AppColors.mediumGray),
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
                                                onPressed: () async {
                                                  await provider.disconnect();
                                                  if (mounted) {
                                                    setState(() {}); // Refresh UI
                                                  }
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                                child: const Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text('Disconnect'),
                                                    SizedBox(width: 8),
                                                    Icon(Icons.bluetooth_disabled, size: 18),
                                                  ],
                                                ),
                                              )
                                            : ElevatedButton(
                                                onPressed: provider.isConnecting ? null : () async {
                                                  HapticFeedback.mediumImpact();
                                                  bool success = await provider.connectToDevice(device);
                                                  if (success && mounted) {
                                                    HapticFeedback.heavyImpact();
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Row(
                                                          children: [
                                                            const Icon(Icons.check_circle, color: Colors.white, size: 20),
                                                            const SizedBox(width: 8),
                                                            Text('Connected to ${device.name ?? "ESP32"}'),
                                                          ],
                                                        ),
                                                        backgroundColor: Colors.green,
                                                        behavior: SnackBarBehavior.floating,
                                                        duration: const Duration(seconds: 2),
                                                      ),
                                                    );
                                                    await Future.delayed(const Duration(milliseconds: 500));
                                                    Navigator.pop(context);
                                                  } else if (mounted) {
                                                    HapticFeedback.heavyImpact();
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Row(
                                                          children: [
                                                            const Icon(Icons.error, color: Colors.white, size: 20),
                                                            const SizedBox(width: 8),
                                                            const Text('Failed to connect. Please try again.'),
                                                          ],
                                                        ),
                                                        backgroundColor: Colors.red,
                                                        behavior: SnackBarBehavior.floating,
                                                        duration: const Duration(seconds: 3),
                                                      ),
                                                    );
                                                  }
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: wasDisconnected ? Colors.orange : cyanBlue,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      provider.isConnecting 
                                                          ? 'Connecting...' 
                                                          : (wasDisconnected ? 'Reconnect' : 'Connect'),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Icon(
                                                      wasDisconnected ? Icons.refresh : Icons.bluetooth,
                                                      size: 18,
                                                    ),
                                                  ],
                                                ),
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
                                child: TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _showAllDevices = true;
                                    });
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Show more (${provider.pairedDevices.length - 5} more devices)',
                                        style: AppTypography.bodyMedium.copyWith(
                                          color: cyanBlue,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.expand_more, color: cyanBlue),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            
                            // Show less button
                            if (_showAllDevices && filteredDevices.length > 5) ...[
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _showAllDevices = false;
                                    });
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Show less',
                                        style: AppTypography.bodyMedium.copyWith(
                                          color: cyanBlue,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.expand_less, color: cyanBlue),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                    },
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


