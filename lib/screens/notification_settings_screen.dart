import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/theme_colors.dart';
import '../services/notification_service.dart';
import '../services/offline_sync_service.dart';
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
  final OfflineSyncService _syncService = OfflineSyncService();
  
  Map<String, bool> _settings = {};
  bool _isLoading = true;
  bool _isSyncing = false;
  int _pendingOperations = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadSyncStatus();
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

  Future<void> _loadSyncStatus() async {
    _pendingOperations = _syncService.pendingOperationsCount;
    _isSyncing = _syncService.isSyncing;
    setState(() {});
  }

  Future<void> _updateSetting(String key, bool value) async {
    try {
      await _notificationService.updateNotificationSettings(
        emergencyEnabled: key == 'emergency' ? value : null,
        messageEnabled: key == 'messages' ? value : null,
        systemEnabled: key == 'system' ? value : null,
        reminderEnabled: key == 'reminders' ? value : null,
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

  Future<void> _performSync() async {
    if (!_syncService.isOnline) {
      _showErrorSnackBar('You are currently offline');
      return;
    }

    try {
      setState(() => _isSyncing = true);
      await _syncService.forceSync();
      _showSuccessSnackBar('Sync completed successfully!');
    } catch (e) {
      _showErrorSnackBar('Sync failed: ${e.toString()}');
    } finally {
      setState(() => _isSyncing = false);
      _loadSyncStatus();
    }
  }

  Future<void> _downloadOfflineData() async {
    if (!_syncService.isOnline) {
      _showErrorSnackBar('You are currently offline');
      return;
    }

    try {
      setState(() => _isSyncing = true);
      await _syncService.downloadOfflineData();
      _showSuccessSnackBar('Offline data downloaded successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to download offline data: ${e.toString()}');
    } finally {
      setState(() => _isSyncing = false);
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
          'Notifications & Sync',
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
                  
                  // Sync Settings Section
                  _buildSectionHeader(
                    'Offline Sync',
                    IconSystem.refresh,
                    Colors.blue,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildSyncCard(),
                  
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
            'Reminders',
            'Scheduled reminders and alerts',
            IconSystem.clock,
            Colors.green,
            'reminders',
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

  Widget _buildSyncCard() {
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
          // Connection Status
          Row(
            children: [
              Icon(
                _syncService.isOnline ? Icons.wifi : Icons.wifi_off,
                color: _syncService.isOnline ? Colors.green : Colors.red,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _syncService.isOnline ? 'Connected' : 'Offline',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _syncService.isOnline ? Colors.green : Colors.red,
                      ),
                    ),
                    Text(
                      _syncService.isOnline 
                          ? 'Changes will sync automatically'
                          : 'Changes will sync when you go online',
                      style: TextStyle(
                        fontSize: 14,
                        color: ThemeColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Pending Operations
          Row(
            children: [
              Icon(
                Icons.pending_actions,
                color: Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pending Operations',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: ThemeColors.textPrimary(context),
                      ),
                    ),
                    Text(
                      '$_pendingOperations items waiting to sync',
                      style: TextStyle(
                        fontSize: 14,
                        color: ThemeColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (_pendingOperations > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_pendingOperations',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Sync Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _syncService.isOnline && !_isSyncing ? _performSync : null,
              icon: _isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.sync),
              label: Text(
                _isSyncing ? 'Syncing...' : 'Sync Now',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Download Offline Data Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _syncService.isOnline && !_isSyncing ? _downloadOfflineData : null,
              icon: const Icon(Icons.download),
              label: const Text(
                'Download Offline Data',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: ThemeColors.info(context),
                side: BorderSide(color: ThemeColors.info(context)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
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
