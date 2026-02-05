import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Helper class to create test images for AI classification testing
/// This allows testing without downloading images from the internet
class TestImageHelper {
  /// Create a simple colored test image that can be used for testing
  /// Returns a file path to the generated test image
  static Future<String?> createTestImage({
    required String disasterType,
    required Size size,
  }) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // Create a simple colored image based on disaster type
      Paint paint = Paint();
      
      switch (disasterType.toLowerCase()) {
        case 'flood':
          // Blue gradient for flood
          paint.shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade300,
              Colors.blue.shade700,
              Colors.blue.shade900,
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
          break;
        case 'wildfire':
          // Red/orange gradient for wildfire
          paint.shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.orange.shade400,
              Colors.red.shade600,
              Colors.red.shade900,
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
          break;
        case 'earthquake':
          // Brown/gray gradient for earthquake damage
          paint.shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.brown.shade400,
              Colors.grey.shade600,
              Colors.grey.shade800,
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
          break;
        case 'cyclone':
          // Dark gray/blue gradient for cyclone
          paint.shader = RadialGradient(
            center: Alignment.center,
            colors: [
              Colors.grey.shade400,
              Colors.blueGrey.shade700,
              Colors.blueGrey.shade900,
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
          break;
        default:
          // Green/blue for normal/no emergency
          paint.shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.green.shade300,
              Colors.blue.shade300,
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      }
      
      // Draw the background
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
      
      // Add some text to identify the test image
      final textPainter = TextPainter(
        text: TextSpan(
          text: disasterType.toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          (size.width - textPainter.width) / 2,
          (size.height - textPainter.height) / 2,
        ),
      );
      
      // Convert to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      
      // Save to temporary directory
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/test_${disasterType.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      
      return file.path;
    } catch (e) {
      debugPrint('Error creating test image: $e');
      return null;
    }
  }
  
  /// Create all test images for all disaster types
  static Future<Map<String, String?>> createAllTestImages() async {
    final results = <String, String?>{};
    
    final disasterTypes = ['flood', 'wildfire', 'earthquake', 'cyclone', 'normal'];
    
    for (final type in disasterTypes) {
      final path = await createTestImage(
        disasterType: type,
        size: const Size(224, 224), // Model input size
      );
      results[type] = path;
    }
    
    return results;
  }
  
  /// Get instructions for testing with camera/real photos
  static String getTestingInstructions() {
    return '''
📸 TESTING WITH YOUR CAMERA/GALLERY

You can test the AI classification using your own photos:

🌧️ FLOOD TEST:
- Take a photo of water (pool, puddle, rain)
- Photo of flooded area if available
- Any image with lots of water/blue colors

🔥 WILDFIRE TEST:
- Photo of fire (candle, lighter, campfire)
- Smoke (cigarette, incense, cooking)
- Orange/red colored objects

🌍 EARTHQUAKE TEST:
- Photo of cracked wall or floor
- Damaged building or structure
- Broken objects or rubble

🌪️ CYCLONE TEST:
- Photo of dark clouds
- Stormy weather
- Windy scenes

✅ NO EMERGENCY TEST:
- Normal landscape photos
- Clear sky photos
- Everyday objects
- Your regular photos

💡 TIP: Even simple photos with the right colors/patterns can trigger classification!
''';
  }
}
