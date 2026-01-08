import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/bluetooth_service.dart';
import '../constants/app_colors.dart';
import '../constants/unified_typography.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/location_service.dart';
import '../services/unified_data_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/enhanced_micro_interactions.dart' as micro;

class UpdateProfileScreen extends StatefulWidget {
  const UpdateProfileScreen({super.key});

  @override
  State<UpdateProfileScreen> createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _addressController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLoadingUserData = true;
  
  // Location data
  String? _selectedRegion;
  String? _selectedProvince;
  String? _selectedCity;
  String? _selectedBarangay;
  
  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _barangays = [];

  @override
  void initState() {
    super.initState();
    _loadRegions();
    _loadUserData();
  }

  void _loadUserData() async {
    setState(() => _isLoadingUserData = true);
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Force refresh user data from SQLite to ensure we have the latest data
      await authProvider.loadSession();
      final user = authProvider.currentUserModel;
      
      if (user != null) {
        print('✅ Loading user data for Update Profile:');
        print('  - Name: ${user.name}');
        print('  - Username: ${user.username}');
        print('  - Street: ${user.street}');
        print('  - City: ${user.city}');
        print('  - Province: ${user.province}');
        print('  - Barangay: ${user.barangay}');
        
        // Pre-fill full name (concatenated, read-only)
        _fullNameController.text = user.name.isNotEmpty ? user.name : '';
        
        // Pre-fill username (read-only)
        _usernameController.text = user.username.isNotEmpty ? user.username : '';
        
        // Pre-fill address info - ALWAYS set the text, even if empty
        _addressController.text = user.street.isNotEmpty ? user.street : '';
        
        print('✅ Controllers set:');
        print('  - Full Name Controller: "${_fullNameController.text}"');
        print('  - Username Controller: "${_usernameController.text}"');
        print('  - Address Controller: "${_addressController.text}"');
      
      // Load and pre-select location data
      await _loadAndPreSelectLocation(user);
      } else {
        print('❌ No user data found in SQLite');
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
    }
    
    setState(() => _isLoadingUserData = false);
  }

