import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../services/disaster_classification_service.dart';
import '../services/model_test_service.dart';
import '../services/model_verification_service.dart';

/// Debug panel widget to show ML model status and dynamic detection info
class MLDebugPanel extends StatelessWidget {
  final bool isModelLoaded;
  final Map<String, dynamic>? debugInfo;
  final bool isLoading;
  
  const MLDebugPanel({
    super.key,
    required this.isModelLoaded,
    this.debugInfo,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final service = DisasterClassificationService.instance;
    final info = debugInfo ?? service.getDebugInfo();
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLoading 
              ? AppColors.info
              : isModelLoaded 
                  ? AppColors.success 
                  : AppColors.error,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isLoading
                      ? AppColors.info.withOpacity(0.2)
                      : isModelLoaded 
                          ? AppColors.success.withOpacity(0.2)
                          : AppColors.error.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.info),
                        ),
                      )
                    : Icon(
                        isModelLoaded ? Icons.check_circle : Icons.error,
                        color: isModelLoaded ? AppColors.success : AppColors.error,
                        size: 20,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'AI Model Status',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkGray,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isLoading
                      ? AppColors.info.withOpacity(0.1)
                      : isModelLoaded 
                          ? AppColors.success.withOpacity(0.1)
                          : AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isLoading
                        ? AppColors.info
                        : isModelLoaded 
                            ? AppColors.success 
                            : AppColors.error,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  isLoading ? 'LOADING...' : (isModelLoaded ? 'LOADED' : 'NOT LOADED'),
                  style: AppTypography.captionText.copyWith(
                    color: isLoading
                        ? AppColors.info
                        : isModelLoaded 
                            ? AppColors.success 
                            : AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Error message if not loaded
          if (!isModelLoaded && !isLoading && info['lastError'] != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.error.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      info['lastError']?.toString() ?? 'Unknown error',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.error,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          // Model Info
          if (isModelLoaded && info['inputShape'] != null) ...[
            _buildInfoRow(
              'Input Shape',
              info['inputShape']?.toString() ?? 'N/A',
              Icons.input,
            ),
            _buildInfoRow(
              'Output Shape',
              info['outputShape']?.toString() ?? 'N/A',
              Icons.output,
            ),
            if (info['modelLoadTime'] != null)
              _buildInfoRow(
                'Loaded At',
                _formatTime(info['modelLoadTime']),
                Icons.access_time,
              ),
            const Divider(height: 20),
          ],
          
          // Inference Stats
          Row(
            children: [
              Icon(
                Icons.psychology,
                size: 18,
                color: AppColors.mediumGray,
              ),
              const SizedBox(width: 8),
              Text(
                'Inference Count: ${info['inferenceCount'] ?? 0}',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.darkGray,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          if (info['lastInferenceTime'] != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              'Last Detection',
              _formatTime(info['lastInferenceTime']),
              Icons.history,
            ),
          ],
          
          if (info['lastClassification'] != null) ...[
            const SizedBox(height: 8),
            _buildInfoRow(
              'Last Result',
              info['lastClassification']?.toString() ?? 'N/A',
              Icons.label,
            ),
          ],
          
          // Dynamic Detection Verification
          if (info['lastImageHash'] != null) ...[
            const Divider(height: 20),
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withOpacity(0.5),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Dynamic Detection Active',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Hash: ${info['lastImageHash']?.toString().substring(0, 12) ?? 'N/A'}...',
              style: AppTypography.captionText.copyWith(
                color: AppColors.mediumGray,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
          
          // Verify Model Button
          const Divider(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : () async {
                // Run comprehensive verification
                final verificationService = ModelVerificationService.instance;
                final results = await verificationService.verifyModel();
                
                // Show results in a dialog
                if (context.mounted) {
                  showDialog(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Row(
                        children: [
                          Icon(
                            results['canDetect'] == true ? Icons.check_circle : Icons.error,
                            color: results['canDetect'] == true ? AppColors.success : AppColors.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              results['canDetect'] == true 
                                  ? 'Model Verified ✅' 
                                  : 'Verification Failed ❌',
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      content: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              verificationService.getVerificationSummary(results),
                              style: AppTypography.bodySmall.copyWith(
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: (results['canDetect'] == true 
                                    ? AppColors.success 
                                    : AppColors.error).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: (results['canDetect'] == true 
                                      ? AppColors.success 
                                      : AppColors.error).withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    results['canDetect'] == true ? Icons.check_circle : Icons.error,
                                    color: results['canDetect'] == true ? AppColors.success : AppColors.error,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      results['canDetect'] == true
                                          ? 'Model can detect disasters'
                                          : 'Model cannot detect - check errors above',
                                      style: AppTypography.bodyMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: results['canDetect'] == true ? AppColors.success : AppColors.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  );
                }
              },
              icon: isLoading 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_user, size: 18),
              label: Text(isLoading ? 'Verifying...' : 'Verify Model'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.info,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: AppColors.mediumGray,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.mediumGray,
              fontSize: 12,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.darkGray,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
  String _formatTime(String? isoString) {
    if (isoString == null) return 'N/A';
    try {
      final time = DateTime.parse(isoString);
      final now = DateTime.now();
      final diff = now.difference(time);
      
      if (diff.inSeconds < 60) {
        return '${diff.inSeconds}s ago';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}h ago';
      } else {
        return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      return 'Invalid';
    }
  }
}
