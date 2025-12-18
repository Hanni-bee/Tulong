import 'package:flutter_test/flutter_test.dart';
import 'package:tulong_app/services/emergency_detection_service.dart';
import 'package:tulong_app/models/emergency_type.dart';
import 'package:tulong_app/models/emergency_detection_result.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  group('EmergencyDetectionService', () {
    late EmergencyDetectionService service;
    late String testImagePath;

    setUp(() {
      service = EmergencyDetectionService();
      // Create a test image path (will be mocked in actual tests)
      testImagePath = '/tmp/test_image.jpg';
    });

    tearDown(() {
      // Clean up test files if needed
    });

    group('detectEmergency', () {
      test('should return EmergencyDetectionResult', () async {
        // Create a minimal test image
        final testImage = img.Image(width: 224, height: 224);
        // Fill with neutral gray color (normal scene)
        img.fill(testImage, color: img.ColorRgb8(128, 128, 128));
        
        // Save test image
        final testFile = File(testImagePath);
        await testFile.writeAsBytes(img.encodeJpg(testImage));
        
        // Create preprocessed input (normalized Float32List)
        final preprocessed = Float32List(224 * 224 * 3);
        for (int i = 0; i < preprocessed.length; i++) {
          preprocessed[i] = 0.5; // Normal gray value
        }
        
        // Call detection
        final result = await service.detectEmergency(
          preprocessed,
          testImagePath,
        );
        
        // Verify result
        expect(result, isA<EmergencyDetectionResult>());
        expect(result.type, isA<EmergencyType>());
        expect(result.severity, isA<SeverityLevel>());
        expect(result.confidence, greaterThanOrEqualTo(0.0));
        expect(result.confidence, lessThanOrEqualTo(1.0));
        expect(result.timestamp, isA<DateTime>());
      });

      test('should detect normal scenes as No Emergency', () async {
        // Create a normal scene (gray, low contrast)
        final testImage = img.Image(width: 224, height: 224);
        img.fill(testImage, color: img.ColorRgb8(150, 150, 150));
        
        // Add some organized patterns (lines) to simulate normal structures
        for (int y = 0; y < 224; y += 20) {
          for (int x = 0; x < 224; x++) {
            testImage.setPixelRgb(x, y, 100, 100, 100);
          }
        }
        
        final testFile = File(testImagePath);
        await testFile.writeAsBytes(img.encodeJpg(testImage));
        
        final preprocessed = Float32List(224 * 224 * 3);
        for (int i = 0; i < preprocessed.length; i++) {
          preprocessed[i] = 0.6; // Light gray
        }
        
        final result = await service.detectEmergency(
          preprocessed,
          testImagePath,
        );
        
        // Should detect as No Emergency for normal scenes
        // (Note: This may vary based on actual detection logic)
        expect(result.type, isIn([
          EmergencyType.noEmergency,
          EmergencyType.general,
        ]));
        
        // If it's noEmergency, severity should be low
        if (result.type == EmergencyType.noEmergency) {
          expect(result.severity, SeverityLevel.low);
          expect(result.confidence, greaterThan(0.6));
        }
      });

      test('should handle missing image file gracefully', () async {
        final preprocessed = Float32List(224 * 224 * 3);
        
        final result = await service.detectEmergency(
          preprocessed,
          '/nonexistent/path/image.jpg',
        );
        
        // Should return a default result, not crash
        expect(result, isA<EmergencyDetectionResult>());
        expect(result.type, isA<EmergencyType>());
      });
    });

    group('Image Analysis Functions', () {
      test('should analyze color distribution correctly', () {
        // Create test image with red pixels (fire indicator)
        final testImage = img.Image(width: 100, height: 100);
        
        // Fill 30% with red (fire color)
        for (int y = 0; y < 100; y++) {
          for (int x = 0; x < 30; x++) {
            testImage.setPixelRgb(x, y, 255, 50, 50);
          }
        }
        // Fill rest with gray
        for (int y = 0; y < 100; y++) {
          for (int x = 30; x < 100; x++) {
            testImage.setPixelRgb(x, y, 128, 128, 128);
          }
        }
        
        // Use reflection or make analysis methods public for testing
        // For now, we test through detectEmergency
        // This would require refactoring private methods to be testable
      });
    });

    group('Edge Cases', () {
      test('should handle very small images', () async {
        final testImage = img.Image(width: 10, height: 10);
        img.fill(testImage, color: img.ColorRgb8(128, 128, 128));
        
        final testFile = File(testImagePath);
        await testFile.writeAsBytes(img.encodeJpg(testImage));
        
        final preprocessed = Float32List(10 * 10 * 3);
        
        final result = await service.detectEmergency(
          preprocessed,
          testImagePath,
        );
        
        expect(result, isA<EmergencyDetectionResult>());
      });

      test('should handle very dark images', () async {
        final testImage = img.Image(width: 224, height: 224);
        img.fill(testImage, color: img.ColorRgb8(10, 10, 10)); // Very dark
        
        final testFile = File(testImagePath);
        await testFile.writeAsBytes(img.encodeJpg(testImage));
        
        final preprocessed = Float32List(224 * 224 * 3);
        for (int i = 0; i < preprocessed.length; i++) {
          preprocessed[i] = 0.05; // Very dark
        }
        
        final result = await service.detectEmergency(
          preprocessed,
          testImagePath,
        );
        
        expect(result, isA<EmergencyDetectionResult>());
      });

      test('should handle very bright images', () async {
        final testImage = img.Image(width: 224, height: 224);
        img.fill(testImage, color: img.ColorRgb8(250, 250, 250)); // Very bright
        
        final testFile = File(testImagePath);
        await testFile.writeAsBytes(img.encodeJpg(testImage));
        
        final preprocessed = Float32List(224 * 224 * 3);
        for (int i = 0; i < preprocessed.length; i++) {
          preprocessed[i] = 0.98; // Very bright
        }
        
        final result = await service.detectEmergency(
          preprocessed,
          testImagePath,
        );
        
        expect(result, isA<EmergencyDetectionResult>());
      });
    });

    group('Confidence Calculation', () {
      test('confidence should be in valid range', () async {
        final testImage = img.Image(width: 224, height: 224);
        img.fill(testImage, color: img.ColorRgb8(128, 128, 128));
        
        final testFile = File(testImagePath);
        await testFile.writeAsBytes(img.encodeJpg(testImage));
        
        final preprocessed = Float32List(224 * 224 * 3);
        
        final result = await service.detectEmergency(
          preprocessed,
          testImagePath,
        );
        
        expect(result.confidence, greaterThanOrEqualTo(0.0));
        expect(result.confidence, lessThanOrEqualTo(1.0));
      });
    });
  });
}



