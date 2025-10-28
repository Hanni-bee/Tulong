import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../constants/app_colors.dart';
import '../widgets/animated_neumorphic_card.dart';
import '../widgets/modern_responsive_layout.dart';
import '../widgets/modern_floating_layout.dart';
import '../widgets/enhanced_text_styles.dart';
import '../widgets/theme_selection_modal.dart';
import '../services/philippine_location_service.dart';
import 'notification_settings_screen.dart';
import '../constants/app_typography.dart';
import '../widgets/enhanced_button.dart';
import '../widgets/polished_animations.dart';
import 'user_info_screen.dart';

class ModernProfileScreen extends StatefulWidget {
  const ModernProfileScreen({super.key});

  @override
  State<ModernProfileScreen> createState() => _ModernProfileScreenState();
}

class _ModernProfileScreenState extends State<ModernProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // User profile data
  final Map<String, dynamic> _userProfile = {
    'name': 'John Doe',
    'email': 'john.doe@example.com',
    'phone': '+63 912 345 6789',
    'location': 'Manila, Philippines',
    'role': 'Emergency Coordinator',
    'status': 'Connected',
    'lastSeen': 'now',
    'joinDate': 'January 2024',
  };

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
    return ModernFloatingLayout(
      hasFloatingAppBar: false,
      hasFloatingBottomBar: true,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                PolishedFadeIn(
                  delay: const Duration(milliseconds: 100),
                  child: _buildHeader(),
                ),
                const SizedBox(height: 24),

                // Profile Info
                PolishedFadeIn(
                  delay: const Duration(milliseconds: 200),
                  child: _buildProfileInfo(),
                ),
                const SizedBox(height: 24),

                // Quick Stats
                PolishedFadeIn(
                  delay: const Duration(milliseconds: 300),
                  child: _buildQuickStats(),
                ),
                const SizedBox(height: 24),

                // Settings Sections
                PolishedFadeIn(
                  delay: const Duration(milliseconds: 400),
                  child: _buildSettingsSections(),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                PolishedFadeIn(
                  delay: const Duration(milliseconds: 500),
                  child: _buildActionButtons(),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return AnimatedNeumorphicCard(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          // Profile icon since this is a main tab (no back button needed)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
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
              Icons.person,
              color: AppColors.info,
              size: 24,
            ),
          ),

          const SizedBox(width: 16),

          // Title
          const Expanded(
            child: PageTitle('Profile'),
          ),

          // User Info button
          //IconButton(
          //  onPressed: () => _viewUserInfo(context),
          //  icon: Container(
          //    padding: const EdgeInsets.all(12),
          //    decoration: BoxDecoration(
          //      color: AppColors.white,
          //       borderRadius: BorderRadius.circular(16),
          //       boxShadow: [
          //         BoxShadow(
          //           color: Colors.black.withOpacity(0.05),
          //           blurRadius: 8,
          //           offset: const Offset(0, 2),
          //         ),
          //         BoxShadow(
          //           color: AppColors.white.withOpacity(0.8),
          //           blurRadius: 8,
          //           offset: const Offset(0, -2),
          //         ),
          //       ],
          //     ),
          //     child: const Icon(
          //       Icons.info_outline,
          //       color: AppColors.info,
          //       size: 24,
          //     ),
          //   ),
          // ),

          // const SizedBox(width: 8),

          // Edit button
          IconButton(
            onPressed: () => _editProfile(context),
            icon: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
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
                Icons.edit,
                color: AppColors.primary,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final userName = authProvider.userName ?? _userProfile['name'];

        // Debug logging
        print(
            'Profile Screen - AuthProvider userName: ${authProvider.userName}');
        print(
            'Profile Screen - AuthProvider userEmail: ${authProvider.userEmail}');
        print(
            'Profile Screen - AuthProvider isAuthenticated: ${authProvider.isAuthenticated}');
        print('Profile Screen - Final userName: $userName');

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AnimatedNeumorphicCard(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Profile Avatar
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(60),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryRed.withOpacity(0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: AppColors.white.withOpacity(0.8),
                          blurRadius: 24,
                          offset: const Offset(0, -10),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(userName),
                        style: AppTypography.displayLarge.copyWith(
                          color: AppColors.white,
                          fontSize: 42,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Name and Role
                  Text(
                    userName,
                    style: AppTypography.displayMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    _userProfile['role'],
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  // Status
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.success.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _userProfile['status'],
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return 'JD';
    final parts = name.trim().split(RegExp(r"\s+"));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].isNotEmpty ? parts[0][0] : '') +
        (parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '');
  }

  Widget _buildQuickStats() {
    return ModernResponsiveGrid(
      children: [
        _buildStatCard(
          title: 'Messages Sent',
          value: '1,234',
          icon: Icons.message,
          color: AppColors.info,
        ),
        _buildStatCard(
          title: 'Emergency Alerts',
          value: '12',
          icon: Icons.emergency,
          color: AppColors.error,
        ),
        _buildStatCard(
          title: 'Calls Made',
          value: '89',
          icon: Icons.call,
          color: AppColors.success,
        ),
        _buildStatCard(
          title: 'Days Active',
          value: '45',
          icon: Icons.calendar_today,
          color: AppColors.warning,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return AnimatedNeumorphicCard(
      child: Column(
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
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSections() {
    return Column(
      children: [
        _buildSettingsSection(
          title: 'Account Settings',
          items: [
            _buildSettingsItem(
              icon: Icons.person,
              title: 'Personal Information',
              subtitle: 'Update your personal details',
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).pushNamed('/update-profile');
              },
            ),
            _buildSettingsItem(
              icon: Icons.security,
              title: 'Security',
              subtitle: 'Password and authentication',
              onTap: () => _openSecurity(context),
            ),
            _buildSettingsItem(
              icon: Icons.notifications,
              title: 'Notifications',
              subtitle: 'Manage notification preferences',
              onTap: () => _openNotifications(context),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSettingsSection(
          title: 'App Settings',
          items: [
            _buildSettingsItem(
              icon: Icons.palette,
              title: 'Theme',
              subtitle: 'Light, Dark, or Auto',
              onTap: () => _openTheme(context),
            ),
            _buildSettingsItem(
              icon: Icons.language,
              title: 'Language',
              subtitle: 'English',
              onTap: () => _openLanguage(context),
            ),
            _buildSettingsItem(
              icon: Icons.privacy_tip,
              title: 'Privacy',
              subtitle: 'Privacy and data settings',
              onTap: () => _openPrivacy(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required List<Widget> items,
  }) {
    return AnimatedNeumorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          ...items,
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        splashColor: AppColors.primaryRed.withOpacity(0.1),
        highlightColor: AppColors.primaryRed.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primary,
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
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppColors.mediumGray,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Sign Out Button
        EnhancedButton(
          text: 'Sign Out',
          variant: ButtonVariant.danger,
          size: ButtonSize.large,
          icon: Icons.logout,
          fullWidth: true,
          onPressed: () {
            _signOut(context);
          },
        ),

        const SizedBox(height: 16),

        // Delete Account Button
        EnhancedButton(
          text: 'Delete Account',
          variant: ButtonVariant.secondary,
          size: ButtonSize.large,
          icon: Icons.delete_forever,
          fullWidth: true,
          onPressed: () {
            _deleteAccount(context);
          },
        ),
      ],
    );
  }

  // Action methods
  void _editProfile(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pushNamed('/update-profile');
  }

  void _viewUserInfo(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const UserInfoScreen(),
      ),
    );
  }

  void _editPersonalInfo(BuildContext context) {
    HapticFeedback.lightImpact();
    final auth = context.read<AuthProvider>();

    // Initialize controllers with current user data
    final TextEditingController firstNameCtrl =
        TextEditingController(text: auth.userName?.split(' ').first ?? '');
    final TextEditingController lastNameCtrl = TextEditingController(
        text: auth.userName?.split(' ').skip(1).join(' ') ?? '');
    final TextEditingController emailCtrl = TextEditingController(
        text: auth.userEmail ?? _userProfile['email'] ?? 'john.doe@example.com');
    final TextEditingController addressCtrl =
        TextEditingController(text: _userProfile['address'] ?? '');
    final TextEditingController phoneCtrl = TextEditingController(text: _userProfile['phone'] ?? '');
    final TextEditingController zipCodeCtrl = TextEditingController(text: _userProfile['zipCode'] ?? '');
    final TextEditingController regionCtrl = TextEditingController(text: _userProfile['region'] ?? '');
    final TextEditingController provinceCtrl = TextEditingController(text: _userProfile['province'] ?? '');
    final TextEditingController cityCtrl = TextEditingController(text: _userProfile['city'] ?? '');
    final TextEditingController barangayCtrl = TextEditingController(text: _userProfile['barangay'] ?? '');

    // Form key for validation
    final _formKey = GlobalKey<FormState>();

    // Location data - use pre-loaded singleton
    String? selectedRegion;
    String? selectedProvince;
    String? selectedCity;
    String? selectedBarangay;

    bool _isLoading = false;

    // Initialize with current user data if it exists
    selectedRegion = _userProfile['region'];
    selectedProvince = _userProfile['province'];
    selectedCity = _userProfile['city'];
    selectedBarangay = _userProfile['barangay'];
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: AnimatedNeumorphicCard(
                margin: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.person,
                              color: AppColors.primary,
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Update Profile',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // First Name
                        TextFormField(
                          controller: firstNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'First Name',
                            border: OutlineInputBorder(),
                            hintText: 'Enter your first name',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'First name is required';
                            }
                            if (value.contains(RegExp(r'[0-9]'))) {
                              return 'First name cannot contain numbers';
                            }
                            return null;
                          },
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                        ),
                        const SizedBox(height: 16),

                        // Last Name
                        TextFormField(
                          controller: lastNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Last Name',
                            border: OutlineInputBorder(),
                            hintText: 'Enter your last name',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Last name is required';
                            }
                            if (value.contains(RegExp(r'[0-9]'))) {
                              return 'Last name cannot contain numbers';
                            }
                            return null;
                          },
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                        ),
                        const SizedBox(height: 16),

                        // Email (Read-only)
                        TextFormField(
                          controller: emailCtrl,
                          enabled: false, // Make email read-only
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                            hintText: 'Email cannot be changed',
                            filled: true,
                            fillColor: AppColors.lightGray,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Address
                        TextFormField(
                          controller: addressCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Address',
                            border: OutlineInputBorder(),
                            hintText: 'Enter your complete address',
                          ),
                          maxLines: 2,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Address is required';
                            }
                            return null;
                          },
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                        ),
                        const SizedBox(height: 16),

                        // Phone
                        TextFormField(
                          controller: phoneCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Phone',
                            border: OutlineInputBorder(),
                            hintText: 'Enter your phone number',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Phone number is required';
                            }
                            return null;
                          },
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                        ),
                        const SizedBox(height: 16),

                        // Zip Code
                        TextFormField(
                          controller: zipCodeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Zip Code',
                            border: OutlineInputBorder(),
                            hintText: 'Enter your zip code',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Zip code is required';
                            }
                            return null;
                          },
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                        ),
                        const SizedBox(height: 16),

                        // Region
                        TextFormField(
                          controller: regionCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Region',
                            border: OutlineInputBorder(),
                            hintText: 'Select Region',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Region is required';
                            }
                            return null;
                          },
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                        ),
                        const SizedBox(height: 16),

                        // Province
                        TextFormField(
                          controller: provinceCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Province',
                            border: OutlineInputBorder(),
                            hintText: 'Select Province',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Province is required';
                            }
                            return null;
                          },
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                        ),
                        const SizedBox(height: 16),

                        // City
                        TextFormField(
                          controller: cityCtrl,
                          decoration: const InputDecoration(
                            labelText: 'City',
                            border: OutlineInputBorder(),
                            hintText: 'Select City',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'City is required';
                            }
                            return null;
                          },
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                        ),
                        const SizedBox(height: 16),

                        // Barangay
                        TextFormField(
                          controller: barangayCtrl,   
                          decoration: const InputDecoration(
                            labelText: 'Barangay',
                            border: OutlineInputBorder(),
                            hintText: 'Select Barangay',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Barangay is required';
                            }
                            return null;
                          },
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                        ),
                        const SizedBox(height: 16),

                        // Region Dropdown
                        DropdownButtonFormField<String>(
                          value: selectedRegion,
                          decoration: const InputDecoration(
                            labelText: 'Region',
                            border: OutlineInputBorder(),
                            hintText: 'Select Region',
                          ),
                          items: PhilippineLocationService.instance
                              .getRegions()
                              .map((region) {
                            return DropdownMenuItem<String>(
                              value: region,
                              child: Text(region),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedRegion = value;
                              // Reset dependent dropdowns
                              selectedProvince = null;
                              selectedCity = null;
                              selectedBarangay = null;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Region is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Province Dropdown
                        DropdownButtonFormField<String>(
                          value: selectedProvince,
                          decoration: const InputDecoration(
                            labelText: 'Province',
                            border: OutlineInputBorder(),
                            hintText: 'Select Province',
                          ),
                          items: selectedRegion != null
                              ? PhilippineLocationService.instance
                                  .getProvincesForRegion(selectedRegion!)
                                  .map((province) {
                                return DropdownMenuItem<String>(
                                  value: province,
                                  child: Text(province),
                                );
                              }).toList()
                              : [const DropdownMenuItem<String>(
                                  value: '',
                                  child: Text('Please select Region first'),
                                )],
                          onChanged: (value) {
                            if (value != null && value.isNotEmpty) {
                              setState(() {
                                selectedProvince = value;
                                // Reset dependent dropdowns
                                selectedCity = null;
                                selectedBarangay = null;
                              });
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Province is required';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // City/Municipality Dropdown
                        DropdownButtonFormField<String>(
                          value: selectedCity,
                          decoration: const InputDecoration(
                            labelText: 'City/Municipality',
                            border: OutlineInputBorder(),
                            hintText: 'Select City/Municipality',
                          ),
                          items: selectedProvince != null
                              ? PhilippineLocationService.instance
                                  .getCitiesForProvince(
                                      selectedRegion!, selectedProvince!)
                                  .map((city) {
                                return DropdownMenuItem<String>(
                                  value: city,
                                  child: Text(city),
                                );
                              }).toList()
                              : [const DropdownMenuItem<String>(
                                  value: '',
                                  child: Text('Please select Province first'),
                                )],
                          onChanged: (value) {
                            if (value != null && value.isNotEmpty) {
                              setState(() {
                                selectedCity = value;
                                // Reset dependent dropdowns
                                selectedBarangay = null;
                              });
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'City/Municipality is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Barangay Dropdown
                        DropdownButtonFormField<String>(
                          value: selectedBarangay,
                          decoration: const InputDecoration(
                            labelText: 'Barangay',
                            border: OutlineInputBorder(),
                            hintText: 'Select Barangay',
                          ),
                          items: selectedCity != null
                              ? PhilippineLocationService.instance
                                  .getBarangaysForCity(selectedRegion!,
                                      selectedProvince!, selectedCity!)
                                  .map((barangay) {
                                return DropdownMenuItem<String>(
                                  value: barangay,
                                  child: Text(barangay),
                                );
                              }).toList()
                              : [const DropdownMenuItem<String>(
                                  value: '',
                                  child: Text('Please select City first'),
                                )],
                          onChanged: (value) {
                            if (value != null && value.isNotEmpty) {
                              setState(() {
                                selectedBarangay = value;
                              });
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Barangay is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _isLoading
                                  ? null
                                  : () async {
                                      if (!_formKey.currentState!
                                          .validate()) {
                                        return;
                                      }
                                      
                                      setState(() {
                                        _isLoading = true;
                                      });

                                      try {
                                        // Update AuthProvider 
                                        await auth.updateUserProfile(
                                          firstName: firstNameCtrl.text.trim(),
                                          lastName: lastNameCtrl.text.trim(),
                                          address: addressCtrl.text.trim(),
                                          region: selectedRegion ?? '',
                                          city: selectedProvince ?? '',
                                          barangay: selectedBarangay ?? '',
                                          phone: phoneCtrl.text.trim(),
                                          zipCode: zipCodeCtrl.text.trim(),
                                          province: selectedProvince ?? '',
                                        );

                                        if (!mounted) return;

                                        // Update local state in the main profile screen
                                        this.setState(() {
                                           _userProfile['name'] = '${firstNameCtrl.text.trim()} ${lastNameCtrl.text.trim()}';
                                           _userProfile['address'] = addressCtrl.text.trim();
                                           _userProfile['region'] = selectedRegion;
                                           _userProfile['province'] = selectedProvince;
                                           _userProfile['city'] = selectedCity;
                                           _userProfile['barangay'] = selectedBarangay;
                                           _userProfile['phone'] = phoneCtrl.text.trim();
                                           _userProfile['zipCode'] = zipCodeCtrl.text.trim();
                                           
                                        });

                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                              content: Text('Profile updated successfully'),
                                              backgroundColor: AppColors.success),
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                              content: Text('Error updating profile: $e'),
                                              backgroundColor: AppColors.error),
                                        );
                                      } finally {
                                        if (mounted) {
                                          setState(() {
                                            _isLoading = false;
                                          });
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryRed,
                                  foregroundColor: AppColors.white),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white),
                                    )
                                  : const Text('Save'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // **FIX**: Restored the missing _openNotifications method
  void _openNotifications(BuildContext context) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const NotificationSettingsScreen(),
      ),
    );
  }

  void _openTheme(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ThemeSelectionModal(),
    );
  }

  void _openLanguage(BuildContext context) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Language settings'),
        backgroundColor: AppColors.info,
      ),
    );
  }

  void _openPrivacy(BuildContext context) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Privacy settings'),
        backgroundColor: AppColors.info,
      ),
    );
  }

  void _openSecurity(BuildContext context) {
    HapticFeedback.lightImpact();
    final auth = context.read<AuthProvider>();

    // Check if user is using Gmail SSO
    final bool isGmailSSO = auth.isGmailSSO;

    final TextEditingController currentCtrl = TextEditingController();
    final TextEditingController newCtrl = TextEditingController();
    final TextEditingController confirmCtrl = TextEditingController();

    // State for password visibility
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom),
              child: AnimatedNeumorphicCard(
                margin: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isGmailSSO ? Icons.account_circle : Icons.security,
                          color: AppColors.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Security',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary),
                          ),
                        ),
                        if (isGmailSSO)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.info.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.info.withOpacity(0.3)),
                            ),
                            child: const Text(
                              'Google Account',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.info,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (!isGmailSSO) ...[
                      // Current Password (only for sign-up accounts)
                      TextField(
                        controller: currentCtrl,
                        obscureText: obscureCurrent,
                        decoration: InputDecoration(
                          labelText: 'Current Password',
                          border: const OutlineInputBorder(),
                          hintText: 'Enter your current password',
                          suffixIcon: IconButton(
                            icon: Icon(obscureCurrent
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () {
                              setModalState(() {
                                obscureCurrent = !obscureCurrent;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // New Password
                    TextField(
                      controller: newCtrl,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: isGmailSSO ? 'New or Create Password' : 'New Password',
                        border: const OutlineInputBorder(),
                        hintText: isGmailSSO ? 'Enter a password to enable email login' : 'Enter your new password',
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () {
                            setModalState(() {
                              obscureNew = !obscureNew;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Confirm Password
                    TextField(
                      controller: confirmCtrl,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        border: const OutlineInputBorder(),
                        hintText: 'Confirm your new password',
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () {
                            setModalState(() {
                              obscureConfirm = !obscureConfirm;
                            });
                          },
                        ),
                      ),
                    ),
                    if (isGmailSSO) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.info.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.info.withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: AppColors.info, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'You can create a password to enable email/password login alongside your Google Sign-In.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.info,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            if (newCtrl.text.isEmpty || confirmCtrl.text.isEmpty) {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill out all password fields.'), backgroundColor: AppColors.error));
                               return;
                            }
                            if (newCtrl.text.length < 6) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters.'), backgroundColor: AppColors.error));
                              return;
                            }
                            if (newCtrl.text != confirmCtrl.text) {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match.'), backgroundColor: AppColors.error));
                               return;
                            }
                            
                            try {
                               bool success = false;
                               if(isGmailSSO){
                                  await auth.createPasswordForGoogleAccount(newCtrl.text);
                                  success = true;
                               } else {
                                  if (currentCtrl.text.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your current password.'), backgroundColor: AppColors.error));
                                      return;
                                  }
                                  final isValid = await auth.verifyCurrentPassword(currentCtrl.text);
                                  if(!mounted) return;
                                  if(isValid){
                                    await auth.updatePassword(newCtrl.text);
                                    success = true;
                                  } else {
                                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Current password is incorrect.'), backgroundColor: AppColors.error));
                                  }
                               }

                               if(!mounted) return;

                               if(success){
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated successfully!'), backgroundColor: AppColors.success));
                               }
                            } catch (e) {
                              if(!mounted) return;
                               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An error occurred: $e'), backgroundColor: AppColors.error));
                            }
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryRed,
                              foregroundColor: AppColors.white),
                          child: const Text('Update'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _signOut(BuildContext context) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final authProvider = context.read<AuthProvider>();
              final navigator = Navigator.of(context);

              navigator.pop(context); // Close the dialog first

              authProvider.signOut();
              navigator.pushNamedAndRemoveUntil('/signin', (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  void _deleteAccount(BuildContext context) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
            'This action cannot be undone. Are you sure you want to delete your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account deletion requested'),
                  backgroundColor: AppColors.error,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}