import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../constants/soft_ui_design.dart';

/// Modern Connected Users Modal with Cyan Blue Design
class ConnectedUsersListModal extends StatelessWidget {
  const ConnectedUsersListModal({super.key});

  static const Color cyanBlue = Color(0xFF3498DB);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Consumer<ChatProvider>(
          builder: (context, provider, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Modern Header with Gradient
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cyanBlue,
                        cyanBlue.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.people,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Connected Users',
                              style: AppTypography.headlineSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${provider.connectedUsersCount} user${provider.connectedUsersCount != 1 ? 's' : ''} on channel',
                              style: AppTypography.bodySmall.copyWith(
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                
                // Connection Status Card
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: provider.isConnected 
                          ? cyanBlue.withOpacity(0.1) 
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: provider.isConnected 
                            ? cyanBlue.withOpacity(0.3) 
                            : Colors.grey.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: provider.isConnected 
                                ? cyanBlue.withOpacity(0.2) 
                                : Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            provider.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                            color: provider.isConnected ? cyanBlue : Colors.grey,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                provider.isConnected 
                                    ? 'Connected' 
                                    : 'Not Connected',
                                style: AppTypography.bodyLarge.copyWith(
                                  color: provider.isConnected ? cyanBlue : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                provider.isConnected 
                                    ? 'Device: ${provider.selectedDevice?.name ?? "ESP32"}' 
                                    : 'Connect to a device to see users',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.mediumGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Connected Users List
                if (provider.isConnected && provider.connectedUsers.isNotEmpty) ...[
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: provider.connectedUsers.length,
                        itemBuilder: (context, index) {
                          final user = provider.connectedUsers[index];
                          final isCurrentUser = provider.isCurrentUser(user);
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCurrentUser 
                                    ? cyanBlue.withOpacity(0.3) 
                                    : Colors.grey.withOpacity(0.2),
                                width: isCurrentUser ? 1.5 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: isCurrentUser
                                        ? [cyanBlue, cyanBlue.withOpacity(0.7)]
                                        : [Colors.grey.withOpacity(0.3), Colors.grey.withOpacity(0.1)],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    user.isNotEmpty ? user[0].toUpperCase() : '?',
                                    style: AppTypography.bodyLarge.copyWith(
                                      color: isCurrentUser ? Colors.white : AppColors.mediumGray,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      user,
                                      style: AppTypography.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.darkGray,
                                      ),
                                    ),
                                  ),
                                  if (isCurrentUser) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [cyanBlue, cyanBlue.withOpacity(0.8)],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Me',
                                        style: AppTypography.bodySmall.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              trailing: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: cyanBlue,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: cyanBlue.withOpacity(0.5),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else if (provider.isConnected) ...[
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: cyanBlue.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person_outline,
                                size: 64,
                                color: cyanBlue,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'You\'re the only one',
                              style: AppTypography.headlineSmall.copyWith(
                                color: AppColors.darkGray,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No other users connected to the channel yet',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.mediumGray,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.bluetooth_disabled,
                                size: 64,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Not Connected',
                              style: AppTypography.headlineSmall.copyWith(
                                color: AppColors.darkGray,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Connect to an ESP32 device to see connected users',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.mediumGray,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
