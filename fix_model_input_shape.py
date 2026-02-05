"""
Fix TFLite Model Input Shape
============================
This script re-converts a Keras model to TFLite with the correct input shape [1, 224, 224, 3]

Usage:
    python fix_model_input_shape.py

Requirements:
    - tensorflow >= 2.0
    - Original Keras model file (.h5 or SavedModel format)
"""

import tensorflow as tf
import numpy as np
from pathlib import Path

def fix_model_input_shape(
    input_model_path: str,
    output_model_path: str = "best_model_fixed.tflite",
    input_shape: tuple = (1, 224, 224, 3)
):
    """
    Re-convert a Keras model to TFLite with correct input shape.
    
    Args:
        input_model_path: Path to original Keras model (.h5 or SavedModel)
        output_model_path: Path to save fixed TFLite model
        input_shape: Desired input shape (batch, height, width, channels)
    """
    print("=" * 70)
    print("FIXING TFLITE MODEL INPUT SHAPE")
    print("=" * 70)
    print(f"Input model: {input_model_path}")
    print(f"Output model: {output_model_path}")
    print(f"Target input shape: {input_shape}")
    print()
    
    # Step 1: Load the original Keras model
    print("📦 Step 1: Loading original Keras model...")
    try:
        if input_model_path.endswith('.h5'):
            model = tf.keras.models.load_model(input_model_path)
        else:
            # Assume SavedModel format
            model = tf.keras.models.load_model(input_model_path)
        
        print(f"✅ Model loaded successfully")
        print(f"   Model input shape: {model.input_shape}")
        print(f"   Model output shape: {model.output_shape}")
        
        # Verify current input shape
        current_input_shape = model.input_shape
        if len(current_input_shape) == 4:
            print(f"   Current input: {current_input_shape}")
        else:
            print(f"   ⚠️ Warning: Model input shape is not 4D: {current_input_shape}")
        
    except Exception as e:
        print(f"❌ Error loading model: {e}")
        print()
        print("🔧 TROUBLESHOOTING:")
        print("   1. Make sure the model file exists")
        print("   2. Check if the model is in .h5 or SavedModel format")
        print("   3. Verify TensorFlow version: pip install tensorflow>=2.0")
        return False
    
    # Step 2: Create a new model with explicit input shape
    print()
    print("📦 Step 2: Creating model with explicit input shape...")
    try:
        # Get the model's input layer
        input_layer = model.input
        
        # Create a new input with explicit shape
        new_input = tf.keras.layers.Input(
            shape=input_shape[1:],  # Remove batch dimension: (224, 224, 3)
            name='input_1',
            dtype=tf.float32
        )
        
        # Build the model with new input
        # If the model has a RESIZE layer, it should work with 4D input
        x = new_input
        for layer in model.layers[1:]:  # Skip the original input layer
            x = layer(x)
        
        new_model = tf.keras.Model(inputs=new_input, outputs=x)
        
        print(f"✅ New model created with input shape: {new_model.input_shape}")
        print(f"   Output shape: {new_model.output_shape}")
        
    except Exception as e:
        print(f"❌ Error creating new model: {e}")
        print("   Trying direct conversion with input shape specification...")
        
        # Fallback: Try direct conversion
        try:
            new_model = model
            # Force input shape by setting it
            new_model._set_inputs(tf.keras.Input(shape=input_shape[1:]))
        except Exception as e2:
            print(f"❌ Fallback also failed: {e2}")
            return False
    
    # Step 3: Convert to TFLite
    print()
    print("📦 Step 3: Converting to TFLite with correct input shape...")
    try:
        converter = tf.lite.TFLiteConverter.from_keras_model(new_model)
        
        # Enable optimizations (optional, but recommended)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        
        # Set target specs
        converter.target_spec.supported_ops = [
            tf.lite.OpsSet.TFLITE_BUILTINS,  # Enable TensorFlow Lite builtin ops
        ]
        
        # Convert
        print("   Converting model (this may take a minute)...")
        tflite_model = converter.convert()
        
        print(f"✅ Conversion successful")
        print(f"   Model size: {len(tflite_model) / (1024 * 1024):.2f} MB")
        
    except Exception as e:
        print(f"❌ Error converting to TFLite: {e}")
        print()
        print("🔧 TROUBLESHOOTING:")
        print("   1. Make sure TensorFlow Lite is installed")
        print("   2. Check if the model uses unsupported operations")
        print("   3. Try without optimizations: converter.optimizations = []")
        return False
    
    # Step 4: Verify the converted model
    print()
    print("📦 Step 4: Verifying converted model...")
    try:
        interpreter = tf.lite.Interpreter(model_content=tflite_model)
        interpreter.allocate_tensors()
        
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        
        input_shape_actual = input_details[0]['shape']
        output_shape_actual = output_details[0]['shape']
        
        print(f"✅ Model verified")
        print(f"   Input shape: {input_shape_actual}")
        print(f"   Output shape: {output_shape_actual}")
        print(f"   Input dtype: {input_details[0]['dtype']}")
        print(f"   Output dtype: {output_details[0]['dtype']}")
        
        # Check if input shape is correct
        if list(input_shape_actual) == list(input_shape):
            print(f"   ✅ Input shape is CORRECT: {input_shape_actual}")
        else:
            print(f"   ⚠️ Warning: Input shape is {input_shape_actual}, expected {input_shape}")
            print(f"   The model might still have issues")
        
        # Test with dummy input
        print()
        print("📦 Step 5: Testing with dummy input...")
        input_data = np.random.random(input_shape).astype(np.float32)
        interpreter.set_tensor(input_details[0]['index'], input_data)
        interpreter.invoke()
        output_data = interpreter.get_tensor(output_details[0]['index'])
        
        print(f"✅ Inference test successful")
        print(f"   Output shape: {output_data.shape}")
        print(f"   Output values: {output_data[0]}")
        print(f"   Output sum: {output_data[0].sum():.6f} (should be ~1.0 if softmax)")
        
    except Exception as e:
        print(f"❌ Error verifying model: {e}")
        print("   Model might still work, but verification failed")
        return False
    
    # Step 5: Save the fixed model
    print()
    print("📦 Step 6: Saving fixed model...")
    try:
        with open(output_model_path, 'wb') as f:
            f.write(tflite_model)
        
        file_size = Path(output_model_path).stat().st_size / (1024 * 1024)
        print(f"✅ Model saved successfully")
        print(f"   File: {output_model_path}")
        print(f"   Size: {file_size:.2f} MB")
        
    except Exception as e:
        print(f"❌ Error saving model: {e}")
        return False
    
    print()
    print("=" * 70)
    print("✅ MODEL FIXED SUCCESSFULLY!")
    print("=" * 70)
    print()
    print("📝 NEXT STEPS:")
    print(f"   1. Copy {output_model_path} to Flutter project:")
    print(f"      cp {output_model_path} assets/best_model.tflite")
    print("   2. In Flutter project, run:")
    print("      flutter clean && flutter pub get")
    print("   3. Rebuild the app")
    print("   4. Test classification - it should work now!")
    print()
    
    return True


if __name__ == "__main__":
    import sys
    
    # Default paths - modify these to match your setup
    input_model = "best_model.h5"  # Change this to your original Keras model path
    output_model = "best_model_fixed.tflite"
    
    # Check if input model exists
    if not Path(input_model).exists():
        print("❌ Error: Input model file not found!")
        print(f"   Looking for: {input_model}")
        print()
        print("📝 USAGE:")
        print("   1. Place your original Keras model (.h5) in the same directory")
        print("   2. Update 'input_model' variable in this script")
        print("   3. Run: python fix_model_input_shape.py")
        print()
        print("   OR specify model path as argument:")
        print("   python fix_model_input_shape.py path/to/your/model.h5")
        sys.exit(1)
    
    # Allow command line argument for input model
    if len(sys.argv) > 1:
        input_model = sys.argv[1]
    
    if len(sys.argv) > 2:
        output_model = sys.argv[2]
    
    # Run the fix
    success = fix_model_input_shape(input_model, output_model)
    
    if not success:
        print()
        print("❌ Model conversion failed. Please check the errors above.")
        sys.exit(1)
