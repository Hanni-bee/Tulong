import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import '../constants/soft_ui_design.dart';
import '../utils/permission_helper.dart';
import '../models/emergency_type.dart';
import '../models/emergency_detection_result.dart';
import '../services/camera_service.dart';
import '../services/image_preprocessing_service.dart';
import '../services/emergency_detection_service.dart';
import '../services/simple_bluetooth_service.dart';

/// Emergency Detection Screen - Replaces Calls Screen
/// Allows users to capture photos and detect emergency types using AI/ML
class EmergencyDetectionScreen extends StatefulWidget {
  const EmergencyDetectionScreen({super.key});

  @override
  State<EmergencyDetectionScreen> createState() => _EmergencyDetectionScreenState();
}

class _EmergencyDetectionScreenState extends State<EmergencyDetectionScreen>
    with SingleTickerProviderStateMixin {
  final CameraService _cameraService = CameraService();
  final ImagePreprocessingService _preprocessingService = ImagePreprocessingService();
  final EmergencyDetectionService _detectionService = EmergencyDetectionService();
  
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  bool _showFlash = false;
  
  // Animation controllers
  late AnimationController _flashController;
  late AnimationController _processingController;
  late Animation<double> _processingAnimation;
  
  // Recent detections history
  final List<EmergencyDetectionResult> _recentDetections = [];

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    
    _processingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    
    _processingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _processingController,
        curve: Curves.easeInOut,
      ),
    );
    
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraService.dispose();
    _flashController.dispose();
    _processingController.dispose();
    super.dispose();
  }

  /// Initialize camera and request permissions
  Future<void> _initializeCamera() async {
    // Request camera permission
    final hasPermission = await PermissionHelper.requestCameraPermission(context);
    
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission is required for emergency detection'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    
    // Initialize camera
    final initialized = await _cameraService.initializeCamera();
    
    if (mounted) {
      setState(() {
        _isCameraInitialized = initialized;
      });
      
      if (!initialized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to initialize camera. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Handle photo capture
  Future<void> _capturePhoto() async {
    if (!_isCameraInitialized || !_cameraService.isReady) {
      await _initializeCamera();
      if (!_cameraService.isReady) {
        return;
      }
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Flash animation
      setState(() {
        _showFlash = true;
      });
      _flashController.forward().then((_) {
        _flashController.reverse().then((_) {
          if (mounted) {
            setState(() {
              _showFlash = false;
            });
          }
        });
      });
      
      // Capture photo
      final imagePath = await _cameraService.takePicture();
      
      if (imagePath == null) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to capture photo. Please try again.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
      
      // Preprocess image for ML model
      final preprocessed = await _preprocessingService.preprocessImage(imagePath);
      
      if (preprocessed == null) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to process image. Please try again.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
      
      // Perform emergency detection using rule-based classification
      final result = await _detectionService.detectEmergency(
        preprocessed,
        imagePath,
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
    } catch (e) {
      debugPrint('Error capturing photo: $e');
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Get severity color
  Color _getSeverityColor(SeverityLevel severity) {
    switch (severity) {
      case SeverityLevel.low:
        return Colors.green;
      case SeverityLevel.medium:
        return Colors.yellow.shade700;
      case SeverityLevel.high:
        return Colors.orange;
      case SeverityLevel.critical:
        return AppColors.primaryRed;
    }
  }

  /// Show detection result dialog with enhanced UI
  void _showDetectionResult(EmergencyDetectionResult result) {
    final severityColor = _getSeverityColor(result.severity);
    
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      severityColor,
                      severityColor.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      result.type.emoji,
                      style: const TextStyle(fontSize: 40),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${result.type.label.toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'DETECTED',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Captured image preview
                    if (result.imagePath != null)
                      Container(
                        height: 200,
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.lightGray,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(result.imagePath!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    
                    // Severity indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: severityColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: severityColor.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: severityColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Severity: ${result.severity.label}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: severityColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Confidence indicator
                    Row(
                      children: [
                        const Icon(
                          Icons.analytics,
                          size: 20,
                          color: AppColors.darkGray,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.darkGray,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Info note
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.lightGray.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 16,
                            color: AppColors.mediumGray,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Image stays on device. Only detection result will be sent via ESP32/radio.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.darkGray.withOpacity(0.7),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Retake'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _sendToChat(result);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Send to Chat',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Send detection result to chat via ESP32/radio
  Future<void> _sendToChat(EmergencyDetectionResult result) async {
    try {
      final btService = Provider.of<SimpleBluetoothService>(context, listen: false);
      
      // Check if connected and authenticated
      if (!btService.isConnected || !btService.isAuthenticated) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Not connected to ESP32. Please connect first.'),
              backgroundColor: AppColors.error,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      // Create formatted message for ESP32/radio transmission
      // The message will be parsed on receiving end to extract emergency info
      final formattedMessage = result.getFormattedMessage();
      
      // Include emergency detection metadata for local display
      final emergencyMetadata = {
        'isEmergency': true,
        'emergency_detection': result.toJson(),
      };
      
      // Send as group message (broadcast to all)
      // The SimpleBluetoothService will handle adding it to message store
      // Emergency detection will be parsed automatically on receiving end
      await btService.sendGroupMessage(formattedMessage, additionalData: emergencyMetadata);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Text(result.type.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Emergency detection sent to chat',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sending emergency detection to chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          'Emergency Detection',
          style: AppTypography.titleLarge.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            color: AppColors.textPrimary,
            onPressed: () {
              // TODO: Show settings dialog
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Camera preview area
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(SoftUIDesign.cardMargin * 2),
              decoration: SoftUIDesign.cardDecoration(
                backgroundColor: Colors.black,
                borderRadius: SoftUIDesign.cardBorderRadius,
                elevation: 4.0,
                showBorder: true,
                borderColor: AppColors.mediumGray.withOpacity(0.3),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: _isCameraInitialized && _cameraService.isReady
                        ? CameraPreview(_cameraService.controller!)
                        : Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (!_isCameraInitialized)
                                  const CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  )
                                else
                                  const Icon(
                                    Icons.camera_alt,
                                    size: 64,
                                    color: Colors.white54,
                                  ),
                                const SizedBox(height: 16),
                                Text(
                                  _isCameraInitialized
                                      ? 'Camera not ready'
                                      : 'Initializing camera...',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                                if (!_isCameraInitialized)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: TextButton(
                                      onPressed: _initializeCamera,
                                      child: const Text(
                                        'Retry',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                  ),
                  
                  // Flash overlay animation
                  if (_showFlash)
                    FadeTransition(
                      opacity: _flashController,
                      child: Container(
                        color: Colors.white,
                      ),
                    ),
                  
                  // Processing overlay
                  if (_isProcessing)
                    Container(
                      color: Colors.black.withOpacity(0.6),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _processingAnimation,
                              builder: (context, child) {
                                return CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primaryRed,
                                  ),
                                  strokeWidth: 4,
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Analyzing emergency...',
                              style: AppTypography.bodyMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Capture button
          Padding(
            padding: const EdgeInsets.all(SoftUIDesign.cardPadding),
            child: SizedBox(
              width: double.infinity,
              height: SoftUIDesign.buttonHeight,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _capturePhoto,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SoftUIDesign.buttonBorderRadius),
                  ),
                  elevation: 0,
                ).copyWith(
                  elevation: MaterialStateProperty.all(0),
                ),
                child: _isProcessing
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Processing...',
                            style: AppTypography.bodyMedium.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.camera_alt, size: 28),
                          const SizedBox(width: 8),
                          Text(
                            'CAPTURE PHOTO',
                            style: AppTypography.titleMedium.copyWith(
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
              margin: const EdgeInsets.all(SoftUIDesign.cardMargin * 2),
              padding: const EdgeInsets.all(SoftUIDesign.cardPadding),
              decoration: SoftUIDesign.cardDecoration(
                backgroundColor: AppColors.white,
                borderRadius: SoftUIDesign.cardBorderRadius,
                elevation: 4.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.history,
                        size: 20,
                        color: AppColors.darkGray,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Recent Detections',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ..._recentDetections.take(3).toList().asMap().entries.map((entry) {
                    final index = entry.key;
                    final detection = entry.value;
                    final severityColor = _getSeverityColor(detection.severity);
                    
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 300 + (index * 100).toInt()),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: severityColor.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: severityColor.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: severityColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                detection.type.emoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    detection.type.label,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: severityColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        detection.severity.label,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: severityColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _formatTimeAgo(detection.timestamp),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.mediumGray,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
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

