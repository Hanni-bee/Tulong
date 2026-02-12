# Scripts

## Converting best_model.h5 to TFLite

The app uses **TensorFlow Lite** for on-device disaster classification. The model in `assets/best_model.tflite` must match the preprocessing (180×180 RGB, normalized [0,1]).

To regenerate the TFLite file from your Keras `best_model.h5`:

1. Install TensorFlow: `pip install tensorflow`
2. From the **project root** (Tulong):  
   `python scripts/convert_h5_to_tflite.py`
3. Output is written to `assets/best_model.tflite` (overwrites existing).
4. Rebuild the Flutter app so the new asset is bundled.

The script builds a 4D model (input shape `[1, 180, 180, 3]`) and loads weights from your H5 so TFLite gets the correct input dimensions and inference runs without "input->dims->size != 4" errors.
