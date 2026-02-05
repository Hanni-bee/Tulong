"""
Analyze and Fix TFLite Model for Flutter
========================================
This script analyzes the current best_model.tflite and attempts to fix it
if there are issues with input shape or other problems.
"""

import tensorflow as tf
import numpy as np
from pathlib import Path
import sys
import io

# Fix encoding for Windows
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

def analyze_model(model_path):
    """Analyze the current TFLite model and report issues."""
    print("=" * 70)
    print("ANALYZING CURRENT TFLITE MODEL")
    print("=" * 70)
    print(f"Model path: {model_path}")
    print()
    
    if not Path(model_path).exists():
        print(f"ERROR: Model file not found at {model_path}")
        return None
    
    try:
        # Load the TFLite model
        print("Step 1: Loading TFLite model...")
        interpreter = tf.lite.Interpreter(model_path=model_path)
        interpreter.allocate_tensors()
        
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        
        print("SUCCESS: Model loaded successfully")
        print()
        
        # Analyze input
        print("Step 2: Analyzing input tensor...")
        input_shape = input_details[0]['shape']
        input_dtype = input_details[0]['dtype']
        input_name = input_details[0]['name']
        
        print(f"  Input name: {input_name}")
        print(f"  Input shape: {input_shape}")
        print(f"  Input dtype: {input_dtype}")
        print(f"  Input size: {np.prod(input_shape)} elements")
        
        # Check if shape is correct
        expected_shape = [1, 224, 224, 3]
        is_correct_shape = list(input_shape) == expected_shape
        is_wrong_shape = len(input_shape) == 2 and input_shape[0] == 1 and input_shape[1] == 150528
        
        print()
        if is_correct_shape:
            print("  STATUS: Input shape is CORRECT [1, 224, 224, 3]")
        elif is_wrong_shape:
            print("  STATUS: Input shape is WRONG [1, 150528]")
            print("  PROBLEM: Model was saved with 2D input but needs 4D")
            print("  This will cause RESIZE_BILINEAR errors in Flutter")
        else:
            print(f"  STATUS: Unexpected input shape: {input_shape}")
        
        # Analyze output
        print()
        print("Step 3: Analyzing output tensor...")
        output_shape = output_details[0]['shape']
        output_dtype = output_details[0]['dtype']
        output_name = output_details[0]['name']
        
        print(f"  Output name: {output_name}")
        print(f"  Output shape: {output_shape}")
        print(f"  Output dtype: {output_dtype}")
        print(f"  Output size: {np.prod(output_shape)} elements")
        
        # Test inference
        print()
        print("Step 4: Testing inference...")
        try:
            # Create dummy input matching the actual shape
            if is_wrong_shape:
                # Model expects [1, 150528] but we'll test with that
                dummy_input = np.random.random((1, 150528)).astype(np.float32)
            else:
                dummy_input = np.random.random((1, 224, 224, 3)).astype(np.float32)
            
            interpreter.set_tensor(input_details[0]['index'], dummy_input)
            interpreter.invoke()
            output = interpreter.get_tensor(output_details[0]['index'])
            
            print("  SUCCESS: Inference test passed")
            print(f"  Output shape: {output.shape}")
            print(f"  Output values: {output[0]}")
            print(f"  Output sum: {np.sum(output[0]):.6f}")
            print(f"  Output max: {np.max(output[0]):.6f}")
            print(f"  Output min: {np.min(output[0]):.6f}")
            
            # Check if output looks like probabilities
            if np.all(output[0] >= 0) and np.all(output[0] <= 1):
                output_sum = np.sum(output[0])
                if 0.9 <= output_sum <= 1.1:
                    print("  STATUS: Output appears to be probabilities (sum ~1.0)")
                else:
                    print(f"  WARNING: Output sum is {output_sum:.6f} (not ~1.0)")
            else:
                print("  WARNING: Output values outside [0, 1] range (might be logits)")
                
        except Exception as e:
            print(f"  ERROR: Inference test failed: {e}")
            print("  This indicates the model has architecture issues")
            return {
                'can_load': True,
                'input_shape': input_shape,
                'output_shape': output_shape,
                'can_infer': False,
                'error': str(e),
                'needs_fix': True,
            }
        
        return {
            'can_load': True,
            'input_shape': list(input_shape),
            'output_shape': list(output_shape),
            'can_infer': True,
            'needs_fix': is_wrong_shape,
            'error': None,
        }
        
    except Exception as e:
        print(f"ERROR: Failed to analyze model: {e}")
        import traceback
        traceback.print_exc()
        return {
            'can_load': False,
            'error': str(e),
            'needs_fix': True,
        }

