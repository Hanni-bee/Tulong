import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import '../models/emergency_type.dart';
import '../models/emergency_detection_result.dart';
import '../utils/hsv_color_converter.dart';
import 'ml_model_service.dart';

/// Service for detecting emergencies from images
/// Uses rule-based classification with optional ML model enhancement
class EmergencyDetectionService {
  final MLModelService _mlModelService = MLModelService.instance;
  bool _useMLModel = false;
  /// Enable/disable ML model usage
  /// ML model must be loaded separately using MLModelService.loadModel()
  void setUseMLModel(bool useML) {
    _useMLModel = useML && _mlModelService.isLoaded;
    debugPrint('ML Model usage: ${_useMLModel ? "ENABLED" : "DISABLED"}');
  }
  
  /// Detect emergency type and severity from preprocessed image
  /// Uses multi-pass analysis with false positive prevention
  /// Optionally uses ML model for feature extraction if available
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
      
    // PASS 1: Full image analysis with adaptive threshold calculation
    var fullAnalysis = _analyzeImage(image);
    
    // Calculate adaptive thresholds based on image characteristics
    final adaptiveThresholds = _calculateAdaptiveThresholds(fullAnalysis);
    fullAnalysis.addAll(adaptiveThresholds);
    
    // PASS 0.5: ML Model feature extraction and disaster intensity analysis (if enabled and available)
    if (_useMLModel && _mlModelService.isLoaded) {
      try {
        // Extract ML features for classification
        final mlFeatures = await _mlModelService.extractFeatures(preprocessedImage);
        if (mlFeatures != null) {
          // Add ML features to analysis
          fullAnalysis['ml_features_mean'] = mlFeatures.reduce((a, b) => a + b) / mlFeatures.length;
          fullAnalysis['ml_features_max'] = mlFeatures.reduce((a, b) => a > b ? a : b);
          fullAnalysis['ml_features_min'] = mlFeatures.reduce((a, b) => a < b ? a : b);
          fullAnalysis['ml_features_variance'] = _calculateVariance(mlFeatures);
          debugPrint('✅ ML features extracted: ${mlFeatures.length} features');
        }
        
        // NEW: Analyze disaster intensity using Disaster Intensity Analyzer
        final intensityAnalysis = await _mlModelService.analyzeDisasterIntensity(preprocessedImage);
        if (intensityAnalysis != null) {
          // Add intensity scores to analysis
          fullAnalysis.addAll(intensityAnalysis);
          
          // Map ML intensity to emergency types
          if (intensityAnalysis.containsKey('earthquake_intensity')) {
            fullAnalysis['ml_earthquake_intensity'] = intensityAnalysis['earthquake_intensity']!;
          }
          if (intensityAnalysis.containsKey('wildfire_intensity')) {
            fullAnalysis['ml_fire_intensity'] = intensityAnalysis['wildfire_intensity']!;
          }
          if (intensityAnalysis.containsKey('flood_intensity')) {
            fullAnalysis['ml_flood_intensity'] = intensityAnalysis['flood_intensity']!;
          }
          if (intensityAnalysis.containsKey('wind_intensity')) {
            fullAnalysis['ml_wind_intensity'] = intensityAnalysis['wind_intensity']!;
          }
          if (intensityAnalysis.containsKey('overall_intensity')) {
            fullAnalysis['ml_overall_intensity'] = intensityAnalysis['overall_intensity']!;
          }
          
          debugPrint('✅ Disaster intensity analyzed: ${intensityAnalysis.keys.join(", ")}');
        }
      } catch (e) {
        debugPrint('⚠️ ML analysis failed, using rule-based only: $e');
      }
    }
    
    // PASS 1.5: Multi-scale analysis (enhanced)
    final multiScaleAnalysis = _analyzeMultiScale(image);
    fullAnalysis.addAll(multiScaleAnalysis);
    
    // PASS 1.6: Histogram analysis (enhanced)
    final histogramAnalysis = _analyzeHistograms(image);
    fullAnalysis.addAll(histogramAnalysis);
    
    // PASS 2: Region-based analysis (divide image into grid)
    final regionAnalysis = _analyzeRegions(image);
    
    // PASS 3: Context validation (check for false positives)
    final contextValidation = _validateContext(image, fullAnalysis);
    
    // PASS 4: Multi-factor classification with validation
    final classificationResult = _classifyWithValidation(
      fullAnalysis,
      regionAnalysis,
      contextValidation,
    );
    
    final detectedType = classificationResult['type'] as EmergencyType;
    final confidence = classificationResult['confidence'] as double;
    final normalSceneLikelihood = contextValidation['normal_scene_likelihood'] ?? 0.5;
    final organizedPatterns = contextValidation['organized_patterns'] ?? 0.0;
    final falsePositiveRisk = contextValidation['false_positive_risk'] ?? 0.0;
    
    // IMPROVED: More aggressive normal scene detection to ALWAYS inform user about safe scenes
    // Check if this is clearly a normal scene with no emergency
    bool isNormalScene = false;
    
    // Get dynamic thresholds from adaptive thresholds (reuse from line 53)
    final normalSceneThreshold = adaptiveThresholds['adaptive_normal_scene_threshold'] ?? 0.70;
    final organizedPatternThreshold = adaptiveThresholds['adaptive_organized_pattern_threshold'] ?? 0.30;
    final falsePositiveThreshold = adaptiveThresholds['adaptive_false_positive_threshold'] ?? 0.40;
    final dynamicConfidenceThreshold = _calculateDynamicConfidenceThreshold(fullAnalysis, detectedType);
    
    // Primary check: High normal scene likelihood (dynamic threshold)
    if (normalSceneLikelihood > normalSceneThreshold) {
      isNormalScene = true;
    }
    // Secondary check: Organized patterns + low emergency indicators (dynamic thresholds)
    else if (organizedPatterns > organizedPatternThreshold &&
             normalSceneLikelihood > (normalSceneThreshold * 0.85) &&
             (falsePositiveRisk > falsePositiveThreshold || organizedPatterns > (organizedPatternThreshold * 1.3))) {
      isNormalScene = true;
    }
    // Tertiary check: Low emergency confidence + moderate normal scene indicators (dynamic thresholds)
    else if (confidence < dynamicConfidenceThreshold &&
             normalSceneLikelihood > (normalSceneThreshold * 0.9) &&
             organizedPatterns > (organizedPatternThreshold * 0.7)) {
      isNormalScene = true;
    }
    // Quaternary check: General type with low confidence and normal indicators
    else if (detectedType == EmergencyType.general && 
             confidence < 0.60 && // Slightly higher
             normalSceneLikelihood > 0.60 && // Lowered from 0.62
             organizedPatterns > 0.15) { // Lowered from 0.2
      isNormalScene = true;
    }
    // NEW: Fifth check - Very low emergency indicators across the board
    else {
      final lowEmergencyIndicators = 
          (fullAnalysis['red_ratio'] ?? 0.0) < 0.05 &&
          (fullAnalysis['orange_ratio'] ?? 0.0) < 0.05 &&
          (fullAnalysis['blue_ratio'] ?? 0.0) < 0.10 &&
          (fullAnalysis['edge_density'] ?? 0.0) < 0.10 &&
          normalSceneLikelihood > 0.55;
      
      if (lowEmergencyIndicators && organizedPatterns > 0.15) {
        isNormalScene = true;
      }
    }
    
    if (isNormalScene) {
      // High confidence that this is a normal scene - ALWAYS reassure user
      // Use higher confidence calculation to make it clear to the user
      final noEmergencyConfidence = (0.70 + (1.0 - normalSceneLikelihood) * 0.25).clamp(0.70, 0.95);
      final noEmergencyInterval = _calculateConfidenceInterval(noEmergencyConfidence, fullAnalysis);
      return EmergencyDetectionResult(
        type: EmergencyType.noEmergency,
        severity: SeverityLevel.low, // Not applicable, but required
        confidence: noEmergencyConfidence,
        confidenceLowerBound: noEmergencyInterval['lower'],
        confidenceUpperBound: noEmergencyInterval['upper'],
        timestamp: DateTime.now(),
        imagePath: originalImagePath,
      );
    }
    
    // Only proceed if confidence is high enough (prevent false alarms)
    if (confidence < 0.6) {
      // Low confidence - likely not an emergency
      // IMPROVED: More aggressively detect "no emergency" in low confidence cases
      if (normalSceneLikelihood > 0.65 || organizedPatterns > 0.25) { // Lowered thresholds
        return EmergencyDetectionResult(
          type: EmergencyType.noEmergency,
          severity: SeverityLevel.low,
          confidence: 0.70 + (normalSceneLikelihood * 0.15).clamp(0.0, 0.25), // Higher confidence
          timestamp: DateTime.now(),
          imagePath: originalImagePath,
        );
      }
      // If we can't say "no emergency" but also can't confirm emergency, still try to be helpful
      // Check if we have enough normal indicators
      final lowEmergencyScore = 
          ((fullAnalysis['red_ratio'] ?? 0.0) < 0.08 ? 1 : 0) +
          ((fullAnalysis['orange_ratio'] ?? 0.0) < 0.08 ? 1 : 0) +
          ((fullAnalysis['blue_ratio'] ?? 0.0) < 0.12 ? 1 : 0) +
          ((fullAnalysis['edge_density'] ?? 0.0) < 0.10 ? 1 : 0);
      
      if (lowEmergencyScore >= 3 && normalSceneLikelihood > 0.55) {
        // Most indicators suggest no emergency
        return EmergencyDetectionResult(
          type: EmergencyType.noEmergency,
          severity: SeverityLevel.low,
          confidence: 0.65 + (normalSceneLikelihood * 0.15).clamp(0.0, 0.20),
          timestamp: DateTime.now(),
          imagePath: originalImagePath,
        );
      }
      
      // Ambiguous - use general as fallback (but this should be rare now)
      return EmergencyDetectionResult(
        type: EmergencyType.general,
        severity: SeverityLevel.low,
        confidence: confidence,
        timestamp: DateTime.now(),
        imagePath: originalImagePath,
      );
    }
    
