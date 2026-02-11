import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tflite;

import 'ai_detection_config.dart';

/// Service for loading and running ML models for emergency detection
/// Currently supports TensorFlow Lite models
class MLModelService {
  static MLModelService? _instance;
  static MLModelService get instance => _instance ??= MLModelService._();
  
  MLModelService._();
  
  tflite.Interpreter? _interpreter;
  bool _isLoaded = false;
  bool _isDisposed = false;
  String? _lastError;
  /// Ensures only one inference runs at a time (avoids "failed precondition" / interpreter busy).
  Completer<void>? _inferenceLock = Completer<void>()..complete();
  /// Ensures only one load runs at a time; others await this and then re-check isLoaded.
  Completer<bool>? _loadCompleter;

  /// Check if ML model is loaded and available (and not disposed)
  bool get isLoaded => !_isDisposed && _isLoaded && _interpreter != null;

  /// Close interpreter and clear state (used on failure paths and retries).
  void _closeAndClear() {
    try {
      _interpreter?.close();
    } catch (e) {
      debugPrint('⚠️ Error closing interpreter: $e');
    }
    _interpreter = null;
    _isLoaded = false;
    // Do not set _isDisposed here; only dispose() does that
  }
  
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

  /// Reshape flat [H*W*C] to 4D [1, H, W, C] with Float32List(3) per pixel so TFLite CONV_2D gets 4D (fixes "input->dims->size != 4").
  static List<List<List<Float32List>>> _reshapeTo4DFloat32List(Float32List flat, {int height = 180, int width = 180, int channels = 3}) {
    return List.generate(1, (_) => List.generate(height, (y) => List.generate(width, (x) {
      final start = (y * width + x) * channels;
      return Float32List.fromList(List.generate(channels, (c) => flat[start + c]));
    })));
  }

  /// Same for uint8 (quantized input).
  static List<List<List<Uint8List>>> _reshapeTo4DUint8PerPixel(Uint8List flat, {int height = 180, int width = 180, int channels = 3}) {
    return List.generate(1, (_) => List.generate(height, (y) => List.generate(width, (x) {
      final start = (y * width + x) * channels;
      return Uint8List.fromList(List.generate(channels, (c) => flat[start + c]));
    })));
  }

  /// Run inference using run() or runForMultipleInputs() only.
  /// Do NOT use setTo+invoke+copyTo - that path can call TfLiteTensorCopyFromBuffer with
  /// null tensor data and cause SIGSEGV if tensors were not allocated.
  static void _runInferenceWithFallback(
    tflite.Interpreter interpreter,
    tflite.Tensor inputTensor,
    tflite.Tensor outputTensor,
    Object inputBuffer,
    Object outputBuffer,
  ) {
    try {
      interpreter.run(inputBuffer, outputBuffer);
      return;
    } catch (e) {
      if (kDebugMode) debugPrint('   run() failed ($e), trying runForMultipleInputs...');
    }
    try {
      interpreter.runForMultipleInputs([inputBuffer], {0: outputBuffer});
    } catch (e2) {
      throw Exception('Inference failed: run() and runForMultipleInputs() threw: $e2');
    }
  }

