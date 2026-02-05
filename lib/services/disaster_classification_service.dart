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

  // Confidence thresholds based on PyImageSearch model (95% accuracy)
  // The model is well-trained, so we can trust its predictions more
  // Reference: https://pyimagesearch.com/2019/11/11/detecting-natural-disasters-with-keras-and-deep-learning/
  static const double _minConfidenceThreshold = 0.20; // 20% minimum confidence for classification
  
  // For "No Emergency", use lower threshold since model is trained to detect disasters
  // If model predicts a disaster with low confidence, it's likely "No Emergency"
  static const double _noEmergencyConfidenceThreshold = 0.30; // 30% minimum to confirm "No Emergency"

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
    if (_mlService.isLoaded) {
      return true;
    }
    
    _modelLoadTime = DateTime.now();
    _lastError = null;
    
    try {
      final success = await _mlService.loadModel('best_model.tflite').timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          _lastError = 'Model loading timeout';
          return false;
        },
      );
      
      if (success && _mlService.isLoaded) {
        _modelLoadTime = DateTime.now();
        return true;
      } else {
        _lastError = _mlService.lastError ?? 'Model loading failed';
        _modelLoadTime = null;
        return false;
      }
    } catch (e) {
      _lastError = 'Failed to load: $e';
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
      
      // CRITICAL: Run fresh inference - ensure model is loaded
      if (!_mlService.isLoaded) {
        debugPrint('❌ CRITICAL: Model not loaded before inference!');
        debugPrint('   Attempting to load model now...');
        final loadSuccess = await loadModel();
        if (!loadSuccess) {
          _lastError = 'Model not loaded and failed to load';
          debugPrint('❌ Failed to load model for inference');
          return _createErrorResult(imagePath);
        }
        debugPrint('✅ Model loaded successfully, proceeding with inference');
      }
      
      // Run fresh inference - DYNAMIC, NO CACHING
      // This is the CORE classification step - runs actual ML inference
      debugPrint('🔄 Calling ML service classify() - this is DYNAMIC inference');
      debugPrint('   Preprocessed image ready: ${preprocessedImage.length} values');
      debugPrint('   Model status: ${_mlService.isLoaded ? "LOADED ✅" : "NOT LOADED ❌"}');
      
      final probabilities = await _mlService.classify(preprocessedImage);
      final inferenceTime = DateTime.now().difference(inferenceStart);
      
      debugPrint('⏱️  Inference duration: ${inferenceTime.inMilliseconds}ms');

      // OUTPUT VALIDATION: Validate inference result structure
      if (probabilities == null) {
        _lastError = 'ML inference returned null - check model loading and input preprocessing';
        debugPrint('❌ OUTPUT VALIDATION FAILED: ML inference returned null');
        debugPrint('   Model loaded: ${_mlService.isLoaded}');
        debugPrint('   Preprocessed image length: ${preprocessedImage.length}');
        debugPrint('   Expected length: ${224 * 224 * 3}');
        debugPrint('   ML Service error: ${_mlService.lastError}');
        return _createErrorResult(imagePath);
      }
      
      // OUTPUT VALIDATION: Check output is not empty
      if (probabilities.isEmpty) {
        _lastError = 'ML inference returned empty list';
        debugPrint('❌ OUTPUT VALIDATION FAILED: ML inference returned empty list');
        debugPrint('   Probabilities length: ${probabilities.length}');
        return _createErrorResult(imagePath);
      }
      
      // OUTPUT VALIDATION: Check output length matches expected (4 classes)
      if (probabilities.length != 4) {
        _lastError = 'ML inference output length mismatch: expected 4, got ${probabilities.length}';
        debugPrint('❌ OUTPUT VALIDATION FAILED: Output length mismatch');
        debugPrint('   Expected: 4 classes');
        debugPrint('   Got: ${probabilities.length}');
        return _createErrorResult(imagePath);
      }
      
      // OUTPUT VALIDATION: Validate probabilities are valid numbers
      final hasInvalid = probabilities.any((p) => p.isNaN || p.isInfinite);
      if (hasInvalid) {
        _lastError = 'ML inference returned invalid probability values (NaN or Infinite)';
        debugPrint('❌ OUTPUT VALIDATION FAILED: Invalid probability values detected');
        debugPrint('   Probabilities: $probabilities');
        debugPrint('   Has NaN: ${probabilities.any((p) => p.isNaN)}');
        debugPrint('   Has Infinite: ${probabilities.any((p) => p.isInfinite)}');
        return _createErrorResult(imagePath);
      }
      
      // OUTPUT VALIDATION: Check for extreme values (might indicate error)
      final hasExtremeValues = probabilities.any((p) => p.abs() > 100.0);
      if (hasExtremeValues) {
        _lastError = 'ML inference returned extreme values (>100)';
        debugPrint('❌ OUTPUT VALIDATION FAILED: Extreme values detected');
        debugPrint('   Probabilities: $probabilities');
        return _createErrorResult(imagePath);
      }
      
      debugPrint('✅ Inference result validated: ${probabilities.length} probabilities');
      debugPrint('✅ Inference complete in ${inferenceTime.inMilliseconds}ms');
      
      // Display raw model output - EXACTLY matches Python output format
      debugPrint('📊 Raw Model Output (Python equivalent: interpreter.get_tensor()[0]):');
      final sum = probabilities.fold(0.0, (a, b) => a + b);
      debugPrint('   Sum of probabilities: ${sum.toStringAsFixed(6)} ${sum > 0.9 && sum < 1.1 ? "(normalized ✅)" : "(logits - will apply softmax)"}');
      for (int i = 0; i < probabilities.length && i < _modelLabels.length; i++) {
        final percentage = (probabilities[i] * 100).toStringAsFixed(2);
        debugPrint('   [${i}] ${_modelLabels[i]}: ${probabilities[i].toStringAsFixed(6)} (${percentage}%)');
      }
      
      // Find argmax (highest probability) - matches Python np.argmax()
      final maxProb = probabilities.reduce((a, b) => a > b ? a : b);
      final argmaxIndex = probabilities.indexOf(maxProb);
      debugPrint('   🎯 Argmax (np.argmax equivalent): index $argmaxIndex = "${_modelLabels[argmaxIndex]}" (${(maxProb * 100).toStringAsFixed(2)}%)');

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
      String classificationLabel = classification['label'] as String;
      double confidence = classification['confidence'] as double;
      
      // ENHANCED: Higher validation for "No Emergency" to prevent false positives
      // Additional validation: Check if this might be a false positive disaster detection
      if (classificationLabel != 'No Emergency') {
        // Get normalized probabilities for validation
        final sum = probabilities.fold(0.0, (a, b) => a + b);
        final normalizedProbs = sum > 0.9 && sum < 1.1
            ? probabilities
            : _softmax(probabilities);
        
        // Check if this might be a false positive
        final sortedProbs = List<double>.from(normalizedProbs)..sort((a, b) => b.compareTo(a));
        final probGap = sortedProbs[0] - (sortedProbs.length > 1 ? sortedProbs[1] : 0.0);
        final avgProb = normalizedProbs.fold(0.0, (a, b) => a + b) / normalizedProbs.length;
        
        // ENHANCED: More lenient validation - only reject if VERY uncertain
        // Only treat as "No Emergency" if confidence is VERY low AND probabilities are VERY close
        // This allows the model to classify more disasters
        if (confidence < 0.10 && probGap < 0.05 && avgProb < 0.30) {
          debugPrint('⚠️ ENHANCED VALIDATION: Very low confidence disaster prediction:');
          debugPrint('   Predicted: $classificationLabel (${(confidence * 100).toStringAsFixed(2)}%)');
          debugPrint('   Probability gap: ${(probGap * 100).toStringAsFixed(2)}%');
          debugPrint('   Average probability: ${(avgProb * 100).toStringAsFixed(2)}%');
          debugPrint('   → Treating as "No Emergency" (very uncertain)');
          classificationLabel = 'No Emergency';
          confidence = (1.0 - confidence).clamp(0.0, 1.0); // Invert confidence
        } else {
          debugPrint('✅ Classification accepted: $classificationLabel (${(confidence * 100).toStringAsFixed(2)}%)');
          debugPrint('   Confidence is sufficient for classification');
        }
      } else {
        // For "No Emergency" predictions, use lower threshold to allow more disaster classifications
        // If confidence is very low, it might actually be a disaster
        if (confidence < 0.10) {
          debugPrint('⚠️ Very low confidence "No Emergency": ${(confidence * 100).toStringAsFixed(2)}%');
          debugPrint('   → Keeping as "No Emergency" (very uncertain)');
          confidence = confidence.clamp(0.0, 0.10);
        } else {
          debugPrint('✅ "No Emergency" classification accepted: ${(confidence * 100).toStringAsFixed(2)}%');
        }
      }
      
      final emergencyType = _mapToEmergencyType(classificationLabel);

      // Step 5: Enhanced severity assessment
      debugPrint('⚖️  Step 5: Assessing severity...');
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
  /// ENHANCED: Robust validation to ensure dynamic inference with proper confidence
  Map<String, dynamic> _findBestPrediction(List<double> probabilities) {
    // CRITICAL: Validate probabilities before processing
    if (probabilities.isEmpty) {
      debugPrint('❌ CRITICAL: Empty probabilities list in _findBestPrediction');
      return {
        'label': 'No Emergency',
        'confidence': 0.0,
        'index': -1,
        'allProbabilities': [],
      };
    }
    
    // CRITICAL: Check for invalid values (NaN, Infinite)
    final hasInvalid = probabilities.any((p) => p.isNaN || p.isInfinite);
    if (hasInvalid) {
      debugPrint('❌ CRITICAL: Invalid probability values in _findBestPrediction');
      debugPrint('   Probabilities: $probabilities');
      debugPrint('   Has NaN: ${probabilities.any((p) => p.isNaN)}');
      debugPrint('   Has Infinite: ${probabilities.any((p) => p.isInfinite)}');
      return {
        'label': 'No Emergency',
        'confidence': 0.0,
        'index': -1,
        'allProbabilities': probabilities,
      };
    }
    
    // CRITICAL: Validate all probabilities are valid numbers
    final sumCheck = probabilities.fold(0.0, (a, b) => a + b);
    if (sumCheck == 0.0) {
      debugPrint('❌ CRITICAL: All probabilities are zero - inference may have failed');
      return {
        'label': 'No Emergency',
        'confidence': 0.0,
        'index': -1,
        'allProbabilities': probabilities,
      };
    }
    
    // EXACTLY matches Python: predicted_idx = int(np.argmax(predictions))
    // Find the index with highest probability
    double maxProb = probabilities[0];
    int bestIndex = 0;

    for (int i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > maxProb) {
        maxProb = probabilities[i];
        bestIndex = i;
      }
    }
    
    // CRITICAL: Validate bestIndex is within bounds
    if (bestIndex < 0 || bestIndex >= _modelLabels.length) {
      debugPrint('❌ CRITICAL: Invalid bestIndex: $bestIndex (should be 0-${_modelLabels.length - 1})');
      bestIndex = 0; // Fallback to first class
      maxProb = probabilities[0];
    }

    debugPrint('🔍 Best prediction analysis:');
    debugPrint('   Raw max value: ${maxProb.toStringAsFixed(6)} at index $bestIndex');
    debugPrint('   Sum of all values: ${sumCheck.toStringAsFixed(6)}');
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

    // EXACTLY matches PyImageSearch tutorial post-processing:
    // Python: predicted_idx = int(np.argmax(predictions))
    // Python: confidence = float(predictions[predicted_idx])
    // Reference: https://pyimagesearch.com/2019/11/11/detecting-natural-disasters-with-keras-and-deep-learning/
    final selectedLabel = _modelLabels[bestIndex];
    final rawConfidence = normalizedConfidence;
    
    debugPrint('🔍 PyImageSearch-equivalent post-processing:');
    debugPrint('   np.argmax(predictions) = $bestIndex → "$selectedLabel"');
    debugPrint('   predictions[$bestIndex] = ${rawConfidence.toStringAsFixed(6)}');
    debugPrint('   Model accuracy: 95% (PyImageSearch tutorial)');
    
    // ENHANCED: More lenient validation to allow actual classifications
    // Only reject if confidence is EXTREMELY low (below 10%)
    // This allows the model to classify disasters even with moderate confidence
    if (normalizedConfidence < 0.10) {
      debugPrint('⚠️ Very low confidence prediction: ${normalizedConfidence.toStringAsFixed(3)} < 0.10 (10%)');
      debugPrint('   → Returning "No Emergency" (too uncertain)');
      return {
        'label': 'No Emergency',
        'confidence': (1.0 - normalizedConfidence).clamp(0.0, 1.0),
        'index': -1,
        'allProbabilities': normalizedProbs,
      };
    }
    
    // ENHANCED: More lenient probability gap validation
    // Only reject if probabilities are EXTREMELY close (gap < 5%) AND confidence is VERY low (< 20%)
    // This allows classifications even when probabilities are somewhat close
    if (normalizedProbs.length > 1) {
      final sortedProbs = List<double>.from(normalizedProbs)..sort((a, b) => b.compareTo(a));
      final probGap = sortedProbs[0] - sortedProbs[1];
      
      // Only reject if gap is VERY small (< 5%) AND confidence is VERY low (< 20%)
      if (probGap < 0.05 && normalizedConfidence < 0.20) {
        debugPrint('⚠️ Very uncertain prediction:');
        debugPrint('   Probability gap: ${(probGap * 100).toStringAsFixed(2)}% < 5%');
        debugPrint('   Confidence: ${(normalizedConfidence * 100).toStringAsFixed(2)}% < 20%');
        debugPrint('   Top probabilities: ${sortedProbs[0].toStringAsFixed(3)}, ${sortedProbs[1].toStringAsFixed(3)}');
        debugPrint('   → Returning "No Emergency" (extremely uncertain)');
        return {
          'label': 'No Emergency',
          'confidence': (1.0 - normalizedConfidence).clamp(0.0, 1.0),
          'index': -1,
          'allProbabilities': normalizedProbs,
        };
      } else {
        debugPrint('✅ Classification accepted despite probability gap:');
        debugPrint('   Gap: ${(probGap * 100).toStringAsFixed(2)}%, Confidence: ${(normalizedConfidence * 100).toStringAsFixed(2)}%');
        debugPrint('   → Accepting classification: $selectedLabel');
      }
    }

    debugPrint('✅ Selected: $selectedLabel (index $bestIndex) with confidence ${(normalizedConfidence * 100).toStringAsFixed(2)}%');
    debugPrint('   Based on PyImageSearch tutorial (95% accuracy model)');
    
    // PyImageSearch model is well-trained (95% accuracy), so we trust its predictions
    // No confidence boosting needed - use raw model output
    // Reference: https://pyimagesearch.com/2019/11/11/detecting-natural-disasters-with-keras-and-deep-learning/
    double finalConfidence = normalizedConfidence;

    return {
      'label': selectedLabel,
      'confidence': finalConfidence.clamp(0.0, 1.0),
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
  /// EXACTLY matches PyImageSearch 4-class model: Cyclone, Earthquake, Flood, Wildfire
  EmergencyType _mapToEmergencyType(String label) {
    switch (label.toLowerCase()) {
      case 'cyclone':
        return EmergencyType.cyclone;  // Index 0
      case 'earthquake':
        return EmergencyType.earthquake; // Index 1
      case 'flood':
        return EmergencyType.flood;    // Index 2
      case 'wildfire':
        return EmergencyType.fire;     // Index 3 (Wildfire -> Fire)
      case 'no emergency':
        return EmergencyType.noEmergency;
      default:
        debugPrint('⚠️ Unknown disaster label: $label - treating as No Emergency');
        return EmergencyType.noEmergency;
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
      case EmergencyType.cyclone:
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

  /// Create error result when classification fails
  EmergencyDetectionResult _createErrorResult(String imagePath) {
    return EmergencyDetectionResult(
      type: EmergencyType.noEmergency, // Changed from general to noEmergency
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
      case EmergencyType.cyclone:
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

    // REMOVED: Probability breakdown - focus only on classified result
    // User requested to remove probability breakdown and focus on actual classification

    return assessment;
  }
}
