import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/navigation_helper.dart';

class GlobalChatScreen extends StatefulWidget {
  const GlobalChatScreen({super.key});

  @override
  State<GlobalChatScreen> createState() => _GlobalChatScreenState();
}

class _GlobalChatScreenState extends State<GlobalChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final bool _isConnected = true;
  final int _connectedUsers = 42;
  final bool _isTyping = false;
  final String _typingUser = '';
  final bool _showOnlineUsers = false;
  
  // Sample global chat messages
  final List<Map<String, dynamic>> _messages = [
    {
      'id': '1',
      'text': 'Power\'s out. You safe?',
      'senderId': 'user2',
      'senderName': 'User 2',
      'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
      'isEmergency': false,
    },
    {
      'id': '2',
      'text': 'Yeah, weak signal. Where are you?',
      'senderId': 'user1',
      'senderName': 'User 1',
      'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
      'isEmergency': false,
    },
    {
      'id': '3',
      'text': 'At barangay hall. Roads flooded?',
      'senderId': 'user2',
      'senderName': 'User 2',
      'timestamp': DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
      'isEmergency': false,
    },
    {
      'id': '4',
      'text': 'Yes, stay there. Battery low?',
      'senderId': 'user1',
      'senderName': 'User 1',
      'timestamp': DateTime.now().subtract(const Duration(hours: 1, minutes: 15)),
      'isEmergency': false,
    },
    {
      'id': '5',
      'text': 'Yes',
      'senderId': 'user2',
      'senderName': 'User 2',
      'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
      'isEmergency': false,
    },
    {
      'id': '6',
      'text': 'Copy. Stay safe.',
      'senderId': 'user1',
      'senderName': 'User 1',
      'timestamp': DateTime.now().subtract(const Duration(minutes: 30)),
      'isEmergency': false,
    },
    {
      'id': '7',
      'text': 'You too.',
      'senderId': 'user2',
      'senderName': 'User 2',
      'timestamp': DateTime.now().subtract(const Duration(minutes: 15)),
      'isEmergency': false,
    },
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      setState(() {
        _messages.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'text': _messageController.text.trim(),
          'senderId': 'me',
          'senderName': 'You',
          'timestamp': DateTime.now(),
          'isEmergency': false,
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

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            // Safe navigation back
            NavigationHelper.safePop(context);
          },
        ),
        title: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.asset(
                      'assets/images/app_logo (3).png',
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Global Chat',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isConnected ? AppColors.online : AppColors.offline,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$_connectedUsers connected',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people, color: AppColors.primaryRed),
            onPressed: () {
              _showConnectedUsersDialog();
            },
          ),
          IconButton(
            icon: const Icon(Icons.emergency, color: AppColors.error),
            onPressed: () {
              _sendEmergencyMessage();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMe = message['senderId'] == 'me';
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: isMe 
                        ? MainAxisAlignment.end 
                        : MainAxisAlignment.start,
                    children: [
                      if (!isMe) ...[
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primaryRed,
                          child: Text(
                            message['senderName'].toString().split(' ').map((n) => n[0]).join(''),
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isMe ? AppColors.primaryRed : AppColors.lightGray,
                            borderRadius: BorderRadius.circular(20).copyWith(
                              bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                              bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMe)
                                Text(
                                  message['senderName'],
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              if (!isMe) const SizedBox(height: 4),
                              Text(
                                message['text'],
                                style: TextStyle(
                                  color: isMe ? AppColors.white : AppColors.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatTime(message['timestamp']),
                                    style: TextStyle(
                                      color: isMe 
                                          ? AppColors.white.withOpacity(0.7)
                                          : AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.done_all,
                                      color: AppColors.white,
                                      size: 12,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 8),
                        const CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primaryRed,
                          child: Icon(
                            Icons.person,
                            color: AppColors.white,
                            size: 16,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Message input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(
                top: BorderSide(color: AppColors.lightGray, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Send Your Message Here',
                      hintStyle: const TextStyle(color: AppColors.mediumGray),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(color: AppColors.lightGray),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: const BorderSide(color: AppColors.primaryRed),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryRed,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send,
                      color: AppColors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showConnectedUsersDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connected Users'),
        content: Text('$_connectedUsers users are currently connected to the global chat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _sendEmergencyMessage() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.emergency, color: AppColors.error),
            SizedBox(width: 8),
            Text('Emergency Alert'),
          ],
        ),
        content: const Text(
          'This will send an emergency message to all connected users. Use only in genuine emergency situations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _messages.add({
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'text': '🚨 EMERGENCY ALERT 🚨',
                  'senderId': 'me',
                  'senderName': 'You',
                  'timestamp': DateTime.now(),
                  'isEmergency': true,
                });
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Send Alert'),
          ),
        ],
      ),
    );
  }
}
