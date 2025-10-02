import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../screens/message_detail_screen.dart';

class UserContacts extends StatelessWidget {
  const UserContacts({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample user contacts data
    final List<Map<String, dynamic>> contacts = [
      {
        'id': '1',
        'name': 'John Doe',
        'phone': '+63 912 345 6789',
        'isOnline': true,
        'lastSeen': '2 minutes ago',
        'avatar': null,
      },
      {
        'id': '2',
        'name': 'Maria Santos',
        'phone': '+63 917 123 4567',
        'isOnline': true,
        'lastSeen': '5 minutes ago',
        'avatar': null,
      },
      {
        'id': '3',
        'name': 'Pedro Cruz',
        'phone': '+63 918 987 6543',
        'isOnline': false,
        'lastSeen': '1 hour ago',
        'avatar': null,
      },
      {
        'id': '4',
        'name': 'Ana Garcia',
        'phone': '+63 919 456 7890',
        'isOnline': true,
        'lastSeen': 'Just now',
        'avatar': null,
      },
    ];

    return Column(
      children: contacts.map((contact) {
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
            children: [
              // Enhanced Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: contact['isOnline'] 
                      ? AppColors.successGradient 
                      : AppColors.warningGradient,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: AppColors.white.withOpacity(0.2),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (contact['isOnline'] ? AppColors.online : AppColors.mediumGray).withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.transparent,
                  child: contact['avatar'] != null
                      ? ClipOval(
                          child: Image.network(
                            contact['avatar'],
                            fit: BoxFit.cover,
                          ),
                        )
                      : Text(
                          contact['name'].split(' ').map((n) => n[0]).join(''),
                          style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Contact info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact['name'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      contact['phone'],
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            gradient: contact['isOnline'] 
                                ? AppColors.successGradient 
                                : AppColors.warningGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (contact['isOnline'] ? AppColors.online : AppColors.mediumGray).withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          contact['isOnline'] 
                              ? 'Connected' 
                              : 'Last seen ${contact['lastSeen']}',
                          style: TextStyle(
                            fontSize: 13,
                            color: contact['isOnline'] 
                                ? AppColors.online 
                                : AppColors.textSecondary,
                            fontWeight: contact['isOnline'] 
                                ? FontWeight.w600 
                                : FontWeight.w500,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Enhanced Action buttons
              Row(
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
                              contactName: contact['name'],
                              contactId: contact['id'],
                              contactAvatar: contact['avatar'],
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
