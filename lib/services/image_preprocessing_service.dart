import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

/// Service for preprocessing images for ML model input
class ImagePreprocessingService {
  /// Target size for ML model (MobileNet typically uses 224x224)
  static const int targetSize = 224;
  
  /// Preprocess image for ML model
  /// Returns normalized Float32List ready for TensorFlow Lite
  /// Format: [1, 224, 224, 3] - batch dimension included
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
      
      // Ensure RGB format (convert if needed)
      img.Image rgbImage = resized;
      if (resized.numChannels == 4) {
        // Convert RGBA to RGB
        rgbImage = img.Image(width: resized.width, height: resized.height);
        for (int y = 0; y < resized.height; y++) {
          for (int x = 0; x < resized.width; x++) {
            final pixel = resized.getPixel(x, y);
            rgbImage.setPixel(x, y, img.ColorRgb8(
              pixel.r.toInt().clamp(0, 255),
              pixel.g.toInt().clamp(0, 255),
              pixel.b.toInt().clamp(0, 255),
            ));
          }
        }
      }
      
      // Normalize pixel values to [0, 1] range
      // Format: [1, 224, 224, 3] - batch dimension included
      final Float32List normalized = _normalizePixels(rgbImage);
      
      // Validate preprocessing - ensure data is varied
      final minVal = normalized.reduce((a, b) => a < b ? a : b);
      final maxVal = normalized.reduce((a, b) => a > b ? a : b);
      final meanVal = normalized.reduce((a, b) => a + b) / normalized.length;
      
      debugPrint('✅ Image preprocessed: ${resized.width}x${resized.height} -> ${targetSize}x$targetSize');
      debugPrint('   Output shape: [1, $targetSize, $targetSize, 3]');
      debugPrint('   Total values: ${normalized.length}');
      debugPrint('   Normalized range: [$minVal, $maxVal], mean: ${meanVal.toStringAsFixed(4)}');
      
      // Validation check
      if ((maxVal - minVal).abs() < 0.0001) {
        debugPrint('⚠️⚠️⚠️ WARNING: Preprocessed data is constant - all pixels are the same! ⚠️⚠️⚠️');
      }
      if (meanVal < 0.001 || meanVal > 0.999) {
        debugPrint('⚠️ Preprocessed mean value is extreme: $meanVal (expected ~0.4-0.6 for typical images)');
      }
      
      return normalized;
    } catch (e) {
      debugPrint('❌ Error preprocessing image: $e');
      return null;
    }
  }
  
  /// Resize image maintaining aspect ratio, then crop center
  img.Image _resizeAndCrop(img.Image image, int size) {
    final int width = image.width;
    final int height = image.height;
    
    // Calculate scaling factor
    final double scale = size / (width > height ? width : height);
    
    // Resize maintaining aspect ratio
    final int newWidth = (width * scale).round();
    final int newHeight = (height * scale).round();
    final img.Image resized = img.copyResize(image, width: newWidth, height: newHeight);
    
    // Crop center to exact size
    final int x = (newWidth - size) ~/ 2;
    final int y = (newHeight - size) ~/ 2;
    
    return img.copyCrop(resized, x: x, y: y, width: size, height: size);
  }
  
  /// Normalize pixel values to [0, 1] range
  /// ImageNet normalization: (pixel / 255.0)
  /// Returns format: [1, height, width, 3] - batch dimension included
  Float32List _normalizePixels(img.Image image) {
    final int width = image.width;
    final int height = image.height;
    final int channels = 3; // RGB output
    final int batchSize = 1; // Single image
    
    // Total size: batch * height * width * channels = 1 * 224 * 224 * 3
    final Float32List normalized = Float32List(batchSize * height * width * channels);
    int index = 0;
    
    // Flatten to [batch, height, width, channels] format
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final img.Pixel pixel = image.getPixel(x, y);
        
        // Extract RGB values and normalize to [0, 1]
        // Format: [batch=1, height, width, channels=3]
        normalized[index++] = pixel.r / 255.0; // R
        normalized[index++] = pixel.g / 255.0;  // G
        normalized[index++] = pixel.b / 255.0;  // B
      }
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

