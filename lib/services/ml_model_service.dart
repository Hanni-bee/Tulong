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
      // Check if model file exists in assets
      final ByteData data = await rootBundle.load('assets/$modelPath');
      final Uint8List bytes = data.buffer.asUint8List();
      
      // Create temporary file (TFLite needs a file path, not bytes)
      final Directory tempDir = Directory.systemTemp;
      final File tempFile = File('${tempDir.path}/emergency_model.tflite');
      await tempFile.writeAsBytes(bytes);
      
      // Load interpreter
      final options = tflite.InterpreterOptions()
        ..threads = 4;
      // Note: GPU delegate can be enabled here if needed for better performance
      
      _interpreter = await tflite.Interpreter.fromAsset(
        modelPath,
        options: options,
      );
      
      _isLoaded = true;
      
      debugPrint('✅ ML Model loaded successfully: $modelPath');
      debugPrint('   Input shape: $inputShape');
      debugPrint('   Output shape: $outputShape');
      
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
    final features = await extractFeatures(preprocessedImage);
    if (features == null) return null;
    
    // If model outputs probabilities directly, return them
    // Otherwise, return feature vector for further processing
    return features.map((e) => e.toDouble()).toList();
  }
  
  /// Dispose resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
    debugPrint('🧹 ML Model service disposed');
  }
}

