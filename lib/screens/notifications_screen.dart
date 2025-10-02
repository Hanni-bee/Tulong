import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../widgets/notification_card.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Sample notifications data
  final List<Map<String, dynamic>> _notifications = [
    {
      'id': '1',
      'title': 'Device Disconnected',
      'message': 'Your device has been disconnected from the network.',
      'timestamp': '2 min ago',
      'type': 'error',
      'isRead': false,
    },
    {
      'id': '2',
      'title': 'Emergency Alert',
      'message': 'Emergency situation reported in your area. Please stay safe.',
      'timestamp': '5 min ago',
      'type': 'emergency',
      'isRead': false,
    },
    {
      'id': '3',
      'title': 'Network Connected',
      'message': 'Successfully connected to the mesh network.',
      'timestamp': '10 min ago',
      'type': 'success',
      'isRead': true,
    },
    {
      'id': '4',
      'title': 'Low Battery Warning',
      'message': 'Your device battery is running low. Please charge soon.',
      'timestamp': '15 min ago',
      'type': 'warning',
      'isRead': true,
    },
    {
      'id': '5',
      'title': 'New Message',
      'message': 'You received a new message from Max Holloway.',
      'timestamp': '20 min ago',
      'type': 'info',
      'isRead': true,
    },
    {
      'id': '6',
      'title': 'System Update',
      'message': 'T.U.L.O.N.G system has been updated to version 1.0.1.',
      'timestamp': '1 hour ago',
      'type': 'info',
      'isRead': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n['isRead']).length;
    
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          AppStrings.notifications,
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () {
                _markAllAsRead();
              },
              child: const Text(
                'Mark all as read',
                style: TextStyle(
                  color: AppColors.primaryRed,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              _showNotificationSettings(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Notification summary
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: unreadCount > 0 ? AppColors.primaryRed : AppColors.online,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.notifications,
                    color: AppColors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You have $unreadCount unread notifications',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_notifications.length} total notifications',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      unreadCount.toString(),
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Notifications list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return NotificationCard(
                  title: notification['title'],
                  message: notification['message'],
                  timestamp: notification['timestamp'],
                  type: notification['type'],
                  isRead: notification['isRead'],
                  onTap: () {
                    _markAsRead(notification['id']);
                  },
                  onDismiss: () {
                    _dismissNotification(notification['id']);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _markAsRead(String notificationId) {
    setState(() {
      final index = _notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        _notifications[index]['isRead'] = true;
      }
    });
  }

  void _markAllAsRead() {
    setState(() {
      for (var notification in _notifications) {
        notification['isRead'] = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All notifications marked as read'),
        backgroundColor: AppColors.online,
      ),
    );
  }

  void _dismissNotification(String notificationId) {
    setState(() {
      _notifications.removeWhere((n) => n['id'] == notificationId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notification dismissed'),
        backgroundColor: AppColors.mediumGray,
      ),
    );
  }

  void _showNotificationSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
              leading: const Icon(Icons.notifications_active, color: AppColors.primaryRed),
              title: const Text('Emergency Notifications'),
              subtitle: const Text('Always receive emergency alerts'),
              trailing: Switch(
                value: true,
                onChanged: (value) {},
                activeThumbColor: AppColors.primaryRed,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.message, color: AppColors.primaryRed),
              title: const Text('Message Notifications'),
              subtitle: const Text('Get notified of new messages'),
              trailing: Switch(
                value: true,
                onChanged: (value) {},
                activeThumbColor: AppColors.primaryRed,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.network_check, color: AppColors.primaryRed),
              title: const Text('Network Notifications'),
              subtitle: const Text('Network status updates'),
              trailing: Switch(
                value: false,
                onChanged: (value) {},
                activeThumbColor: AppColors.primaryRed,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.battery_alert, color: AppColors.primaryRed),
              title: const Text('Power Notifications'),
              subtitle: const Text('Battery and power alerts'),
              trailing: Switch(
                value: true,
                onChanged: (value) {},
                activeThumbColor: AppColors.primaryRed,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
