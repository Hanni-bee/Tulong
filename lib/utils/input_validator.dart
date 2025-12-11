
class InputValidator {
  static const int _minPasswordLength = 8;
  static const int _maxPasswordLength = 128;
  static const int _maxNameLength = 50;
  static const int _maxEmailLength = 254;
  static const int _maxAddressLength = 200;

  // Philippine phone number validation for UI with fixed +63 prefix
  // Expects only the 10-digit part entered by user (no +63 in value)
  static String? validatePhilippinePhoneNumber(String? tenDigitNumber) {
    if (tenDigitNumber == null || tenDigitNumber.isEmpty) {
      return 'Phone number is required';
    }

    final digits = tenDigitNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) {
      return 'Please enter exactly 10 digits after +63';
    }
    if (!RegExp(r'^\d{10}$').hasMatch(digits)) {
      return 'Please enter only digits for the phone number';
    }
    if (!digits.startsWith('9')) {
      return 'Please enter a valid phone number starting with 9.';
    }
    return null;
  }

  // Username validation - 6+ characters, letters and numbers only
  static String? validateUsername(String? username) {
    if (username == null || username.isEmpty) {
      return 'Username is required';
    }

    if (username.length < 6) {
      return 'Username must be at least 6 characters';
    }

    if (username.length > 30) {
      return 'Username is too long (max 30 characters)';
    }

    // Only letters and numbers allowed
    final usernameRegex = RegExp(r'^[a-zA-Z0-9]+$');

    if (!usernameRegex.hasMatch(username)) {
      return 'Username can only contain letters and numbers (no special characters)';
    }

    return null;
  }

  // Legacy email validation - deprecated
  @Deprecated('Use validateUsername instead')
  static String? validateEmail(String? email) {
    return validateUsername(email);
  }

  // Password validation with strength requirements
  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }

    if (password.length < _minPasswordLength) {
      return 'Password must be at least $_minPasswordLength characters long';
    }

    if (password.length > _maxPasswordLength) {
      return 'Password is too long';
    }

    // Check for at least one uppercase letter
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }

    // Check for at least one lowercase letter
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }

    // Check for at least one number
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }

    // Check for at least one special character
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least one special character';
    }

    return null;
  }

  // Confirm password validation
  static String? validateConfirmPassword(String? password, String? confirmPassword) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return 'Please confirm your password';
    }

    if (password != confirmPassword) {
      return 'Passwords do not match';
    }

    return null;
  }

  // Name validation (First Name, Last Name) - TEXT ONLY, NO NUMBERS, NO EMOJIS
  static String? validateName(String? name, String fieldName) {
    if (name == null || name.isEmpty) {
      return '$fieldName is required';
    }

    if (name.length > _maxNameLength) {
      return '$fieldName is too long';
    }

    // Check for emojis and special Unicode characters
    final emojiRegex = RegExp(r'[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]', unicode: true);
    if (emojiRegex.hasMatch(name)) {
      return '$fieldName cannot contain emojis or special characters';
    }

    // Check for numbers
    if (name.contains(RegExp(r'[0-9]'))) {
      return '$fieldName cannot contain numbers';
    }

    // Only allow letters, spaces, hyphens, and apostrophes
    final nameRegex = RegExp(r"^[a-zA-Z\s\-']+$");
    if (!nameRegex.hasMatch(name)) {
      return '$fieldName can only contain letters, spaces, hyphens, and apostrophes';
    }

    return null;
  }

  // Address validation - NUMBERS ALLOWED, NO EMOJIS
  static String? validateAddress(String? address) {
    if (address == null || address.isEmpty) {
      return 'Address is required';
    }

    if (address.length > _maxAddressLength) {
      return 'Address is too long';
    }

    // Check for emojis and special Unicode characters
    final emojiRegex = RegExp(r'[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]', unicode: true);
    if (emojiRegex.hasMatch(address)) {
      return 'Address cannot contain emojis or special characters';
    }

    // Basic sanitization - remove potentially dangerous characters
    final sanitized = address.replaceAll('<', '').replaceAll('>', '').replaceAll('"', '').replaceAll('&', '').replaceAll('\'', '');
    if (sanitized.length < 10) {
      return 'Please provide a complete address';
    }

    return null;
  }

  // Location validation (Region, City, Barangay) - ALLOWS ROMAN NUMERALS
  static String? validateLocation(String? location, String fieldName) {
    if (location == null || location.isEmpty) {
      return '$fieldName is required';
    }

    // Trim whitespace first
    final trimmedLocation = location.trim();
    if (trimmedLocation.isEmpty) {
      return '$fieldName is required';
    }

    if (trimmedLocation.length > _maxNameLength) {
      return '$fieldName is too long';
    }

    // Check for emojis and special Unicode characters
    final emojiRegex = RegExp(r'[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]', unicode: true);
    if (emojiRegex.hasMatch(trimmedLocation)) {
      return '$fieldName cannot contain emojis or special characters';
    }

    // Check for Arabic digits (0-9) only - ALLOW ROMAN NUMERALS (I, V, X, L, C, D, M)
    // Roman numerals are letters, not digits, so they should pass
    // Only reject if actual Arabic digits (0-9) are present
    if (trimmedLocation.contains(RegExp(r'[0-9]'))) {
      return '$fieldName cannot contain Arabic digits (0-9). Roman numerals (I, II, III, IV, V, VI, VII, VIII, IX, X, XI, XII, XIII) are allowed.';
    }

    // Allow letters (including Roman numerals I, V, X, L, C, D, M), spaces, hyphens, and common location characters
    // Examples that should pass: "REGION IV-B", "REGION XII", "REGION IV-A", "NCR"
    // The hyphen (-) is explicitly allowed in the regex
    final locationRegex = RegExp(r"^[a-zA-Z\s\-'.,()]+$");
    if (!locationRegex.hasMatch(trimmedLocation)) {
      return '$fieldName can only contain letters (including Roman numerals), spaces, hyphens, apostrophes, periods, commas, and parentheses';
    }

    return null;
  }

  // Zip code validation removed

  // Message validation
  static String? validateMessage(String? message, {int maxLength = 1000}) {
    if (message == null || message.isEmpty) {
      return 'Message cannot be empty';
    }

    if (message.length > maxLength) {
      return 'Message is too long (max $maxLength characters)';
    }

    // Basic XSS prevention - remove script tags
    final sanitized = message.replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false), '');
    if (sanitized.length < message.length * 0.8) {
      return 'Message contains invalid content';
    }

    return null;
  }

  // Phone number validation (optional)
  static String? validatePhoneNumber(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      return null; // Phone number is optional
    }

    // Philippine phone number format
    final phoneRegex = RegExp(r'^(\+63|0)[0-9]{10}$');
    if (!phoneRegex.hasMatch(phoneNumber)) {
      return 'Please enter a valid Philippine phone number';
    }

    return null;
  }

  // Emergency priority validation
  static String? validatePriority(String? priority) {
    if (priority == null || priority.isEmpty) {
      return 'Priority is required';
    }

    final validPriorities = ['low', 'medium', 'high', 'critical'];
    if (!validPriorities.contains(priority.toLowerCase())) {
      return 'Priority must be: low, medium, high, or critical';
    }

    return null;
  }

  // Emergency type validation
  static String? validateEmergencyType(String? type) {
    if (type == null || type.isEmpty) {
      return 'Emergency type is required';
    }

    final validTypes = ['medical', 'fire', 'flood', 'earthquake', 'typhoon', 'accident', 'security', 'other'];
    if (!validTypes.contains(type.toLowerCase())) {
      return 'Please select a valid emergency type';
    }

    return null;
  }

  // Sanitize text input (remove potentially dangerous characters)
  static String sanitizeText(String input) {
    return input
        .replaceAll('<', '').replaceAll('>', '').replaceAll('"', '').replaceAll('&', '').replaceAll('\'', '') // Remove HTML/script characters
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }

  // Validate and sanitize all user input data
  static Map<String, String?> validateUserInput({
    required String username,
    required String password,
    required String confirmPassword,
    required String firstName,
    required String lastName,
    required String address,
    required String region,
    required String city,
    required String barangay,
    String? phoneNumber,
  }) {
    return {
      'username': validateUsername(username),
      'password': validatePassword(password),
      'confirmPassword': validateConfirmPassword(password, confirmPassword),
      'firstName': validateName(firstName, 'First name'),
      'lastName': validateName(lastName, 'Last name'),
      'address': validateAddress(address),
      'region': validateLocation(region, 'Region'),
      'city': validateLocation(city, 'City'),
      'barangay': validateLocation(barangay, 'Barangay'),
      'phoneNumber': validatePhoneNumber(phoneNumber),
    };
  }
}
