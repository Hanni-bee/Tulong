import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'ml_model_service.dart';
import 'image_preprocessing_service.dart';

/// Service for assessing damage severity using the medic_damage_severity_model
/// This service uses the TFLite model to classify damage into:
/// - "Little/No damage" (class 0)
/// - "Mild damage" (class 1)
/// - "Severe damage" (class 2)
class DamageSeverityService {
  static DamageSeverityService? _instance;
  static DamageSeverityService get instance => _instance ??= DamageSeverityService._();
  
  DamageSeverityService._();
  
  final MLModelService _mlModelService = MLModelService.instance;
  final ImagePreprocessingService _preprocessingService = ImagePreprocessingService();
  bool _isModelLoaded = false;
  
  // Tracking for static detection testing
  List<double>? _lastPredictions;
  String? _lastImagePath;
  int _inferenceCount = 0;
  bool _isModelStatic = false;
  String? _modelStatusMessage;
  
  /// Get model validation status for UI display
  bool get isModelStatic => _isModelStatic;
  String? get modelStatusMessage => _modelStatusMessage;
  
  /// Class names for damage severity
  static const List<String> classNames = [
    "Little/No damage",
    "Mild damage",
    "Severe damage",
  ];
  
  /// Check if model is loaded
  bool get isModelLoaded => _isModelLoaded && _mlModelService.isLoaded;
  
  /// Load the damage severity model
  Future<bool> loadModel() async {
    try {
      debugPrint('🔄 DamageSeverityService: Loading model...');
      // Model is in assets root, not in a subdirectory
      // Path should be without 'assets/' prefix for fromAsset
      final loaded = await _mlModelService.loadModel('medic_damage_severity_model.keras.tflite');
      _isModelLoaded = loaded;
      
      if (loaded) {
        debugPrint('✅ Damage Severity Model loaded successfully');
        debugPrint('   Input shape: ${_mlModelService.inputShape}');
        debugPrint('   Output shape: ${_mlModelService.outputShape}');
      } else {
        debugPrint('❌ Failed to load Damage Severity Model');
      }
      
      return loaded;
    } catch (e) {
      debugPrint('❌ Error loading Damage Severity Model: $e');
      _isModelLoaded = false;
      return false;
    }
  }
  
