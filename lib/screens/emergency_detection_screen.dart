import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import '../services/ml_model_service.dart';

/// Emergency Detection Screen - Replaces Calls Screen
/// Allows users to capture photos and detect emergency types using AI/ML
class EmergencyDetectionScreen extends StatefulWidget {
  const EmergencyDetectionScreen({super.key});

  @override
  State<EmergencyDetectionScreen> createState() => _EmergencyDetectionScreenState();
}

class _EmergencyDetectionScreenState extends State<EmergencyDetectionScreen>
    with TickerProviderStateMixin {
  final CameraService _cameraService = CameraService();
  final ImagePreprocessingService _preprocessingService = ImagePreprocessingService();
  final EmergencyDetectionService _detectionService = EmergencyDetectionService();
  
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  bool _showFlash = false;
  
  // Animation controllers
  late AnimationController _flashController;
  late AnimationController _processingController;
  late AnimationController _captureButtonController;
  late Animation<double> _processingAnimation;
  late Animation<double> _captureButtonScale;
  late Animation<double> _captureButtonGlow;
  
  // Recent detections history
  final List<EmergencyDetectionResult> _recentDetections = [];
  
  // UI state
  bool _isButtonPressed = false;
  bool _showGrid = true;
  
  // Cooldown timer to prevent spam (1 minute)
  static const Duration _cooldownDuration = Duration(minutes: 1);
  DateTime? _lastCaptureTime;
  Timer? _cooldownTimer;
  int _cooldownSecondsRemaining = 0;
  bool get _isOnCooldown => _cooldownSecondsRemaining > 0;

  @override
  void initState() {
    super.initState();
    
    // Load last capture time and initialize cooldown
    _loadLastCaptureTime();
    
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
    
    // Capture button animation
    _captureButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    
    _captureButtonScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _captureButtonController,
        curve: Curves.easeInOut,
      ),
    );
    
    _captureButtonGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _captureButtonController,
        curve: Curves.easeOut,
      ),
    );
    
    // Try to load ML model if available (optional, won't fail if not present)
    _tryLoadMLModel();
    
    _initializeCamera();
  }
  
  /// Try to load ML model (optional enhancement)
  Future<void> _tryLoadMLModel() async {
    try {
      // Try to load model - will fail silently if model not found
      final loaded = await MLModelService.instance.loadModel('models/emergency_detector.tflite');
      if (loaded) {
        // Enable ML model usage in detection service
        _detectionService.setUseMLModel(true);
        debugPrint('✅ ML Model enabled for emergency detection');
      } else {
        debugPrint('ℹ️ ML Model not available, using rule-based detection');
      }
    } catch (e) {
      // Model not found or other error - this is fine, rule-based will work
      debugPrint('ℹ️ ML Model not available: $e (rule-based detection will be used)');
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _cameraService.dispose();
    _flashController.dispose();
    _processingController.dispose();
    _captureButtonController.dispose();
    super.dispose();
  }
  
  /// Load last capture time from SharedPreferences
  Future<void> _loadLastCaptureTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCaptureTimestamp = prefs.getInt('last_emergency_capture_time');
      if (lastCaptureTimestamp != null) {
        _lastCaptureTime = DateTime.fromMillisecondsSinceEpoch(lastCaptureTimestamp);
        _updateCooldownState();
      }
    } catch (e) {
      debugPrint('Error loading last capture time: $e');
    }
  }
  
  /// Save last capture time to SharedPreferences
  Future<void> _saveLastCaptureTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_emergency_capture_time', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error saving last capture time: $e');
    }
  }
  
  /// Update cooldown state and start timer if needed
  void _updateCooldownState() {
    if (_lastCaptureTime == null) {
      setState(() {
        _cooldownSecondsRemaining = 0;
      });
      return;
    }
    
    final now = DateTime.now();
    final timeSinceLastCapture = now.difference(_lastCaptureTime!);
    
    if (timeSinceLastCapture >= _cooldownDuration) {
      // Cooldown expired
      setState(() {
        _cooldownSecondsRemaining = 0;
        _lastCaptureTime = null;
      });
      _cooldownTimer?.cancel();
      _saveLastCaptureTime(); // Clear saved time
    } else {
      // Still on cooldown
      final remaining = _cooldownDuration - timeSinceLastCapture;
      setState(() {
        _cooldownSecondsRemaining = remaining.inSeconds;
      });
      
      // Start timer to update countdown every second
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        
        final now = DateTime.now();
        final timeSinceLastCapture = now.difference(_lastCaptureTime!);
        
        if (timeSinceLastCapture >= _cooldownDuration) {
          // Cooldown expired
          timer.cancel();
          setState(() {
            _cooldownSecondsRemaining = 0;
            _lastCaptureTime = null;
          });
          _saveLastCaptureTime(); // Clear saved time
        } else {
          final remaining = _cooldownDuration - timeSinceLastCapture;
          setState(() {
            _cooldownSecondsRemaining = remaining.inSeconds;
          });
        }
      });
    }
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
    // Check cooldown timer
    if (_isOnCooldown) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please wait ${_cooldownSecondsRemaining}s before capturing again'),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    
    if (!_isCameraInitialized || !_cameraService.isReady) {
      await _initializeCamera();
      if (!_cameraService.isReady) {
        return;
      }
    }
    
    // Haptic feedback for capture
    HapticFeedback.mediumImpact();
    
    // Set last capture time and start cooldown
    _lastCaptureTime = DateTime.now();
    await _saveLastCaptureTime();
    _updateCooldownState();

    setState(() {
      _isProcessing = true;
    });

    try {
      // Flash animation with enhanced effect
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
    // Special handling for "No Emergency" - positive, reassuring message
    if (result.type == EmergencyType.noEmergency) {
      _showNoEmergencyDialog(result);
      return;
    }
    
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
                            result.type.label.toUpperCase(),
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
                    
                    // Confidence indicator with progress bar
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.analytics,
                              size: 20,
                              color: AppColors.darkGray,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Confidence: ${result.getConfidenceString()}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.darkGray,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.lightGray.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Stack(
                              children: [
                                // Background
                                Container(width: double.infinity),
                                // Progress
                                FractionallySizedBox(
                                  widthFactor: result.confidence,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          severityColor,
                                          severityColor.withOpacity(0.7),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: severityColor.withOpacity(0.3),
                                          blurRadius: 4,
                                          spreadRadius: 0,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Quick actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showAnalysisDetails(result);
                            },
                            icon: const Icon(Icons.insights, size: 18),
                            label: const Text('Details'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _reportFalsePositive(result);
                            },
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Incorrect'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
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
                child: Column(
                  children: [
                    // User feedback buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _reportFalsePositive(result);
                            },
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Not an Emergency'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.mediumGray,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showAnalysisDetails(result);
                            },
                            icon: const Icon(Icons.info_outline, size: 18),
                            label: const Text('View Analysis'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.info,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Main action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Retake'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _sendToChat(result);
                            },
                            icon: const Icon(Icons.send, size: 18),
                            label: const Text(
                              'Send to Chat',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                      ],
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
    // Don't send "No Emergency" to chat - it's just for user reassurance
    if (result.type == EmergencyType.noEmergency) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No emergency detected - no alert will be sent.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    
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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: AppColors.primaryRed,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Emergency Detection',
              style: AppTypography.titleLarge.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          // Grid toggle
          IconButton(
            icon: Icon(_showGrid ? Icons.grid_on_rounded : Icons.grid_off_rounded),
            color: AppColors.textPrimary,
            tooltip: _showGrid ? 'Hide grid' : 'Show grid',
            onPressed: () {
              setState(() {
                _showGrid = !_showGrid;
              });
              HapticFeedback.lightImpact();
            },
          ),
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            color: AppColors.textPrimary,
            tooltip: 'About Emergency Detection',
            onPressed: () {
              _showInfoDialog();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Camera preview area with improved layout
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                decoration: SoftUIDesign.cardDecoration(
                  backgroundColor: Colors.black,
                  borderRadius: SoftUIDesign.cardBorderRadius,
                  elevation: 6.0,
                  showBorder: true,
                  borderColor: AppColors.primaryRed.withOpacity(0.3),
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(SoftUIDesign.cardBorderRadius - 2),
                      child: _isCameraInitialized && _cameraService.isReady
                          ? Stack(
                              children: [
                                CameraPreview(_cameraService.controller!),
                                // Grid lines overlay for composition
                                if (_showGrid && !_isProcessing)
                                  _buildCameraGrid(),
                                // Center focus indicator
                                if (!_isProcessing)
                                  _buildFocusIndicator(),
                              ],
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.black87,
                                    Colors.black54,
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (!_isCameraInitialized)
                                      const CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryRed),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryRed.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt,
                                          size: 64,
                                          color: AppColors.primaryRed,
                                        ),
                                      ),
                                    const SizedBox(height: 20),
                                    Text(
                                      _isCameraInitialized
                                          ? 'Camera not ready'
                                          : 'Initializing camera...',
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (!_isCameraInitialized)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 16),
                                        child: ElevatedButton.icon(
                                          onPressed: _initializeCamera,
                                          icon: const Icon(Icons.refresh, size: 18),
                                          label: const Text('Retry'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primaryRed,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                    
                    // Camera overlay guides with enhanced design
                    if (_isCameraInitialized && _cameraService.isReady && !_isProcessing)
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 16,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 10 * (1 - value)),
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppColors.primaryRed.withOpacity(0.4),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryRed.withOpacity(0.2),
                                  blurRadius: 12,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryRed.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    'Point camera at emergency scene',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
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
                    
                    // Processing overlay with enhanced design and animations
                    if (_isProcessing)
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: child,
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(SoftUIDesign.cardBorderRadius - 2),
                            border: Border.all(
                              color: AppColors.primaryRed.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Animated processing indicator with glow
                                AnimatedBuilder(
                                  animation: _processingAnimation,
                                  builder: (context, child) {
                                    return Container(
                                      padding: const EdgeInsets.all(28),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            AppColors.primaryRed.withOpacity(0.2 * _processingAnimation.value),
                                            AppColors.primaryRed.withOpacity(0.05),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primaryRed.withOpacity(0.3 * _processingAnimation.value),
                                            blurRadius: 20 + (10 * _processingAnimation.value),
                                            spreadRadius: 5,
                                          ),
                                        ],
                                      ),
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          AppColors.primaryRed,
                                        ),
                                        strokeWidth: 4,
                                        value: _processingAnimation.value,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 28),
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: const Duration(milliseconds: 800),
                                  curve: Curves.easeOut,
                                  builder: (context, value, child) {
                                    return Opacity(
                                      opacity: value,
                                      child: Transform.translate(
                                        offset: Offset(0, 10 * (1 - value)),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Column(
                                    children: [
                                      Text(
                                        'Analyzing emergency...',
                                        style: AppTypography.titleMedium.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'AI is processing your image',
                                        style: AppTypography.bodySmall.copyWith(
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Capture button with enhanced animations and interactions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: GestureDetector(
                onTapDown: (_) {
                  if (!_isProcessing && !_isOnCooldown) {
                    HapticFeedback.lightImpact();
                    _captureButtonController.forward();
                    setState(() => _isButtonPressed = true);
                  }
                },
                onTapUp: (_) {
                  if (!_isProcessing && !_isOnCooldown) {
                    _captureButtonController.reverse();
                    setState(() => _isButtonPressed = false);
                    _capturePhoto();
                  } else {
                    _captureButtonController.reverse();
                    setState(() => _isButtonPressed = false);
                  }
                },
                onTapCancel: () {
                  _captureButtonController.reverse();
                  setState(() => _isButtonPressed = false);
                },
                child: AnimatedBuilder(
                  animation: _captureButtonController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _captureButtonScale.value,
                      child: Opacity(
                        opacity: _isOnCooldown ? 0.6 : 1.0,
                        child: Container(
                          width: double.infinity,
                          height: SoftUIDesign.buttonHeight + 4,
                          decoration: SoftUIDesign.buttonDecoration(
                            backgroundColor: _isOnCooldown ? AppColors.mediumGray : AppColors.primaryRed,
                            shadowColor: _isOnCooldown ? AppColors.mediumGray : AppColors.primaryRed,
                            isPressed: _isButtonPressed,
                          ).copyWith(
                            boxShadow: _isOnCooldown
                                ? []
                                : [
                                    ...SoftUIDesign.getButtonShadow(color: AppColors.primaryRed),
                                    // Pulsing glow effect
                                    BoxShadow(
                                      color: AppColors.primaryRed.withOpacity(0.4 * _captureButtonGlow.value),
                                      blurRadius: 20 + (10 * _captureButtonGlow.value),
                                      spreadRadius: 5 + (3 * _captureButtonGlow.value),
                                    ),
                                  ],
                          ),
                    child: _isProcessing
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Processing...',
                                style: AppTypography.titleMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        : _isOnCooldown
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.timer_outlined,
                                      size: 24,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Wait ${_cooldownSecondsRemaining}s',
                                    style: AppTypography.titleMedium.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 24,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'CAPTURE PHOTO',
                                    style: AppTypography.titleMedium.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Recent detections section - always visible
            Flexible(
              flex: 2,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: SoftUIDesign.cardDecoration(
                  backgroundColor: AppColors.white,
                  borderRadius: SoftUIDesign.cardBorderRadius,
                  elevation: 4.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryRed.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.history_rounded,
                              size: 20,
                              color: AppColors.primaryRed,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Recent Detections',
                            style: AppTypography.titleLarge.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (_recentDetections.isNotEmpty)
                            Text(
                              '${_recentDetections.length}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.mediumGray,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    // Content - scrollable if many items
                    Expanded(
                      child: _recentDetections.isEmpty
                          ? SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: MediaQuery.of(context).size.height * 0.2,
                                ),
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0.0, end: 1.0),
                                          duration: const Duration(milliseconds: 800),
                                          curve: Curves.easeOut,
                                          builder: (context, value, child) {
                                            return Transform.scale(
                                              scale: 0.8 + (0.2 * value),
                                              child: Opacity(
                                                opacity: value,
                                                child: child,
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(24),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryRed.withOpacity(0.1),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: AppColors.primaryRed.withOpacity(0.2),
                                                width: 2,
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.camera_alt_rounded,
                                              size: 48,
                                              color: AppColors.primaryRed.withOpacity(0.6),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        Text(
                                          'Ready to Detect',
                                          style: AppTypography.titleMedium.copyWith(
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Capture a photo to detect emergency situations',
                                          style: AppTypography.bodySmall.copyWith(
                                            color: AppColors.mediumGray,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 16),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryRed.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: AppColors.primaryRed.withOpacity(0.2),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.auto_awesome,
                                                size: 16,
                                                color: AppColors.primaryRed,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'AI-Powered Detection',
                                                style: AppTypography.bodySmall.copyWith(
                                                  color: AppColors.primaryRed,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _recentDetections.length,
                              itemBuilder: (context, index) {
                                final detection = _recentDetections[index];
                                final severityColor = _getSeverityColor(detection.severity);
                                
                                return TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: Duration(milliseconds: 300 + (index * 50)),
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
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(14),
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
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: severityColor.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: severityColor.withOpacity(0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            detection.type.emoji,
                                            style: const TextStyle(fontSize: 28),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                detection.type.label,
                                                style: AppTypography.titleMedium.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 10,
                                                    height: 10,
                                                    decoration: BoxDecoration(
                                                      color: severityColor,
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: severityColor.withOpacity(0.5),
                                                          blurRadius: 4,
                                                          spreadRadius: 1,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    detection.severity.label.toUpperCase(),
                                                    style: AppTypography.bodySmall.copyWith(
                                                      color: severityColor,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              _formatTimeAgo(detection.timestamp),
                                              style: AppTypography.bodySmall.copyWith(
                                                color: AppColors.mediumGray,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${(detection.confidence * 100).toStringAsFixed(0)}%',
                                              style: AppTypography.bodySmall.copyWith(
                                                color: AppColors.mediumGray,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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

  /// Report false positive - helps improve system
  void _reportFalsePositive(EmergencyDetectionResult result) {
    // TODO: Store false positive feedback
    // This will be used to improve detection accuracy
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Thank you! Your feedback helps improve detection accuracy.',
                style: AppTypography.bodyMedium.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 3),
      ),
    );
    
    // Remove from recent detections if it's there
    setState(() {
      _recentDetections.removeWhere((d) => 
        d.timestamp == result.timestamp && 
        d.type == result.type
      );
    });
  }

  /// Show analysis details - transparency
  void _showAnalysisDetails(EmergencyDetectionResult result) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics, color: AppColors.primaryRed, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Analysis Details',
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildAnalysisDetailRow('Emergency Type', result.type.label),
              _buildAnalysisDetailRow('Severity', result.severity.label),
              _buildAnalysisDetailRow(
                'Confidence', 
                '${(result.confidence * 100).toStringAsFixed(1)}%',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lightGray.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How this was detected:',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The system analyzed color patterns, texture, edges, and spatial distribution across multiple regions of the image. This detection used a multi-pass validation system to ensure accuracy.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.mediumGray,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.mediumGray,
            ),
          ),
          Text(
            value,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// Show positive "No Emergency" dialog - reassuring message
  void _showNoEmergencyDialog(EmergencyDetectionResult result) {
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
              // Positive header with green gradient
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.success,
                      AppColors.success.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 64,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'NO EMERGENCY DETECTED',
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your surroundings appear safe',
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white.withOpacity(0.95),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                            color: AppColors.success.withOpacity(0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.success.withOpacity(0.1),
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
                    
                    // Reassuring message
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.success.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.verified,
                                color: AppColors.success,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Good News!',
                                  style: AppTypography.titleSmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'The AI analysis shows no signs of emergency situations. Your area appears safe and normal. Continue to stay alert and report any concerns if needed.',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textPrimary,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Confidence indicator
                    Row(
                      children: [
                        Icon(
                          Icons.analytics,
                          size: 18,
                          color: AppColors.mediumGray,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.mediumGray,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Info message
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.lightGray.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: AppColors.info,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Image stays on device. No emergency alert will be sent.',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.mediumGray,
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
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      'Understood',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Show info dialog about emergency detection
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.primaryRed,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Emergency Detection',
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildInfoRow(
                icon: Icons.camera_alt_rounded,
                title: 'Real-time Detection',
                description: 'Capture photos using the in-app camera to detect emergency situations instantly.',
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                icon: Icons.smartphone,
                title: '100% Offline',
                description: 'All processing happens on your device. No internet required. Works during disasters.',
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                icon: Icons.security,
                title: 'Privacy Protected',
                description: 'Images stay on your device. Only detection results are shared via ESP32/radio.',
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                icon: Icons.auto_awesome,
                title: 'AI-Powered',
                description: 'Uses advanced image analysis to detect fires, floods, earthquakes, accidents, and more.',
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryRed.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: AppColors.primaryRed,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.mediumGray,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  /// Build camera grid lines for composition
  Widget _buildCameraGrid() {
    return IgnorePointer(
      ignoring: true,
      child: CustomPaint(
        painter: _GridPainter(),
      ),
    );
  }
  
  /// Build focus indicator at center
  Widget _buildFocusIndicator() {
    return IgnorePointer(
      ignoring: true,
      child: Center(
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.white.withOpacity(0.6),
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              // Corner indicators
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.white.withOpacity(0.8), width: 2),
                      left: BorderSide(color: Colors.white.withOpacity(0.8), width: 2),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.white.withOpacity(0.8), width: 2),
                      right: BorderSide(color: Colors.white.withOpacity(0.8), width: 2),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 4,
                left: 4,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withOpacity(0.8), width: 2),
                      left: BorderSide(color: Colors.white.withOpacity(0.8), width: 2),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withOpacity(0.8), width: 2),
                      right: BorderSide(color: Colors.white.withOpacity(0.8), width: 2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for camera grid lines
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Rule of thirds grid (2 horizontal, 2 vertical lines)
    final thirdWidth = size.width / 3;
    final thirdHeight = size.height / 3;

    // Vertical lines
    canvas.drawLine(
      Offset(thirdWidth, 0),
      Offset(thirdWidth, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(thirdWidth * 2, 0),
      Offset(thirdWidth * 2, size.height),
      paint,
    );

    // Horizontal lines
    canvas.drawLine(
      Offset(0, thirdHeight),
      Offset(size.width, thirdHeight),
      paint,
    );
    canvas.drawLine(
      Offset(0, thirdHeight * 2),
      Offset(size.width, thirdHeight * 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

