import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/theme_colors.dart';
import '../constants/soft_ui_design.dart';
import '../utils/performance_optimizer.dart';
import '../widgets/modern_message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/modern_floating_layout.dart';
import '../widgets/enhanced_text_styles.dart';
import '../widgets/enhanced_shadows.dart' as shadows;
import '../constants/unified_typography.dart';

class ModernGlobalChatScreen extends StatefulWidget {
  const ModernGlobalChatScreen({super.key});

  @override
  State<ModernGlobalChatScreen> createState() => _ModernGlobalChatScreenState();
}

class _ModernGlobalChatScreenState extends State<ModernGlobalChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  String _typingUser = '';
  final bool _isConnected = true;
  
  // Sample global chat messages
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
      'text': 'Yes, stay there. Battery low?',
      'senderId': 'user1',
      'senderName': 'User 1',
      'timestamp': DateTime.now().subtract(const Duration(hours: 1, minutes: 15)),
      'isEmergency': false,
      'isRead': true,
    },
    {
      'id': '5',
      'text': 'Yes',
      'senderId': 'user2',
      'senderName': 'User 2',
      'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
      'isEmergency': false,
      'isRead': true,
    },
    {
      'id': '6',
      'text': 'Copy. Stay safe.',
      'senderId': 'user1',
      'senderName': 'User 1',
      'timestamp': DateTime.now().subtract(const Duration(minutes: 30)),
      'isEmergency': false,
      'isRead': true,
    },
    {
      'id': '7',
      'text': 'You too.',
      'senderId': 'user2',
      'senderName': 'User 2',
      'timestamp': DateTime.now().subtract(const Duration(minutes: 15)),
      'isEmergency': false,
      'isRead': true,
    },
  ];

  @override
  void initState() {
    super.initState();
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
        _typingUser = 'You';
      });
      
      // Simulate other users typing
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isTyping = false;
            _typingUser = '';
          });
        }
      });
    }
  }

  void _onScroll() {
    // Auto-hide typing indicator when scrolling
    if (_isTyping) {
      setState(() {
        _isTyping = false;
        _typingUser = '';
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
          'senderName': 'You',
          'timestamp': DateTime.now(),
          'isEmergency': false,
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
        'text': '🚨 EMERGENCY ALERT: Immediate assistance needed!',
        'senderId': 'me',
        'senderName': 'You',
        'timestamp': DateTime.now(),
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
              backgroundColor: AppColors.chatBubble,
              foregroundcolor: ThemeColors.surface(context),
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showChatSettings() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Chat Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Notifications'),
              trailing: Switch(
                value: true,
                onChanged: (value) {},
              ),
            ),
            ListTile(
              leading: const Icon(Icons.volume_up),
              title: const Text('Sound'),
              trailing: Switch(
                value: true,
                onChanged: (value) {},
              ),
            ),
            ListTile(
              leading: const Icon(Icons.vibration),
              title: const Text('Vibration'),
              trailing: Switch(
                value: true,
                onChanged: (value) {},
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ModernFloatingAppBarLayout(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          margin: const EdgeInsets.all(8), // Reduced from 16
          decoration: BoxDecoration(
            color: ThemeColors.surface(context),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              // Neumorphic shadow - outer shadow
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(8, 8),
              ),
              // Neumorphic shadow - inner highlight
              BoxShadow(
                color: Colors.white.withOpacity(0.8),
                blurRadius: 20,
                offset: const Offset(-8, -8),
              ),
            ],
          ),
          child: SafeArea(
              child: Container(
                height: 80,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: const BoxDecoration(
                  color: ThemeColors.surface(context),
                ),
                child: Row(
                children: [
                  // Chat icon (consistent with other screens)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: ThemeColors.surface(context),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: shadows.EnhancedShadows.buttonLight,
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline,
                      color: AppColors.primaryRed,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // App logo
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(4, 4),
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.8),
                          blurRadius: 8,
                          offset: const Offset(-4, -4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/app_logo (3).png',
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Title and status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SectionTitle('Global Chat'),
                      ],
                    ),
                  ),
                  
                  // Action buttons
                  Row(
                    children: [
                      _buildNeumorphicActionButton(
                        icon: Icons.more_vert,
                        onPressed: () => _showActionMenu(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      child: ModernFloatingLayout(
        hasFloatingAppBar: true,
        hasFloatingBottomBar: false,
        child: Column(
        children: [
          // Messages list
          Expanded(
            child: Container(
              color: AppColors.backgroundLight,
              child: PerformanceOptimizer.buildOptimizedListView(
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  return ModernMessageBubble(
                    text: message['text'],
                    senderName: message['senderName'],
                    timestamp: message['timestamp'],
                    isMe: message['senderId'] == 'me',
                    isEmergency: message['isEmergency'] ?? false,
                    isRead: message['isRead'] ?? false,
                    onLongPress: () {
                      // Show message options
                      _showMessageOptions(message);
                    },
                  );
                },
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
          
          // Typing indicator
          if (_isTyping && _typingUser.isNotEmpty)
            TypingIndicator(
              userName: _typingUser,
              isVisible: _isTyping,
            ),
          
          // Message input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ThemeColors.surface(context),
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
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.warning, color: ThemeColors.surface(context)),
                    onPressed: _sendEmergencyMessage,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Message input field
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: ThemeColors.surface(context),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: AppColors.lightGray.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Send Your Message Here',
                        hintStyle: TextStyle(
                          color: AppColors.mediumGray,
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16, // Reduced from 24
                          vertical: 12, // Reduced from 16
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                        fontSize: 16,
                        color: ThemeColors.textPrimary(context),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Send button
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.send_rounded, color: ThemeColors.surface(context), size: 24),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
        ),
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
            if (message['senderId'] != 'me')
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('View Profile'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Show user profile
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

  Widget _buildNeumorphicButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(4, 4),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 8,
            offset: const Offset(-4, -4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: AppColors.primaryRed,
          size: 20,
        ),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildNeumorphicActionButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(3, 3),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 6,
            offset: const Offset(-3, -3),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: ThemeColors.textPrimary(context),
          size: 18,
        ),
        onPressed: onPressed,
      ),
    );
  }

  void _showActionMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: SoftUIDesign.cardDecoration(
          backgroundColor: ThemeColors.surface(context),
          borderRadius: SoftUIDesign.cardBorderRadius,
          elevation: 6.0,
          borderColor: AppColors.lightGray.withOpacity(0.3),
          showBorder: true,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildMenuOption(
                    icon: Icons.warning,
                    title: 'Send Emergency Alert',
                    color: AppColors.error,
                    onTap: () {
                      Navigator.pop(context);
                      _sendEmergencyMessage();
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildMenuOption(
                    icon: Icons.clear_all,
                    title: 'Clear Chat',
                    color: ThemeColors.textSecondary(context),
                    onTap: () {
                      Navigator.pop(context);
                      _clearChat();
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildMenuOption(
                    icon: Icons.settings,
                    title: 'Chat Settings',
                    color: ThemeColors.textSecondary(context),
                    onTap: () {
                      Navigator.pop(context);
                      _showChatSettings();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(2, 2),
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.8),
              blurRadius: 8,
              offset: const Offset(-2, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: UnifiedTypography.titleLarge,
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: ThemeColors.textSecondary(context),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