  /// Load ML model from assets with retries and warm-up inference.
  ///
  /// [modelPath] - Path to model file in assets (e.g., 'best_model.tflite')
  /// Returns true only if model loads and a warm-up inference succeeds.
  Future<bool> loadModel(String modelPath) async {
    // If another load is in progress, wait for it and return its result
    if (_loadCompleter != null) {
      final result = await _loadCompleter!.future;
      debugPrint('📦 Load already in progress; waited. Result: $result');
      return result;
    }

    _loadCompleter = Completer<bool>();

    final maxAttempts = AIDetectionConfig.modelLoadMaxAttempts;
    final retryDelay = Duration(milliseconds: AIDetectionConfig.modelLoadRetryDelayMs);

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        if (attempt > 1) {
          debugPrint('🔄 Load retry $attempt/$maxAttempts after ${retryDelay.inMilliseconds}ms');
          await Future.delayed(retryDelay);
        }
        final ok = await _loadModelOnce(modelPath);
        if (ok) {
          _loadCompleter!.complete(true);
          _loadCompleter = null;
          return true;
        }
      } catch (e, st) {
        debugPrint('❌ Load attempt $attempt failed: $e');
        if (kDebugMode) debugPrint('$st');
      }
      _closeAndClear();
    }

    _lastError = _lastError ?? 'Model load failed after $maxAttempts attempts';
    _loadCompleter!.complete(false);
    _loadCompleter = null;
    return false;
  }

  /// Single attempt at loading the model (no retry). Returns true iff load + optional warm-up succeed.
  Future<bool> _loadModelOnce(String modelPath) async {
    try {
      _lastError = null;
      _isDisposed = false;
      _closeAndClear();

      // fromAsset expects path relative to assets folder (no "assets/" prefix)
      String assetPath = modelPath.trim();
      if (assetPath.startsWith('assets/')) assetPath = assetPath.substring(7);
      if (assetPath.startsWith('/')) assetPath = assetPath.substring(1);
      if (assetPath.isEmpty) assetPath = 'best_model.tflite';

      debugPrint('');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('🔄 ML MODEL LOADING');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('📁 Asset: assets/$assetPath');
      
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
          _closeAndClear();
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
        _closeAndClear();
        return false;
      }
      
      // Step 2: Load interpreter from asset
      debugPrint('📦 Step 2: Loading TFLite interpreter...');
      final options = tflite.InterpreterOptions()
        ..threads = 4;

      try {
        
        // Try fromAsset first (fastest if it works)
        try {
          _interpreter = await Future(() async {
            return await tflite.Interpreter.fromAsset(
              assetPath,
              options: options,
            );
          }).timeout(
            const Duration(seconds: 45),
            onTimeout: () {
              throw TimeoutException('fromAsset timeout after 45 seconds');
            },
          );
          
          if (_interpreter != null) {
            debugPrint('✅ Interpreter loaded successfully via fromAsset');
            // Continue to Step 3 (tensor validation)
          } else {
            throw Exception('Interpreter is null after fromAsset');
          }
        } catch (fromAssetError) {
          debugPrint('⚠️ fromAsset() failed: $fromAssetError');
          debugPrint('   Trying fallback: copy to internal storage and load from file...');
          
          // FALLBACK: Copy asset to internal storage and load from file
          // This works even if the model is compressed or fromAsset has issues
          try {
            final ByteData assetData = await rootBundle.load('assets/$assetPath');
            final List<int> bytes = assetData.buffer.asUint8List();
            
            // Get app's internal directory
            final Directory appDir = await getApplicationDocumentsDirectory();
            final String modelPath = '${appDir.path}/$assetPath';
            final File modelFile = File(modelPath);
            
            // Write model to internal storage (only if it doesn't exist or is different size)
            if (!await modelFile.exists() || await modelFile.length() != bytes.length) {
              await modelFile.writeAsBytes(bytes);
              debugPrint('✅ Model copied to internal storage: $modelPath');
            } else {
              debugPrint('✅ Model already exists in internal storage');
            }
            debugPrint('   File size: ${(bytes.length / 1024 / 1024).toStringAsFixed(2)} MB');
            
            // Load from file path (fromFile is synchronous, wrap in Future for timeout)
            _interpreter = await Future(() {
              return tflite.Interpreter.fromFile(
                modelFile,
                options: options,
              );
            }).timeout(
              const Duration(seconds: 45),
              onTimeout: () {
                throw TimeoutException('fromFile timeout after 45 seconds');
              },
            );
            
            if (_interpreter != null) {
              debugPrint('✅ Interpreter loaded successfully via fromFile (fallback)');
              // Continue to Step 3 (tensor validation)
            } else {
              throw Exception('Interpreter is null after fromFile');
            }
          } catch (fallbackError) {
            debugPrint('❌ Fallback method also failed: $fallbackError');
            throw fromAssetError; // Throw original error for better diagnostics
          }
        }
      } catch (e, stackTrace) {
        _lastError = 'Failed to create interpreter: $e';
        debugPrint('❌ CRITICAL: Failed to create TFLite interpreter');
        debugPrint('   Error: $e');
        debugPrint('   Asset path used: $assetPath');
        debugPrint('   Full asset path: assets/$assetPath');
        debugPrint('   Stack trace: $stackTrace');
        debugPrint('');
        debugPrint('🔧 TROUBLESHOOTING STEPS:');
        debugPrint('   1. Verify file exists: assets/$assetPath');
        debugPrint('   2. Check pubspec.yaml includes: - assets/$assetPath');
        debugPrint('   3. Run: flutter clean && flutter pub get');
        debugPrint('   4. Verify Android build.gradle.kts has noCompress for .tflite');
        debugPrint('   5. Check file is not corrupted (best_model.tflite ~4 MB for 180x180 model)');
        _closeAndClear();
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
        
        // Verify expected input shape (e.g. [1, 180, 180, 3] for best_model.tflite)
        final expectedInputSize = AIDetectionConfig.expectedInputPixels;
        final actualInputSize = inputShape.length > 1
            ? inputShape.sublist(1).reduce((a, b) => a * b)  // Skip batch dimension
            : inputShape.reduce((a, b) => a * b);
        
        if (actualInputSize != expectedInputSize) {
          debugPrint('⚠️ Warning: Input size mismatch');
          debugPrint('   Expected: $expectedInputSize (${AIDetectionConfig.modelInputHeight}x${AIDetectionConfig.modelInputWidth}x3)');
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
        _closeAndClear();
        return false;
      }

      // Allocate tensor memory so TfLiteTensorCopyFromBuffer never gets null (avoids SIGSEGV).
      debugPrint('📦 Step 3b: Allocate tensors...');
      try {
        _interpreter!.allocateTensors();
        debugPrint('   allocateTensors() OK');
      } catch (e) {
        debugPrint('⚠️ allocateTensors() failed: $e (inference may still work via run())');
        // Continue without allocation; run() might allocate internally on first call.
      }

      // Warm-up inference: use same input shape as classify (4D when model expects [1,H,W,3])
      if (AIDetectionConfig.warmupInferenceAfterLoad && _interpreter != null) {
        debugPrint('📦 Step 4: Warm-up inference...');
        try {
          final inputTensor = _interpreter!.getInputTensor(0);
          final outputTensor = _interpreter!.getOutputTensor(0);
          final warmupInputShape = inputTensor.shape;
          final nonBatch = warmupInputShape.length > 1
              ? warmupInputShape.sublist(1).reduce((a, b) => a * b)
              : warmupInputShape.reduce((a, b) => a * b);
          final outSize = outputTensor.shape.reduce((a, b) => a * b);
          final inputTypeStr = inputTensor.type.toString().toLowerCase();
          final isQuantInput = inputTypeStr.contains('uint8') || inputTypeStr.contains('int8');
          final is4D = warmupInputShape.length == 4 &&
              warmupInputShape[0] == 1 &&
              warmupInputShape[3] == 3 &&
              warmupInputShape[1] > 0 &&
              warmupInputShape[2] > 0;
          final int wh = is4D ? warmupInputShape[1] : AIDetectionConfig.modelInputHeight;
          final int ww = is4D ? warmupInputShape[2] : AIDetectionConfig.modelInputWidth;
          Object warmupInput;
          if (isQuantInput) {
            final flat = Uint8List(nonBatch);
            warmupInput = is4D ? _reshapeTo4DUint8PerPixel(flat, height: wh, width: ww) : flat;
          } else {
            final flat = Float32List(nonBatch);
            warmupInput = is4D ? _reshapeTo4DFloat32List(flat, height: wh, width: ww) : flat;
          }
          if (is4D) debugPrint('   Warm-up input: 4D [1, $wh, $ww, 3] (CONV_2D compatible)');
          final outputTypeStr = outputTensor.type.toString().toLowerCase();
          final isQuantOutput = outputTypeStr.contains('uint8') || outputTypeStr.contains('int8');
          // For output shape [1, N], tflite_flutter expects a 2D structure. The plugin
          // may assign native result (List<double>) into output[0], so use List<double>
          // for the inner buffer to avoid "List<double> is not a subtype of Float32List".
          Object warmupOutput;
          if (outputTensor.shape.length == 2 && outputTensor.shape[0] == 1) {
            final n = outSize;
            if (isQuantOutput) {
              warmupOutput = <Uint8List>[Uint8List(n)];
            } else {
              warmupOutput = <List<double>>[List<double>.filled(n, 0.0)];
            }
          } else {
            warmupOutput = isQuantOutput
                ? Uint8List(outSize)
                : Float32List(outSize);
          }
          _runInferenceWithFallback(_interpreter!, inputTensor, outputTensor, warmupInput, warmupOutput);
          final numClasses = outputTensor.shape.length > 1 && outputTensor.shape[0] == 1
              ? outputTensor.shape.sublist(1).reduce((a, b) => a * b)
              : outSize;
          if (numClasses != AIDetectionConfig.numClasses) {
            _lastError = 'Warm-up output size $numClasses != ${AIDetectionConfig.numClasses}';
            _closeAndClear();
            return false;
          }
          debugPrint('✅ Warm-up inference OK');
        } catch (e) {
          _lastError = 'Warm-up inference error: $e';
          debugPrint('❌ Warm-up inference error: $e');
          _closeAndClear();
          return false;
        }
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
      _closeAndClear();
      return false;
    }
  }
  
  /// Run full classification using ML model
  ///
  /// [preprocessedImage] - Normalized Float32List (HxWx3, e.g. 180x180x3 = 97200 values)
  /// Returns classification probabilities [Cyclone, Earthquake, Flood, Wildfire] or null
  Future<List<double>?> classify(Float32List? preprocessedImage) async {
    if (_isDisposed) {
      debugPrint('⚠️ ML model service disposed, cannot classify');
      return null;
    }
    if (!_isLoaded || _interpreter == null) {
      debugPrint('⚠️ ML model not loaded, cannot classify');
      return null;
    }
    if (preprocessedImage == null || preprocessedImage.isEmpty) {
      debugPrint('⚠️ classify: null or empty input');
      return null;
    }
    if (preprocessedImage.length != AIDetectionConfig.expectedInputPixels) {
      debugPrint('⚠️ classify: input size ${preprocessedImage.length} != ${AIDetectionConfig.expectedInputPixels}');
      return null;
    }

    try {
      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);
      
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
      
      debugPrint('📐 Input tensor shape: $inputShape');
      debugPrint('📐 Preprocessed image length: ${preprocessedImage.length}');

      final expectedNonBatchSize = inputShape.length > 1
          ? inputShape.sublist(1).reduce((a, b) => a * b)
          : inputShape.reduce((a, b) => a * b);
      if (preprocessedImage.length != expectedNonBatchSize) {
        debugPrint('❌ Input size mismatch: got ${preprocessedImage.length}, expected $expectedNonBatchSize (tensor: $inputShape)');
        return null;
      }
      
      debugPrint('✅ Input size verified: ${preprocessedImage.length} elements (matches $expectedNonBatchSize)');

      // CONV_2D requires 4D input [1, H, W, 3]. Pass 4D structure with Float32List(3) per pixel to avoid "input->dims->size != 4".
      final inputType = inputTensor.type;
      final inputTypeStr = inputType.toString().toLowerCase();
      debugPrint('📐 Input tensor type: $inputType');
      final is4DShape = inputShape.length == 4 &&
          inputShape[0] == 1 &&
          inputShape[3] == 3 &&
          inputShape[1] > 0 &&
          inputShape[2] > 0;
      final int inputH = is4DShape ? inputShape[1] : AIDetectionConfig.modelInputHeight;
      final int inputW = is4DShape ? inputShape[2] : AIDetectionConfig.modelInputWidth;
      Object runInput;
      final isQuantizedInput = inputTypeStr.contains('uint8') || inputTypeStr.contains('int8');
      if (isQuantizedInput) {
        final uint8List = Uint8List(preprocessedImage.length);
        double scale = 1.0 / 255.0;
        int zeroPoint = 0;
        try {
          final q = inputTensor.params;
          if (q.scale != 0) {
            scale = q.scale.toDouble();
            zeroPoint = q.zeroPoint;
            debugPrint('   Input quantization: scale=$scale zeroPoint=$zeroPoint');
          }
        } catch (_) {}
        for (int i = 0; i < preprocessedImage.length; i++) {
          final v = preprocessedImage[i].clamp(0.0, 1.0);
          final qv = (v / scale + zeroPoint).round();
          uint8List[i] = qv.clamp(0, 255);
        }
        runInput = is4DShape ? _reshapeTo4DUint8PerPixel(uint8List, height: inputH, width: inputW) : uint8List;
        debugPrint('   Using ${is4DShape ? "4D" : "flat"} Uint8List input (quantized)');
      } else {
        if (is4DShape) {
          runInput = _reshapeTo4DFloat32List(Float32List.fromList(preprocessedImage), height: inputH, width: inputW);
          debugPrint('   Using 4D input [1, $inputH, $inputW, 3] for CONV_2D');
        } else {
          runInput = Float32List.fromList(preprocessedImage);
          debugPrint('   Using flat Float32List input');
        }
      }
      
      // Prepare output buffer (type and shape must match model output tensor)
      final outputSize = outputTensor.shape.reduce((a, b) => a * b);
      if (outputSize <= 0) {
        debugPrint('❌ Invalid output tensor size: $outputSize');
        return null;
      }
      final outputTypeStr = outputTensor.type.toString().toLowerCase();
      final isQuantizedOutput = outputTypeStr.contains('uint8') || outputTypeStr.contains('int8');
      Object runOutput;
      if (outputTensor.shape.length == 2 && outputTensor.shape[0] == 1) {
        // Output shape [1, numClasses]. Use List<double> inner so plugin can assign native result.
        final n = outputSize;
        if (isQuantizedOutput) {
          runOutput = <Uint8List>[Uint8List(n)];
        } else {
          runOutput = <List<double>>[List<double>.filled(n, 0.0)];
        }
      } else {
        runOutput = isQuantizedOutput
            ? Uint8List(outputSize)
            : Float32List(outputSize);
      }
      if (isQuantizedOutput) {
        debugPrint('   Output tensor type: quantized (uint8/int8)');
      }

      // Run inference - one at a time to avoid "failed precondition" / interpreter busy
      await _inferenceLock!.future;
      _inferenceLock = Completer<void>();
      debugPrint('🔄 Running TFLite inference (dynamic, no caching)...');
      debugPrint('   Input buffer size: ${runInputBuffer[0] is List ? (runInputBuffer[0] as List).length : 0}');
      debugPrint('   Output buffer size: ${(outputBuffer[0] as List).length}');

      // Re-check interpreter is still valid (could have been disposed)
      if (_isDisposed || _interpreter == null || !_isLoaded) {
        debugPrint('⚠️ Interpreter no longer available; skipping inference');
        if (_inferenceLock != null && !_inferenceLock!.isCompleted) _inferenceLock!.complete();
        return null;
      }

      final inferenceStartTime = DateTime.now();
      final timeoutDuration = Duration(seconds: AIDetectionConfig.inferenceTimeoutSeconds);

      try {
        await Future(() {
          _runInferenceWithFallback(
            _interpreter!,
            inputTensor,
            outputTensor,
            runInput,
            runOutput,
          );
        }).timeout(
          timeoutDuration,
          onTimeout: () {
            throw TimeoutException(
              'Inference timeout after ${timeoutDuration.inSeconds}s',
            );
          },
        );
      } catch (e, stackTrace) {
        debugPrint('❌ CRITICAL: Inference failed: $e');
        if (kDebugMode) debugPrint('   Stack trace: $stackTrace');
        _lastError = 'Inference failed: $e';
        return null;
      } finally {
        if (_inferenceLock != null && !_inferenceLock!.isCompleted) {
          _inferenceLock!.complete();
        }
      }
      
      final inferenceDuration = DateTime.now().difference(inferenceStartTime);
      debugPrint('✅ TFLite inference completed in ${inferenceDuration.inMilliseconds}ms');
      
      // Extract and dequantize output (must match Python/TFLite: scale/zeroPoint or raw float)
      final output = runOutput;
      final numClasses = outputTensor.shape.length > 1 && outputTensor.shape[0] == 1
          ? outputTensor.shape.sublist(1).reduce((a, b) => a * b)
          : outputSize;
      List<double> rawOutput;
      if (output is Float32List) {
        rawOutput = output.sublist(0, numClasses).map((e) => e.toDouble()).toList();
      } else if (output is Uint8List) {
        double scale = 1.0 / 255.0;
        int zeroPoint = 0;
        try {
          final q = outputTensor.params;
          if (q.scale != 0) {
            scale = q.scale.toDouble();
            zeroPoint = q.zeroPoint;
            debugPrint('📊 Output dequantization: scale=$scale zeroPoint=$zeroPoint');
          }
        } catch (_) {}
        rawOutput = output.sublist(0, numClasses).map((e) {
          final r = (e - zeroPoint) * scale;
          return r.toDouble();
        }).toList();
        debugPrint('📊 Dequantized ${rawOutput.length} values from uint8 (${scale != 1.0/255 ? "tensor params" : "÷255"})');
      } else if (output is List) {
        // Handle [Float32List], [Uint8List], or [List<double>] for shape [1, numClasses]
        if (output.isEmpty) {
          debugPrint('⚠️ Empty output list');
          return null;
        }
        final first = output.first;
        if (first is Float32List) {
          rawOutput = first.sublist(0, numClasses).map((e) => e.toDouble()).toList();
        } else if (first is Uint8List) {
          double scale = 1.0 / 255.0;
          int zeroPoint = 0;
          try {
            final q = outputTensor.params;
            if (q.scale != 0) {
              scale = q.scale.toDouble();
              zeroPoint = q.zeroPoint;
              debugPrint('📊 Output dequantization (list): scale=$scale zeroPoint=$zeroPoint');
            }
          } catch (_) {}
          rawOutput = first.sublist(0, numClasses).map((e) {
            final r = (e - zeroPoint) * scale;
            return r.toDouble();
          }).toList();
        } else if (first is List) {
          // [List<double>] from run when using List<double>.filled for [1, N] output
          rawOutput = (first as List<dynamic>).take(numClasses).map((e) => (e as num).toDouble()).toList();
        } else {
          final list = output.cast<num>();
          rawOutput = list.take(numClasses).map((e) => e.toDouble()).toList();
        }
      } else {
        debugPrint('⚠️ Unexpected output buffer type: ${output.runtimeType}');
        return null;
      }

      // Allow logits (negative/large) or probabilities; only reject NaN/Infinite
      if (rawOutput.length != AIDetectionConfig.numClasses) {
        debugPrint('⚠️ Output class count ${rawOutput.length} != ${AIDetectionConfig.numClasses}');
        return null;
      }
      final hasInvalid = rawOutput.any((p) => p.isNaN || p.isInfinite);
      if (hasInvalid) {
        debugPrint('⚠️ Output contains NaN/Infinite');
        return null;
      }
      final probabilities = rawOutput;

      debugPrint('📊 Raw output buffer size: ${(output is List ? (output as List).length : 0)}');
      debugPrint('📊 Output tensor shape: ${outputTensor.shape}');
      debugPrint('📊 Extracted ${probabilities.length} probabilities');
      if (kDebugMode) {
        for (int i = 0; i < probabilities.length && i < 4; i++) {
          debugPrint('   Output[$i]: ${probabilities[i].toStringAsFixed(6)}');
        }
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
  /// [preprocessedImage] - Normalized Float32List (HxWx3, e.g. 180x180x3)
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
      
      // Create dummy input (HxWx3, all zeros)
      final dummyInput = Float32List(AIDetectionConfig.expectedInputPixels);
      
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
  
  /// Dispose resources. Safe to call multiple times.
  void dispose() {
    _isDisposed = true;
    if (_loadCompleter != null && !_loadCompleter!.isCompleted) {
      _loadCompleter!.complete(false);
    }
    _loadCompleter = null;
    _closeAndClear();
    _lastError = null;
    // Reset inference lock to a completed state so future classify() calls
    // won't crash even if dispose() was invoked earlier.
    _inferenceLock = Completer<void>()..complete();
    debugPrint('🧹 ML Model service disposed');
  }
}
