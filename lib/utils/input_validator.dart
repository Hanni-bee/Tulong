import 'package:flutter/material.dart';

class InputValidator {
  static const int _minPasswordLength = 8;
  static const int _maxPasswordLength = 128;
  static const int _maxNameLength = 50;
  static const int _maxEmailLength = 254;
  static const int _maxAddressLength = 200;

  // Email validation with comprehensive regex - EMOJIS ALLOWED
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email is required';
    }

    if (email.length > _maxEmailLength) {
      return 'Email is too long';
    }

    // Email regex - allows emojis and special characters in local part
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }

    return null;
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

  // Location validation (Region, City, Barangay) - TEXT ONLY, NO NUMBERS, NO EMOJIS
  static String? validateLocation(String? location, String fieldName) {
    if (location == null || location.isEmpty) {
      return '$fieldName is required';
    }

    if (location.length > _maxNameLength) {
      return '$fieldName is too long';
    }

    // Check for emojis and special Unicode characters
    final emojiRegex = RegExp(r'[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]', unicode: true);
    if (emojiRegex.hasMatch(location)) {
      return '$fieldName cannot contain emojis or special characters';
    }

    // Check for numbers
    if (location.contains(RegExp(r'[0-9]'))) {
      return '$fieldName cannot contain numbers';
    }

    // Only allow letters, spaces, and common location characters
    final locationRegex = RegExp(r"^[a-zA-Z\s\-'.,()]+$");
    if (!locationRegex.hasMatch(location)) {
      return '$fieldName can only contain letters, spaces, hyphens, apostrophes, periods, commas, and parentheses';
    }

    return null;
  }

  // Zip code validation (Philippine format)
  static String? validateZipCode(String? zipCode) {
    if (zipCode == null || zipCode.isEmpty) {
      return 'Zip code is required';
    }

    // Philippine zip code format: 4 digits
    final zipCodeRegex = RegExp(r'^\d{4}$');
    if (!zipCodeRegex.hasMatch(zipCode)) {
      return 'Zip code must be 4 digits';
    }

    return null;
  }

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
    required String email,
    required String password,
    required String confirmPassword,
    required String firstName,
    required String lastName,
    required String address,
    required String region,
    required String city,
    required String barangay,
    required String zipCode,
    String? phoneNumber,
  }) {
    return {
      'email': validateEmail(email),
      'password': validatePassword(password),
      'confirmPassword': validateConfirmPassword(password, confirmPassword),
      'firstName': validateName(firstName, 'First name'),
      'lastName': validateName(lastName, 'Last name'),
      'address': validateAddress(address),
      'region': validateLocation(region, 'Region'),
      'city': validateLocation(city, 'City'),
      'barangay': validateLocation(barangay, 'Barangay'),
      'zipCode': validateZipCode(zipCode),
      'phoneNumber': validatePhoneNumber(phoneNumber),
    };
  }
}
