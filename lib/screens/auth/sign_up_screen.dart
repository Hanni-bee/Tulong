import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../constants/app_colors.dart';
import '../../constants/unified_typography.dart';
import '../../constants/soft_ui_design.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/password_strength_indicator.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
// import removed
import '../../widgets/terms_conditions_modal.dart';
import '../../services/firebase_service.dart';
import '../../services/sqlite_service.dart';
import 'dart:io';
import '../../services/location_service.dart';
import '../../utils/input_validator.dart';
import '../../utils/responsive_spacing.dart';
import '../../services/emailjs_service.dart';
import '../../widgets/accessible_text.dart';
import 'dart:math';

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
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _verificationCodeController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _acceptedTerms = false;
  
  // Email verification states
  String? _generatedVerificationCode;
  bool _isVerificationCodeSent = false;
  bool _isEmailVerified = false;
  bool _isSendingCode = false;
  bool _isVerifyingCode = false;
  String? _verificationMessage;
  
  // Real-time validation states
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
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
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
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }
    
    // Check if email is verified
    if (!_isEmailVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please verify your email address first'),
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

      // Normalize phone for storage: 0 + 10 digits
      final phoneDigits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
      final normalizedPhone = phoneDigits.isEmpty ? null : ('0$phoneDigits');

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final firebaseService = FirebaseService();
      final isConnected = await _isConnected();

      // Get region name from code (for validation - codes contain digits)
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

      // ONLINE-FIRST APPROACH: Firebase is the main source
      if (isConnected) {
        try {
          print('🌐 Online mode detected - saving to Firebase Realtime Database FIRST...');
          print('   Region code: $_selectedRegion -> Region name: $regionName');
          
          // STEP 1: Save to Firebase Realtime Database FIRST (main source)
          final userCredential = await firebaseService.signUpWithEmail(
            email: email,
            password: pwd,
            firstName: first,
            lastName: last,
            phone: normalizedPhone,
            address: _addressController.text.trim(),
            region: regionName, // Use name for validation, not code
            province: provinceName, // Use name for validation, not code
            city: _selectedCity ?? '',
            barangay: _selectedBarangay ?? '',
          );

          if (userCredential?.user == null) {
            throw Exception('Firebase signup failed - user credential is null');
          }

          // Verify Firebase save was successful
          final userUid = userCredential!.user!.uid;
          final verifyRef = firebaseService.database.ref('users/$userUid');
          final verifySnapshot = await verifyRef.get();
          
          if (!verifySnapshot.exists) {
            throw Exception('Firebase Realtime Database save verification failed - data not found');
          }

          print('✅ CONFIRMED: User data saved to Firebase Realtime Database at users/$userUid');
          final savedData = verifySnapshot.value as Map<dynamic, dynamic>;
          print('   Email: ${savedData['Email']}');
          print('   Phone: ${savedData['Phone']}');
          print('   FirstName: ${savedData['FirstName']}');
          print('   LastName: ${savedData['LastName']}');

          // STEP 2: Save to SQLite as offline backup (should already be done by _saveUserToSQLite in signUpWithEmail)
          // Just verify SQLite has the data
          try {
            final sqliteService = SQLiteService();
            await sqliteService.database; // Initialize
            final existingUser = await sqliteService.getUserByEmail(email);
            if (existingUser == null) {
              print('📱 User not in SQLite yet, saving now as backup...');
              // Save to SQLite manually if not already saved - ALL FIELDS INCLUDED
              await sqliteService.insertUser({
                'firebase_uid': userUid,
                'email': email,
                'first_name': first,
                'last_name': last,
                'phone': normalizedPhone,
                'street': _addressController.text.trim(), // SQLite uses 'street' column
                'region': regionName,
                'province': provinceName,
                'city': _selectedCity ?? '',
                'barangay': _selectedBarangay ?? '',
                'password': firebaseService.hashPassword(pwd), // Hashed password
                'is_online': 1,
                'account_status': 'active',
                'created_at': DateTime.now().millisecondsSinceEpoch,
                'last_seen': DateTime.now().millisecondsSinceEpoch,
                'is_synced': 1, // Mark as synced since Firebase save succeeded
                'sync_timestamp': DateTime.now().millisecondsSinceEpoch,
                'is_google_auth': 0,
                'address_setup_completed': 0,
                'is_verified': 1, // Email verification completed
              });
              print('✅ User saved to SQLite as backup');
            } else {
              print('✅ User already exists in SQLite');
            }
          } catch (sqliteError) {
            print('⚠️ SQLite backup save error (non-critical): $sqliteError');
            // Continue anyway since Firebase save succeeded
          }

          // STEP 3: Set authenticated and navigate
          if (!mounted) return;
          
          // Small delay to ensure Firebase data is fully saved
          await Future.delayed(const Duration(milliseconds: 500));
          
          await authProvider.setAuthenticated(
            email: email,
            name: '$first $last',
          );
          
          // Ensure user model is loaded before navigating
          await authProvider.loadUserModel();
          
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed('/');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Account created successfully! Saved to Firebase.'),
                  ),
                ],
              ),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 4),
            ),
          );
          return; // Success - exit early
          
        } catch (firebaseError) {
          print('❌ Firebase signup failed: $firebaseError');
          print('❌ Error details: ${firebaseError.toString()}');
          
          // If online but Firebase fails, show error - don't fall back to SQLite-only
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Failed to create account: ${firebaseError.toString()}'),
                    ),
                  ],
                ),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          return; // Don't proceed with SQLite-only signup
        }
      } else {
        // OFFLINE MODE: Only allow SQLite signup if truly offline
        print('📴 Offline mode detected - saving to SQLite only');
        
        await authProvider.signupOffline(
          email: email,
          password: pwd,
          firstName: first,
          lastName: last,
          phone: normalizedPhone,
          address: _addressController.text.trim(),
          region: regionName,
          province: provinceName,
          city: _selectedCity ?? '',
          barangay: _selectedBarangay ?? '',
        );

        if (!mounted) return;
        await authProvider.setAuthenticated(
          email: email,
          name: '$first $last',
        );
        
        Navigator.of(context).pushReplacementNamed('/');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Account created offline. Will sync to Firebase when online.'),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
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

  // Simple connectivity check
  Future<bool> _isConnected() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // Generate 6-digit verification code
  String _generateVerificationCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // Send verification code via EmailJS
  Future<void> _sendVerificationCode() async {
    final email = _emailController.text.trim();
    
    // Validate email first
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isSendingCode = true;
      _verificationMessage = null;
    });

    try {
      // Generate 6-digit code
      _generatedVerificationCode = _generateVerificationCode();
      
      // Send via EmailJS
      final emailJSService = EmailJSService();
      final success = await emailJSService.sendVerificationCode(
        email: email,
        passcode: _generatedVerificationCode!,
      );

      if (success) {
        setState(() {
          _isVerificationCodeSent = true;
          _isEmailVerified = false;
          _verificationMessage = 'Check your email for the verification code.';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification code sent! Check your email.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        setState(() {
          _verificationMessage = 'Failed to send verification code. Please try again.';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send verification code. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _verificationMessage = 'Error sending verification code: ${e.toString()}';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        _isSendingCode = false;
      });
    }
  }

  // Verify the entered code
  Future<void> _verifyCode() async {
    final enteredCode = _verificationCodeController.text.trim();
    
    if (enteredCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the verification code'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isVerifyingCode = true;
      _verificationMessage = null;
    });

    // Simulate a small delay for better UX
    await Future.delayed(const Duration(milliseconds: 500));

    if (enteredCode == _generatedVerificationCode) {
      setState(() {
        _isEmailVerified = true;
        _verificationMessage = 'Verification successful.';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Verification successful.'),
            ],
          ),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      setState(() {
        _isEmailVerified = false;
        _verificationMessage = 'Wrong code, please try again.';
        _verificationCodeController.clear();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Wrong code, please try again.'),
            ],
          ),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 2),
        ),
      );
    }

    setState(() {
      _isVerifyingCode = false;
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Removed background overlay to avoid hazy/blurred appearance on sign-up
          
          Column(
            children: [
              AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.primaryRed),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).pop();
                  },
                ),
                title: AccessibleHeading(
                  'Create Account',
                  level: HeadingLevel.h2,
                  color: AppColors.primary,
                  backgroundColor: AppColors.backgroundLight,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
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
        // T.U.L.O.N.G logo with red accent
        Container(
          width: 80,
          height: 80,
          decoration: SoftUIDesign.cardDecoration(
            backgroundColor: AppColors.white,
            borderRadius: 20,
            elevation: 6.0,
            borderColor: AppColors.primaryRed.withOpacity(0.2),
            showBorder: true,
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
        
        Text(
          'T.U.L.O.N.G',
          style: UnifiedTypography.displayLarge.copyWith(
            color: AppColors.primary,
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
        
        Text(
          'Join the Disaster-Ready Community',
          style: UnifiedTypography.bodyLarge.copyWith(
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
      decoration: SoftUIDesign.cardDecoration(
        backgroundColor: Colors.white,
        borderRadius: SoftUIDesign.cardBorderRadius,
        elevation: 4.0,
        borderColor: AppColors.lightGray.withOpacity(0.3),
        showBorder: true,
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
            onChanged: (value) {
              // Reset verification state when email changes
              if (value != _emailController.text.trim()) {
                setState(() {
                  _isVerificationCodeSent = false;
                  _isEmailVerified = false;
                  _generatedVerificationCode = null;
                  _verificationCodeController.clear();
                  _verificationMessage = null;
                });
              }
            },
          ),
          
          // Send Verification Code button
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSendingCode ? null : _sendVerificationCode,
              icon: _isSendingCode
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
              label: Text(
                _isSendingCode ? 'Sending...' : 'Send Verification Code',
                style: UnifiedTypography.titleMedium,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          
          // Verification message
          if (_verificationMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isEmailVerified 
                    ? Colors.green.shade50 
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isEmailVerified 
                      ? Colors.green.shade200 
                      : Colors.blue.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isEmailVerified ? Icons.check_circle : Icons.info_outline,
                    color: _isEmailVerified 
                        ? Colors.green.shade700 
                        : Colors.blue.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _verificationMessage!,
                      style: TextStyle(
                        color: _isEmailVerified 
                            ? Colors.green.shade700 
                            : Colors.blue.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Verification Code Input (only show after code is sent)
          if (_isVerificationCodeSent && !_isEmailVerified) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _verificationCodeController,
                    label: 'Verification Code',
                    hint: 'Enter 6-digit code',
                    keyboardType: TextInputType.number,
                    prefixIcon: Icons.verified_user_outlined,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 100,
                  child: ElevatedButton(
                    onPressed: _isVerifyingCode ? null : _verifyCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isVerifyingCode
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Verify'),
                  ),
                ),
              ],
            ),
          ],
          
          // Email verified indicator
          if (_isEmailVerified) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Text(
                    '✅ Email verified successfully',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 20),
          
          // Phone Number field (+63 prefix, 10 digits only, starts with 9)
          CustomTextField(
            controller: _phoneController,
            label: 'Phone Number',
            hint: '9123456789',
            keyboardType: TextInputType.number,
            prefixIcon: Icons.phone_outlined,
            prefixText: '+63 ',
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            validator: (value) => InputValidator.validatePhilippinePhoneNumber(value),
            autovalidateMode: AutovalidateMode.onUserInteraction,
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
            decoration: SoftUIDesign.cardDecoration(
              backgroundColor: Colors.white,
              borderRadius: SoftUIDesign.cardBorderRadius,
              elevation: 2.0,
              borderColor: AppColors.lightGray.withOpacity(0.3),
              showBorder: true,
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
                labelStyle: TextStyle(
                  color: AppColors.primary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
                hintStyle: TextStyle(
                  color: AppColors.mediumGray,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
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
            decoration: SoftUIDesign.cardDecoration(
              backgroundColor: Colors.white,
              borderRadius: SoftUIDesign.cardBorderRadius,
              elevation: 2.0,
              borderColor: AppColors.lightGray.withOpacity(0.3),
              showBorder: true,
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
                labelStyle: TextStyle(
                  color: AppColors.primary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
                hintStyle: TextStyle(
                  color: AppColors.mediumGray,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
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
                    // For NCR, the "province" dropdown contains districts (like "NATIONAL CAPITAL REGION - FIRST DISTRICT")
                    // We need to load cities for that district so the City/Municipality dropdown can show the cities
                    _selectedProvince = newValue; // Keep track of the selected district
                    _loadCities(newValue); // Load cities for the selected district
                    // Don't set _selectedCity here - let the user select from City/Municipality dropdown
                    // Don't load barangays yet - wait for city selection
                  } else {
                    // For non-NCR regions, load cities normally
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
          
          // City/Municipality dropdown (always visible)
          const SizedBox(height: 20),
          Container(
            decoration: SoftUIDesign.cardDecoration(
              backgroundColor: AppColors.white,
              borderRadius: SoftUIDesign.cardBorderRadius,
              elevation: 2.0,
              borderColor: AppColors.lightGray.withOpacity(0.3),
              showBorder: true,
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
                labelStyle: TextStyle(
                  color: AppColors.primary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
                hintStyle: TextStyle(
                  color: AppColors.mediumGray,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
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
                      : _selectedRegion == null
                        ? const Text('Select a region first')
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

          const SizedBox(height: 20),
          
          // Barangay dropdown (full width)
          Container(
            decoration: SoftUIDesign.cardDecoration(
              backgroundColor: Colors.white,
              borderRadius: SoftUIDesign.cardBorderRadius,
              elevation: 2.0,
              borderColor: AppColors.lightGray.withOpacity(0.3),
              showBorder: true,
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
                labelStyle: TextStyle(
                  color: AppColors.primary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
                hintStyle: TextStyle(
                  color: AppColors.mediumGray,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
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
          
          // Zip code removed
          
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
              // Password validation handled by form validator
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
            onPressed: (_isLoading || !_acceptedTerms || !_isEmailVerified) ? null : _signUp,
            isLoading: _isLoading,
            backgroundColor: (_acceptedTerms && _isEmailVerified) ? AppColors.primaryRed : Colors.grey,
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
          
          // Email verification requirement message
          if (!_isEmailVerified) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.email_outlined,
                  size: 16,
                  color: Colors.orange.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Please verify your email address to continue',
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
        style: UnifiedTypography.headlineSmall.copyWith(
          color: AppColors.primaryRed,
        ),
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
              style: UnifiedTypography.errorText.copyWith(
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
        Text(
          'Already have an account? ',
          style: UnifiedTypography.bodyLarge.copyWith(
            color: Colors.grey,
          ),
        ),
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).pop();
          },
          child: Text(
            'Sign In',
            style: UnifiedTypography.bodyLarge.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}