import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../widgets/chat_card.dart';
import '../widgets/search_bar.dart';
import '../widgets/unified_top_bar.dart';
import 'message_detail_screen.dart';
import 'calls_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Sample conversations data
  final List<Map<String, dynamic>> _conversations = [
    {
      'id': '1',
      'name': 'Max Holloway',
      'lastMessage': 'Hey, what are you up?',
      'timestamp': '1 min ago',
      'unreadCount': 2,
      'isOnline': true,
      'avatar': null,
    },
    {
      'id': '2',
      'name': 'Charles Oliveira',
      'lastMessage': 'Thanks for the help earlier!',
      'timestamp': '5 min ago',
      'unreadCount': 0,
      'isOnline': true,
      'avatar': null,
    },
    {
      'id': '3',
      'name': 'Alexa Grasso',
      'lastMessage': 'Emergency situation in my area',
      'timestamp': '10 min ago',
      'unreadCount': 1,
      'isOnline': false,
      'avatar': null,
    },
    {
      'id': '4',
      'name': 'Jon Jones',
      'lastMessage': 'Standing by for assistance',
      'timestamp': '15 min ago',
      'unreadCount': 0,
      'isOnline': true,
      'avatar': null,
    },
    {
      'id': '5',
      'name': 'Amanda Nunes',
      'lastMessage': 'Ready to help anyone in need',
      'timestamp': '20 min ago',
      'unreadCount': 0,
      'isOnline': true,
      'avatar': null,
    },
    {
      'id': '6',
      'name': 'Emergency Group',
      'lastMessage': 'All clear in Zone A',
      'timestamp': '30 min ago',
      'unreadCount': 5,
      'isOnline': true,
      'avatar': null,
      'isGroup': true,
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredConversations {
    if (_searchQuery.isEmpty) {
      return _conversations;
    }
    return _conversations.where((conversation) {
      return conversation['name'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
             conversation['lastMessage'].toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            // Unified top bar
            TopBarConfigs.messagesTopBar(
            onCallTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CallsScreen(),
                ),
              );
            },
            onMoreTap: () {
              _showOptionsMenu(context);
            },
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: CustomSearchBar(
              controller: _searchController,
              hintText: 'Search messages...',
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // Messages count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.message,
                  color: AppColors.primaryRed,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_conversations.length} conversations',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_conversations.where((c) => c['unreadCount'] > 0).length} unread',
                  style: const TextStyle(
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Conversations list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredConversations.length,
              itemBuilder: (context, index) {
                final conversation = _filteredConversations[index];
                return ChatCard(
                  name: conversation['name'],
                  lastMessage: conversation['lastMessage'],
                  timestamp: conversation['timestamp'],
                  unreadCount: conversation['unreadCount'],
                  isOnline: conversation['isOnline'],
                  isGroup: conversation['isGroup'] ?? false,
                  onTap: () {
                    _openChat(context, conversation);
                  },
                );
              },
            ),
          ),
        ],
      ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('messages_new_fab'),
        heroTag: 'messages_new_fab',
        onPressed: () {
          _showNewMessageDialog(context);
        },
        backgroundColor: AppColors.primaryRed,
        child: const Icon(
          Icons.add,
          color: AppColors.white,
        ),
      ),
    );
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.lightGray,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.mark_email_read, color: AppColors.primaryRed),
              title: const Text('Mark all as read'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Mark all as read
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep, color: AppColors.error),
              title: const Text('Clear all messages'),
              onTap: () {
                Navigator.pop(context);
                _showClearAllDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings, color: AppColors.mediumGray),
              title: const Text('Message settings'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Show message settings
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showNewMessageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('New Message'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add, color: AppColors.primaryRed),
              title: const Text('Message a person'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to people list
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add, color: AppColors.primaryRed),
              title: const Text('Create group'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Create group
              },
            ),
            ListTile(
              leading: const Icon(Icons.broadcast_on_personal, color: AppColors.primaryRed),
              title: const Text('Broadcast message'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Broadcast message
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _openChat(BuildContext context, Map<String, dynamic> conversation) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MessageDetailScreen(
          contactName: conversation['name'],
          contactId: conversation['id'],
          contactAvatar: conversation['avatar'],
        ),
      ),
    );
  }

  void _showClearAllDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Clear All Messages'),
        content: const Text(
          'This will delete all your message conversations. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All messages cleared'),
                  backgroundColor: AppColors.primaryRed,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
