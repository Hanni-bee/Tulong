import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'ml_model_service.dart';
import 'disaster_classification_service.dart';
import 'image_preprocessing_service.dart';

/// Service for testing and debugging ML model functionality
class ModelTestService {
  static ModelTestService? _instance;
  static ModelTestService get instance => _instance ??= ModelTestService._();
  
  ModelTestService._();
  
  final MLModelService _mlService = MLModelService.instance;
  final DisasterClassificationService _classificationService = DisasterClassificationService.instance;
  
  /// Run comprehensive model test
  Future<Map<String, dynamic>> runComprehensiveTest() async {
    final results = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'tests': <String, dynamic>{},
      'overallStatus': 'unknown',
    };
    
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('🧪 COMPREHENSIVE ML MODEL TEST SUITE');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('');
    
    // Test 1: Model Loading
    debugPrint('📦 Test 1: Model Loading...');
    final loadResult = await _testModelLoading();
    results['tests']['modelLoading'] = loadResult;
    
    if (!loadResult['success']) {
      results['overallStatus'] = 'failed';
      results['error'] = loadResult['error'];
      debugPrint('❌ Model loading failed - stopping tests');
      return results;
    }
    
    // Test 2: Model Structure Verification
    debugPrint('');
    debugPrint('📦 Test 2: Model Structure Verification...');
    final structureResult = await _testModelStructure();
    results['tests']['modelStructure'] = structureResult;
    
    // Test 3: Dummy Input Test
    debugPrint('');
    debugPrint('📦 Test 3: Dummy Input Test...');
    final dummyTestResult = await _testDummyInput();
    results['tests']['dummyInput'] = dummyTestResult;
    
    // Test 4: Preprocessing Test
    debugPrint('');
    debugPrint('📦 Test 4: Image Preprocessing Test...');
    final preprocessingResult = await _testPreprocessing();
    results['tests']['preprocessing'] = preprocessingResult;
    
    // Determine overall status
    final allTestsPassed = [
      loadResult['success'] as bool? ?? false,
      structureResult['success'] as bool? ?? false,
      dummyTestResult['success'] as bool? ?? false,
    ].every((result) => result == true);
    
    results['overallStatus'] = allTestsPassed ? 'passed' : 'failed';
    
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('${allTestsPassed ? '✅' : '❌'} OVERALL TEST STATUS: ${results['overallStatus'].toString().toUpperCase()}');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('');
    
