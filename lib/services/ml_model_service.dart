import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tflite;

/// Service for loading and running ML models for emergency detection
/// Currently supports TensorFlow Lite models
class MLModelService {
  static MLModelService? _instance;
  static MLModelService get instance => _instance ??= MLModelService._();
  
  MLModelService._();
  
  tflite.Interpreter? _interpreter;
  bool _isLoaded = false;
  String? _lastError;
  
  /// Check if ML model is loaded and available
  bool get isLoaded => _isLoaded && _interpreter != null;
  
  /// Get last error message
  String? get lastError => _lastError;
  
  /// Get model input shape
  List<int>? get inputShape {
    if (_interpreter == null) return null;
    try {
      return _interpreter!.getInputTensor(0).shape;
    } catch (e) {
      debugPrint('Error getting input shape: $e');
      return null;
    }
  }
  
  /// Get model output shape
  List<int>? get outputShape {
    if (_interpreter == null) return null;
    try {
      return _interpreter!.getOutputTensor(0).shape;
    } catch (e) {
      debugPrint('Error getting output shape: $e');
      return null;
    }
  }
  
  /// Load ML model from assets
  /// 
  /// [modelPath] - Path to model file in assets (e.g., 'best_model.tflite')
  /// Returns true if model loaded successfully
  Future<bool> loadModel(String modelPath) async {
    try {
      _lastError = null;
      
      // CRITICAL: Ensure modelPath is correctly formatted for fromAsset
      // fromAsset expects: 'best_model.tflite' (relative to assets folder, NO "assets/" prefix)
      // File location: assets/best_model.tflite (WITH underscore between "best" and "model")
      String assetPath = modelPath.trim();
      
      // Remove 'assets/' prefix if present
      if (assetPath.startsWith('assets/')) {
        assetPath = assetPath.substring(7);
      }
      
      // Remove leading slash if present
      if (assetPath.startsWith('/')) {
        assetPath = assetPath.substring(1);
      }
      
      // CRITICAL: Verify and correct the path to 'best_model.tflite' (with underscore)
      // The actual file is assets/best_model.tflite (with underscore between "best" and "model")
      // Common mistake: "bestmodel.tflite" (no underscore) - this will fail!
      if (assetPath != 'best_model.tflite') {
        debugPrint('⚠️ WARNING: Asset path mismatch detected!');
        debugPrint('   Provided path: "$assetPath"');
        debugPrint('   Expected path: "best_model.tflite" (with underscore)');
        debugPrint('   Actual file: assets/best_model.tflite');
        // Force correct path - this is critical!
        assetPath = 'best_model.tflite';
        debugPrint('   ✅ Corrected to: "$assetPath"');
      }
      
      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('🔄 ML MODEL LOADING - COMPREHENSIVE DEBUG');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('📁 Requested model path: $modelPath');
      debugPrint('📁 Asset path (for fromAsset): $assetPath');
      debugPrint('📁 Full asset path: assets/$assetPath');
      debugPrint('📁 File must exist at: assets/best_model.tflite (with underscore)');
      
      // Step 1: Verify asset exists in bundle
      debugPrint('📦 Step 1: Verifying asset exists in bundle...');
      try {
        final ByteData data = await rootBundle.load('assets/$assetPath');
        final int assetSize = data.lengthInBytes;
        debugPrint('✅ Asset found in bundle: assets/$assetPath');
        debugPrint('   Asset size: ${(assetSize / 1024 / 1024).toStringAsFixed(2)} MB');
        
        if (assetSize == 0) {
          _lastError = 'Asset file is empty';
          debugPrint('❌ Asset file is empty!');
          return false;
        }
      } catch (e) {
        _lastError = 'Asset not found in bundle: $e';
        debugPrint('❌ Asset NOT found in bundle: assets/$assetPath');
        debugPrint('   Error: $e');
        debugPrint('   Make sure:');
        debugPrint('   1. File exists at: assets/$assetPath');
        debugPrint('   2. pubspec.yaml includes: - assets/$assetPath');
        debugPrint('   3. Run: flutter clean && flutter pub get');
        return false;
      }
      
      // Step 2: Load interpreter from asset
      debugPrint('📦 Step 2: Loading TFLite interpreter from asset...');
      debugPrint('   Using asset path: $assetPath');
      debugPrint('   Full path for fromAsset: $assetPath (should NOT include "assets/")');
      
      // CRITICAL: fromAsset expects path relative to assets folder WITHOUT "assets/" prefix
      // Example: 'best_model.tflite' not 'assets/best_model.tflite'
      final options = tflite.InterpreterOptions()
        ..threads = 4;
      // Note: GPU delegate can be enabled here if needed for better performance
      
      try {
        debugPrint('   Calling tflite.Interpreter.fromAsset("$assetPath")...');
        _interpreter = await tflite.Interpreter.fromAsset(
          assetPath, // Must be 'best_model.tflite' not 'assets/best_model.tflite'
          options: options,
        );
        debugPrint('   ✅ Interpreter created successfully');
        
        if (_interpreter == null) {
          _lastError = 'Interpreter is null after loading';
          debugPrint('❌ Interpreter is null after loading');
          _isLoaded = false;
          return false;
        }
        
        debugPrint('✅ Interpreter created successfully');
      } catch (e, stackTrace) {
        _lastError = 'Failed to create interpreter: $e';
        debugPrint('❌ CRITICAL: Failed to create TFLite interpreter');
        debugPrint('   Error: $e');
        debugPrint('   Asset path used: $assetPath');
        debugPrint('   Full asset path: assets/$assetPath');
        debugPrint('   Stack trace: $stackTrace');
        debugPrint('');
        debugPrint('🔧 TROUBLESHOOTING STEPS:');
        debugPrint('   1. Verify file exists: assets/best_model.tflite (with underscore)');
        debugPrint('   2. Check pubspec.yaml includes: - assets/best_model.tflite');
        debugPrint('   3. Run: flutter clean && flutter pub get');
        debugPrint('   4. Verify Android build.gradle.kts has noCompress for .tflite');
        debugPrint('   5. Check file is not corrupted (should be ~14.5 MB)');
        debugPrint('   6. Ensure file name is exactly: best_model.tflite (with underscore)');
        _isLoaded = false;
        _interpreter = null;
        return false;
      }
      
      // Step 3: Verify interpreter is initialized
      debugPrint('📦 Step 3: Verifying interpreter initialization...');
      try {
        final inputTensor = _interpreter!.getInputTensor(0);
        final outputTensor = _interpreter!.getOutputTensor(0);
        
        final inputShape = inputTensor.shape;
        final outputShape = outputTensor.shape;
        final inputType = inputTensor.type;
        final outputType = outputTensor.type;
        
        debugPrint('✅ Interpreter initialized successfully');
        debugPrint('   Input tensor:');
        debugPrint('     Shape: $inputShape');
        debugPrint('     Type: $inputType');
        debugPrint('     Size: ${inputShape.reduce((a, b) => a * b)} elements');
        debugPrint('   Output tensor:');
        debugPrint('     Shape: $outputShape');
        debugPrint('     Type: $outputType');
        debugPrint('     Size: ${outputShape.reduce((a, b) => a * b)} elements');
        
        // Verify expected input shape (should be [1, 224, 224, 3] or [224, 224, 3])
        final expectedInputSize = 224 * 224 * 3;
        final actualInputSize = inputShape.length > 1
            ? inputShape.sublist(1).reduce((a, b) => a * b)  // Skip batch dimension
            : inputShape.reduce((a, b) => a * b);
        
        if (actualInputSize != expectedInputSize) {
          debugPrint('⚠️ Warning: Input size mismatch');
          debugPrint('   Expected: $expectedInputSize (224x224x3)');
          debugPrint('   Actual: $actualInputSize');
        } else {
          debugPrint('✅ Input size matches expected: $expectedInputSize');
        }
        
        // Verify expected output shape (should be [1, 4] or [4] for 4 classes)
        final expectedOutputSize = 4;
        final actualOutputSize = outputShape.length > 1
            ? outputShape.sublist(1).reduce((a, b) => a * b)  // Skip batch dimension
            : outputShape.reduce((a, b) => a * b);
        
        if (actualOutputSize != expectedOutputSize) {
          debugPrint('⚠️ Warning: Output size mismatch');
          debugPrint('   Expected: $expectedOutputSize (4 classes)');
          debugPrint('   Actual: $actualOutputSize');
        } else {
          debugPrint('✅ Output size matches expected: $expectedOutputSize');
        }
        
      } catch (e, stackTrace) {
        _lastError = 'Failed to verify interpreter: $e';
        debugPrint('❌ Failed to verify interpreter initialization: $e');
        debugPrint('   Stack trace: $stackTrace');
        _isLoaded = false;
        _interpreter = null;
        return false;
      }
      
      _isLoaded = true;
      
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('✅ ML MODEL LOADED SUCCESSFULLY');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('');
      
      return true;
    } catch (e, stackTrace) {
      _lastError = 'Unexpected error loading model: $e';
      debugPrint('❌ Unexpected error loading ML model: $e');
      debugPrint('   Stack trace: $stackTrace');
      _isLoaded = false;
      _interpreter = null;
      return false;
    }
  }
  