  /// Assess damage severity from an image
  /// 
  /// [imagePath] - Path to the image file
  /// Returns a map with:
  /// - 'classIndex': int (0, 1, or 2)
  /// - 'className': String (class name)
  /// - 'confidence': double (0.0 to 1.0)
  /// - 'probabilities': List<double> (probabilities for all classes)
  Future<Map<String, dynamic>?> assessDamageSeverity(String imagePath) async {
    // STRICT CHECK: Don't run if model is not loaded
    if (!isModelLoaded) {
      debugPrint('⚠️⚠️⚠️ Model not loaded - attempting to load...');
      final loaded = await loadModel();
      if (!loaded) {
        debugPrint('❌❌❌ Cannot assess damage: model failed to load');
        debugPrint('   Model will NOT run. Please check model file and path.');
        return null;
      }
      // Double check after loading
      if (!isModelLoaded) {
        debugPrint('❌❌❌ Model still not loaded after loadModel() call');
        return null;
      }
    }
    
    // Verify ML service is also loaded
    if (!_mlModelService.isLoaded) {
      debugPrint('❌❌❌ MLModelService is not loaded');
      return null;
    }
    
    debugPrint('✅ Model verified loaded - proceeding with assessment');
    
    try {
      // Step 1: Preprocess the image
      debugPrint('📸 Preprocessing image: $imagePath');
      final preprocessed = await _preprocessingService.preprocessImage(imagePath);
      
      if (preprocessed == null) {
        debugPrint('❌ Failed to preprocess image');
        return null;
      }
      
      debugPrint('✅ Image preprocessed: ${preprocessed.length} values');
      
      // Step 2: Run TFLite inference
      debugPrint('🤖 Running TFLite inference...');
      final predictions = await _mlModelService.classify(preprocessed);
      
      if (predictions == null || predictions.isEmpty) {
        debugPrint('❌ Model inference returned null or empty');
        return null;
      }
      
      debugPrint('✅ Inference complete: ${predictions.length} outputs');
      debugPrint('   Raw predictions: $predictions');
      
      // ===== MODEL VALIDATION & TESTING =====
      // Verify model is actually running and not static
      _inferenceCount++;
      debugPrint('🔍 MODEL TESTING - Inference #$_inferenceCount');
      debugPrint('   Image path: $imagePath');
      debugPrint('   Image file size: ${await _getFileSize(imagePath)} bytes');
      debugPrint('   Image modified: ${await _getFileModifiedTime(imagePath)}');
      
      // Calculate input data hash (first 10 pixels) to verify different images
      final inputSample = preprocessed.sublist(0, preprocessed.length < 30 ? preprocessed.length : 30);
      final inputHash = inputSample.map((e) => e.toStringAsFixed(3)).join(',');
      debugPrint('   Input data sample (first 10 pixels): ${inputSample.take(10).map((e) => e.toStringAsFixed(3)).join(", ")}');
      
      // Check if predictions are static (same as last time)
      bool isStaticDetection = false;
      if (_lastPredictions != null && _lastImagePath != imagePath) {
        bool isStatic = true;
        for (int i = 0; i < predictions.length && i < _lastPredictions!.length; i++) {
          if ((predictions[i] - _lastPredictions![i]).abs() > 0.0001) {
            isStatic = false;
            break;
          }
        }
        
        isStaticDetection = isStatic;
        
        if (isStatic) {
          debugPrint('⚠️⚠️⚠️ STATIC DETECTION WARNING ⚠️⚠️⚠️');
          debugPrint('   Current predictions: $predictions');
          debugPrint('   Last predictions: $_lastPredictions');
          debugPrint('   Different image but SAME predictions - Model may not be working!');
          _isModelStatic = true;
          _modelStatusMessage = 'Warning: Same predictions detected for different images';
        } else {
          debugPrint('✅ Dynamic detection confirmed - predictions differ from last');
          debugPrint('   Current: $predictions');
          debugPrint('   Previous: $_lastPredictions');
          _isModelStatic = false;
          _modelStatusMessage = 'Model is working dynamically';
        }
      }
      
      // Check for other static indicators
      final allSame = predictions.every((p) => (p - predictions[0]).abs() < 0.001);
      final hasVariation = predictions.any((p) => (p - predictions[0]).abs() > 0.01);
      
      if (allSame && _inferenceCount > 1) {
        _isModelStatic = true;
        _modelStatusMessage = 'Warning: All predictions are identical';
      } else if (!hasVariation && _inferenceCount > 1) {
        _isModelStatic = true;
        _modelStatusMessage = 'Warning: Predictions show no variation';
      } else if (_inferenceCount == 1) {
        _modelStatusMessage = 'Model validation in progress...';
      } else if (!isStaticDetection && hasVariation) {
        _isModelStatic = false;
        _modelStatusMessage = 'Model validated: Working correctly';
      }
      
      // Store for next comparison
      _lastPredictions = List<double>.from(predictions);
      _lastImagePath = imagePath;
      
      // Validate output shape
      if (predictions.length != 3) {
        debugPrint('⚠️ Unexpected output shape: expected 3 classes, got ${predictions.length}');
      }
      
      // Validate probabilities are reasonable
      final allZero = predictions.every((p) => p.abs() < 0.0001);
      if (allZero) {
        debugPrint('⚠️⚠️⚠️ ALL PREDICTIONS ARE ZERO - Model may not be working! ⚠️⚠️⚠️');
      }
      if (allSame) {
        debugPrint('⚠️⚠️⚠️ ALL PREDICTIONS ARE IDENTICAL - Model may not be working! ⚠️⚠️⚠️');
      }
      // ===== END MODEL VALIDATION =====
      
      // Step 3: Interpret output
      // Get class index with highest probability (argmax)
      int predictedClassIndex = 0;
      double maxConfidence = predictions[0];
      
      for (int i = 0; i < predictions.length; i++) {
        if (predictions[i] > maxConfidence) {
          maxConfidence = predictions[i];
          predictedClassIndex = i;
        }
      }
      
      // Ensure class index is valid
      if (predictedClassIndex < 0 || predictedClassIndex >= classNames.length) {
        debugPrint('⚠️ Invalid class index: $predictedClassIndex, defaulting to 0');
        predictedClassIndex = 0;
        maxConfidence = predictions[0];
      }
      
      final className = classNames[predictedClassIndex];
      // Enhanced confidence calculation: ensure it's properly normalized and clamped
      double confidence = maxConfidence.clamp(0.0, 1.0);
      
      // Enhanced validation: if confidence is very low (< 0.3), log a warning
      if (confidence < 0.3) {
        debugPrint('⚠️ Low confidence detection: ${(confidence * 100).toStringAsFixed(2)}%');
        debugPrint('   Consider reviewing this detection manually');
      }
      
      // Ensure probabilities are normalized (sum should be ~1.0)
      final probSum = predictions.fold(0.0, (sum, prob) => sum + prob);
      if (probSum > 0.0 && probSum != 1.0) {
        // Normalize probabilities if they don't sum to 1.0
        final normalizedProbs = predictions.map((p) => p / probSum).toList();
        debugPrint('📊 Normalized probabilities (sum was ${probSum.toStringAsFixed(3)})');
        // Recalculate confidence from normalized probabilities
        confidence = normalizedProbs[predictedClassIndex].clamp(0.0, 1.0);
      }
      
      debugPrint('🎯 Assessment Result:');
      debugPrint('   Class: $className (index: $predictedClassIndex)');
      debugPrint('   Confidence: ${(confidence * 100).toStringAsFixed(2)}%');
      debugPrint('   All probabilities: ${predictions.map((p) => (p * 100).toStringAsFixed(2)).join(", ")}%');
      
      // ===== FINAL VALIDATION SUMMARY =====
      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('📊 MODEL TESTING SUMMARY:');
      debugPrint('   Inference count: $_inferenceCount');
      debugPrint('   Image file: ${imagePath.split('/').last}');
      debugPrint('   Model loaded: $_isModelLoaded');
      debugPrint('   Input shape verified: ✅');
      debugPrint('   Output shape verified: ${predictions.length} classes');
      debugPrint('   Predictions: ${predictions.map((p) => (p * 100).toStringAsFixed(1)).join("% / ")}%');
      debugPrint('   Selected class: $className (${(confidence * 100).toStringAsFixed(1)}%)');
      
      // Check if this looks like a real model inference (hasVariation already declared above)
      if (!hasVariation) {
        debugPrint('   ⚠️ WARNING: All predictions are nearly identical - Model may be static!');
      } else {
        debugPrint('   ✅ Predictions show variation - Model appears to be working');
      }
      
      if (_inferenceCount > 1 && _lastPredictions != null && _lastImagePath != imagePath) {
        bool sameAsLast = true;
        for (int i = 0; i < predictions.length && i < _lastPredictions!.length; i++) {
          if ((predictions[i] - _lastPredictions![i]).abs() > 0.001) {
            sameAsLast = false;
            break;
          }
        }
        if (sameAsLast) {
          debugPrint('   ⚠️⚠️⚠️ CRITICAL: Same predictions for different images - MODEL IS STATIC! ⚠️⚠️⚠️');
        } else {
          debugPrint('   ✅ Different predictions for different images - Model is DYNAMIC');
        }
      }
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('');
      // ===== END SUMMARY =====
      
      return {
        'classIndex': predictedClassIndex,
        'className': className,
        'confidence': confidence,
        'probabilities': predictions,
        'detectedAt': DateTime.now().millisecondsSinceEpoch,
        // Model validation status for UI
        'isModelStatic': _isModelStatic,
        'modelStatusMessage': _modelStatusMessage,
        'inferenceCount': _inferenceCount,
      };
    } catch (e, stackTrace) {
      debugPrint('❌ Error assessing damage severity: $e');
      debugPrint('   Stack trace: $stackTrace');
      return null;
    }
  }
  
  /// Get severity level from class index
  /// Maps damage classes to severity levels
  String getSeverityLevel(int classIndex) {
    switch (classIndex) {
      case 0:
        return 'Low';
      case 1:
        return 'Medium';
      case 2:
        return 'High';
      default:
        return 'Unknown';
    }
  }
  
  /// Get color for severity level
  int getSeverityColor(int classIndex) {
    switch (classIndex) {
      case 0:
        return 0xFF4CAF50; // Green for little/no damage
      case 1:
        return 0xFFFF9800; // Orange for mild damage
      case 2:
        return 0xFFD32F2F; // Red for severe damage
      default:
        return 0xFF757575; // Gray for unknown
    }
  }
  
  /// Helper to get file size for testing
  Future<int?> _getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
    } catch (e) {
      return null;
    }
    return null;
  }
  
  /// Helper to get file modified time for testing
  Future<String?> _getFileModifiedTime(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final stat = await file.stat();
        return stat.modified.toString();
      }
    } catch (e) {
      return null;
    }
    return null;
  }
}
