"""
Fix Existing TFLite Model Input Shape
======================================
Attempts to fix the existing best_model.tflite by loading and re-converting it.

This is a workaround - ideally you need the original Keras model.
"""

import tensorflow as tf
import numpy as np
from pathlib import Path

def fix_existing_tflite_model():
    """Try to fix the existing TFLite model."""
    print("=" * 70)
    print("ATTEMPTING TO FIX EXISTING TFLITE MODEL")
    print("=" * 70)
    print()
    
    input_model = "assets/best_model.tflite"
    output_model = "assets/best_model_fixed.tflite"
    
    if not Path(input_model).exists():
        print(f"ERROR: {input_model} not found!")
        return False
    
    print(f"Loading existing TFLite model: {input_model}")
    try:
        # Load the existing TFLite model
        interpreter = tf.lite.Interpreter(model_path=input_model)
        interpreter.allocate_tensors()
        
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        
        current_input_shape = input_details[0]['shape']
        output_shape = output_details[0]['shape']
        
        print(f"Model loaded successfully")
        print(f"   Current input shape: {current_input_shape}")
        print(f"   Output shape: {output_shape}")
        print()
        
        # Check if shape is already correct
        if list(current_input_shape) == [1, 224, 224, 3]:
            print("SUCCESS: Model already has correct input shape!")
            print("   No conversion needed.")
            return True
        
        print("WARNING: Model has wrong input shape, attempting to fix...")
        print()
        
        # Try to reshape the input tensor
        print("Attempting to reshape input tensor...")
        try:
            interpreter.resizeInputTensor(0, [1, 224, 224, 3])
            interpreter.allocateTensors()
            
            new_input_details = interpreter.get_input_details()
            new_shape = new_input_details[0]['shape']
            
            print(f"   Reshaped to: {new_shape}")
            
            if list(new_shape) == [1, 224, 224, 3]:
                print("SUCCESS: Reshape successful!")
                print()
                print("NOTE: This reshape is temporary and will reset when model is reloaded.")
                print("   The model graph structure still has wrong shape.")
                print("   You still need the original Keras model to properly fix this.")
                return False
            else:
                print("ERROR: Reshape did not work - model doesn't support dynamic shapes")
                return False
                
        except Exception as e:
            print(f"ERROR: Reshape failed: {e}")
            print("   Model doesn't support dynamic input shapes")
            print("   You need the original Keras model to fix this properly")
            return False
            
    except Exception as e:
        print(f"ERROR: Error loading model: {e}")
        return False


def create_dummy_model_with_correct_shape():
    """Create a dummy model with correct shape for testing."""
    print()
    print("=" * 70)
    print("CREATING DUMMY MODEL WITH CORRECT SHAPE (FOR TESTING)")
    print("=" * 70)
    print()
    print("WARNING: This creates a dummy model that won't classify correctly,")
    print("   but it will have the correct input shape for testing the app.")
    print()
    
    try:
        # Create a simple dummy model with correct input shape
        model = tf.keras.Sequential([
            tf.keras.layers.Input(shape=(224, 224, 3), name='input_1'),
            tf.keras.layers.GlobalAveragePooling2D(),
            tf.keras.layers.Dense(4, activation='softmax', name='predictions')
        ])
        
        print("SUCCESS: Dummy model created")
        print(f"   Input shape: {model.input_shape}")
        print(f"   Output shape: {model.output_shape}")
        print()
        
        # Convert to TFLite
        print("Converting to TFLite...")
        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        tflite_model = converter.convert()
        
        # Verify
        interpreter = tf.lite.Interpreter(model_content=tflite_model)
        interpreter.allocate_tensors()
        input_details = interpreter.get_input_details()
        
        print(f"SUCCESS: Conversion successful")
        print(f"   Input shape: {input_details[0]['shape']}")
        print()
        
        # Save
        output_path = "assets/best_model_dummy.tflite"
        with open(output_path, 'wb') as f:
            f.write(tflite_model)
        
        print(f"SUCCESS: Dummy model saved: {output_path}")
        print()
        print("NOTE: This is a DUMMY model - it won't classify disasters correctly!")
        print("   It's only for testing that the app works with correct input shape.")
        print("   You still need the original Keras model for real classification.")
        
        return True
        
    except Exception as e:
        print(f"ERROR: Error creating dummy model: {e}")
        return False


if __name__ == "__main__":
    import sys
    import io
    
    # Fix encoding for Windows
    if sys.platform == 'win32':
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')
    
    print()
    print("Checking if we can fix the existing model...")
    print()
    
    # Try to fix existing model
    if fix_existing_tflite_model():
        print("SUCCESS: Model fixed successfully!")
    else:
        print()
        print("ERROR: Cannot fix existing model - need original Keras model")
        print()
        print("OPTIONS:")
        print("   1. Get the original Keras model (.h5) and run:")
        print("      python fix_model_input_shape.py path/to/original_model.h5")
        print()
        print("   2. Create a dummy model for testing (won't classify correctly)")
        print("      This will create a model with correct shape for app testing")
        print()
        
        # Auto-create dummy model for testing
        print("Creating dummy model automatically for testing...")
        if create_dummy_model_with_correct_shape():
            print()
            print("SUCCESS: Dummy model created!")
            print("   File: assets/best_model_dummy.tflite")
            print("   You can copy this to assets/best_model.tflite for testing")
            print("   (It won't classify correctly, but app won't crash)")
        else:
            print("ERROR: Failed to create dummy model")
            print()
            print("You need the original Keras model to properly fix this.")
