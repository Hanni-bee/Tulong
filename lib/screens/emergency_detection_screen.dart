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
import '../services/damage_severity_service.dart' show DamageSeverityService;
import '../services/sqlite_service.dart';

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
  final DamageSeverityService _damageSeverityService = DamageSeverityService.instance;
  
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
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    
    _processingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _processingController,
        curve: Curves.linear, // Smooth continuous rotation
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
    
    // Load damage severity model
    _loadDamageSeverityModel();
    
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
  
  /// Load damage severity model for AI assessment
  Future<void> _loadDamageSeverityModel() async {
    try {
      debugPrint('🔄 Loading Damage Severity Model...');
      
      // Retry mechanism - try loading up to 3 times
      bool loaded = false;
      for (int attempt = 1; attempt <= 3; attempt++) {
        debugPrint('   Attempt $attempt/3...');
        loaded = await _damageSeverityService.loadModel();
        
        if (loaded) {
          // Verify it's actually loaded
          if (_damageSeverityService.isModelLoaded && MLModelService.instance.isLoaded) {
            debugPrint('✅ Model verified loaded on attempt $attempt');
            break;
          } else {
            debugPrint('⚠️ loadModel returned true but model not actually loaded');
            loaded = false;
          }
        }
        
        if (attempt < 3) {
          debugPrint('   Waiting 1 second before retry...');
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      
      if (mounted) {
        setState(() {
          // Trigger rebuild to update UI status
        });
      }
      
      if (loaded && _damageSeverityService.isModelLoaded) {
        debugPrint('✅✅✅ Damage Severity Model loaded and verified successfully');
        debugPrint('   Input shape: ${MLModelService.instance.inputShape}');
        debugPrint('   Output shape: ${MLModelService.instance.outputShape}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ AI Model loaded successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        debugPrint('❌❌❌ Damage Severity Model FAILED to load after 3 attempts');
        debugPrint('   Model will NOT be used for detection');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ AI Model failed to load. Using rule-based detection only.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌❌❌ Damage Severity Model error: $e');
      debugPrint('   Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          // Trigger rebuild even on error
        });
      }
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
      
      // CAPTURE FIRST - no processing yet
      final imagePath = await _cameraService.takePicture();
      
      // NOW SET PROCESSING - after capture is done
      if (mounted) {
        setState(() {
          _isProcessing = true;
        });
      }
      
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
      
      // Perform AI damage severity assessment
      // STRICT CHECK: Only run if model is properly loaded
      Map<String, dynamic>? aiAssessment;
      if (_damageSeverityService.isModelLoaded) {
        debugPrint('✅ Model is loaded - running AI assessment');
        try {
          aiAssessment = await _damageSeverityService.assessDamageSeverity(imagePath);
          if (aiAssessment != null) {
            debugPrint('✅ AI Assessment: ${aiAssessment['className']} (${(aiAssessment['confidence'] * 100).toStringAsFixed(1)}%)');
          } else {
            debugPrint('⚠️ AI assessment returned null - model may not have run');
          }
        } catch (e, stackTrace) {
          debugPrint('❌ AI assessment failed: $e');
          debugPrint('   Stack trace: $stackTrace');
        }
      } else {
        debugPrint('⚠️ Model not loaded - skipping AI assessment');
        debugPrint('   Emergency detection will use rule-based classification only');
      }
      
      // Perform emergency detection using rule-based classification
      final result = await _detectionService.detectEmergency(
        preprocessed,
        imagePath,
      );
      
      // Enhance result with AI assessment if available
      if (aiAssessment != null) {
        // Update result with AI assessment data
        result.aiAssessment = aiAssessment;
        debugPrint('✅ Enhanced result with AI assessment');
        
        // Save severity status (ONLY THE STATUS) to SQLite
        try {
          final sqliteService = SQLiteService();
          final severityStatus = aiAssessment['className'] as String? ?? 'Unknown';
          final detectedDate = DateTime.now();
          final confidence = aiAssessment['confidence'] as double?;
          final classIndex = aiAssessment['classIndex'] as int?;
          
          await sqliteService.insertSeverityStatus(
            severityStatus: severityStatus,
            detectedDate: detectedDate,
            confidence: confidence,
            classIndex: classIndex,
          );
          debugPrint('✅ Severity status saved to SQLite: $severityStatus (Date: $detectedDate)');
        } catch (e) {
          debugPrint('⚠️ Failed to save severity status to SQLite: $e');
        }
      }

      if (mounted) {
        // Disable flashlight after detection
        try {
          if (_cameraService.isReady && _cameraService.controller != null) {
            await _cameraService.controller!.setFlashMode(FlashMode.off);
          }
        } catch (e) {
          debugPrint('⚠️ Failed to disable flash: $e');
        }
        
        setState(() {
          _isProcessing = false;
          _showFlash = false; // Ensure flash UI is off
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
          constraints: BoxConstraints(
            maxWidth: 380,
            maxHeight: MediaQuery.of(context).size.height * 0.80,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with RED gradient - Emergency theme
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryRed,
                      AppColors.error.withOpacity(0.9),
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
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${result.type.label.toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'DETECTED',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.85),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content - Scrollable to prevent overlap
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Captured image preview - More compact
                      if (result.imagePath != null)
                        Container(
                          height: 160,
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.lightGray.withOpacity(0.5),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.file(
                              File(result.imagePath!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      
                      // AI Assessment Display (if available) - Enhanced & Cleaner UI
                    if (result.aiAssessment != null)
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 600),
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
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryRed.withOpacity(0.15),
                                AppColors.error.withOpacity(0.08),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.primaryRed.withOpacity(0.4),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryRed.withOpacity(0.15),
                                blurRadius: 10,
                                spreadRadius: 0,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header - More compact design
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.primaryRed,
                                          AppColors.error,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primaryRed.withOpacity(0.4),
                                          blurRadius: 8,
                                          spreadRadius: 0,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 22,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'AI Damage Assessment',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.mediumGray,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          result.aiAssessment!['className'] as String,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryRed,
                                            letterSpacing: 0.2,
                                            height: 1.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(_damageSeverityService.getSeverityColor(result.aiAssessment!['classIndex'] as int)),
                                          Color(_damageSeverityService.getSeverityColor(result.aiAssessment!['classIndex'] as int)).withOpacity(0.8),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(28),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Color(_damageSeverityService.getSeverityColor(result.aiAssessment!['classIndex'] as int)).withOpacity(0.3),
                                          blurRadius: 8,
                                          spreadRadius: 0,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      '${((result.aiAssessment!['confidence'] as double) * 100).toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              // Detected Date & Time - REQUIRED DISPLAY
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    size: 14,
                                    color: AppColors.mediumGray,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Detected: ${_formatDateTime(result.timestamp)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.mediumGray,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              // Confidence progress bar - More compact
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Confidence Level',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.mediumGray,
                                        ),
                                      ),
                                      Text(
                                        '${((result.aiAssessment!['confidence'] as double) * 100).toStringAsFixed(1)}%',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(_damageSeverityService.getSeverityColor(result.aiAssessment!['classIndex'] as int)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0.0, end: result.aiAssessment!['confidence'] as double),
                                      duration: const Duration(milliseconds: 1000),
                                      curve: Curves.easeOut,
                                      builder: (context, value, child) {
                                        return Container(
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: AppColors.lightGray.withOpacity(0.25),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Stack(
                                            children: [
                                              FractionallySizedBox(
                                                widthFactor: value,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [
                                                        Color(_damageSeverityService.getSeverityColor(result.aiAssessment!['classIndex'] as int)),
                                                        Color(_damageSeverityService.getSeverityColor(result.aiAssessment!['classIndex'] as int)).withOpacity(0.7),
                                                      ],
                                                    ),
                                                    borderRadius: BorderRadius.circular(10),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Color(_damageSeverityService.getSeverityColor(result.aiAssessment!['classIndex'] as int)).withOpacity(0.4),
                                                        blurRadius: 6,
                                                        spreadRadius: 0,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              // Probability breakdown - More compact design
                              if (result.aiAssessment!['probabilities'] != null)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Probability Breakdown',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.mediumGray,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    // Model Status Indicator
                                    if (result.aiAssessment!['isModelStatic'] != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        margin: const EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          color: (result.aiAssessment!['isModelStatic'] as bool)
                                              ? Colors.orange.withOpacity(0.15)
                                              : Colors.green.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: (result.aiAssessment!['isModelStatic'] as bool)
                                                ? Colors.orange
                                                : Colors.green,
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              (result.aiAssessment!['isModelStatic'] as bool)
                                                  ? Icons.warning_rounded
                                                  : Icons.check_circle_rounded,
                                              size: 16,
                                              color: (result.aiAssessment!['isModelStatic'] as bool)
                                                  ? Colors.orange
                                                  : Colors.green,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                result.aiAssessment!['modelStatusMessage'] as String? ?? 'Model status unknown',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: (result.aiAssessment!['isModelStatic'] as bool)
                                                      ? Colors.orange.shade800
                                                      : Colors.green.shade800,
                                                ),
                                              ),
                                            ),
                                            if (result.aiAssessment!['inferenceCount'] != null)
                                              Text(
                                                '#${result.aiAssessment!['inferenceCount']}',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  color: AppColors.mediumGray,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ...((result.aiAssessment!['probabilities'] as List<double>).asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final prob = entry.value;
                                      final classNames = ["Little/No damage", "Mild damage", "Severe damage"];
                                      final className = classNames[index];
                                      final isSelected = index == result.aiAssessment!['classIndex'];
                                      final classColor = Color(_damageSeverityService.getSeverityColor(index));
                                      
                                      return TweenAnimationBuilder<double>(
                                        tween: Tween(begin: 0.0, end: prob),
                                        duration: Duration(milliseconds: 700 + (index * 100)),
                                        curve: Curves.easeOut,
                                        builder: (context, animValue, child) {
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? classColor.withOpacity(0.1)
                                                  : AppColors.lightGray.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isSelected
                                                    ? classColor.withOpacity(0.4)
                                                    : AppColors.lightGray.withOpacity(0.3),
                                                width: isSelected ? 2 : 1,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      width: 10,
                                                      height: 10,
                                                      decoration: BoxDecoration(
                                                        color: isSelected ? classColor : AppColors.mediumGray,
                                                        shape: BoxShape.circle,
                                                        boxShadow: isSelected
                                                            ? [
                                                                BoxShadow(
                                                                  color: classColor.withOpacity(0.4),
                                                                  blurRadius: 4,
                                                                  spreadRadius: 0,
                                                                ),
                                                              ]
                                                            : null,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Text(
                                                        className,
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: isSelected ? AppColors.textPrimary : AppColors.mediumGray,
                                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      '${(animValue * 100).toStringAsFixed(1)}%',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: isSelected ? classColor : AppColors.mediumGray,
                                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(5),
                                                  child: Container(
                                                    height: 6,
                                                    decoration: BoxDecoration(
                                                      color: AppColors.lightGray.withOpacity(0.2),
                                                    ),
                                                    child: FractionallySizedBox(
                                                      widthFactor: animValue,
                                                      alignment: Alignment.centerLeft,
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          gradient: LinearGradient(
                                                            colors: [
                                                              classColor,
                                                              classColor.withOpacity(0.7),
                                                            ],
                                                          ),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    }).toList()),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    
                    // Detection Summary - RED THEME for Emergency
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.error.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.warning_rounded,
                                  size: 18,
                                  color: AppColors.error,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Severity Status: ${result.severity.label}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.bar_chart_rounded,
                                      size: 14,
                                      color: AppColors.error,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${(result.confidence * 100).toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Info note - More compact
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.lightGray.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 14,
                            color: AppColors.mediumGray,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Image stays on device. Only detection result will be sent via ESP32/radio.',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.darkGray.withOpacity(0.7),
                                height: 1.3,
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
              
              // Actions - More compact layout
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Main action button - Send to Chat (as abang, not dynamic)
                    SizedBox(
                      width: double.infinity,
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
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // AI Assessment Log Button (only if AI assessment exists)
                    if (result.aiAssessment != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _showAssessmentLogs(result);
                            },
                            icon: const Icon(Icons.description, size: 16),
                            label: const Text('View Assessment Logs', style: TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryRed,
                              side: BorderSide(color: AppColors.primaryRed, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Secondary actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _showAnalysisDetails(result);
                            },
                            icon: const Icon(Icons.insights, size: 16),
                            label: const Text('Details', style: TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
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
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Incorrect', style: TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
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
        automaticallyImplyLeading: false, // Remove back button to prevent logout
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
          // Debug Model Status Button
          IconButton(
            icon: Icon(
              _damageSeverityService.isModelStatic ? Icons.warning_rounded : Icons.bug_report_rounded,
              color: _damageSeverityService.isModelStatic ? Colors.orange : AppColors.textPrimary,
            ),
            tooltip: 'Model Status Debug',
            onPressed: () {
              _showModelStatusDialog();
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
                              fit: StackFit.expand,
                              children: [
                                // Camera preview - fill properly without black screen
                                SizedBox.expand(
                                  child: CameraPreview(_cameraService.controller!),
                                ),
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
                                // Animated processing indicator - Better animation
                                AnimatedBuilder(
                                  animation: _processingAnimation,
                                  builder: (context, child) {
                                    return Container(
                                      padding: const EdgeInsets.all(28),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            AppColors.primaryRed.withOpacity(0.25),
                                            AppColors.primaryRed.withOpacity(0.05),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primaryRed.withOpacity(0.4),
                                            blurRadius: 25,
                                            spreadRadius: 5,
                                          ),
                                        ],
                                      ),
                                      child: Transform.rotate(
                                        angle: _processingAnimation.value * 2.0 * 3.14159, // Smooth rotation
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            AppColors.primaryRed,
                                          ),
                                          strokeWidth: 4,
                                          value: null, // Indeterminate for smooth spin
                                        ),
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
                                  child: InkWell(
                                    onTap: () {
                                      // Make recent detection clickable to view details
                                      _showDetectionResult(detection);
                                    },
                                    borderRadius: BorderRadius.circular(12),
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

  /// Format date and time for display - Simple format
  String _formatDateTime(DateTime dateTime) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[dateTime.month - 1];
    final day = dateTime.day;
    final year = dateTime.year;
    
    int hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
    
    return '$month $day, $year at $hour:$minute $period';
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

  /// Show AI assessment logs - detailed information about model execution
  void _showAssessmentLogs(EmergencyDetectionResult result) {
    if (result.aiAssessment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No AI assessment available'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    
    final assessment = result.aiAssessment!;
    final isStatic = assessment['isModelStatic'] as bool? ?? false;
    final statusMessage = assessment['modelStatusMessage'] as String? ?? 'Unknown status';
    final inferenceCount = assessment['inferenceCount'] as int? ?? 0;
    final classIndex = assessment['classIndex'] as int? ?? 0;
    final className = assessment['className'] as String? ?? 'Unknown';
    final confidence = assessment['confidence'] as double? ?? 0.0;
    final probabilities = assessment['probabilities'] as List<double>? ?? [];
    final detectedAt = assessment['detectedAt'] as int?;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryRed,
                      AppColors.error.withOpacity(0.9),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.description, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'AI Assessment Logs',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              
              // Scrollable content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Model Status
                      _buildLogSection(
                        'Model Status',
                        [
                          _buildLogRow('Model Loaded', _damageSeverityService.isModelLoaded ? 'Yes ✅' : 'No ❌'),
                          _buildLogRow('ML Service Ready', MLModelService.instance.isLoaded ? 'Yes ✅' : 'No ❌'),
                          _buildLogRow('Detection Type', isStatic ? 'STATIC ⚠️' : 'DYNAMIC ✅'),
                          _buildLogRow('Status Message', statusMessage),
                          _buildLogRow('Inference Count', '$inferenceCount'),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Assessment Result
                      _buildLogSection(
                        'Assessment Result',
                        [
                          _buildLogRow('Class Index', '$classIndex'),
                          _buildLogRow('Class Name', className),
                          _buildLogRow('Confidence', '${(confidence * 100).toStringAsFixed(2)}%'),
                          if (detectedAt != null)
                            _buildLogRow('Detected At', _formatDateTime(DateTime.fromMillisecondsSinceEpoch(detectedAt))),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Probabilities
                      if (probabilities.isNotEmpty)
                        _buildLogSection(
                          'Class Probabilities',
                          probabilities.asMap().entries.map((entry) {
                            final index = entry.key;
                            final prob = entry.value;
                            final classNames = ["Little/No damage", "Mild damage", "Severe damage"];
                            final isSelected = index == classIndex;
                            return _buildLogRow(
                              classNames[index],
                              '${(prob * 100).toStringAsFixed(2)}%${isSelected ? " ⭐ (Selected)" : ""}',
                            );
                          }).toList(),
                        ),
                      
                      const SizedBox(height: 16),
                      
                      // Model Information
                      _buildLogSection(
                        'Model Information',
                        [
                          _buildLogRow('Model Name', 'medic_damage_severity_model.keras.tflite'),
                          _buildLogRow('Input Shape', MLModelService.instance.inputShape?.toString() ?? 'Unknown'),
                          _buildLogRow('Output Shape', MLModelService.instance.outputShape?.toString() ?? 'Unknown'),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Image Information
                      if (result.imagePath != null)
                        _buildLogSection(
                          'Image Information',
                          [
                            _buildLogRow('Image Path', result.imagePath!.split('/').last),
                            _buildLogRow('Timestamp', _formatDateTime(result.timestamp)),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              
              // Close Button
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
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
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
  
  /// Build log section
  Widget _buildLogSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryRed,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.lightGray.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.mediumGray.withOpacity(0.2),
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
  
  /// Build log row
  Widget _buildLogRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.mediumGray,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
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
          constraints: BoxConstraints(
            maxWidth: 380,
            maxHeight: MediaQuery.of(context).size.height * 0.80,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with RED gradient - Emergency theme (even for no emergency)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryRed,
                      AppColors.error.withOpacity(0.9),
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
                    const Icon(
                      Icons.check_circle,
                      size: 32,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NO EMERGENCY DETECTED',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Your surroundings appear safe',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.85),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content - Scrollable
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Captured image preview - Compact
                      if (result.imagePath != null)
                        Container(
                          height: 160,
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primaryRed.withOpacity(0.3),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryRed.withOpacity(0.1),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.file(
                              File(result.imagePath!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                    
                      // AI Assessment Display (if available)
                      if (result.aiAssessment != null)
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 600),
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
                            padding: const EdgeInsets.all(14),
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primaryRed.withOpacity(0.15),
                                  AppColors.primaryRed.withOpacity(0.08),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.primaryRed.withOpacity(0.4),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                        colors: [
                                          AppColors.primaryRed,
                                          AppColors.error,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primaryRed.withOpacity(0.4),
                                          blurRadius: 8,
                                          spreadRadius: 0,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 22,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'AI Damage Assessment',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.mediumGray,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          result.aiAssessment!['className'] as String,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryRed,
                                              letterSpacing: 0.2,
                                              height: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.primaryRed,
                                            AppColors.error,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(28),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primaryRed.withOpacity(0.4),
                                            blurRadius: 8,
                                            spreadRadius: 0,
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        '${((result.aiAssessment!['confidence'] as double) * 100).toStringAsFixed(0)}%',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      // Severity Status - Most Important (from AI) - RED THEME
                      if (result.aiAssessment != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primaryRed.withOpacity(0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    color: AppColors.primaryRed,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Severity Status',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryRed,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                result.aiAssessment!['className'] as String,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryRed,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Detected: ${_formatDateTime(result.timestamp)}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.mediumGray,
                                ),
                              ),
                              // Model Status Indicator for No Emergency
                              if (result.aiAssessment!['isModelStatic'] != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: (result.aiAssessment!['isModelStatic'] as bool)
                                        ? Colors.orange.withOpacity(0.15)
                                        : Colors.green.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: (result.aiAssessment!['isModelStatic'] as bool)
                                          ? Colors.orange
                                          : Colors.green,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        (result.aiAssessment!['isModelStatic'] as bool)
                                            ? Icons.warning_rounded
                                            : Icons.check_circle_rounded,
                                        size: 14,
                                        color: (result.aiAssessment!['isModelStatic'] as bool)
                                            ? Colors.orange
                                            : Colors.green,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          result.aiAssessment!['modelStatusMessage'] as String? ?? 'Model status unknown',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: (result.aiAssessment!['isModelStatic'] as bool)
                                                ? Colors.orange.shade800
                                                : Colors.green.shade800,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 12),
                      
                      // Detected Date & Time - REQUIRED DISPLAY
                      if (result.aiAssessment != null)
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: AppColors.primaryRed,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Detected: ${_formatDateTime(result.timestamp)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.primaryRed,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      if (result.aiAssessment != null) const SizedBox(height: 10),
                      
                      // Confidence indicator - Compact - RED THEME
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bar_chart_rounded,
                              size: 14,
                              color: AppColors.primaryRed,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: AppColors.primaryRed,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Info message - Compact
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.lightGray.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 14,
                              color: AppColors.mediumGray,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Image stays on device. No emergency alert will be sent.',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.darkGray.withOpacity(0.7),
                                  height: 1.3,
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
              
              // Actions - Same as emergency modal (Send to Chat, Incorrect)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Main action button - Send to Chat (abang)
                    SizedBox(
                      width: double.infinity,
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
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // AI Assessment Log Button (only if AI assessment exists)
                    if (result.aiAssessment != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              _showAssessmentLogs(result);
                            },
                            icon: const Icon(Icons.description, size: 16),
                            label: const Text('View Assessment Logs', style: TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryRed,
                              side: BorderSide(color: AppColors.primaryRed, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Secondary actions - Incorrect (delete)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _reportFalsePositive(result);
                            },
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Incorrect', style: TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              side: BorderSide(
                                color: AppColors.mediumGray.withOpacity(0.3),
                              ),
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

  /// Show info dialog about emergency detection
  /// Show model status debug dialog
  void _showModelStatusDialog() {
    // Refresh status by checking current state
    final isStatic = _damageSeverityService.isModelStatic;
    final statusMessage = _damageSeverityService.modelStatusMessage ?? 
        (_damageSeverityService.isModelLoaded ? 'Model is loaded and ready' : 'Model not loaded');
    final isLoaded = _damageSeverityService.isModelLoaded;
    
    // Also check MLModelService directly
    final mlServiceLoaded = MLModelService.instance.isLoaded;
    
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
                      color: isStatic ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isStatic ? Icons.warning_rounded : Icons.check_circle_rounded,
                      color: isStatic ? Colors.orange : Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Model Status Debug',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Model Loaded Status - Check both services
              _buildStatusRow(
                'Model Loaded',
                (isLoaded && mlServiceLoaded) ? 'Yes' : 'No',
                (isLoaded && mlServiceLoaded) ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 12),
              // ML Service Status
              _buildStatusRow(
                'ML Service Status',
                mlServiceLoaded ? 'Ready' : 'Not Ready',
                mlServiceLoaded ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 12),
              // Damage Service Status
              _buildStatusRow(
                'Damage Service Status',
                isLoaded ? 'Ready' : 'Not Ready',
                isLoaded ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 12),
              // Static/Dynamic Status
              _buildStatusRow(
                'Detection Type',
                isStatic ? 'STATIC (Not Working)' : 'DYNAMIC (Working)',
                isStatic ? Colors.orange : Colors.green,
              ),
              const SizedBox(height: 12),
              // Status Message
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isStatic ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isStatic ? Colors.orange : Colors.green,
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isStatic ? Icons.warning_rounded : Icons.info_rounded,
                      size: 18,
                      color: isStatic ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        statusMessage,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
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
  
  /// Build status row for debug dialog
  Widget _buildStatusRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.mediumGray,
            fontWeight: FontWeight.w500,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: valueColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: valueColor, width: 1),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: valueColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

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

