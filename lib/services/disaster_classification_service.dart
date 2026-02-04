import 'dart:io';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../models/emergency_type.dart';
import '../models/emergency_detection_result.dart';
import 'ml_model_service.dart';
import 'image_preprocessing_service.dart';

/// Service for ML-based disaster classification
/// Uses TensorFlow Lite model trained on PyImageSearch natural disaster dataset
/// Classifies images into: Flood, Wildfire, Earthquake, Cyclone
class DisasterClassificationService {
  static DisasterClassificationService? _instance;
  static DisasterClassificationService get instance =>
      _instance ??= DisasterClassificationService._();

  DisasterClassificationService._();

  final MLModelService _mlService = MLModelService.instance;
  final ImagePreprocessingService _preprocessingService = ImagePreprocessingService();

  // Model labels in order (as per PyImageSearch model output)
  // Class Mapping: 0=Cyclone, 1=Earthquake, 2=Flood, 3=Wildfire
  static const List<String> _modelLabels = [
    'Cyclone',    // Index 0
    'Earthquake', // Index 1
    'Flood',      // Index 2
    'Wildfire',   // Index 3
  ];

  // Confidence threshold below which we consider the prediction uncertain
  static const double _minConfidenceThreshold = 0.3;

  // Debugging and status tracking
  int _inferenceCount = 0;
  DateTime? _modelLoadTime;
  String? _lastClassificationLabel;
  List<double>? _lastAllProbabilities;
  String? _lastImageHash;
  DateTime? _lastInferenceTime;
  String? _lastError;

  /// Get debugging information for UI display
  Map<String, dynamic> getDebugInfo() {
    return {
      'isModelLoaded': isModelLoaded,
      'modelLoadTime': _modelLoadTime?.toIso8601String(),
      'inferenceCount': _inferenceCount,
      'lastInferenceTime': _lastInferenceTime?.toIso8601String(),
      'lastImageHash': _lastImageHash?.substring(0, 16),
      'lastClassification': _lastClassificationLabel,
      'lastProbabilities': _lastAllProbabilities,
      'lastError': _lastError,
      'inputShape': _mlService.inputShape?.toString(),
      'outputShape': _mlService.outputShape?.toString(),
    };
  }

  /// Get inference count
  int get inferenceCount => _inferenceCount;

  /// Get last inference time
  DateTime? get lastInferenceTime => _lastInferenceTime;

  /// Load the disaster classification model
  Future<bool> loadModel() async {
    try {
      _modelLoadTime = DateTime.now();
      _lastError = null;
      debugPrint('🔄 Attempting to load disaster classification model...');
      debugPrint('   Model path: assets/best_model.tflite');
      
      // Load model - fromAsset expects path relative to assets folder
      final success = await _mlService.loadModel('best_model.tflite');
      
      if (success && _mlService.isLoaded) {
        debugPrint('✅ Disaster classification model loaded successfully');
        debugPrint('   Input shape: ${_mlService.inputShape}');
        debugPrint('   Output shape: ${_mlService.outputShape}');
        debugPrint('   Load time: ${_modelLoadTime?.toIso8601String()}');
        return true;
      } else {
        _lastError = 'Model loading returned false or model not loaded';
        debugPrint('❌ Model loading returned false or model not loaded');
        _modelLoadTime = null;
        return false;
      }
    } catch (e, stackTrace) {
      _lastError = 'Failed to load: $e';
      debugPrint('❌ Failed to load disaster classification model: $e');
      debugPrint('   Stack trace: $stackTrace');
      _modelLoadTime = null;
      return false;
    }
  }

  /// Check if model is loaded and ready
  bool get isModelLoaded => _mlService.isLoaded;

