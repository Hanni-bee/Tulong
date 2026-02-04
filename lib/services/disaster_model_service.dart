import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tflite;

/// Disaster Model Service - Singleton service for loading and running TFLite model
/// Based on PyImageSearch VGG16 natural disaster detection model
///
/// Model Specifications:
/// - Architecture: VGG16-based (pre-trained on ImageNet, fine-tuned for natural disasters)
/// - Input: 224x224 RGB image, normalized [0, 1], shape [1, 224, 224, 3]
/// - Input dtype: float32
/// - Output: 4-class softmax probabilities [Cyclone, Earthquake, Flood, Wildfire]
/// - Output shape: [1, 4]
/// - Output dtype: float32
/// - Class Mapping: 0=Cyclone, 1=Earthquake, 2=Flood, 3=Wildfire
class DisasterModelService {
  static DisasterModelService? _instance;
  static DisasterModelService get instance => _instance ??= DisasterModelService._();

  DisasterModelService._();

  tflite.Interpreter? _interpreter;
  bool _isLoaded = false;
  String? _lastError;

  // Model specifications
  static const String _modelPath = 'best_model.tflite'; // Located in assets/
  static const int _inputSize = 224;
  static const int _inputChannels = 3; // RGB
  static const int _numClasses = 4;

  // Class labels in order (matching model output indices)
  static const List<String> classLabels = [
    'Cyclone',    // Index 0
    'Earthquake', // Index 1
    'Flood',      // Index 2
    'Wildfire',   // Index 3
  ];

  /// Check if model is loaded and ready
  bool get isLoaded => _isLoaded && _interpreter != null;

  /// Get last error message
  String? get lastError => _lastError;

  /// Get model input shape [1, 224, 224, 3]
  List<int>? get inputShape {
    if (_interpreter == null) return null;
    try {
      return _interpreter!.getInputTensor(0).shape;
    } catch (e) {
      debugPrint('Error getting input shape: $e');
      return null;
    }
  }

  /// Get model output shape [1, 4]
  List<int>? get outputShape {
    if (_interpreter == null) return null;
    try {
      return _interpreter!.getOutputTensor(0).shape;
    } catch (e) {
      debugPrint('Error getting output shape: $e');
      return null;
    }
  }

  /// Get input size (224)
  int get inputSize => _inputSize;

  /// Get number of classes (4)
  int get numClasses => _numClasses;

  /// Load model from assets
  /// Returns true if model loaded successfully
  Future<bool> loadModel() async {
    try {
      _lastError = null;

      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('🔄 DISASTER MODEL LOADING');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('📁 Model path: assets/$_modelPath');
      debugPrint('📐 Expected input: [1, $_inputSize, $_inputSize, $_inputChannels]');
      debugPrint('📊 Expected output: [1, $_numClasses]');

      // Step 1: Verify asset exists
      debugPrint('📦 Step 1: Verifying asset exists...');
      try {
        final ByteData data = await rootBundle.load('assets/$_modelPath');
        final int assetSize = data.lengthInBytes;
        debugPrint('✅ Asset found: assets/$_modelPath');
        debugPrint('   Size: ${(assetSize / 1024 / 1024).toStringAsFixed(2)} MB');

        if (assetSize == 0) {
          _lastError = 'Asset file is empty';
          debugPrint('❌ Asset file is empty!');
          return false;
        }
      } catch (e) {
        _lastError = 'Asset not found: $e';
        debugPrint('❌ Asset NOT found: assets/$_modelPath');
        debugPrint('   Error: $e');
        debugPrint('   Make sure:');
        debugPrint('   1. File exists at: assets/$_modelPath');
        debugPrint('   2. pubspec.yaml includes: - assets/$_modelPath');
        debugPrint('   3. Run: flutter clean && flutter pub get');
        return false;
      }

      // Step 2: Load TFLite interpreter
      debugPrint('📦 Step 2: Loading TFLite interpreter...');
      final options = tflite.InterpreterOptions()
        ..threads = 4;

      try {
        _interpreter = await tflite.Interpreter.fromAsset(
          _modelPath,
          options: options,
        );

        debugPrint('✅ Interpreter loaded successfully');
      } catch (e, stackTrace) {
        _lastError = 'Failed to load interpreter: $e';
        debugPrint('❌ Failed to load interpreter: $e');
        debugPrint('   Stack trace: $stackTrace');
        return false;
      }

      // Step 3: Verify tensor shapes
      debugPrint('📦 Step 3: Verifying tensor shapes...');
      try {
        final inputTensor = _interpreter!.getInputTensor(0);
        final outputTensor = _interpreter!.getOutputTensor(0);

        final inputShape = inputTensor.shape;
        final outputShape = outputTensor.shape;

        debugPrint('   Input tensor shape: $inputShape');
        debugPrint('   Output tensor shape: $outputShape');
        debugPrint('   Input dtype: ${inputTensor.type}');
        debugPrint('   Output dtype: ${outputTensor.type}');

        // Verify input shape matches expected [1, 224, 224, 3]
        if (inputShape.length != 4 ||
            inputShape[0] != 1 ||
            inputShape[1] != _inputSize ||
            inputShape[2] != _inputSize ||
            inputShape[3] != _inputChannels) {
          _lastError = 'Input shape mismatch. Expected [1, $_inputSize, $_inputSize, $_inputChannels], got $inputShape';
          debugPrint('❌ Input shape mismatch!');
          debugPrint('   Expected: [1, $_inputSize, $_inputSize, $_inputChannels]');
          debugPrint('   Got: $inputShape');
          _interpreter?.close();
          _interpreter = null;
          return false;
        }

        // Verify output shape matches expected [1, 4]
        if (outputShape.length != 2 ||
            outputShape[0] != 1 ||
            outputShape[1] != _numClasses) {
          _lastError = 'Output shape mismatch. Expected [1, $_numClasses], got $outputShape';
          debugPrint('❌ Output shape mismatch!');
          debugPrint('   Expected: [1, $_numClasses]');
          debugPrint('   Got: $outputShape');
          _interpreter?.close();
          _interpreter = null;
          return false;
        }

        debugPrint('✅ Tensor shapes verified');
      } catch (e, stackTrace) {
        _lastError = 'Failed to verify tensor shapes: $e';
        debugPrint('❌ Failed to verify tensor shapes: $e');
        debugPrint('   Stack trace: $stackTrace');
        _interpreter?.close();
        _interpreter = null;
        return false;
      }

      _isLoaded = true;
      debugPrint('✅ Model loaded and verified successfully!');
      debugPrint('═══════════════════════════════════════════════════════════');
      return true;
    } catch (e, stackTrace) {
      _lastError = 'Unexpected error: $e';
      debugPrint('❌ Unexpected error loading model: $e');
      debugPrint('   Stack trace: $stackTrace');
      _isLoaded = false;
      return false;
    }
  }

