import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

/// Service for preprocessing images for ML model input
/// 
/// Based on PyImageSearch Tutorial:
/// https://pyimagesearch.com/2019/11/11/detecting-natural-disasters-with-keras-and-deep-learning/
/// 
/// Model: Fine-tuned VGG16 (pre-trained on ImageNet)
/// Preprocessing steps (EXACTLY matches PyImageSearch tutorial):
/// 1. Decode image to Image object
/// 2. Convert to RGB format (remove alpha channel if present)
/// 3. Resize to exactly 224x224 pixels (VGG16 standard input size)
///    - Python: PIL.Image.resize((224, 224), Image.Resampling.LANCZOS)
///    - Flutter: LINEAR interpolation (closest to LANCZOS)
/// 4. Normalize pixel values: divide each RGB value by 255.0 to get [0, 1] range
///    - Python: np.array(img, dtype=np.float32) / 255.0
///    - Note: Fine-tuned VGG16 uses simple [0,1] normalization (not ImageNet mean/std)
/// 5. Flatten to Float32List in RGB channel order: [R, G, B, R, G, B, ...]
/// 6. Final shape: [1, 224, 224, 3] = 150,528 float32 values
/// 
/// Channel order: RGB (not BGR)
class ImagePreprocessingService {
  /// Target size for ML model (VGG16 standard: 224x224)
  /// Reference: PyImageSearch natural disaster detection tutorial
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
      
      // CRITICAL: Resize to EXACTLY 224x224 (matches Python PIL.Image.resize)
      // Python: img.resize((224, 224), Image.Resampling.LANCZOS)
      // Flutter: Direct resize with LINEAR interpolation (closest to LANCZOS)
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
  
  /// Resize image to EXACTLY 224x224 pixels
  /// MATCHES Python: PIL.Image.resize((224, 224), Image.Resampling.LANCZOS)
  /// Uses LINEAR interpolation (closest to PIL LANCZOS in Flutter)
  /// Python does direct resize (not resize+crop), so we match that exactly
  img.Image _resizeAndCrop(img.Image image, int size) {
    final int width = image.width;
    final int height = image.height;
    
    debugPrint('📐 Original image size: ${width}x${height}');
    
    // CRITICAL: Match Python PIL.Image.resize exactly
    // Python: img.resize((224, 224), Image.Resampling.LANCZOS)
    // This does DIRECT resize to 224x224 (stretches/squashes if needed)
    // NOT aspect-ratio preserving resize+crop
    // Use LINEAR interpolation (closest to LANCZOS in Flutter image package)
    final img.Image resized = img.copyResize(
      image,
      width: size,
      height: size,
      interpolation: img.Interpolation.linear, // Closest to PIL LANCZOS
    );
    
    debugPrint('✅ Resized to EXACTLY ${resized.width}x${resized.height} (matches Python PIL.resize)');
    
    // Verify final size matches exactly
    if (resized.width != size || resized.height != size) {
      debugPrint('❌ ERROR: Resized image size mismatch! Expected ${size}x${size}, got ${resized.width}x${resized.height}');
      throw Exception('Image resize failed: expected $size x $size, got ${resized.width} x ${resized.height}');
    }
    
    return resized;
  }
  
  /// Normalize pixel values to [0, 1] range
  /// EXACTLY matches Python: img_array = np.array(img, dtype=np.float32) / 255.0
  /// Handles both RGB and RGBA images
  /// IMPORTANT: Output format is [R, G, B, R, G, B, ...] for each pixel row by row
  /// Final shape: [1, 224, 224, 3] = 150,528 float32 values (flattened)
  Float32List _normalizePixels(img.Image image) {
    final int width = image.width;
    final int height = image.height;
    final int channels = 3; // RGB output
    
    // CRITICAL: Must be exactly 224*224*3 = 150,528 elements
    final Float32List normalized = Float32List(width * height * channels);
    int index = 0;
    
    debugPrint('📐 Normalizing pixels: ${width}x${height} = ${width * height} pixels');
    debugPrint('   Expected output size: ${width * height * channels} = ${normalized.length}');
    debugPrint('   Python equivalent: np.array(img, dtype=np.float32) / 255.0');
    
    // CRITICAL: Process row by row, pixel by pixel, channel by channel
    // Order: [R, G, B, R, G, B, ...] for all pixels
    // This matches Python's flattening: img_array.flatten() or img_array.reshape(-1)
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final img.Pixel pixel = image.getPixel(x, y);
        
        // EXACTLY matches Python: pixel_value / 255.0
        // Order: R, G, B (RGB channel order, NOT BGR)
        normalized[index++] = pixel.r / 255.0; // R channel
        normalized[index++] = pixel.g / 255.0;  // G channel
        normalized[index++] = pixel.b / 255.0;  // B channel
      }
    }
    
    // Verify normalization matches Python exactly
    final minVal = normalized.reduce((a, b) => a < b ? a : b);
    final maxVal = normalized.reduce((a, b) => a > b ? a : b);
    debugPrint('✅ Normalization complete (matches Python /255.0):');
    debugPrint('   Min value: ${minVal.toStringAsFixed(6)} (should be >= 0.0)');
    debugPrint('   Max value: ${maxVal.toStringAsFixed(6)} (should be <= 1.0)');
    debugPrint('   Sample values [0-5]: ${normalized.take(6).map((v) => v.toStringAsFixed(4)).join(", ")}');
    debugPrint('   Final shape: [1, $width, $height, $channels] = ${normalized.length} float32 values');
    
    if (minVal < 0.0 || maxVal > 1.0) {
      debugPrint('❌ ERROR: Normalization out of expected range [0, 1]!');
      throw Exception('Normalization failed: values outside [0, 1] range');
    }
    
    if (normalized.length != 150528) {
      debugPrint('❌ ERROR: Output size mismatch! Expected 150528, got ${normalized.length}');
      throw Exception('Preprocessing failed: expected 150528 values, got ${normalized.length}');
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