    return EmergencyDetectionResult(
      type: detectedType,
      severity: classificationResult['severity'] as SeverityLevel,
      confidence: confidence,
      timestamp: DateTime.now(),
      imagePath: originalImagePath,
    );
    } catch (e) {
      debugPrint('Error in emergency detection: $e');
      return _createDefaultResult();
    }
  }
  
  /// Analyze image for emergency indicators with comprehensive analysis
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
    analysis['brightness_variance'] = _analyzeBrightnessVariance(image);
    
    // Edge detection (for structural damage)
    final edgeAnalysis = _analyzeEdges(image);
    analysis.addAll(edgeAnalysis);
    
    // Spatial distribution analysis
    final spatialAnalysis = _analyzeSpatialDistribution(image);
    analysis.addAll(spatialAnalysis);
    
    // Motion blur / stability detection
    analysis['image_stability'] = _analyzeImageStability(image);
    
    // Contrast analysis
    analysis['overall_contrast'] = _analyzeOverallContrast(image);
    
    // NEW: Advanced pattern detection
    analysis['smoke_pattern'] = _detectSmokePatterns(image);
    analysis['water_texture'] = _detectWaterTexture(image);
    analysis['structural_damage'] = _detectStructuralDamage(image);
    analysis['flame_pattern'] = _detectFlamePatterns(image);
    analysis['reflection_pattern'] = _detectReflectionPatterns(image);
    
    return analysis;
  }
  
  /// Analyze image divided into regions for better detection
  Map<String, double> _analyzeRegions(img.Image image) {
    final int gridSize = 3; // 3x3 grid = 9 regions
    final int regionWidth = image.width ~/ gridSize;
    final int regionHeight = image.height ~/ gridSize;
    
    final List<Map<String, double>> regionAnalyses = [];
    
    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        final x = col * regionWidth;
        final y = row * regionHeight;
        final region = img.copyCrop(
          image,
          x: x,
          y: y,
          width: regionWidth,
          height: regionHeight,
        );
        
        final regionAnalysis = _analyzeImage(region);
        regionAnalyses.add(regionAnalysis);
      }
    }
    
    // Aggregate region analysis
    return _aggregateRegionAnalysis(regionAnalyses);
  }
  
  /// Aggregate multiple region analyses into single metrics
  Map<String, double> _aggregateRegionAnalysis(List<Map<String, double>> regions) {
    final aggregated = <String, double>{};
    final int regionCount = regions.length;
    
    // Calculate overall brightness and texture variance from regions for dynamic thresholds
    double overallBrightness = 0.0;
    double overallTextureVariance = 0.0;
    for (final region in regions) {
      overallBrightness += region['brightness'] ?? 0.0;
      overallTextureVariance += region['texture_variance'] ?? 0.0;
    }
    overallBrightness /= regionCount;
    overallTextureVariance /= regionCount;
    
    // Calculate mean and variance for key metrics
    final metrics = ['red_ratio', 'orange_ratio', 'blue_ratio', 'edge_density', 'brightness'];
    
    for (final metric in metrics) {
      double sum = 0.0;
      double maxVal = 0.0;
      double minVal = double.infinity;
      int activeRegions = 0;
      
      for (final region in regions) {
        final value = region[metric] ?? 0.0;
        sum += value;
        if (value > maxVal) maxVal = value;
        if (value < minVal) minVal = value;
        // Dynamic threshold for "active" region based on metric type
        final dynamicActiveThreshold = metric == 'edge_density' 
            ? 0.04 + (overallTextureVariance / 30000)
            : 0.05 + (overallBrightness * 0.02);
        if (value > dynamicActiveThreshold) activeRegions++;
      }
      
      aggregated['${metric}_mean'] = sum / regionCount;
      aggregated['${metric}_max'] = maxVal;
      aggregated['${metric}_min'] = minVal;
      aggregated['${metric}_spread'] = maxVal - minVal;
      aggregated['${metric}_active_regions'] = activeRegions / regionCount;
    }
    
    return aggregated;
  }
  
  /// Validate context to prevent false positives - ENHANCED & FULLY DYNAMIC
  Map<String, double> _validateContext(img.Image image, Map<String, double> analysis) {
    final validation = <String, double>{};
    
    // Get dynamic thresholds from adaptive calculation
    final adaptiveThresholds = _calculateAdaptiveThresholds(analysis);
    final normalSceneThreshold = adaptiveThresholds['adaptive_normal_scene_threshold'] ?? 0.70;
    final organizedPatternThreshold = adaptiveThresholds['adaptive_organized_pattern_threshold'] ?? 0.25;
    final falsePositiveThreshold = adaptiveThresholds['adaptive_false_positive_threshold'] ?? 0.40;
    
    // Check if image looks like normal indoor/outdoor scene
    final brightness = analysis['brightness'] ?? 0.5;
    final edgeDensity = analysis['edge_density'] ?? 0.0;
    final textureVariance = analysis['texture_variance'] ?? 0.0;
    final redRatio = analysis['red_ratio'] ?? 0.0;
    final orangeRatio = analysis['orange_ratio'] ?? 0.0;
    final blueRatio = analysis['blue_ratio'] ?? 0.0;
    final overallContrast = analysis['overall_contrast'] ?? 0.5;
    
    // Calculate dynamic thresholds based on image characteristics
    final dynamicBrightnessMin = 0.20 + (brightness * 0.1);
    final dynamicBrightnessMax = 0.70 + (brightness * 0.1);
    final dynamicEdgeThreshold = 0.08 + (textureVariance / 15000);
    final dynamicTextureThreshold = 1000 + (textureVariance * 0.2);
    final dynamicRedThreshold = 0.06 + (brightness * 0.04);
    final dynamicOrangeThreshold = 0.06 + (brightness * 0.04);
    final dynamicBlueThreshold = 0.12 + (brightness * 0.05);
    final dynamicContrastMin = 0.15 + (overallContrast * 0.1);
    final dynamicContrastMax = 0.75 + (overallContrast * 0.1);
    final dynamicStabilityThreshold = 0.35 + (brightness * 0.1);
    
    // Normal scene indicators - DYNAMIC CHECKS
    double normalScore = 1.0;
    int normalIndicators = 0;
    int totalChecks = 0;
    
    // Check 1: Moderate brightness (normal indoor/outdoor) - DYNAMIC
    totalChecks++;
    if (brightness > dynamicBrightnessMin && brightness < dynamicBrightnessMax) {
      normalIndicators++;
    }
    
    // Check 2: Low edge density (no structural damage) - DYNAMIC
    totalChecks++;
    if (edgeDensity < dynamicEdgeThreshold) {
      normalIndicators++;
    }
    
    // Check 3: Low texture variance (organized, not chaotic) - DYNAMIC
    totalChecks++;
    if (textureVariance < dynamicTextureThreshold) {
      normalIndicators++;
    }
    
    // Check 4: Low emergency color ratios (no fire/flood indicators) - DYNAMIC
    totalChecks++;
    if (redRatio < dynamicRedThreshold && orangeRatio < dynamicOrangeThreshold && blueRatio < dynamicBlueThreshold) {
      normalIndicators++;
    }
    
    // Check 5: Moderate contrast (not extreme) - DYNAMIC
    totalChecks++;
    if (overallContrast > dynamicContrastMin && overallContrast < dynamicContrastMax) {
      normalIndicators++;
    }
    
    // Check 6: Organized patterns (windows, walls, structures) - DYNAMIC
    final organizedPatterns = _detectOrganizedPatterns(image);
    totalChecks++;
    if (organizedPatterns > organizedPatternThreshold) {
      normalIndicators++;
      normalScore *= 0.6; // Strong penalty for organized patterns
    }
    
    // Check 7: Image stability (not blurry, not chaotic) - DYNAMIC
    final imageStability = analysis['image_stability'] ?? 0.5;
    totalChecks++;
    if (imageStability > dynamicStabilityThreshold) {
      normalIndicators++;
    }
    
    // Calculate normal score based on indicators
    final indicatorRatio = normalIndicators / totalChecks;
    normalScore = indicatorRatio;
    
    // DYNAMIC: If most indicators suggest normal scene, heavily penalize
    final dynamicIndicatorThreshold = 0.55 + (brightness * 0.1);
    if (indicatorRatio > dynamicIndicatorThreshold) {
      normalScore = 0.3; // Very high normal scene likelihood
    }
    
    // EXTRA CHECK: If organized patterns AND low emergency indicators → Very likely normal - DYNAMIC
    final dynamicOrganizedCheck = organizedPatternThreshold * 1.2;
    final dynamicRedCheck = dynamicRedThreshold * 1.3;
    final dynamicOrangeCheck = dynamicOrangeThreshold * 1.3;
    final dynamicBlueCheck = dynamicBlueThreshold * 1.2;
    final dynamicEdgeCheck = dynamicEdgeThreshold * 1.5;
    
    if (organizedPatterns > dynamicOrganizedCheck && 
        redRatio < dynamicRedCheck && 
        orangeRatio < dynamicOrangeCheck && 
        blueRatio < dynamicBlueCheck && 
        edgeDensity < dynamicEdgeCheck) {
      normalScore = 0.2; // Extremely likely normal scene
    }
    
    validation['normal_scene_likelihood'] = normalScore;
    validation['organized_patterns'] = organizedPatterns;
    validation['normal_indicators'] = normalIndicators / totalChecks;
    validation['false_positive_risk'] = 1.0 - normalScore;
    
    return validation;
  }
  
  /// Detect organized patterns (windows, walls, regular structures)
  double _detectOrganizedPatterns(img.Image image) {
    // Look for horizontal and vertical lines (indicating structures)
    int horizontalLines = 0;
    int verticalLines = 0;
    int totalPixels = 0;
    
    // Sample every 5th pixel for performance
    for (int y = 2; y < image.height - 2; y += 5) {
      for (int x = 2; x < image.width - 2; x += 5) {
        final center = image.getPixel(x, y);
        final left = image.getPixel(x - 2, y);
        final right = image.getPixel(x + 2, y);
        final top = image.getPixel(x, y - 2);
        final bottom = image.getPixel(x, y + 2);
        
        final centerGray = (center.r + center.g + center.b) / 3;
        final leftGray = (left.r + left.g + left.b) / 3;
        final rightGray = (right.r + right.g + right.b) / 3;
        final topGray = (top.r + top.g + top.b) / 3;
        final bottomGray = (bottom.r + bottom.g + bottom.b) / 3;
        
        // Horizontal line detection
        if ((leftGray - centerGray).abs() < 10 && (rightGray - centerGray).abs() < 10 &&
            (leftGray - rightGray).abs() < 15) {
          horizontalLines++;
        }
        
        // Vertical line detection
        if ((topGray - centerGray).abs() < 10 && (bottomGray - centerGray).abs() < 10 &&
            (topGray - bottomGray).abs() < 15) {
          verticalLines++;
        }
        
        totalPixels++;
      }
    }
    
    final lineRatio = (horizontalLines + verticalLines) / (totalPixels * 2);
    return lineRatio.clamp(0.0, 1.0);
  }
  
  /// Analyze spatial distribution of emergency indicators
  Map<String, double> _analyzeSpatialDistribution(img.Image image) {
    // Divide image into zones and analyze distribution
    // Top-left, top-right, bottom-left, bottom-right
    final int midX = image.width ~/ 2;
    final int midY = image.height ~/ 2;
    
    final List<double> zoneRedRatios = [];
    final List<double> zoneEdgeDensities = [];
    
    final zonesList = [
      {'x': 0, 'y': 0, 'w': midX, 'h': midY}, // Top-left
      {'x': midX, 'y': 0, 'w': image.width - midX, 'h': midY}, // Top-right
      {'x': 0, 'y': midY, 'w': midX, 'h': image.height - midY}, // Bottom-left
      {'x': midX, 'y': midY, 'w': image.width - midX, 'h': image.height - midY}, // Bottom-right
    ];
    
    for (final zone in zonesList) {
      final zoneImg = img.copyCrop(
        image,
        x: zone['x'] as int,
        y: zone['y'] as int,
        width: zone['w'] as int,
        height: zone['h'] as int,
      );
      
      final colorAnalysis = _analyzeColors(zoneImg);
      final edgeAnalysis = _analyzeEdges(zoneImg);
      
      zoneRedRatios.add(colorAnalysis['red_ratio'] ?? 0.0);
      zoneEdgeDensities.add(edgeAnalysis['edge_density'] ?? 0.0);
    }
    
    // Calculate distribution metrics
    final redMax = zoneRedRatios.reduce((a, b) => a > b ? a : b);
    final redMin = zoneRedRatios.reduce((a, b) => a < b ? a : b);
    final redSpread = redMax - redMin;
    
    final edgeMax = zoneEdgeDensities.reduce((a, b) => a > b ? a : b);
    final edgeMin = zoneEdgeDensities.reduce((a, b) => a < b ? a : b);
    final edgeSpread = edgeMax - edgeMin;
    
    return {
      'spatial_red_spread': redSpread,
      'spatial_edge_spread': edgeSpread,
      'spatial_concentration': (redMax > 0.2 || edgeMax > 0.15) ? 1.0 : 0.0,
    };
  }
  
  /// Analyze brightness variance across image
  double _analyzeBrightnessVariance(img.Image image) {
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
    double variance = 0.0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final value = (pixel.r + pixel.g + pixel.b) / 3;
        variance += (value - mean) * (value - mean);
      }
    }
    variance /= pixelCount;
    
    return variance / (255 * 255); // Normalize
  }
  
  /// Analyze image stability (motion blur detection)
  double _analyzeImageStability(img.Image image) {
    // Simple motion blur detection using edge sharpness
    int sharpEdges = 0;
    int totalEdges = 0;
    
    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        final center = image.getPixel(x, y);
        final right = image.getPixel(x + 1, y);
        final bottom = image.getPixel(x, y + 1);
        
        final centerGray = (center.r + center.g + center.b) / 3;
        final rightGray = (right.r + right.g + right.b) / 3;
        final bottomGray = (bottom.r + bottom.g + bottom.b) / 3;
        
        final gradient = ((centerGray - rightGray).abs() + (centerGray - bottomGray).abs()) / 2;
        
        if (gradient > 20) {
          totalEdges++;
          if (gradient > 50) {
            sharpEdges++;
          }
        }
      }
    }
    
    if (totalEdges == 0) return 0.5;
    return (sharpEdges / totalEdges).clamp(0.0, 1.0);
  }
  
  /// Analyze overall contrast
  double _analyzeOverallContrast(img.Image image) {
    double minBrightness = 255.0;
    double maxBrightness = 0.0;
    
    // Sample pixels for performance
    for (int y = 0; y < image.height; y += 2) {
      for (int x = 0; x < image.width; x += 2) {
        final pixel = image.getPixel(x, y);
        final brightness = (pixel.r + pixel.g + pixel.b) / 3;
        if (brightness < minBrightness) minBrightness = brightness;
        if (brightness > maxBrightness) maxBrightness = brightness;
      }
    }
    
    return ((maxBrightness - minBrightness) / 255.0).clamp(0.0, 1.0);
  }
  
  /// Multi-scale analysis - analyze at different resolutions
  Map<String, double> _analyzeMultiScale(img.Image image) {
    final analysis = <String, double>{};
    
    // Scale 1: Full image (already analyzed)
    // Scale 2: Half resolution
    final halfSize = img.copyResize(image, width: image.width ~/ 2, height: image.height ~/ 2);
    final halfAnalysis = _analyzeImage(halfSize);
    
    // Scale 3: Quarter resolution
    final quarterSize = img.copyResize(image, width: image.width ~/ 4, height: image.height ~/ 4);
    final quarterAnalysis = _analyzeImage(quarterSize);
    
    // Compare scales - real emergencies show consistent patterns
    final redRatioFull = analysis['red_ratio'] ?? 0.0;
    final redRatioHalf = halfAnalysis['red_ratio'] ?? 0.0;
    final redRatioQuarter = quarterAnalysis['red_ratio'] ?? 0.0;
    
    final edgeDensityFull = analysis['edge_density'] ?? 0.0;
    final edgeDensityHalf = halfAnalysis['edge_density'] ?? 0.0;
    final edgeDensityQuarter = quarterAnalysis['edge_density'] ?? 0.0;
    
    // Consistency score - real emergencies are consistent across scales
    final redConsistency = 1.0 - ((redRatioFull - redRatioHalf).abs() + 
                                  (redRatioHalf - redRatioQuarter).abs()) / 2.0;
    final edgeConsistency = 1.0 - ((edgeDensityFull - edgeDensityHalf).abs() + 
                                    (edgeDensityHalf - edgeDensityQuarter).abs()) / 2.0;
    
    analysis['multi_scale_consistency'] = (redConsistency + edgeConsistency) / 2.0;
    analysis['multi_scale_red_avg'] = (redRatioFull + redRatioHalf + redRatioQuarter) / 3.0;
    analysis['multi_scale_edge_avg'] = (edgeDensityFull + edgeDensityHalf + edgeDensityQuarter) / 3.0;
    
    return analysis;
  }
  
  /// Histogram analysis - better color distribution understanding
  Map<String, double> _analyzeHistograms(img.Image image) {
    final analysis = <String, double>{};
    
    // RGB histograms
    final List<int> redHist = List.filled(256, 0);
    final List<int> greenHist = List.filled(256, 0);
    final List<int> blueHist = List.filled(256, 0);
    final List<int> brightnessHist = List.filled(256, 0);
    
    int totalPixels = 0;
    
    // Build histograms
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        redHist[pixel.r.toInt()]++;
        greenHist[pixel.g.toInt()]++;
        blueHist[pixel.b.toInt()]++;
        
        final brightness = ((pixel.r + pixel.g + pixel.b) / 3).round();
        brightnessHist[brightness.clamp(0, 255).toInt()]++;
        totalPixels++;
      }
    }
    
    // Find peaks in histograms
    int redPeak = 0;
    int redPeakValue = 0;
    int bluePeak = 0;
    int bluePeakValue = 0;
    int brightnessPeak = 0;
    int brightnessPeakValue = 0;
    
    for (int i = 0; i < 256; i++) {
      if (redHist[i] > redPeakValue) {
        redPeakValue = redHist[i];
        redPeak = i;
      }
      if (blueHist[i] > bluePeakValue) {
        bluePeakValue = blueHist[i];
        bluePeak = i;
      }
      if (brightnessHist[i] > brightnessPeakValue) {
        brightnessPeakValue = brightnessHist[i];
        brightnessPeak = i;
      }
    }
    
    // Analyze histogram characteristics
    // Fire: High red peak (>200), high brightness peak
    // Flood: High blue peak (>150), moderate brightness
    // Normal: Balanced histograms, no extreme peaks
    
    analysis['red_histogram_peak'] = redPeak / 255.0;
    analysis['red_histogram_peak_strength'] = redPeakValue / totalPixels;
    analysis['blue_histogram_peak'] = bluePeak / 255.0;
    analysis['blue_histogram_peak_strength'] = bluePeakValue / totalPixels;
    analysis['brightness_histogram_peak'] = brightnessPeak / 255.0;
    analysis['brightness_histogram_peak_strength'] = brightnessPeakValue / totalPixels;
    
    // Calculate histogram variance (spread)
    double redMean = 0.0;
    double blueMean = 0.0;
    for (int i = 0; i < 256; i++) {
      redMean += i * redHist[i];
      blueMean += i * blueHist[i];
    }
    redMean /= totalPixels;
    blueMean /= totalPixels;
    
    double redVariance = 0.0;
    double blueVariance = 0.0;
    for (int i = 0; i < 256; i++) {
      redVariance += (i - redMean) * (i - redMean) * redHist[i];
      blueVariance += (i - blueMean) * (i - blueMean) * blueHist[i];
    }
    redVariance /= totalPixels;
    blueVariance /= totalPixels;
    
    analysis['red_histogram_variance'] = redVariance / (255 * 255);
    analysis['blue_histogram_variance'] = blueVariance / (255 * 255);
    
    return analysis;
  }
  
  /// Classify with validation to prevent false positives
  Map<String, dynamic> _classifyWithValidation(
    Map<String, double> fullAnalysis,
    Map<String, double> regionAnalysis,
    Map<String, double> contextValidation,
  ) {
    // Get initial classification
    final initialType = _classifyEmergencyType(fullAnalysis);
    
    // Check false positive risk
    final falsePositiveRisk = contextValidation['false_positive_risk'] ?? 0.0;
    final normalSceneLikelihood = contextValidation['normal_scene_likelihood'] ?? 0.5;
    
    // STRICT false positive prevention
    EmergencyType finalType = initialType;
    
    // If high risk of false positive OR high normal scene likelihood, downgrade
    if (falsePositiveRisk > 0.5 || normalSceneLikelihood > 0.6) {
      // High risk of false positive - be VERY conservative
      // Only keep fire if confidence is extremely high (>85%)
      if (initialType == EmergencyType.fire) {
        final initialConfidence = _calculateConfidence(fullAnalysis, initialType);
        if (initialConfidence < 0.85) {
          finalType = EmergencyType.general;
        }
      } else {
        // For all other types, downgrade if false positive risk
        finalType = EmergencyType.general;
      }
    }
    
    // EXTRA CHECK: If organized patterns detected AND low emergency indicators → Definitely normal
    final organizedPatterns = contextValidation['organized_patterns'] ?? 0.0;
    final redRatio = fullAnalysis['red_ratio'] ?? 0.0;
    final orangeRatio = fullAnalysis['orange_ratio'] ?? 0.0;
    final blueRatio = fullAnalysis['blue_ratio'] ?? 0.0;
    final edgeDensity = fullAnalysis['edge_density'] ?? 0.0;
    
    if (organizedPatterns > 0.3 && 
        redRatio < 0.1 && 
        orangeRatio < 0.1 && 
        blueRatio < 0.15 && 
        edgeDensity < 0.12) {
      // This is definitely a normal scene - force to general
      finalType = EmergencyType.general;
    }
    
    // Validate with region analysis
    final regionValidation = _validateWithRegions(initialType, regionAnalysis);
    if (!regionValidation['valid']) {
      // Regions don't support the classification
      finalType = EmergencyType.general;
    }
    
    // Calculate confidence FIRST (before severity)
    double confidence = _calculateConfidence(fullAnalysis, finalType);
    
    // Apply validation penalties
    confidence *= (1.0 - falsePositiveRisk * 0.4); // Increased penalty
    confidence *= regionValidation['confidence_multiplier'] as double;
    
    // Get dynamic confidence threshold (no static values)
    final dynamicConfidenceThreshold = _calculateDynamicConfidenceThreshold(fullAnalysis, finalType);
    final normalSceneThreshold = fullAnalysis['adaptive_normal_scene_threshold'] ?? 0.70;
    
    // STRICT minimum confidence threshold - prevent false alarms (dynamic)
    if (finalType != EmergencyType.general) {
      // Dynamic threshold based on type and image characteristics
      if (confidence < dynamicConfidenceThreshold) {
        finalType = EmergencyType.general;
        confidence = 0.4; // Lower confidence for ambiguous cases
      }
    }
    
    // FINAL SAFETY CHECK: If normal scene likelihood is very high, force general (dynamic threshold)
    if (normalSceneLikelihood > normalSceneThreshold) {
      finalType = EmergencyType.general;
      confidence = 0.35; // Very low confidence for normal scenes
    }
    
    // Calculate severity AFTER type is finalized
    // IMPORTANT: General emergencies should ALWAYS be Low severity
    SeverityLevel severity;
    if (finalType == EmergencyType.general) {
      // General emergency = always Low severity (prevents false alarms)
      severity = SeverityLevel.low;
      // If confidence is very low, reduce it further
      if (confidence < 0.5) {
        confidence = 0.35;
      }
    } else {
      // Only calculate severity for specific emergency types
      severity = _determineSeverity(fullAnalysis, finalType);
      
      // Get dynamic confidence thresholds for severity adjustment
      final dynamicConfidenceThreshold = _calculateDynamicConfidenceThreshold(fullAnalysis, finalType);
      final highConfidenceThreshold = dynamicConfidenceThreshold + 0.10;
      final mediumConfidenceThreshold = dynamicConfidenceThreshold + 0.05;
      
      // If confidence is borderline, reduce severity (dynamic thresholds)
      if (confidence < highConfidenceThreshold && severity == SeverityLevel.critical) {
        severity = SeverityLevel.high;
      }
      if (confidence < mediumConfidenceThreshold && severity == SeverityLevel.high) {
        severity = SeverityLevel.medium;
      }
    }
    
    return {
      'type': finalType,
      'severity': severity,
      'confidence': confidence.clamp(0.3, 0.98),
    };
  }
  
  /// Validate classification with region analysis
  Map<String, dynamic> _validateWithRegions(
    EmergencyType type,
    Map<String, double> regionAnalysis,
  ) {
    bool valid = true;
    double confidenceMultiplier = 1.0;
    
    switch (type) {
      case EmergencyType.fire:
        final redActiveRegions = regionAnalysis['red_ratio_active_regions'] ?? 0.0;
        final orangeActiveRegions = regionAnalysis['orange_ratio_active_regions'] ?? 0.0;
        if (redActiveRegions < 0.2 && orangeActiveRegions < 0.2) {
          valid = false;
          confidenceMultiplier = 0.5;
        }
        break;
      case EmergencyType.flood:
        final blueActiveRegions = regionAnalysis['blue_ratio_active_regions'] ?? 0.0;
        if (blueActiveRegions < 0.3) {
          valid = false;
          confidenceMultiplier = 0.6;
        }
        break;
      case EmergencyType.earthquake:
        final edgeActiveRegions = regionAnalysis['edge_density_active_regions'] ?? 0.0;
        if (edgeActiveRegions < 0.3) {
          valid = false;
          confidenceMultiplier = 0.5;
        }
        break;
      default:
        break;
    }
    
    return {
      'valid': valid,
      'confidence_multiplier': confidenceMultiplier,
    };
  }
  
  /// Analyze color distribution in image with IMPROVED HSV-based algorithms
  /// HSV color space is more accurate for emergency detection than RGB
  Map<String, double> _analyzeColors(img.Image image) {
    int firePixels = 0;
    int waterPixels = 0;
    int smokePixels = 0;
    int yellowPixels = 0;
    int grayPixels = 0;
    int darkPixels = 0;
    int brightPixels = 0;
    int totalPixels = image.width * image.height;
    
    // Intensity accumulators (using HSV-based scoring)
    double fireIntensitySum = 0.0;
    double waterIntensitySum = 0.0;
    double smokeIntensitySum = 0.0;
    
    // For backward compatibility, also track RGB-based ratios
    int redPixels = 0;
    int orangePixels = 0;
    int bluePixels = 0;
    double redIntensity = 0.0;
    double orangeIntensity = 0.0;
    double blueIntensity = 0.0;
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();
        
        // Calculate luminance (still used for some checks)
        final luminance = (0.299 * r + 0.587 * g + 0.114 * b);
        
        // IMPROVED: Convert to HSV for better color-based detection
        final hsv = HSVColorConverter.rgbToHsv(r, g, b);
        final h = hsv['h']!;
        final s = hsv['s']!;
        final v = hsv['v']!;
        
        // Fire detection using HSV (more accurate than RGB)
        if (HSVColorConverter.isFireColor(h, s, v)) {
          firePixels++;
          final intensity = HSVColorConverter.getFireIntensity(h, s, v);
          fireIntensitySum += intensity;
          
          // Also track for backward compatibility
          if (h <= 30 || h >= 330) {
            redPixels++;
            redIntensity += intensity;
          } else {
            orangePixels++;
            orangeIntensity += intensity;
          }
        }
        
        // Water/Flood detection using HSV (more accurate for blue/cyan)
        if (HSVColorConverter.isWaterColor(h, s, v)) {
          waterPixels++;
          final intensity = HSVColorConverter.getWaterIntensity(h, s, v);
          waterIntensitySum += intensity;
          
          // Also track for backward compatibility
          bluePixels++;
          blueIntensity += intensity;
        }
        
        // Smoke detection using HSV (low saturation = grayish)
        if (HSVColorConverter.isSmokeColor(h, s, v)) {
          smokePixels++;
          smokeIntensitySum += s; // Lower saturation = more smoke-like
        }
        
        // Accident/Vehicle detection: Yellow/white (road markings, vehicles, signs)
        // Yellow in HSV: Hue 45-65, high saturation and value
        if ((h >= 45 && h <= 65) && s > 0.5 && v > 0.6) {
          yellowPixels++;
        }
        // Also check RGB for white/yellow
        if (r > 180 && g > 180 && b < 120 && luminance > 150) {
          yellowPixels++;
        }
        
        // Gray detection (using HSV: low saturation)
        if (s < 0.3 && v > 0.2 && v < 0.8) {
          grayPixels++;
        }
        
        // Bright emergency indicators (fire, explosions)
        if (HSVColorConverter.isBrightEmergency(v, s)) {
          brightPixels++;
        }
        
        // Dark emergency indicators (damage, debris, smoke)
        if (HSVColorConverter.isDarkEmergency(v, s)) {
          darkPixels++;
        }
      }
    }
    
    // Calculate average intensities
    final fireIntensity = firePixels > 0 ? fireIntensitySum / firePixels : 0.0;
    final waterIntensity = waterPixels > 0 ? waterIntensitySum / waterPixels : 0.0;
    final smokeIntensity = smokePixels > 0 ? smokeIntensitySum / smokePixels : 0.0;
    
    return {
      // HSV-based ratios (more accurate)
      'fire_ratio': firePixels / totalPixels,
      'water_ratio': waterPixels / totalPixels,
      'smoke_ratio': smokePixels / totalPixels,
      'fire_intensity': fireIntensity,
      'water_intensity': waterIntensity,
      'smoke_intensity': smokeIntensity,
      
      // RGB-based ratios (backward compatibility)
      'red_ratio': redPixels / totalPixels,
      'orange_ratio': orangePixels / totalPixels,
      'blue_ratio': bluePixels / totalPixels,
      'yellow_ratio': yellowPixels / totalPixels,
      'gray_ratio': grayPixels / totalPixels,
      'dark_ratio': darkPixels / totalPixels,
      'bright_ratio': brightPixels / totalPixels,
      'red_intensity': redPixels > 0 ? redIntensity / redPixels : 0.0,
      'orange_intensity': orangePixels > 0 ? orangeIntensity / orangePixels : 0.0,
      'blue_intensity': bluePixels > 0 ? blueIntensity / bluePixels : 0.0,
    };
  }
  
  /// Analyze texture patterns with enhanced algorithms
  Map<String, double> _analyzeTexture(img.Image image) {
    double variance = 0.0;
    double mean = 0.0;
    double contrast = 0.0;
    int pixelCount = 0;
    int highContrastPixels = 0;
    
    // Calculate mean and local contrast
    final List<List<double>> localContrasts = [];
    
    for (int y = 0; y < image.height; y++) {
      final List<double> row = [];
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final value = (pixel.r + pixel.g + pixel.b) / 3;
        mean += value;
        pixelCount++;
        row.add(value);
      }
      localContrasts.add(row);
    }
    mean /= pixelCount;
    
    // Calculate variance and contrast
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final value = localContrasts[y][x];
        variance += (value - mean) * (value - mean);
        
        // Local contrast (difference with neighbors)
        double localContrast = 0.0;
        int neighbors = 0;
        
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            final ny = y + dy;
            final nx = x + dx;
            if (ny >= 0 && ny < image.height && nx >= 0 && nx < image.width) {
              final neighborValue = localContrasts[ny][nx];
              localContrast += (value - neighborValue).abs();
              neighbors++;
            }
          }
        }
        
        if (neighbors > 0) {
          localContrast /= neighbors;
          contrast += localContrast;
          if (localContrast > 40) {
            highContrastPixels++;
          }
        }
      }
    }
    
    variance /= pixelCount;
    contrast /= pixelCount;
    
    return {
      'texture_variance': variance,
      'texture_mean': mean,
      'texture_contrast': contrast,
      'high_contrast_ratio': highContrastPixels / pixelCount,
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
  
  /// Analyze edge density with improved Sobel operator
  Map<String, double> _analyzeEdges(img.Image image) {
    int edgeCount = 0;
    int strongEdgeCount = 0;
    int totalPixels = 0;
    double totalEdgeStrength = 0.0;
    
    // Enhanced Sobel-like edge detection
    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        // Get 3x3 neighborhood
        final topLeft = image.getPixel(x - 1, y - 1);
        final top = image.getPixel(x, y - 1);
        final topRight = image.getPixel(x + 1, y - 1);
        final left = image.getPixel(x - 1, y);
        final center = image.getPixel(x, y);
        final right = image.getPixel(x + 1, y);
        final bottomLeft = image.getPixel(x - 1, y + 1);
        final bottom = image.getPixel(x, y + 1);
        final bottomRight = image.getPixel(x + 1, y + 1);
        
        // Convert to grayscale
        final getGray = (img.Pixel p) => (p.r + p.g + p.b) / 3;
        
        final gtl = getGray(topLeft);
        final gt = getGray(top);
        final gtr = getGray(topRight);
        final gl = getGray(left);
        final gc = getGray(center);
        final gr = getGray(right);
        final gbl = getGray(bottomLeft);
        final gb = getGray(bottom);
        final gbr = getGray(bottomRight);
        
        // Sobel operator: Gx and Gy
        final gx = (-1 * gtl + 0 * gt + 1 * gtr +
                    -2 * gl + 0 * gc + 2 * gr +
                    -1 * gbl + 0 * gb + 1 * gbr);
        
        final gy = (-1 * gtl - 2 * gt - 1 * gtr +
                     0 * gl + 0 * gc + 0 * gr +
                     1 * gbl + 2 * gb + 1 * gbr);
        
        // Edge magnitude
        final edgeMagnitude = (gx * gx + gy * gy).abs();
        totalEdgeStrength += edgeMagnitude;
        
        // Threshold for edge detection
        if (edgeMagnitude > 2500) { // ~50 pixel difference
          edgeCount++;
          if (edgeMagnitude > 10000) { // ~100 pixel difference - strong edge
            strongEdgeCount++;
          }
        }
        totalPixels++;
      }
    }
    
    return {
      'edge_density': edgeCount / totalPixels,
      'strong_edge_density': strongEdgeCount / totalPixels,
      'avg_edge_strength': totalEdgeStrength / totalPixels,
    };
  }
  
  /// Classify emergency type with improved multi-factor scoring
  EmergencyType _classifyEmergencyType(Map<String, double> analysis) {
    final redRatio = analysis['red_ratio'] ?? 0.0;
    final orangeRatio = analysis['orange_ratio'] ?? 0.0;
    final blueRatio = analysis['blue_ratio'] ?? 0.0;
    final grayRatio = analysis['gray_ratio'] ?? 0.0;
    final yellowRatio = analysis['yellow_ratio'] ?? 0.0;
    final darkRatio = analysis['dark_ratio'] ?? 0.0;
    final brightRatio = analysis['bright_ratio'] ?? 0.0;
    final redIntensity = analysis['red_intensity'] ?? 0.0;
    final orangeIntensity = analysis['orange_intensity'] ?? 0.0;
    final blueIntensity = analysis['blue_intensity'] ?? 0.0;
    final edgeDensity = analysis['edge_density'] ?? 0.0;
    final strongEdgeDensity = analysis['strong_edge_density'] ?? 0.0;
    final brightness = analysis['brightness'] ?? 0.0;
    final textureVariance = analysis['texture_variance'] ?? 0.0;
    final textureContrast = analysis['texture_contrast'] ?? 0.0;
    final highContrastRatio = analysis['high_contrast_ratio'] ?? 0.0;
    
    // Multi-factor scoring system
    final Map<EmergencyType, double> scores = {
      EmergencyType.fire: 0.0,
      EmergencyType.flood: 0.0,
      EmergencyType.earthquake: 0.0,
      EmergencyType.accident: 0.0,
      EmergencyType.calamity: 0.0,
      EmergencyType.general: 0.0,
    };
    
    // Fire scoring: IMPROVED with HSV-based detection + adaptive thresholds
    final fireRatio = analysis['fire_ratio'] ?? redRatio + orangeRatio; // Use HSV if available
    final fireIntensity = analysis['fire_intensity'] ?? (redIntensity + orangeIntensity) / 2;
    final fireThreshold = analysis['adaptive_fire_threshold'] ?? 0.08;
    final redHistPeak = analysis['red_histogram_peak'] ?? 0.0;
    final redHistStrength = analysis['red_histogram_peak_strength'] ?? 0.0;
    final multiScaleConsistency = analysis['multi_scale_consistency'] ?? 0.5;
    final smokeRatio = analysis['smoke_ratio'] ?? 0.0; // Smoke often accompanies fire
    
    // Only score fire if ratio exceeds adaptive threshold
    final effectiveFireRatio = math.max(0.0, fireRatio - fireThreshold);
    
    // Get ML intensity scores if available
    final mlFireIntensity = analysis['ml_fire_intensity'] ?? 0.0;
    final mlOverallIntensity = analysis['ml_overall_intensity'] ?? 0.0;
    
    // Enhanced fire scoring with HSV-based detection, adaptive thresholds, NEW patterns, and ML intensity
    final smokePattern = analysis['smoke_pattern'] ?? 0.0;
    final flamePattern = analysis['flame_pattern'] ?? 0.0;
    final baseFireScore = 
        (effectiveFireRatio * 4.0) * (1.0 + fireIntensity * 1.5) + // HSV-based (more accurate)
        ((redRatio + orangeRatio) * 2.0) * (1.0 + redIntensity + orangeIntensity) + // RGB fallback
        (smokeRatio * 1.5) + // Smoke is often present with fire
        smokePattern * 1.2 +  // Advanced smoke pattern detection
        flamePattern * 1.5 +   // Flame pattern detection
        (brightRatio * 2.0) +
        (brightness > 0.6 ? brightness * 1.5 : 0.0) +
        (textureVariance > 1500 ? 0.3 : 0.0) +
        (redHistPeak > 0.75 && redHistStrength > 0.1 ? 0.5 : 0.0) + // High red peak
        (multiScaleConsistency > 0.7 ? 0.3 : 0.0); // Consistent across scales
    
    // DYNAMIC: Calculate adaptive weights for ML/rule-based combination
    final mlWeights = _calculateDynamicMLWeights(analysis);
    final mlWeight = mlWeights['ml_weight']!;
    final ruleWeight = mlWeights['rule_weight']!;
    final typeMultiplier = mlWeights['type_multiplier']!;
    final overallMultiplier = mlWeights['overall_multiplier']!;
    
    // Combine rule-based score with ML intensity using dynamic weights
    final mlFireScore = (mlFireIntensity * typeMultiplier + mlOverallIntensity * overallMultiplier);
    scores[EmergencyType.fire] = baseFireScore * ruleWeight + mlFireScore * mlWeight;
    
    // Flood scoring: IMPROVED with HSV-based water detection + adaptive thresholds
    final waterRatio = analysis['water_ratio'] ?? blueRatio; // Use HSV if available
    final waterIntensity = analysis['water_intensity'] ?? blueIntensity;
    final waterThreshold = analysis['adaptive_water_threshold'] ?? 0.12;
    final blueHistPeak = analysis['blue_histogram_peak'] ?? 0.0;
    final blueHistStrength = analysis['blue_histogram_peak_strength'] ?? 0.0;
    
    // Only score flood if ratio exceeds adaptive threshold
    final effectiveWaterRatio = math.max(0.0, waterRatio - waterThreshold);
    
    // Get ML flood intensity if available
    final mlFloodIntensity = analysis['ml_flood_intensity'] ?? 0.0;
    
    // Enhanced flood scoring with HSV-based detection, adaptive thresholds, NEW patterns, and ML intensity
    final waterTexture = analysis['water_texture'] ?? 0.0;
    final reflectionPattern = analysis['reflection_pattern'] ?? 0.0;
    final baseFloodScore = 
        (effectiveWaterRatio * 4.5) * (1.0 + waterIntensity * 1.3) + // HSV-based (more accurate)
        (blueRatio * 3.0) * (1.0 + blueIntensity) + // RGB fallback
        waterTexture * 1.5 +      // Advanced water texture detection
        reflectionPattern * 1.2 + // Reflection pattern detection
        (brightness > 0.3 && brightness < 0.75 ? 1.0 : 0.0) +
        (textureContrast > 20 ? 0.4 : 0.0) +
        (darkRatio > 0.15 ? 0.3 : 0.0) +
        (blueHistPeak > 0.5 && blueHistStrength > 0.15 ? 0.5 : 0.0) + // High blue peak
        (multiScaleConsistency > 0.7 ? 0.3 : 0.0); // Consistent across scales
    
    // DYNAMIC: Use same adaptive weights (calculated once, reused for consistency)
    final mlFloodScore = (mlFloodIntensity * typeMultiplier + mlOverallIntensity * overallMultiplier);
    scores[EmergencyType.flood] = baseFloodScore * ruleWeight + mlFloodScore * mlWeight;
    
    // Earthquake scoring: IMPROVED with smoke/debris detection + adaptive thresholds
    final edgeThreshold = analysis['adaptive_edge_threshold'] ?? 0.10;
    
    // Only score earthquake if edge density exceeds adaptive threshold
    final effectiveEdgeDensity = math.max(0.0, edgeDensity - edgeThreshold);
    final effectiveStrongEdgeDensity = math.max(0.0, strongEdgeDensity - edgeThreshold * 0.7);
    
    // Get ML earthquake intensity if available
    final mlEarthquakeIntensity = analysis['ml_earthquake_intensity'] ?? 0.0;
    
    final structuralDamage = analysis['structural_damage'] ?? 0.0;
    final baseEarthquakeScore = 
        (effectiveEdgeDensity * 4.5 + effectiveStrongEdgeDensity * 7.0) + // Adaptive threshold
        (grayRatio * 2.5 + smokeRatio * 2.0) + // Smoke/debris often present
        (highContrastRatio * 3.0) +
        (textureVariance > 2500 ? 0.5 : 0.0) +
        (darkRatio > 0.2 ? 0.4 : 0.0) +
        structuralDamage * 2.0;  // Structural damage detection
    
    // DYNAMIC: Use same adaptive weights (calculated once, reused for consistency)
    final mlEarthquakeScore = (mlEarthquakeIntensity * typeMultiplier + mlOverallIntensity * overallMultiplier);
    scores[EmergencyType.earthquake] = baseEarthquakeScore * ruleWeight + mlEarthquakeScore * mlWeight;
    
    // Accident scoring: Yellow (road/vehicles) + edges + moderate indicators
    scores[EmergencyType.accident] = 
        (yellowRatio * 3.0) +
        (edgeDensity * 2.5) +
        (brightness > 0.4 && brightness < 0.8 ? 0.8 : 0.0) +
        (textureContrast > 15 ? 0.3 : 0.0);
    
    // Calamity scoring: STRICT - requires multiple strong indicators - FULLY DYNAMIC
    // Calamity is the most serious, so we need VERY strong evidence
    // Calculate dynamic thresholds based on image characteristics
    final dynamicFireIndicatorThreshold = 0.08 + (brightness * 0.04);
    final dynamicWaterIndicatorThreshold = 0.12 + (brightness * 0.05);
    final dynamicGrayIndicatorThreshold = 0.12 + (brightness * 0.05);
    final dynamicEdgeIndicatorThreshold = 0.10 + (textureVariance / 20000);
    final dynamicStrongEdgeIndicatorThreshold = 0.06 + (textureVariance / 25000);
    final dynamicTextureVarianceThreshold = 2500 + (textureVariance * 0.1);
    final dynamicBrightRatioThreshold = 0.12 + (brightness * 0.05);
    final dynamicDarkRatioThreshold = 0.20 + ((1.0 - brightness) * 0.08);
    final dynamicCalamityEdgeThreshold = 0.12 + (textureVariance / 18000);
    
    final hasMultipleIndicators = (redRatio > dynamicFireIndicatorThreshold || orangeRatio > dynamicFireIndicatorThreshold) &&
                                   (blueRatio > dynamicWaterIndicatorThreshold || grayRatio > dynamicGrayIndicatorThreshold) &&
                                   (edgeDensity > dynamicEdgeIndicatorThreshold || strongEdgeDensity > dynamicStrongEdgeIndicatorThreshold);
    
    scores[EmergencyType.calamity] = 
        (hasMultipleIndicators ? 1.5 : 0.0) + // Base requirement
        (textureVariance > dynamicTextureVarianceThreshold ? (textureVariance / 800) : 0.0) + // Dynamic threshold
        ((redRatio + blueRatio + grayRatio) * 2.5) + // Stronger weighting
        (highContrastRatio * 3.0) + // Higher contrast requirement
        (brightRatio > dynamicBrightRatioThreshold || darkRatio > dynamicDarkRatioThreshold ? 0.8 : 0.0) + // Dynamic thresholds
        (edgeDensity > dynamicCalamityEdgeThreshold ? 0.5 : 0.0); // Dynamic structural damage threshold
    
    // General emergency: Moderate indicators - FULLY DYNAMIC
    // Calculate dynamic thresholds
    final dynamicGeneralBrightnessMin = 0.25 + (brightness * 0.1);
    final dynamicGeneralBrightnessMax = 0.80 + (brightness * 0.1);
    final dynamicGeneralEdgeThreshold = 0.10 + (textureVariance / 20000);
    final dynamicGeneralTextureThreshold = 800 + (textureVariance * 0.1);
    
    scores[EmergencyType.general] = 
        (brightness < dynamicGeneralBrightnessMin || brightness > dynamicGeneralBrightnessMax ? 0.5 : 0.0) +
        (edgeDensity > dynamicGeneralEdgeThreshold ? 0.4 : 0.0) +
        (textureVariance > dynamicGeneralTextureThreshold ? 0.3 : 0.0);
    
    // No Emergency: Strong normal scene indicators
    // IMPROVED: More aggressive detection of normal scenes to always inform user
    final organizedPatterns = analysis['organized_patterns'] ?? 0.0;
    final normalSceneScore = analysis['normal_scene_likelihood'] ?? 0.0;
    
    // Calculate "No Emergency" score with better weighting
    double noEmergencyScore = 0.0;
    
    // Primary indicator: Normal scene likelihood (most important)
    noEmergencyScore += normalSceneScore * 3.0;
    
    // Organized patterns strongly indicate normal scenes
    noEmergencyScore += organizedPatterns * 2.0;
    
    // Get dynamic thresholds from adaptive calculation
    final adaptiveThresholds = _calculateAdaptiveThresholds(analysis);
    final dynamicRedThreshold = 0.04 + (brightness * 0.02);
    final dynamicOrangeThreshold = 0.04 + (brightness * 0.02);
    final dynamicBlueThreshold = 0.08 + (brightness * 0.04);
    final dynamicEdgeThreshold = 0.06 + (textureVariance / 20000);
    final dynamicBrightnessMin = 0.25 + (brightness * 0.1);
    final dynamicBrightnessMax = 0.65 + (brightness * 0.1);
    final dynamicTextureThreshold = 700 + (textureVariance * 0.1);
    final dynamicContrastThreshold = 12 + (textureContrast * 0.2);
    final dynamicFirePenaltyThreshold = 0.08 + (brightness * 0.04);
    final dynamicFloodPenaltyThreshold = 0.12 + (brightness * 0.05);
    final dynamicDamagePenaltyThreshold = 0.10 + (textureVariance / 15000);
    
    // No emergency colors (no fire, flood indicators) - DYNAMIC
    if (redRatio < dynamicRedThreshold && orangeRatio < dynamicOrangeThreshold && blueRatio < dynamicBlueThreshold) {
      noEmergencyScore += 1.5;
    }
    
    // Low edge density = no structural damage - DYNAMIC
    if (edgeDensity < dynamicEdgeThreshold) {
      noEmergencyScore += 1.2;
    }
    
    // Normal brightness range (not too dark, not too bright) - DYNAMIC
    if (brightness > dynamicBrightnessMin && brightness < dynamicBrightnessMax) {
      noEmergencyScore += 1.0;
    }
    
    // Low texture variance = organized, not chaotic - DYNAMIC
    if (textureVariance < dynamicTextureThreshold) {
      noEmergencyScore += 1.0;
    }
    
    // Low contrast = peaceful scene - DYNAMIC
    if (textureContrast < dynamicContrastThreshold) {
      noEmergencyScore += 0.8;
    }
    
    // Penalize if emergency indicators are present - DYNAMIC THRESHOLDS
    if (redRatio > dynamicFirePenaltyThreshold || orangeRatio > dynamicFirePenaltyThreshold) {
      noEmergencyScore *= 0.3; // Strong penalty for fire colors
    }
    if (blueRatio > dynamicFloodPenaltyThreshold) {
      noEmergencyScore *= 0.5; // Penalty for flood colors
    }
    if (edgeDensity > dynamicDamagePenaltyThreshold) {
      noEmergencyScore *= 0.4; // Penalty for structural damage
    }
    
    scores[EmergencyType.noEmergency] = noEmergencyScore;
    
    // Find highest scoring type
    EmergencyType bestType = EmergencyType.general;
    double bestScore = 0.0;
    
    scores.forEach((type, score) {
      if (score > bestScore) {
        bestScore = score;
        bestType = type;
      }
    });
    
    // Get dynamic thresholds from adaptive calculation (reuse from line 1373)
    final normalSceneThreshold = adaptiveThresholds['adaptive_normal_scene_threshold'] ?? 0.70;
    final organizedPatternThreshold = adaptiveThresholds['adaptive_organized_pattern_threshold'] ?? 0.25;
    
    // Calculate dynamic thresholds for "no emergency" detection
    final dynamicHighNoEmergencyThreshold = 1.8 + (normalSceneScore * 0.3);
    final dynamicMediumNoEmergencyThreshold = 1.3 + (normalSceneScore * 0.2);
    final dynamicLowEmergencyThreshold = 0.7 + (normalSceneScore * 0.1);
    final dynamicNormalSceneCheck = normalSceneThreshold * 0.9;
    final dynamicOrganizedCheck = organizedPatternThreshold;
    
    // DYNAMIC: Always report "No Emergency" if score is high enough
    // This ensures users are informed when scenes are clearly safe
    if (bestType == EmergencyType.noEmergency && bestScore >= dynamicHighNoEmergencyThreshold) {
      // Clear "no emergency" signal - always return it to inform user
      return EmergencyType.noEmergency;
    }
    
    // If no emergency scores highest but is close to threshold, still report it - DYNAMIC
    if (bestType == EmergencyType.noEmergency && bestScore >= dynamicMediumNoEmergencyThreshold) {
      // Moderate "no emergency" signal - still report it
      return EmergencyType.noEmergency;
    }
    
    // If all emergency types score very low AND normal scene indicators are strong - DYNAMIC
    if (bestScore < dynamicLowEmergencyThreshold && normalSceneScore > dynamicNormalSceneCheck) {
      // Low emergency scores + strong normal indicators = no emergency
      return EmergencyType.noEmergency;
    }
    
    // Minimum threshold to avoid false positives for emergencies - DYNAMIC
    final dynamicMinThreshold = 0.4 + (normalSceneScore * 0.2);
    if (bestScore < dynamicMinThreshold) {
      // Very low scores - check if we can confidently say "no emergency" - DYNAMIC
      if (normalSceneScore > dynamicNormalSceneCheck || organizedPatterns > dynamicOrganizedCheck) {
        return EmergencyType.noEmergency;
      }
      // Ambiguous case - use general as fallback but with low confidence
      return EmergencyType.general;
    }
    
    return bestType;
  }
  
  /// Determine severity level with enhanced multi-dimensional scoring
  SeverityLevel _determineSeverity(Map<String, double> analysis, EmergencyType type) {
    final brightness = analysis['brightness'] ?? 0.5;
    final edgeDensity = analysis['edge_density'] ?? 0.0;
    final strongEdgeDensity = analysis['strong_edge_density'] ?? 0.0;
    final redRatio = analysis['red_ratio'] ?? 0.0;
    final orangeRatio = analysis['orange_ratio'] ?? 0.0;
    final blueRatio = analysis['blue_ratio'] ?? 0.0;
    final grayRatio = analysis['gray_ratio'] ?? 0.0;
    final darkRatio = analysis['dark_ratio'] ?? 0.0;
    final brightRatio = analysis['bright_ratio'] ?? 0.0;
    final redIntensity = analysis['red_intensity'] ?? 0.0;
    final orangeIntensity = analysis['orange_intensity'] ?? 0.0;
    final blueIntensity = analysis['blue_intensity'] ?? 0.0;
    final textureVariance = analysis['texture_variance'] ?? 0.0;
    final textureContrast = analysis['texture_contrast'] ?? 0.0;
    final highContrastRatio = analysis['high_contrast_ratio'] ?? 0.0;
    
    // NEW: Advanced pattern indicators
    final smokePattern = analysis['smoke_pattern'] ?? 0.0;
    final waterTexture = analysis['water_texture'] ?? 0.0;
    final structuralDamage = analysis['structural_damage'] ?? 0.0;
    final flamePattern = analysis['flame_pattern'] ?? 0.0;
    final reflectionPattern = analysis['reflection_pattern'] ?? 0.0;
    
    // Multi-dimensional severity assessment
    double visualIntensity = 0.0;
    double spatialExtent = 0.0;
    double temporalProgression = 0.0; // Estimated from visual intensity
    double contextRisk = 0.0;
    
    // NEW: Get ML intensity scores if available
    final mlOverallIntensity = analysis['ml_overall_intensity'] ?? 0.0;
    final mlFireIntensity = analysis['ml_fire_intensity'] ?? 0.0;
    final mlFloodIntensity = analysis['ml_flood_intensity'] ?? 0.0;
    final mlEarthquakeIntensity = analysis['ml_earthquake_intensity'] ?? 0.0;
    
    // DYNAMIC: Calculate adaptive weights for severity assessment
    final severityWeights = _calculateDynamicSeverityWeights(analysis);
    final visualMLWeight = severityWeights['visual_ml_weight']!;
    final visualRuleWeight = severityWeights['visual_rule_weight']!;
    final spatialMLWeight = severityWeights['spatial_ml_weight']!;
    final spatialRuleWeight = severityWeights['spatial_rule_weight']!;
    final temporalMLWeight = severityWeights['temporal_ml_weight']!;
    final temporalRuleWeight = severityWeights['temporal_rule_weight']!;
    final boostMultiplier = _calculateDynamicMLWeights(analysis)['boost_multiplier']!;
    
    // Fire severity: Enhanced with smoke, flame patterns, and ML intensity
    if (type == EmergencyType.fire) {
      // Visual Intensity (35% weight) - Enhanced with ML intensity
      final baseVisualIntensity = 
          (redRatio + orangeRatio) * 2.5 * (1.0 + redIntensity + orangeIntensity) +
          brightness * 0.8 +
          brightRatio * 1.5 +
          (textureVariance > 2000 ? 0.4 : 0.0) +
          smokePattern * 1.2 +  // Smoke detection
          flamePattern * 1.5;     // Flame detection
      
      // DYNAMIC: Combine rule-based with ML intensity using adaptive weights
      final mlBoost = (mlFireIntensity > 0 ? mlFireIntensity * boostMultiplier : 0.0) + 
                     (mlOverallIntensity > 0 ? mlOverallIntensity * (boostMultiplier * 0.4) : 0.0);
      visualIntensity = ((baseVisualIntensity * visualRuleWeight) + (mlBoost * visualMLWeight)).clamp(0.0, 2.0) * 0.35;
      
      // Spatial Extent (25% weight) - DYNAMIC: enhanced with ML if available
      final baseSpatialExtent = ((redRatio + orangeRatio) * 2.0).clamp(0.0, 1.0);
      spatialExtent = (baseSpatialExtent * spatialRuleWeight + (mlOverallIntensity * spatialMLWeight)).clamp(0.0, 1.0) * 0.25;
      
      // Temporal Progression (20% weight) - DYNAMIC: enhanced with ML intensity
      final baseTemporal = (baseVisualIntensity * 1.2).clamp(0.0, 1.0);
      temporalProgression = (baseTemporal * temporalRuleWeight + (mlOverallIntensity * temporalMLWeight)).clamp(0.0, 1.0) * 0.20;
      
      // Context Risk (20% weight)
      contextRisk = (brightness > 0.7 ? 0.3 : 0.0) * 0.20;
    }
    // Flood severity: Enhanced with water texture, reflections, and ML intensity
    else if (type == EmergencyType.flood) {
      // Visual Intensity (35% weight) - Enhanced with ML intensity
      final baseVisualIntensity = 
          (blueRatio * 3.5 * (1.0 + blueIntensity)) +
          ((1 - brightness) * 0.8) +
          (darkRatio * 1.2) +
          (textureContrast > 25 ? 0.5 : 0.0) +
          waterTexture * 1.5 +        // Water texture
          reflectionPattern * 1.2;     // Reflection patterns
      
      // DYNAMIC: Combine rule-based with ML intensity using adaptive weights
      final mlBoost = (mlFloodIntensity > 0 ? mlFloodIntensity * boostMultiplier : 0.0) + 
                     (mlOverallIntensity > 0 ? mlOverallIntensity * (boostMultiplier * 0.4) : 0.0);
      visualIntensity = ((baseVisualIntensity * visualRuleWeight) + (mlBoost * visualMLWeight)).clamp(0.0, 2.0) * 0.35;
      
      // Spatial Extent (25% weight) - DYNAMIC: enhanced with ML
      final baseSpatialExtent = (blueRatio * 2.5).clamp(0.0, 1.0);
      spatialExtent = (baseSpatialExtent * spatialRuleWeight + (mlOverallIntensity * spatialMLWeight)).clamp(0.0, 1.0) * 0.25;
      
      // Temporal Progression (20% weight) - DYNAMIC: enhanced with ML
      final baseTemporal = (waterTexture * 1.3).clamp(0.0, 1.0);
      temporalProgression = (baseTemporal * temporalRuleWeight + (mlOverallIntensity * temporalMLWeight)).clamp(0.0, 1.0) * 0.20;
      
      // Context Risk (20% weight) - bottom-heavy = more likely flood
      contextRisk = (blueRatio > 0.3 ? 0.4 : 0.0) * 0.20;
    }
    // Earthquake severity: Enhanced with structural damage patterns and ML intensity
    else if (type == EmergencyType.earthquake) {
      // Visual Intensity (35% weight) - Enhanced with ML intensity
      final baseVisualIntensity = 
          (edgeDensity * 4.0 + strongEdgeDensity * 7.0) +
          (grayRatio * 2.0) +
          (textureVariance / 800) +
          (highContrastRatio * 3.5) +
          (darkRatio * 1.5) +
          structuralDamage * 2.0;  // Structural damage
      
      // DYNAMIC: Combine rule-based with ML intensity using adaptive weights
      final mlBoost = (mlEarthquakeIntensity > 0 ? mlEarthquakeIntensity * boostMultiplier : 0.0) + 
                     (mlOverallIntensity > 0 ? mlOverallIntensity * (boostMultiplier * 0.4) : 0.0);
      visualIntensity = ((baseVisualIntensity * visualRuleWeight) + (mlBoost * visualMLWeight)).clamp(0.0, 2.0) * 0.35;
      
      // Spatial Extent (25% weight) - DYNAMIC: enhanced with ML
      final baseSpatialExtent = (edgeDensity * 3.0).clamp(0.0, 1.0);
      spatialExtent = (baseSpatialExtent * spatialRuleWeight + (mlOverallIntensity * spatialMLWeight)).clamp(0.0, 1.0) * 0.25;
      
      // Temporal Progression (20% weight) - DYNAMIC: enhanced with ML
      final baseTemporal = (structuralDamage * 1.5).clamp(0.0, 1.0);
      temporalProgression = (baseTemporal * temporalRuleWeight + (mlOverallIntensity * temporalMLWeight)).clamp(0.0, 1.0) * 0.20;
      
      // Context Risk (20% weight)
      contextRisk = (edgeDensity > 0.15 ? 0.3 : 0.0) * 0.20;
    }
    // Accident severity: Impact indicators
    else if (type == EmergencyType.accident) {
      visualIntensity = 
          ((edgeDensity * 3.5 + strongEdgeDensity * 5.0) * 0.35) +
          ((1 - brightness) * 0.6 * 0.35) +
          (highContrastRatio * 2.5 * 0.35) +
          ((textureVariance > 1500 ? 0.4 : 0.0) * 0.35) +
          structuralDamage * 1.5 * 0.35;  // NEW: Damage indicators
      
      spatialExtent = (edgeDensity * 2.5).clamp(0.0, 1.0) * 0.25;
      temporalProgression = (edgeDensity * 1.2).clamp(0.0, 1.0) * 0.20;
      contextRisk = (highContrastRatio > 0.15 ? 0.3 : 0.0) * 0.20;
    }
    // Calamity severity: Overall chaos level
    else if (type == EmergencyType.calamity) {
      visualIntensity = 
          ((textureVariance / 600) * 0.35) +
          ((edgeDensity * 2.5) * 0.35) +
          (((redRatio + blueRatio + grayRatio) * 1.8) * 0.35) +
          ((highContrastRatio * 2.0) * 0.35) +
          (((brightRatio + darkRatio) * 1.5) * 0.35);
      
      spatialExtent = ((redRatio + blueRatio + grayRatio) * 1.5).clamp(0.0, 1.0) * 0.25;
      temporalProgression = (textureVariance / 1000).clamp(0.0, 1.0) * 0.20;
      contextRisk = (textureVariance > 2000 ? 0.4 : 0.0) * 0.20;
    }
    // General severity: ALWAYS LOW
    else {
      return SeverityLevel.low;
    }
    
    // Combined severity score (multi-dimensional)
    final combinedScore = visualIntensity + spatialExtent + temporalProgression + contextRisk;
    
    // Normalize and map to severity levels
    // Clamp to reasonable range
    final normalizedScore = combinedScore.clamp(0.0, 2.0);
    
    // Get dynamic severity thresholds (no static values)
    final severityThresholds = _calculateDynamicSeverityThresholds(analysis);
    final criticalThreshold = severityThresholds['critical_threshold'] ?? 1.5;
    final highThreshold = severityThresholds['high_threshold'] ?? 1.0;
    final mediumThreshold = severityThresholds['medium_threshold'] ?? 0.6;
    
    // Map to levels with dynamic thresholds
    if (normalizedScore >= criticalThreshold) {
      return SeverityLevel.critical;
    } else if (normalizedScore >= highThreshold) {
      return SeverityLevel.high;
    } else if (normalizedScore >= mediumThreshold) {
      return SeverityLevel.medium;
    } else {
      return SeverityLevel.low;
    }
  }
  
  /// Calculate confidence score with improved multi-factor analysis
  double _calculateConfidence(Map<String, double> analysis, EmergencyType type) {
    double confidence = 0.4; // Base confidence (lower to be more conservative)
    
    final redRatio = analysis['red_ratio'] ?? 0.0;
    final orangeRatio = analysis['orange_ratio'] ?? 0.0;
    final blueRatio = analysis['blue_ratio'] ?? 0.0;
    final grayRatio = analysis['gray_ratio'] ?? 0.0;
    final edgeDensity = analysis['edge_density'] ?? 0.0;
    final strongEdgeDensity = analysis['strong_edge_density'] ?? 0.0;
    final textureVariance = analysis['texture_variance'] ?? 0.0;
    final textureContrast = analysis['texture_contrast'] ?? 0.0;
    final highContrastRatio = analysis['high_contrast_ratio'] ?? 0.0;
    final redIntensity = analysis['red_intensity'] ?? 0.0;
    final orangeIntensity = analysis['orange_intensity'] ?? 0.0;
    final blueIntensity = analysis['blue_intensity'] ?? 0.0;
    
    // Multi-factor confidence calculation
    switch (type) {
      case EmergencyType.fire:
        final smokePattern = analysis['smoke_pattern'] ?? 0.0;
        final flamePattern = analysis['flame_pattern'] ?? 0.0;
        confidence = 0.4 + 
            (redRatio + orangeRatio) * 1.8 * (1.0 + (redIntensity + orangeIntensity) * 0.5) +
            (textureVariance > 1500 ? 0.15 : 0.0) +
            (highContrastRatio > 0.1 ? 0.1 : 0.0) +
            smokePattern * 0.12 +  // NEW: Smoke pattern boost
            flamePattern * 0.15;     // NEW: Flame pattern boost
        break;
      case EmergencyType.flood:
        final waterTexture = analysis['water_texture'] ?? 0.0;
        final reflectionPattern = analysis['reflection_pattern'] ?? 0.0;
        confidence = 0.4 + 
            blueRatio * 2.2 * (1.0 + blueIntensity * 0.5) +
            (textureContrast > 20 ? 0.15 : 0.0) +
            (grayRatio > 0.1 ? 0.1 : 0.0) +
            waterTexture * 0.12 +      // NEW: Water texture boost
            reflectionPattern * 0.10;  // NEW: Reflection pattern boost
        break;
      case EmergencyType.earthquake:
        final structuralDamage = analysis['structural_damage'] ?? 0.0;
        confidence = 0.4 + 
            (edgeDensity * 1.8 + strongEdgeDensity * 2.5) +
            grayRatio * 1.2 +
            (textureVariance > 2000 ? 0.2 : 0.0) +
            (highContrastRatio > 0.15 ? 0.15 : 0.0) +
            structuralDamage * 0.15;  // NEW: Structural damage boost
        break;
      case EmergencyType.accident:
        confidence = 0.4 + 
            (edgeDensity * 1.5 + strongEdgeDensity * 2.0) +
            (textureContrast > 15 ? 0.15 : 0.0) +
            (highContrastRatio > 0.1 ? 0.1 : 0.0);
        break;
      case EmergencyType.calamity:
        confidence = 0.4 + 
            (textureVariance / 2500) +
            ((redRatio + blueRatio + grayRatio) * 1.5) +
            (highContrastRatio * 1.8) +
            (edgeDensity > 0.1 ? 0.15 : 0.0);
        break;
      case EmergencyType.general:
        confidence = 0.4 + 
            edgeDensity * 1.2 +
            (textureVariance > 1000 ? 0.15 : 0.0) +
            (highContrastRatio * 0.8);
        break;
      case EmergencyType.noEmergency:
        // High confidence in "no emergency" - based on normal scene indicators
        final normalSceneLikelihood = analysis['normal_scene_likelihood'] ?? 0.5;
        confidence = 0.75 + (normalSceneLikelihood * 0.2); // Boost confidence based on normal scene score
        break;
    }
    
    // Clamp to [0.35, 0.98] range (slightly higher max for very clear cases)
    if (confidence < 0.35) confidence = 0.35;
    if (confidence > 0.98) confidence = 0.98;
    
    return confidence;
  }
  
  /// Calculate confidence interval (lower and upper bounds)
  /// More conservative approach - uses lower bound for decisions
  Map<String, double> _calculateConfidenceInterval(double baseConfidence, Map<String, double> fullAnalysis) {
    // Calculate uncertainty based on analysis quality
    final normalSceneLikelihood = fullAnalysis['normal_scene_likelihood'] ?? 0.5;
    final organizedPatterns = fullAnalysis['organized_patterns'] ?? 0.0;
    final falsePositiveRisk = fullAnalysis['false_positive_risk'] ?? 0.0;
    
    // Higher uncertainty if normal scene indicators are present
    double uncertainty = 0.05; // Base uncertainty (5%)
    
    if (normalSceneLikelihood > 0.6) {
      uncertainty += 0.10; // Add 10% uncertainty
    }
    if (organizedPatterns > 0.3) {
      uncertainty += 0.08; // Add 8% uncertainty
    }
    if (falsePositiveRisk > 0.4) {
      uncertainty += 0.12; // Add 12% uncertainty
    }
    
    // Clamp uncertainty to reasonable range
    uncertainty = uncertainty.clamp(0.05, 0.20); // 5-20% uncertainty
    
    final lowerBound = (baseConfidence - uncertainty).clamp(0.0, 1.0);
    final upperBound = (baseConfidence + uncertainty).clamp(0.0, 1.0);
    
    return {
      'lower': lowerBound,
      'upper': upperBound,
    };
  }
  
  /// Calculate dynamic weights for ML/rule-based combination
  /// Adapts based on image characteristics and ML output quality
  Map<String, double> _calculateDynamicMLWeights(Map<String, double> analysis) {
    final brightness = analysis['brightness'] ?? 0.5;
    final contrast = analysis['overall_contrast'] ?? 0.5;
    final textureVariance = analysis['texture_variance'] ?? 0.0;
    final mlOverallIntensity = analysis['ml_overall_intensity'] ?? 0.0;
    final mlIntensityVariance = analysis['intensity_variance'] ?? 0.0;
    
    // Calculate ML confidence based on output quality
    // Lower variance = higher confidence in ML
    // Also consider if ML actually provided meaningful output
    final hasMLOutput = mlOverallIntensity > 0.01; // ML provided meaningful output
    final mlConfidence = hasMLOutput && mlIntensityVariance > 0 
        ? (1.0 - (mlIntensityVariance.clamp(0.0, 0.5) * 2.0)).clamp(0.3, 0.9)
        : hasMLOutput 
            ? 0.6 // ML provided output but no variance (single value) - moderate confidence
            : 0.3; // No ML output or very low - low confidence, rely more on rules
    
    // Calculate rule-based confidence based on image quality
    // High contrast, good brightness range = higher confidence
    final ruleBasedConfidence = (contrast * 0.4 + 
                                (brightness > 0.2 && brightness < 0.8 ? 0.3 : 0.1) +
                                (textureVariance > 1000 && textureVariance < 5000 ? 0.3 : 0.1)).clamp(0.3, 0.9);
    
    // Dynamic ML weight: Higher when ML confidence is high and rule-based is uncertain
    // Base weight adapts to image characteristics
    final baseMLWeight = 0.2 + (mlConfidence * 0.2) - (ruleBasedConfidence * 0.1);
    final dynamicMLWeight = baseMLWeight.clamp(0.15, 0.45);
    final dynamicRuleWeight = 1.0 - dynamicMLWeight;
    
    // Dynamic ML multipliers: Adapt based on image characteristics
    // Higher multipliers for clearer images, lower for ambiguous
    final imageClarity = (contrast * 0.5 + (brightness > 0.3 && brightness < 0.7 ? 0.3 : 0.1) + 
                         (textureVariance > 500 && textureVariance < 4000 ? 0.2 : 0.0)).clamp(0.3, 1.0);
    
    final dynamicTypeMultiplier = 2.0 + (imageClarity * 1.0); // 2.0-3.0 range
    final dynamicOverallMultiplier = 0.8 + (imageClarity * 0.5); // 0.8-1.3 range
    final dynamicBoostMultiplier = 1.2 + (imageClarity * 0.6); // 1.2-1.8 range
    
    return {
      'ml_weight': dynamicMLWeight,
      'rule_weight': dynamicRuleWeight,
      'type_multiplier': dynamicTypeMultiplier,
      'overall_multiplier': dynamicOverallMultiplier,
      'boost_multiplier': dynamicBoostMultiplier,
      'ml_confidence': mlConfidence,
      'rule_confidence': ruleBasedConfidence,
    };
  }
  
  /// Calculate dynamic weights for severity assessment
  /// Adapts based on image characteristics and available data
  Map<String, double> _calculateDynamicSeverityWeights(Map<String, double> analysis) {
    final brightness = analysis['brightness'] ?? 0.5;
    final contrast = analysis['overall_contrast'] ?? 0.5;
    final mlOverallIntensity = analysis['ml_overall_intensity'] ?? 0.0;
    final mlIntensityVariance = analysis['intensity_variance'] ?? 0.0;
    
    // Calculate ML reliability for severity assessment
    final mlReliability = mlOverallIntensity > 0 
        ? (1.0 - (mlIntensityVariance.clamp(0.0, 0.5) * 1.5)).clamp(0.2, 0.8)
        : 0.0; // No ML if intensity is 0
    
    // Visual intensity weights: Adapt based on image quality
    final imageQuality = (contrast * 0.5 + (brightness > 0.25 && brightness < 0.75 ? 0.3 : 0.1) + 
                         (mlReliability * 0.2)).clamp(0.3, 1.0);
    
    // Dynamic visual intensity ML weight: Higher when ML is reliable
    final visualMLWeight = (0.2 + (mlReliability * 0.15)).clamp(0.15, 0.4);
    final visualRuleWeight = 1.0 - visualMLWeight;
    
    // Spatial extent weights: ML helps when available
    final spatialMLWeight = mlReliability > 0.3 ? (0.15 + (mlReliability * 0.1)).clamp(0.1, 0.3) : 0.0;
    final spatialRuleWeight = 1.0 - spatialMLWeight;
    
    // Temporal progression weights: ML helps estimate progression
    final temporalMLWeight = mlReliability > 0.3 ? (0.2 + (mlReliability * 0.15)).clamp(0.15, 0.4) : 0.0;
    final temporalRuleWeight = 1.0 - temporalMLWeight;
    
    return {
      'visual_ml_weight': visualMLWeight,
      'visual_rule_weight': visualRuleWeight,
      'spatial_ml_weight': spatialMLWeight,
      'spatial_rule_weight': spatialRuleWeight,
      'temporal_ml_weight': temporalMLWeight,
      'temporal_rule_weight': temporalRuleWeight,
      'ml_reliability': mlReliability,
    };
  }
  
  /// Calculate fully dynamic adaptive thresholds based on image characteristics
  /// All thresholds are calculated dynamically - no static values
  Map<String, double> _calculateAdaptiveThresholds(Map<String, double> analysis) {
    final brightness = analysis['brightness'] ?? 0.5;
    final contrast = analysis['overall_contrast'] ?? 0.5;
    final textureVariance = analysis['texture_variance'] ?? 0.0;
    final edgeDensity = analysis['edge_density'] ?? 0.0;
    final redRatio = analysis['red_ratio'] ?? 0.0;
    final blueRatio = analysis['blue_ratio'] ?? 0.0;
    final orangeRatio = analysis['orange_ratio'] ?? 0.0;
    
    // Dynamic base threshold calculation (no static values)
    // Base threshold adapts to image characteristics
    final dynamicBase = (brightness * 0.3 + contrast * 0.3 + (textureVariance / 5000).clamp(0.0, 0.4));
    
    // Fire threshold: Dynamic based on image brightness and contrast
    // Dark images need lower threshold, bright images need higher
    final fireThreshold = dynamicBase * 0.8 + 
                         (brightness < 0.3 ? 0.05 : brightness > 0.7 ? 0.12 : 0.08) +
                         (contrast < 0.3 ? 0.02 : contrast > 0.7 ? 0.05 : 0.03);
    
    // Water threshold: Dynamic based on brightness and blue presence
    final waterThreshold = dynamicBase * 0.9 +
                          (brightness < 0.4 ? 0.08 : brightness > 0.6 ? 0.15 : 0.12) +
                          (blueRatio > 0.1 ? 0.03 : 0.0);
    
    // Edge threshold: Dynamic based on texture variance and contrast
    final edgeThreshold = dynamicBase * 0.7 +
                         (textureVariance < 1000 ? 0.08 : textureVariance > 3000 ? 0.15 : 0.10) +
                         (contrast < 0.4 ? 0.05 : 0.08);
    
    // Normal scene threshold: Dynamic based on image characteristics
    final normalSceneThreshold = (brightness * 0.2 + contrast * 0.2 + (1.0 - edgeDensity) * 0.3).clamp(0.5, 0.85);
    
    // Organized pattern threshold: Dynamic based on texture variance
    final organizedPatternThreshold = (textureVariance / 4000).clamp(0.15, 0.35);
    
    // False positive risk threshold: Dynamic based on multiple factors
    final falsePositiveThreshold = ((1.0 - brightness) * 0.2 + (1.0 - contrast) * 0.2 + edgeDensity * 0.3).clamp(0.3, 0.6);
    
    // Return all dynamic thresholds (no static values)
    return {
      'adaptive_fire_threshold': fireThreshold.clamp(0.05, 0.20),
      'adaptive_water_threshold': waterThreshold.clamp(0.08, 0.25),
      'adaptive_edge_threshold': edgeThreshold.clamp(0.05, 0.20),
      'adaptive_normal_scene_threshold': normalSceneThreshold,
      'adaptive_organized_pattern_threshold': organizedPatternThreshold,
      'adaptive_false_positive_threshold': falsePositiveThreshold,
    };
  }
  
  /// Calculate dynamic confidence threshold based on image characteristics
  /// No static values - all thresholds adapt to image
  double _calculateDynamicConfidenceThreshold(Map<String, double> analysis, EmergencyType type) {
    final brightness = analysis['brightness'] ?? 0.5;
    final contrast = analysis['overall_contrast'] ?? 0.5;
    final textureVariance = analysis['texture_variance'] ?? 0.0;
    final normalSceneLikelihood = analysis['normal_scene_likelihood'] ?? 0.5;
    
    // Base confidence threshold (dynamic, calculated from image characteristics)
    double baseThreshold = 0.60 + (brightness * 0.1) + (contrast * 0.1);
    
    // Adjust based on image quality (dynamic)
    baseThreshold += (brightness < 0.3 || brightness > 0.8 ? 0.05 : 0.0);
    baseThreshold += (contrast < 0.3 ? 0.05 : 0.0);
    baseThreshold += (textureVariance > 3000 ? 0.03 : 0.0);
    baseThreshold += (normalSceneLikelihood > 0.6 ? 0.08 : 0.0);
    
    // Type-specific adjustments (dynamic based on type)
    switch (type) {
      case EmergencyType.calamity:
        baseThreshold += 0.10;
        break;
      case EmergencyType.fire:
      case EmergencyType.earthquake:
        baseThreshold += 0.05;
        break;
      default:
        break;
    }
    
    return baseThreshold.clamp(0.60, 0.90);
  }
  
  /// Calculate dynamic severity thresholds based on image characteristics
  Map<String, double> _calculateDynamicSeverityThresholds(Map<String, double> analysis) {
    final brightness = analysis['brightness'] ?? 0.5;
    final contrast = analysis['overall_contrast'] ?? 0.5;
    final textureVariance = analysis['texture_variance'] ?? 0.0;
    
    // Dynamic severity thresholds (calculated from image, no static values)
    final criticalThreshold = 1.3 + (brightness * 0.2) + (contrast * 0.1) + (textureVariance / 10000);
    final highThreshold = 0.9 + (brightness * 0.15) + (contrast * 0.08) + (textureVariance / 12000);
    final mediumThreshold = 0.5 + (brightness * 0.1) + (contrast * 0.05) + (textureVariance / 15000);
    
    return {
      'critical_threshold': criticalThreshold.clamp(1.2, 1.8),
      'high_threshold': highThreshold.clamp(0.8, 1.3),
      'medium_threshold': mediumThreshold.clamp(0.5, 0.9),
    };
  }
  
  /// Calculate variance of a list of numbers
  double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance = values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / values.length;
    return variance;
  }
  
  /// Detect smoke patterns (gray/white wispy patterns, low contrast)
  /// Fully dynamic - no static thresholds
  double _detectSmokePatterns(img.Image image) {
    int smokePixels = 0;
    int totalPixels = 0;
    
    // Calculate image brightness for dynamic thresholds
    double totalBrightness = 0.0;
    int brightnessSamples = 0;
    for (int y = 0; y < image.height; y += 10) {
      for (int x = 0; x < image.width; x += 10) {
        final pixel = image.getPixel(x, y);
        totalBrightness += (pixel.r + pixel.g + pixel.b) / 3;
        brightnessSamples++;
      }
    }
    final avgBrightness = brightnessSamples > 0 ? totalBrightness / brightnessSamples : 128.0;
    final normalizedBrightness = avgBrightness / 255.0;
    
    // Sample pixels for performance
    for (int y = 0; y < image.height; y += 3) {
      for (int x = 0; x < image.width; x += 3) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;
        
        // Smoke characteristics: gray/white, low saturation, wispy
        final gray = (r + g + b) / 3;
        final maxColor = math.max(math.max(r, g), b);
        final minColor = math.min(math.min(r, g), b);
        final saturation = maxColor > 0 ? (maxColor - minColor) / maxColor : 0.0;
        
        // Dynamic thresholds based on image brightness (no static values)
        final dynamicGrayMin = 80 + (normalizedBrightness * 40);
        final dynamicGrayMax = 200 + (normalizedBrightness * 30);
        final dynamicSaturationMax = 0.25 + (normalizedBrightness * 0.1);
        
        if (gray > dynamicGrayMin && gray < dynamicGrayMax && saturation < dynamicSaturationMax) {
          smokePixels++;
        }
        totalPixels++;
      }
    }
    
    return totalPixels > 0 ? (smokePixels / totalPixels).clamp(0.0, 1.0) : 0.0;
  }
  
  /// Detect water texture (smooth, reflective surfaces, blue/cyan)
  double _detectWaterTexture(img.Image image) {
    int waterPixels = 0;
    int totalPixels = 0;
    
    // Sample pixels for performance
    for (int y = 0; y < image.height; y += 3) {
      for (int x = 0; x < image.width; x += 3) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;
        
        // Water characteristics: blue/cyan dominant, smooth texture
        final blueRatio = b / (r + g + b + 1);
        final cyanRatio = (g + b) / (r + g + b + 1);
        
        // Calculate average brightness for dynamic thresholds
        final pixelBrightness = (r + g + b) / 3;
        final normalizedBrightness = pixelBrightness / 255.0;
        
        // Dynamic thresholds based on image characteristics (no static values)
        final dynamicBlueThreshold = 0.30 + (normalizedBrightness * 0.1);
        final dynamicCyanThreshold = 0.45 + (normalizedBrightness * 0.1);
        
        // Check for water-like colors (blue/cyan) and smoothness
        if (blueRatio > dynamicBlueThreshold || cyanRatio > dynamicCyanThreshold) {
          // Check local smoothness (low variance in 3x3 area)
          if (x > 1 && y > 1 && x < image.width - 1 && y < image.height - 1) {
            final neighbors = [
              image.getPixel(x - 1, y - 1),
              image.getPixel(x, y - 1),
              image.getPixel(x + 1, y - 1),
              image.getPixel(x - 1, y),
              image.getPixel(x + 1, y),
              image.getPixel(x - 1, y + 1),
              image.getPixel(x, y + 1),
              image.getPixel(x + 1, y + 1),
            ];
            
            final centerGray = (r + g + b) / 3;
            double variance = 0.0;
            for (final n in neighbors) {
              final nGray = (n.r + n.g + n.b) / 3;
              variance += (nGray - centerGray) * (nGray - centerGray);
            }
            variance /= neighbors.length;
            
            // Water is smooth (low variance) - dynamic threshold
            final dynamicVarianceThreshold = 150 + (normalizedBrightness * 100); // Adapts to brightness
            if (variance < dynamicVarianceThreshold) {
              waterPixels++;
            }
          } else {
            waterPixels++;
          }
        }
        totalPixels++;
      }
    }
    
    return totalPixels > 0 ? (waterPixels / totalPixels).clamp(0.0, 1.0) : 0.0;
  }
  
  /// Detect structural damage (cracks, debris, irregular patterns)
  double _detectStructuralDamage(img.Image image) {
    int damagePixels = 0;
    int totalPixels = 0;
    
    // Sample pixels for performance
    for (int y = 2; y < image.height - 2; y += 4) {
      for (int x = 2; x < image.width - 2; x += 4) {
        final center = image.getPixel(x, y);
        final top = image.getPixel(x, y - 1);
        final bottom = image.getPixel(x, y + 1);
        final left = image.getPixel(x - 1, y);
        final right = image.getPixel(x + 1, y);
        
        final centerGray = (center.r + center.g + center.b) / 3;
        final topGray = (top.r + top.g + top.b) / 3;
        final bottomGray = (bottom.r + bottom.g + bottom.b) / 3;
        final leftGray = (left.r + left.g + left.b) / 3;
        final rightGray = (right.r + right.g + right.b) / 3;
        
        // Structural damage: high contrast edges, irregular patterns
        final verticalEdge = (topGray - bottomGray).abs();
        final horizontalEdge = (leftGray - rightGray).abs();
        final edgeStrength = (verticalEdge + horizontalEdge) / 2;
        
        // Damage indicators: strong edges (cracks), gray/dark colors (debris)
        // Calculate dynamic thresholds from image characteristics
        final avgEdgeStrength = (verticalEdge + horizontalEdge) / 2;
        final dynamicEdgeThreshold = 30 + (avgEdgeStrength / 10); // Adapts to image texture
        final dynamicGrayThreshold = 120 + (centerGray / 5); // Adapts to brightness
        
        if (edgeStrength > dynamicEdgeThreshold && centerGray < dynamicGrayThreshold) {
          damagePixels++;
        }
        totalPixels++;
      }
    }
    
    return totalPixels > 0 ? (damagePixels / totalPixels).clamp(0.0, 1.0) : 0.0;
  }
  
  /// Detect flame patterns (bright orange/red, upward-tending shapes)
  double _detectFlamePatterns(img.Image image) {
    int flamePixels = 0;
    int totalPixels = 0;
    
    // Sample pixels for performance
    for (int y = 1; y < image.height - 1; y += 3) {
      for (int x = 1; x < image.width - 1; x += 3) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r;
        final g = pixel.g;
        final b = pixel.b;
        
        // Flame characteristics: bright orange/red, high intensity
        final redRatio = r / (r + g + b + 1);
        final orangeRatio = (r + g) / (r + g + b + 1);
        final brightness = (r + g + b) / 3;
        
        // Flame: bright, red/orange dominant - dynamic thresholds
        // Calculate average brightness for dynamic thresholds
        final avgBrightness = (r + g + b) / 3;
        final normalizedBrightness = avgBrightness / 255.0;
        final dynamicRedThreshold = 0.35 + (normalizedBrightness * 0.1);
        final dynamicOrangeThreshold = 0.45 + (normalizedBrightness * 0.1);
        final dynamicBrightnessThreshold = 130 + (normalizedBrightness * 30);
        
        if ((redRatio > dynamicRedThreshold || orangeRatio > dynamicOrangeThreshold) && 
            brightness > dynamicBrightnessThreshold) {
          flamePixels++;
        }
        totalPixels++;
      }
    }
    
    return totalPixels > 0 ? (flamePixels / totalPixels).clamp(0.0, 1.0) : 0.0;
  }
  
  /// Detect reflection patterns (water reflections, mirror-like surfaces)
  double _detectReflectionPatterns(img.Image image) {
    int reflectionPixels = 0;
    int totalPixels = 0;
    
    // Sample pixels for performance
    for (int y = 1; y < image.height - 1; y += 4) {
      for (int x = 1; x < image.width - 1; x += 4) {
        final pixel = image.getPixel(x, y);
        final top = image.getPixel(x, y - 1);
        final bottom = image.getPixel(x, y + 1);
        
        final pixelGray = (pixel.r + pixel.g + pixel.b) / 3;
        final topGray = (top.r + top.g + top.b) / 3;
        final bottomGray = (bottom.r + bottom.g + bottom.b) / 3;
        
        // Reflection: symmetric patterns (top and bottom similar)
        final symmetry = 1.0 - ((topGray - bottomGray).abs() / 255.0);
        
        // Water reflections: moderate brightness, high symmetry - fully dynamic thresholds
        // Calculate average brightness for dynamic thresholds
        final avgBrightness = (pixel.r + pixel.g + pixel.b) / 3;
        final normalizedBrightness = avgBrightness / 255.0;
        final dynamicSymmetryThreshold = 0.65 + (normalizedBrightness * 0.1);
        final dynamicGrayMin = 70 + (normalizedBrightness * 20);
        final dynamicGrayMax = 190 + (normalizedBrightness * 20);
        
        if (symmetry > dynamicSymmetryThreshold && 
            pixelGray > dynamicGrayMin && pixelGray < dynamicGrayMax) {
          reflectionPixels++;
        }
        totalPixels++;
      }
    }
    
    return totalPixels > 0 ? (reflectionPixels / totalPixels).clamp(0.0, 1.0) : 0.0;
  }
  
  /// Calculate spatial extent (how much of image is affected)
  double _calculateSpatialExtent(Map<String, double> regionAnalysis, EmergencyType type) {
    // Get active regions from region analysis
    double activeRegions = 0.0;
    
    switch (type) {
      case EmergencyType.fire:
        activeRegions = (regionAnalysis['red_ratio_active_regions'] ?? 0.0) +
                       (regionAnalysis['orange_ratio_active_regions'] ?? 0.0);
        break;
      case EmergencyType.flood:
        activeRegions = regionAnalysis['blue_ratio_active_regions'] ?? 0.0;
        break;
      case EmergencyType.earthquake:
        activeRegions = regionAnalysis['edge_density_active_regions'] ?? 0.0;
        break;
      default:
        activeRegions = 0.5; // Default moderate extent
    }
    
    // Normalize to 0-1 range (active regions is already 0-1)
    return activeRegions.clamp(0.0, 1.0);
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

