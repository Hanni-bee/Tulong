import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for sending emails via EmailJS
class EmailJSService {
  static const String _baseUrl = 'https://api.emailjs.com/api/v1.0/email/send';
  static const String _serviceId = 'service_5d15f9c';
  static const String _templateId = 'template_wqf8kz7';
  static const String _publicKey = 'FMhX6Fc_Nlc0EGZIK';

  /// Send verification code email
  /// 
  /// [email] - Recipient email address
  /// [passcode] - 6-digit verification code
  /// 
  /// Returns true if email was sent successfully, false otherwise
  Future<bool> sendVerificationCode({
    required String email,
    required String passcode,
  }) async {
    try {
      // Prepare the request body according to EmailJS API format
      // Template expects: {{email}} for recipient, {{passcode}} for verification code
      final requestBody = {
        'service_id': _serviceId,
        'template_id': _templateId,
        'user_id': _publicKey,
        'template_params': {
          'email': email,  // Recipient email (matches template {{email}})
          'passcode': passcode,  // Verification code (matches template {{passcode}})
          'to_email': email,  // Also include to_email in case template uses it
          'from_name': 'T.U.L.O.N.G',
          'from_email': 'tulongcapstone@gmail.com',
          'reply_to': 'tulongcapstone@gmail.com',
        },
      };

      print('📧 Sending verification code to: $email');
      print('📧 Request body: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Origin': 'http://localhost',  // Some EmailJS configurations require this
        },
        body: jsonEncode(requestBody),
      );

      print('📧 Response status: ${response.statusCode}');
      print('📧 Response body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ Verification code sent successfully to $email');
        return true;
      } else {
        // Try to parse error message
        try {
          final errorData = jsonDecode(response.body);
          print('❌ EmailJS Error: ${errorData.toString()}');
        } catch (_) {
          print('❌ Failed to send verification code: ${response.statusCode} - ${response.body}');
        }
        return false;
      }
    } catch (e, stackTrace) {
      print('❌ Exception sending verification code: $e');
      print('❌ Stack trace: $stackTrace');
      return false;
    }
  }
}