  /// Run full classification using ML model
  /// 
  /// [preprocessedImage] - Normalized Float32List (224x224x3 = 150528 values)
  /// Returns classification probabilities or null
  Future<List<double>?> classify(Float32List preprocessedImage) async {
    if (!isLoaded || _interpreter == null) {
      debugPrint('⚠️ ML model not loaded, cannot classify');
      return null;
    }
    
    try {
      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);
      
      // Get input shape (usually [1, 224, 224, 3] for batch, height, width, channels)
      final inputShape = inputTensor.shape;
      final expectedSize = inputShape.length > 1
          ? inputShape.sublist(1).reduce((a, b) => a * b)  // Skip batch dimension
          : inputShape.reduce((a, b) => a * b);
      
      // Verify input size matches (accounting for batch dimension)
      if (preprocessedImage.length != expectedSize) {
        debugPrint('❌ Input size mismatch in classify:');
        debugPrint('   Expected: $expectedSize');
        debugPrint('   Got: ${preprocessedImage.length}');
        debugPrint('   Input shape: $inputShape');
        return null;
      }
      
      // CRITICAL: Prepare input buffer correctly
      // TFLite expects input to match tensor shape exactly
      // If tensor is [1, 224, 224, 3], we need to reshape the flat array
      debugPrint('📐 Input tensor shape: $inputShape');
      debugPrint('📐 Preprocessed image length: ${preprocessedImage.length}');
      
      // Reshape the flat array to match tensor shape
      // For shape [1, 224, 224, 3], we need to create a properly shaped buffer
      final inputBuffer = [preprocessedImage];
      
      // Verify input buffer size matches expected
      // The preprocessedImage is [224*224*3] = 150,528 elements (without batch dimension)
      // The input tensor shape is [1, 224, 224, 3] = 150,528 elements (with batch dimension)
      // tflite_flutter handles the batch dimension automatically when we wrap in [preprocessedImage]
      final expectedInputElements = inputShape.reduce((a, b) => a * b); // Full tensor size including batch
      final expectedNonBatchSize = inputShape.sublist(1).reduce((a, b) => a * b); // Size without batch
      
      // Preprocessed image should match non-batch size (150,528)
      if (preprocessedImage.length != expectedNonBatchSize) {
        debugPrint('❌ CRITICAL: Input size mismatch!');
        debugPrint('   Tensor shape: $inputShape');
        debugPrint('   Tensor expects (with batch): $expectedInputElements elements');
        debugPrint('   Tensor expects (without batch): $expectedNonBatchSize elements');
        debugPrint('   Preprocessed image has: ${preprocessedImage.length} elements');
        debugPrint('   Expected: $expectedNonBatchSize (224 * 224 * 3)');
        return null;
      }
      
      debugPrint('✅ Input size verified: ${preprocessedImage.length} elements (matches $expectedNonBatchSize)');
      
      // Prepare output buffer
      final outputSize = outputTensor.shape.reduce((a, b) => a * b);
      final outputBuffer = [Float32List(outputSize)];
      
      // Run inference - THIS IS DYNAMIC, RUNS FRESH EVERY TIME
      debugPrint('🔄 Running TFLite inference (dynamic, no caching)...');
      debugPrint('   Input buffer size: ${inputBuffer[0].length}');
      debugPrint('   Output buffer size: ${outputBuffer[0].length}');
      final inferenceStartTime = DateTime.now();
      
      try {
        _interpreter!.run(inputBuffer, outputBuffer);
      } catch (e, stackTrace) {
        debugPrint('❌ CRITICAL: Inference failed with error: $e');
        debugPrint('   Stack trace: $stackTrace');
        debugPrint('   Input shape: $inputShape');
        debugPrint('   Input buffer length: ${inputBuffer[0].length}');
        debugPrint('   Output shape: ${outputTensor.shape}');
        return null;
      }
      
      final inferenceDuration = DateTime.now().difference(inferenceStartTime);
      debugPrint('✅ TFLite inference completed in ${inferenceDuration.inMilliseconds}ms');
      
      // Extract probabilities (handle batch dimension if present)
      final output = outputBuffer[0];
      debugPrint('📊 Raw output buffer size: ${output.length}');
      debugPrint('📊 Output tensor shape: ${outputTensor.shape}');
      
      // If output has batch dimension [1, num_classes], take first element
      // Otherwise, use output directly
      List<double> probabilities;
      if (outputTensor.shape.length > 1 && outputTensor.shape[0] == 1) {
        // Has batch dimension, extract first batch
        final numClasses = outputTensor.shape.sublist(1).reduce((a, b) => a * b);
        probabilities = output.sublist(0, numClasses).map((e) => e.toDouble()).toList();
        debugPrint('📊 Extracted ${probabilities.length} probabilities from batch dimension');
      } else {
        // No batch dimension, use directly
        probabilities = output.map((e) => e.toDouble()).toList();
        debugPrint('📊 Using ${probabilities.length} probabilities directly');
      }
      
      // Log raw output for verification
      debugPrint('📊 Raw Model Output Values:');
      for (int i = 0; i < probabilities.length && i < 4; i++) {
        debugPrint('   Output[$i]: ${probabilities[i].toStringAsFixed(6)}');
      }
      
      return probabilities;
    } catch (e, stackTrace) {
      debugPrint('❌ Error during ML classification: $e');
      debugPrint('   Stack trace: $stackTrace');
      return null;
    }
  }
  
  /// Extract features from preprocessed image using ML model
  /// 
  /// [preprocessedImage] - Normalized Float32List (224x224x3)
  /// Returns feature vector or null if model not loaded
  Future<Float32List?> extractFeatures(Float32List preprocessedImage) async {
    // For classification models, use classify instead
    final probabilities = await classify(preprocessedImage);
    if (probabilities == null) return null;
    return Float32List.fromList(probabilities.map((e) => e.toDouble()).toList());
  }
  
  /// Test model with dummy input to verify it works
  Future<bool> testModel() async {
    if (!isLoaded || _interpreter == null) {
      debugPrint('⚠️ Model not loaded, cannot test');
      return false;
    }
    
    try {
      debugPrint('🧪 Testing model with dummy input...');
      
      // Create dummy input (224x224x3 = 150528 values, all zeros)
      final dummyInput = Float32List(224 * 224 * 3);
      
      final result = await classify(dummyInput);
      
      if (result != null && result.length > 0) {
        debugPrint('✅ Model test successful - got ${result.length} outputs');
        return true;
      } else {
        debugPrint('❌ Model test failed - no output');
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Model test error: $e');
      debugPrint('   Stack trace: $stackTrace');
      return false;
    }
  }
  
  /// Dispose resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
    _lastError = null;
    debugPrint('🧹 ML Model service disposed');
  }
}
