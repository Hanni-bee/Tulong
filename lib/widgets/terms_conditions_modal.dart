import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class TermsConditionsModal extends StatelessWidget {
  const TermsConditionsModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.description_outlined,
                  color: AppColors.primaryRed,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Terms & Conditions',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.mediumGray,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Last updated: December 2024',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    _buildSection(
                      '1. Acceptance of Terms',
                      'By using the T.U.L.O.N.G application, you agree to be bound by these Terms and Conditions. If you do not agree to these terms, please do not use the application.',
                    ),
                    
                    _buildSection(
                      '2. Description of Service',
                      'T.U.L.O.N.G (Transmission Unit for Local Offline Network Generation) is a disaster communication system designed to provide emergency communication capabilities during natural disasters and emergencies when traditional communication networks may be unavailable.',
                    ),
                    
                    _buildSection(
                      '3. User Responsibilities',
                      '• Provide accurate and complete information during registration\n• Use the service responsibly and in accordance with local laws\n• Report any misuse or security concerns immediately\n• Maintain the confidentiality of your account credentials',
                    ),
                    
                    _buildSection(
                      '4. Emergency Use',
                      'This application is designed for emergency communication purposes. Users should not rely solely on this application for emergency services. Always contact official emergency services (911, local authorities) when possible.',
                    ),
                    
                    _buildSection(
                      '5. Privacy and Data',
                      'We collect and store minimal necessary information to provide the service. Location data may be shared with other users in your network for emergency coordination purposes. We do not sell or share personal information with third parties.',
                    ),
                    
                    _buildSection(
                      '6. Network Limitations',
                      'The application operates on local network connections and may have limited range and functionality. Network availability depends on device proximity and environmental conditions.',
                    ),
                    
                    _buildSection(
                      '7. Prohibited Uses',
                      '• Transmitting illegal, harmful, or inappropriate content\n• Attempting to compromise network security\n• Using the service for commercial purposes without authorization\n• Impersonating emergency services or authorities',
                    ),
                    
                    _buildSection(
                      '8. Limitation of Liability',
                      'T.U.L.O.N.G is provided "as is" without warranties. We are not liable for any damages arising from the use or inability to use the service, including but not limited to emergency situations.',
                    ),
                    
                    _buildSection(
                      '9. Service Availability',
                      'We do not guarantee continuous service availability. The application may be unavailable due to maintenance, technical issues, or other circumstances beyond our control.',
                    ),
                    
                    _buildSection(
                      '10. Changes to Terms',
                      'We reserve the right to modify these terms at any time. Continued use of the application after changes constitutes acceptance of the new terms.',
                    ),
                    
                    const SizedBox(height: 20),
                    
                    const Text(
                      'By using T.U.L.O.N.G, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Action buttons
            Row(
              children: [
                // Cancel button
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.mediumGray,
                      side: const BorderSide(color: AppColors.mediumGray),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Accept button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'I Accept',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryRed,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
