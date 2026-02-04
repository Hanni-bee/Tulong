import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../utils/theme_colors.dart';
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
import '../services/disaster_classification_service.dart';
import '../services/detection_history_service.dart';
import '../widgets/unified_top_bar.dart';
import '../widgets/ai_info_widget.dart';
import '../widgets/ai_assessment_widget.dart';

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
  final DisasterClassificationService _mlClassificationService = DisasterClassificationService.instance;
  final DetectionHistoryService _historyService = DetectionHistoryService.instance;
  
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
    
    // Try to load AI disaster classification model (best_model.tflite)
    _tryLoadMLModel();
    _loadHistory();
    _initializeCamera();
  }

  /// Load detection history from SQLite (user-specific)
  Future<void> _loadHistory() async {
    if (!mounted) return;
    try {
      final detections = await _historyService.getUserDetections(limit: 10);
      if (mounted) {
        setState(() {
          _recentDetections.clear();
          _recentDetections.addAll(detections);
        });
      }
    } catch (e) {
      debugPrint('Error loading detection history: $e');
    }
  }

  /// Try to load ML model (AI disaster classification - best_model.tflite)
  Future<void> _tryLoadMLModel() async {
    try {
      final loaded = await _mlClassificationService.loadModel();
      if (loaded) {
        debugPrint('✅ AI disaster classification model loaded successfully');
      } else {
        // Fallback: try legacy path for rule-based enhancement
        final legacyLoaded = await MLModelService.instance.loadModel('best_model.tflite');
        if (legacyLoaded) {
          _detectionService.setUseMLModel(true);
          debugPrint('✅ ML Model enabled for emergency detection');
        } else {
          debugPrint('ℹ️ AI model not available, using rule-based detection');
        }
      }
    } catch (e) {
      debugPrint('ℹ️ AI model not available: $e (rule-based detection will be used)');
    }
  }

  /// Show AI info modal (replaces debug UI)
  void _showAIInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.psychology, color: AppColors.primaryRed),
            SizedBox(width: 8),
            Text('AI Disaster Detection'),
          ],
        ),
        content: SingleChildScrollView(
          child: AIInfoWidget(
            isModelLoaded: _mlClassificationService.isModelLoaded,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
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
      
      // Use AI disaster classification if model is loaded, else rule-based
      EmergencyDetectionResult result;
      if (_mlClassificationService.isModelLoaded) {
        result = await _mlClassificationService.classifyDisaster(imagePath);
        await _historyService.saveDetection(result);
      } else {
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
        result = await _detectionService.detectEmergency(preprocessed, imagePath);
        await _historyService.saveDetection(result);
      }

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _recentDetections.insert(0, result);
          if (_recentDetections.length > 10) {
            _recentDetections.removeLast();
          }
        });
        _showDetectionResult(result);
        _loadHistory();
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
  /// [detailedAssessment] optional from DisasterClassificationService for AI breakdown
  void _showDetectionResult(EmergencyDetectionResult result, [Map<String, dynamic>? detailedAssessment]) {
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
                    if (detailedAssessment != null) ...[
                      const SizedBox(height: 16),
                      AIAssessmentWidget(result: result, detailedAssessment: detailedAssessment),
                    ],
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
      backgroundColor: ThemeColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            UnifiedTopBar(
              title: 'Emergency',
              subtitle: null,
              icon: Icons.camera_alt_rounded,
              iconColor: AppColors.primaryRed,
              actions: [
                IconButton(
                  icon: const Icon(Icons.info_outline_rounded),
                  onPressed: _showAIInfo,
                  tooltip: 'AI Detection Info',
                ),
              ],
              compact: true,
            ),

            // Camera preview area with improved layout
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                decoration: SoftUIDesign.cardDecoration(
                  context: context,
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
                            context: context,
                            backgroundColor: _isOnCooldown ? AppColors.mediumGray : AppColors.primaryRed,
                            shadowColor: _isOnCooldown ? AppColors.mediumGray : AppColors.primaryRed,
                            isPressed: _isButtonPressed,
                          ).copyWith(
                            boxShadow: _isOnCooldown
                                ? []
                                : [
                                    ...SoftUIDesign.getButtonShadow(context: context, color: AppColors.primaryRed),
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

            // Detection History section (branch UI - horizontal list + View All modal)
            Flexible(
              flex: 2,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.history, color: AppColors.primaryRed, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Detection History',
                          style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const Spacer(),
                        if (_recentDetections.isNotEmpty)
                          GestureDetector(
                            onTap: _showFullHistoryModal,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryRed.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.primaryRed.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'View All',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.primaryRed,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 12,
                                    color: AppColors.primaryRed,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_recentDetections.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: ThemeColors.surface(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.lightGray),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.history_outlined,
                                size: 48,
                                color: AppColors.mediumGray.withOpacity(0.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No detections yet',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.mediumGray,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Capture a photo to start',
                                style: AppTypography.captionText.copyWith(
                                  color: AppColors.mediumGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 140,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _recentDetections.length,
                          itemBuilder: (context, index) {
                            final detection = _recentDetections[index];
                            final severityColor = _getSeverityColor(detection.severity);
                            final dateFormat = DateFormat('MMM dd');
                            final timeFormat = DateFormat('hh:mm a');
                            return GestureDetector(
                              onTap: () => _showDetectionDetails(detection),
                              child: Container(
                                width: 140,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  color: ThemeColors.surface(context),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: severityColor.withOpacity(0.3),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: severityColor.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            detection.type.emoji,
                                            style: const TextStyle(fontSize: 28),
                                          ),
                                          const Spacer(),
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: severityColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        detection.type.label,
                                        style: AppTypography.bodySmall.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        detection.severity.label,
                                        style: AppTypography.captionText.copyWith(
                                          color: severityColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 10,
                                        ),
                                      ),
                                      const Spacer(),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 10,
                                            color: AppColors.mediumGray,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              '${dateFormat.format(detection.timestamp)}\n${timeFormat.format(detection.timestamp)}',
                                              style: AppTypography.captionText.copyWith(
                                                color: AppColors.mediumGray,
                                                fontSize: 9,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
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

  /// Full history modal (branch UI - draggable sheet with list)
  void _showFullHistoryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: ThemeColors.surface(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.mediumGray.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.history, color: AppColors.primaryRed, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'Detection History',
                          style: AppTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_recentDetections.length}',
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.mediumGray,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: _recentDetections.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history_outlined,
                                  size: 64,
                                  color: AppColors.mediumGray.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No detection history',
                                  style: AppTypography.bodyLarge.copyWith(
                                    color: AppColors.mediumGray,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _recentDetections.length,
                            itemBuilder: (context, index) {
                              final detection = _recentDetections[index];
                              final severityColor = _getSeverityColor(detection.severity);
                              final dateFormat = DateFormat('MMM dd, yyyy');
                              final timeFormat = DateFormat('hh:mm:ss a');
                              return GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                  _showDetectionDetails(detection);
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: ThemeColors.surface(context),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: severityColor.withOpacity(0.3),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: severityColor.withOpacity(0.1),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: severityColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          detection.type.emoji,
                                          style: const TextStyle(fontSize: 32),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              detection.type.label.toUpperCase(),
                                              style: AppTypography.bodyLarge.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
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
                                                  detection.severity.label.toUpperCase(),
                                                  style: AppTypography.bodySmall.copyWith(
                                                    color: severityColor,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  detection.getConfidenceString(),
                                                  style: AppTypography.bodySmall.copyWith(
                                                    color: AppColors.mediumGray,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.access_time,
                                                  size: 14,
                                                  color: AppColors.mediumGray,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '${dateFormat.format(detection.timestamp)} • ${timeFormat.format(detection.timestamp)}',
                                                  style: AppTypography.captionText.copyWith(
                                                    color: AppColors.mediumGray,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right,
                                        color: AppColors.mediumGray,
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
            );
          },
        );
      },
    );
  }

  /// Show detection details (from history tap) with optional AI assessment
  void _showDetectionDetails(EmergencyDetectionResult detection) {
    Map<String, dynamic>? detailedAssessment;
    if (_mlClassificationService.isModelLoaded) {
      detailedAssessment = _mlClassificationService.getDetailedAssessment(
        detection.type,
        detection.confidence,
      );
    }
    _showDetectionResult(detection, detailedAssessment);
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
              color: ThemeColors.textPrimary(context),
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
                              color: ThemeColors.textPrimary(context),
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

