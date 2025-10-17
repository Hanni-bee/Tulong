import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../services/simple_bluetooth_service.dart';
import '../widgets/modern_message_bubble.dart';
import '../widgets/enhanced_card.dart';
import '../widgets/enhanced_text_field.dart';

/// ESP32 LoRa Chat Screen
/// Integrates with ESP32 Bluetooth service for offline messaging
class ESP32LoRaChatScreen extends StatefulWidget {
  const ESP32LoRaChatScreen({super.key});

  @override
  State<ESP32LoRaChatScreen> createState() => _ESP32LoRaChatScreenState();
}

class _ESP32LoRaChatScreenState extends State<ESP32LoRaChatScreen>
    with TickerProviderStateMixin {
  // ============================================================================
  // CONTROLLERS AND STATE
  // ============================================================================
  
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocus = FocusNode();
  
  late AnimationController _connectionAnimationController;
  late AnimationController _messageAnimationController;
  late Animation<double> _connectionAnimation;
  late Animation<double> _messageAnimation;
  
  List<Map<String, dynamic>> _messages = [];
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<String>? _statusSubscription;
  
  bool _isSending = false;
  String _selectedChatMode = 'group'; // 'group' or 'private'
  
  // ============================================================================
  // INITIALIZATION
  // ============================================================================
  
  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeESP32Service();
    _setupMessageStreams();
  }
  
  void _initializeAnimations() {
    _connectionAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _messageAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _connectionAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _connectionAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _messageAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _messageAnimationController,
      curve: Curves.easeOut,
    ));
  }
  
  void _initializeESP32Service() async {
    final esp32Service = Provider.of<SimpleBluetoothService>(context, listen: false);
    await esp32Service.initialize();
    
    // Auto-connect to ESP32 if not already connected
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
    
    // Listen for status updates
    _statusSubscription = esp32Service.statusStream.listen((status) {
      _handleStatusUpdate(status);
    });
  }
  
  // ============================================================================
  // MESSAGE HANDLING
  // ============================================================================
  
  void _handleIncomingMessage(Map<String, dynamic> message) {
    setState(() {
      _messages.add(message);
    });
    
    _animateNewMessage();
    _scrollToBottom();
    
    // Provide haptic feedback
    HapticFeedback.lightImpact();
  }
  
  void _handleStatusUpdate(String status) {
    // Update connection animation based on status
    if (status.contains('Connected')) {
      _connectionAnimationController.forward();
    } else if (status.contains('Disconnected')) {
      _connectionAnimationController.reverse();
    }
  }
  
  void _animateNewMessage() {
    _messageAnimationController.forward().then((_) {
      _messageAnimationController.reverse();
    });
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
  
  // ============================================================================
  // MESSAGE SENDING
  // ============================================================================
  
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isSending) return;
    
    final esp32Service = Provider.of<SimpleBluetoothService>(context, listen: false);
    
    // Check connection first
    if (!esp32Service.isConnected) {
      _showErrorSnackBar('❌ Not connected to ESP32. Tap Bluetooth icon to connect.');
      return;
    }
    
    if (!esp32Service.isAuthenticated) {
      _showErrorSnackBar('⏳ Authenticating... Please wait.');
      return;
    }
    
    setState(() => _isSending = true);
    
    try {
      // Add message to local list immediately for instant feedback
      final localMessage = {
        'type': _selectedChatMode,
        'sender_name': esp32Service.userName,
        'sender_id': esp32Service.esp32NodeId,
        'receiver_id': _selectedChatMode == 'group' ? 'all' : 'target_node',
        'message': message,
        'timestamp': DateTime.now().toString(),
        'isLocal': true,
        'status': 'sending', // Add status
      };
      
      setState(() {
        _messages.add(localMessage);
      });
      
      _animateNewMessage();
      _scrollToBottom();
      _messageController.clear();
      
      // Send via ESP32
      if (_selectedChatMode == 'group') {
        await esp32Service.sendGroupMessage(message);
      } else {
        await esp32Service.sendPrivateMessage(message, 'target_node');
      }
      
      // Update message status to sent
      setState(() {
        if (_messages.isNotEmpty) {
          _messages.last['status'] = 'sent';
        }
      });
      
      HapticFeedback.mediumImpact();
      _showSuccessSnackBar('✓ Message sent via LoRa');
      
    } catch (e) {
      _showErrorSnackBar('❌ Failed to send: $e');
      // Mark message as failed
      if (_messages.isNotEmpty && _messages.last['message'] == message) {
        setState(() {
          _messages.last['status'] = 'failed';
        });
      }
    } finally {
      setState(() => _isSending = false);
    }
  }
  
  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
  
  // ============================================================================
  // UI BUILDERS
  // ============================================================================
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          _buildModernAppBar(),
          _buildConnectionStatusCard(),
          _buildChatModeSelector(),
          Expanded(child: _buildMessagesList()),
          _buildModernMessageInput(),
        ],
      ),
    );
  }
  
  Widget _buildModernAppBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.8),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: AppColors.darkGray),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ESP32 LoRa Chat',
                      style: AppTypography.titleLarge.copyWith(
                        color: AppColors.darkGray,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Consumer<SimpleBluetoothService>(
                      builder: (context, esp32Service, child) {
                        return Text(
                          esp32Service.isConnected ? 'Connected' : 'Disconnected',
                          style: AppTypography.bodyMedium.copyWith(
                            color: esp32Service.isConnected ? AppColors.success : AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
                  Consumer<SimpleBluetoothService>(
                    builder: (context, esp32Service, child) {
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).pushNamed('/esp32-auth');
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
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
                          child: Icon(
                            esp32Service.isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                            color: esp32Service.isConnected ? AppColors.success : AppColors.online,
                            size: 24,
                          ),
                        ),
                      );
                    },
                  ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildConnectionStatusCard() {
    return Consumer<SimpleBluetoothService>(
      builder: (context, esp32Service, child) {
        return AnimatedBuilder(
          animation: _connectionAnimation,
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.all(16),
              child: EnhancedCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: esp32Service.isConnected 
                                ? AppColors.success.withOpacity(0.1)
                                : AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            esp32Service.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                            color: esp32Service.isConnected ? AppColors.success : AppColors.error,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                esp32Service.connectionStatus,
                                style: AppTypography.bodyLarge.copyWith(
                                  color: esp32Service.isConnected ? AppColors.success : AppColors.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (esp32Service.isAuthenticated) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Node: ${esp32Service.esp32NodeId}',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.mediumGray,
                                  ),
                                ),
                                Text(
                                  'User: ${esp32Service.userName}',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.mediumGray,
                                  ),
                                ),
                              ] else if (!esp32Service.isConnected) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Tap button below to connect',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.mediumGray,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (esp32Service.isConnected && esp32Service.isAuthenticated)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.success.withOpacity(0.3),
                              ),
                            ),
                            child: const Text(
                              '✓ READY',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    // Show connect button when not connected
                    if (!esp32Service.isConnected) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(context).pushNamed('/esp32-auth');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.online,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.bluetooth_searching, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Connect to ESP32',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildChatModeSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: EnhancedCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedChatMode = 'group'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _selectedChatMode == 'group' ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(2, 2),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.8),
                        blurRadius: 8,
                        offset: const Offset(-2, -2),
                      ),
                    ] : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(1, 1),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.9),
                        blurRadius: 4,
                        offset: const Offset(-1, -1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.group,
                        color: _selectedChatMode == 'group' 
                            ? AppColors.primaryRed 
                            : AppColors.mediumGray,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Group Chat',
                        style: AppTypography.bodyLarge.copyWith(
                          color: _selectedChatMode == 'group' 
                              ? AppColors.primaryRed 
                              : AppColors.mediumGray,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedChatMode = 'private'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: _selectedChatMode == 'private' ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(2, 2),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.8),
                        blurRadius: 8,
                        offset: const Offset(-2, -2),
                      ),
                    ] : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(1, 1),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.9),
                        blurRadius: 4,
                        offset: const Offset(-1, -1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person,
                        color: _selectedChatMode == 'private' 
                            ? AppColors.primaryRed 
                            : AppColors.mediumGray,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Private Chat',
                        style: AppTypography.bodyLarge.copyWith(
                          color: _selectedChatMode == 'private' 
                              ? AppColors.primaryRed 
                              : AppColors.mediumGray,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMessagesList() {
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: AppColors.lightGray,
            ),
            const SizedBox(height: 16),
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
      );
    }
    
    return AnimatedBuilder(
      animation: _messageAnimation,
      builder: (context, child) {
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: _messages.length,
          itemBuilder: (context, index) {
            return _buildMessageBubble(_messages[index], index);
          },
        );
      },
    );
  }
  
  Widget _buildMessageBubble(Map<String, dynamic> message, int index) {
    final isLocal = message['isLocal'] == true;
    final messageType = message['type'] ?? 'group';
    final senderName = message['sender_name'] ?? 'Unknown';
    final messageText = message['message'] ?? '';
    final timestamp = message['timestamp'] ?? '';
    
    return AnimatedBuilder(
      animation: _messageAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: index == _messages.length - 1 ? _messageAnimation.value : 1.0,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ModernMessageBubble(
              text: messageText,
              senderName: senderName,
              timestamp: DateTime.tryParse(timestamp) ?? DateTime.now(),
              isMe: isLocal,
              isEmergency: messageType == 'group' && messageText.toLowerCase().contains('emergency'),
              isRead: true,
              onTap: () => _showMessageOptions(message),
              onLongPress: () => _showMessageOptions(message),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildModernMessageInput() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: EnhancedTextField(
                  controller: _messageController,
                  focusNode: _messageFocus,
                  label: _selectedChatMode == 'group' 
                      ? 'Group Message' 
                      : 'Private Message',
                  hint: _selectedChatMode == 'group' 
                      ? 'Type a group message...' 
                      : 'Type a private message...',
                  maxLines: 3,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _isSending ? null : _sendMessage,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _isSending ? AppColors.lightGray : const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: _isSending ? null : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
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
                  child: _isSending
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.mediumGray),
                          ),
                        )
                      : Icon(
                          Icons.send_rounded,
                          color: AppColors.primaryRed,
                          size: 24,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // ============================================================================
  // UTILITY FUNCTIONS
  // ============================================================================
  
  
  // Connection dialog removed - using dedicated auth screen instead
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showMessageOptions(Map<String, dynamic> message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Message Options',
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: AppColors.primaryRed),
              title: const Text('Copy Message'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message['message'] ?? ''));
                Navigator.pop(context);
                _showErrorSnackBar('Message copied to clipboard');
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: AppColors.primaryRed),
              title: const Text('Share Message'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement share functionality
                _showErrorSnackBar('Share functionality coming soon');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
  
  // ============================================================================
  // CLEANUP
  // ============================================================================
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocus.dispose();
    _connectionAnimationController.dispose();
    _messageAnimationController.dispose();
    _messageSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }
}


