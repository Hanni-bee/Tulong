import 'dart:io';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../models/emergency_type.dart';
import '../models/emergency_detection_result.dart';
import 'ai_detection_config.dart';
import 'ml_model_service.dart';
import 'image_preprocessing_service.dart';

/// Service for ML-based disaster classification.
/// Uses TensorFlow Lite (PyImageSearch) to classify into: Flood, Wildfire, Earthquake, Cyclone.
/// Detection is tuned via [AIDetectionConfig] (thresholds, min gap, entropy).
class DisasterClassificationService {
  static DisasterClassificationService? _instance;
  static DisasterClassificationService get instance =>
      _instance ??= DisasterClassificationService._();

  DisasterClassificationService._();

  final MLModelService _mlService = MLModelService.instance;
  final ImagePreprocessingService _preprocessingService = ImagePreprocessingService();

  static List<String> get _modelLabels => AIDetectionConfig.modelLabels;

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
  /// ENHANCED: With timeout, retry logic, and proper state management
  Future<bool> loadModel() async {
    // Prevent multiple simultaneous loads
    if (_mlService.isLoaded) {
      debugPrint('✅ Model already loaded, skipping reload');
      return true;
    }
    
    try {
      _modelLoadTime = DateTime.now();
      _lastError = null;
      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('🔄 LOADING DISASTER CLASSIFICATION MODEL');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('📁 Model path: assets/best_model.tflite');
      debugPrint('⏳ Starting load at: ${_modelLoadTime?.toIso8601String()}');
      
      // Load model with timeout to prevent infinite hanging
      final timeoutSecs = AIDetectionConfig.modelLoadTimeoutSeconds;
      final success = await _mlService.loadModel('best_model.tflite').timeout(
        Duration(seconds: timeoutSecs),
        onTimeout: () {
          _lastError = 'Model loading timeout after $timeoutSecs seconds';
          debugPrint('❌ TIMEOUT: Model loading exceeded $timeoutSecs seconds');
          debugPrint('   Possible causes:');
          debugPrint('   1. Model file is corrupted in APK');
          debugPrint('   2. Model file was compressed despite noCompress setting');
          debugPrint('   3. Device has insufficient memory');
          debugPrint('   4. Model file path is incorrect');
          return false;
        },
      );
      
      final loadDuration = DateTime.now().difference(_modelLoadTime!);
      
      if (success && _mlService.isLoaded) {
        debugPrint('✅ Disaster classification model loaded successfully');
        debugPrint('   Load duration: ${loadDuration.inMilliseconds}ms');
        debugPrint('   Input shape: ${_mlService.inputShape}');
        debugPrint('   Output shape: ${_mlService.outputShape}');
        debugPrint('   Model is ready for classification');
        debugPrint('═══════════════════════════════════════════════════════════');
        return true;
      } else {
        _lastError = _mlService.lastError ?? 'Model loading returned false or model not loaded';
        debugPrint('❌ Model loading failed');
        debugPrint('   Success flag: $success');
        debugPrint('   MLService loaded: ${_mlService.isLoaded}');
        debugPrint('   MLService error: ${_mlService.lastError}');
        debugPrint('   Load duration: ${loadDuration.inMilliseconds}ms');
        debugPrint('═══════════════════════════════════════════════════════════');
        _modelLoadTime = null;
        return false;
      }
    } catch (e, stackTrace) {
      _lastError = 'Failed to load: $e';
      debugPrint('❌ EXCEPTION during model loading: $e');
      debugPrint('   Error type: ${e.runtimeType}');
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
  /// ENHANCED: Proper model state checking and error handling
  Future<EmergencyDetectionResult> classifyDisaster(String imagePath) async {
    // CRITICAL: Check if model is loaded before attempting classification
    if (!_mlService.isLoaded || !isModelLoaded) {
      _lastError = 'Model not loaded. Cannot classify.';
      debugPrint('❌ CRITICAL: Model not loaded, cannot classify');
      debugPrint('   MLService.isLoaded: ${_mlService.isLoaded}');
      debugPrint('   isModelLoaded: $isModelLoaded');
      debugPrint('   Attempting to load model now...');
      
      // Try to load model if not loaded
      final loadSuccess = await loadModel();
      if (!loadSuccess) {
        debugPrint('❌ Failed to load model, returning error result');
        return _createErrorResult(imagePath);
      }
      debugPrint('✅ Model loaded successfully, proceeding with classification');
    }
    
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

      // Step 1: Preprocess image (validate + resize to model size, normalize 0-1)
      debugPrint('📐 Step 1: Preprocessing image...');
      final preprocessStart = DateTime.now();
      final preprocessResult = await _preprocessingService.preprocessImageWithResult(imagePath);
      final preprocessTime = DateTime.now().difference(preprocessStart);

      if (!preprocessResult.isSuccess) {
        _lastError = 'Preprocess failed: ${preprocessResult.errorCode ?? "unknown"}';
        debugPrint('❌ Preprocess failed: ${preprocessResult.errorCode}');
        return _createErrorResult(imagePath);
      }

      final preprocessedImage = preprocessResult.data!;
      debugPrint('✅ Preprocessing complete: ${preprocessedImage.length} pixels in ${preprocessTime.inMilliseconds}ms');

      // Step 2: Run ML inference (with optional TTA: flip + average)
      debugPrint('🧠 Step 2: Running ML inference...');
      final inferenceStart = DateTime.now();
      _lastAllProbabilities = null;

      List<double> probabilities;
      if (AIDetectionConfig.enableTTA) {
        final probs1 = await _mlService.classify(preprocessedImage);
        final flipped = _flipPreprocessedImage(preprocessedImage);
        final probs2 = flipped != null ? await _mlService.classify(flipped) : null;
        if (probs1 == null || probs1.isEmpty) {
          _lastError = 'ML inference returned null or empty';
          debugPrint('❌ ML inference returned null or empty');
          return _createErrorResult(imagePath);
        }
        if (probs2 != null && probs2.length == probs1.length) {
          probabilities = List.generate(probs1.length, (i) => (probs1[i] + probs2[i]) / 2.0);
          debugPrint('   TTA: averaged with flipped image');
        } else {
          probabilities = probs1;
        }
      } else {
        probabilities = await _mlService.classify(preprocessedImage) ?? [];
      }

      final inferenceTime = DateTime.now().difference(inferenceStart);
      if (probabilities.isEmpty) {
        _lastError = 'ML inference returned null or empty';
        debugPrint('❌ ML inference returned null or empty');
        return _createErrorResult(imagePath);
      }

      debugPrint('✅ Inference complete in ${inferenceTime.inMilliseconds}ms');
      debugPrint('📊 Raw Model Output:');
      for (int i = 0; i < probabilities.length && i < _modelLabels.length; i++) {
        debugPrint('   ${_modelLabels[i]}: ${probabilities[i].toStringAsFixed(6)}');
      }

      // Step 3: Post-process output (find highest probability, optional temperature)
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

  /// Horizontally flip preprocessed image (HxWx3 row-major) for TTA.
  Float32List? _flipPreprocessedImage(Float32List input) {
    if (input.length != AIDetectionConfig.expectedInputPixels) return null;
    final w = AIDetectionConfig.modelInputWidth;
    final h = AIDetectionConfig.modelInputHeight;
    const c = 3;
    final out = Float32List(input.length);
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final src = (y * w + x) * c;
        final dst = (y * w + (w - 1 - x)) * c;
        out[dst] = input[src];
        out[dst + 1] = input[src + 1];
        out[dst + 2] = input[src + 2];
      }
    }
    return out;
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
      return _noEmergencyResult([]);
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

    // Optional temperature scaling (soften or sharpen the distribution)
    final temp = AIDetectionConfig.temperatureScale;
    if (temp > 0 && (temp - 1.0).abs() > 0.01) {
      final invT = 1.0 / temp;
      final scaled = normalizedProbs.map((p) => math.pow(p, invT).toDouble()).toList();
      final sum = scaled.fold(0.0, (a, b) => a + b);
      if (sum > 0) {
        for (int i = 0; i < scaled.length; i++) scaled[i] = scaled[i] / sum;
        normalizedProbs = scaled;
        normalizedConfidence = normalizedProbs[bestIndex];
      }
    }

    // Apply detection thresholds for reliable reporting
    final minConf = AIDetectionConfig.minConfidenceToReport;
    final minGap = AIDetectionConfig.minProbabilityGap;
    final maxEnt = AIDetectionConfig.maxEntropyForReport;

    if (normalizedConfidence < minConf) {
      debugPrint('⚠️ Low confidence: ${(normalizedConfidence * 100).toStringAsFixed(1)}% < ${(minConf * 100).toStringAsFixed(0)}% → No Emergency');
      return _noEmergencyResult(normalizedProbs);
    }

    // Require clear lead over second class (avoids ties/uncertainty)
    double gap = 0.0;
    if (normalizedProbs.length > 1) {
      final sorted = List<double>.from(normalizedProbs)..sort((a, b) => b.compareTo(a));
      gap = sorted[0] - sorted[1];
    }
    if (gap < minGap) {
      debugPrint('⚠️ Probability gap too small: ${(gap * 100).toStringAsFixed(1)}% < ${(minGap * 100).toStringAsFixed(0)}% → No Emergency');
      return _noEmergencyResult(normalizedProbs);
    }

    // Reject high-entropy (uniform) predictions
    final entropy = _computeEntropy(normalizedProbs);
    if (entropy > maxEnt) {
      debugPrint('⚠️ High uncertainty (entropy ${entropy.toStringAsFixed(3)} > $maxEnt) → No Emergency');
      return _noEmergencyResult(normalizedProbs);
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

  Map<String, dynamic> _noEmergencyResult(List<double> allProbabilities) {
    return {
      'label': 'No Emergency',
      'confidence': AIDetectionConfig.defaultNoEmergencyConfidence,
      'index': -1,
      'allProbabilities': allProbabilities,
    };
  }

  /// Entropy of probability distribution (0 = certain, ln(4)≈1.39 = uniform over 4 classes)
  double _computeEntropy(List<double> probs) {
    if (probs.isEmpty) return 0.0;
    double h = 0.0;
    for (final p in probs) {
      if (p > 0.0 && p < 1.0) h -= p * math.log(p);
    }
    return h;
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
        debugPrint('⚠️ Unknown disaster label: $label - treating as No Emergency');
        return EmergencyType.noEmergency; // Changed from general to noEmergency
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

  /// Create error result when classification fails (no detection)
  EmergencyDetectionResult _createErrorResult(String imagePath) {
    return EmergencyDetectionResult(
      type: EmergencyType.noEmergency,
      severity: SeverityLevel.low,
      confidence: AIDetectionConfig.defaultNoEmergencyConfidence,
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
