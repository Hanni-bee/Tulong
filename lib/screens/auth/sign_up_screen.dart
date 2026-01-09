import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui' show ImageFilter;
import '../../constants/app_colors.dart';
import '../../constants/unified_typography.dart';
import '../../widgets/enhanced_text_field.dart';
import '../../widgets/password_strength_indicator.dart';
import '../../widgets/terms_conditions_modal.dart';
import '../../widgets/elite_liquid_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/firebase_service.dart';
import '../../services/location_service.dart';
import '../../services/sqlite_service.dart';
import '../../utils/input_validator.dart';
import '../../utils/responsive_spacing.dart';
import '../../utils/haptic_helper.dart';
import 'biometric_verification_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _suffixController = TextEditingController();
  final _usernameController = TextEditingController(); // Replaced email with username
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _acceptedTerms = false;
  
  // Location data
  String? _selectedRegion;
  String? _selectedProvince;
  String? _selectedCity;
  String? _selectedBarangay;
  
  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _barangays = [];
  
  bool _isLoadingLocations = false;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _suffixController.dispose();
    _usernameController.dispose(); // Replaced email with username
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }


  Future<void> _loadRegions() async {
    setState(() {
      _isLoadingLocations = true;
    });
    
    try {
      final regions = await LocationService.getRegions();
      if (regions.isEmpty) {
        _regions = LocationService.getFallbackRegions();
      } else {
        _regions = regions;
      }
    } catch (e) {
      _regions = LocationService.getFallbackRegions();
    }
    
    setState(() {
      _isLoadingLocations = false;
    });
  }

  Future<void> _loadProvinces(String regionCode) async {
    setState(() {
      _isLoadingLocations = true;
    });
    
    try {
      _provinces = await LocationService.getProvinces(regionCode);
      if (_provinces.isEmpty) {
        _provinces = LocationService.getFallbackProvinces(regionCode);
      }
    } catch (e) {
      _provinces = LocationService.getFallbackProvinces(regionCode);
    }
    
    setState(() {
      _isLoadingLocations = false;
    });
  }

  Future<void> _loadCities(String provinceCode) async {
    setState(() {
      _isLoadingLocations = true;
    });
    try {
      _cities = await LocationService.getCities(provinceCode);
    } catch (e) {
      _cities = LocationService.getFallbackCities(provinceCode);
    }
    setState(() {
      _isLoadingLocations = false;
    });
  }


  Future<void> _loadBarangays(String cityCode) async {
    setState(() {
      _isLoadingLocations = true;
    });
    
    try {
      _barangays = await LocationService.getBarangays(cityCode);
      if (_barangays.isEmpty) {
        _barangays = LocationService.getFallbackBarangays(cityCode);
      }
    } catch (e) {
      _barangays = LocationService.getFallbackBarangays(cityCode);
    }
    
    setState(() {
      _isLoadingLocations = false;
    });
  }



  Future<void> _signUp() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the Terms and Conditions'),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check if an account already exists on this device (1:1 device-to-account relationship)
      // First check SharedPreferences for quick check
      final prefs = await SharedPreferences.getInstance();
      final deviceAccountExists = prefs.getBool('device_account_exists') ?? false;
      
      if (deviceAccountExists) {
        // Double-check with SQLite to ensure consistency
        final sqliteService = SQLiteService();
        final existingUsers = await sqliteService.getAllUsers();
        
        if (existingUsers.isNotEmpty) {
          // Account already exists - prevent registration
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('An account already exists on this device. Only one account per device is allowed.'),
                backgroundColor: AppColors.primary,
                duration: Duration(seconds: 4),
              ),
            );
          }
          return;
        } else {
          // Flag was set but no users found - reset flag
          await prefs.setBool('device_account_exists', false);
        }
      } else {
        // Also check SQLite directly in case SharedPreferences was cleared
        final sqliteService = SQLiteService();
        final existingUsers = await sqliteService.getAllUsers();
        
        if (existingUsers.isNotEmpty) {
          // Account exists but flag not set - update flag and prevent registration
          await prefs.setBool('device_account_exists', true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('An account already exists on this device. Only one account per device is allowed.'),
                backgroundColor: AppColors.primary,
                duration: Duration(seconds: 4),
              ),
            );
          }
          return;
        }
      }

      final first = _firstNameController.text.trim();
      final last = _lastNameController.text.trim();
      final suffix = _suffixController.text.trim();
      final username = _usernameController.text.trim();
      final pwd = _passwordController.text;

      // Get region name from code
      String regionName = _selectedRegion ?? '';
      if (_selectedRegion != null) {
        final regionData = _regions.firstWhere(
          (r) => r['code'] == _selectedRegion,
          orElse: () => {'name': _selectedRegion!},
        );
        regionName = regionData['name'] ?? _selectedRegion!;
      }

      // Get province name from code if needed
      String provinceName = _selectedProvince ?? '';
      if (_selectedProvince != null && _provinces.isNotEmpty) {
        final provinceData = _provinces.firstWhere(
          (p) => p['code'] == _selectedProvince,
          orElse: () => {'name': _selectedProvince!},
        );
        provinceName = provinceData['name'] ?? _selectedProvince!;
      }

      // Hash password
      final firebaseService = FirebaseService();
      final hashedPassword = firebaseService.hashPassword(pwd);

      // Prepare registration data to pass to biometric screen
      final registrationData = {
        'firstName': first,
        'lastName': last,
        'suffix': suffix.isEmpty ? null : suffix,
        'username': username,
        'address': _addressController.text.trim(),
        'region': regionName,
        'province': provinceName,
        'city': _selectedCity ?? '',
        'barangay': _selectedBarangay ?? '',
        'hashedPassword': hashedPassword,
      };

      // Navigate to biometric verification screen
      // Data will be saved after successful biometric verification
      if (!mounted) return;
      
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => BiometricVerificationScreen(
            registrationData: registrationData,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign up failed: ${e.toString()}'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Liquid Background
          const EliteLiquidBackground(isLight: true),
          
          Column(
            children: [
              AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primaryRed),
                  onPressed: () {
                    HapticHelper.medium();
                    Navigator.of(context).pop();
                  },
                ),
                title: Text(
                  'Create Account',
                  style: UnifiedTypography.headlineSmall.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                centerTitle: true,
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: ResponsiveSpacing.getResponsivePadding(context, horizontal: 20, vertical: 0),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      
                      // Disaster-focused header
                      _buildDisasterHeader(),
                      
                      const SizedBox(height: 32),
                      
                      // Sign up form
                      _buildSignUpForm(),
                      
                      const SizedBox(height: 32),
                      
                      // Sign in link
                      _buildSignInLink(),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDisasterHeader() {
    return Column(
      children: [
        // T.U.L.O.N.G logo with layered glow
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryRed.withOpacity(0.15),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Image.asset(
              'assets/images/app_logo (3).png',
              fit: BoxFit.contain,
            ),
          ),
        ).animate()
         .scale(duration: 800.ms, curve: Curves.elasticOut)
         .shimmer(delay: 2.seconds, duration: 1.5.seconds),
        
        const SizedBox(height: 24),
        
        Text(
          'T.U.L.O.N.G',
          style: UnifiedTypography.displaySmall.copyWith(
            color: AppColors.primaryRed,
            fontWeight: FontWeight.w900,
            letterSpacing: 4.0,
          ),
        ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.2, end: 0),
        
        const SizedBox(height: 8),
        
        Text(
          'Join the Disaster-Ready Community',
          style: UnifiedTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary.withOpacity(0.6),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ).animate().fadeIn(duration: 800.ms, delay: 200.ms).slideY(begin: 0.2, end: 0),
      ],
    );
  }

  Widget _buildSignUpForm() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionHeader('Personal Information'),
                const SizedBox(height: 20),
                
                // First Name field
                EnhancedTextField(
                  controller: _firstNameController,
                  label: 'First Name',
                  hint: 'Enter your first name',
                  prefixIcon: Icons.person_outline_rounded,
                  validator: (value) => InputValidator.validateName(value, 'First Name'),
                ),
                
                const SizedBox(height: 20),
                
                // Last Name field
                EnhancedTextField(
                  controller: _lastNameController,
                  label: 'Last Name',
                  hint: 'Enter your last name',
                  prefixIcon: Icons.badge_outlined,
                  validator: (value) => InputValidator.validateName(value, 'Last Name'),
                ),
                
                const SizedBox(height: 20),
                
                // Suffix field (optional)
                EnhancedTextField(
                  controller: _suffixController,
                  label: 'Suffix (optional)',
                  hint: 'Jr., Sr., III, etc.',
                  prefixIcon: Icons.text_fields,
                  validator: (value) {
                    // Optional field - no validation error if empty
                    if (value != null && value.trim().isNotEmpty) {
                      // If provided, validate it's reasonable
                      if (value.trim().length > 10) {
                        return 'Suffix is too long';
                      }
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),
                
                // Username field
                EnhancedTextField(
                  controller: _usernameController,
                  label: 'Username',
                  hint: 'Min 6 characters, letters/numbers',
                  prefixIcon: Icons.alternate_email_rounded,
                  validator: InputValidator.validateUsername,
                ),
                
                const SizedBox(height: 32),
                _buildSectionHeader('Location'),
                const SizedBox(height: 20),
                
                // Region dropdown
                _buildModernDropdown(
                  label: 'Region',
                  value: _selectedRegion,
                  hint: 'Select Region',
                  icon: Icons.map_outlined,
                  items: _regions.map((r) => DropdownMenuItem(
                    value: r['code'] as String,
                    child: Text(r['name'] as String),
                  )).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedRegion = val;
                      _selectedProvince = null;
                      _selectedCity = null;
                      _selectedBarangay = null;
                    });
                    if (val != null) _loadProvinces(val);
                  },
                  validator: (v) => v == null ? 'Region is required' : null,
                ),
                
                const SizedBox(height: 20),
                
                // Province dropdown
                _buildModernDropdown(
                  label: 'Province',
                  value: _selectedProvince,
                  hint: 'Select Province',
                  icon: Icons.location_city_outlined,
                  items: _provinces.map((p) => DropdownMenuItem(
                    value: p['code'] as String,
                    child: Text(p['name'] as String),
                  )).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedProvince = val;
                      _selectedCity = null;
                      _selectedBarangay = null;
                    });
                    if (val != null) _loadCities(val);
                  },
                  validator: (v) => v == null ? 'Province is required' : null,
                ),
                
                const SizedBox(height: 20),
                
                // City dropdown
                _buildModernDropdown(
                  label: 'City/Municipality',
                  value: _selectedCity,
                  hint: 'Select City',
                  icon: Icons.apartment_rounded,
                  items: _cities.map((c) => DropdownMenuItem(
                    value: c['name'] as String,
                    child: Text(c['name'] as String),
                  )).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCity = val;
                      _selectedBarangay = null;
                    });
                    if (val != null) _loadBarangays(val);
                  },
                  validator: (v) => v == null ? 'City is required' : null,
                ),
                
                const SizedBox(height: 20),
                
                // Barangay dropdown
                _buildModernDropdown(
                  label: 'Barangay',
                  value: _selectedBarangay,
                  hint: 'Select Barangay',
                  icon: Icons.home_work_outlined,
                  items: _barangays.map((b) => DropdownMenuItem(
                    value: b['code'] as String,
                    child: Text(b['name'] as String),
                  )).toList(),
                  onChanged: (val) => setState(() => _selectedBarangay = val),
                  validator: (v) => v == null ? 'Barangay is required' : null,
                ),
                
                const SizedBox(height: 20),

                EnhancedTextField(
                  controller: _addressController,
                  label: 'House No. / Street',
                  hint: 'Enter your specific address',
                  prefixIcon: Icons.home_outlined,
                  validator: InputValidator.validateAddress,
                ),
                
                const SizedBox(height: 32),
                _buildSectionHeader('Security'),
                const SizedBox(height: 20),
                
                // Password
                EnhancedTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Create a strong password',
                  prefixIcon: Icons.lock_open_rounded,
                  isPassword: true,
                  validator: PasswordValidator.validate,
                ),
                
                if (_passwordController.text.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  PasswordStrengthIndicator(
                    password: _passwordController.text,
                    showIndicator: true,
                  ),
                ],
                
                const SizedBox(height: 20),
                
                // Confirm Password
                EnhancedTextField(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  hint: 'Re-enter your password',
                  prefixIcon: Icons.lock_outline_rounded,
                  isPassword: true,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Confirm your password';
                    if (val != _passwordController.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                
                const SizedBox(height: 32),
                
                // Terms and Conditions
                _buildModernTerms(),
                
                const SizedBox(height: 32),
                
                // Sign up button
                _buildModernSignUpButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernDropdown({
    required String label,
    required String? value,
    required String hint,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label.toUpperCase(),
            style: UnifiedTypography.labelMedium.copyWith(
              color: AppColors.textSecondary.withOpacity(0.7),
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              fontSize: 11,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.textSecondary.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.01),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: UnifiedTypography.bodyMedium.copyWith(color: AppColors.textSecondary.withOpacity(0.3)),
              prefixIcon: Icon(icon, color: AppColors.textSecondary.withOpacity(0.4), size: 22),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
            items: items.isEmpty 
              ? [DropdownMenuItem(value: null, child: Text(_isLoadingLocations ? 'Loading...' : 'None'))] 
              : items,
            onChanged: (val) {
              HapticHelper.light();
              onChanged(val);
            },
            validator: validator,
            style: UnifiedTypography.bodyLarge.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ],
    );
  }

  Widget _buildModernTerms() {
    return GestureDetector(
      onTap: () async {
        HapticHelper.light();
        final result = await showDialog<bool>(
          context: context,
          builder: (context) => const TermsConditionsModal(),
        );
        if (result == true) setState(() => _acceptedTerms = true);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _acceptedTerms ? AppColors.primaryRed.withOpacity(0.05) : AppColors.lightGray.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _acceptedTerms ? AppColors.primaryRed.withOpacity(0.2) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _acceptedTerms ? AppColors.primaryRed : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _acceptedTerms ? AppColors.primaryRed : AppColors.textSecondary.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: _acceptedTerms 
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) 
                : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'I agree to the Terms and Conditions',
                style: UnifiedTypography.bodyMedium.copyWith(
                  color: _acceptedTerms ? AppColors.primaryRed : AppColors.textSecondary,
                  fontWeight: _acceptedTerms ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate(target: _acceptedTerms ? 1 : 0).shimmer(color: Colors.white.withOpacity(0.2));
  }

  Widget _buildModernSignUpButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 60,
      child: ElevatedButton(
        onPressed: (_isLoading || !_acceptedTerms) ? null : _signUp,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryRed,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.lightGray,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: _acceptedTerms ? 8 : 0,
          shadowColor: AppColors.primaryRed.withOpacity(0.5),
        ),
        child: _isLoading 
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Create Account',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.arrow_forward_rounded),
              ],
            ),
      ),
    ).animate(target: _acceptedTerms ? 1 : 0).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primaryRed,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: UnifiedTypography.titleMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSignInLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Already have an account? ",
          style: UnifiedTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        GestureDetector(
          onTap: () {
            HapticHelper.medium();
            Navigator.pop(context);
          },
          child: Text(
            'Sign In',
            style: UnifiedTypography.bodyMedium.copyWith(
              color: AppColors.primaryRed,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ).animate().fade(delay: 500.ms);
  }
}