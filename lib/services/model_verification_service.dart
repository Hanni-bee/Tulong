import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'ml_model_service.dart';
import 'disaster_classification_service.dart';
import 'image_preprocessing_service.dart';

/// Comprehensive model verification service
/// Tests model loading, structure, and inference capabilities
class ModelVerificationService {
  static ModelVerificationService? _instance;
  static ModelVerificationService get instance => _instance ??= ModelVerificationService._();
  
  ModelVerificationService._();
  
  final MLModelService _mlService = MLModelService.instance;
  final DisasterClassificationService _classificationService = DisasterClassificationService.instance;
  final ImagePreprocessingService _preprocessingService = ImagePreprocessingService();
  
  /// Run comprehensive model verification
  Future<Map<String, dynamic>> verifyModel() async {
    final results = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'tests': <String, dynamic>{},
      'overallStatus': 'unknown',
      'canDetect': false,
    };
    
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('🔍 COMPREHENSIVE MODEL VERIFICATION');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('');
    
    // Test 1: Asset File Verification
    debugPrint('📦 Test 1: Asset File Verification...');
    final assetTest = await _testAssetFile();
    results['tests']['assetFile'] = assetTest;
    
    if (!assetTest['exists']) {
      results['overallStatus'] = 'failed';
      results['error'] = 'Asset file not found';
      return results;
    }
    
    // Test 2: Model Loading
    debugPrint('');
    debugPrint('📦 Test 2: Model Loading...');
    final loadTest = await _testModelLoading();
    results['tests']['modelLoading'] = loadTest;
    
    if (!loadTest['success']) {
      results['overallStatus'] = 'failed';
      results['error'] = loadTest['error'];
      return results;
    }
    
    // Test 3: Model Structure
    debugPrint('');
    debugPrint('📦 Test 3: Model Structure Verification...');
    final structureTest = await _testModelStructure();
    results['tests']['modelStructure'] = structureTest;
    
    if (!structureTest['success']) {
      results['overallStatus'] = 'failed';
      results['error'] = 'Model structure invalid';
      return results;
    }
    
    // Test 4: Dummy Input Inference
    debugPrint('');
    debugPrint('📦 Test 4: Dummy Input Inference Test...');
    final dummyTest = await _testDummyInference();
    results['tests']['dummyInference'] = dummyTest;
    
    if (!dummyTest['success']) {
      results['overallStatus'] = 'failed';
      results['error'] = 'Dummy inference failed';
      return results;
    }
    
    // Test 5: Preprocessing Pipeline
    debugPrint('');
    debugPrint('📦 Test 5: Preprocessing Pipeline Test...');
    final preprocessTest = await _testPreprocessing();
    results['tests']['preprocessing'] = preprocessTest;
    
    // Determine overall status
    final criticalTestsPassed = [
      loadTest['success'],
      structureTest['success'],
      dummyTest['success'],
    ].every((result) => result == true);
    
    results['overallStatus'] = criticalTestsPassed ? 'passed' : 'failed';
    results['canDetect'] = criticalTestsPassed;
    
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('${criticalTestsPassed ? '✅' : '❌'} VERIFICATION ${results['overallStatus'].toString().toUpperCase()}');
    debugPrint('   Model can detect: ${results['canDetect']}');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('');
    
