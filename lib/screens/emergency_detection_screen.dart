import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../constants/storage_keys.dart';
import '../constants/severity_colors.dart';
import '../constants/app_typography.dart';
import '../utils/theme_colors.dart';
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
  /// User-controlled flash: when true, flash fires on capture (device + overlay).
  bool _flashOnCapture = false;
  
  // Animation controllers
  late AnimationController _flashController;
  late AnimationController _processingController;
  late AnimationController _captureButtonController;
  late Animation<double> _processingAnimation;
  late Animation<double> _captureButtonScale;
  late Animation<double> _captureButtonGlow;
  
  // Recent detections history (loaded from SQLite)
  List<EmergencyDetectionResult> _recentDetections = [];
  int _newDetectionsCount = 0;
  
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

  /// Load detection history from SQLite for current user and update new-count badge
  Future<void> _loadHistory() async {
    try {
      final detections = await _historyService.getUserDetections(limit: 10);
      final prefs = await SharedPreferences.getInstance();
      final lastSeenMs = prefs.getInt('detection_history_last_seen_ms');
      final lastSeen = lastSeenMs != null ? DateTime.fromMillisecondsSinceEpoch(lastSeenMs) : null;
      int newCount = 0;
      if (lastSeen != null && detections.isNotEmpty) {
        newCount = detections.where((d) => d.timestamp.isAfter(lastSeen)).length;
      } else if (lastSeen == null && detections.isNotEmpty) {
        newCount = detections.length;
      }
      if (mounted) {
        setState(() {
          _recentDetections = detections;
          _newDetectionsCount = newCount;
        });
      }
    } catch (e) {
      debugPrint('❌ Failed to load history: $e');
    }
  }

  /// Mark detection history as seen (clear badge)
  Future<void> _markHistoryAsSeen() async {
    if (_recentDetections.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final latest = _recentDetections.first.timestamp;
    await prefs.setInt('detection_history_last_seen_ms', latest.millisecondsSinceEpoch);
    if (mounted) setState(() => _newDetectionsCount = 0);
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
      _updateCooldownState();
    } else if (state == AppLifecycleState.paused) {
      _cameraService.dispose();
    }
  }

  /// Step 1: Load ML model (or use already-loaded from app init). Step 2: classification uses it when ready.
  Future<void> _loadMLModel() async {
    // If already loaded (e.g. by app init preload), just sync state
    if (_mlClassificationService.isModelLoaded) {
      if (mounted && !_isMLModelLoaded) {
        setState(() {
          _isMLModelLoaded = true;
          _isMLModelLoading = false;
        });
      }
      debugPrint('✅ ML model already loaded (ready for detection)');
      return;
    }
    if (_isMLModelLoading) {
      debugPrint('⚠️ Model load already in progress');
      return;
    }

    if (mounted) {
      setState(() {
        _isMLModelLoading = true;
        _isMLModelLoaded = false;
      });
    }

    try {
      debugPrint('🔄 Loading ML model (first load or retry)...');

      // Single load path: MLModelService enforces one load at a time; others wait
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
          initialChildSize: 0.72,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: ThemeColors.background(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: ThemeColors.shadow(context, opacity: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag handle
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: ThemeColors.textTertiary(context).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 12, 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ThemeColors.primary(context).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: ThemeColors.primary(context).withOpacity(0.25),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.psychology_rounded,
                            color: ThemeColors.primary(context),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI Disaster Detection',
                                style: AppTypography.titleLarge.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: ThemeColors.textPrimary(context),
                                  fontSize: 18,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'How the model works',
                                style: AppTypography.bodySmall.copyWith(
                                  color: ThemeColors.textTertiary(context),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: ThemeColors.surfaceContainer(context),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: ThemeColors.border(context)),
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: ThemeColors.textPrimary(context),
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, thickness: 1, color: ThemeColors.divider(context)),
                  // AI Info content
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
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
      // Only show flash overlay and use device flash when user has enabled it
      if (_flashOnCapture) {
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
        await _cameraService.setFlashMode(FlashMode.always);
      } else {
        await _cameraService.setFlashMode(FlashMode.off);
      }
      
      final imagePath = await _cameraService.takePicture();
      
      // Restore flash mode to user preference after capture
      if (mounted) {
        await _cameraService.setFlashMode(_flashOnCapture ? FlashMode.always : FlashMode.off);
      }
      
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

      // Use ML only when model is loaded (integrate after load)
      final bool useML = _isMLModelLoaded && _mlClassificationService.isModelLoaded;
      if (useML) {
        debugPrint('🔍 Running ML classification (model loaded)');
        result = await _mlClassificationService.classifyDisaster(imagePath);
        detailedAssessment = _mlClassificationService.getDetailedAssessment(
          result.type,
          result.confidence,
        );
      } else {
        debugPrint('🔍 Model not ready; using rule-based fallback');
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

  void _showDetectionResult(EmergencyDetectionResult result, [Map<String, dynamic>? detailedAssessment]) {
    // Ensure "no emergency" has low severity; preserve failureReason (e.g. image too dark)
    final adjustedResult = result.type == EmergencyType.noEmergency
        ? EmergencyDetectionResult(
            type: result.type,
            severity: SeverityLevel.low, // Force low severity for no emergency
            confidence: result.confidence,
            timestamp: result.timestamp,
            imagePath: result.imagePath,
            failureReason: result.failureReason,
            probabilityBreakdown: result.probabilityBreakdown,
          )
        : result;
    
    // REMOVED: No longer showing separate dialog for noEmergency
    // Now showing full analysis dialog for ALL results including "No Emergency"
    // This allows users to view analysis and send to chat even for "No Emergency"
    
    final typeColor = DisasterTypeColors.color(adjustedResult.type);
    final severityColor = SeverityColors.color(adjustedResult.severity);
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm:ss a');
    
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        // One-time tip: Re-analyze (QoL6)
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final prefs = await SharedPreferences.getInstance();
          if (prefs.getBool(StorageKeys.emergencyTipReanalyzeShown) == true) return;
          await prefs.setBool(StorageKeys.emergencyTipReanalyzeShown, true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Tip: Use Re-analyze to run the AI again on the same photo.'),
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        });
        final screenSize = MediaQuery.of(dialogContext).size;
        final isSmallScreen = screenSize.width < 360;
        final isLargeScreen = screenSize.width > 600;
        // B.4: Radius convention – dialog 24, cards 20, inner 12–14, buttons 14
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 12 : (isLargeScreen ? 24 : 16),
            vertical: isSmallScreen ? 16 : 28,
          ),
          elevation: 8,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isLargeScreen ? 560 : (screenSize.width * 0.94).clamp(320.0, 520.0),
              maxHeight: screenSize.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: ThemeColors.surface(dialogContext),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: ThemeColors.shadow(dialogContext, opacity: 0.2),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with disaster-type color; red accent when real emergency so urgency is clear
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 18 : 22,
                    vertical: isSmallScreen ? 16 : 20,
                  ),
                  decoration: BoxDecoration(
                    color: typeColor,
                    border: adjustedResult.type.isRealEmergency
                        ? Border(
                            top: BorderSide(
                              color: SeverityColors.critical,
                              width: 4,
                            ),
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: typeColor.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                      if (adjustedResult.type.isRealEmergency)
                        BoxShadow(
                          color: SeverityColors.critical.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (adjustedResult.type.isRealEmergency) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.white, size: isSmallScreen ? 14 : 16),
                            const SizedBox(width: 6),
                            Text(
                              'Action required',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 11 : 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 8 : 10),
                      ],
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.35),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              adjustedResult.type.icon,
                              size: isSmallScreen ? 34 : 44,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: isSmallScreen ? 14 : 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  adjustedResult.type.label,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 17 : (isLargeScreen ? 22 : 20),
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                    height: 1.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 10 : 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.22),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.4),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      SizedBox(width: isSmallScreen ? 6 : 8),
                                      Text(
                                        '${adjustedResult.severity.label} severity',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 10 : 12,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Close button (upper right)
                          Semantics(
                            button: true,
                            label: 'Close',
                            child: IconButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              icon: const Icon(Icons.close_rounded),
                              color: Colors.white,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withOpacity(0.2),
                                padding: const EdgeInsets.all(8),
                                minimumSize: const Size(48, 48),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 12 : 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              color: Colors.white.withOpacity(0.95),
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
                                      fontSize: isSmallScreen ? 12 : 13,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    timeFormat.format(adjustedResult.timestamp),
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 11 : 12,
                                      color: Colors.white.withOpacity(0.88),
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
                
                // Content - theme-aware surface so info pops
                Flexible(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      color: ThemeColors.surface(dialogContext),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          isSmallScreen ? 16 : 20,
                          isSmallScreen ? 16 : 20,
                          isSmallScreen ? 16 : 20,
                          isSmallScreen ? 32 : 40,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          // Image preview - frame that pops in light and dark
                          if (adjustedResult.imagePath != null)
                            Container(
                              height: isSmallScreen ? 150 : (isLargeScreen ? 250 : 200),
                              width: double.infinity,
                              margin: EdgeInsets.only(bottom: isSmallScreen ? 16 : 20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: ThemeColors.border(dialogContext),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: ThemeColors.shadow(dialogContext, opacity: ThemeColors.isDark(dialogContext) ? 0.4 : 0.12),
                                    blurRadius: ThemeColors.isDark(dialogContext) ? 12 : 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
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
                            // Show message: either "No emergency" or preprocess failure (e.g. image too dark)
                            Container(
                              padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
                              decoration: BoxDecoration(
                                color: adjustedResult.isPreprocessFailure
                                    ? ThemeColors.textTertiary(dialogContext).withOpacity(ThemeColors.isDark(dialogContext) ? 0.2 : 0.12)
                                    : ThemeColors.success(dialogContext).withOpacity(ThemeColors.isDark(dialogContext) ? 0.2 : 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: adjustedResult.isPreprocessFailure
                                      ? ThemeColors.textTertiary(dialogContext).withOpacity(0.4)
                                      : ThemeColors.success(dialogContext).withOpacity(ThemeColors.isDark(dialogContext) ? 0.5 : 0.35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    adjustedResult.isPreprocessFailure ? Icons.info_outline_rounded : Icons.check_circle,
                                    color: adjustedResult.isPreprocessFailure ? ThemeColors.textSecondary(dialogContext) : ThemeColors.success(dialogContext),
                                    size: 24,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      adjustedResult.failureReason ?? 'No emergency detected. Area appears safe.',
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: ThemeColors.textPrimary(dialogContext),
                                        fontWeight: FontWeight.w500,
                                      ),
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
                            
                            // Confidence Display
                            Container(
                              padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
                              decoration: BoxDecoration(
                                color: ThemeColors.surfaceContainer(dialogContext),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: severityColor.withOpacity(0.25),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: ThemeColors.shadow(dialogContext, opacity: 0.06),
                                    blurRadius: 10,
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
                                          color: ThemeColors.textPrimary(dialogContext),
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
                                        color: ThemeColors.textTertiary(dialogContext).withOpacity(0.4),
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
                          // Detection tips (A.3)
                          Padding(
                            padding: EdgeInsets.only(top: isSmallScreen ? 12 : 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'For better results:',
                                  style: AppTypography.labelLarge.copyWith(
                                    color: ThemeColors.textSecondary(dialogContext),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.light_mode_outlined, size: 18, color: ThemeColors.textTertiary(dialogContext)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Good lighting',
                                        style: AppTypography.bodySmall.copyWith(color: ThemeColors.textSecondary(dialogContext)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.camera_alt_outlined, size: 18, color: ThemeColors.textTertiary(dialogContext)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Include the hazard in frame',
                                        style: AppTypography.bodySmall.copyWith(color: ThemeColors.textSecondary(dialogContext)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.blur_off_outlined, size: 18, color: ThemeColors.textTertiary(dialogContext)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Avoid blur',
                                        style: AppTypography.bodySmall.copyWith(color: ThemeColors.textSecondary(dialogContext)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 12 : 16),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'This is an AI estimate. Use your judgment and report to authorities when needed.',
                              style: AppTypography.bodySmall.copyWith(
                                color: ThemeColors.textTertiary(dialogContext),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                          // Local feedback: Was this correct? (A.5)
                          StatefulBuilder(
                            builder: (context, setDialogState) {
                              return FutureBuilder<bool>(
                                future: _historyService.hasFeedbackForDetection(
                                  imagePath: adjustedResult.imagePath,
                                  timestamp: adjustedResult.timestamp,
                                ),
                                builder: (context, snapshot) {
                                  final alreadySent = snapshot.data == true;
                                  if (alreadySent) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                                      child: Text(
                                        'Thanks for your feedback.',
                                        style: AppTypography.bodySmall.copyWith(
                                          color: ThemeColors.textTertiary(dialogContext),
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    );
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Was this assessment correct?',
                                          style: AppTypography.bodySmall.copyWith(
                                            color: ThemeColors.textSecondary(dialogContext),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            TextButton.icon(
                                              onPressed: () async {
                                                await _historyService.saveDetectionFeedback(
                                                  imagePath: adjustedResult.imagePath,
                                                  timestamp: adjustedResult.timestamp,
                                                  correct: true,
                                                );
                                                setDialogState(() {});
                                              },
                                              icon: Icon(Icons.thumb_up_outlined, size: 18, color: ThemeColors.success(dialogContext)),
                                              label: Text('Yes', style: TextStyle(color: ThemeColors.success(dialogContext), fontWeight: FontWeight.w600)),
                                            ),
                                            const SizedBox(width: 8),
                                            TextButton.icon(
                                              onPressed: () async {
                                                await _historyService.saveDetectionFeedback(
                                                  imagePath: adjustedResult.imagePath,
                                                  timestamp: adjustedResult.timestamp,
                                                  correct: false,
                                                );
                                                setDialogState(() {});
                                              },
                                              icon: Icon(Icons.thumb_down_outlined, size: 18, color: ThemeColors.error(dialogContext)),
                                              label: Text('No', style: TextStyle(color: ThemeColors.error(dialogContext), fontWeight: FontWeight.w600)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Actions - Not an Emergency, Re-analyze (when ML + image), Send/Try Again
                Container(
                  padding: EdgeInsets.fromLTRB(isSmallScreen ? 12 : 16, 12, isSmallScreen ? 12 : 16, isSmallScreen ? 16 : 20),
                  decoration: BoxDecoration(
                    color: ThemeColors.surfaceContainer(dialogContext),
                    border: Border(
                      top: BorderSide(color: ThemeColors.divider(dialogContext), width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              _confirmReportFalsePositive(result);
                            },
                            icon: Icon(Icons.close_rounded, size: isSmallScreen ? 16 : 18),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Not an Emergency',
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: isSmallScreen ? 11 : 13,
                                  color: ThemeColors.textPrimary(dialogContext),
                                ),
                                maxLines: 1,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: ThemeColors.textPrimary(dialogContext),
                              side: BorderSide(color: ThemeColors.border(dialogContext)),
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ),
                      if (adjustedResult.imagePath != null && _isMLModelLoaded) ...[
                        SizedBox(width: isSmallScreen ? 6 : 8),
                        SizedBox(
                          height: 48,
                          child: TextButton.icon(
                            onPressed: () async {
                              Navigator.pop(dialogContext);
                              if (adjustedResult.imagePath == null || !_isMLModelLoaded || !mounted) return;
                              setState(() => _isProcessing = true);
                              try {
                                final newResult = await _mlClassificationService.classifyDisaster(adjustedResult.imagePath!);
                                final newAssessment = _mlClassificationService.getDetailedAssessment(newResult.type, newResult.confidence);
                                if (!mounted) return;
                                await _historyService.saveDetection(newResult);
                                await _loadHistory();
                                _showDetectionResult(newResult, newAssessment);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Analysis updated.'),
                                      backgroundColor: AppColors.success,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _isProcessing = false);
                              }
                            },
                            icon: Icon(Icons.refresh_rounded, size: 16, color: ThemeColors.primary(dialogContext)),
                            label: Text(
                              'Re-analyze',
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: isSmallScreen ? 11 : 12,
                                color: ThemeColors.primary(dialogContext),
                              ),
                            ),
                          ),
                        ),
                      ],
                      SizedBox(width: isSmallScreen ? 6 : 8),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              if (!adjustedResult.isPreprocessFailure) _sendToChat(result);
                            },
                            icon: Icon(adjustedResult.isPreprocessFailure ? Icons.refresh_rounded : Icons.send_rounded, size: isSmallScreen ? 16 : 18),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                adjustedResult.isPreprocessFailure ? 'Try Again' : (adjustedResult.type == EmergencyType.noEmergency ? 'Send to Chat' : 'Send Alert'),
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: isSmallScreen ? 11 : 13,
                                ),
                                maxLines: 1,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: typeColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: adjustedResult.type.isRealEmergency ? 2 : 0,
                              side: adjustedResult.type.isRealEmergency
                                  ? BorderSide(color: SeverityColors.critical, width: 2)
                                  : null,
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
        );
      },
    );
  }

  void _showNoEmergencyDialog(EmergencyDetectionResult result) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: ThemeColors.success(dialogContext), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No Emergency Detected',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ThemeColors.textPrimary(dialogContext),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'The area appears safe. No emergency situation was detected.',
          style: AppTypography.bodyMedium.copyWith(color: ThemeColors.textSecondary(dialogContext)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: ThemeColors.primary(dialogContext))),
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
      
      // Message must include "Severity: X" so receivers can parse consistently (EmergencyMessageParser)
      final message = result.type == EmergencyType.noEmergency
          ? 'NO EMERGENCY DETECTED\n'
              'Severity: Low\n'
              'Status: Area appears safe\n'
              'Time: ${DateFormat('MMM dd, yyyy hh:mm:ss a').format(result.timestamp)}'
          : '${result.type.label.toUpperCase()} DETECTED\n'
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
          final message = result.type == EmergencyType.noEmergency ? 'Sent to chat' : 'Emergency alert sent to chat';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message,
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

  void _confirmReportFalsePositive(EmergencyDetectionResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report as not an emergency?'),
        content: Text(
          'This will mark the detection as a false positive. You can still find it in history.',
          style: AppTypography.bodyMedium.copyWith(color: ThemeColors.textSecondary(ctx)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: ThemeColors.primary(ctx))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _reportFalsePositive(result);
            },
            child: Text('Report', style: TextStyle(color: ThemeColors.primary(ctx), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
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
          initialChildSize: 0.72,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: ThemeColors.background(context),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: ThemeColors.shadow(context, opacity: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag handle
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: ThemeColors.textTertiary(context).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: ThemeColors.primary(context).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: ThemeColors.primary(context).withOpacity(0.25),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.history_rounded,
                            color: ThemeColors.primary(context),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Detection History',
                                style: AppTypography.titleLarge.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: ThemeColors.textPrimary(context),
                                  fontSize: 18,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_recentDetections.length} recent ${_recentDetections.length == 1 ? 'detection' : 'detections'}',
                                style: AppTypography.bodySmall.copyWith(
                                  color: ThemeColors.textTertiary(context),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: ThemeColors.primary(context).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: ThemeColors.primary(context).withOpacity(0.25),
                            ),
                          ),
                          child: Text(
                            '${_recentDetections.length}',
                            style: AppTypography.labelLarge.copyWith(
                              color: ThemeColors.primary(context),
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, thickness: 1, color: ThemeColors.divider(context)),
                  // History list with pull-to-refresh
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async { await _loadHistory(); },
                      child: _recentDetections.isEmpty
                          ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: SizedBox(
                                height: 280,
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      'No detection history yet.\nYour captures will appear here.',
                                      textAlign: TextAlign.center,
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: ThemeColors.textTertiary(context),
                                        height: 1.45,
                                      ),
                                    ),
                                  ),
                                ),
                            ),
                          )
                          : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            itemCount: _recentDetections.length,
                            itemBuilder: (context, index) {
                              final detection = _recentDetections[index];
                              final severityColor = SeverityColors.color(detection.severity);
                              final dateFormat = DateFormat('MMM dd, yyyy');
                              final timeFormat = DateFormat('hh:mm a');
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.pop(context);
                                      _showDetectionDetails(detection);
                                    },
                                    borderRadius: BorderRadius.circular(18),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: ThemeColors.surfaceContainer(context),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: severityColor.withOpacity(0.3),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: ThemeColors.shadow(context, opacity: 0.06),
                                            blurRadius: 10,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: severityColor.withOpacity(0.14),
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(
                                                color: severityColor.withOpacity(0.25),
                                                width: 1,
                                              ),
                                            ),
                                            child: Icon(
                                              detection.type.icon,
                                              size: 28,
                                              color: severityColor,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  detection.type.label,
                                                  style: AppTypography.bodyLarge.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    color: ThemeColors.textPrimary(context),
                                                    letterSpacing: 0.1,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    Container(
                                                      width: 8,
                                                      height: 8,
                                                      decoration: BoxDecoration(
                                                        color: severityColor,
                                                        shape: BoxShape.circle,
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: severityColor.withOpacity(0.4),
                                                            blurRadius: 4,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      detection.severity.label,
                                                      style: AppTypography.bodySmall.copyWith(
                                                        color: severityColor,
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      detection.getConfidenceString(),
                                                      style: AppTypography.bodySmall.copyWith(
                                                        color: ThemeColors.textTertiary(context),
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.schedule_rounded,
                                                      size: 14,
                                                      color: ThemeColors.textTertiary(context),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${dateFormat.format(detection.timestamp)} · ${timeFormat.format(detection.timestamp)}',
                                                      style: AppTypography.captionText.copyWith(
                                                        color: ThemeColors.textTertiary(context),
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right_rounded,
                                            color: ThemeColors.textTertiary(context),
                                            size: 22,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
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

  /// Show detection details (from history or recent list). Uses stored breakdown so we never show wrong probabilities.
  void _showDetectionDetails(EmergencyDetectionResult detection) {
    final detailedAssessment = <String, dynamic>{
      'type': detection.type.label,
      'confidence': detection.confidence,
      'confidencePercent': (detection.confidence * 100).toStringAsFixed(1),
      'riskMessage': _mlClassificationService.getRiskAssessmentMessage(detection.type, detection.confidence),
      'timestamp': detection.timestamp.toIso8601String(),
      'probabilityBreakdown': detection.probabilityBreakdown,
    };
    _showDetectionResult(detection, detailedAssessment);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ThemeColors.background(context),
              ThemeColors.background(context),
              ThemeColors.surfaceContainer(context).withOpacity(0.4),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Unified Top Bar
              UnifiedTopBar(
              title: 'Emergency Detection',
              subtitle: _isMLModelLoading
                  ? 'Loading model...'
                  : _isMLModelLoaded
                      ? 'Ready'
                      : null,
              icon: Icons.emergency_rounded,
              iconColor: ThemeColors.primary(context),
              showBackButton: false,
              actions: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showAIInfo(),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: ThemeColors.primary(context).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: ThemeColors.primary(context).withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.info_outline_rounded,
                        color: ThemeColors.primary(context),
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Camera preview - Fixed aspect ratio to prevent cut-off
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: ThemeColors.primary(context).withOpacity(0.4),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ThemeColors.shadow(context, opacity: 0.14),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: ThemeColors.primary(context).withOpacity(0.1),
                      blurRadius: 28,
                      offset: const Offset(0, 8),
                      spreadRadius: -6,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
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
                                        CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(ThemeColors.primary(context)),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: ThemeColors.primary(context).withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.camera_alt,
                                          size: 64,
                                          color: ThemeColors.primary(context),
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
                                            backgroundColor: ThemeColors.primary(context),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                      
                      // Dynamic AI Detection badge (top)
                      if (_isCameraInitialized && _cameraService.isReady && !_isProcessing && _isMLModelLoaded)
                        Positioned(
                          top: 12,
                          left: 12,
                          right: 12,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: ThemeColors.primary(context).withOpacity(0.92),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.psychology_rounded, size: 16, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    'AI Detection Active',
                                    style: AppTypography.labelMedium.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      // Point camera hint (bottom of viewfinder)
                      if (_isCameraInitialized && _cameraService.isReady && !_isProcessing)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 12,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.center_focus_strong_rounded, size: 16, color: Colors.white.withOpacity(0.9)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Point at emergency scene',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: Colors.white.withOpacity(0.95),
                                      fontWeight: FontWeight.w500,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
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
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: AnimatedBuilder(
                                      animation: _processingAnimation,
                                      builder: (context, child) {
                                        return CircularProgressIndicator(
                                          value: _processingAnimation.value,
                                          valueColor: AlwaysStoppedAnimation<Color>(ThemeColors.primary(context)),
                                          strokeWidth: 3,
                                          backgroundColor: ThemeColors.primary(context).withOpacity(0.2),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Analyzing image…',
                                    style: AppTypography.bodyLarge.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'AI is assessing the scene',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
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
            
            // Capture controls and cooldown
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: _isOnCooldown
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: ThemeColors.warning(context).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: ThemeColors.warning(context).withOpacity(0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.timer_outlined, color: ThemeColors.warning(context), size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Wait ${_cooldownSecondsRemaining}s before next capture',
                            style: AppTypography.bodyMedium.copyWith(
                              color: ThemeColors.warning(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: ThemeColors.surfaceContainer(context),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: ThemeColors.border(context), width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: ThemeColors.shadow(context, opacity: 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Flash toggle
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () async {
                                setState(() => _flashOnCapture = !_flashOnCapture);
                                if (_cameraService.isReady) {
                                  await _cameraService.setFlashMode(
                                    _flashOnCapture ? FlashMode.always : FlashMode.off,
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: ThemeColors.background(context),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _flashOnCapture
                                        ? ThemeColors.primary(context).withOpacity(0.4)
                                        : ThemeColors.border(context),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _flashOnCapture ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                                      size: 20,
                                      color: _flashOnCapture
                                          ? ThemeColors.primary(context)
                                          : ThemeColors.textTertiary(context),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Flash on capture',
                                      style: AppTypography.labelLarge.copyWith(
                                        color: ThemeColors.textPrimary(context),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Switch.adaptive(
                                      value: _flashOnCapture,
                                      onChanged: (bool value) async {
                                        setState(() => _flashOnCapture = value);
                                        if (_cameraService.isReady) {
                                          await _cameraService.setFlashMode(
                                            value ? FlashMode.always : FlashMode.off,
                                          );
                                        }
                                      },
                                      activeColor: ThemeColors.primary(context),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Capture button with label
                          AnimatedBuilder(
                            animation: _captureButtonScale,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _captureButtonScale.value,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTapDown: (_) => _captureButtonController.forward(),
                                      onTapUp: (_) {
                                        _captureButtonController.reverse();
                                        _capturePhoto();
                                      },
                                      onTapCancel: () => _captureButtonController.reverse(),
                                      child: Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: ThemeColors.primary(context),
                                          border: Border.all(
                                            color: Colors.white.withOpacity(0.3),
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: ThemeColors.primary(context).withOpacity(0.4),
                                              blurRadius: 18,
                                              spreadRadius: 1,
                                              offset: const Offset(0, 4),
                                            ),
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.2),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt_rounded,
                                          color: Colors.white,
                                          size: 26,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Capture & Analyze',
                                      style: AppTypography.labelMedium.copyWith(
                                        color: ThemeColors.textSecondary(context),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
            ),
            
            // Spacing between capture card and Detection History
            const SizedBox(height: 12),
            // Detection History Section – tap anywhere to open View All (no scrollable list)
            Expanded(
              flex: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 100),
                child: GestureDetector(
                  onTap: () {
                    _markHistoryAsSeen();
                    _showFullHistoryModal();
                  },
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    decoration: BoxDecoration(
                      color: ThemeColors.surfaceContainer(context),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: ThemeColors.border(context), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: ThemeColors.shadow(context, opacity: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: ThemeColors.primary(context).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: ThemeColors.primary(context).withOpacity(0.25),
                                    width: 1,
                                  ),
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Icon(
                                      Icons.history_rounded,
                                      color: ThemeColors.primary(context),
                                      size: 16,
                                    ),
                                    if (_newDetectionsCount > 0)
                                      Positioned(
                                        top: -5,
                                        right: -5,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: ThemeColors.primary(context),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: ThemeColors.surfaceContainer(context), width: 1),
                                          ),
                                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                          alignment: Alignment.center,
                                          child: Text(
                                            _newDetectionsCount > 99 ? '99+' : '$_newDetectionsCount',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Detection History',
                                        style: AppTypography.bodyLarge.copyWith(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: ThemeColors.textPrimary(context),
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Tap to view all',
                                        style: AppTypography.captionText.copyWith(
                                          color: ThemeColors.textTertiary(context),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: ThemeColors.primary(context).withOpacity(ThemeColors.isDark(context) ? 0.2 : 0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: ThemeColors.primary(context).withOpacity(0.35),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'View All',
                                      style: AppTypography.labelMedium.copyWith(
                                        color: ThemeColors.primary(context),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 10,
                                      color: ThemeColors.primary(context),
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
