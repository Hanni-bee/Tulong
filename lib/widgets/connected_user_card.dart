import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class ConnectedUserCard extends StatelessWidget {
  final String name;
  final bool isOnline;
  final int signalStrength;
  final int batteryLevel;
  final VoidCallback? onCall;
  final VoidCallback? onDisconnect;

  const ConnectedUserCard({
    super.key,
    required this.name,
    required this.isOnline,
    required this.signalStrength,
    required this.batteryLevel,
    this.onCall,
    this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: isOnline ? onCall : null,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.cardGlassGradient,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isOnline ? AppColors.online.withOpacity(0.3) : AppColors.mediumGray.withOpacity(0.3),
                width: 2,
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
                // Enhanced User avatar
                Stack(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: isOnline ? AppColors.successGradient : AppColors.warningGradient,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: AppColors.white.withOpacity(0.2),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isOnline ? AppColors.online : AppColors.mediumGray).withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.transparent,
                        child: Text(
                          name.split(' ').map((e) => e[0]).join(),
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    if (isOnline)
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
                
                // User info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Signal strength
                          Row(
                            children: List.generate(5, (index) {
                              return Container(
                                width: 3,
                                height: 8 + (index * 2),
                                margin: const EdgeInsets.only(right: 2),
                                decoration: BoxDecoration(
                                  color: index < signalStrength 
                                      ? AppColors.online 
                                      : AppColors.lightGray,
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Signal: $signalStrength/5',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.battery_std,
                            size: 14,
                            color: batteryLevel > 20 
                                ? AppColors.online 
                                : AppColors.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Battery: $batteryLevel%',
                            style: TextStyle(
                              fontSize: 12,
                              color: batteryLevel > 20 
                                  ? AppColors.textSecondary 
                                  : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Action buttons
                Row(
                  children: [
                    if (isOnline && onCall != null)
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.online,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          onPressed: onCall,
                          icon: const Icon(
                            Icons.call,
                            color: AppColors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    if (onDisconnect != null)
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          onPressed: onDisconnect,
                          icon: const Icon(
                            Icons.close,
                            color: AppColors.white,
                            size: 18,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