  /// Run inference on preprocessed image
  ///
  /// [preprocessedImage] - Float32List of shape [224*224*3] = 150,528 values
  ///                       Normalized [0, 1], RGB channel order
  ///
  /// Returns Map with:
  /// - predicted_class: int (0-3)
  /// - class_name: String (Cyclone, Earthquake, Flood, or Wildfire)
  /// - confidence: double (0.0 to 1.0)
  /// - all_probabilities: Map<String, double> with all 4 class probabilities
  ///
  /// Returns null if inference fails
  Map<String, dynamic>? predict(Float32List preprocessedImage) {
    if (!isLoaded || _interpreter == null) {
      debugPrint('❌ Model not loaded, cannot run inference');
      _lastError = 'Model not loaded';
      return null;
    }

    try {
      // Verify input size
      final expectedSize = _inputSize * _inputSize * _inputChannels; // 224 * 224 * 3 = 150,528
      if (preprocessedImage.length != expectedSize) {
        debugPrint('❌ Input size mismatch: expected $expectedSize, got ${preprocessedImage.length}');
        _lastError = 'Input size mismatch: expected $expectedSize, got ${preprocessedImage.length}';
        return null;
      }

      // Prepare input buffer: [preprocessedImage] for batch dimension
      final inputBuffer = [preprocessedImage];

      // Prepare output buffer: [1, 4] = 4 float32 values
      final outputBuffer = [Float32List(_numClasses)];

      debugPrint('🔄 Running inference...');
      debugPrint('   Input size: ${preprocessedImage.length} (${_inputSize}x$_inputSize x $_inputChannels)');
      debugPrint('   Output size: ${outputBuffer[0].length} (${_numClasses} classes)');

      // Run inference
      final inferenceStartTime = DateTime.now();
      _interpreter!.run(inputBuffer, outputBuffer);
      final inferenceDuration = DateTime.now().difference(inferenceStartTime);

      debugPrint('✅ Inference completed in ${inferenceDuration.inMilliseconds}ms');

      // Extract probabilities (output is already softmax from model)
      final probabilities = outputBuffer[0];
      debugPrint('📊 Raw output probabilities:');
      for (int i = 0; i < probabilities.length; i++) {
        debugPrint('   ${classLabels[i]}: ${probabilities[i].toStringAsFixed(6)}');
      }

      // Find predicted class (argmax)
      int predictedClass = 0;
      double maxProb = probabilities[0];
      for (int i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          predictedClass = i;
        }
      }

      // Build all probabilities map
      final allProbabilities = <String, double>{};
      for (int i = 0; i < probabilities.length; i++) {
        allProbabilities[classLabels[i]] = probabilities[i].toDouble();
      }

      debugPrint('🎯 Prediction: ${classLabels[predictedClass]} (confidence: ${(maxProb * 100).toStringAsFixed(2)}%)');

      return {
        'predicted_class': predictedClass,
        'class_name': classLabels[predictedClass],
        'confidence': maxProb.toDouble(),
        'all_probabilities': allProbabilities,
      };
    } catch (e, stackTrace) {
      debugPrint('❌ Error during inference: $e');
      debugPrint('   Stack trace: $stackTrace');
      _lastError = 'Inference error: $e';
      return null;
    }
  }

  /// Dispose interpreter and free resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
    debugPrint('🗑️ Model service disposed');
  }
}
