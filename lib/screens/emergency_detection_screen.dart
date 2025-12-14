import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../utils/permission_helper.dart';
import '../models/emergency_type.dart';
import '../models/emergency_detection_result.dart';

/// Emergency Detection Screen - Replaces Calls Screen
/// Allows users to capture photos and detect emergency types using AI/ML
class EmergencyDetectionScreen extends StatefulWidget {
  const EmergencyDetectionScreen({super.key});

  @override
  State<EmergencyDetectionScreen> createState() => _EmergencyDetectionScreenState();
}

class _EmergencyDetectionScreenState extends State<EmergencyDetectionScreen> {
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  
  // Recent detections history
  final List<EmergencyDetectionResult> _recentDetections = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  /// Initialize camera and request permissions
  Future<void> _initializeCamera() async {
    // Request camera permission
    final hasPermission = await PermissionHelper.requestCameraPermission(context);
    
    if (hasPermission && mounted) {
      setState(() {
        _isCameraInitialized = true;
      });
      // TODO: Phase 2 - Initialize camera controller
    } else if (mounted) {
      // Show error if permission denied
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera permission is required for emergency detection'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  /// Handle photo capture
  Future<void> _capturePhoto() async {
    if (!_isCameraInitialized) {
      await _initializeCamera();
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    // TODO: Phase 2 - Implement actual camera capture
    // TODO: Phase 3 - Implement ML processing
    
    // Simulate processing delay
    await Future.delayed(const Duration(seconds: 2));

    // TODO: Replace with actual detection result
    // For now, create a placeholder result
    final result = EmergencyDetectionResult(
      type: EmergencyType.general,
      severity: SeverityLevel.medium,
      confidence: 0.75,
      timestamp: DateTime.now(),
    );

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _recentDetections.insert(0, result);
        // Keep only last 10 detections
        if (_recentDetections.length > 10) {
          _recentDetections.removeLast();
        }
      });

      // Show result dialog
      _showDetectionResult(result);
    }
  }

  /// Show detection result dialog
  void _showDetectionResult(EmergencyDetectionResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Text(result.type.emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${result.type.label.toUpperCase()} DETECTED',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryRed,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Severity: ${result.severity.label}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.darkGray,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Note: Image stays on device. Only detection result will be sent via ESP32/radio.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: AppColors.mediumGray,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Retake'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendToChat(result);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send to Chat'),
          ),
        ],
      ),
    );
  }

  /// Send detection result to chat
  void _sendToChat(EmergencyDetectionResult result) {
    // TODO: Phase 5 - Integrate with chat system
    // Create text message for ESP32/radio transmission
    final message = result.getFormattedMessage();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Emergency detection sent: $message'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
    
    // TODO: Actually send via ESP32/radio and add to chat
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text(
          'Emergency Detection',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Show settings dialog
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Camera preview area (placeholder for Phase 2)
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.lightGray,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.mediumGray,
                  width: 2,
                ),
              ),
              child: _isCameraInitialized
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt,
                            size: 64,
                            color: AppColors.mediumGray,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Camera Preview\n(Phase 2 Implementation)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.darkGray,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          const Text(
                            'Initializing camera...',
                            style: TextStyle(
                              color: AppColors.darkGray,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),

          // Capture button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _capturePhoto,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: _isProcessing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Processing...'),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 28),
                          SizedBox(width: 8),
                          Text(
                            'CAPTURE PHOTO',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          // Recent detections
          if (_recentDetections.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Detections:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._recentDetections.take(3).map((detection) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Text(
                              detection.type.emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${detection.type.label} - ${detection.severity.label}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              _formatTimeAgo(detection.timestamp),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.mediumGray,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Format timestamp as "X minutes ago"
  String _formatTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}

