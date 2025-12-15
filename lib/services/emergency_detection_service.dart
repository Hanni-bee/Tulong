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
  /// Uses multi-pass analysis with false positive prevention
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
      
    // PASS 1: Full image analysis
    final fullAnalysis = _analyzeImage(image);
    
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
    
    // IMPROVED: More aggressive normal scene detection to reduce false positives
    // Check if this is clearly a normal scene with no emergency
    bool isNormalScene = false;
    
    // Primary check: High normal scene likelihood
    if (normalSceneLikelihood > 0.75) { // Lowered from 0.80
      isNormalScene = true;
    }
    // Secondary check: Organized patterns + low emergency indicators
    else if (organizedPatterns > 0.35 && // Increased from 0.3
             normalSceneLikelihood > 0.65 && // Lowered from 0.70
             falsePositiveRisk > 0.4) {
      isNormalScene = true;
    }
    // Tertiary check: Low confidence + moderate normal scene
    else if (confidence < 0.55 && // Lowered from 0.5
             normalSceneLikelihood > 0.68 && // Lowered from 0.70
             organizedPatterns > 0.25) {
      isNormalScene = true;
    }
    // Quaternary check: General type with low confidence and normal indicators
    else if (detectedType == EmergencyType.general && 
             confidence < 0.55 && // Lowered from 0.5
             normalSceneLikelihood > 0.62 && // Lowered from 0.65
             organizedPatterns > 0.2) {
      isNormalScene = true;
    }
    
    if (isNormalScene) {
      // High confidence that this is a normal scene - reassure user
      final noEmergencyConfidence = (1.0 - normalSceneLikelihood).clamp(0.75, 0.95); // Higher base confidence
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
      // Low confidence - likely not an emergency, but not certain enough to say "no emergency"
      // Check if we can confidently say "no emergency"
      if (normalSceneLikelihood > 0.75) {
        return EmergencyDetectionResult(
          type: EmergencyType.noEmergency,
          severity: SeverityLevel.low,
          confidence: 0.75,
          timestamp: DateTime.now(),
          imagePath: originalImagePath,
        );
      }
      // Ambiguous - use general as fallback
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
        if (value > 0.05) activeRegions++; // Threshold for "active" region
      }
      
      aggregated['${metric}_mean'] = sum / regionCount;
      aggregated['${metric}_max'] = maxVal;
      aggregated['${metric}_min'] = minVal;
      aggregated['${metric}_spread'] = maxVal - minVal;
      aggregated['${metric}_active_regions'] = activeRegions / regionCount;
    }
    
    return aggregated;
  }
  
  /// Validate context to prevent false positives - ENHANCED
  Map<String, double> _validateContext(img.Image image, Map<String, double> analysis) {
    final validation = <String, double>{};
    
    // Check if image looks like normal indoor/outdoor scene
    final brightness = analysis['brightness'] ?? 0.5;
    final edgeDensity = analysis['edge_density'] ?? 0.0;
    final textureVariance = analysis['texture_variance'] ?? 0.0;
    final redRatio = analysis['red_ratio'] ?? 0.0;
    final orangeRatio = analysis['orange_ratio'] ?? 0.0;
    final blueRatio = analysis['blue_ratio'] ?? 0.0;
    final overallContrast = analysis['overall_contrast'] ?? 0.5;
    
    // Normal scene indicators - STRICT CHECKS
    double normalScore = 1.0;
    int normalIndicators = 0;
    int totalChecks = 0;
    
    // Check 1: Moderate brightness (normal indoor/outdoor)
    totalChecks++;
    if (brightness > 0.25 && brightness < 0.75) {
      normalIndicators++;
    }
    
    // Check 2: Low edge density (no structural damage)
    totalChecks++;
    if (edgeDensity < 0.10) {
      normalIndicators++;
    }
    
    // Check 3: Low texture variance (organized, not chaotic)
    totalChecks++;
    if (textureVariance < 1200) {
      normalIndicators++;
    }
    
    // Check 4: Low emergency color ratios (no fire/flood indicators)
    totalChecks++;
    if (redRatio < 0.08 && orangeRatio < 0.08 && blueRatio < 0.15) {
      normalIndicators++;
    }
    
    // Check 5: Moderate contrast (not extreme)
    totalChecks++;
    if (overallContrast > 0.2 && overallContrast < 0.8) {
      normalIndicators++;
    }
    
    // Check 6: Organized patterns (windows, walls, structures)
    final organizedPatterns = _detectOrganizedPatterns(image);
    totalChecks++;
    if (organizedPatterns > 0.25) {
      normalIndicators++;
      normalScore *= 0.6; // Strong penalty for organized patterns
    }
    
    // Check 7: Image stability (not blurry, not chaotic)
    final imageStability = analysis['image_stability'] ?? 0.5;
    totalChecks++;
    if (imageStability > 0.4) {
      normalIndicators++;
    }
    
    // Calculate normal score based on indicators
    final indicatorRatio = normalIndicators / totalChecks;
    normalScore = indicatorRatio;
    
    // STRICT: If most indicators suggest normal scene, heavily penalize
    if (indicatorRatio > 0.6) {
      normalScore = 0.3; // Very high normal scene likelihood
    }
    
    // EXTRA CHECK: If organized patterns AND low emergency indicators → Very likely normal
    if (organizedPatterns > 0.3 && 
        redRatio < 0.1 && 
        orangeRatio < 0.1 && 
        blueRatio < 0.15 && 
        edgeDensity < 0.12) {
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
    
    // STRICT minimum confidence threshold - prevent false alarms
    if (finalType != EmergencyType.general) {
      // Higher threshold for calamity (most serious, most prone to false positives)
      if (finalType == EmergencyType.calamity && confidence < 0.80) {
        finalType = EmergencyType.general;
        confidence = 0.4;
      }
      // High threshold for other emergencies
      else if (confidence < 0.70) {
        finalType = EmergencyType.general;
        confidence = 0.4; // Lower confidence for ambiguous cases
      }
    }
    
    // FINAL SAFETY CHECK: If normal scene likelihood is very high, force general
    if (normalSceneLikelihood > 0.70) { // Lowered threshold from 0.75
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
      
      // If confidence is borderline, reduce severity
      if (confidence < 0.75 && severity == SeverityLevel.critical) {
        severity = SeverityLevel.high;
      }
      if (confidence < 0.70 && severity == SeverityLevel.high) {
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
  
  /// Analyze color distribution in image with improved algorithms
  Map<String, double> _analyzeColors(img.Image image) {
    int redPixels = 0;
    int orangePixels = 0;
    int bluePixels = 0;
    int yellowPixels = 0;
    int grayPixels = 0;
    int darkPixels = 0;
    int brightPixels = 0;
    int totalPixels = image.width * image.height;
    
    // Color intensity accumulators for better detection
    double redIntensity = 0.0;
    double orangeIntensity = 0.0;
    double blueIntensity = 0.0;
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();
        
        // Calculate luminance
        final luminance = (0.299 * r + 0.587 * g + 0.114 * b);
        
        // Fire detection: Enhanced red/orange with intensity scoring
        // Bright red flames
        if (r > 180 && r > g * 1.5 && r > b * 1.5 && luminance > 100) {
          redPixels++;
          redIntensity += (r / 255.0);
        }
        // Orange/yellow flames
        else if (r > 150 && g > 80 && g < r * 1.2 && b < g * 0.8 && luminance > 120) {
          orangePixels++;
          orangeIntensity += ((r + g) / 2 / 255.0);
        }
        
        // Flood/Water detection: Enhanced blue/cyan with depth perception
        // Deep water (darker blue)
        if (b > 120 && b > r * 1.3 && b > g * 1.1 && luminance < 180) {
          bluePixels++;
          blueIntensity += (b / 255.0);
        }
        // Shallow/flooded water (lighter cyan)
        else if (b > 100 && g > 100 && b > r * 1.2 && luminance > 100 && luminance < 220) {
          bluePixels++;
          blueIntensity += ((b + g) / 2 / 255.0);
        }
        
        // Accident/Vehicle detection: Yellow/white (road markings, vehicles, signs)
        if (r > 180 && g > 180 && b < 120 && luminance > 150) {
          yellowPixels++;
        }
        
        // Smoke/Debris detection: Enhanced gray detection
        final grayValue = (r + g + b) / 3;
        final colorVariance = ((r - grayValue).abs() + (g - grayValue).abs() + (b - grayValue).abs()) / 3;
        if (grayValue > 60 && grayValue < 220 && colorVariance < 25) {
          grayPixels++;
        }
        
        // Dark areas (damage, shadows, debris)
        if (luminance < 50) {
          darkPixels++;
        }
        
        // Very bright areas (fire, explosions, intense light)
        if (luminance > 220) {
          brightPixels++;
        }
      }
    }
    
    return {
      'red_ratio': redPixels / totalPixels,
      'orange_ratio': orangePixels / totalPixels,
      'blue_ratio': bluePixels / totalPixels,
      'yellow_ratio': yellowPixels / totalPixels,
      'gray_ratio': grayPixels / totalPixels,
      'dark_ratio': darkPixels / totalPixels,
      'bright_ratio': brightPixels / totalPixels,
      'red_intensity': redIntensity / (redPixels > 0 ? redPixels : 1),
      'orange_intensity': orangeIntensity / (orangePixels > 0 ? orangePixels : 1),
      'blue_intensity': blueIntensity / (bluePixels > 0 ? bluePixels : 1),
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
    
    // Fire scoring: Red/orange intensity + brightness + texture + histogram
    final redHistPeak = analysis['red_histogram_peak'] ?? 0.0;
    final redHistStrength = analysis['red_histogram_peak_strength'] ?? 0.0;
    final multiScaleConsistency = analysis['multi_scale_consistency'] ?? 0.5;
    
    scores[EmergencyType.fire] = 
        (redRatio * 3.0 + orangeRatio * 2.5) * (1.0 + redIntensity + orangeIntensity) +
        (brightRatio * 2.0) +
        (brightness > 0.6 ? brightness * 1.5 : 0.0) +
        (textureVariance > 1500 ? 0.3 : 0.0) +
        (redHistPeak > 0.75 && redHistStrength > 0.1 ? 0.5 : 0.0) + // High red peak
        (multiScaleConsistency > 0.7 ? 0.3 : 0.0); // Consistent across scales
    
    // Flood scoring: Blue intensity + moderate brightness + texture + histogram
    final blueHistPeak = analysis['blue_histogram_peak'] ?? 0.0;
    final blueHistStrength = analysis['blue_histogram_peak_strength'] ?? 0.0;
    
    scores[EmergencyType.flood] = 
        (blueRatio * 3.5) * (1.0 + blueIntensity) +
        (brightness > 0.3 && brightness < 0.75 ? 1.0 : 0.0) +
        (textureContrast > 20 ? 0.4 : 0.0) +
        (darkRatio > 0.15 ? 0.3 : 0.0) +
        (blueHistPeak > 0.5 && blueHistStrength > 0.15 ? 0.5 : 0.0) + // High blue peak
        (multiScaleConsistency > 0.7 ? 0.3 : 0.0); // Consistent across scales
    
    // Earthquake scoring: Edge density + debris (gray) + high contrast
    scores[EmergencyType.earthquake] = 
        (edgeDensity * 4.0 + strongEdgeDensity * 6.0) +
        (grayRatio * 2.5) +
        (highContrastRatio * 3.0) +
        (textureVariance > 2500 ? 0.5 : 0.0) +
        (darkRatio > 0.2 ? 0.4 : 0.0);
    
    // Accident scoring: Yellow (road/vehicles) + edges + moderate indicators
    scores[EmergencyType.accident] = 
        (yellowRatio * 3.0) +
        (edgeDensity * 2.5) +
        (brightness > 0.4 && brightness < 0.8 ? 0.8 : 0.0) +
        (textureContrast > 15 ? 0.3 : 0.0);
    
    // Calamity scoring: STRICT - requires multiple strong indicators
    // Calamity is the most serious, so we need VERY strong evidence
    final hasMultipleIndicators = (redRatio > 0.1 || orangeRatio > 0.1) &&
                                   (blueRatio > 0.15 || grayRatio > 0.15) &&
                                   (edgeDensity > 0.12 || strongEdgeDensity > 0.08);
    
    scores[EmergencyType.calamity] = 
        (hasMultipleIndicators ? 1.5 : 0.0) + // Base requirement
        (textureVariance > 3000 ? (textureVariance / 800) : 0.0) + // Higher threshold
        ((redRatio + blueRatio + grayRatio) * 2.5) + // Stronger weighting
        (highContrastRatio * 3.0) + // Higher contrast requirement
        (brightRatio > 0.15 || darkRatio > 0.25 ? 0.8 : 0.0) + // More extreme
        (edgeDensity > 0.15 ? 0.5 : 0.0); // Structural damage required
    
    // General emergency: Moderate indicators
    scores[EmergencyType.general] = 
        (brightness < 0.3 || brightness > 0.85 ? 0.5 : 0.0) +
        (edgeDensity > 0.12 ? 0.4 : 0.0) +
        (textureVariance > 1000 ? 0.3 : 0.0);
    
    // No Emergency: Strong normal scene indicators
    // High score = very likely normal scene
    final organizedPatterns = analysis['organized_patterns'] ?? 0.0;
    final normalSceneScore = analysis['normal_scene_likelihood'] ?? 0.0;
    
    scores[EmergencyType.noEmergency] = 
        (normalSceneScore * 2.0) + // Primary indicator
        (organizedPatterns * 1.5) + // Organized = normal
        (redRatio < 0.05 && orangeRatio < 0.05 && blueRatio < 0.1 ? 1.0 : 0.0) + // No emergency colors
        (edgeDensity < 0.08 ? 0.8 : 0.0) + // Low edge density = normal
        (brightness > 0.3 && brightness < 0.7 ? 0.6 : 0.0) + // Normal brightness
        (textureVariance < 800 ? 0.5 : 0.0); // Low texture variance = normal
    
    // Find highest scoring type
    EmergencyType bestType = EmergencyType.general;
    double bestScore = 0.0;
    
    scores.forEach((type, score) {
      if (score > bestScore) {
        bestScore = score;
        bestType = type;
      }
    });
    
    // Special handling for "No Emergency"
    if (bestType == EmergencyType.noEmergency && bestScore > 2.5) {
      // Strong "no emergency" signal - return it
      return EmergencyType.noEmergency;
    }
    
    // Minimum threshold to avoid false positives
    if (bestScore < 0.5) {
      // Very low scores - likely no emergency
      if (normalSceneScore > 0.7) {
        return EmergencyType.noEmergency;
      }
      return EmergencyType.general;
    }
    
    // Don't return "no emergency" if other types scored higher
    if (bestType == EmergencyType.noEmergency && bestScore < 3.0) {
      // Weak "no emergency" - use general as fallback
      return EmergencyType.general;
    }
    
    return bestType;
  }
  
  /// Determine severity level with enhanced scoring
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
    
    double severityScore = 0.0;
    
    // Fire severity: Intensity-based scoring
    if (type == EmergencyType.fire) {
      severityScore = 
          (redRatio + orangeRatio) * 2.5 * (1.0 + redIntensity + orangeIntensity) +
          brightness * 0.8 +
          brightRatio * 1.5 +
          (textureVariance > 2000 ? 0.4 : 0.0);
    }
    // Flood severity: Depth and coverage
    else if (type == EmergencyType.flood) {
      severityScore = 
          blueRatio * 3.5 * (1.0 + blueIntensity) +
          (1 - brightness) * 0.8 +
          darkRatio * 1.2 +
          (textureContrast > 25 ? 0.5 : 0.0);
    }
    // Earthquake severity: Structural damage indicators
    else if (type == EmergencyType.earthquake) {
      severityScore = 
          (edgeDensity * 4.0 + strongEdgeDensity * 7.0) +
          grayRatio * 2.0 +
          (textureVariance / 800) +
          highContrastRatio * 3.5 +
          darkRatio * 1.5;
    }
    // Accident severity: Impact indicators
    else if (type == EmergencyType.accident) {
      severityScore = 
          (edgeDensity * 3.5 + strongEdgeDensity * 5.0) +
          (1 - brightness) * 0.6 +
          highContrastRatio * 2.5 +
          (textureVariance > 1500 ? 0.4 : 0.0);
    }
    // Calamity severity: Overall chaos level
    else if (type == EmergencyType.calamity) {
      severityScore = 
          (textureVariance / 600) +
          (edgeDensity * 2.5) +
          ((redRatio + blueRatio + grayRatio) * 1.8) +
          highContrastRatio * 2.0 +
          (brightRatio + darkRatio) * 1.5;
    }
    // General severity: ALWAYS LOW (General is a safe fallback, not a real emergency)
    else {
      // General emergencies should NEVER be Critical/High/Medium
      // They are fallbacks for ambiguous cases - always Low severity
      return SeverityLevel.low;
    }
    
    // Normalize and map to severity levels
    // Clamp to reasonable range
    if (severityScore > 2.0) severityScore = 2.0;
    
    // Map to levels with better thresholds
    if (severityScore >= 1.5) {
      return SeverityLevel.critical;
    } else if (severityScore >= 1.0) {
      return SeverityLevel.high;
    } else if (severityScore >= 0.6) {
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
        confidence = 0.4 + 
            (redRatio + orangeRatio) * 1.8 * (1.0 + (redIntensity + orangeIntensity) * 0.5) +
            (textureVariance > 1500 ? 0.15 : 0.0) +
            (highContrastRatio > 0.1 ? 0.1 : 0.0);
        break;
      case EmergencyType.flood:
        confidence = 0.4 + 
            blueRatio * 2.2 * (1.0 + blueIntensity * 0.5) +
            (textureContrast > 20 ? 0.15 : 0.0) +
            (grayRatio > 0.1 ? 0.1 : 0.0);
        break;
      case EmergencyType.earthquake:
        confidence = 0.4 + 
            (edgeDensity * 1.8 + strongEdgeDensity * 2.5) +
            grayRatio * 1.2 +
            (textureVariance > 2000 ? 0.2 : 0.0) +
            (highContrastRatio > 0.15 ? 0.15 : 0.0);
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

