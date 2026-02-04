import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

/// Service for preprocessing images for ML model input
///
/// Preprocessing steps (must match Python exactly):
/// 1. Decode image to Image object
/// 2. Convert to RGB format (remove alpha channel if present)
/// 3. Resize to exactly 224x224 pixels (use linear interpolation)
/// 4. Normalize pixel values: divide each RGB value by 255.0 to get [0, 1] range
/// 5. Flatten to Float32List in RGB channel order: [R, G, B, R, G, B, ...]
/// 6. Final shape: [1, 224, 224, 3] = 150,528 float32 values
///
/// Channel order: RGB (not BGR)
class ImagePreprocessingService {
  /// Target size for ML model (VGG16 uses 224x224)
  static const int targetSize = 224;

  /// Preprocess image for ML model
  /// Returns normalized Float32List ready for TensorFlow Lite
  Future<Float32List?> preprocessImage(String imagePath) async {
    try {
      // Read image file
      final File imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        debugPrint('Image file does not exist: $imagePath');
        return null;
      }

      final Uint8List imageBytes = await imageFile.readAsBytes();

      // Decode image
      final img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        debugPrint('Failed to decode image');
        return null;
      }

      // Resize to target size (maintain aspect ratio, then crop center)
      final img.Image resized = _resizeAndCrop(image, targetSize);

      // Normalize pixel values to [0, 1] range
      // Camera images are typically RGB, but we handle RGBA if present
      final Float32List normalized = _normalizePixels(resized);

      debugPrint('Image preprocessed: ${resized.width}x${resized.height} -> ${targetSize}x$targetSize');
      return normalized;
    } catch (e) {
      debugPrint('Error preprocessing image: $e');
      return null;
    }
  }

  /// Resize image maintaining aspect ratio, then crop center to 224x224
  /// This ensures the model receives exactly 224x224 pixels as required
  img.Image _resizeAndCrop(img.Image image, int size) {
    final int width = image.width;
    final int height = image.height;

    debugPrint('Original image size: ${width}x${height}');

    // Calculate scaling factor to ensure the longer side becomes 'size'
    final double scale = size / (width > height ? width : height);

    // Resize maintaining aspect ratio
    final int newWidth = (width * scale).round();
    final int newHeight = (height * scale).round();
    final img.Image resized = img.copyResize(image, width: newWidth, height: newHeight);

    debugPrint('Resized image size: ${resized.width}x${resized.height}');

    // Crop center to exact size (224x224)
    final int x = (newWidth - size) ~/ 2;
    final int y = (newHeight - size) ~/ 2;

    final img.Image cropped = img.copyCrop(resized, x: x, y: y, width: size, height: size);

    debugPrint('Final cropped size: ${cropped.width}x${cropped.height} (should be ${size}x$size)');

    // Verify final size matches exactly
    if (cropped.width != size || cropped.height != size) {
      debugPrint('⚠️ Warning: Cropped image size mismatch! Expected ${size}x$size, got ${cropped.width}x${cropped.height}');
    }

    return cropped;
  }

  /// Normalize pixel values to [0, 1] range
  /// ImageNet normalization: (pixel / 255.0)
  /// Handles both RGB and RGBA images
  /// IMPORTANT: Output format is [R, G, B, R, G, B, ...] for each pixel row by row
  Float32List _normalizePixels(img.Image image) {
    final int width = image.width;
    final int height = image.height;
    final int channels = 3; // RGB output

    final Float32List normalized = Float32List(width * height * channels);
    int index = 0;

    debugPrint('📐 Normalizing pixels: ${width}x$height = ${width * height} pixels');
    debugPrint('   Expected output size: ${width * height * channels} = ${normalized.length}');

    // Verify we're processing in the correct order (row by row, then RGB channels)
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final img.Pixel pixel = image.getPixel(x, y);

        // Extract RGB values and normalize (ignore alpha if present)
        // Order: R, G, B (standard RGB channel order)
        normalized[index++] = pixel.r / 255.0; // R
        normalized[index++] = pixel.g / 255.0;  // G
        normalized[index++] = pixel.b / 255.0;  // B
      }
    }

    // Verify normalization
    final minVal = normalized.reduce((a, b) => a < b ? a : b);
    final maxVal = normalized.reduce((a, b) => a > b ? a : b);
    debugPrint('✅ Normalization complete:');
    debugPrint('   Min value: ${minVal.toStringAsFixed(6)} (should be >= 0.0)');
    debugPrint('   Max value: ${maxVal.toStringAsFixed(6)} (should be <= 1.0)');
    debugPrint('   Sample values [0-5]: ${normalized.take(6).map((v) => v.toStringAsFixed(4)).join(", ")}');

    if (minVal < 0.0 || maxVal > 1.0) {
      debugPrint('⚠️ WARNING: Normalization out of expected range [0, 1]!');
    }

    return normalized;
  }

  /// Get image dimensions
  Future<Map<String, int>?> getImageDimensions(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        return null;
      }

      final Uint8List imageBytes = await imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(imageBytes);

      if (image == null) {
        return null;
      }

      return {
        'width': image.width,
        'height': image.height,
      };
    } catch (e) {
      debugPrint('Error getting image dimensions: $e');
      return null;
    }
  }
}
