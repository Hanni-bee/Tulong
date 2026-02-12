#!/usr/bin/env python3
"""
Convert Keras best_model.h5 to TensorFlow Lite for Flutter (TULONG disaster detection).
Your model is 4D (batch, 180, 180, 3) with Conv2D layers and 4-class softmax.

Usage (from project root):
  pip install tensorflow
  python scripts/convert_h5_to_tflite.py

Output: assets/best_model.tflite (overwrites existing).
Flutter must use 180x180 preprocessing to match (see AIDetectionConfig).
"""

import os
import sys

# Project root = parent of scripts/
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
H5_PATH = os.path.join(PROJECT_ROOT, "best_model.h5")
OUTPUT_PATH = os.path.join(PROJECT_ROOT, "assets", "best_model.tflite")

# From your H5 config: input (180, 180, 3), 4 classes
INPUT_H, INPUT_W = 180, 180
INPUT_C = 3


def main():
    if not os.path.isfile(H5_PATH):
        print(f"ERROR: Model file not found: {H5_PATH}")
        sys.exit(1)

    try:
        import tensorflow as tf
    except ImportError:
        print("ERROR: Install TensorFlow: pip install tensorflow")
        sys.exit(1)

    print("Building model with input shape ({}x{}x{})...".format(INPUT_H, INPUT_W, INPUT_C))
    # Recreate architecture from your H5 config so we get correct 4D input (avoids Keras load bugs)
    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(INPUT_H, INPUT_W, INPUT_C), batch_size=1),
        tf.keras.layers.Conv2D(32, (3, 3), activation="relu", padding="valid"),
        tf.keras.layers.MaxPooling2D((2, 2), strides=(2, 2)),
        tf.keras.layers.Conv2D(64, (3, 3), activation="relu", padding="valid"),
        tf.keras.layers.MaxPooling2D((2, 2), strides=(2, 2)),
        tf.keras.layers.Conv2D(128, (3, 3), activation="relu", padding="valid"),
        tf.keras.layers.MaxPooling2D((2, 2), strides=(2, 2)),
        tf.keras.layers.Conv2D(128, (3, 3), activation="relu", padding="valid"),
        tf.keras.layers.MaxPooling2D((2, 2), strides=(2, 2)),
        tf.keras.layers.Conv2D(128, (3, 3), activation="relu", padding="valid"),
        tf.keras.layers.MaxPooling2D((2, 2), strides=(2, 2)),
        tf.keras.layers.Flatten(),
        tf.keras.layers.Dropout(0.3),
        tf.keras.layers.Dense(512, activation="relu"),
        tf.keras.layers.Dense(4, activation="softmax"),
    ])

    print("Loading weights from:", H5_PATH)
    model.load_weights(H5_PATH)
    model.compile()  # not required for conversion but avoids warnings

    in_shape = model.input_shape
    print("  Model input_shape:", in_shape)

    print("Converting to TFLite...")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS,
        tf.lite.OpsSet.SELECT_TF_OPS,
    ]
    tflite_model = converter.convert()

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, "wb") as f:
        f.write(tflite_model)

    size_mb = len(tflite_model) / (1024 * 1024)
    print("Written:", OUTPUT_PATH)
    print("Size: {:.2f} MB".format(size_mb))
    print("Done. In Flutter set preprocessing to {}x{} (AIDetectionConfig / ImagePreprocessingService).".format(INPUT_H, INPUT_W))
    return 0


if __name__ == "__main__":
    sys.exit(main())
