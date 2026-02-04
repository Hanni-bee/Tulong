import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/theme_colors.dart';

class PersonalMessageScreen extends StatefulWidget {
  final String contactName;
  final String contactId;
  final String? contactAvatar;

  const PersonalMessageScreen({
    super.key,
    required this.contactName,
    required this.contactId,
    this.contactAvatar,
  });

  @override
  State<PersonalMessageScreen> createState() => _PersonalMessageScreenState();
}

class _PersonalMessageScreenState extends State<PersonalMessageScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
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
      },
      {
        'id': '2',
        'text': 'I\'m doing well, thanks for asking! How about you?',
        'senderId': widget.contactId,
        'timestamp': DateTime.now().subtract(const Duration(hours: 1, minutes: 45)),
        'isMe': false,
      },
      {
        'id': '3',
        'text': 'All good here. Just checking in during this emergency situation.',
        'senderId': 'me',
        'timestamp': DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
        'isMe': true,
      },
      {
        'id': '4',
        'text': 'Thanks for checking. Stay safe out there!',
        'senderId': widget.contactId,
        'timestamp': DateTime.now().subtract(const Duration(minutes: 30)),
        'isMe': false,
      },
    ];
  }

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
          'timestamp': DateTime.now(),
          'isMe': true,
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
      backgroundColor: ThemeColors.surface(context),
      appBar: AppBar(
        backgroundColor: AppColors.primaryRed,
        foregroundcolor: ThemeColors.surface(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            // Contact avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: ThemeColors.surface(context),
              child: widget.contactAvatar != null
                  ? ClipOval(
                      child: Image.network(
                        widget.contactAvatar!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Text(
                      widget.contactName.split(' ').map((n) => n[0]).join(''),
                      style: const TextStyle(
                        color: AppColors.primaryRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: ThemeColors.surface(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'Connected',
                    style: TextStyle(
                      fontSize: 12,
                      color: ThemeColors.surface(context),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              _showMoreOptions(context);
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
                final isMe = message['isMe'] as bool;
                
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
                          child: widget.contactAvatar != null
                              ? ClipOval(
                                  child: Image.network(
                                    widget.contactAvatar!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Text(
                                  widget.contactName.split(' ').map((n) => n[0]).join(''),
                                  style: const TextStyle(
                                    color: ThemeColors.surface(context),
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
                                      color: ThemeColors.surface(context),
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
                            color: ThemeColors.surface(context),
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
              color: ThemeColors.surface(context),
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
                      hintText: 'Type a message...',
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
                      color: ThemeColors.surface(context),
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


  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.mediumGray,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Options for ${widget.contactName}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ThemeColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 20),
              // Options list
              ListTile(
                leading: const Icon(Icons.info_outline, color: AppColors.primaryRed),
                title: const Text('View Profile'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Viewing ${widget.contactName}\'s profile'),
                      backgroundColor: AppColors.info,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_off, color: AppColors.mediumGray),
                title: const Text('Mute Notifications'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Notifications muted for ${widget.contactName}'),
                      backgroundColor: AppColors.mediumGray,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: AppColors.error),
                title: const Text('Block Contact'),
                onTap: () {
                  Navigator.pop(context);
                  _showBlockConfirmation(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.report, color: AppColors.warning),
                title: const Text('Report'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Report submitted'),
                      backgroundColor: AppColors.warning,
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showBlockConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.block,
                color: AppColors.error,
                size: 28,
              ),
              SizedBox(width: 12),
              Text(
                'Block Contact',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: ThemeColors.textPrimary(context),
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to block ${widget.contactName}? You won\'t receive messages from them.',
            style: const TextStyle(
              color: ThemeColors.textSecondary(context),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.mediumGray,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Close the options sheet too
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${widget.contactName} has been blocked'),
                    backgroundColor: AppColors.error,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Block'),
            ),
          ],
        );
      },
    );
  }
}
