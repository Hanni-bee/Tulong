import 'dart:io';
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
  
  /// Check if ML model is loaded and available
  bool get isLoaded => _isLoaded && _interpreter != null;
  
  /// Get model input shape
  List<int>? get inputShape {
    if (_interpreter == null) return null;
    return _interpreter!.getInputTensor(0).shape;
  }
  
  /// Get model output shape
  List<int>? get outputShape {
    if (_interpreter == null) return null;
    return _interpreter!.getOutputTensor(0).shape;
  }
  
  /// Load ML model from assets
  /// 
  /// [modelPath] - Path to model file in assets (e.g., 'models/emergency_detector.tflite')
  /// Returns true if model loaded successfully
  Future<bool> loadModel(String modelPath) async {
    try {
      debugPrint('📦 Loading ML model: $modelPath');
      
      // fromAsset expects path WITHOUT 'assets/' prefix
      // If modelPath already includes 'assets/', remove it
      String assetPath = modelPath;
      if (modelPath.startsWith('assets/')) {
        assetPath = modelPath.substring(7); // Remove 'assets/' prefix
      }
      
      debugPrint('   Asset path: $assetPath');
      
      // Verify file exists in assets first
      try {
        final ByteData data = await rootBundle.load('assets/$assetPath');
        debugPrint('   ✅ Model file found in assets (${data.lengthInBytes} bytes)');
      } catch (e) {
        debugPrint('   ❌ Model file not found in assets: $e');
        return false;
      }
      
      // Load interpreter using fromAsset (it handles assets path internally)
      final options = tflite.InterpreterOptions()
        ..threads = 4;
      // Note: GPU delegate can be enabled here if needed for better performance
      
      debugPrint('   Loading TFLite interpreter from asset: $assetPath');
      try {
        // Try loading with the asset path (without assets/ prefix)
        _interpreter = await tflite.Interpreter.fromAsset(
          assetPath,
          options: options,
        );
        debugPrint('   ✅ Successfully loaded with path: $assetPath');
      } catch (e1) {
        debugPrint('   ⚠️ First attempt failed: $e1');
        // Try with assets/ prefix if first attempt failed
        try {
          debugPrint('   Retrying with assets/ prefix...');
          _interpreter = await tflite.Interpreter.fromAsset(
            'assets/$assetPath',
            options: options,
          );
          debugPrint('   ✅ Successfully loaded with path: assets/$assetPath');
        } catch (e2) {
          debugPrint('   ❌ Both attempts failed');
          debugPrint('   Attempt 1 error: $e1');
          debugPrint('   Attempt 2 error: $e2');
          debugPrint('   Model file might be corrupted or path is incorrect');
          _isLoaded = false;
          _interpreter = null;
          return false;
        }
      }
      
      _isLoaded = true;
      
      // Validate model loaded correctly
      if (_interpreter == null) {
        debugPrint('❌ Interpreter is null after loading');
        _isLoaded = false;
        return false;
      }
      
      debugPrint('   ✅ TFLite interpreter created successfully');
      
      final actualInputShape = inputShape;
      final actualOutputShape = outputShape;
      
      if (actualInputShape == null || actualOutputShape == null) {
        debugPrint('❌ Cannot get model shapes - model may not be loaded correctly');
        _isLoaded = false;
        _interpreter = null;
        return false;
      }
      
      debugPrint('✅ ML Model loaded successfully: $modelPath');
      debugPrint('   Input shape: $actualInputShape');
      debugPrint('   Output shape: $actualOutputShape');
      debugPrint('   Expected input size: ${actualInputShape.reduce((a, b) => a * b)}');
      debugPrint('   Expected output size: ${actualOutputShape.reduce((a, b) => a * b)}');
      
      // Validate output shape has 3 classes for damage severity
      final outputSize = actualOutputShape.reduce((a, b) => a * b);
      if (outputSize != 3) {
        debugPrint('⚠️ WARNING: Model output size is $outputSize, expected 3 classes');
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ Failed to load ML model: $e');
      _isLoaded = false;
      _interpreter = null;
      return false;
    }
  }
  
  /// Extract features from preprocessed image using ML model
  /// 
  /// [preprocessedImage] - Normalized Float32List (224x224x3)
  /// Returns feature vector or null if model not loaded
  Future<Float32List?> extractFeatures(Float32List preprocessedImage) async {
    if (!isLoaded || _interpreter == null) {
      debugPrint('⚠️ ML model not loaded, returning null');
      return null;
    }
    
    try {
      if (_interpreter == null) {
        debugPrint('❌ Interpreter is null');
        return null;
      }
      
      // Prepare input/output buffers
      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);
      
      // Reshape input if needed (ensure it matches model input shape)
      final inputShape = inputTensor.shape;
      final expectedSize = inputShape[0] * inputShape[1] * inputShape[2];
      
      if (preprocessedImage.length != expectedSize) {
        debugPrint('❌ Input size mismatch: expected $expectedSize, got ${preprocessedImage.length}');
        return null;
      }
      
      // Prepare input/output buffers
      final inputBuffer = [preprocessedImage];
      final outputBuffer = [
        Float32List(outputTensor.shape.reduce((a, b) => a * b))
      ];
      
      // Run inference
      _interpreter!.run(inputBuffer, outputBuffer);
      
      // Return feature vector
      return outputBuffer[0];
    } catch (e) {
      debugPrint('❌ Error during ML inference: $e');
      return null;
    }
  }
  
  /// Run full classification using ML model (if model outputs probabilities)
  /// 
  /// [preprocessedImage] - Normalized Float32List (224x224x3)
  /// Returns classification probabilities or null
  Future<List<double>?> classify(Float32List preprocessedImage) async {
    // STRICT CHECK: Don't run inference if model is not loaded
    if (!isLoaded || _interpreter == null) {
      debugPrint('❌❌❌ ML model not loaded - inference BLOCKED');
      debugPrint('   isLoaded: $isLoaded');
      debugPrint('   _interpreter is null: ${_interpreter == null}');
      return null;
    }
    
    try {
      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);
      
      // Ensure input matches expected shape [1, 224, 224, 3]
      final inputShape = inputTensor.shape;
      final expectedSize = inputShape[0] * inputShape[1] * inputShape[2] * (inputShape.length > 3 ? inputShape[3] : 1);
      
      debugPrint('🔍 ML MODEL CLASSIFY DEBUG:');
      debugPrint('   Model input shape: $inputShape');
      debugPrint('   Expected input size: $expectedSize');
      debugPrint('   Actual input size: ${preprocessedImage.length}');
      debugPrint('   Model output shape: ${outputTensor.shape}');
      
      if (preprocessedImage.length != expectedSize) {
        debugPrint('❌ Input size mismatch: expected $expectedSize, got ${preprocessedImage.length}');
        return null;
      }
      
      // Validate input data is not all zeros or all same
      final inputMin = preprocessedImage.reduce((a, b) => a < b ? a : b);
      final inputMax = preprocessedImage.reduce((a, b) => a > b ? a : b);
      final inputMean = preprocessedImage.reduce((a, b) => a + b) / preprocessedImage.length;
      debugPrint('   Input data range: [$inputMin, $inputMax], mean: ${inputMean.toStringAsFixed(4)}');
      
      if ((inputMax - inputMin).abs() < 0.0001) {
        debugPrint('⚠️⚠️⚠️ WARNING: Input data is constant (all same values) - preprocessing may be broken! ⚠️⚠️⚠️');
      }
      
      // Prepare input/output buffers with batch dimension
      final inputBuffer = [preprocessedImage];
      final outputSize = outputTensor.shape.reduce((a, b) => a * b);
      final outputBuffer = [Float32List(outputSize)];
      
      debugPrint('   Running inference...');
      final stopwatch = Stopwatch()..start();
      
      // Run inference
      _interpreter!.run(inputBuffer, outputBuffer);
      
      stopwatch.stop();
      debugPrint('   Inference completed in ${stopwatch.elapsedMilliseconds}ms');
      
      // Validate output is not all zeros
      final outputRaw = outputBuffer[0];
      final outputMin = outputRaw.reduce((a, b) => a < b ? a : b);
      final outputMax = outputRaw.reduce((a, b) => a > b ? a : b);
      debugPrint('   Output raw range: [$outputMin, $outputMax]');
      
      if (outputRaw.every((v) => v.abs() < 0.0001)) {
        debugPrint('⚠️⚠️⚠️ WARNING: Model output is all zeros - model may not be working! ⚠️⚠️⚠️');
      }
      
      // Convert to List<double> and return probabilities
      final probabilities = outputRaw.map((e) => e.toDouble()).toList();
      debugPrint('   Converted probabilities: $probabilities');
      
      return probabilities;
    } catch (e) {
      debugPrint('❌ Error during ML classification: $e');
      return null;
    }
  }
  
  /// Dispose resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
    debugPrint('🧹 ML Model service disposed');
  }
}

