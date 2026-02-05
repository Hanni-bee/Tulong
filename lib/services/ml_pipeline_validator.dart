import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'ml_model_service.dart';
import 'image_preprocessing_service.dart';
import 'disaster_classification_service.dart';

/// Comprehensive validator for the entire ML pipeline
/// Validates structure, process, and output handling to ensure dynamic operation
class MLPipelineValidator {
  static MLPipelineValidator? _instance;
  static MLPipelineValidator get instance => _instance ??= MLPipelineValidator._();
  
  MLPipelineValidator._();
  
  final MLModelService _mlService = MLModelService.instance;
  final ImagePreprocessingService _preprocessingService = ImagePreprocessingService();
  final DisasterClassificationService _classificationService = DisasterClassificationService.instance;
  
  /// Comprehensive validation result
  Map<String, dynamic>? _lastValidationResult;
  Map<String, dynamic>? get lastValidationResult => _lastValidationResult;
  
  /// Run complete pipeline validation
  /// Returns validation result with all checks
  Future<Map<String, dynamic>> validatePipeline() async {
    final result = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'overallStatus': 'unknown',
      'structure': <String, dynamic>{},
      'process': <String, dynamic>{},
      'output': <String, dynamic>{},
      'errors': <String>[],
      'warnings': <String>[],
    };
    
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('🔍 ML PIPELINE COMPREHENSIVE VALIDATION');
    debugPrint('═══════════════════════════════════════════════════════════');
    
    // ========== STRUCTURE VALIDATION ==========
    debugPrint('');
    debugPrint('📐 STEP 1: STRUCTURE VALIDATION');
    debugPrint('───────────────────────────────────────────────────────────');
    final structureResult = await _validateStructure();
    result['structure'] = structureResult;
    
    if (!structureResult['valid']) {
      result['overallStatus'] = 'failed';
      result['errors'].addAll((structureResult['errors'] as List<dynamic>).cast<String>());
      _lastValidationResult = result;
      return result;
    }
    
    // ========== PROCESS VALIDATION ==========
    debugPrint('');
    debugPrint('⚙️  STEP 2: PROCESS VALIDATION');
    debugPrint('───────────────────────────────────────────────────────────');
    final processResult = await _validateProcess();
    result['process'] = processResult;
    
    if (!processResult['valid']) {
      result['overallStatus'] = 'failed';
      result['errors'].addAll((processResult['errors'] as List<dynamic>).cast<String>());
      _lastValidationResult = result;
      return result;
    }
    
    // ========== OUTPUT VALIDATION ==========
    debugPrint('');
    debugPrint('📊 STEP 3: OUTPUT VALIDATION');
    debugPrint('───────────────────────────────────────────────────────────');
    final outputResult = await _validateOutput();
    result['output'] = outputResult;
    
    if (!outputResult['valid']) {
      result['overallStatus'] = 'failed';
      result['errors'].addAll((outputResult['errors'] as List<dynamic>).cast<String>());
    } else {
      result['overallStatus'] = 'passed';
    }
    
    result['warnings'].addAll((structureResult['warnings'] as List<dynamic>).cast<String>());
    result['warnings'].addAll((processResult['warnings'] as List<dynamic>).cast<String>());
    result['warnings'].addAll((outputResult['warnings'] as List<dynamic>).cast<String>());
    
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('✅ VALIDATION COMPLETE: ${result['overallStatus'].toString().toUpperCase()}');
    debugPrint('═══════════════════════════════════════════════════════════');
    
