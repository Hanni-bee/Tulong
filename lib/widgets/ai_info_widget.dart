import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';

/// Widget displaying AI disaster detection information
class AIInfoWidget extends StatelessWidget {
  final bool isModelLoaded;

  const AIInfoWidget({
    super.key,
    required this.isModelLoaded,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isModelLoaded
                ? AppColors.success.withOpacity(0.1)
                : AppColors.error.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isModelLoaded ? AppColors.success : AppColors.error,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isModelLoaded ? Icons.check_circle : Icons.error_outline,
                color: isModelLoaded ? AppColors.success : AppColors.error,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isModelLoaded
                      ? 'AI Model Ready'
                      : 'AI Model Loading...',
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isModelLoaded ? AppColors.success : AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // AI Overview
        _buildSection(
          title: 'How It Works',
          icon: Icons.auto_awesome,
          children: [
            _buildInfoItem(
              'Advanced Machine Learning',
              'Our AI uses a deep learning model trained on thousands of disaster images to identify emergency situations in real-time.',
            ),
            _buildInfoItem(
              'Instant Detection',
              'Simply point your camera at the scene, and the AI analyzes the image to detect natural disasters like floods, wildfires, earthquakes, and cyclones.',
            ),
            _buildInfoItem(
              'Confidence Scoring',
              'Each detection includes a confidence percentage, helping you understand how certain the AI is about its assessment.',
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Supported Disasters
        _buildSection(
          title: 'Supported Disaster Types',
          icon: Icons.warning_amber_rounded,
          children: [
            _buildDisasterType('🌊', 'Flood', 'Detects flooding, water damage, and inundated areas'),
            _buildDisasterType('🔥', 'Wildfire', 'Identifies fire, smoke, and burned landscapes'),
            _buildDisasterType('🌍', 'Earthquake', 'Recognizes structural damage and ground displacement'),
            _buildDisasterType('🌀', 'Cyclone', 'Detects storm damage, strong winds, and hurricane effects'),
          ],
        ),

        const SizedBox(height: 24),

        // Severity Levels
        _buildSection(
          title: 'Severity Assessment',
          icon: Icons.assessment,
          children: [
            _buildSeverityLevel('Low', AppColors.success, 'Minimal risk, monitor situation'),
            _buildSeverityLevel('Medium', AppColors.warning, 'Moderate risk, take precautions'),
            _buildSeverityLevel('High', AppColors.error, 'Significant risk, immediate action needed'),
            _buildSeverityLevel('Critical', AppColors.primaryRed, 'Extreme danger, evacuate immediately'),
          ],
        ),

        const SizedBox(height: 24),

        // Privacy & Offline
        _buildSection(
          title: 'Privacy & Performance',
          icon: Icons.security,
          children: [
            _buildInfoItem(
              '100% Offline',
              'All AI processing happens on your device. No images are sent to external servers, ensuring complete privacy.',
            ),
            _buildInfoItem(
              'Fast & Efficient',
              'Optimized for mobile devices, providing instant results without draining your battery.',
            ),
            _buildInfoItem(
              'Always Improving',
              'The AI model is continuously refined to provide more accurate and reliable disaster detection.',
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Tips
        _buildSection(
          title: 'Tips for Best Results',
          icon: Icons.lightbulb_outline,
          children: [
            _buildTip('Ensure good lighting when capturing images'),
            _buildTip('Capture clear, focused images of the disaster scene'),
            _buildTip('Include context in the frame for better accuracy'),
            _buildTip('Review the confidence score before taking action'),
          ],
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primaryRed, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.mediumGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisasterType(String emoji, String name, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.mediumGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityLevel(String level, Color color, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.mediumGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTip(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: AppColors.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.mediumGray,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
