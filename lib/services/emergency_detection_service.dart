import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import '../models/emergency_type.dart';
import '../models/emergency_detection_result.dart';

/// Service for detecting emergencies from images
/// Uses rule-based classification (can be enhanced with ML model later)
class EmergencyDetectionService {
  /// Detect emergency type and severity from preprocessed image
  /// 
  /// [preprocessedImage] - Normalized Float32List from ImagePreprocessingService
  /// [originalImagePath] - Path to original image for additional analysis
  /// 
  /// Returns EmergencyDetectionResult with detected type and severity
  Future<EmergencyDetectionResult> detectEmergency(
    Float32List preprocessedImage,
    String originalImagePath,
  ) async {
    try {
      // Load original image for rule-based analysis
      final File imageFile = File(originalImagePath);
      if (!await imageFile.exists()) {
        return _createDefaultResult();
      }
      
      final Uint8List imageBytes = await imageFile.readAsBytes();
      final img.Image? image = img.decodeImage(imageBytes);
      
      if (image == null) {
        return _createDefaultResult();
      }
      
      // Perform rule-based analysis
      final analysis = _analyzeImage(image);
      
      // Determine emergency type
      final emergencyType = _classifyEmergencyType(analysis);
      
      // Determine severity
      final severity = _determineSeverity(analysis, emergencyType);
      
      // Calculate confidence based on analysis strength
      final confidence = _calculateConfidence(analysis, emergencyType);
      
      return EmergencyDetectionResult(
        type: emergencyType,
        severity: severity,
        confidence: confidence,
        timestamp: DateTime.now(),
        imagePath: originalImagePath,
      );
    } catch (e) {
      debugPrint('Error in emergency detection: $e');
      return _createDefaultResult();
    }
  }
  
  /// Analyze image for emergency indicators
  Map<String, double> _analyzeImage(img.Image image) {
    final analysis = <String, double>{};
    
    // Color analysis
    final colorAnalysis = _analyzeColors(image);
    analysis.addAll(colorAnalysis);
    
    // Texture/pattern analysis
    final textureAnalysis = _analyzeTexture(image);
    analysis.addAll(textureAnalysis);
    
    // Brightness analysis
    analysis['brightness'] = _analyzeBrightness(image);
    
    // Edge detection (for structural damage)
    analysis['edge_density'] = _analyzeEdges(image);
    
    return analysis;
  }
  
