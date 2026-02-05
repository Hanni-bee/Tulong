import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tflite;

/// Diagnostic service to check why model isn't working in Flutter
class ModelDiagnosticService {
  static ModelDiagnosticService? _instance;
  static ModelDiagnosticService get instance => _instance ??= ModelDiagnosticService._();
  
  ModelDiagnosticService._();
  
  /// Run comprehensive diagnostics on the model
  Future<Map<String, dynamic>> runDiagnostics() async {
    final results = <String, dynamic>{
      'modelFileExists': false,
      'modelFileSize': 0,
      'canLoadModel': false,
      'inputShape': null,
      'outputShape': null,
      'canAllocateTensors': false,
      'canRunInference': false,
      'errors': <String>[],
    };
    
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('🔍 MODEL DIAGNOSTIC SERVICE');
    debugPrint('═══════════════════════════════════════════════════════════');
    
    // Step 1: Check if model file exists
    try {
      final ByteData assetData = await rootBundle.load('assets/best_model.tflite');
      results['modelFileExists'] = true;
      results['modelFileSize'] = assetData.lengthInBytes;
      debugPrint('✅ Model file exists in assets');
      debugPrint('   File size: ${(assetData.lengthInBytes / 1024 / 1024).toStringAsFixed(2)} MB');
    } catch (e) {
      results['errors'].add('Model file not found: $e');
      debugPrint('❌ Model file not found: $e');
      return results;
    }
    
    // Step 2: Try to load model
    tflite.Interpreter? interpreter;
    try {
      debugPrint('');
      debugPrint('📦 Attempting to load model...');
      final options = tflite.InterpreterOptions()..threads = 4;
      
      interpreter = await tflite.Interpreter.fromAsset(
        'best_model.tflite',
        options: options,
      );
      
      if (interpreter != null) {
        results['canLoadModel'] = true;
        debugPrint('✅ Model loaded successfully');
      } else {
        results['errors'].add('Interpreter is null after fromAsset');
        debugPrint('❌ Interpreter is null after fromAsset');
        return results;
      }
    } catch (e, stackTrace) {
      results['errors'].add('Failed to load model: $e');
      debugPrint('❌ Failed to load model: $e');
      debugPrint('   Stack trace: $stackTrace');
      return results;
    }
    
    // Step 3: Check input/output shapes
    try {
      debugPrint('');
      debugPrint('📐 Checking tensor shapes...');
      
      final inputTensor = interpreter!.getInputTensor(0);
      final outputTensor = interpreter.getOutputTensor(0);
      
      results['inputShape'] = inputTensor.shape;
      results['outputShape'] = outputTensor.shape;
      
      debugPrint('   Input shape: ${inputTensor.shape}');
      debugPrint('   Input type: ${inputTensor.type}');
      debugPrint('   Output shape: ${outputTensor.shape}');
      debugPrint('   Output type: ${outputTensor.type}');
      
      // Check if input shape is problematic
      final inputShape = inputTensor.shape;
      if (inputShape.length == 2 && inputShape[0] == 1 && inputShape[1] == 150528) {
        results['errors'].add('Model has wrong input shape [1, 150528] instead of [1, 224, 224, 3]');
        debugPrint('❌ PROBLEM: Model has wrong input shape [1, 150528]');
        debugPrint('   This will cause RESIZE_BILINEAR errors');
      } else if (inputShape.length == 4 && 
                 inputShape[0] == 1 && 
                 inputShape[1] == 224 && 
                 inputShape[2] == 224 && 
                 inputShape[3] == 3) {
        debugPrint('✅ Input shape is correct: [1, 224, 224, 3]');
      } else {
        results['errors'].add('Unexpected input shape: $inputShape');
        debugPrint('⚠️ Unexpected input shape: $inputShape');
      }
    } catch (e) {
      results['errors'].add('Failed to get tensor shapes: $e');
      debugPrint('❌ Failed to get tensor shapes: $e');
      return results;
    }
    
    // Step 4: Try to allocate tensors
    try {
      debugPrint('');
      debugPrint('🔄 Attempting to allocate tensors...');
      
      // Try reshaping first if needed
      final inputShape = interpreter!.getInputTensor(0).shape;
      if (inputShape.length == 2) {
        debugPrint('   Reshaping input tensor to [1, 224, 224, 3]...');
        interpreter.resizeInputTensor(0, [1, 224, 224, 3]);
      }
      
      interpreter.allocateTensors();
      results['canAllocateTensors'] = true;
      debugPrint('✅ Tensors allocated successfully');
    } catch (e, stackTrace) {
      results['errors'].add('Failed to allocate tensors: $e');
      debugPrint('❌ Failed to allocate tensors: $e');
      debugPrint('   This is the ROOT CAUSE of inference failures');
      debugPrint('   Stack trace: $stackTrace');
      return results;
    }
    
    // Step 5: Try dummy inference
    try {
      debugPrint('');
      debugPrint('🧪 Attempting dummy inference...');
      
      final inputTensor = interpreter!.getInputTensor(0);
      final outputTensor = interpreter.getOutputTensor(0);
      
      // Create dummy input
      final inputSize = inputTensor.shape.reduce((a, b) => a * b);
      final dummyInput = List.filled(inputSize, 0.5).map((e) => e.toDouble()).toList();
      final inputBuffer = [Float32List.fromList(dummyInput)];
      
      final outputSize = outputTensor.shape.reduce((a, b) => a * b);
      final outputBuffer = [Float32List(outputSize)];
      
      debugPrint('   Input buffer size: ${inputBuffer[0].length}');
      debugPrint('   Output buffer size: ${outputBuffer[0].length}');
      
      interpreter.run(inputBuffer, outputBuffer);
      
      // Check output
      final outputSum = outputBuffer[0].fold(0.0, (a, b) => a + b);
      if (outputSum > 0) {
        results['canRunInference'] = true;
        debugPrint('✅ Dummy inference successful');
        debugPrint('   Output values: ${outputBuffer[0].take(4).map((v) => v.toStringAsFixed(4)).join(", ")}');
      } else {
        results['errors'].add('Inference returned all zeros');
        debugPrint('⚠️ Inference returned all zeros');
      }
    } catch (e, stackTrace) {
      results['errors'].add('Failed to run inference: $e');
      debugPrint('❌ Failed to run inference: $e');
      debugPrint('   Stack trace: $stackTrace');
    } finally {
      interpreter?.close();
    }
    
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('📊 DIAGNOSTIC SUMMARY');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('Model file exists: ${results['modelFileExists']}');
    debugPrint('Can load model: ${results['canLoadModel']}');
    debugPrint('Can allocate tensors: ${results['canAllocateTensors']}');
    debugPrint('Can run inference: ${results['canRunInference']}');
    debugPrint('Errors: ${results['errors'].length}');
    if (results['errors'].isNotEmpty) {
      for (final error in results['errors']) {
        debugPrint('   - $error');
      }
    }
    debugPrint('═══════════════════════════════════════════════════════════');
    
    return results;
  }
}
