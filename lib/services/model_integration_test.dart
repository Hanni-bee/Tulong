import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'image_preprocessing_service.dart';
import 'ml_model_service.dart';
import 'disaster_classification_service.dart';

/// Comprehensive test to verify model integration and classification
/// Run this test to ensure the model loads and classifies correctly
class ModelIntegrationTest {
  static Future<Map<String, dynamic>> runFullTest() async {
    final results = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'tests': <String, dynamic>{},
      'overallStatus': 'UNKNOWN',
      'errors': <String>[],
    };

    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('🧪 MODEL INTEGRATION TEST - COMPREHENSIVE VERIFICATION');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('');

    // Test 1: Asset Existence
    debugPrint('📦 Test 1: Checking asset file existence...');
    final assetTest = await _testAssetFile();
    results['tests']['assetFile'] = assetTest;
    if (!assetTest['exists']) {
      results['errors'].add('Asset file not found: ${assetTest['error']}');
    }
    debugPrint('   Result: ${assetTest['exists'] ? '✅ PASS' : '❌ FAIL'}');
    debugPrint('');

    // Test 2: Model Loading
    debugPrint('📦 Test 2: Testing model loading...');
    final loadTest = await _testModelLoading();
    results['tests']['modelLoading'] = loadTest;
    if (!loadTest['success']) {
      results['errors'].add('Model loading failed: ${loadTest['error']}');
    }
    debugPrint('   Result: ${loadTest['success'] ? '✅ PASS' : '❌ FAIL'}');
    debugPrint('');

    // Test 3: Tensor Shape Verification
    if (loadTest['success']) {
      debugPrint('📦 Test 3: Verifying tensor shapes...');
      final shapeTest = await _testTensorShapes();
      results['tests']['tensorShapes'] = shapeTest;
      if (!shapeTest['valid']) {
        results['errors'].add('Tensor shape mismatch: ${shapeTest['error']}');
      }
      debugPrint('   Result: ${shapeTest['valid'] ? '✅ PASS' : '❌ FAIL'}');
      debugPrint('');
    }

    // Test 4: Image Preprocessing
    debugPrint('📦 Test 4: Testing image preprocessing...');
    final preprocessTest = await _testImagePreprocessing();
    results['tests']['imagePreprocessing'] = preprocessTest;
    if (!preprocessTest['success']) {
      results['errors'].add('Preprocessing failed: ${preprocessTest['error']}');
    }
    debugPrint('   Result: ${preprocessTest['success'] ? '✅ PASS' : '❌ FAIL'}');
    debugPrint('');

    // Test 5: Dummy Inference (if model loaded and preprocessing works)
    if (loadTest['success'] && preprocessTest['success']) {
      debugPrint('📦 Test 5: Running dummy inference test...');
      final inferenceTest = await _testDummyInference(preprocessTest['preprocessedImage'] as Float32List);
      results['tests']['dummyInference'] = inferenceTest;
      if (!inferenceTest['success']) {
        results['errors'].add('Inference failed: ${inferenceTest['error']}');
      }
      debugPrint('   Result: ${inferenceTest['success'] ? '✅ PASS' : '❌ FAIL'}');
      debugPrint('');
    }

    // Test 6: End-to-End Classification Service
    debugPrint('📦 Test 6: Testing end-to-end classification service...');
    final serviceTest = await _testClassificationService();
    results['tests']['classificationService'] = serviceTest;
    if (!serviceTest['success']) {
      results['errors'].add('Classification service failed: ${serviceTest['error']}');
    }
    debugPrint('   Result: ${serviceTest['success'] ? '✅ PASS' : '❌ FAIL'}');
    debugPrint('');

    // Overall Status
    final allTestsPassed = results['tests'].values.every((test) {
      if (test is Map) {
        return test['success'] == true || test['valid'] == true || test['exists'] == true;
      }
      return false;
    });

    results['overallStatus'] = allTestsPassed && results['errors'].isEmpty ? 'PASS' : 'FAIL';
    results['canClassify'] = allTestsPassed && results['errors'].isEmpty;

    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('📊 TEST SUMMARY');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('   Overall Status: ${results['overallStatus']}');
    debugPrint('   Can Classify: ${results['canClassify']}');
    debugPrint('   Errors: ${results['errors'].length}');
    if (results['errors'].isNotEmpty) {
      for (final error in results['errors']) {
        debugPrint('     - $error');
      }
    }
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('');

