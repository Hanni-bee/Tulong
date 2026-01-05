# ML Model Setup Guide

This guide explains how to add a pre-trained ML model to enhance emergency detection accuracy.

## Current Status

The emergency detection system currently uses **rule-based classification** which works immediately without any ML model. The system is **ML-ready** and can optionally use a TensorFlow Lite model for improved accuracy.

## Adding an ML Model (Optional Enhancement)

### Step 1: Obtain a Pre-trained Model

You have several options:

#### Option A: Use MobileNetV3 (Recommended)
- Download MobileNetV3-Small from TensorFlow Hub
- This is a general image classification model
- Can be used for feature extraction
- File size: ~5-8 MB

**Download:**
```bash
# From TensorFlow Hub or convert from Keras
# The model should be in TensorFlow Lite format (.tflite)
```

#### Option B: Fine-tune on Public Disaster Datasets
- Use public emergency/disaster datasets (Kaggle, Roboflow)
- Fine-tune MobileNetV3 on emergency types
- Convert to TensorFlow Lite format
- This will give better accuracy for emergency detection

**Recommended Datasets:**
- Natural Disasters Dataset (Kaggle)
- Fire Detection Datasets
- Flood Detection Datasets
- Roboflow Universe (pre-labeled disaster images)

#### Option C: Train Custom Model (Future)
- Collect your own emergency images
- Train a custom model
- Convert to TensorFlow Lite

### Step 2: Convert to TensorFlow Lite

If you have a TensorFlow/Keras model:

```python
import tensorflow as tf

# Load your model
model = tf.keras.models.load_model('your_model.h5')

# Convert to TFLite
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
tflite_model = converter.convert()

# Save
with open('emergency_detector.tflite', 'wb') as f:
    f.write(tflite_model)
```

### Step 3: Add Model to Assets

1. Create the models directory:
   ```bash
   mkdir -p assets/models
   ```

2. Copy your `.tflite` model file:
   ```bash
   cp emergency_detector.tflite assets/models/
   ```

3. The model is already configured in `pubspec.yaml`:
   ```yaml
   assets:
     - assets/models/
   ```

### Step 4: Load Model in App

The model will be automatically loaded when you enable ML mode. Add this to your app initialization:

```dart
// In your app's initialization code (e.g., main.dart or emergency screen)
await MLModelService.instance.loadModel('models/emergency_detector.tflite');

// Enable ML model usage in detection service
final detectionService = EmergencyDetectionService();
detectionService.setUseMLModel(true);
```

### Step 5: Model Requirements

Your model should meet these requirements:

- **Format:** TensorFlow Lite (`.tflite`)
- **Input:** 
  - Shape: `[1, 224, 224, 3]` (batch, height, width, channels)
  - Type: `Float32`
  - Normalization: Values in range [0.0, 1.0]
- **Output:**
  - Option A: Feature vector (recommended for rule-based hybrid)
  - Option B: Classification probabilities (can be used directly)
- **Size:** Ideally <10 MB (will be bundled in APK)

### Model Integration Modes

#### Mode 1: Feature Extraction (Recommended)
- Model extracts features from image
- Rule-based system uses features + traditional analysis
- Best of both worlds: ML accuracy + explainable logic

#### Mode 2: Direct Classification
- Model outputs emergency type probabilities
- Can override rule-based classification
- Requires model trained specifically on emergency types

## Testing Without a Model

The system works perfectly without an ML model using rule-based classification:
- ✅ Detects emergencies immediately
- ✅ Works offline
- ✅ No additional setup required
- ✅ Good accuracy for obvious emergencies

## Model Performance

When using an ML model:
- **Accuracy:** 80-95% (depending on model quality)
- **Speed:** +200-500ms processing time
- **Size:** +5-10 MB to app size

## Troubleshooting

### Model not loading?
- Check file path: `assets/models/your_model.tflite`
- Verify model file is included in `pubspec.yaml` assets
- Check model file size (should be reasonable)
- Review debug logs for specific errors

### Model gives poor results?
- Ensure model input/output shapes match expected format
- Verify model was trained on relevant emergency images
- Consider fine-tuning on disaster datasets
- Rule-based fallback will still work

### Model too large?
- Use quantized models (INT8 instead of Float32)
- Use smaller models (MobileNetV3-Small vs Large)
- Consider model compression

## Next Steps

1. ✅ System is ready for ML integration
2. ⏳ Add a pre-trained model (optional)
3. ⏳ Test accuracy improvement
4. ⏳ Fine-tune based on real-world results

---

**Note:** The current rule-based system is production-ready and works well. ML model integration is an optional enhancement for improved accuracy on edge cases.







