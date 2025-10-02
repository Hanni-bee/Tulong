import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/user_contacts.dart';
import '../widgets/recent_messages.dart';
import '../utils/responsive_helper.dart';
import '../utils/responsive_spacing.dart';
import 'messages_screen.dart';
import 'calls_screen.dart';
import 'animation_demo_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Row(
          children: [
            // Custom Logo
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryRed.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/app_logo (3).png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              AppStrings.appName,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: AppColors.white,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryRed,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Navigate to notifications
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: ResponsiveHelper.getResponsiveEdgeInsets(context),
            child: AnimationLimiter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section with Enhanced Glassmorphism
                  AnimationConfiguration.staggeredList(
                    position: 0,
                    duration: const Duration(milliseconds: 600),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: Container(
                          width: double.infinity,
                          padding: ResponsiveSpacing.getScreenPadding(context),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryRed.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Logo with animation
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: AppColors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                        color: AppColors.white.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(15),
                                      child: Image.asset(
                                        'assets/images/app_logo (3).png',
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  )
                                      .animate()
                                      .scale(
                                        duration: 800.ms,
                                        curve: Curves.elasticOut,
                                      )
                                      .then()
                                      .shimmer(
                                        duration: 2000.ms,
                                        color: AppColors.white.withOpacity(0.3),
                                      ),
                                  
                                  const SizedBox(width: 16),
                                  
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Welcome to T.U.L.O.N.G',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.white,
                                          ),
                                        )
                                            .animate()
                                            .fadeIn(
                                              duration: 1000.ms,
                                              delay: 300.ms,
                                            )
                                            .slideX(
                                              begin: 0.3,
                                              end: 0,
                                              duration: 1000.ms,
                                              delay: 300.ms,
                                              curve: Curves.easeOutCubic,
                                            ),
                                        
                                        const SizedBox(height: 8),
                                        
                                        const Text(
                                          'Your emergency communication network',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: AppColors.white,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        )
                                            .animate()
                                            .fadeIn(
                                              duration: 1000.ms,
                                              delay: 500.ms,
                                            )
                                            .slideX(
                                              begin: 0.3,
                                              end: 0,
                                              duration: 1000.ms,
                                              delay: 500.ms,
                                              curve: Curves.easeOutCubic,
                                            ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: ResponsiveSpacing.getResponsiveSpacing(context, xs: 20, sm: 25, md: 30)),

                  // Quick Actions with Enhanced Glassmorphism
                  AnimationConfiguration.staggeredList(
                    position: 2,
                    duration: const Duration(milliseconds: 600),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Quick Actions',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            )
                                .animate()
                                .fadeIn(
                                  duration: 800.ms,
                                  delay: 200.ms,
                                )
                                .slideX(
                                  begin: -0.3,
                                  end: 0,
                                  duration: 800.ms,
                                  delay: 200.ms,
                                  curve: Curves.easeOutCubic,
                                ),
                            
                            const SizedBox(height: 16),
                            
                            SizedBox(
                              height: 100,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  QuickActionCard(
                                    title: 'Emergency Alert',
                                    icon: Icons.warning,
                                    color: AppColors.error,
                                    onTap: () {
                                      _showEmergencyDialog(context);
                                    },
                                  ),
                                  QuickActionCard(
                                    title: 'Send Message',
                                    icon: Icons.message,
                                    color: AppColors.info,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => const MessagesScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  QuickActionCard(
                                    title: 'Make Call',
                                    icon: Icons.call,
                                    color: AppColors.success,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => const CallsScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                  QuickActionCard(
                                    title: 'Network Info',
                                    icon: Icons.network_check,
                                    color: AppColors.warning,
                                    onTap: () {
                                      // TODO: Show network info
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: ResponsiveSpacing.getResponsiveSpacing(context, xs: 20, sm: 25, md: 30)),

                  // Recent Messages Section
                  const AnimationConfiguration.staggeredList(
                    position: 3,
                    duration: Duration(milliseconds: 600),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recent Messages',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 16),
                            RecentMessages(),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: ResponsiveSpacing.getResponsiveSpacing(context, xs: 20, sm: 25, md: 30)),

                  // Your Contacts Section
                  const AnimationConfiguration.staggeredList(
                    position: 4,
                    duration: Duration(milliseconds: 600),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your Contacts',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 16),
                            UserContacts(),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 100), // Extra space for FAB
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: Stack(
        children: [
          // Animation Demo FAB
          Positioned(
            right: 0,
            bottom: 80,
            child: FloatingActionButton(
              key: const ValueKey('animation_demo_fab'),
              heroTag: 'animation_demo_fab',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AnimationDemoScreen(),
                  ),
                );
              },
              backgroundColor: AppColors.info,
              foregroundColor: Colors.white,
              child: const Icon(Icons.animation),
            )
                .animate()
                .scale(
                  duration: 600.ms,
                  curve: Curves.elasticOut,
                )
                .then()
                .shimmer(
                  duration: 2000.ms,
                  color: AppColors.white.withOpacity(0.3),
                ),
          ),
          // Emergency Alert FAB
          FloatingActionButton.extended(
            key: const ValueKey('home_emergency_fab'),
            heroTag: 'home_emergency_fab',
            onPressed: () {
              _showEmergencyDialog(context);
            },
            backgroundColor: AppColors.error,
            foregroundColor: AppColors.white,
            icon: const Icon(Icons.warning),
            label: const Text('Emergency Alert'),
          )
              .animate()
              .scale(
                duration: 600.ms,
                curve: Curves.elasticOut,
              )
              .then()
              .shimmer(
                duration: 2000.ms,
                color: AppColors.white.withOpacity(0.3),
              ),
        ],
      ),
    );
  }

  void _showEmergencyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.warning,
                color: AppColors.error,
                size: 28,
              ),
              SizedBox(width: 12),
              Text(
                'Emergency Alert',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          content: const Text(
            'This will send an emergency alert to all connected users in your network. Are you sure you want to proceed?',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.mediumGray,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // TODO: Send emergency alert
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Emergency alert sent!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Send Alert'),
            ),
          ],
        );
      },
    );
  }
}