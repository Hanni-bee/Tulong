import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../constants/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/password_strength_indicator.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/offline_auth_service.dart';
import '../../widgets/terms_conditions_modal.dart';
import '../../services/location_service.dart';
import '../../utils/input_validator.dart';
import '../../utils/responsive_spacing.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _acceptedTerms = false;
  
  // Real-time validation states
  bool _hasMinLength = false;
  bool _hasSpecialChar = false;
  bool _hasUppercase = false;
  bool _nameHasNumbers = false;

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
    _emailController.dispose();
    _addressController.dispose();
    _zipCodeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _checkPasswordRequirements(String password) {
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
    });
  }

  void _checkNameValidation(String name) {
    setState(() {
      _nameHasNumbers = name.contains(RegExp(r'[0-9]'));
    });
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
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final first = _firstNameController.text.trim();
      final last = _lastNameController.text.trim();
      final email = _emailController.text.trim();
      final pwd = _passwordController.text;

      // Prefer online (Firebase); if offline, fallback to SQLite and queue sync
      Map<String, dynamic>? user;
      try {
        final cred = await FirebaseService().signUpWithEmail(
          email: email,
          password: pwd,
          firstName: first,
          lastName: last,
          address: _addressController.text.trim(),
          region: _selectedRegion ?? '',
          city: _selectedProvince ?? '',
          barangay: _selectedBarangay ?? '',
          zipCode: _zipCodeController.text.trim(),
        );
        // Mirror into SQLite for offline
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        user = await authProvider.signupOffline(
          email: email,
          password: pwd,
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          address: _addressController.text.trim(),
          region: _selectedRegion ?? '',
          city: _selectedProvince ?? '', // Using province as city for now
          barangay: _selectedBarangay ?? '',
          zipCode: _zipCodeController.text.trim(),
        );
      } catch (_) {
        // Offline path only
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        user = await authProvider.signupOffline(
          email: email,
          password: pwd,
          firstName: first,
          lastName: last,
          address: _addressController.text.trim(),
          region: _selectedRegion ?? '',
          city: _selectedProvince ?? '',
          barangay: _selectedBarangay ?? '',
          zipCode: _zipCodeController.text.trim(),
        );
      }

      if (!mounted) return;
      // Also register in AuthProvider demo registry + create session
      await Provider.of<AuthProvider>(context, listen: false).setAuthenticated(
        email: email,
        name: '$first $last',
      );
      // Navigate to splash screen to handle tutorial logic for new users
      Navigator.of(context).pushReplacementNamed('/');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign up failed: ${e.toString()}'),
            backgroundColor: AppColors.error,
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryRed),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Create Account',
          style: TextStyle(
            color: AppColors.primaryRed,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: ResponsiveSpacing.getResponsivePadding(context, horizontal: 16, vertical: 0),
        child: Column(
          children: [
            SizedBox(height: ResponsiveSpacing.getResponsiveSpacing(context, xs: 16, sm: 18, md: 20)),
            
            // Disaster-focused header
            _buildDisasterHeader(),
            
            SizedBox(height: ResponsiveSpacing.getResponsiveSpacing(context, xs: 30, sm: 35, md: 40)),
            
            // Sign up form
            _buildSignUpForm(),
            
            SizedBox(height: ResponsiveSpacing.getResponsiveSpacing(context, xs: 20, sm: 25, md: 30)),
            
            // Sign in link
            _buildSignInLink(),
            
            SizedBox(height: ResponsiveSpacing.getResponsiveSpacing(context, xs: 16, sm: 18, md: 20)),
          ],
        ),
      ),
    );
  }

  Widget _buildDisasterHeader() {
    return Column(
      children: [
        // T.U.L.O.N.G logo with red accent
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primaryRed,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryRed.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/images/app_logo (3).png',
              width: 80,
              height: 80,
              fit: BoxFit.contain,
            ),
          ),
        )
            .animate()
            .scale(
              duration: 800.ms,
              curve: Curves.elasticOut,
            ),
        
        const SizedBox(height: 20),
        
        const Text(
          'T.U.L.O.N.G',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryRed,
            letterSpacing: 2.0,
          ),
        )
            .animate()
            .fadeIn(
              duration: 1000.ms,
              delay: 300.ms,
            )
            .slideY(
              begin: 0.3,
              end: 0,
              duration: 1000.ms,
              delay: 300.ms,
              curve: Curves.easeOutCubic,
            ),
        
        const SizedBox(height: 8),
        
        const Text(
          'Join the Disaster-Ready Community',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
            letterSpacing: 0.5,
          ),
        )
            .animate()
            .fadeIn(
              duration: 1000.ms,
              delay: 500.ms,
            )
            .slideY(
              begin: 0.3,
              end: 0,
              duration: 1000.ms,
              delay: 500.ms,
              curve: Curves.easeOutCubic,
            ),
      ],
    );
  }

  Widget _buildSignUpForm() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
          // First Name field
          CustomTextField(
            controller: _firstNameController,
            label: 'First Name',
            hint: 'Enter your first name',
            prefixIcon: Icons.person_outline,
            onChanged: (value) {
              _checkNameValidation(value);
            },
            validator: (value) {
              return InputValidator.validateName(value, 'First Name');
            },
          ),
          
          // Real-time name validation indicator
          if (_firstNameController.text.isNotEmpty && _nameHasNumbers) ...[
            const SizedBox(height: 8),
            _buildNameValidationError('First name cannot contain numbers'),
          ],
          
          SizedBox(height: ResponsiveSpacing.getResponsiveSpacing(context, xs: 16, sm: 18, md: 20)),
          
          // Last Name field
          CustomTextField(
            controller: _lastNameController,
            label: 'Last Name',
            hint: 'Enter your last name',
            prefixIcon: Icons.badge_outlined,
            onChanged: (value) {
              _checkNameValidation(value);
            },
            validator: (value) {
              return InputValidator.validateName(value, 'Last Name');
            },
          ),
          
          // Real-time name validation indicator
          if (_lastNameController.text.isNotEmpty && _nameHasNumbers) ...[
            const SizedBox(height: 8),
            _buildNameValidationError('Last name cannot contain numbers'),
          ],
          
          const SizedBox(height: 20),
          
          // Email field
          CustomTextField(
            controller: _emailController,
            label: 'Email',
            hint: 'Enter your email',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_outlined,
            validator: (value) {
              return InputValidator.validateEmail(value);
            },
          ),
          
          const SizedBox(height: 20),
          
          // Address field
          CustomTextField(
            controller: _addressController,
            label: 'Address',
            hint: 'Enter your complete address',
            prefixIcon: Icons.home_outlined,
            validator: (value) {
              return InputValidator.validateAddress(value);
            },
          ),
          
          const SizedBox(height: 20),
          
          // Region dropdown
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedRegion,
              decoration: const InputDecoration(
                labelText: 'Region',
                prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.primaryRed),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: AppColors.primaryRed, width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              items: _regions.isEmpty 
                ? [DropdownMenuItem<String>(
                    value: null,
                    child: _isLoadingLocations 
                      ? const Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Loading regions...'),
                          ],
                        )
                      : const Text('No regions available'),
                  )]
                : _regions.map((Map<String, dynamic> region) {
                    return DropdownMenuItem<String>(
                      value: region['code'],
                      child: Text(region['name']),
                    );
                  }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedRegion = newValue;
                  _selectedProvince = null;
                  _selectedCity = null;
                  _selectedBarangay = null;
                  _provinces.clear();
                  _cities.clear();
                  _barangays.clear();
                });
                if (newValue != null) {
                  _loadProvinces(newValue);
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select your region';
                }
                return null;
              },
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Province or City (for NCR) dropdown
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedProvince,
              decoration: const InputDecoration(
                labelText: 'Province (or City for NCR)',
                prefixIcon: Icon(Icons.location_city_outlined, color: AppColors.primaryRed),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: AppColors.primaryRed, width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              items: _provinces.isEmpty 
                ? [DropdownMenuItem<String>(
                    value: null,
                    child: _isLoadingLocations 
                      ? const Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Loading provinces...'),
                          ],
                        )
                      : _selectedRegion == null 
                        ? const Text('Select a region first')
                        : const Text('Select a province first'),
                  )]
                : _provinces.map((Map<String, dynamic> province) {
                    return DropdownMenuItem<String>(
                      value: province['code'],
                      child: Text(province['name']),
                    );
                  }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedProvince = newValue;
                  _selectedCity = null;
                  _selectedBarangay = null;
                  _cities.clear();
                  _barangays.clear();
                });
                if (newValue != null) {
                  final isNCR = (_selectedRegion ?? '').toUpperCase().contains('NCR') || (_selectedRegion ?? '').toUpperCase().contains('NATIONAL CAPITAL REGION');
                  if (isNCR) {
                    // For NCR, the "province" dropdown actually contains city names
                    _selectedCity = newValue;
                    _loadBarangays(newValue);
                  } else {
                    _loadCities(newValue);
                  }
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select your province';
                }
                return null;
              },
            ),
          ),
          
          // City/Municipality dropdown (shown for non-NCR regions)
          if (!((_selectedRegion ?? '').toUpperCase().contains('NCR') || (_selectedRegion ?? '').toUpperCase().contains('NATIONAL CAPITAL REGION'))) ...[
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedCity,
                decoration: const InputDecoration(
                  labelText: 'City/Municipality',
                  prefixIcon: Icon(Icons.location_city, color: AppColors.primaryRed),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: AppColors.primaryRed, width: 2),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                items: _cities.isEmpty 
                  ? [DropdownMenuItem<String>(
                      value: null,
                      child: _isLoadingLocations 
                        ? const Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text('Loading cities...'),
                            ],
                          )
                        : const Text('Select a province first'),
                    )]
                  : _cities.map((Map<String, dynamic> city) {
                      return DropdownMenuItem<String>(
                        // Use city NAME as the value so barangay lookup can work by name
                        value: city['name'],
                        child: Text(city['name']),
                      );
                    }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCity = newValue;
                    _selectedBarangay = null;
                    _barangays.clear();
                  });
                  if (newValue != null) {
                    _loadBarangays(newValue);
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select your city/municipality';
                  }
                  return null;
                },
              ),
            ),
          ],

          const SizedBox(height: 20),
          
          // Barangay dropdown (full width)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedBarangay,
              decoration: const InputDecoration(
                labelText: 'Barangay',
                prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.primaryRed),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: AppColors.primaryRed, width: 2),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              items: _barangays.isEmpty 
                ? [DropdownMenuItem<String>(
                    value: null,
                    child: _isLoadingLocations 
                      ? const Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Loading barangays...'),
                          ],
                        )
                      : _selectedCity == null 
                        ? const Text('Select a city first')
                        : const Text('No barangays found'),
                  )]
                : _barangays.map((Map<String, dynamic> barangay) {
                    return DropdownMenuItem<String>(
                      value: barangay['code'],
                      child: Text(barangay['name']),
                    );
                  }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedBarangay = newValue;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select your barangay';
                }
                return null;
              },
            ),
          ),
          
          const SizedBox(height: 20),
          
          // ZIP Code field (full width)
          CustomTextField(
            controller: _zipCodeController,
            label: 'ZIP Code',
            hint: 'Enter ZIP code (4 digits)',
            keyboardType: TextInputType.number,
            prefixIcon: Icons.local_post_office_outlined,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter ZIP code';
              }
              if (!RegExp(r'^\d{4}$').hasMatch(value)) {
                return 'ZIP code must be 4 digits';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 30),
          
          // Security Section
          _buildSectionHeader('Security'),
          
          const SizedBox(height: 20),
          
          // Password field
          CustomTextField(
            controller: _passwordController,
            label: 'Password',
            hint: 'Enter your password',
            obscureText: _obscurePassword,
            prefixIcon: Icons.lock_outline,
            onChanged: (value) {
              _checkPasswordRequirements(value);
            },
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            validator: PasswordValidator.validate,
          ),
          
          // Real-time password validation indicators
          if (_passwordController.text.isNotEmpty) ...[
            const SizedBox(height: 12),
            PasswordStrengthIndicator(
              password: _passwordController.text,
              showIndicator: true,
            ),
          ],
          
          const SizedBox(height: 20),
          
          // Confirm Password field
          CustomTextField(
            controller: _confirmPasswordController,
            label: 'Confirm Password',
            hint: 'Confirm your password',
            obscureText: _obscureConfirmPassword,
            prefixIcon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey,
              ),
              onPressed: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          
          const SizedBox(height: 30),
          
          // Terms and Conditions
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  if (_acceptedTerms) {
                    // If already checked, uncheck it directly
                    setState(() {
                      _acceptedTerms = false;
                    });
                  } else {
                    // If not checked, show modal
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (context) => const TermsConditionsModal(),
                    );
                    
                    // Only check if user accepted the terms
                    if (result == true) {
                      setState(() {
                        _acceptedTerms = true;
                      });
                    }
                  }
                },
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _acceptedTerms ? AppColors.primaryRed : Colors.grey,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                    color: _acceptedTerms ? AppColors.primaryRed : Colors.transparent,
                  ),
                  child: _acceptedTerms
                    ? const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      )
                    : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    // Also show modal when text is clicked
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (context) => const TermsConditionsModal(),
                    );
                    
                    // Only check if user accepted the terms
                    if (result == true) {
                      setState(() {
                        _acceptedTerms = true;
                      });
                    }
                  },
                  child: Text(
                    'I agree to the Terms and Conditions',
                    style: TextStyle(
                      color: _acceptedTerms ? AppColors.primaryRed : Colors.grey,
                      fontSize: 14,
                      fontWeight: _acceptedTerms ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 30),
          
          // Sign up button
          CustomButton(
            text: 'Create Account',
            onPressed: (_isLoading || !_acceptedTerms) ? null : _signUp,
            isLoading: _isLoading,
            backgroundColor: _acceptedTerms ? AppColors.primaryRed : Colors.grey,
            textColor: Colors.white,
          ),
          
          // Terms acceptance message
          if (!_acceptedTerms) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.orange.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Please accept the Terms and Conditions to continue',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          
        ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryRed,
        ),
      ),
    );
  }

  Widget _buildPasswordValidation() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Password Requirements:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          _buildValidationItem(
            'At least 8 characters',
            _hasMinLength,
          ),
          _buildValidationItem(
            '1 special character (!@#\$%^&*)',
            _hasSpecialChar,
          ),
          _buildValidationItem(
            '1 uppercase letter (A-Z)',
            _hasUppercase,
          ),
        ],
      ),
    );
  }

  Widget _buildValidationItem(String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: isValid ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isValid ? Colors.green : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameValidationError(String message) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 16,
            color: Colors.red.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Already have an account? ',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 16,
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.of(context).pop();
          },
          child: const Text(
            'Sign In',
            style: TextStyle(
              color: AppColors.primaryRed,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}