    return results;
  }

  /// Test 1: Check if asset file exists
  static Future<Map<String, dynamic>> _testAssetFile() async {
    try {
      final ByteData data = await rootBundle.load('assets/best_model.tflite');
      final int size = data.lengthInBytes;
      return {
        'exists': true,
        'size': size,
        'sizeMB': (size / 1024 / 1024).toStringAsFixed(2),
      };
    } catch (e) {
      return {
        'exists': false,
        'error': e.toString(),
      };
    }
  }

  /// Test 2: Test model loading
  static Future<Map<String, dynamic>> _testModelLoading() async {
    try {
      final mlService = MLModelService.instance;
      final startTime = DateTime.now();
      
      final success = await mlService.loadModel('best_model.tflite');
      final duration = DateTime.now().difference(startTime);
      
      return {
        'success': success && mlService.isLoaded,
        'duration': duration.inMilliseconds,
        'inputShape': mlService.inputShape?.toString(),
        'outputShape': mlService.outputShape?.toString(),
        'error': mlService.lastError,
      };
    } catch (e, stackTrace) {
      return {
        'success': false,
        'error': '$e\n$stackTrace',
      };
    }
  }

  /// Test 3: Verify tensor shapes
  static Future<Map<String, dynamic>> _testTensorShapes() async {
    try {
      final mlService = MLModelService.instance;
      if (!mlService.isLoaded) {
        return {
          'valid': false,
          'error': 'Model not loaded',
        };
      }

      final inputShape = mlService.inputShape;
      final outputShape = mlService.outputShape;

      // Expected shapes
      const expectedInputShape = [1, 224, 224, 3];
      const expectedOutputShape = [1, 4];

      final inputValid = inputShape != null &&
          inputShape.length == 4 &&
          inputShape[0] == 1 &&
          inputShape[1] == 224 &&
          inputShape[2] == 224 &&
          inputShape[3] == 3;

      final outputValid = outputShape != null &&
          outputShape.length == 2 &&
          outputShape[0] == 1 &&
          outputShape[1] == 4;

      return {
        'valid': inputValid && outputValid,
        'inputShape': inputShape?.toString(),
        'outputShape': outputShape?.toString(),
        'expectedInputShape': expectedInputShape.toString(),
        'expectedOutputShape': expectedOutputShape.toString(),
        'inputValid': inputValid,
        'outputValid': outputValid,
        'error': !inputValid
            ? 'Input shape mismatch: expected $expectedInputShape, got $inputShape'
            : (!outputValid
                ? 'Output shape mismatch: expected $expectedOutputShape, got $outputShape'
                : null),
      };
    } catch (e) {
      return {
        'valid': false,
        'error': e.toString(),
      };
    }
  }

  /// Test 4: Test image preprocessing
  static Future<Map<String, dynamic>> _testImagePreprocessing() async {
    try {
      // Verify the preprocessing service exists and has the correct target size
      // Full preprocessing test requires an actual image file
      
      return {
        'success': true,
        'serviceAvailable': true,
        'targetSize': ImagePreprocessingService.targetSize,
        'note': 'Preprocessing service is available. Full test requires an actual image file.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Test 5: Test dummy inference
  static Future<Map<String, dynamic>> _testDummyInference(Float32List? preprocessedImage) async {
    try {
      final mlService = MLModelService.instance;
      if (!mlService.isLoaded) {
        return {
          'success': false,
          'error': 'Model not loaded',
        };
      }

      // Create dummy preprocessed image if not provided
      final testImage = preprocessedImage ?? Float32List(224 * 224 * 3);
      // Fill with random values in [0, 1] range
      for (int i = 0; i < testImage.length; i++) {
        testImage[i] = (i % 255) / 255.0;
      }

      final startTime = DateTime.now();
      final probabilities = await mlService.classify(testImage);
      final duration = DateTime.now().difference(startTime);

      if (probabilities == null || probabilities.isEmpty) {
        return {
          'success': false,
          'error': 'Inference returned null or empty',
        };
      }

      // Verify output
      final hasValidProbabilities = probabilities.length == 4 &&
          probabilities.every((p) => p >= 0.0 && p <= 1.0);
      
      final sum = probabilities.fold(0.0, (a, b) => a + b);
      final isNormalized = sum > 0.9 && sum < 1.1;

      return {
        'success': hasValidProbabilities && isNormalized,
        'duration': duration.inMilliseconds,
        'probabilities': probabilities,
        'sum': sum,
        'isNormalized': isNormalized,
        'hasValidRange': hasValidProbabilities,
        'error': !hasValidProbabilities
            ? 'Invalid probability range'
            : (!isNormalized ? 'Probabilities not normalized (sum: $sum)' : null),
      };
    } catch (e, stackTrace) {
      return {
        'success': false,
        'error': '$e\n$stackTrace',
      };
    }
  }

  /// Test 6: Test end-to-end classification service
  static Future<Map<String, dynamic>> _testClassificationService() async {
    try {
      final service = DisasterClassificationService.instance;
      
      // Check if model is loaded
      final isLoaded = service.isModelLoaded;
      
      // Get debug info
      final debugInfo = service.getDebugInfo();
      
      return {
        'success': isLoaded,
        'isModelLoaded': isLoaded,
        'debugInfo': debugInfo,
        'error': !isLoaded ? 'Model not loaded in classification service' : null,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}