    return results;
  }
  
  /// Test model loading
  Future<Map<String, dynamic>> _testModelLoading() async {
    try {
      final startTime = DateTime.now();
      final success = await _classificationService.loadModel();
      final duration = DateTime.now().difference(startTime);
      
      final result = {
        'success': success && _mlService.isLoaded,
        'durationMs': duration.inMilliseconds,
        'isLoaded': _mlService.isLoaded,
        'error': _mlService.lastError ?? _classificationService.getDebugInfo()['lastError'],
      };
      
      if (result['success']) {
        debugPrint('✅ Model loading test PASSED (${duration.inMilliseconds}ms)');
      } else {
        debugPrint('❌ Model loading test FAILED');
        debugPrint('   Error: ${result['error']}');
      }
      
      return result;
    } catch (e, stackTrace) {
      debugPrint('❌ Model loading test ERROR: $e');
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
      
      final result = {
        'success': inputShape != null && outputShape != null,
        'inputShape': inputShape?.toString(),
        'outputShape': outputShape?.toString(),
        'inputSize': inputShape != null
            ? (inputShape.length > 1
                ? inputShape.sublist(1).reduce((a, b) => a * b)
                : inputShape.reduce((a, b) => a * b))
            : null,
        'outputSize': outputShape != null
            ? (outputShape.length > 1
                ? outputShape.sublist(1).reduce((a, b) => a * b)
                : outputShape.reduce((a, b) => a * b))
            : null,
      };
      
      if (result['success'] == true) {
        debugPrint('✅ Model structure test PASSED');
        debugPrint('   Input: ${result['inputShape']} (${result['inputSize']} elements)');
        debugPrint('   Output: ${result['outputShape']} (${result['outputSize']} elements)');
        
        // Verify expected sizes
        final expectedInput = 224 * 224 * 3; // 150528
        final expectedOutput = 4; // 4 classes
        
        if (result['inputSize'] == expectedInput) {
          debugPrint('   ✅ Input size correct: $expectedInput');
        } else {
          debugPrint('   ⚠️ Input size mismatch: expected $expectedInput, got ${result['inputSize']}');
        }
        
        if (result['outputSize'] == expectedOutput) {
          debugPrint('   ✅ Output size correct: $expectedOutput');
        } else {
          debugPrint('   ⚠️ Output size mismatch: expected $expectedOutput, got ${result['outputSize']}');
        }
      } else {
        debugPrint('❌ Model structure test FAILED');
      }
      
      return result;
    } catch (e, stackTrace) {
      debugPrint('❌ Model structure test ERROR: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Test with dummy input
  Future<Map<String, dynamic>> _testDummyInput() async {
    try {
      if (!_mlService.isLoaded) {
        return {
          'success': false,
          'error': 'Model not loaded',
        };
      }
      
      // Create dummy input (224x224x3 = 150528 values)
      final dummyInput = Float32List(224 * 224 * 3);
      // Fill with small random values for testing
      for (int i = 0; i < dummyInput.length; i++) {
        dummyInput[i] = (i % 255) / 255.0;
      }
      
      final startTime = DateTime.now();
      final output = await _mlService.classify(dummyInput);
      final duration = DateTime.now().difference(startTime);
      
      final result = {
        'success': output != null && output.length > 0,
        'outputLength': output?.length ?? 0,
        'durationMs': duration.inMilliseconds,
        'outputValues': output?.take(4).toList(),
      };
      
      if (result['success'] == true) {
        debugPrint('✅ Dummy input test PASSED (${duration.inMilliseconds}ms)');
        debugPrint('   Output length: ${result['outputLength']}');
        if (output != null && output.length >= 4) {
          debugPrint('   First 4 outputs:');
          for (int i = 0; i < 4; i++) {
            debugPrint('     [$i]: ${output[i].toStringAsFixed(6)}');
          }
        }
      } else {
        debugPrint('❌ Dummy input test FAILED');
      }
      
      return result;
    } catch (e, stackTrace) {
      debugPrint('❌ Dummy input test ERROR: $e');
      debugPrint('   Stack trace: $stackTrace');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Test image preprocessing
  Future<Map<String, dynamic>> _testPreprocessing() async {
    try {
      // Create a test image file (we'll use a placeholder)
      // In real scenario, this would use an actual image
      debugPrint('   ⚠️ Preprocessing test requires actual image file');
      debugPrint('   This test will be performed during actual image capture');
      
      return {
        'success': true,
        'note': 'Requires actual image file - will be tested during capture',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Get test summary for UI display
  String getTestSummary(Map<String, dynamic> testResults) {
    final overallStatus = testResults['overallStatus'] as String? ?? 'unknown';
    final tests = testResults['tests'] as Map<String, dynamic>? ?? {};
    
    final buffer = StringBuffer();
    buffer.writeln('Test Status: ${overallStatus.toUpperCase()}');
    buffer.writeln('');
    
    if (tests['modelLoading'] != null) {
      final loading = tests['modelLoading'] as Map<String, dynamic>;
      buffer.writeln('Model Loading: ${loading['success'] == true ? '✅ PASSED' : '❌ FAILED'}');
      if (loading['error'] != null) {
        buffer.writeln('  Error: ${loading['error']}');
      }
    }
    
    if (tests['modelStructure'] != null) {
      final structure = tests['modelStructure'] as Map<String, dynamic>;
      buffer.writeln('Model Structure: ${structure['success'] == true ? '✅ PASSED' : '❌ FAILED'}');
      buffer.writeln('  Input: ${structure['inputShape']}');
      buffer.writeln('  Output: ${structure['outputShape']}');
    }
    
    if (tests['dummyInput'] != null) {
      final dummy = tests['dummyInput'] as Map<String, dynamic>;
      buffer.writeln('Dummy Input: ${dummy['success'] == true ? '✅ PASSED' : '❌ FAILED'}');
    }
    
    return buffer.toString();
  }
}
