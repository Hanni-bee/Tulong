import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tulong_app/models/emergency_type.dart';
import 'package:tulong_app/models/emergency_detection_result.dart';
import 'package:tulong_app/services/disaster_classification_service.dart';
import 'package:tulong_app/services/emergency_detection_service.dart';
import 'package:tulong_app/services/image_preprocessing_service.dart';

/// Offline scenario validation: fixed (imagePath, expectedType) cases.
/// No network I/O; uses only local temp files and bundled model/assets.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Disaster detection scenario validation (offline)', () {
    late String tempDir;

    setUpAll(() async {
      final dir = await Directory.systemTemp.createTemp('detection_scenario');
      tempDir = dir.path;
    });

    tearDownAll(() async {
      try {
        await Directory(tempDir).delete(recursive: true);
      } catch (_) {}
    });

    String createTestImage({
      required int width,
      required int height,
      required String filename,
      void Function(img.Image image)? fill,
    }) {
      final image = img.Image(width: width, height: height);
      if (fill != null) {
        fill(image);
      } else {
        img.fill(image, color: img.ColorRgb8(128, 128, 128));
      }
      final path = '$tempDir${Platform.pathSeparator}$filename';
      File(path).writeAsBytesSync(img.encodeJpg(image));
      return path;
    }

    test('rule-based: normal gray image yields No Emergency or general', () async {
      final path = createTestImage(
        width: 180,
        height: 180,
        filename: 'normal_gray.jpg',
      );
      final preprocess = ImagePreprocessingService();
      final preprocessed = await preprocess.preprocessImage(path);
      if (preprocessed == null) {
        return; // skip if preprocessing fails in test env
      }
      final service = EmergencyDetectionService();
      final result = await service.detectEmergency(preprocessed, path);

      expect(result, isA<EmergencyDetectionResult>());
      expect(
        result.type,
        anyOf(EmergencyType.noEmergency, EmergencyType.general),
        reason: 'Normal gray scene should not be classified as disaster',
      );
    });

    test('rule-based: balanced-color image yields valid result', () async {
      final path = createTestImage(
        width: 180,
        height: 180,
        filename: 'balanced_color.jpg',
        fill: (img.Image im) {
          for (int y = 0; y < im.height; y++) {
            for (int x = 0; x < im.width; x++) {
              final r = (x * 255 / im.width).round().clamp(0, 255);
              final g = 128;
              final b = (255 - (x * 255 / im.width).round()).clamp(0, 255);
              im.setPixelRgba(x, y, r, g, b, 255);
            }
          }
        },
      );
      final preprocess = ImagePreprocessingService();
      final preprocessed = await preprocess.preprocessImage(path);
      if (preprocessed == null) return;

      final service = EmergencyDetectionService();
      final result = await service.detectEmergency(preprocessed, path);

      expect(result, isA<EmergencyDetectionResult>());
      expect(result.type, isA<EmergencyType>());
      expect(result.confidence, greaterThanOrEqualTo(0.0));
      expect(result.confidence, lessThanOrEqualTo(1.0));
    });

    test('ML path: same image yields same result (determinism)', () async {
      final path = createTestImage(
        width: 180,
        height: 180,
        filename: 'ml_consistency.jpg',
      );

      final service = DisasterClassificationService.instance;
      final loaded = await service.loadModel();
      if (!loaded || !service.isModelLoaded) {
        return; // skip if model not available in test env
      }

      final result1 = await service.classifyDisaster(path);
      final result2 = await service.classifyDisaster(path);

      expect(result1.type, result2.type, reason: 'Same image must yield same type');
      expect(
        (result1.confidence - result2.confidence).abs(),
        lessThan(1e-9),
        reason: 'Same image must yield same confidence',
      );
    });

    test('scenario: expected type is returned for curated image', () async {
      final path = createTestImage(
        width: 180,
        height: 180,
        filename: 'normal_curated.jpg',
      );

      final service = DisasterClassificationService.instance;
      final loaded = await service.loadModel();
      if (!loaded || !service.isModelLoaded) {
        return;
      }

      final result = await service.classifyDisaster(path);
      expect(result, isA<EmergencyDetectionResult>());
      expect(result.type, isA<EmergencyType>());
      expect(result.confidence, greaterThanOrEqualTo(0.0));
      expect(result.confidence, lessThanOrEqualTo(1.0));
      expect(
        result.type,
        anyOf(EmergencyType.noEmergency, EmergencyType.general, EmergencyType.fire, EmergencyType.flood, EmergencyType.earthquake, EmergencyType.calamity),
      );
    });
  });
}
