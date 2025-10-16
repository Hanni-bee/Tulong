import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_typography.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/location_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class AddressSetupScreen extends StatefulWidget {
  const AddressSetupScreen({super.key});

  @override
  State<AddressSetupScreen> createState() => _AddressSetupScreenState();
}

class _AddressSetupScreenState extends State<AddressSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _zipCodeController = TextEditingController();
  
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
      if (user.zipCode.isNotEmpty) _zipCodeController.text = user.zipCode;
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _zipCodeController.dispose();
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

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final firebaseService = FirebaseService();
      
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
      
      final updatedUser = authProvider.currentUserModel!.copyWith(
        street: _addressController.text.trim(),
        barangay: barangayName,
        city: cityName,
        province: provinceName,
        zipCode: _zipCodeController.text.trim(),
        addressSetupCompleted: true,
      );

      await firebaseService.updateUserModelProfile(updatedUser);
      authProvider.updateUser(updatedUser);

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
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
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
            value: value,
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
                        child: Text(
                          'We need your address for emergency response and location-based features.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.4,
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

                // ZIP Code
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ZIP Code',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                      child: TextFormField(
                        controller: _zipCodeController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        decoration: InputDecoration(
                          hintText: 'Enter ZIP code',
                          hintStyle: TextStyle(
                            color: AppColors.textSecondary.withOpacity(0.6),
                          ),
                          prefixIcon: const Icon(Icons.pin_drop, color: AppColors.primaryRed),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your ZIP code';
                          }
                          if (value.length < 4) {
                            return 'ZIP code must be 4 digits';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
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