def try_fix_model(input_model_path, output_model_path):
    """Try to fix the model by loading and re-saving with correct shape."""
    print()
    print("=" * 70)
    print("ATTEMPTING TO FIX MODEL")
    print("=" * 70)
    print()
    
    try:
        # Load the model
        print("Step 1: Loading model...")
        interpreter = tf.lite.Interpreter(model_path=input_model_path)
        interpreter.allocate_tensors()
        
        input_details = interpreter.get_input_details()
        input_shape = input_details[0]['shape']
        
        print(f"  Current input shape: {input_shape}")
        
        # Try to reshape
        if len(input_shape) == 2 and input_shape[0] == 1 and input_shape[1] == 150528:
            print("  Detected wrong shape [1, 150528], attempting to reshape...")
            try:
                interpreter.resizeInputTensor(0, [1, 224, 224, 3])
                interpreter.allocateTensors()
                new_shape = interpreter.getInputTensor(0).shape
                print(f"  Reshaped to: {new_shape}")
                
                if list(new_shape) == [1, 224, 224, 3]:
                    print("  SUCCESS: Reshape worked!")
                    print("  However, this is temporary - model needs to be re-converted")
                    print("  The model graph still has wrong shape internally")
                    return False
                else:
                    print("  FAILED: Reshape did not work")
                    return False
            except Exception as e:
                print(f"  ERROR: Cannot reshape: {e}")
                print("  Model needs to be re-converted from original Keras model")
                return False
        else:
            print("  Model shape is already correct or unexpected")
            return False
            
    except Exception as e:
        print(f"ERROR: Failed to fix model: {e}")
        return False

def main():
    model_path = "assets/best_model.tflite"
    
    if not Path(model_path).exists():
        print(f"ERROR: Model not found at {model_path}")
        print("Please ensure the model file exists in the assets folder")
        sys.exit(1)
    
    # Analyze the model
    analysis = analyze_model(model_path)
    
    if analysis is None:
        print("Failed to analyze model")
        sys.exit(1)
    
    print()
    print("=" * 70)
    print("ANALYSIS SUMMARY")
    print("=" * 70)
    print(f"Can load model: {analysis.get('can_load', False)}")
    if 'input_shape' in analysis:
        print(f"Input shape: {analysis['input_shape']}")
    if 'output_shape' in analysis:
        print(f"Output shape: {analysis['output_shape']}")
    print(f"Can run inference: {analysis.get('can_infer', False)}")
    print(f"Needs fix: {analysis.get('needs_fix', False)}")
    if analysis.get('error'):
        print(f"Error: {analysis['error']}")
    print()
    
    # Try to fix if needed
    if analysis.get('needs_fix', False):
        print("Model needs fixing. Attempting fix...")
        fixed = try_fix_model(model_path, "assets/best_model_fixed.tflite")
        
        if not fixed:
            print()
            print("=" * 70)
            print("SOLUTION REQUIRED")
            print("=" * 70)
            print("The model cannot be fixed at runtime.")
            print("You need to re-convert the original Keras model (.h5 file).")
            print()
            print("Steps:")
            print("1. Get the original Keras model file (.h5)")
            print("2. Run: python fix_model_input_shape.py path/to/original_model.h5")
            print("3. Copy best_model_fixed.tflite to assets/best_model.tflite")
            print("4. Run: flutter clean && flutter pub get")
            print("5. Rebuild the app")
            print()
    else:
        print("Model appears to be correct!")
        print("If Flutter still has issues, check:")
        print("1. Model file is not compressed in APK (check build.gradle)")
        print("2. tflite_flutter version is compatible")
        print("3. Device has enough memory")

if __name__ == "__main__":
    main()
