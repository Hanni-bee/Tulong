import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../utils/theme_colors.dart';
import '../constants/app_strings.dart';
import '../providers/auth_provider.dart';
import '../providers/power_provider.dart';
import '../widgets/profile_info_card.dart';
import '../widgets/settings_tile.dart';
import 'change_password_screen.dart';
import 'notifications_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.background(context),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/app_logo (3).png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              AppStrings.profile,
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              _showSettingsDialog(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // User profile header
            Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: ThemeColors.surface(context),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.primaryRed,
                        child: Text(
                          (authProvider.userName ?? 'User')[0].toUpperCase(),
                          style: const TextStyle(
                            color: ThemeColors.surface(context),
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        authProvider.userName ?? 'User',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: ThemeColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        authProvider.userUsername ?? 'username',
                        style: const TextStyle(
                          fontSize: 16,
                          color: ThemeColors.textSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRedLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'T.U.L.O.N.G User',
                          style: TextStyle(
                            color: AppColors.primaryRed,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            // Profile information
            const Text(
              'Profile Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ThemeColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 16),
            
            Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                return ProfileInfoCard(
                  title: 'Username',
                  value: authProvider.userUsername ?? 'username',
                  icon: Icons.person,
                  onEdit: null, // Username cannot be edited
                );
              },
            ),
            
            ProfileInfoCard(
              title: 'Address',
              value: '123 Main St, City, Region',
              icon: Icons.location_on,
              onEdit: () => _editField(context, 'Address', '123 Main St, City, Region'),
            ),
            
            const SizedBox(height: 24),
            
            // Settings
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: ThemeColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 16),
            
            SettingsTile(
              title: AppStrings.changePassword,
              subtitle: 'Update your password',
              icon: Icons.lock,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ChangePasswordScreen(),
                  ),
                );
              },
            ),
            
            SettingsTile(
              title: AppStrings.notifications,
              subtitle: 'Manage notification preferences',
              icon: Icons.notifications,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const NotificationsScreen(),
                  ),
                );
              },
            ),
            
            SettingsTile(
              title: 'Privacy & Security',
              subtitle: 'Manage your privacy settings',
              icon: Icons.security,
              onTap: () {
                _showPrivacyDialog(context);
              },
            ),
            
            SettingsTile(
              title: 'About T.U.L.O.N.G',
              subtitle: 'App version 1.0.0',
              icon: Icons.info,
              onTap: () {
                _showAboutDialog(context);
              },
            ),
            
            const SizedBox(height: 24),
            
            // Emergency power status
            Consumer<PowerProvider>(
              builder: (context, powerProvider, child) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: powerProvider.isLowBattery 
                        ? AppColors.warning.withOpacity(0.1)
                        : AppColors.online.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: powerProvider.isLowBattery 
                          ? AppColors.warning 
                          : AppColors.online,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        powerProvider.isCharging 
                            ? Icons.battery_charging_full 
                            : Icons.battery_std,
                        color: powerProvider.isLowBattery 
                            ? AppColors.warning 
                            : AppColors.online,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Emergency Power',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: ThemeColors.textPrimary(context),
                              ),
                            ),
                            Text(
                              '${powerProvider.batteryLevel}% - ${powerProvider.powerStatus}',
                              style: TextStyle(
                                fontSize: 14,
                                color: powerProvider.isLowBattery 
                                    ? AppColors.warning 
                                    : AppColors.online,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (powerProvider.isLowBattery)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.warning,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'LOW',
                            style: TextStyle(
                              color: ThemeColors.surface(context),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _showLogoutDialog(context);
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text(AppStrings.logOut),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: ThemeColors.surface(context),
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
              leading: const Icon(Icons.edit, color: AppColors.primaryRed),
              title: const Text('Edit Profile'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to edit profile
              },
            ),
            ListTile(
              leading: const Icon(Icons.palette, color: AppColors.primaryRed),
              title: const Text('Theme Settings'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Show theme settings
              },
            ),
            ListTile(
              leading: const Icon(Icons.language, color: AppColors.primaryRed),
              title: const Text('Language'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Show language settings
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _editField(BuildContext context, String field, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text('Edit $field'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter $field',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
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
                SnackBar(
                  content: Text('$field updated successfully'),
                  backgroundColor: AppColors.online,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Privacy & Security'),
        content: const Text(
          'Your data is encrypted and stored locally on your device. No personal information is transmitted to external servers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('About T.U.L.O.N.G'),
        content: const Text(
          'T.U.L.O.N.G - Transmission Unit for Local Offline Network Generation\n\nVersion 1.0.0\n\nA disaster-ready communication system for emergency situations.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }


  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                await authProvider.signOut();
                
                // Close dialog first
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                
                // Navigate to sign-in screen and clear navigation stack
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
                    '/signin',
                    (route) => false,
                  );
                }
              } catch (e) {
                print('❌ Logout error: $e');
                // Even if there's an error, try to navigate
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
                    '/signin',
                    (route) => false,
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}
