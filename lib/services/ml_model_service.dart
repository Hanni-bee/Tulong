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
  /// Returns true if model loaded successfully AND functions properly
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
      debugPrint('   Input shape: ${inputShape}');
      debugPrint('   Output shape: ${outputShape}');
      
      // Validate that model actually works by running a test inference
      final isValid = await _validateModel();
      if (!isValid) {
        debugPrint('⚠️ Model loaded but validation failed - model may not function correctly');
        _isLoaded = false;
        _interpreter?.close();
        _interpreter = null;
        return false;
      }
      
      debugPrint('✅ ML Model validation passed - model is functional');
      
      return true;
    } catch (e) {
      debugPrint('❌ Failed to load ML model: $e');
      _isLoaded = false;
      _interpreter?.close();
      _interpreter = null;
      return false;
    }
  }
  
  /// Validate that the loaded model actually works by running a test inference
  /// Returns true if model runs inference successfully
  Future<bool> _validateModel() async {
    if (_interpreter == null) {
      debugPrint('❌ Cannot validate: interpreter is null');
      return false;
    }
    
    try {
      // Get input/output shapes
      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);
      final inputShape = inputTensor.shape;
      final outputShape = outputTensor.shape;
      
      if (inputShape.isEmpty || outputShape.isEmpty) {
        debugPrint('❌ Invalid model shapes: input=$inputShape, output=$outputShape');
        return false;
      }
      
      // Calculate expected input size
      final expectedInputSize = inputShape.reduce((a, b) => a * b);
      
      // Create dummy test input (all zeros - normalized image would be in [0,1] range)
      final testInput = Float32List(expectedInputSize);
      for (int i = 0; i < expectedInputSize; i++) {
        testInput[i] = 0.5; // Neutral value in normalized range
      }
      
      // Prepare output buffer
      final outputSize = outputShape.reduce((a, b) => a * b);
      final testOutput = Float32List(outputSize);
      
      // Run test inference
      _interpreter!.run([testInput], [testOutput]);
      
      // Validate output - check for NaN or infinite values
      bool hasValidOutput = true;
      for (int i = 0; i < outputSize; i++) {
        final value = testOutput[i];
        if (value.isNaN || value.isInfinite) {
          debugPrint('❌ Model output contains invalid values (NaN or Infinite) at index $i');
          hasValidOutput = false;
          break;
        }
      }
      
      if (!hasValidOutput) {
        return false;
      }
      
      // Check that output has reasonable values (not all zeros or all same value)
      final outputMin = testOutput.reduce((a, b) => a < b ? a : b);
      final outputMax = testOutput.reduce((a, b) => a > b ? a : b);
      
      if (outputMax == outputMin) {
        debugPrint('⚠️ Model output is constant (all values are the same)');
        // This might be okay for some models, but log it
      }
      
      debugPrint('✅ Model validation successful:');
      debugPrint('   Input shape: $inputShape');
      debugPrint('   Output shape: $outputShape');
      debugPrint('   Output range: [$outputMin, $outputMax]');
      debugPrint('   Output size: $outputSize');
      
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Model validation failed: $e');
      debugPrint('   Stack trace: $stackTrace');
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
      // Calculate expected size based on actual shape (handle different dimensions)
      int expectedSize = 1;
      for (int i = 1; i < inputShape.length; i++) {
        expectedSize *= inputShape[i];
      }
      
      if (preprocessedImage.length != expectedSize) {
        debugPrint('❌ Input size mismatch: expected $expectedSize (from shape $inputShape), got ${preprocessedImage.length}');
        return null;
      }
      
      // Prepare input/output buffers
      final inputBuffer = [preprocessedImage];
      final outputSize = outputTensor.shape.reduce((a, b) => a * b);
      final outputBuffer = [Float32List(outputSize)];
      
      // Run inference with error handling
      _interpreter!.run(inputBuffer, outputBuffer);
      
      // Validate output
      final output = outputBuffer[0];
      bool hasInvalidValues = false;
      for (int i = 0; i < output.length; i++) {
        if (output[i].isNaN || output[i].isInfinite) {
          debugPrint('❌ ML inference produced invalid value at index $i: ${output[i]}');
          hasInvalidValues = true;
        }
      }
      
      if (hasInvalidValues) {
        debugPrint('⚠️ ML inference produced invalid values, returning null');
        return null;
      }
      
      debugPrint('✅ ML features extracted successfully: ${output.length} features');
      
      // Return feature vector
      return output;
    } catch (e, stackTrace) {
      debugPrint('❌ Error during ML inference: $e');
      debugPrint('   Stack trace: $stackTrace');
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
  
  /// Analyze disaster intensity using the Disaster Intensity Analyzer model
  /// 
  /// [preprocessedImage] - Normalized Float32List (224x224x3)
  /// Returns map with intensity scores for different disaster types and overall intensity
  Future<Map<String, double>?> analyzeDisasterIntensity(Float32List preprocessedImage) async {
    if (!isLoaded || _interpreter == null) {
      debugPrint('⚠️ ML model not loaded, cannot analyze disaster intensity');
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
      
      // Reshape input if needed
      final inputShape = inputTensor.shape;
      // Calculate expected size: multiply all dimensions except batch (first dimension)
      int expectedSize = 1;
      for (int i = 1; i < inputShape.length; i++) {
        expectedSize *= inputShape[i];
      }
      
      if (preprocessedImage.length != expectedSize) {
        debugPrint('❌ Input size mismatch: expected $expectedSize (from shape $inputShape), got ${preprocessedImage.length}');
        return null;
      }
      
      // Prepare input/output buffers
      final inputBuffer = [preprocessedImage];
      final outputSize = outputTensor.shape.reduce((a, b) => a * b);
      final outputBuffer = [Float32List(outputSize)];
      
      // Run inference with error handling
      try {
        _interpreter!.run(inputBuffer, outputBuffer);
      } catch (e) {
        debugPrint('❌ Error running ML inference: $e');
        return null;
      }
      
      final output = outputBuffer[0];
      
      // Validate output for invalid values
      bool hasInvalidValues = false;
      for (int i = 0; i < output.length; i++) {
        if (output[i].isNaN || output[i].isInfinite) {
          debugPrint('❌ ML intensity analysis produced invalid value at index $i: ${output[i]}');
          hasInvalidValues = true;
        }
      }
      
      if (hasInvalidValues) {
        debugPrint('⚠️ ML intensity analysis produced invalid values');
        return null;
      }
      
      // DYNAMIC: Parse output based on model structure (adapts to any model architecture)
      // Handles various output formats: single value, array, multi-dimensional
      final outputShape = outputTensor.shape;
      
      Map<String, double> intensityResults = {};
      List<double> outputValues = output.map((e) => e.toDouble()).toList();
      
      // Calculate statistics for dynamic interpretation
      final outputMean = outputValues.reduce((a, b) => a + b) / outputSize;
      final outputMax = outputValues.reduce((a, b) => a > b ? a : b);
      final outputMin = outputValues.reduce((a, b) => a < b ? a : b);
      final outputVariance = _calculateVariance(outputValues);
      final outputRange = outputMax - outputMin;
      
      // DYNAMIC: Determine output format based on shape and values
      if (outputShape.length == 1 || (outputShape.length == 2 && outputShape[1] == 1)) {
        // Single output - overall intensity
        // Normalize dynamically based on value range
        final normalizedIntensity = outputRange > 0 
            ? ((output[0] - outputMin) / outputRange).clamp(0.0, 1.0)
            : output[0].clamp(0.0, 1.0);
        intensityResults['overall_intensity'] = normalizedIntensity;
      } else if (outputShape.length == 2) {
        // Multiple outputs - disaster type intensities
        final numOutputs = outputShape[1];
        
        // DYNAMIC: Map outputs based on count and values
        if (numOutputs >= 4) {
          // Standard format: [earthquake, wind, wildfire, flood, ...]
          intensityResults['earthquake_intensity'] = _normalizeOutput(output[0], outputMin, outputMax, outputRange);
          if (outputSize > 1) intensityResults['wind_intensity'] = _normalizeOutput(output[1], outputMin, outputMax, outputRange);
          if (outputSize > 2) intensityResults['wildfire_intensity'] = _normalizeOutput(output[2], outputMin, outputMax, outputRange);
          if (outputSize > 3) intensityResults['flood_intensity'] = _normalizeOutput(output[3], outputMin, outputMax, outputRange);
          
          // Calculate overall intensity dynamically
          if (outputSize > 4) {
            intensityResults['overall_intensity'] = _normalizeOutput(output[4], outputMin, outputMax, outputRange);
          } else {
            // Average of type-specific intensities (count only type-specific keys)
            final typeIntensities = [
              intensityResults['earthquake_intensity']!,
              intensityResults['wind_intensity'] ?? 0.0,
              intensityResults['wildfire_intensity'] ?? 0.0,
              intensityResults['flood_intensity'] ?? 0.0,
            ];
            final validIntensities = typeIntensities.where((v) => v > 0).toList();
            final avgIntensity = validIntensities.isNotEmpty
                ? validIntensities.reduce((a, b) => a + b) / validIntensities.length
                : typeIntensities.reduce((a, b) => a + b) / typeIntensities.length;
            intensityResults['overall_intensity'] = avgIntensity.clamp(0.0, 1.0);
          }
        } else {
          // Fewer outputs - map dynamically
          for (int i = 0; i < outputSize; i++) {
            intensityResults['intensity_$i'] = _normalizeOutput(output[i], outputMin, outputMax, outputRange);
          }
          intensityResults['overall_intensity'] = outputMean.clamp(0.0, 1.0);
        }
      } else {
        // Multi-dimensional or feature vector - use statistical approach
        // Normalize each value and calculate aggregate metrics
        final normalizedValues = outputValues.map((v) => 
          outputRange > 0 ? ((v - outputMin) / outputRange).clamp(0.0, 1.0) : v.clamp(0.0, 1.0)
        ).toList();
        
        intensityResults['overall_intensity'] = (normalizedValues.reduce((a, b) => a + b) / normalizedValues.length).clamp(0.0, 1.0);
        intensityResults['intensity_variance'] = _calculateVariance(normalizedValues);
        intensityResults['intensity_max'] = normalizedValues.reduce((a, b) => a > b ? a : b);
        intensityResults['intensity_min'] = normalizedValues.reduce((a, b) => a < b ? a : b);
        
        // If we have enough values, try to infer types (first 4 could be disaster types)
        if (normalizedValues.length >= 4) {
          intensityResults['earthquake_intensity'] = normalizedValues[0];
          if (normalizedValues.length > 1) intensityResults['wind_intensity'] = normalizedValues[1];
          if (normalizedValues.length > 2) intensityResults['wildfire_intensity'] = normalizedValues[2];
          if (normalizedValues.length > 3) intensityResults['flood_intensity'] = normalizedValues[3];
        }
      }
      
      // Always add variance for dynamic weighting
      if (!intensityResults.containsKey('intensity_variance')) {
        intensityResults['intensity_variance'] = outputVariance;
      }
      
      debugPrint('✅ Disaster intensity analyzed: $intensityResults');
      return intensityResults;
    } catch (e) {
      debugPrint('❌ Error during disaster intensity analysis: $e');
      return null;
    }
  }
  
  /// Calculate variance of a list of numbers
  double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / values.length;
    return variance;
  }
  
  /// Normalize output value dynamically based on range
  double _normalizeOutput(double value, double min, double max, double range) {
    if (range > 0) {
      return ((value - min) / range).clamp(0.0, 1.0);
    } else {
      // No range variation - use value directly (already normalized or constant)
      return value.clamp(0.0, 1.0);
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

