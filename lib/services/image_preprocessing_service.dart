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
  /// Handles both RGB and RGBA images
  Float32List _normalizePixels(img.Image image) {
    final int width = image.width;
    final int height = image.height;
    final int channels = 3; // RGB output
    
    final Float32List normalized = Float32List(width * height * channels);
    int index = 0;
    
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final img.Pixel pixel = image.getPixel(x, y);
        
        // Extract RGB values and normalize (ignore alpha if present)
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

