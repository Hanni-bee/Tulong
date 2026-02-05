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
import '../services/disaster_classification_service.dart';
import '../services/model_test_service.dart';
import '../services/model_verification_service.dart';
import '../services/detection_history_service.dart';
import '../providers/chat_provider.dart';
import 'local_chat_screen.dart';
import '../widgets/unified_top_bar.dart';
import '../widgets/ai_assessment_widget.dart';
import '../widgets/ai_info_widget.dart';
import '../services/ml_model_service.dart';
import 'package:intl/intl.dart';

/// Emergency Detection Screen - Clean and focused on detection
class EmergencyDetectionScreen extends StatefulWidget {
  const EmergencyDetectionScreen({super.key});

  @override
  State<EmergencyDetectionScreen> createState() => _EmergencyDetectionScreenState();
}

class _EmergencyDetectionScreenState extends State<EmergencyDetectionScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final CameraService _cameraService = CameraService();
  final ImagePreprocessingService _preprocessingService = ImagePreprocessingService();
  final EmergencyDetectionService _detectionService = EmergencyDetectionService();
  final DisasterClassificationService _mlClassificationService = DisasterClassificationService.instance;
  final DetectionHistoryService _historyService = DetectionHistoryService.instance;
  
  bool _isMLModelLoaded = false;
  bool _isMLModelLoading = false;
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
  
  // Recent detections history (loaded from SQLite)
  List<EmergencyDetectionResult> _recentDetections = [];
  
  // Cooldown timer to prevent spam (1 minute)
  static const Duration _cooldownDuration = Duration(minutes: 1);
  DateTime? _lastCaptureTime;
  Timer? _cooldownTimer;
  int _cooldownSecondsRemaining = 0;
  bool get _isOnCooldown => _cooldownSecondsRemaining > 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
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
    
    // Load ML model on initialization
    _loadMLModel();
    
    _initializeCamera();
    
    // Load history from SQLite
    _loadHistory();
  }

  /// Load detection history from SQLite for current user
  Future<void> _loadHistory() async {
    try {
      final detections = await _historyService.getUserDetections(limit: 10);
      if (mounted) {
        setState(() {
          _recentDetections = detections;
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to load history: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flashController.dispose();
    _processingController.dispose();
    _captureButtonController.dispose();
    _cooldownTimer?.cancel();
    _cameraService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    } else if (state == AppLifecycleState.paused) {
      _cameraService.dispose();
    }
  }

  /// Load ML disaster classification model - ENHANCED with proper state management
  Future<void> _loadMLModel() async {
    // Prevent multiple simultaneous loads
    if (_isMLModelLoading || _isMLModelLoaded) {
      debugPrint('⚠️ Model loading already in progress or already loaded');
      return;
    }
    
    if (mounted) {
      setState(() {
        _isMLModelLoading = true;
        _isMLModelLoaded = false; // Reset to ensure clean state
      });
    }
    
    try {
      debugPrint('🔄 Loading ML model directly...');
      debugPrint('⏳ This may take 10-30 seconds for the ~14.5 MB model...');
      
      // Load model with timeout to prevent infinite hanging
      final loaded = await _mlClassificationService.loadModel().timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          debugPrint('❌ TIMEOUT: Model loading exceeded 90 seconds');
          debugPrint('   This usually means:');
          debugPrint('   1. Model file is corrupted in APK');
          debugPrint('   2. Model file was compressed despite noCompress setting');
          debugPrint('   3. Device has insufficient memory');
          return false;
        },
      );
      
      // ALWAYS update state, even on timeout or failure
      if (mounted) {
        setState(() {
          _isMLModelLoaded = loaded && _mlClassificationService.isModelLoaded;
          _isMLModelLoading = false; // CRITICAL: Always set to false to prevent infinite loading
        });
      }
      
      if (loaded && _mlClassificationService.isModelLoaded) {
        debugPrint('✅ ML model loaded successfully');
        debugPrint('   Input shape: ${_mlClassificationService.getDebugInfo()['inputShape']}');
        debugPrint('   Output shape: ${_mlClassificationService.getDebugInfo()['outputShape']}');
        
        // Run verification in background (non-blocking)
        Future.delayed(const Duration(seconds: 1), () async {
          final verificationService = ModelVerificationService.instance;
          final verificationResults = await verificationService.verifyModel();
          debugPrint('📊 Background verification: ${verificationResults['canDetect'] == true ? 'PASSED' : 'FAILED'}');
        });
      } else {
        debugPrint('❌ ML model failed to load');
        final debugInfo = _mlClassificationService.getDebugInfo();
        debugPrint('   Error: ${debugInfo['lastError']}');
        debugPrint('   Model loaded flag: ${_mlClassificationService.isModelLoaded}');
        final mlService = MLModelService.instance;
        debugPrint('   MLModelService error: ${mlService.lastError}');
        debugPrint('   MLModelService loaded: ${mlService.isLoaded}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading ML model: $e');
      debugPrint('   Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isMLModelLoaded = false;
          _isMLModelLoading = false;
        });
      }
    }
  }

  /// Show AI information modal
  void _showAIInfo() {
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
                color: AppColors.backgroundLight,
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
                  // Header
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const Icon(Icons.psychology, color: AppColors.primaryRed, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'AI Disaster Detection',
                          style: AppTypography.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // AI Info content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: AIInfoWidget(
                        isModelLoaded: _isMLModelLoaded,
                      ),
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

  /// Load last capture time from SharedPreferences
  Future<void> _loadLastCaptureTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTime = prefs.getInt('last_emergency_capture_time');
      if (lastTime != null) {
        _lastCaptureTime = DateTime.fromMillisecondsSinceEpoch(lastTime);
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
      setState(() {
        _cooldownSecondsRemaining = 0;
        _lastCaptureTime = null;
      });
      _cooldownTimer?.cancel();
      _saveLastCaptureTime();
    } else {
      final remaining = _cooldownDuration - timeSinceLastCapture;
      setState(() {
        _cooldownSecondsRemaining = remaining.inSeconds;
      });
      
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        
        final now = DateTime.now();
        final timeSinceLastCapture = now.difference(_lastCaptureTime!);
        
        if (timeSinceLastCapture >= _cooldownDuration) {
          timer.cancel();
          setState(() {
            _cooldownSecondsRemaining = 0;
            _lastCaptureTime = null;
          });
          _saveLastCaptureTime();
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
    final hasPermission = await PermissionHelper.requestCameraPermission(context);
    
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission is required'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    
    final initialized = await _cameraService.initializeCamera();
    
    if (mounted) {
      setState(() {
        _isCameraInitialized = initialized;
      });
      
      if (!initialized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to initialize camera'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Handle photo capture
  Future<void> _capturePhoto() async {
    if (_isOnCooldown) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please wait ${_cooldownSecondsRemaining}s'),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    if (!_isCameraInitialized || !_cameraService.isReady) {
      await _initializeCamera();
      if (!_cameraService.isReady) return;
    }
    
    HapticFeedback.mediumImpact();
    
    _lastCaptureTime = DateTime.now();
    await _saveLastCaptureTime();
    _updateCooldownState();

    setState(() {
      _isProcessing = true;
    });

    try {
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
      
      final imagePath = await _cameraService.takePicture();
      
      if (imagePath == null) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to capture photo'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
      
      EmergencyDetectionResult result;
      Map<String, dynamic>? detailedAssessment;

      if (_isMLModelLoaded && _mlClassificationService.isModelLoaded) {
        debugPrint('🔍 Using ML classification');
        result = await _mlClassificationService.classifyDisaster(imagePath);
        detailedAssessment = _mlClassificationService.getDetailedAssessment(
          result.type,
          result.confidence,
        );
      } else {
        debugPrint('🔍 Using fallback detection');
        final preprocessed = await _preprocessingService.preprocessImage(imagePath);
        
        if (preprocessed == null) {
          if (mounted) {
            setState(() {
              _isProcessing = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to process image'),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
        
        result = await _detectionService.detectEmergency(preprocessed, imagePath);
      }

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        // Save to SQLite database FIRST
        try {
          await _historyService.saveDetection(result);
          debugPrint('✅ Detection saved to SQLite: ${result.type.label} at ${result.timestamp}');
        } catch (e) {
          debugPrint('❌ Failed to save detection to database: $e');
        }

        // Reload history from database
        await _loadHistory();

        // Show result modal
        _showDetectionResult(result, detailedAssessment);
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

  void _showDetectionResult(EmergencyDetectionResult result, [Map<String, dynamic>? detailedAssessment]) {
    // Ensure "no emergency" has low severity
    final adjustedResult = result.type == EmergencyType.noEmergency
        ? EmergencyDetectionResult(
            type: result.type,
            severity: SeverityLevel.low, // Force low severity for no emergency
            confidence: result.confidence,
            timestamp: result.timestamp,
            imagePath: result.imagePath,
          )
        : result;
    
    // REMOVED: No longer showing separate dialog for noEmergency
    // Now showing full analysis dialog for ALL results including "No Emergency"
    // This allows users to view analysis and send to chat even for "No Emergency"
    
    final severityColor = _getSeverityColor(adjustedResult.severity);
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm:ss a');
    
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        final screenSize = MediaQuery.of(dialogContext).size;
        final isSmallScreen = screenSize.width < 360;
        final isLargeScreen = screenSize.width > 600;
        
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 8 : (isLargeScreen ? 24 : 16),
            vertical: isSmallScreen ? 8 : 16,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isLargeScreen ? 500 : (isSmallScreen ? double.infinity : 400),
              maxHeight: screenSize.height * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Enhanced Header with Severity Badge
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        severityColor,
                        severityColor.withOpacity(0.85),
                        severityColor.withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: severityColor.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: Text(
                              adjustedResult.type.emoji,
                              style: TextStyle(fontSize: isSmallScreen ? 36 : 48),
                            ),
                          ),
                          SizedBox(width: isSmallScreen ? 16 : 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  adjustedResult.type.label.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 18 : (isLargeScreen ? 26 : 24),
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                // Severity Status Badge
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 10 : 14,
                                    vertical: isSmallScreen ? 4 : 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.5),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.white.withOpacity(0.8),
                                              blurRadius: 6,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: isSmallScreen ? 6 : 8),
                                      Text(
                                        '${adjustedResult.severity.label.toUpperCase()} SEVERITY',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 11 : 13,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Date and Time
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 12 : 16,
                          vertical: isSmallScreen ? 8 : 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: Colors.white.withOpacity(0.9),
                              size: isSmallScreen ? 16 : 18,
                            ),
                            SizedBox(width: isSmallScreen ? 8 : 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dateFormat.format(adjustedResult.timestamp),
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 12 : 14,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    timeFormat.format(adjustedResult.timestamp),
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 11 : 13,
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
                    ],
                  ),
                ),
                
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image preview
                          if (adjustedResult.imagePath != null)
                            Container(
                              height: isSmallScreen ? 150 : (isLargeScreen ? 250 : 200),
                              width: double.infinity,
                              margin: EdgeInsets.only(bottom: isSmallScreen ? 16 : 20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.lightGray, width: 2),
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
                                  File(adjustedResult.imagePath!),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          
                          // AI Assessment Widget (if ML classification was used)
                          // ENHANCED: Show for ALL results including "No Emergency"
                          if (detailedAssessment != null && _isMLModelLoaded) ...[
                            AIAssessmentWidget(
                              result: adjustedResult,
                              detailedAssessment: detailedAssessment,
                            ),
                            SizedBox(height: isSmallScreen ? 16 : 20),
                          ] else if (adjustedResult.type == EmergencyType.noEmergency && _isMLModelLoaded) ...[
                            // Show basic info for "No Emergency" even without detailed assessment
                            Container(
                              padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green, size: 24),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'No emergency detected. Area appears safe.',
                                      style: AppTypography.bodyMedium.copyWith(color: Colors.green.shade700),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 16 : 20),
                          ] else ...[
                            // Fallback UI
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 12 : 16,
                                vertical: isSmallScreen ? 10 : 12,
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
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: severityColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: severityColor.withOpacity(0.5),
                                          blurRadius: 6,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Flexible(
                                    child: Text(
                                      'Severity: ${adjustedResult.severity.label.toUpperCase()}',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 15 : 17,
                                        fontWeight: FontWeight.bold,
                                        color: severityColor,
                                        letterSpacing: 0.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            SizedBox(height: isSmallScreen ? 16 : 20),
                            
                            // Enhanced Confidence Display
                            Container(
                              padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
                              decoration: BoxDecoration(
                                color: AppColors.backgroundLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: severityColor.withOpacity(0.2),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: severityColor.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.analytics_outlined,
                                        size: isSmallScreen ? 20 : 22,
                                        color: severityColor,
                                      ),
                                      SizedBox(width: isSmallScreen ? 8 : 10),
                                      Text(
                                        'Confidence Level',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 14 : 16,
                                          color: AppColors.darkGray,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        adjustedResult.getConfidenceString(),
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 16 : 18,
                                          color: severityColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: AppColors.lightGray.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Stack(
                                        children: [
                                          Container(width: double.infinity),
                                          FractionallySizedBox(
                                            widthFactor: adjustedResult.confidence,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    severityColor,
                                                    severityColor.withOpacity(0.8),
                                                    severityColor.withOpacity(0.6),
                                                  ],
                                                ),
                                                borderRadius: BorderRadius.circular(10),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: severityColor.withOpacity(0.4),
                                                    blurRadius: 8,
                                                    spreadRadius: 1,
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
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Actions
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
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
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _reportFalsePositive(result);
                          },
                          icon: Icon(Icons.close, size: isSmallScreen ? 16 : 18),
                          label: const Text('Not an Emergency'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.mediumGray,
                            padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 10 : 12),
                          ),
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 6 : 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            _sendToChat(result);
                          },
                          icon: Icon(Icons.send, size: isSmallScreen ? 16 : 18),
                          label: Text(
                            adjustedResult.type == EmergencyType.noEmergency ? 'Send to Chat' : 'Send Alert',
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallScreen ? 13 : 14,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryRed,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 12 : 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showNoEmergencyDialog(EmergencyDetectionResult result) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No Emergency Detected',
                style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'The area appears safe. No emergency situation was detected.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendToChat(EmergencyDetectionResult result) async {
    try {
      // Navigate to chat screen and send message
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      
      // Create emergency message - REMOVED confidence, ENHANCED with severity-based styling
      // ENHANCED: Ensure "No Emergency" always has low severity for green color
      final adjustedSeverity = result.type == EmergencyType.noEmergency 
          ? SeverityLevel.low 
          : result.severity;
      
      final message = result.type == EmergencyType.noEmergency
          ? '✅ NO EMERGENCY DETECTED\n'
              'Status: Area appears safe\n'
              'Time: ${DateFormat('MMM dd, yyyy hh:mm:ss a').format(result.timestamp)}'
          : '🚨 ${result.type.emoji} ${result.type.label.toUpperCase()} DETECTED\n'
              'Severity: ${result.severity.label.toUpperCase()}\n'
              'Time: ${DateFormat('MMM dd, yyyy hh:mm:ss a').format(result.timestamp)}';
      
      // Send message via chat provider with severity level for unique UI styling
      // CRITICAL: Use adjustedSeverity to ensure "No Emergency" shows green (low severity)
      final success = await chatProvider.sendMessage(
        message, 
        context: context,
        severityLevel: adjustedSeverity,  // Use adjusted severity (low for no emergency)
        emergencyType: result.type,
      );
      
      if (mounted) {
        if (success) {
          // Navigate to chat screen
          Navigator.of(context).pushNamed('/chat');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Emergency alert sent to chat',
                      style: AppTypography.bodyMedium.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Failed to send. Please connect to a device first.',
                      style: AppTypography.bodyMedium.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error sending to chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _reportFalsePositive(EmergencyDetectionResult result) {
    // TODO: Store false positive feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Reported as false positive. Thank you for the feedback.',
                style: AppTypography.bodyMedium.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.info,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show full history modal
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
                color: AppColors.backgroundLight,
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
                  // Drag handle
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
                  // Header
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
                  // History list
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
                                    color: AppColors.backgroundLight,
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
                                                  '${detection.getConfidenceString()}',
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

  /// Show detection details
  void _showDetectionDetails(EmergencyDetectionResult detection) {
    // Get detailed assessment if available
    Map<String, dynamic>? detailedAssessment;
    if (_isMLModelLoaded && _mlClassificationService.isModelLoaded) {
      detailedAssessment = _mlClassificationService.getDetailedAssessment(
        detection.type,
        detection.confidence,
      );
    }
    
    _showDetectionResult(detection, detailedAssessment);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text('Emergency Detection', style: AppTypography.titleLarge),
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'AI Information',
            onPressed: () => _showAIInfo(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Camera preview - Fixed aspect ratio to prevent cut-off
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: SoftUIDesign.cardDecoration(
                  backgroundColor: Colors.black,
                  borderRadius: SoftUIDesign.cardBorderRadius,
                  elevation: 6.0,
                  showBorder: true,
                  borderColor: AppColors.primaryRed.withOpacity(0.3),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(SoftUIDesign.cardBorderRadius - 2),
                  child: Stack(
                    children: [
                      // Camera preview with proper aspect ratio
                      _isCameraInitialized && _cameraService.isReady
                          ? LayoutBuilder(
                              builder: (context, constraints) {
                                // Get camera aspect ratio to prevent cut-off
                                final camera = _cameraService.controller!;
                                final cameraAspectRatio = camera.value.aspectRatio;
                                
                                return Center(
                                  child: AspectRatio(
                                    aspectRatio: cameraAspectRatio,
                                    child: CameraPreview(camera),
                                  ),
                                );
                              },
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Colors.black87, Colors.black54],
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
                                      _isCameraInitialized ? 'Camera not ready' : 'Initializing camera...',
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
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                      
                      // Camera overlay
                      if (_isCameraInitialized && _cameraService.isReady && !_isProcessing)
                        Positioned(
                          top: 16,
                          left: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: AppColors.primaryRed.withOpacity(0.4),
                                width: 1.5,
                              ),
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
                                    color: AppColors.primaryRed,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Point camera at emergency scene',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      // Flash overlay
                      if (_showFlash)
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _flashController,
                            builder: (context, child) {
                              return Container(
                                color: Colors.white.withOpacity(_flashController.value * 0.8),
                              );
                            },
                          ),
                        ),
                      
                      // Processing overlay
                      if (_isProcessing)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withOpacity(0.7),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedBuilder(
                                    animation: _processingAnimation,
                                    builder: (context, child) {
                                      return CircularProgressIndicator(
                                        value: _processingAnimation.value,
                                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryRed),
                                        strokeWidth: 4,
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    'Analyzing...',
                                    style: AppTypography.bodyLarge.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
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
            ),
            
            // Capture button and cooldown
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  if (_isOnCooldown)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timer, color: AppColors.warning, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Wait ${_cooldownSecondsRemaining}s',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    AnimatedBuilder(
                      animation: _captureButtonScale,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _captureButtonScale.value,
                          child: GestureDetector(
                            onTapDown: (_) {
                              _captureButtonController.forward();
                            },
                            onTapUp: (_) {
                              _captureButtonController.reverse();
                              _capturePhoto();
                            },
                            onTapCancel: () {
                              _captureButtonController.reverse();
                            },
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primaryRed,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryRed.withOpacity(0.4),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
            
            // Enhanced History Section - ACCESSIBLE
            Container(
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
                          onTap: () => _showFullHistoryModal(),
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
                        color: AppColors.backgroundLight,
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
                    Container(
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
                                color: AppColors.backgroundLight,
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
          ],
        ),
      ),
    );
  }
}