    return results;
  }
  
  /// Test if asset file exists
  Future<Map<String, dynamic>> _testAssetFile() async {
    try {
      // Try to load the asset
      final ByteData data = await rootBundle.load('assets/best_model.tflite');
      final int size = data.lengthInBytes;
      
      debugPrint('✅ Asset file found');
      debugPrint('   Size: ${(size / 1024 / 1024).toStringAsFixed(2)} MB');
      debugPrint('   Path: assets/best_model.tflite');
      
      return {
        'exists': true,
        'size': size,
        'sizeMB': (size / 1024 / 1024).toStringAsFixed(2),
      };
    } catch (e) {
      debugPrint('❌ Asset file NOT found');
      debugPrint('   Error: $e');
      debugPrint('   Check:');
      debugPrint('   1. File exists at: assets/best_model.tflite');
      debugPrint('   2. pubspec.yaml includes: - assets/best_model.tflite');
      debugPrint('   3. Run: flutter clean && flutter pub get');
      
      return {
        'exists': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Test model loading
  Future<Map<String, dynamic>> _testModelLoading() async {
    try {
      final startTime = DateTime.now();
      
      // Try loading through classification service
      final loaded = await _classificationService.loadModel();
      final duration = DateTime.now().difference(startTime);
      
      final isLoaded = loaded && _mlService.isLoaded;
      
      if (isLoaded) {
        debugPrint('✅ Model loaded successfully');
        debugPrint('   Duration: ${duration.inMilliseconds}ms');
        debugPrint('   Input shape: ${_mlService.inputShape}');
        debugPrint('   Output shape: ${_mlService.outputShape}');
      } else {
        debugPrint('❌ Model failed to load');
        final debugInfo = _classificationService.getDebugInfo();
        debugPrint('   Error: ${debugInfo['lastError']}');
        debugPrint('   ML Service loaded: ${_mlService.isLoaded}');
        debugPrint('   ML Service error: ${_mlService.lastError}');
      }
      
      return {
        'success': isLoaded,
        'durationMs': duration.inMilliseconds,
        'inputShape': _mlService.inputShape?.toString(),
        'outputShape': _mlService.outputShape?.toString(),
        'error': isLoaded ? null : (_mlService.lastError ?? 'Unknown error'),
      };
    } catch (e, stackTrace) {
      debugPrint('❌ Model loading exception: $e');
      debugPrint('   Stack trace: $stackTrace');
      return {
        'success': false,
        'error': e.toString(),
        'stackTrace': stackTrace.toString(),
      };
    }
  }
  
  /// Test model structure
  Future<Map<String, dynamic>> _testModelStructure() async {
    try {
      if (!_mlService.isLoaded) {
        return {
          'success': false,
          'error': 'Model not loaded',
        };
      }
      
      final inputShape = _mlService.inputShape;
      final outputShape = _mlService.outputShape;
      
      if (inputShape == null || outputShape == null) {
        return {
          'success': false,
          'error': 'Cannot get tensor shapes',
        };
      }
      
      // Calculate sizes (skip batch dimension if present)
      final inputSize = inputShape.length > 1
          ? inputShape.sublist(1).reduce((a, b) => a * b)
          : inputShape.reduce((a, b) => a * b);
      
      final outputSize = outputShape.length > 1
          ? outputShape.sublist(1).reduce((a, b) => a * b)
          : outputShape.reduce((a, b) => a * b);
      
      // Expected values
      final expectedInput = 224 * 224 * 3; // 150528
      final expectedOutput = 4; // 4 classes
      
      final inputValid = inputSize == expectedInput;
      final outputValid = outputSize == expectedOutput;
      
      debugPrint('📊 Model Structure:');
      debugPrint('   Input shape: $inputShape');
      debugPrint('   Input size: $inputSize (expected: $expectedInput)');
      debugPrint('   ${inputValid ? '✅' : '❌'} Input size ${inputValid ? 'valid' : 'INVALID'}');
      debugPrint('   Output shape: $outputShape');
      debugPrint('   Output size: $outputSize (expected: $expectedOutput)');
      debugPrint('   ${outputValid ? '✅' : '❌'} Output size ${outputValid ? 'valid' : 'INVALID'}');
      
      return {
        'success': inputValid && outputValid,
        'inputShape': inputShape.toString(),
        'outputShape': outputShape.toString(),
        'inputSize': inputSize,
        'outputSize': outputSize,
        'expectedInput': expectedInput,
        'expectedOutput': expectedOutput,
        'inputValid': inputValid,
        'outputValid': outputValid,
      };
    } catch (e, stackTrace) {
      debugPrint('❌ Model structure test error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Test dummy inference
  Future<Map<String, dynamic>> _testDummyInference() async {
    try {
      if (!_mlService.isLoaded) {
        return {
          'success': false,
          'error': 'Model not loaded',
        };
      }
      
      // Create dummy input (224x224x3 = 150528 values)
      final dummyInput = Float32List(224 * 224 * 3);
      // Fill with normalized values (0-1 range)
      for (int i = 0; i < dummyInput.length; i++) {
        dummyInput[i] = (i % 255) / 255.0;
      }
      
      debugPrint('🧪 Running dummy inference...');
      debugPrint('   Input size: ${dummyInput.length} (224x224x3)');
      
      final startTime = DateTime.now();
      final output = await _mlService.classify(dummyInput);
      final duration = DateTime.now().difference(startTime);
      
      if (output == null || output.isEmpty) {
        debugPrint('❌ Inference returned null or empty');
        return {
          'success': false,
          'error': 'Inference returned null',
        };
      }
      
      debugPrint('✅ Inference successful');
      debugPrint('   Duration: ${duration.inMilliseconds}ms');
      debugPrint('   Output length: ${output.length}');
      debugPrint('   Output values:');
      for (int i = 0; i < output.length && i < 4; i++) {
        final labels = ['Cyclone', 'Earthquake', 'Flood', 'Wildfire'];
        debugPrint('     ${labels[i]}: ${output[i].toStringAsFixed(6)}');
      }
      
      // Verify output makes sense (not all zeros, not all same value)
      final allSame = output.every((v) => v == output[0]);
      final allZero = output.every((v) => v == 0.0);
      
      if (allSame || allZero) {
        debugPrint('⚠️ Warning: Output values are ${allZero ? 'all zeros' : 'all the same'}');
      }
      
      return {
        'success': true,
        'durationMs': duration.inMilliseconds,
        'outputLength': output.length,
        'outputValues': output.take(4).toList(),
        'allSame': allSame,
        'allZero': allZero,
      };
    } catch (e, stackTrace) {
      debugPrint('❌ Dummy inference error: $e');
      debugPrint('   Stack trace: $stackTrace');
      return {
        'success': false,
        'error': e.toString(),
        'stackTrace': stackTrace.toString(),
      };
    }
  }
  
  /// Test preprocessing
  Future<Map<String, dynamic>> _testPreprocessing() async {
    try {
      // Create a test image (we'll use a placeholder)
      debugPrint('📐 Preprocessing test requires actual image file');
      debugPrint('   Will be tested during actual image capture');
      
      // Verify preprocessing constants
      final targetSize = ImagePreprocessingService.targetSize;
      final expectedSize = targetSize * targetSize * 3; // 224 * 224 * 3 = 150528
      
      debugPrint('   Target size: ${targetSize}x${targetSize}');
      debugPrint('   Expected output: $expectedSize values (${targetSize}x${targetSize}x3)');
      
      return {
        'success': true,
        'targetSize': targetSize,
        'expectedOutputSize': expectedSize,
        'note': 'Requires actual image file - tested during capture',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Get verification summary
  String getVerificationSummary(Map<String, dynamic> results) {
    final buffer = StringBuffer();
    final overallStatus = results['overallStatus'] as String? ?? 'unknown';
    final canDetect = results['canDetect'] as bool? ?? false;
    final tests = results['tests'] as Map<String, dynamic>? ?? {};
    
    buffer.writeln('═══════════════════════════════════════════════════════════');
    buffer.writeln('MODEL VERIFICATION SUMMARY');
    buffer.writeln('═══════════════════════════════════════════════════════════');
    buffer.writeln('');
    buffer.writeln('Overall Status: ${overallStatus.toUpperCase()}');
    buffer.writeln('Can Detect: ${canDetect ? '✅ YES' : '❌ NO'}');
    buffer.writeln('');
    
    if (tests['assetFile'] != null) {
      final asset = tests['assetFile'] as Map<String, dynamic>;
      buffer.writeln('Asset File: ${asset['exists'] == true ? '✅ Found' : '❌ Not Found'}');
      if (asset['exists'] == true) {
        buffer.writeln('  Size: ${asset['sizeMB']} MB');
      }
    }
    
    if (tests['modelLoading'] != null) {
      final loading = tests['modelLoading'] as Map<String, dynamic>;
      buffer.writeln('Model Loading: ${loading['success'] == true ? '✅ PASSED' : '❌ FAILED'}');
      if (loading['error'] != null) {
        buffer.writeln('  Error: ${loading['error']}');
      }
      if (loading['inputShape'] != null) {
        buffer.writeln('  Input: ${loading['inputShape']}');
        buffer.writeln('  Output: ${loading['outputShape']}');
      }
    }
    
    if (tests['modelStructure'] != null) {
      final structure = tests['modelStructure'] as Map<String, dynamic>;
      buffer.writeln('Model Structure: ${structure['success'] == true ? '✅ PASSED' : '❌ FAILED'}');
      if (structure['inputValid'] != null) {
        buffer.writeln('  Input: ${structure['inputValid'] == true ? '✅ Valid' : '❌ Invalid'}');
        buffer.writeln('  Output: ${structure['outputValid'] == true ? '✅ Valid' : '❌ Invalid'}');
      }
    }
    
    if (tests['dummyInference'] != null) {
      final inference = tests['dummyInference'] as Map<String, dynamic>;
      buffer.writeln('Inference Test: ${inference['success'] == true ? '✅ PASSED' : '❌ FAILED'}');
      if (inference['durationMs'] != null) {
        buffer.writeln('  Duration: ${inference['durationMs']}ms');
      }
    }
    
    buffer.writeln('');
    buffer.writeln('═══════════════════════════════════════════════════════════');
    
    return buffer.toString();
  }
}