  /// Analyze color distribution in image
  Map<String, double> _analyzeColors(img.Image image) {
    int redPixels = 0;
    int orangePixels = 0;
    int bluePixels = 0;
    int yellowPixels = 0;
    int grayPixels = 0;
    int totalPixels = image.width * image.height;
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;
        
        // Fire detection: Red/Orange dominance
        if (r > 200 && g < 150 && b < 150) {
          redPixels++;
        } else if (r > 180 && g > 100 && g < 200 && b < 100) {
          orangePixels++;
        }
        
        // Flood/Water detection: Blue/Cyan dominance
        if (b > 150 && r < 150 && g > 100) {
          bluePixels++;
        }
        
        // Accident/Vehicle detection: Yellow (road markings, vehicles)
        if (r > 200 && g > 200 && b < 100) {
          yellowPixels++;
        }
        
        // Smoke/Debris detection: Gray
        final grayValue = (r + g + b) / 3;
        if (grayValue > 80 && grayValue < 200 && (r - g).abs() < 30 && (g - b).abs() < 30) {
          grayPixels++;
        }
      }
    }
    
    return {
      'red_ratio': redPixels / totalPixels,
      'orange_ratio': orangePixels / totalPixels,
      'blue_ratio': bluePixels / totalPixels,
      'yellow_ratio': yellowPixels / totalPixels,
      'gray_ratio': grayPixels / totalPixels,
    };
  }
  
  /// Analyze texture patterns (for smoke, water, debris)
  Map<String, double> _analyzeTexture(img.Image image) {
    // Simple texture analysis using variance
    double variance = 0.0;
    double mean = 0.0;
    int pixelCount = 0;
    
    // Calculate mean
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        mean += (pixel.r + pixel.g + pixel.b) / 3;
        pixelCount++;
      }
    }
    mean /= pixelCount;
    
    // Calculate variance
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final value = (pixel.r + pixel.g + pixel.b) / 3;
        variance += (value - mean) * (value - mean);
      }
    }
    variance /= pixelCount;
    
    return {
      'texture_variance': variance,
      'texture_mean': mean,
    };
  }
  
  /// Analyze overall brightness
  double _analyzeBrightness(img.Image image) {
    double totalBrightness = 0.0;
    int pixelCount = 0;
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        totalBrightness += (pixel.r + pixel.g + pixel.b) / 3;
        pixelCount++;
      }
    }
    
    return totalBrightness / pixelCount / 255.0; // Normalize to [0, 1]
  }
  
  /// Analyze edge density (for structural damage, cracks)
  double _analyzeEdges(img.Image image) {
    // Simple edge detection using Sobel-like operator
    int edgeCount = 0;
    int totalPixels = 0;
    
    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        final center = image.getPixel(x, y);
        final right = image.getPixel(x + 1, y);
        final bottom = image.getPixel(x, y + 1);
        
        final centerGray = (center.r + center.g + center.b) / 3;
        final rightGray = (right.r + right.g + right.b) / 3;
        final bottomGray = (bottom.r + bottom.g + bottom.b) / 3;
        
        final horizontalGradient = (centerGray - rightGray).abs();
        final verticalGradient = (centerGray - bottomGray).abs();
        
        if (horizontalGradient > 30 || verticalGradient > 30) {
          edgeCount++;
        }
        totalPixels++;
      }
    }
    
    return edgeCount / totalPixels;
  }
  
  /// Classify emergency type based on analysis
  EmergencyType _classifyEmergencyType(Map<String, double> analysis) {
    final redRatio = analysis['red_ratio'] ?? 0.0;
    final orangeRatio = analysis['orange_ratio'] ?? 0.0;
    final blueRatio = analysis['blue_ratio'] ?? 0.0;
    final grayRatio = analysis['gray_ratio'] ?? 0.0;
    final yellowRatio = analysis['yellow_ratio'] ?? 0.0;
    final edgeDensity = analysis['edge_density'] ?? 0.0;
    final brightness = analysis['brightness'] ?? 0.0;
    final textureVariance = analysis['texture_variance'] ?? 0.0;
    
    // Fire detection: High red/orange + high brightness
    if ((redRatio > 0.15 || orangeRatio > 0.15) && brightness > 0.6) {
      return EmergencyType.fire;
    }
    
    // Flood detection: High blue + moderate brightness
    if (blueRatio > 0.20 && brightness > 0.3 && brightness < 0.7) {
      return EmergencyType.flood;
    }
    
    // Earthquake/Structural damage: High edge density + gray (debris)
    if (edgeDensity > 0.15 && grayRatio > 0.20) {
      return EmergencyType.earthquake;
    }
    
    // Accident: Yellow (road/vehicles) + moderate edge density
    if (yellowRatio > 0.10 && edgeDensity > 0.10) {
      return EmergencyType.accident;
    }
    
    // Calamity: High variance (chaos) + multiple indicators
    if (textureVariance > 2000 && (redRatio + blueRatio + grayRatio) > 0.30) {
      return EmergencyType.calamity;
    }
    
    // General emergency: Moderate indicators
    if (brightness < 0.3 || brightness > 0.8 || edgeDensity > 0.12) {
      return EmergencyType.general;
    }
    
    // Default: General emergency
    return EmergencyType.general;
  }
  
  /// Determine severity level
  SeverityLevel _determineSeverity(Map<String, double> analysis, EmergencyType type) {
    final brightness = analysis['brightness'] ?? 0.5;
    final edgeDensity = analysis['edge_density'] ?? 0.0;
    final redRatio = analysis['red_ratio'] ?? 0.0;
    final orangeRatio = analysis['orange_ratio'] ?? 0.0;
    final blueRatio = analysis['blue_ratio'] ?? 0.0;
    final textureVariance = analysis['texture_variance'] ?? 0.0;
    
    double severityScore = 0.0;
    
    // Fire severity: Based on red/orange intensity and brightness
    if (type == EmergencyType.fire) {
      severityScore = (redRatio + orangeRatio) * 2 + brightness * 0.5;
    }
    // Flood severity: Based on blue intensity
    else if (type == EmergencyType.flood) {
      severityScore = blueRatio * 3 + (1 - brightness) * 0.5;
    }
    // Earthquake severity: Based on edge density and variance
    else if (type == EmergencyType.earthquake) {
      severityScore = edgeDensity * 5 + (textureVariance / 1000);
    }
    // Accident severity: Based on edge density and brightness
    else if (type == EmergencyType.accident) {
      severityScore = edgeDensity * 4 + (1 - brightness) * 0.3;
    }
    // General severity: Based on overall indicators
    else {
      severityScore = (edgeDensity * 2) + (textureVariance / 2000) + (1 - brightness) * 0.2;
    }
    
    // Map severity score to levels
    if (severityScore >= 0.8) {
      return SeverityLevel.critical;
    } else if (severityScore >= 0.6) {
      return SeverityLevel.high;
    } else if (severityScore >= 0.4) {
      return SeverityLevel.medium;
    } else {
      return SeverityLevel.low;
    }
  }
  
  /// Calculate confidence score
  double _calculateConfidence(Map<String, double> analysis, EmergencyType type) {
    double confidence = 0.5; // Base confidence
    
    final redRatio = analysis['red_ratio'] ?? 0.0;
    final orangeRatio = analysis['orange_ratio'] ?? 0.0;
    final blueRatio = analysis['blue_ratio'] ?? 0.0;
    final edgeDensity = analysis['edge_density'] ?? 0.0;
    final textureVariance = analysis['texture_variance'] ?? 0.0;
    
    // Increase confidence based on type-specific indicators
    switch (type) {
      case EmergencyType.fire:
        confidence = 0.5 + (redRatio + orangeRatio) * 1.5;
        break;
      case EmergencyType.flood:
        confidence = 0.5 + blueRatio * 2.0;
        break;
      case EmergencyType.earthquake:
        confidence = 0.5 + edgeDensity * 2.0;
        break;
      case EmergencyType.accident:
        confidence = 0.5 + edgeDensity * 1.5;
        break;
      case EmergencyType.calamity:
        confidence = 0.5 + (textureVariance / 3000);
        break;
      case EmergencyType.general:
        confidence = 0.5 + edgeDensity;
        break;
    }
    
    // Clamp to [0.3, 0.95] range
    if (confidence < 0.3) confidence = 0.3;
    if (confidence > 0.95) confidence = 0.95;
    
    return confidence;
  }
  
  /// Create default result when detection fails
  EmergencyDetectionResult _createDefaultResult() {
    return EmergencyDetectionResult(
      type: EmergencyType.general,
      severity: SeverityLevel.medium,
      confidence: 0.5,
      timestamp: DateTime.now(),
    );
  }
}