  /// Classify disaster from image file path
  /// Returns EmergencyDetectionResult with ML-based classification
  /// DYNAMIC - runs fresh inference every time, no caching
  Future<EmergencyDetectionResult> classifyDisaster(String imagePath) async {
      final startTime = DateTime.now();
      _inferenceCount++;
      _lastError = null;

    try {
      // ========== DYNAMIC DETECTION VERIFICATION ==========
      // Calculate image hash to verify we're processing different images
      final imageHash = await _calculateImageHash(imagePath);
      final isNewImage = imageHash != _lastImageHash;

      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('🤖 AI DISASTER CLASSIFICATION - DYNAMIC INFERENCE #$_inferenceCount');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('📸 Image Path: $imagePath');
      debugPrint('🔐 Image Hash: ${imageHash.substring(0, 16)}... (${isNewImage ? "NEW IMAGE" : "SAME IMAGE - VERIFYING DYNAMIC PROCESSING"})');
      debugPrint('⏰ Inference Time: ${startTime.toIso8601String()}');
      debugPrint('🔄 Previous Inference: ${_lastInferenceTime?.toIso8601String() ?? "First inference"}');
      if (_lastInferenceTime != null) {
        final timeSinceLast = startTime.difference(_lastInferenceTime!);
        debugPrint('⏱️  Time Since Last: ${timeSinceLast.inMilliseconds}ms');
      }
      debugPrint('───────────────────────────────────────────────────────────');

      // Step 1: Preprocess image (resize to 224x224, normalize to 0-1)
      debugPrint('📐 Step 1: Preprocessing image...');
      final preprocessStart = DateTime.now();
      final preprocessedImage = await _preprocessingService.preprocessImage(imagePath);
      final preprocessTime = DateTime.now().difference(preprocessStart);

      if (preprocessedImage == null) {
        _lastError = 'Failed to preprocess image';
        debugPrint('❌ Failed to preprocess image');
        return _createErrorResult(imagePath);
      }

      debugPrint('✅ Preprocessing complete: ${preprocessedImage.length} pixels in ${preprocessTime.inMilliseconds}ms');
      debugPrint('   Input shape: [1, 224, 224, 3] = ${224 * 224 * 3} values');

      // Step 2: Run ML inference - DYNAMIC, NO CACHING
      debugPrint('🧠 Step 2: Running ML inference (DYNAMIC - fresh inference every time)...');
      final inferenceStart = DateTime.now();
      
      // Clear any previous cached results to ensure dynamic processing
      _lastAllProbabilities = null;
      
      // Run fresh inference
      final probabilities = await _mlService.classify(preprocessedImage);
      final inferenceTime = DateTime.now().difference(inferenceStart);

      if (probabilities == null || probabilities.isEmpty) {
        _lastError = 'ML inference returned null or empty';
        debugPrint('❌ ML inference returned null or empty');
        return _createErrorResult(imagePath);
      }

      debugPrint('✅ Inference complete in ${inferenceTime.inMilliseconds}ms');
      debugPrint('📊 Raw Model Output:');
      for (int i = 0; i < probabilities.length && i < _modelLabels.length; i++) {
        debugPrint('   ${_modelLabels[i]}: ${probabilities[i].toStringAsFixed(6)}');
      }

      // Step 3: Post-process output (find highest probability)
      debugPrint('🔍 Step 3: Post-processing output...');
      final classification = _postProcessOutput(probabilities);

      // Store probabilities and metadata for detailed assessment
      _lastAllProbabilities = probabilities;
      _lastImageHash = imageHash;
      _lastInferenceTime = startTime;
      _lastClassificationLabel = classification['label'] as String;

      debugPrint('✅ Post-processing complete:');
      debugPrint('   Detected: ${classification['label']}');
      final confidenceValue = (classification['confidence'] as double) * 100;
      debugPrint('   Confidence: ${confidenceValue.toStringAsFixed(2)}%');
      debugPrint('   Index: ${classification['index']}');
      debugPrint('   All Probabilities:');
      for (int i = 0; i < _modelLabels.length && i < probabilities.length; i++) {
        debugPrint('      ${_modelLabels[i]}: ${(probabilities[i] * 100).toStringAsFixed(2)}%');
      }

      // Step 4: Map model output to EmergencyType
      final emergencyType = _mapToEmergencyType(classification['label'] as String);
      final confidence = classification['confidence'] as double;

      // Step 5: Enhanced severity assessment
      debugPrint('⚖️  Step 4: Assessing severity...');
      final severity = await _determineSeverityEnhanced(
        confidence,
        probabilities,
        emergencyType,
        imagePath,
      );

      debugPrint('✅ Severity Assessment: ${severity.label}');

      // Step 6: Create result
      final totalTime = DateTime.now().difference(startTime);
      debugPrint('───────────────────────────────────────────────────────────');
      debugPrint('✅ CLASSIFICATION COMPLETE');
      debugPrint('   Type: ${emergencyType.label}');
      debugPrint('   Severity: ${severity.label}');
      debugPrint('   Confidence: ${(confidence * 100).toStringAsFixed(2)}%');
      debugPrint('   Total Time: ${totalTime.inMilliseconds}ms');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('');

      return EmergencyDetectionResult(
        type: emergencyType,
        severity: severity,
        confidence: confidence,
        timestamp: startTime,
        imagePath: imagePath,
      );
    } catch (e, stackTrace) {
      _lastError = 'Error in classification: $e';
      debugPrint('❌ Error in disaster classification: $e');
      debugPrint('Stack trace: $stackTrace');
      return _createErrorResult(imagePath);
    }
  }