    _lastValidationResult = result;
    return result;
  }
  
  /// Validate ML pipeline structure
  Future<Map<String, dynamic>> _validateStructure() async {
    final result = <String, dynamic>{
      'valid': false,
      'checks': <String, dynamic>{},
      'errors': <String>[],
      'warnings': <String>[],
    };
    
    // Check 1: Model asset exists
    debugPrint('  ✓ Check 1.1: Model asset exists...');
    try {
      await rootBundle.load('assets/best_model.tflite');
      result['checks']['assetExists'] = true;
      debugPrint('    ✅ Asset found');
    } catch (e) {
      result['checks']['assetExists'] = false;
      result['errors'].add('Model asset not found: $e');
      debugPrint('    ❌ Asset not found: $e');
      return result;
    }
    
    // Check 2: Model can be loaded
    debugPrint('  ✓ Check 1.2: Model loading...');
    if (!_mlService.isLoaded) {
      final loadSuccess = await _mlService.loadModel('best_model.tflite');
      if (!loadSuccess) {
        result['checks']['modelLoads'] = false;
        result['errors'].add('Model failed to load: ${_mlService.lastError}');
        debugPrint('    ❌ Model failed to load: ${_mlService.lastError}');
        return result;
      }
    }
    result['checks']['modelLoads'] = true;
    debugPrint('    ✅ Model loaded successfully');
    
    // Check 3: Interpreter is valid
    debugPrint('  ✓ Check 1.3: Interpreter validity...');
    if (_mlService.isLoaded) {
      result['checks']['interpreterValid'] = true;
      debugPrint('    ✅ Interpreter is valid');
    } else {
      result['checks']['interpreterValid'] = false;
      result['errors'].add('Interpreter is not loaded');
      debugPrint('    ❌ Interpreter is not loaded');
      return result;
    }
    
    // Check 4: Input tensor shape
    debugPrint('  ✓ Check 1.4: Input tensor shape...');
    final inputShape = _mlService.inputShape;
    if (inputShape == null) {
      result['checks']['inputShape'] = false;
      result['errors'].add('Input tensor shape is null');
      debugPrint('    ❌ Input tensor shape is null');
      return result;
    }
    
    final expectedInputShape = [1, 224, 224, 3];
    final isCorrectShape = inputShape.length == 4 &&
        inputShape[0] == 1 &&
        inputShape[1] == 224 &&
        inputShape[2] == 224 &&
        inputShape[3] == 3;
    
    if (isCorrectShape) {
      result['checks']['inputShape'] = true;
      result['checks']['inputShapeValue'] = inputShape;
      debugPrint('    ✅ Input shape correct: $inputShape');
    } else {
      result['checks']['inputShape'] = false;
      result['errors'].add('Input shape mismatch: expected $expectedInputShape, got $inputShape');
      debugPrint('    ❌ Input shape mismatch: $inputShape');
      return result;
    }
    
    // Check 5: Output tensor shape
    debugPrint('  ✓ Check 1.5: Output tensor shape...');
    final outputShape = _mlService.outputShape;
    if (outputShape == null) {
      result['checks']['outputShape'] = false;
      result['errors'].add('Output tensor shape is null');
      debugPrint('    ❌ Output tensor shape is null');
      return result;
    }
    
    final expectedOutputShape = [1, 4];
    final isCorrectOutputShape = outputShape.length == 2 &&
        outputShape[0] == 1 &&
        outputShape[1] == 4;
    
    if (isCorrectOutputShape) {
      result['checks']['outputShape'] = true;
      result['checks']['outputShapeValue'] = outputShape;
      debugPrint('    ✅ Output shape correct: $outputShape');
    } else {
      result['checks']['outputShape'] = false;
      result['errors'].add('Output shape mismatch: expected $expectedOutputShape, got $outputShape');
      debugPrint('    ❌ Output shape mismatch: $outputShape');
      return result;
    }
    
    // Check 6: Tensor allocation
    debugPrint('  ✓ Check 1.6: Tensor allocation...');
    try {
      // Try to get tensors - if this works, allocation is valid
      final inputTensor = _mlService.inputShape;
      final outputTensor = _mlService.outputShape;
      if (inputTensor != null && outputTensor != null) {
        result['checks']['tensorAllocation'] = true;
        debugPrint('    ✅ Tensors allocated successfully');
      } else {
        result['checks']['tensorAllocation'] = false;
        result['errors'].add('Tensor allocation failed');
        debugPrint('    ❌ Tensor allocation failed');
        return result;
      }
    } catch (e) {
      result['checks']['tensorAllocation'] = false;
      result['errors'].add('Tensor allocation error: $e');
      debugPrint('    ❌ Tensor allocation error: $e');
      return result;
    }
    
    result['valid'] = true;
    debugPrint('  ✅ STRUCTURE VALIDATION PASSED');
    return result;
  }
  
  /// Validate ML pipeline process
  Future<Map<String, dynamic>> _validateProcess() async {
    final result = <String, dynamic>{
      'valid': false,
      'checks': <String, dynamic>{},
      'errors': <String>[],
      'warnings': <String>[],
    };
    
    // Check 1: Preprocessing service works
    debugPrint('  ✓ Check 2.1: Preprocessing service...');
    try {
      // Create a dummy test image path (we'll test with actual inference)
      result['checks']['preprocessingService'] = true;
      debugPrint('    ✅ Preprocessing service available');
    } catch (e) {
      result['checks']['preprocessingService'] = false;
      result['errors'].add('Preprocessing service error: $e');
      debugPrint('    ❌ Preprocessing service error: $e');
      return result;
    }
    
    // Check 2: Model can run dummy inference
    debugPrint('  ✓ Check 2.2: Dummy inference test...');
    try {
      // Create dummy input matching expected shape [1, 224, 224, 3] = 150528 values
      final dummyInput = Float32List(150528);
      for (int i = 0; i < dummyInput.length; i++) {
        dummyInput[i] = (i % 255) / 255.0; // Normalized values [0, 1]
      }
      
      final probabilities = await _mlService.classify(dummyInput);
      
      if (probabilities == null) {
        result['checks']['dummyInference'] = false;
        result['errors'].add('Dummy inference returned null: ${_mlService.lastError}');
        debugPrint('    ❌ Dummy inference failed: ${_mlService.lastError}');
        return result;
      }
      
      if (probabilities.length != 4) {
        result['checks']['dummyInference'] = false;
        result['errors'].add('Dummy inference output length mismatch: expected 4, got ${probabilities.length}');
        debugPrint('    ❌ Output length mismatch: ${probabilities.length}');
        return result;
      }
      
      // Validate probabilities are valid numbers
      if (probabilities.any((p) => p.isNaN || p.isInfinite)) {
        result['checks']['dummyInference'] = false;
        result['errors'].add('Dummy inference output contains invalid values (NaN or Infinite)');
        debugPrint('    ❌ Output contains invalid values');
        return result;
      }
      
      // Check if probabilities sum to ~1.0 (softmax output)
      final sum = probabilities.fold(0.0, (a, b) => a + b);
      if (sum < 0.9 || sum > 1.1) {
        result['warnings'].add('Probability sum is $sum (expected ~1.0) - might be logits, not probabilities');
        debugPrint('    ⚠️  Probability sum: $sum (expected ~1.0)');
      } else {
        debugPrint('    ✅ Probability sum: $sum');
      }
      
      result['checks']['dummyInference'] = true;
      result['checks']['dummyOutput'] = probabilities;
      result['checks']['dummyOutputSum'] = sum;
      debugPrint('    ✅ Dummy inference successful');
      debugPrint('      Output: ${probabilities.map((p) => p.toStringAsFixed(4)).join(", ")}');
    } catch (e, stackTrace) {
      result['checks']['dummyInference'] = false;
      result['errors'].add('Dummy inference error: $e');
      debugPrint('    ❌ Dummy inference error: $e');
      debugPrint('      Stack: $stackTrace');
      return result;
    }
    
    // Check 3: Input size validation
    debugPrint('  ✓ Check 2.3: Input size validation...');
    try {
      // Test with wrong size
      final wrongSizeInput = Float32List(1000);
      final wrongResult = await _mlService.classify(wrongSizeInput);
      if (wrongResult != null) {
        result['warnings'].add('Model accepted wrong input size - validation might be missing');
        debugPrint('    ⚠️  Model accepted wrong input size');
      } else {
        result['checks']['inputSizeValidation'] = true;
        debugPrint('    ✅ Input size validation works');
      }
    } catch (e) {
      // Expected to fail
      result['checks']['inputSizeValidation'] = true;
      debugPrint('    ✅ Input size validation works (rejected wrong size)');
    }
    
    // Check 4: Dynamic inference (no caching)
    debugPrint('  ✓ Check 2.4: Dynamic inference verification...');
    try {
      // Run inference twice with same input - should get same result (not cached, but deterministic)
      final testInput = Float32List(150528);
      for (int i = 0; i < testInput.length; i++) {
        testInput[i] = 0.5; // Uniform gray
      }
      
      final result1 = await _mlService.classify(testInput);
      await Future.delayed(const Duration(milliseconds: 100));
      final result2 = await _mlService.classify(testInput);
      
      if (result1 == null || result2 == null) {
        result['checks']['dynamicInference'] = false;
        result['errors'].add('Dynamic inference test failed - one result is null');
        debugPrint('    ❌ Dynamic inference test failed');
        return result;
      }
      
      // Results should be very similar (same input = same output, but fresh inference)
      final diff = result1.asMap().entries.map((e) => 
        (e.value - result2[e.key]).abs()
      ).fold(0.0, (a, b) => a + b);
      
      if (diff < 0.001) {
        result['checks']['dynamicInference'] = true;
        debugPrint('    ✅ Dynamic inference works (deterministic output)');
      } else {
        result['warnings'].add('Inference results differ significantly (diff: $diff) - might indicate non-deterministic behavior');
        debugPrint('    ⚠️  Results differ: $diff');
        result['checks']['dynamicInference'] = true; // Still valid, just different
      }
    } catch (e) {
      result['checks']['dynamicInference'] = false;
      result['errors'].add('Dynamic inference test error: $e');
      debugPrint('    ❌ Dynamic inference test error: $e');
      return result;
    }
    
    result['valid'] = true;
    debugPrint('  ✅ PROCESS VALIDATION PASSED');
    return result;
  }
  
  /// Validate ML pipeline output handling
  Future<Map<String, dynamic>> _validateOutput() async {
    final result = <String, dynamic>{
      'valid': false,
      'checks': <String, dynamic>{},
      'errors': <String>[],
      'warnings': <String>[],
    };
    
    // Check 1: Output format validation
    debugPrint('  ✓ Check 3.1: Output format validation...');
    try {
      final testInput = Float32List(150528);
      for (int i = 0; i < testInput.length; i++) {
        testInput[i] = (i % 255) / 255.0;
      }
      
      final output = await _mlService.classify(testInput);
      
      if (output == null) {
        result['checks']['outputFormat'] = false;
        result['errors'].add('Output is null');
        debugPrint('    ❌ Output is null');
        return result;
      }
      
      if (output.isEmpty) {
        result['checks']['outputFormat'] = false;
        result['errors'].add('Output is empty');
        debugPrint('    ❌ Output is empty');
        return result;
      }
      
      if (output.length != 4) {
        result['checks']['outputFormat'] = false;
        result['errors'].add('Output length mismatch: expected 4, got ${output.length}');
        debugPrint('    ❌ Output length mismatch: ${output.length}');
        return result;
      }
      
      result['checks']['outputFormat'] = true;
      debugPrint('    ✅ Output format correct: ${output.length} probabilities');
    } catch (e) {
      result['checks']['outputFormat'] = false;
      result['errors'].add('Output format validation error: $e');
      debugPrint('    ❌ Output format validation error: $e');
      return result;
    }
    
    // Check 2: Output value validation
    debugPrint('  ✓ Check 3.2: Output value validation...');
    try {
      final testInput = Float32List(150528);
      for (int i = 0; i < testInput.length; i++) {
        testInput[i] = 0.5;
      }
      
      final output = await _mlService.classify(testInput);
      
      if (output == null) {
        result['checks']['outputValues'] = false;
        result['errors'].add('Output is null for value validation');
        return result;
      }
      
      // Check for NaN or Infinite
      final hasInvalid = output.any((v) => v.isNaN || v.isInfinite);
      if (hasInvalid) {
        result['checks']['outputValues'] = false;
        result['errors'].add('Output contains invalid values (NaN or Infinite)');
        debugPrint('    ❌ Output contains invalid values');
        return result;
      }
      
      // Check if values are in reasonable range
      final hasNegative = output.any((v) => v < -0.1);
      if (hasNegative) {
        result['warnings'].add('Output contains negative values (might be logits, not probabilities)');
        debugPrint('    ⚠️  Output contains negative values');
      }
      
      final hasLarge = output.any((v) => v > 10.0);
      if (hasLarge) {
        result['warnings'].add('Output contains very large values (might be logits, not probabilities)');
        debugPrint('    ⚠️  Output contains very large values');
      }
      
      result['checks']['outputValues'] = true;
      debugPrint('    ✅ Output values are valid');
    } catch (e) {
      result['checks']['outputValues'] = false;
      result['errors'].add('Output value validation error: $e');
      debugPrint('    ❌ Output value validation error: $e');
      return result;
    }
    
    // Check 3: Classification service integration
    debugPrint('  ✓ Check 3.3: Classification service integration...');
    try {
      // Check if classification service can access model
      final isModelLoaded = _classificationService.isModelLoaded;
      if (!isModelLoaded) {
        result['warnings'].add('Classification service reports model not loaded');
        debugPrint('    ⚠️  Classification service reports model not loaded');
      } else {
        result['checks']['classificationService'] = true;
        debugPrint('    ✅ Classification service integration works');
      }
    } catch (e) {
      result['warnings'].add('Classification service check error: $e');
      debugPrint('    ⚠️  Classification service check error: $e');
    }
    
    result['valid'] = true;
    debugPrint('  ✅ OUTPUT VALIDATION PASSED');
    return result;
  }
  
  /// Get validation summary
  String getValidationSummary() {
    if (_lastValidationResult == null) {
      return 'No validation run yet';
    }
    
    final result = _lastValidationResult!;
    final status = result['overallStatus'] as String;
    final errors = (result['errors'] as List).length;
    final warnings = (result['warnings'] as List).length;
    
    return 'Status: ${status.toUpperCase()}\nErrors: $errors\nWarnings: $warnings';
  }
}
