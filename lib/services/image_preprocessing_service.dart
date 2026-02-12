import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

import 'ai_detection_config.dart';

/// Result of image preprocessing (success with data or failure with reason).
class PreprocessResult {
  final Float32List? data;
  final String? errorCode;

  const PreprocessResult._({this.data, this.errorCode});

  static PreprocessResult success(Float32List data) =>
      PreprocessResult._(data: data);

  static PreprocessResult failure(String errorCode) =>
      PreprocessResult._(errorCode: errorCode);

  bool get isSuccess => data != null && errorCode == null;
}

/// Service for preprocessing images for ML model input
///
/// Preprocessing steps (must match training pipeline and assets/best_model.tflite):
/// 1. Validate file exists and size
/// 2. Decode image; validate dimensions
/// 3. Resize (shorter side scale) + center crop to modelInputHeight x modelInputWidth
/// 4. Normalize to [0, 1], RGB channel order
/// 5. Flatten to Float32List: [R,G,B,...]
///
/// Channel order: RGB (not BGR)
class ImagePreprocessingService {
  /// Target size for ML model (must match AIDetectionConfig.modelInputHeight/Width)
  static int get targetSize => AIDetectionConfig.modelInputHeight;

  /// Preprocess image for ML model
  /// Returns normalized Float32List ready for TensorFlow Lite, or null on failure
  Future<Float32List?> preprocessImage(String imagePath) async {
    final result = await preprocessImageWithResult(imagePath);
    return result.data;
  }

  /// Preprocess with detailed result (for pipeline validation)
  Future<PreprocessResult> preprocessImageWithResult(String imagePath) async {
    try {
      if (imagePath.trim().isEmpty) {
        debugPrint('[Preprocess] Empty image path');
        return PreprocessResult.failure('empty_path');
      }

      final File imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        debugPrint('[Preprocess] File does not exist: $imagePath');
        return PreprocessResult.failure('file_not_found');
      }

      final int fileSize = await imageFile.length();
      if (fileSize > AIDetectionConfig.maxImageFileSizeBytes) {
        debugPrint('[Preprocess] File too large: ${fileSize ~/ 1024} KB');
        return PreprocessResult.failure('file_too_large');
      }
      if (fileSize == 0) {
        debugPrint('[Preprocess] Empty file');
        return PreprocessResult.failure('empty_file');
      }

      final Uint8List imageBytes = await imageFile.readAsBytes();
      // Decode to a non-null image; if decode fails, bail out early.
      final img.Image? decoded = img.decodeImage(imageBytes);
      if (decoded == null) {
        debugPrint('[Preprocess] Failed to decode image');
        return PreprocessResult.failure('decode_failed');
      }
      img.Image image = decoded;

      // Apply EXIF orientation so camera photos are upright (avoids sideways misclassification)
      if (AIDetectionConfig.applyExifOrientation) {
        try {
          image = img.bakeOrientation(image);
        } catch (_) {
          // EXIF may be missing or invalid; continue with original
        }
      }

      final int w = image.width;
      final int h = image.height;
      if (w < AIDetectionConfig.minImageDimension ||
          h < AIDetectionConfig.minImageDimension) {
        debugPrint('[Preprocess] Image too small: ${w}x$h');
        return PreprocessResult.failure('image_too_small');
      }

      final int size = AIDetectionConfig.modelInputHeight;
      final img.Image resized = _resizeAndCrop(image, size);
      final Float32List normalized = _normalizePixels(resized);

      if (normalized.length != AIDetectionConfig.expectedInputPixels) {
        debugPrint('[Preprocess] Output size mismatch: ${normalized.length}');
        return PreprocessResult.failure('output_size_mismatch');
      }

      // Reject very dark/flat images (optional)
      final minContrast = AIDetectionConfig.minContrastForInference;
      if (minContrast > 0) {
        final contrast = _computeContrast(normalized);
        if (contrast < minContrast) {
          debugPrint('[Preprocess] Low contrast: $contrast < $minContrast');
          return PreprocessResult.failure('low_contrast');
        }
      }

      debugPrint('[Preprocess] OK: ${w}x$h -> ${size}x$size, ${normalized.length} values');
      return PreprocessResult.success(normalized);
    } catch (e, st) {
      debugPrint('[Preprocess] Error: $e');
      if (kDebugMode) debugPrint('$st');
      return PreprocessResult.failure('exception');
    }
  }
  
  /// Resize image maintaining aspect ratio, then crop center to targetSize x targetSize
  /// Scale by SHORTER side so both dimensions >= size, then crop center
  img.Image _resizeAndCrop(img.Image image, int size) {
    final int width = image.width;
    final int height = image.height;
    
    debugPrint('Original image size: ${width}x${height}');
    
    // Scale by SHORTER side so both dimensions are >= size (enables valid center crop)
    final double scale = size / (width < height ? width : height);
    final int newWidth = (width * scale).round();
    final int newHeight = (height * scale).round();
    final img.Image resized = img.copyResize(image, width: newWidth, height: newHeight);
    
    debugPrint('Resized image size: ${resized.width}x${resized.height}');
    
    // Crop center to exact size (targetSize x targetSize)
    final int x = (newWidth - size) ~/ 2;
    final int y = (newHeight - size) ~/ 2;
    
    final img.Image cropped = img.copyCrop(resized, x: x, y: y, width: size, height: size);
    
    debugPrint('Final cropped size: ${cropped.width}x${cropped.height} (should be ${size}x${size})');
    
    // Verify final size matches exactly
    if (cropped.width != size || cropped.height != size) {
      debugPrint('⚠️ Warning: Cropped image size mismatch! Expected ${size}x${size}, got ${cropped.width}x${cropped.height}');
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
    
    debugPrint('📐 Normalizing pixels: ${width}x${height} = ${width * height} pixels');
    debugPrint('   Expected output size: ${width * height * channels} = ${normalized.length}');
    
    // Channel order and normalization (must match Python training)
    final useBGR = AIDetectionConfig.useBGR;
    final useImageNet = AIDetectionConfig.useImageNetNormalization;
    // ImageNet mean (BGR order: B=103.939, G=116.779, R=123.68) as in tf.keras.applications
    const double imB = 103.939 / 255.0, imG = 116.779 / 255.0, imR = 123.68 / 255.0;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final img.Pixel pixel = image.getPixel(x, y);
        double r = pixel.r / 255.0;
        double g = pixel.g / 255.0;
        double b = pixel.b / 255.0;
        if (useImageNet) {
          r = r - imR;
          g = g - imG;
          b = b - imB;
        }
        if (useBGR) {
          normalized[index++] = b;
          normalized[index++] = g;
          normalized[index++] = r;
        } else {
          normalized[index++] = r;
          normalized[index++] = g;
          normalized[index++] = b;
        }
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

  /// Contrast as std dev of pixel values (0 = flat, ~0.2–0.3 = typical). Used to reject very dark/flat images.
  double _computeContrast(Float32List pixels) {
    if (pixels.isEmpty) return 0.0;
    double sum = 0.0;
    for (final p in pixels) sum += p;
    final mean = sum / pixels.length;
    double sq = 0.0;
    for (final p in pixels) sq += (p - mean) * (p - mean);
    final variance = sq / pixels.length;
    return math.sqrt(variance.clamp(0.0, 1.0));
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