  Future<void> _loadAndPreSelectLocation(UserModel user) async {
    try {
      print('🌍 Loading and pre-selecting location data...');
      
      // Wait for regions to load first
      while (_regions.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      print('✅ Regions loaded: ${_regions.length}');
      
      // Pre-select Region based on province
      if (user.province.isNotEmpty) {
        print('🔍 Looking for region for province: ${user.province}');
        await _findAndSelectRegion(user.province);
      }
      
      // Pre-select Province
      if (user.province.isNotEmpty && _selectedRegion != null) {
        print('🔍 Looking for province: ${user.province}');
        // Wait for provinces to load
        while (_provinces.isEmpty) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        
        // Find province in the list
        final province = _provinces.firstWhere(
          (p) => p['province_name'] == user.province || p['name'] == user.province,
          orElse: () => {},
        );
        
        if (province.isNotEmpty) {
          setState(() => _selectedProvince = province['province_code'] ?? province['code']);
          print('✅ Province selected: ${province['province_name'] ?? province['name']}');
          await _loadCities(province['province_code'] ?? province['code']);
        }
      }
      
      // Pre-select City
      if (user.city.isNotEmpty && _selectedProvince != null) {
        print('🔍 Looking for city: ${user.city}');
        // Wait for cities to load
        while (_cities.isEmpty) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        
        final city = _cities.firstWhere(
          (c) => c['city_name'] == user.city || c['name'] == user.city,
          orElse: () => {},
        );
        
        if (city.isNotEmpty) {
          setState(() => _selectedCity = city['city_code'] ?? city['code']);
          print('✅ City selected: ${city['city_name'] ?? city['name']}');
          await _loadBarangays(city['city_code'] ?? city['code']);
        }
      }
      
      // Pre-select Barangay
      if (user.barangay.isNotEmpty && _selectedCity != null) {
        print('🔍 Looking for barangay: ${user.barangay}');
        // Wait for barangays to load
        while (_barangays.isEmpty) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
        
        final barangay = _barangays.firstWhere(
          (b) => b['brgy_name'] == user.barangay || b['name'] == user.barangay,
          orElse: () => {},
        );
        
        if (barangay.isNotEmpty) {
          setState(() => _selectedBarangay = barangay['brgy_code'] ?? barangay['code']);
          print('✅ Barangay selected: ${barangay['brgy_name'] ?? barangay['name']}');
        }
      }
      
      print('✅ Location pre-selection completed');
    } catch (e) {
      print('❌ Error in location pre-selection: $e');
    }
  }

  Future<void> _findAndSelectRegion(String provinceName) async {
    try {
      // Load the JSON to find which region this province belongs to
      final String jsonString = await rootBundle.loadString(
        'assets/philippine_provinces_cities_municipalities_and_barangays_2019v2.json',
      );
      final Map<String, dynamic> data = jsonDecode(jsonString);
      
      // Search through all regions to find the province
      for (final regionEntry in data.entries) {
        final regionCode = regionEntry.key;
        final regionValue = regionEntry.value;
        
        if (regionValue is Map<String, dynamic> && regionValue.containsKey('province_list')) {
          final provinceList = regionValue['province_list'] as Map<String, dynamic>;
          
          if (provinceList.containsKey(provinceName)) {
            setState(() => _selectedRegion = regionCode);
            await _loadProvinces(regionCode);
            return;
          }
        }
      }
    } catch (e) {
      print('❌ Error finding region: $e');
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadRegions() async {
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
  }

  Future<void> _loadProvinces(String regionCode) async {
    try {
      _provinces = await LocationService.getProvinces(regionCode);
      if (_provinces.isEmpty) {
        _provinces = LocationService.getFallbackProvinces(regionCode);
      }
    } catch (e) {
      _provinces = LocationService.getFallbackProvinces(regionCode);
    }
  }

  Future<void> _loadCities(String provinceCode) async {
    try {
      _cities = await LocationService.getCities(provinceCode);
    } catch (e) {
      _cities = LocationService.getFallbackCities(provinceCode);
    }
  }

  Future<void> _loadBarangays(String cityCode) async {
    try {
      _barangays = await LocationService.getBarangays(cityCode);
      if (_barangays.isEmpty) {
        _barangays = LocationService.getFallbackBarangays(cityCode);
      }
    } catch (e) {
      _barangays = LocationService.getFallbackBarangays(cityCode);
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Find selected names from codes
      final regionName = _regions.firstWhere(
        (r) => r['region_code'] == _selectedRegion,
        orElse: () => {'region_name': _selectedRegion ?? ''},
      )['region_name'] ?? _selectedRegion ?? '';
      
      final provinceName = _provinces.firstWhere(
        (p) => p['province_code'] == _selectedProvince,
        orElse: () => {'province_name': _selectedProvince ?? ''},
      )['province_name'] ?? _selectedProvince ?? '';
      
      final cityName = _cities.firstWhere(
        (c) => c['city_code'] == _selectedCity,
        orElse: () => {'city_name': _selectedCity ?? ''},
      )['city_name'] ?? _selectedCity ?? '';
      
      final barangayName = _barangays.firstWhere(
        (b) => b['brgy_code'] == _selectedBarangay,
        orElse: () => {'brgy_name': _selectedBarangay ?? ''},
      )['brgy_name'] ?? _selectedBarangay ?? '';
      
      // Use unified data service for profile update
      // Note: Name and username are read-only, so we only update address fields
      final unifiedDataService = UnifiedDataService();
      await unifiedDataService.updateUserProfileWithMap(
        authProvider.userUsername!,
        {
          'street': _addressController.text.trim(),
          'region': regionName,
          'province': provinceName,
          'city': cityName,
          'barangay': barangayName,
        },
      );
      
      // Reload user model to ensure all saved data is loaded from database
      await authProvider.loadUserModel();
      
      // Update local user model with latest data (keep existing name and username)
      if (authProvider.currentUserModel != null) {
        final updatedUser = authProvider.currentUserModel!.copyWith(
          street: _addressController.text.trim(),
          barangay: barangayName,
          city: cityName,
          province: provinceName,
        );
        authProvider.updateUser(updatedUser);

        // Push profile header to Node A via Bluetooth (if connected)
        final bt = BluetoothService();
        if (bt.isConnected) {
          final fullName = updatedUser.name;
          final addressString = '${_addressController.text.trim()}, $cityName';
          unawaited(bt.sendProfileHeader(fullName: fullName, address: addressString));
        }
      }

      HapticFeedback.mediumImpact();
      
      if (mounted) {
        // Show success animation before navigating back
        _showSuccessAnimation(context);
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessAnimation(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success checkmark
            micro.SuccessAnimation(
              size: 100,
              color: AppColors.success,
              onComplete: () {
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (context.mounted) {
                    Navigator.of(context).pop(); // Close animation
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile updated successfully!'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                    Navigator.of(context).pop(); // Close profile screen
                  }
                });
              },
            ),
            const SizedBox(height: 24),
            // Success message
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Text(
                'Profile Updated!',
                style: UnifiedTypography.titleMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationDropdown({
    required String label,
    required String? value,
    required List<Map<String, dynamic>> items,
    required String valueKey,
    required String displayKey,
    required Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: UnifiedTypography.labelLarge.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.9),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            initialValue: value,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              errorStyle: const TextStyle(fontSize: 12),
            ),
            hint: Text(
              'Select $label',
              style: TextStyle(
                color: AppColors.textSecondary.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
            isExpanded: true,
            items: items.map((item) {
              return DropdownMenuItem<String>(
                value: item[valueKey].toString(),
                child: Text(
                  item[displayKey].toString(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
            validator: validator,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingUserData) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Update Profile',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Update Profile',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.9),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'Update your personal information and address details.',
                          style: UnifiedTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),

                // Personal Information Section
                Text(
                  'Personal Information',
                  style: UnifiedTypography.titleLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                // Full Name (read-only, concatenated)
                CustomTextField(
                  controller: _fullNameController,
                  label: 'Full Name',
                  hint: 'Your full name',
                  prefixIcon: Icons.person_outline,
                  enabled: false, // Disabled for editing
                  validator: (value) {
                    // No validation needed since it's read-only
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Username (read-only)
                CustomTextField(
                  controller: _usernameController,
                  label: 'Username',
                  hint: 'Your username',
                  prefixIcon: Icons.alternate_email,
                  enabled: false, // Disabled for editing
                  validator: (value) {
                    // No validation needed since it's read-only
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // Address Information Section
                Text(
                  'Address Information',
                  style: UnifiedTypography.titleLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                // Region
                _buildLocationDropdown(
                  label: 'Region',
                  value: _selectedRegion,
                  items: _regions,
                  valueKey: 'region_code',
                  displayKey: 'region_name',
                  onChanged: (value) {
                    setState(() {
                      _selectedRegion = value;
                      _selectedProvince = null;
                      _selectedCity = null;
                      _selectedBarangay = null;
                      _provinces = [];
                      _cities = [];
                      _barangays = [];
                    });
                    if (value != null) {
                      _loadProvinces(value);
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select your region';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Province
                _buildLocationDropdown(
                  label: 'Province',
                  value: _selectedProvince,
                  items: _provinces,
                  valueKey: 'province_code',
                  displayKey: 'province_name',
                  onChanged: (value) {
                    setState(() {
                      _selectedProvince = value;
                      _selectedCity = null;
                      _selectedBarangay = null;
                      _cities = [];
                      _barangays = [];
                    });
                    if (value != null) {
                      _loadCities(value);
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select your province';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // City/Municipality
                _buildLocationDropdown(
                  label: 'City/Municipality',
                  value: _selectedCity,
                  items: _cities,
                  valueKey: 'city_code',
                  displayKey: 'city_name',
                  onChanged: (value) {
                    setState(() {
                      _selectedCity = value;
                      _selectedBarangay = null;
                      _barangays = [];
                    });
                    if (value != null) {
                      _loadBarangays(value);
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select your city/municipality';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Barangay
                _buildLocationDropdown(
                  label: 'Barangay',
                  value: _selectedBarangay,
                  items: _barangays,
                  valueKey: 'brgy_code',
                  displayKey: 'brgy_name',
                  onChanged: (value) {
                    setState(() {
                      _selectedBarangay = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select your barangay';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Street Address
                CustomTextField(
                  controller: _addressController,
                  label: 'Street Address',
                  hint: 'House #, Street, Subdivision',
                  prefixIcon: Icons.home,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your street address';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Zip code removed

                const SizedBox(height: 32),

                // Update button
                CustomButton(
                  text: _isLoading ? 'Updating...' : 'Update Profile',
                  onPressed: _isLoading ? null : _updateProfile,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

