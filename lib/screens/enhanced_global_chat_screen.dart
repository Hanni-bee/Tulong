import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../widgets/modern_message_bubble.dart';
import '../widgets/interactive_gestures.dart';
import '../widgets/modern_shimmer_loading.dart';
import '../utils/neumorphic_utils.dart';

class EnhancedGlobalChatScreen extends StatefulWidget {
  const EnhancedGlobalChatScreen({super.key});

  @override
  State<EnhancedGlobalChatScreen> createState() => _EnhancedGlobalChatScreenState();
}

class _EnhancedGlobalChatScreenState extends State<EnhancedGlobalChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  
  bool _isTyping = false;
  final bool _isConnected = true;
  final String _typingUser = '';
  
  late AnimationController _sendButtonController;
  late Animation<double> _sendButtonScale;

  // Sample global chat messages (SAME AS YOUR BACKEND WOULD PROVIDE)
  final List<Map<String, dynamic>> _messages = [
    {
      'id': '1',
      'text': 'Power\'s out. You safe?',
      'senderId': 'user2',
      'senderName': 'User 2',
      'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
      'isEmergency': false,
      'isRead': true,
    },
    {
      'id': '2',
      'text': 'Yeah, weak signal. Where are you?',
      'senderId': 'user1',
      'senderName': 'User 1',
      'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
      'isEmergency': false,
      'isRead': true,
    },
    {
      'id': '3',
      'text': 'At barangay hall. Roads flooded?',
      'senderId': 'user2',
      'senderName': 'User 2',
      'timestamp': DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
      'isEmergency': false,
      'isRead': true,
    },
    {
      'id': '4',
      'text': 'EMERGENCY: Need medical help at Zone 5!',
      'senderId': 'user3',
      'senderName': 'User 3',
      'timestamp': DateTime.now().subtract(const Duration(minutes: 30)),
      'isEmergency': true,
      'isRead': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    
    _sendButtonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _sendButtonScale = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _sendButtonController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _sendButtonController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText != _isTyping) {
      setState(() => _isTyping = hasText);
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.mediumImpact();
    _sendButtonController.forward().then((_) => _sendButtonController.reverse());

    // TODO: Replace with YOUR Firebase/Backend sendMessage function
    setState(() {
      _messages.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'text': text,
        'senderId': 'currentUser',
        'senderName': 'Me',
        'timestamp': DateTime.now(),
        'isEmergency': false,
        'isRead': false,
      });
      _messageController.clear();
    });

    // Auto scroll to bottom
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

  void _deleteMessage(String messageId) {
    HapticFeedback.mediumImpact();
    // TODO: Replace with YOUR Firebase/Backend deleteMessage function
    setState(() {
      _messages.removeWhere((msg) => msg['id'] == messageId);
    });
  }

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check, color: Colors.white),
            SizedBox(width: 8),
            Text('Message copied'),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neumorphicBase,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Connection status banner
          if (!_isConnected) _buildOfflineBanner(),

          // Messages list with pull to refresh
          Expanded(
            child: CustomPullToRefresh(
              onRefresh: () async {
                // TODO: Replace with YOUR Firebase/Backend refreshMessages function
                await Future.delayed(const Duration(seconds: 1));
                HapticFeedback.mediumImpact();
              },
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                physics: const BouncingScrollPhysics(),
                itemCount: _messages.length + (_typingUser.isNotEmpty ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _typingUser.isNotEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Text(
                            '$_typingUser is typing',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 30,
                            height: 12,
                            child: ThreeDotsLoading(dotSize: 6),
                          ),
                        ],
                      ),
                    );
                  }

                  final message = _messages[index];
                  final isMe = message['senderId'] == 'currentUser';
                  
                  // SWIPEABLE MESSAGE WITH LONG PRESS MENU
                  return LongPressMenu(
                    actions: [
                      if (isMe)
                        MenuAction(
                          icon: Icons.delete,
                          label: 'Delete',
                          color: AppColors.error,
                          onTap: () => _deleteMessage(message['id']),
                        ),
                      MenuAction(
                        icon: Icons.copy,
                        label: 'Copy',
                        onTap: () => _copyMessage(message['text']),
                      ),
                    ],
                    child: SwipeableCard(
                      onSwipeLeft: isMe ? () => _deleteMessage(message['id']) : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: ModernMessageBubble(
                          text: message['text'],
                          senderName: message['senderName'],
                          timestamp: message['timestamp'],
                          isMe: isMe,
                          isEmergency: message['isEmergency'] ?? false,
                          isRead: message['isRead'] ?? false,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Input area with modern design
          _buildMessageInput(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.neumorphicBase,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Global Chat',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isConnected ? AppColors.success : AppColors.offline,
                  shape: BoxShape.circle,
                  boxShadow: _isConnected
                      ? [
                          BoxShadow(
                            color: AppColors.success.withOpacity(0.5),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _isConnected ? 'Connected' : 'Offline',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: const [
        SizedBox(width: 8),
      ],
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.2),
        border: Border(
          bottom: BorderSide(
            color: AppColors.warning.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.cloud_off, size: 16, color: AppColors.warning),
          SizedBox(width: 8),
          Text(
            'Offline - Messages will sync when connected',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.neumorphicDark.withOpacity(0.1),
            offset: const Offset(0, -2),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Text input with neumorphic design
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.neumorphicBase,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: NeumorphicUtils.getInnerShadow(depth: 2),
                ),
                child: TextField(
                  controller: _messageController,
                  focusNode: _focusNode,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Send button with animation
            AnimatedBuilder(
              animation: _sendButtonScale,
              builder: (context, child) {
                return Transform.scale(
                  scale: _sendButtonScale.value,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: _isTyping
                          ? NeumorphicUtils.getModernGradient()
                          : null,
                      color: _isTyping ? null : AppColors.mediumGray.withOpacity(0.3),
                      shape: BoxShape.circle,
                      boxShadow: _isTyping
                          ? [
                              BoxShadow(
                                color: AppColors.primaryRed.withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: _isTyping ? _sendMessage : null,
                        child: Icon(
                          Icons.send,
                          color: _isTyping ? Colors.white : AppColors.mediumGray,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

