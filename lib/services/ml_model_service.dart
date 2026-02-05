import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tflite;

/// Service for loading and running ML models for emergency detection
/// Uses TensorFlow Lite for on-device inference
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
      return null;
    }
  }
  
  /// Get model output shape
  List<int>? get outputShape {
    if (_interpreter == null) return null;
    try {
      return _interpreter!.getOutputTensor(0).shape;
    } catch (e) {
      return null;
    }
  }
  
  /// Load ML model from assets
  /// Returns true if model loaded successfully
  Future<bool> loadModel(String modelPath) async {
    if (_isLoaded && _interpreter != null) {
      return true;
    }
    
    _lastError = null;
    String assetPath = modelPath.trim();
    
    // Remove 'assets/' prefix if present
    if (assetPath.startsWith('assets/')) {
      assetPath = assetPath.substring(7);
    }
    
    // Remove leading slash if present
    if (assetPath.startsWith('/')) {
      assetPath = assetPath.substring(1);
    }
    
    try {
      // Verify asset exists
      try {
        await rootBundle.load('assets/$assetPath');
      } catch (e) {
        _lastError = 'Asset not found: $e';
        debugPrint('Model asset not found: assets/$assetPath');
        return false;
      }
      
      // Load model - try fromAsset first, fallback to fromFile
      final options = tflite.InterpreterOptions()..threads = 4;
      
      try {
        // Method 1: Load from asset
        _interpreter = await tflite.Interpreter.fromAsset(
          assetPath,
          options: options,
        );
        
        if (_interpreter == null) {
          throw Exception('Interpreter is null after fromAsset');
        }
      } catch (fromAssetError) {
        // Method 2: Fallback - copy to internal storage and load from file
        try {
          final ByteData assetData = await rootBundle.load('assets/$assetPath');
          final List<int> bytes = assetData.buffer.asUint8List();
          
          final Directory appDir = await getApplicationDocumentsDirectory();
          final String filePath = '${appDir.path}/$assetPath';
          final File modelFile = File(filePath);
          
          if (!await modelFile.exists() || await modelFile.length() != bytes.length) {
            await modelFile.writeAsBytes(bytes);
          }
          
          _interpreter = tflite.Interpreter.fromFile(
            modelFile,
            options: options,
          );
          
          if (_interpreter == null) {
            throw Exception('Interpreter is null after fromFile');
          }
        } catch (fromFileError) {
          _lastError = 'Failed to load model: $fromAssetError (fromAsset), $fromFileError (fromFile)';
          debugPrint('Failed to load model: $fromAssetError');
          _isLoaded = false;
          _interpreter = null;
          return false;
        }
      }
      
      // Allocate tensors - this validates the model
      try {
        _interpreter!.allocateTensors();
      } catch (e) {
        _lastError = 'Failed to allocate tensors: $e';
        debugPrint('Failed to allocate tensors: $e');
        _interpreter?.close();
        _interpreter = null;
        _isLoaded = false;
        return false;
      }
      
      // Verify tensors
      try {
        final inputTensor = _interpreter!.getInputTensor(0);
        final outputTensor = _interpreter!.getOutputTensor(0);
        
        // Verify input shape is correct [1, 224, 224, 3]
        final inputShape = inputTensor.shape;
        
        // Verify output shape is correct [1, 4]
        final outputShape = outputTensor.shape;
        if (outputShape.length != 2 || 
            outputShape[0] != 1 || 
            outputShape[1] != 4) {
          _lastError = 'Output shape mismatch: expected [1, 4], got $outputShape';
          debugPrint('Output shape issue: $outputShape');
          _interpreter?.close();
          _interpreter = null;
          _isLoaded = false;
          return false;
        }
        
        if (inputShape.length != 4 || 
            inputShape[0] != 1 || 
            inputShape[1] != 224 || 
            inputShape[2] != 224 || 
            inputShape[3] != 3) {
          // Try to reshape if needed
          try {
            _interpreter!.resizeInputTensor(0, [1, 224, 224, 3]);
            _interpreter!.allocateTensors();
            
            // Verify reshape worked
            final reshapedTensor = _interpreter!.getInputTensor(0);
            final reshapedShape = reshapedTensor.shape;
            if (reshapedShape.length != 4 || 
                reshapedShape[0] != 1 || 
                reshapedShape[1] != 224 || 
                reshapedShape[2] != 224 || 
                reshapedShape[3] != 3) {
              throw Exception('Cannot reshape to [1, 224, 224, 3]');
            }
          } catch (reshapeError) {
            _lastError = 'Input shape mismatch: $inputShape, cannot reshape: $reshapeError';
            debugPrint('Input shape issue: $inputShape');
            _interpreter?.close();
            _interpreter = null;
            _isLoaded = false;
            return false;
          }
        }
        
        _isLoaded = true;
        debugPrint('Model loaded successfully');
        debugPrint('  Input shape: ${_interpreter!.getInputTensor(0).shape}');
        debugPrint('  Output shape: ${_interpreter!.getOutputTensor(0).shape}');
        return true;
      } catch (e) {
        _lastError = 'Failed to verify tensors: $e';
        debugPrint('Failed to verify tensors: $e');
        _interpreter?.close();
        _interpreter = null;
        _isLoaded = false;
        return false;
      }
    } catch (e) {
      _lastError = 'Failed to load model: $e';
      debugPrint('Model loading error: $e');
      _isLoaded = false;
      _interpreter = null;
      return false;
    }
  }
  
  /// Run inference on preprocessed image
  /// Returns list of probabilities for each class, or null if inference fails
  /// Validates structure, process, and output at each step
  Future<List<double>?> classify(Float32List preprocessedImage) async {
    // STRUCTURE VALIDATION: Check model is loaded
    if (!isLoaded || _interpreter == null) {
      _lastError = 'Model not loaded';
      return null;
    }
    
    try {
      // STRUCTURE VALIDATION: Get tensors
      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);
      
      // PROCESS VALIDATION: Verify input size matches expected shape
      const expectedInputSize = 150528; // 224 * 224 * 3
      if (preprocessedImage.length != expectedInputSize) {
        _lastError = 'Input size mismatch: expected $expectedInputSize, got ${preprocessedImage.length}';
        return null;
      }
      
      // PROCESS VALIDATION: Verify input values are in valid range [0, 1]
      final invalidInput = preprocessedImage.any((v) => v.isNaN || v.isInfinite || v < -0.1 || v > 1.1);
      if (invalidInput) {
        _lastError = 'Input contains invalid values (NaN, Infinite, or out of [0,1] range)';
        return null;
      }
      
      // PROCESS VALIDATION: Verify input tensor shape
      final inputShape = inputTensor.shape;
      if (inputShape.length != 4 || 
          inputShape[0] != 1 || 
          inputShape[1] != 224 || 
          inputShape[2] != 224 || 
          inputShape[3] != 3) {
        _lastError = 'Input tensor shape mismatch: expected [1, 224, 224, 3], got $inputShape';
        return null;
      }
      
      // PROCESS VALIDATION: Verify output tensor shape
      final outputShape = outputTensor.shape;
      if (outputShape.length != 2 || 
          outputShape[0] != 1 || 
          outputShape[1] != 4) {
        _lastError = 'Output tensor shape mismatch: expected [1, 4], got $outputShape';
        return null;
      }
      
      // Prepare buffers - EXACTLY matches Python format
      // Python: interpreter.set_tensor(input_index, img_array) where img_array is [1, 224, 224, 3]
      // Flutter: inputBuffer = [preprocessedImage] where preprocessedImage is Float32List(150528)
      final inputBuffer = [preprocessedImage];
      
      // Python: output shape is [1, 4], so outputSize = 4
      final outputSize = outputTensor.shape.reduce((a, b) => a * b);
      final outputBuffer = [Float32List(outputSize)];
      
      debugPrint('🔄 Running inference (Python equivalent: interpreter.invoke())...');
      debugPrint('   Input buffer: ${inputBuffer.length} batch(es), ${inputBuffer[0].length} values');
      debugPrint('   Output buffer: ${outputBuffer.length} batch(es), ${outputBuffer[0].length} values');
      debugPrint('   Expected output: 4 probabilities (Cyclone, Earthquake, Flood, Wildfire)');
      
      // PROCESS: Run inference with validation
      // Python: interpreter.invoke()
      // Flutter: interpreter.run() does set_tensor + invoke in one call
      try {
        _interpreter!.run(inputBuffer, outputBuffer);
        debugPrint('✅ Inference completed successfully');
      } catch (e) {
        _lastError = 'Inference failed: $e';
        debugPrint('❌ Inference error: $e');
        debugPrint('   This might indicate:');
        debugPrint('   1. Model architecture issue');
        debugPrint('   2. Input format mismatch');
        debugPrint('   3. Tensor allocation problem');
        return null;
      }
      
      // OUTPUT VALIDATION: Extract and validate output
      // Python: predictions = interpreter.get_tensor(output_index)[0]  # Remove batch dimension
      // Flutter: output = outputBuffer[0]  # Remove batch dimension
      final output = outputBuffer[0];
      
      debugPrint('📊 Raw model output extracted:');
      debugPrint('   Output length: ${output.length}');
      debugPrint('   Output values: ${output.take(4).map((v) => v.toStringAsFixed(6)).join(", ")}');
      
      // OUTPUT VALIDATION: Check output is not empty
      if (output.isEmpty) {
        _lastError = 'Output is empty';
        return null;
      }
      
      // OUTPUT VALIDATION: Check output length matches expected
      if (output.length != 4) {
        _lastError = 'Output length mismatch: expected 4, got ${output.length}';
        return null;
      }
      
      // OUTPUT VALIDATION: Check for invalid values
      if (output.any((v) => v.isNaN || v.isInfinite)) {
        _lastError = 'Output contains invalid values (NaN or Infinite)';
        return null;
      }
      
      // OUTPUT VALIDATION: Check output values are reasonable
      // (Allow negative values as they might be logits, not probabilities)
      final hasExtremeValues = output.any((v) => v.abs() > 100.0);
      if (hasExtremeValues) {
        _lastError = 'Output contains extreme values (>100)';
        return null;
      }
      
      // Convert to List<double> and return
      // Python: predictions is already a numpy array of float32, we convert to List<double>
      final probabilities = output.map((v) => v.toDouble()).toList();
      
      // OUTPUT VALIDATION: Final check - probabilities should be valid
      if (probabilities.length != 4) {
        _lastError = 'Final probabilities length mismatch: expected 4, got ${probabilities.length}';
        return null;
      }
      
      // Log final output for debugging
      debugPrint('✅ Classification output ready:');
      debugPrint('   Probabilities: ${probabilities.map((p) => p.toStringAsFixed(6)).join(", ")}');
      debugPrint('   Sum: ${probabilities.fold(0.0, (a, b) => a + b).toStringAsFixed(6)}');
      debugPrint('   Max: ${probabilities.reduce((a, b) => a > b ? a : b).toStringAsFixed(6)}');
      debugPrint('   Argmax index: ${probabilities.indexOf(probabilities.reduce((a, b) => a > b ? a : b))}');
      
      return probabilities;
    } catch (e) {
      _lastError = 'Classification error: $e';
      debugPrint('Classification error: $e');
      return null;
    }
  }
  
  /// Dispose of the model interpreter
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
    _lastError = null;
  }
}
