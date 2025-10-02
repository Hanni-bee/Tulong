import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../screens/message_detail_screen.dart';

class RecentMessages extends StatelessWidget {
  const RecentMessages({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample recent messages data
    final List<Map<String, dynamic>> messages = [
      {
        'id': '1',
        'name': 'John Doe',
        'lastMessage': 'Hey, how are you doing?',
        'timestamp': '2 min ago',
        'unreadCount': 2,
        'isOnline': true,
        'avatar': null,
      },
      {
        'id': '2',
        'name': 'Maria Santos',
        'lastMessage': 'Thanks for the help earlier!',
        'timestamp': '5 min ago',
        'unreadCount': 0,
        'isOnline': true,
        'avatar': null,
      },
      {
        'id': '3',
        'name': 'Pedro Cruz',
        'lastMessage': 'Emergency situation in my area',
        'timestamp': '10 min ago',
        'unreadCount': 1,
        'isOnline': false,
        'avatar': null,
      },
      {
        'id': '4',
        'name': 'Ana Garcia',
        'lastMessage': 'All good here, thanks for checking',
        'timestamp': '15 min ago',
        'unreadCount': 0,
        'isOnline': true,
        'avatar': null,
      },
    ];

    return Column(
      children: messages.map((message) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.cardGlassGradient,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.glassBorder,
              width: 1,
            ),
            boxShadow: [
              const BoxShadow(
                color: AppColors.redShadow,
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
              BoxShadow(
                color: AppColors.white.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced Avatar
              Stack(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: message['isOnline'] 
                          ? AppColors.successGradient 
                          : AppColors.warningGradient,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: AppColors.white.withOpacity(0.2),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (message['isOnline'] ? AppColors.online : AppColors.mediumGray).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.transparent,
                      child: message['avatar'] != null
                          ? ClipOval(
                              child: Image.network(
                                message['avatar'],
                                fit: BoxFit.cover,
                              ),
                            )
                          : Text(
                              message['name'].split(' ').map((n) => n[0]).join(''),
                              style: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                    ),
                  ),
                  if (message['isOnline'])
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          gradient: AppColors.successGradient,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.white,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.online.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(width: 16),
              
              // Message info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            message['name'],
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          message['timestamp'],
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            message['lastMessage'],
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.textSecondary,
                              fontWeight: message['unreadCount'] > 0 
                                  ? FontWeight.w600 
                                  : FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (message['unreadCount'] > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: AppColors.buttonGradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryRed.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              message['unreadCount'].toString(),
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Enhanced Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppColors.buttonGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryRed.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => MessageDetailScreen(
                              contactName: message['name'],
                              contactId: message['id'],
                              contactAvatar: message['avatar'],
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.message,
                        color: AppColors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