  /// Calculate hash of image file to verify dynamic processing
  Future<String> _calculateImageHash(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        return 'file_not_found';
      }
      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes);
      return hash.toString();
    } catch (e) {
      return 'hash_error_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Post-process model output to extract label and confidence
  Map<String, dynamic> _postProcessOutput(List<double> probabilities) {
    if (probabilities.length != _modelLabels.length) {
      debugPrint('⚠️ Unexpected output size: ${probabilities.length}, expected ${_modelLabels.length}');
      final adjustedProbs = probabilities.take(_modelLabels.length).toList();
      return _findBestPrediction(adjustedProbs);
    }

    return _findBestPrediction(probabilities);
  }

  /// Find the best prediction from probabilities
  Map<String, dynamic> _findBestPrediction(List<double> probabilities) {
    if (probabilities.isEmpty) {
      debugPrint('❌ Empty probabilities list');
      return {
        'label': 'No Emergency',
        'confidence': 0.0,
        'index': -1,
      };
    }

    // Find the index with highest probability
    double maxProb = probabilities[0];
    int bestIndex = 0;

    for (int i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > maxProb) {
        maxProb = probabilities[i];
        bestIndex = i;
      }
    }

    debugPrint('🔍 Best prediction analysis:');
    debugPrint('   Raw max value: ${maxProb.toStringAsFixed(6)} at index $bestIndex');
    debugPrint('   Sum of all values: ${probabilities.fold(0.0, (a, b) => a + b).toStringAsFixed(6)}');
    debugPrint('   All raw values: ${probabilities.map((p) => p.toStringAsFixed(4)).join(", ")}');

    // Check if values are logits (usually negative or large) or probabilities (0-1 range)
    final hasNegative = probabilities.any((p) => p < 0);
    final hasLargeValues = probabilities.any((p) => p > 10.0);
    final isLikelyLogits = hasNegative || hasLargeValues || maxProb > 1.0;
    
    debugPrint('   Has negative values: $hasNegative');
    debugPrint('   Has large values (>10): $hasLargeValues');
    debugPrint('   Max > 1.0: ${maxProb > 1.0}');
    debugPrint('   Likely logits: $isLikelyLogits');

    // Apply softmax if needed (check if probabilities sum to ~1.0)
    final sum = probabilities.fold(0.0, (a, b) => a + b);
    final isNormalized = sum > 0.9 && sum < 1.1;
    
    debugPrint('   Sum: ${sum.toStringAsFixed(6)}');
    debugPrint('   Is normalized (0.9-1.1): $isNormalized');

    List<double> normalizedProbs;
    double normalizedConfidence;

    if (isNormalized && !isLikelyLogits) {
      // Already probabilities, use directly
      debugPrint('   ✅ Using raw probabilities (already normalized)');
      normalizedProbs = probabilities;
      normalizedConfidence = maxProb;
    } else {
      // Need softmax normalization (logits)
      debugPrint('   🔄 Applying softmax (logits detected)');
      debugPrint('   Before softmax: ${probabilities.map((p) => p.toStringAsFixed(4)).join(", ")}');
      normalizedProbs = _softmax(probabilities);
      normalizedConfidence = normalizedProbs[bestIndex];

      debugPrint('   ✅ After softmax:');
      final softmaxSum = normalizedProbs.fold(0.0, (a, b) => a + b);
      debugPrint('      Sum: ${softmaxSum.toStringAsFixed(6)} (should be ~1.0)');
      for (int i = 0; i < normalizedProbs.length && i < _modelLabels.length; i++) {
        debugPrint('      ${_modelLabels[i]}: ${normalizedProbs[i].toStringAsFixed(6)} (${(normalizedProbs[i] * 100).toStringAsFixed(2)}%)');
      }
    }

    // Ensure bestIndex is within valid range
    if (bestIndex >= _modelLabels.length) {
      debugPrint('⚠️ Best index $bestIndex exceeds label count ${_modelLabels.length}, using 0');
      bestIndex = 0;
    }

    // Handle low confidence predictions
    if (normalizedConfidence < _minConfidenceThreshold) {
      debugPrint('⚠️ Low confidence prediction: ${normalizedConfidence.toStringAsFixed(3)} < $_minConfidenceThreshold');
      debugPrint('   Returning "No Emergency"');
      return {
        'label': 'No Emergency',
        'confidence': (1.0 - normalizedConfidence).clamp(0.0, 1.0),
        'index': -1,
        'allProbabilities': normalizedProbs,
      };
    }

    final selectedLabel = _modelLabels[bestIndex];
    debugPrint('✅ Selected: $selectedLabel (index $bestIndex) with confidence ${(normalizedConfidence * 100).toStringAsFixed(2)}%');

    return {
      'label': selectedLabel,
      'confidence': normalizedConfidence.clamp(0.0, 1.0),
      'index': bestIndex,
      'allProbabilities': normalizedProbs,
    };
  }

  /// Apply softmax normalization to probabilities
  List<double> _softmax(List<double> logits) {
    if (logits.isEmpty) return [];

    final maxLogit = logits.reduce((a, b) => a > b ? a : b);
    final expValues = logits.map((x) => math.exp(x - maxLogit)).toList();
    final sum = expValues.fold(0.0, (a, b) => a + b);

    if (sum == 0.0) {
      return List.filled(logits.length, 1.0 / logits.length);
    }

    return expValues.map((x) => x / sum).toList();
  }

  /// Map model label to EmergencyType enum
  EmergencyType _mapToEmergencyType(String label) {
    switch (label.toLowerCase()) {
      case 'flood':
        return EmergencyType.flood;
      case 'wildfire':
        return EmergencyType.fire;
      case 'earthquake':
        return EmergencyType.earthquake;
      case 'cyclone':
        return EmergencyType.calamity;
      case 'no emergency':
        return EmergencyType.noEmergency;
      default:
        debugPrint('⚠️ Unknown disaster label: $label');
        return EmergencyType.general;
    }
  }

  /// Enhanced severity assessment considering multiple factors
  Future<SeverityLevel> _determineSeverityEnhanced(
    double confidence,
    List<double> probabilities,
    EmergencyType type,
    String imagePath,
  ) async {
    double severityScore = confidence;

    // Factor in probability gap
    if (probabilities.length > 1) {
      final sortedProbs = List<double>.from(probabilities)..sort((a, b) => b.compareTo(a));
      final probGap = sortedProbs[0] - sortedProbs[1];
      severityScore += probGap * 0.2;
    }

    // Adjust based on disaster type
    switch (type) {
      case EmergencyType.fire:
        severityScore += confidence * 0.15;
        break;
      case EmergencyType.flood:
        severityScore += confidence * 0.1;
        break;
      case EmergencyType.earthquake:
        severityScore += confidence * 0.2;
        break;
      case EmergencyType.calamity:
        severityScore += confidence * 0.18;
        break;
      case EmergencyType.noEmergency:
        return SeverityLevel.low;
      case EmergencyType.general:
        return SeverityLevel.low;
      default:
        break;
    }

    severityScore = severityScore.clamp(0.0, 1.0);

    if (severityScore >= 0.85) {
      return SeverityLevel.critical;
    } else if (severityScore >= 0.70) {
      return SeverityLevel.high;
    } else if (severityScore >= 0.55) {
      return SeverityLevel.medium;
    } else {
      return SeverityLevel.low;
    }
  }

  /// Create error result when classification fails
  EmergencyDetectionResult _createErrorResult(String imagePath) {
    return EmergencyDetectionResult(
      type: EmergencyType.general,
      severity: SeverityLevel.low,
      confidence: 0.0,
      timestamp: DateTime.now(),
      imagePath: imagePath,
    );
  }

  /// Get context-aware risk assessment message for disaster type
  String getRiskAssessmentMessage(EmergencyType type, double confidence) {
    final confidencePercent = (confidence * 100).toStringAsFixed(0);

    switch (type) {
      case EmergencyType.flood:
        return 'Flood detected ($confidencePercent% confidence). Risk: Water damage, evacuation may be necessary.';
      case EmergencyType.fire:
        return 'Wildfire detected ($confidencePercent% confidence). Risk: Fire spread, smoke inhalation. Evacuate immediately.';
      case EmergencyType.earthquake:
        return 'Earthquake damage detected ($confidencePercent% confidence). Risk: Structural collapse, falling debris.';
      case EmergencyType.calamity:
        return 'Cyclone detected ($confidencePercent% confidence). Risk: High winds, flying debris, flooding.';
      case EmergencyType.noEmergency:
        return 'No emergency detected ($confidencePercent% confidence). Area appears safe.';
      default:
        return 'Emergency situation detected ($confidencePercent% confidence). Exercise caution.';
    }
  }

  /// Get detailed assessment breakdown
  Map<String, dynamic> getDetailedAssessment(
    EmergencyType type,
    double confidence,
  ) {
    final probabilities = _lastAllProbabilities;

    final assessment = <String, dynamic>{
      'type': type.label,
      'confidence': confidence,
      'confidencePercent': (confidence * 100).toStringAsFixed(1),
      'riskMessage': getRiskAssessmentMessage(type, confidence),
      'timestamp': DateTime.now().toIso8601String(),
    };

    // Add probability breakdown if available
    if (probabilities != null && probabilities.length >= _modelLabels.length) {
      final sum = probabilities.fold(0.0, (a, b) => a + b);
      final normalizedProbs = sum > 0.9 && sum < 1.1
          ? probabilities
          : _softmax(probabilities);

      final breakdown = <String, double>{};
      for (int i = 0; i < _modelLabels.length && i < normalizedProbs.length; i++) {
        breakdown[_modelLabels[i]] = normalizedProbs[i];
      }
      assessment['probabilityBreakdown'] = breakdown;
    }

    return assessment;
  }
}
