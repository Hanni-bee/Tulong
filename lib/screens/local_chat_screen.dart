import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../constants/soft_ui_design.dart';
import '../utils/theme_colors.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../services/voice_chat_extension.dart' as voice;
import '../widgets/unified_top_bar.dart';
import '../widgets/connected_users_list_modal.dart';
import '../widgets/sender_info_modal.dart';
import '../widgets/enhanced_skeleton_loaders.dart';
import '../widgets/enhanced_empty_state.dart';
import '../widgets/accessible_text.dart';
import '../widgets/enhanced_message_status.dart';
import '../widgets/enhanced_voice_message_view.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';

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
  
  // Pinned banner timer management (30 seconds display duration)
  static const Duration _pinnedRetention = Duration(days: 1); // For history (24 hours)
  static const Duration _pinnedBannerDuration = Duration(seconds: 30); // For banner display
  Timer? _pinnedBannerCheckTimer; // Periodic timer to check every second
  Timer? _pinnedBannerHideTimer; // One-time timer for 30-second hide
  Timer? _pinnedRefreshTimer;
  DateTime? _pinnedBannerStartTime;
  bool _isPinnedBannerAnimatingOut = false;

  @override
  void initState() {
    super.initState();
    
    // Keep pinned banner/history time-window accurate while the screen stays open
    _pinnedRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
    
    // Check for pinned banner timer every second
    _pinnedBannerCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _checkPinnedBannerTimer();
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final chatProvider = context.read<ChatProvider>();
      
      // Mark chat screen as visible and mark all messages as read
      chatProvider.setLocalChatScreenVisible(true);
      chatProvider.markAllMessagesAsRead();
      
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
      
      // Final fallback to username
      if (userName == null || userName.isEmpty) {
        userName = authProvider.userUsername ?? 'Me';
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
  
  void _startPinnedBannerTimer(DateTime messageTimestamp) {
    _pinnedBannerStartTime = messageTimestamp;
    _isPinnedBannerAnimatingOut = false;
    
    // Clear existing hide timer
    _pinnedBannerHideTimer?.cancel();
    
    // Start 30-second timer to hide banner
    _pinnedBannerHideTimer = Timer(_pinnedBannerDuration, () {
      if (!mounted) return;
      setState(() {
        _isPinnedBannerAnimatingOut = true;
      });
      
      // After outro animation completes, hide banner
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() {
          _isPinnedBannerAnimatingOut = false;
        });
      });
    });
  }
  
  void _checkPinnedBannerTimer() {
    if (_pinnedBannerStartTime == null) return;
    
    final now = DateTime.now();
    final elapsed = now.difference(_pinnedBannerStartTime!);
    
    if (elapsed >= _pinnedBannerDuration && !_isPinnedBannerAnimatingOut) {
      setState(() {
        _isPinnedBannerAnimatingOut = true;
      });
      
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() {
          _isPinnedBannerAnimatingOut = false;
        });
      });
    }
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

  void _showConnectedUsersModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => const ConnectedUsersListModal(),
    );
  }

  // UI-only: Check if message is SOS emergency
  bool _isSosEmergencyMessage(ChatMessage message) {
    if (!message.isEmergency) return false;
    // Check source from rawData first (matches UI branch)
    final source = message.rawData?['source']?.toString();
    if (source == 'sos') return true;
    // Fallback heuristic for older/legacy SOS payloads
    return message.isMe && message.text.contains('🚨');
  }

  // UI-only: Get SOS emergency history (last 24 hours)
  List<ChatMessage> _getSosEmergencyHistory(List<ChatMessage> messages) {
    final now = DateTime.now();
    final list = messages
        .where((m) => _isSosEmergencyMessage(m) && now.difference(m.timestamp) < _pinnedRetention)
        .toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  // UI-only: Build pinned history button for top bar
  Widget _buildPinnedHistoryButton() {
    final provider = context.watch<ChatProvider>();
    final pinnedCount = _getSosEmergencyHistory(provider.messages).length;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showPinnedHistoryModal,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: 'Pinned SOS history',
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.error.withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.error.withOpacity(0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.push_pin_rounded,
                  color: AppColors.error,
                  size: 22,
                ),
              ),
              if (pinnedCount > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Center(
                      child: Text(
                        pinnedCount > 9 ? '9+' : pinnedCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
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

  // UI-only: Show pinned SOS history modal
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
            color: ThemeColors.surface(ctx),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: ThemeColors.shadow(ctx, opacity: 0.18),
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
                      color: ThemeColors.textTertiary(ctx),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Pinned SOS History',
                  style: AppTypography.titleMedium.copyWith(
                    color: ThemeColors.textPrimary(ctx),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.history,
                          size: 48,
                          color: ThemeColors.textTertiary(ctx),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No SOS history',
                          style: AppTypography.bodyMedium.copyWith(
                            color: ThemeColors.textSecondary(ctx),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final message = items[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: ThemeColors.error(context).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: ThemeColors.error(context).withOpacity(0.25),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.emergency,
                                    size: 16,
                                    color: ThemeColors.error(context),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      message.senderName ?? 'Unknown',
                                      style: AppTypography.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: ThemeColors.error(context),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    DateFormat('MMM d, h:mm a').format(message.timestamp),
                                    style: AppTypography.bodySmall.copyWith(
                                      color: ThemeColors.textSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                message.text,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: ThemeColors.textPrimary(ctx),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.background(context),
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
                  onBluetoothTap: () {
                    // Bluetooth tap handler - can be used for future features
                  },
                  onConnectedTap: () {
                    if (provider.isConnected) {
                      _showConnectedUsersModal();
                    }
                    // Removed radar modal - now on home screen
                  },
                  additionalActions: [
                    const SizedBox(width: 8),
                    _buildPinnedHistoryButton(),
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
                  
                  // Find the latest SOS emergency message (for pinned banner)
                  final now = DateTime.now();
                  ChatMessage? latestEmergency;
                  for (final m in provider.messages.reversed) {
                    if (!_isSosEmergencyMessage(m)) continue;
                    if (now.difference(m.timestamp) >= _pinnedRetention) continue;
                    latestEmergency = m;
                    break;
                  }
                  
                  // Check if this is a new emergency message (not the one currently showing)
                  final hasActiveEmergency = latestEmergency != null;
                  ChatMessage? currentEmergency = latestEmergency;
                  final isNewEmergency = hasActiveEmergency && 
                      (_pinnedBannerStartTime == null || 
                       (currentEmergency != null && currentEmergency.timestamp.isAfter(_pinnedBannerStartTime!)));
                  
                  // Start timer for new emergency
                  if (isNewEmergency && !_isPinnedBannerAnimatingOut && currentEmergency != null) {
                    _startPinnedBannerTimer(currentEmergency.timestamp);
                  }
                  
                  // Check if banner should be visible (within 30 seconds)
                  final shouldShowBanner = hasActiveEmergency && 
                      !_isPinnedBannerAnimatingOut &&
                      (_pinnedBannerStartTime == null || 
                       now.difference(_pinnedBannerStartTime!) < _pinnedBannerDuration);
                  
                  // Show messages with refresh indicator overlay
                  final regularMessages = provider.messages.where((msg) => !msg.isPinned).toList();
                  
                  return Column(
                    children: [
                      // Pinned Emergency Alert (only show for 30 seconds)
                      if (shouldShowBanner && currentEmergency != null)
                        _buildPinnedEmergencyAlert(currentEmergency),
                      
                      Expanded(
                        child: Stack(
                          children: [
                            ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16),
                              itemCount: regularMessages.length + (provider.isTyping ? 1 : 0),
                              itemBuilder: (context, index) {
                                // Show typing indicator at the end
                                if (index == regularMessages.length && provider.isTyping) {
                                  return _buildTypingIndicator();
                                }
                                
                                // Show regular messages
                                if (index < regularMessages.length) {
                                  final message = regularMessages[index];
                                  // Auto-scroll to bottom when new messages arrive
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (_scrollController.hasClients && index == regularMessages.length - 1) {
                                      _scrollController.animateTo(
                                        _scrollController.position.maxScrollExtent,
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeOut,
                                      );
                                    }
                                  });
                                  return _buildMessageBubble(message);
                                }
                                
                                return const SizedBox.shrink();
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
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  /// Build pinned emergency alert - Shows for 30 seconds only
  /// Compact red banner design matching UI branch
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
    )
    .animate()
    .fadeIn(duration: 300.ms)
    .slideY(begin: -0.1, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
  
  void _showPinnedEmergencyDetails(ChatMessage message) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
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
                Text(
                  'Pinned Emergency',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message.text,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Sent ${_formatDateTime(message.timestamp)}',
                  style: AppTypography.bodySmall.copyWith(
                    color: ThemeColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
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
    final row = Row(
        mainAxisAlignment: message.isMe 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        children: [
          if (!message.isMe) ...[
            GestureDetector(
              onTap: (message.senderUid != null && message.senderUid!.isNotEmpty) ||
                     (message.senderName != null && message.senderName!.isNotEmpty)
                  ? () {
                      _showSenderInfoModal(
                        senderUid: message.senderUid,
                        senderName: message.senderName,
                      );
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
            padding: EdgeInsets.symmetric(
              horizontal: isEmergency ? 18 : 16,
              vertical: isEmergency ? 14 : 12,
            ),
            decoration: BoxDecoration(
              color: isEmergency
                  ? (message.isMe ? AppColors.error : AppColors.error.withOpacity(0.18))
                  : (message.isMe ? AppColors.primaryRed : ThemeColors.surface(context)),
              borderRadius: BorderRadius.circular(20).copyWith(
                bottomLeft: message.isMe ? const Radius.circular(20) : const Radius.circular(4),
                bottomRight: message.isMe ? const Radius.circular(4) : const Radius.circular(20),
              ),
              border: Border.all(
                color: isEmergency
                    ? AppColors.error.withOpacity(0.8)
                    : (message.isMe 
                        ? Colors.white.withOpacity(0.2)
                        : AppColors.lightGray.withOpacity(0.5)),
                width: isEmergency ? 2.5 : 1.5,
              ),
              boxShadow: isEmergency ? [
                BoxShadow(
                  color: AppColors.error.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ] : null,
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
                          message.text,
                          style: AppTypography.bodyLarge.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: message.isMe ? Colors.white : AppColors.error,
                            height: 1.25,
                          ),
                        )
                      : AccessibleChatText(
                          message.text,
                          isMe: message.isMe,
                          backgroundColor: message.isMe
                              ? AppColors.primaryRed
                              : ThemeColors.surface(context),
                          maxLines: null,
                        ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatDateTime(message.timestamp),
                      style: AppTypography.bodySmall.copyWith(
                        color: isEmergency
                            ? (message.isMe ? Colors.white70 : AppColors.error.withOpacity(0.8))
                            : (message.isMe ? Colors.white70 : AppColors.lightGray),
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
      );
    if (isEmergency) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: row
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scale(begin: const Offset(1, 1), end: const Offset(1.02, 1.02), duration: 1600.ms, curve: Curves.easeInOut),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: row,
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

  void _showSenderInfoModal({String? senderUid, String? senderName}) {
    showDialog(
      context: context,
      builder: (context) => SenderInfoModal(
        senderUid: senderUid,
        senderName: senderName,
      ),
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
        context: context,
        backgroundColor: ThemeColors.surface(context),
        borderRadius: 0,
        elevation: 3.0,
        borderColor: ThemeColors.border(context),
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
                        context: context,
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
                            context: context,
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
                        context: context,
                        backgroundColor: ThemeColors.surface(context),
                        borderRadius: 24.0,
                        elevation: 2.0,
                        borderColor: ThemeColors.border(context),
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
    // Mark chat screen as not visible
    final chatProvider = context.read<ChatProvider>();
    chatProvider.setLocalChatScreenVisible(false);
    
    // Cancel timers
    _pinnedBannerCheckTimer?.cancel();
    _pinnedBannerHideTimer?.cancel();
    _pinnedRefreshTimer?.cancel();
    
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isBluetoothEnabled = true;
  bool _isCheckingBluetooth = true;
  
  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    _checkBluetoothState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isBluetoothEnabled) {
        context.read<ChatProvider>().loadPairedDevices();
      }
    });
  }

  Future<void> _checkBluetoothState() async {
    try {
      final isEnabled = await FlutterBluetoothSerial.instance.isOn;
      if (mounted) {
        setState(() {
          _isBluetoothEnabled = isEnabled ?? false;
          _isCheckingBluetooth = false;
        });
        // Reload devices if Bluetooth is enabled
        if (_isBluetoothEnabled) {
          context.read<ChatProvider>().loadPairedDevices();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBluetoothEnabled = false;
          _isCheckingBluetooth = false;
        });
      }
    }
  }

  Future<void> _requestEnableBluetooth() async {
    try {
      // Request to enable Bluetooth
      await FlutterBluetoothSerial.instance.requestEnable();
      // Wait a bit then check again
      await Future.delayed(const Duration(milliseconds: 500));
      await _checkBluetoothState();
    } catch (e) {
      // User cancelled or error occurred
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please enable Bluetooth in Settings'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
          color: ThemeColors.surface(context),
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
                // Modern Header with Gradient - Changes color when Bluetooth is off
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _isBluetoothEnabled
                          ? [
                              cyanBlue,
                              cyanBlue.withOpacity(0.8),
                            ]
                          : [
                              Colors.orange,
                              Colors.orange.withOpacity(0.8),
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
                        child: Icon(
                          _isBluetoothEnabled ? Icons.bluetooth : Icons.bluetooth_disabled,
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
                              _isBluetoothEnabled
                                  ? 'Select an ESP32 device to connect'
                                  : 'Bluetooth is turned off',
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
                
                // Connection Status Card - Shows Bluetooth off state
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: _isCheckingBluetooth
                      ? Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _isBluetoothEnabled
                                ? (provider.isConnected 
                                    ? cyanBlue.withOpacity(0.1) 
                                    : Colors.grey.withOpacity(0.1))
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _isBluetoothEnabled
                                  ? (provider.isConnected 
                                      ? cyanBlue.withOpacity(0.3) 
                                      : Colors.grey.withOpacity(0.3))
                                  : Colors.orange.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _isBluetoothEnabled
                                      ? (provider.isConnected 
                                          ? cyanBlue.withOpacity(0.2) 
                                          : Colors.grey.withOpacity(0.2))
                                      : Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _isBluetoothEnabled
                                      ? (provider.isConnected 
                                          ? Icons.bluetooth_connected 
                                          : Icons.bluetooth_disabled)
                                      : Icons.bluetooth_disabled,
                                  color: _isBluetoothEnabled
                                      ? (provider.isConnected ? cyanBlue : Colors.grey)
                                      : Colors.orange,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isBluetoothEnabled
                                          ? (provider.isConnected 
                                              ? 'Connected' 
                                              : (provider.selectedDevice != null
                                                  ? 'Disconnected'
                                                  : 'Not Connected'))
                                          : 'Bluetooth Off',
                                      style: AppTypography.bodyLarge.copyWith(
                                        color: _isBluetoothEnabled
                                            ? (provider.isConnected 
                                                ? cyanBlue 
                                                : (provider.selectedDevice != null 
                                                    ? Colors.orange 
                                                    : Colors.grey))
                                            : Colors.orange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _isBluetoothEnabled
                                          ? (provider.isConnected 
                                              ? 'Device: ${provider.selectedDevice?.name ?? "ESP32"}' 
                                              : (provider.selectedDevice != null
                                                  ? 'Disconnected from ${provider.selectedDevice?.name ?? "ESP32"}\nTap "Reconnect" to connect again'
                                                  : 'No device connected'))
                                          : 'Please enable Bluetooth to connect',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: _isBluetoothEnabled
                                            ? (provider.isConnected 
                                                ? AppColors.mediumGray 
                                                : (provider.selectedDevice != null 
                                                    ? Colors.orange.shade700 
                                                    : AppColors.mediumGray))
                                            : AppColors.mediumGray,
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
                
                // Search Bar
                if (provider.pairedDevices.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search paired devices...',
                        prefixIcon: Icon(Icons.search, color: ThemeColors.textSecondary(context), size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  _searchController.clear();
                                },
                                color: ThemeColors.textSecondary(context),
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
                
                // Device list or Bluetooth off message
                Expanded(
                  child: !_isBluetoothEnabled
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
                                      color: Colors.orange.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.bluetooth_disabled,
                                      size: 64,
                                      color: Colors.orange,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Bluetooth is Turned Off',
                                    style: AppTypography.headlineSmall.copyWith(
                                      color: AppColors.darkGray,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Please enable Bluetooth to connect to ESP32 devices',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.mediumGray,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: _requestEnableBluetooth,
                                    icon: const Icon(Icons.bluetooth, size: 20),
                                    label: const Text('Enable Bluetooth'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : Builder(
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
                                            ? ElevatedButton.icon(
                                                onPressed: () async {
                                                  await provider.disconnect();
                                                  if (mounted) {
                                                    setState(() {}); // Refresh UI
                                                  }
                                                },
                                                icon: const Icon(Icons.bluetooth_disabled, size: 18),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                                label: const Text('Disconnect'),
                                              )
                                            : ElevatedButton.icon(
                                                onPressed: provider.isConnecting ? null : () async {
                                                  HapticFeedback.mediumImpact();
                                                  bool success = await provider.connectToDevice(device, context: context);
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
                                                icon: Icon(
                                                  wasDisconnected ? Icons.refresh : Icons.bluetooth,
                                                  size: 18,
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: wasDisconnected ? Colors.orange : cyanBlue,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                ),
                                                label: Text(
                                                  provider.isConnecting 
                                                      ? 'Connecting...' 
                                                      : (wasDisconnected ? 'Reconnect' : 'Connect'),
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
                            if (_showAllDevices && filteredDevices.length > 5) ...[
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


