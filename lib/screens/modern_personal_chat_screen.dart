import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/navigation_helper.dart';
import '../utils/performance_optimizer.dart';
import '../widgets/modern_message_bubble.dart';
import '../widgets/typing_indicator.dart';
import 'private_call_screen.dart';

class ModernPersonalChatScreen extends StatefulWidget {
  final String contactName;
  final String contactId;
  final String? contactAvatar;
  final bool isOnline;

  const ModernPersonalChatScreen({
    super.key,
    required this.contactName,
    required this.contactId,
    this.contactAvatar,
    this.isOnline = true,
  });

  @override
  State<ModernPersonalChatScreen> createState() => _ModernPersonalChatScreenState();
}

class _ModernPersonalChatScreenState extends State<ModernPersonalChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  bool _contactIsTyping = false;
  
  // Sample messages for this contact
  late final List<Map<String, dynamic>> _messages;

  @override
  void initState() {
    super.initState();
    _messages = [
      {
        'id': '1',
        'text': 'Hey, how are you doing?',
        'senderId': 'me',
        'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
        'isMe': true,
        'isRead': true,
      },
      {
        'id': '2',
        'text': 'I\'m doing well, thanks for asking! How about you?',
        'senderId': widget.contactId,
        'timestamp': DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
        'isMe': false,
        'isRead': true,
      },
      {
        'id': '3',
        'text': 'All good here. Just checking in during this emergency situation.',
        'senderId': 'me',
        'timestamp': DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
        'isMe': true,
        'isRead': true,
      },
      {
        'id': '4',
        'text': 'Thanks for checking. Stay safe out there!',
        'senderId': widget.contactId,
        'timestamp': DateTime.now().subtract(const Duration(minutes: 30)),
        'isMe': false,
        'isRead': true,
      },
    ];
    
    _messageController.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_messageController.text.isNotEmpty && !_isTyping) {
      setState(() {
        _isTyping = true;
      });
      
      // Simulate contact typing back
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _contactIsTyping = true;
          });
          
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _contactIsTyping = false;
                _isTyping = false;
              });
            }
          });
        }
      });
    } else if (_messageController.text.isEmpty) {
      setState(() {
        _isTyping = false;
        _contactIsTyping = false;
      });
    }
  }

  void _onScroll() {
    // Auto-hide typing indicator when scrolling
    if (_isTyping || _contactIsTyping) {
      setState(() {
        _isTyping = false;
        _contactIsTyping = false;
      });
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      setState(() {
        _messages.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'text': _messageController.text.trim(),
          'senderId': 'me',
          'timestamp': DateTime.now(),
          'isMe': true,
          'isRead': false,
        });
      });
      _messageController.clear();
      
      // Auto-scroll to bottom
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
  }

  void _sendEmergencyMessage() {
    setState(() {
      _messages.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'text': '🚨 EMERGENCY: I need immediate assistance!',
        'senderId': 'me',
        'timestamp': DateTime.now(),
        'isMe': true,
        'isEmergency': true,
        'isRead': false,
      });
    });
    
    // Auto-scroll to bottom
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

  void _showContactInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.lightGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Contact info
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Avatar
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.chatBubble,
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.chatBubble.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        widget.contactName.isNotEmpty ? widget.contactName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Name
                  Text(
                    widget.contactName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Online status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: widget.isOnline ? AppColors.success : AppColors.mediumGray,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.isOnline ? 'Connected' : 'Offline',
                        style: TextStyle(
                          color: widget.isOnline ? AppColors.success : AppColors.mediumGray,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.primaryRed,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => NavigationHelper.safePop(context),
        ),
        title: Row(
          children: [
            // Contact avatar
            GestureDetector(
              onTap: _showContactInfo,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: widget.isOnline ? AppColors.success : AppColors.mediumGray,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryRed.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    widget.contactName.isNotEmpty ? widget.contactName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.contactName,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: widget.isOnline ? AppColors.success : AppColors.mediumGray,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.isOnline ? 'Connected' : 'Last seen recently',
                        style: TextStyle(
                          color: AppColors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam, color: AppColors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PrivateCallScreen(
                    contactName: widget.contactName,
                    contactId: widget.contactId,
                    isVideoCall: true,
                  ),
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.white),
            onSelected: (value) {
              switch (value) {
                case 'info':
                  _showContactInfo();
                  break;
                case 'block':
                  _blockContact();
                  break;
                case 'clear':
                  _clearChat();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info, color: AppColors.primaryRed),
                    SizedBox(width: 8),
                    Text('Contact Info'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('Block Contact'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, color: AppColors.mediumGray),
                    SizedBox(width: 8),
                    Text('Clear Chat'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.backgroundGradient,
              ),
              child: PerformanceOptimizer.buildOptimizedListView(
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return ModernMessageBubble(
                    text: message['text'],
                    senderName: message['isMe'] ? 'You' : widget.contactName,
                    timestamp: message['timestamp'],
                    isMe: message['isMe'],
                    isEmergency: message['isEmergency'] ?? false,
                    isRead: message['isRead'] ?? false,
                    onLongPress: () {
                      _showMessageOptions(message);
                    },
                  );
                },
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), // Reduced top padding
              ),
            ),
          ),
          
          // Typing indicator
          if (_contactIsTyping)
            TypingIndicator(
              userName: widget.contactName,
              isVisible: _contactIsTyping,
            ),
          
          // Message input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border(
                top: BorderSide(
                  color: AppColors.lightGray.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
            ),
            child: Row(
              children: [
                // Emergency button
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.warning, color: AppColors.white),
                    onPressed: _sendEmergencyMessage,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Message input field
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.lightGray.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Send button
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: AppColors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(Map<String, dynamic> message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy Message'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Copy to clipboard
              },
            ),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Reply to message
              },
            ),
            ListTile(
              leading: const Icon(Icons.forward),
              title: const Text('Forward'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Forward message
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.error),
              title: const Text('Delete', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _messages.removeWhere((m) => m['id'] == message['id']);
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _blockContact() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block Contact'),
        content: Text('Are you sure you want to block ${widget.contactName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to previous screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Are you sure you want to clear all messages?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _messages.clear();
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
