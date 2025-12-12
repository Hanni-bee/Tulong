import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/unified_typography.dart';
import '../../providers/auth_provider.dart';
import '../../services/unified_data_service.dart';
import '../../services/location_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../utils/input_validator.dart';

class AddressSetupScreen extends StatefulWidget {
  const AddressSetupScreen({super.key});

  @override
  State<AddressSetupScreen> createState() => _AddressSetupScreenState();
}

class _AddressSetupScreenState extends State<AddressSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  bool _isLoading = false;
  
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
    _loadUserData();
  }

  void _loadUserData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUserModel;
    
    if (user != null) {
      // Pre-fill with existing data if available
      if (user.street.isNotEmpty) _addressController.text = user.street;
      if (user.phone != null && user.phone!.startsWith('0') && user.phone!.length == 11) {
        _phoneController.text = user.phone!.substring(1);
      }
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _phoneController.dispose();
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

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate required fields
    if (_selectedRegion == null || _selectedProvince == null || 
        _selectedCity == null || _selectedBarangay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select all location fields'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final unifiedDataService = UnifiedDataService();
      
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
      
      // For Google users, we need to create/update their profile in SQLite first
      final userEmail = authProvider.userEmail;
      if (userEmail == null) {
        throw Exception('User email not found');
      }
      
      // Check if user exists in SQLite, if not create them
      var sqliteUser = await unifiedDataService.getUserByEmail(userEmail);
      if (sqliteUser == null) {
        // Create user in SQLite for Google auth users
        final userModel = authProvider.currentUserModel!;
        final digits = _phoneController.text.replaceAll(RegExp(r'\\D'), '');
        final storedPhone = digits.isEmpty ? null : ('0$digits');
        sqliteUser = await unifiedDataService.createUser(
          email: userEmail,
          password: '', // Google users don't have password initially
          firstName: userModel.name.split(' ').first,
          lastName: userModel.name.split(' ').skip(1).join(' '),
          phone: storedPhone,
          street: _addressController.text.trim(),
          region: regionName,
          province: provinceName,
          city: cityName,
          barangay: barangayName,
          isGoogleAuth: true,
        );
      } else {
        // Update existing user profile
        final digits = _phoneController.text.replaceAll(RegExp(r'\\D'), '');
        final storedPhone = digits.isEmpty ? null : ('0$digits');
        await unifiedDataService.updateUserProfileWithMap(userEmail, {
          'street': _addressController.text.trim(),
          'region': regionName,
          'province': provinceName,
          'city': cityName,
          'barangay': barangayName,
          'phone': storedPhone,
        });
      }
      
      // Mark address setup as completed
      await unifiedDataService.markAddressSetupCompleted(userEmail);
      
      // Reload user model to ensure all saved data is loaded
      await authProvider.loadUserModel();
      
      // Update local user model with latest data
      if (authProvider.currentUserModel != null) {
        final updatedUser = authProvider.currentUserModel!.copyWith(
          street: _addressController.text.trim(),
          barangay: barangayName,
          city: cityName,
          province: provinceName,
          phone: (() { final d = _phoneController.text.replaceAll(RegExp(r'\\D'), ''); return d.isEmpty ? null : ('0$d'); })(),
          addressSetupCompleted: true,
        );
        authProvider.updateUser(updatedUser);
      }

      HapticFeedback.mediumImpact();
      
      // Navigate to main app
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/main',
          (route) => false,
        );
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving address: $e'),
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
          style: UnifiedTypography.titleMedium,
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
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Complete Your Profile',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
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
                          color: AppColors.primaryRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: AppColors.primaryRed,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child:                         Text(
                          'We need your address for emergency response and location-based features.',
                          style: UnifiedTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),

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

                // Phone number (+63 prefix, 10 digits only) - styled like street address
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '9123456789',
                    prefixText: '+63 ',
                    prefixIcon: Icon(Icons.phone_outlined, color: AppColors.primaryRed),
                    labelStyle: TextStyle(
                      color: AppColors.primaryRed,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: AppColors.primaryRed, width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: AppColors.primaryRed, width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: AppColors.primaryRed, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: AppColors.error, width: 1.5),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: AppColors.error, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  validator: (value) => InputValidator.validatePhilippinePhoneNumber(value),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),

                const SizedBox(height: 24),

                // Privacy note
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.online.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.online.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.security,
                        color: AppColors.online,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your address is securely stored and only used for emergency response.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.online,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Save button
                CustomButton(
                  text: _isLoading ? 'Saving...' : 'Save & Continue',
                  onPressed: _isLoading ? null : _saveAddress,
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
