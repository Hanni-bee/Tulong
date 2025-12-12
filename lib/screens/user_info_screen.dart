import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../constants/app_colors.dart';
import '../widgets/animated_neumorphic_card.dart';
import '../constants/app_typography.dart';

class UserInfoScreen extends StatefulWidget {
  const UserInfoScreen({super.key});

  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: AppColors.white.withOpacity(0.8),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back,
              color: AppColors.textPrimary,
              size: 20,
            ),
          ),
        ),
        title: const Text(
          'User Information',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                final user = authProvider.currentUserModel;
                
                // If UserModel is null, try to load it
                if (user == null && authProvider.isAuthenticated) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    authProvider.loadUserModel();
                  });
                }
                
                // Debug logging
                print('UserInfoScreen - User data: ${user?.toMap()}');
                print('UserInfoScreen - User name: ${user?.name}');
                print('UserInfoScreen - User email: ${user?.email}');
                print('UserInfoScreen - User phone: ${user?.phone}');
                print('UserInfoScreen - User street: ${user?.street}');
                print('UserInfoScreen - User barangay: ${user?.barangay}');
                print('UserInfoScreen - User city: ${user?.city}');
                print('UserInfoScreen - User province: ${user?.province}');

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card
                    AnimatedNeumorphicCard(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(40),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryRed.withOpacity(0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  _getInitials(user?.name ?? 'User'),
                                  style: AppTypography.displayLarge.copyWith(
                                    color: AppColors.white,
                                    fontSize: 32,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'User Information',
                              style: AppTypography.titleLarge.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Current logged-in user details',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // User Information Cards
                    _buildInfoCard(
                      title: 'Full Name',
                      value: user?.name ?? 'Not available',
                      icon: Icons.person,
                      color: AppColors.primary,
                    ),

                    const SizedBox(height: 16),

                    _buildInfoCard(
                      title: 'Email',
                      value: user?.email ?? 'Not available',
                      icon: Icons.email,
                      color: AppColors.info,
                    ),

                    const SizedBox(height: 16),

                    _buildInfoCard(
                      title: 'Phone Number',
                      value: user?.phone ?? 'Not available',
                      icon: Icons.phone,
                      color: AppColors.success,
                    ),

                    const SizedBox(height: 16),

                    _buildInfoCard(
                      title: 'Region',
                      value: user?.region ?? 'Not available',
                      icon: Icons.location_on,
                      color: AppColors.warning,
                    ),

                    const SizedBox(height: 16),

                    _buildInfoCard(
                      title: 'Province',
                      value: user?.province ?? 'Not available',
                      icon: Icons.map,
                      color: AppColors.error,
                    ),

                    const SizedBox(height: 16),

                    _buildInfoCard(
                      title: 'City/Municipality',
                      value: user?.city ?? 'Not available',
                      icon: Icons.location_city,
                      color: AppColors.primary,
                    ),

                    const SizedBox(height: 16),

                    _buildInfoCard(
                      title: 'Barangay',
                      value: user?.barangay ?? 'Not available',
                      icon: Icons.home,
                      color: AppColors.info,
                    ),

                    const SizedBox(height: 16),

                    _buildInfoCard(
                      title: 'Address',
                      value: user?.street ?? 'Not available',
                      icon: Icons.location_on,
                      color: AppColors.success,
                    ),

                    const SizedBox(height: 16),

                    // Zipcode removed

                    const SizedBox(height: 32),

                    // Debug Information Card
                    AnimatedNeumorphicCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.bug_report,
                                  color: AppColors.warning,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Debug Information',
                                  style: AppTypography.titleMedium.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'User ID: ${user?.id ?? 'Not available'}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Is Google Auth: ${user?.isGoogleAuth ?? false}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Address Setup Completed: ${user?.addressSetupCompleted ?? false}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 4),
                              Text(
                              'Account Status: ${user?.accountStatus ?? 'Not available'}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return AnimatedNeumorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r"\s+"));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].isNotEmpty ? parts[0][0] : '') +
        (parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '');
  }
}
