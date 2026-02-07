import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/theme_colors.dart';
import '../services/notification_service.dart';
import '../widgets/accessible_text.dart';
import '../utils/standardized_spacing.dart';
import '../utils/icon_system.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  final NotificationService _notificationService = NotificationService();
  
  Map<String, bool> _settings = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _notificationService.getNotificationSettings();
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Failed to load notification settings');
    }
  }

  Future<void> _updateSetting(String key, bool value) async {
    try {
      await _notificationService.updateNotificationSettings(
        emergencyEnabled: key == 'emergency' ? value : null,
        messageEnabled: key == 'messages' ? value : null,
        systemEnabled: key == 'system' ? value : null,
        soundEnabled: key == 'sound' ? value : null,
        vibrationEnabled: key == 'vibration' ? value : null,
      );
      
      setState(() {
        _settings[key] = value;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to update setting');
    }
  }

  Future<void> _testNotification() async {
    try {
      await _notificationService.showSystemNotification(
        title: 'Test Notification',
        body: 'This is a test notification from T.U.L.O.N.G',
        payload: 'test_notification',
      );
      _showSuccessSnackBar('Test notification sent!');
    } catch (e) {
      _showErrorSnackBar('Failed to send test notification');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.background(context),
      appBar: AppBar(
        title: AccessibleHeading(
          'Notifications',
          level: HeadingLevel.h2,
          color: ThemeColors.textPrimary(context),
          backgroundColor: ThemeColors.background(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: ThemeColors.textPrimary(context)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: StandardizedSpacing.screenPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Notification Settings Section
                  _buildSectionHeader(
                    'Notification Settings',
                    Icons.notifications,
                    AppColors.primaryRed,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildNotificationCard(),
                  
                  const SizedBox(height: 32),
                  
                  // Test Section
                  _buildSectionHeader(
                    'Test & Actions',
                    IconSystem.settings,
                    Colors.green,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildTestCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        AccessibleHeading(
          title,
          level: HeadingLevel.h3,
          color: ThemeColors.textPrimary(context),
          backgroundColor: ThemeColors.background(context),
        ),
      ],
    );
  }

  Widget _buildNotificationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: ThemeColors.shadow(context, opacity: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingTile(
            'Emergency Alerts',
            'Critical emergency notifications',
            Icons.warning,
            Colors.red,
            'emergency',
          ),
          Divider(height: 24, color: ThemeColors.divider(context)),
          _buildSettingTile(
            'Chat Messages',
            'New messages in conversations',
            IconSystem.message,
            Colors.blue,
            'messages',
          ),
          Divider(height: 24, color: ThemeColors.divider(context)),
          _buildSettingTile(
            'System Notifications',
            'App updates and system messages',
            IconSystem.info,
            Colors.orange,
            'system',
          ),
          Divider(height: 24, color: ThemeColors.divider(context)),
          _buildSettingTile(
            'Sound',
            'Play notification sounds',
            IconSystem.volume,
            Colors.purple,
            'sound',
          ),
          Divider(height: 24, color: ThemeColors.divider(context)),
          _buildSettingTile(
            'Vibration',
            'Vibrate on notifications',
            IconSystem.signal,
            Colors.teal,
            'vibration',
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    String key,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AccessibleHeading(
                title,
                level: HeadingLevel.h5,
                color: ThemeColors.textPrimary(context),
                backgroundColor: ThemeColors.surface(context),
              ),
              AccessibleBodyText(
                subtitle,
                size: BodySize.medium,
                color: ThemeColors.textSecondary(context),
                backgroundColor: ThemeColors.surface(context),
              ),
            ],
          ),
        ),
        Switch(
          value: _settings[key] ?? false,
          onChanged: (value) => _updateSetting(key, value),
          activeTrackColor: ThemeColors.primary(context).withOpacity(0.5),
          activeThumbColor: ThemeColors.primary(context),
        ),
      ],
    );
  }

  Widget _buildTestCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: ThemeColors.shadow(context, opacity: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _testNotification,
              icon: const Icon(Icons.notifications_active),
              label: const Text(
                'Test Notification',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
