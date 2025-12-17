
/// Utility for converting RGB to HSV color space
/// HSV is better for emergency detection (especially fire/flood)
class HSVColorConverter {
  /// Convert RGB to HSV
  /// Returns Map with 'h' (0-360), 's' (0-1), 'v' (0-1)
  static Map<String, double> rgbToHsv(double r, double g, double b) {
    // Normalize RGB to 0-1
    r /= 255.0;
    g /= 255.0;
    b /= 255.0;

    final max = r > g ? (r > b ? r : b) : (g > b ? g : b);
    final min = r < g ? (r < b ? r : b) : (g < b ? g : b);
    final delta = max - min;

    double h = 0.0;
    double s = 0.0;
    final v = max;

    if (delta != 0.0) {
      s = delta / max;

      if (max == r) {
        h = ((g - b) / delta) % 6;
      } else if (max == g) {
        h = (b - r) / delta + 2;
      } else {
        h = (r - g) / delta + 4;
      }
      h *= 60.0;
      if (h < 0) h += 360.0;
    }

    return {'h': h, 's': s, 'v': v};
  }

  /// Check if color is in fire range (red/orange/yellow in HSV)
  /// Fire colors: Hue 0-60 (red-orange-yellow), high saturation, high value
  static bool isFireColor(double h, double s, double v) {
    // Red: 0-30, Orange: 15-45, Yellow: 30-60
    final inFireHue = (h >= 0 && h <= 60) || (h >= 330 && h <= 360); // Wraps around red
    final hasHighSaturation = s > 0.5; // Bright, saturated colors
    final hasHighValue = v > 0.4; // Not too dark
    return inFireHue && hasHighSaturation && hasHighValue;
  }

  /// Check if color is in flood/water range (blue/cyan in HSV)
  /// Water colors: Hue 180-240 (cyan-blue), moderate-high saturation, variable value
  static bool isWaterColor(double h, double s, double v) {
    // Cyan: 150-210, Blue: 210-270
    final inWaterHue = h >= 150 && h <= 270;
    final hasModerateSaturation = s > 0.3; // Blue can be more muted
    final hasReasonableValue = v > 0.2 && v < 0.9; // Not pure black/white
    return inWaterHue && hasModerateSaturation && hasReasonableValue;
  }

  /// Check if color is in smoke/gray range (low saturation in HSV)
  /// Smoke: Low saturation (grayish), medium value
  static bool isSmokeColor(double h, double s, double v) {
    final lowSaturation = s < 0.3; // Grayish
    final mediumValue = v > 0.3 && v < 0.8; // Not pure black/white
    return lowSaturation && mediumValue;
  }

  /// Get fire intensity score (0-1) based on HSV
  /// Higher score = more intense fire colors
  static double getFireIntensity(double h, double s, double v) {
    if (!isFireColor(h, s, v)) return 0.0;
    
    // Red (0-30) is most intense
    double hueScore = 1.0;
    if (h > 30 && h <= 60) {
      hueScore = 0.8; // Orange-yellow
    } else if (h >= 330 || h <= 15) {
      hueScore = 0.9; // Pure red
    }
    
    // Combine saturation and value for intensity
    final intensity = hueScore * s * v;
    return intensity.clamp(0.0, 1.0);
  }

  /// Get water/flood intensity score (0-1) based on HSV
  static double getWaterIntensity(double h, double s, double v) {
    if (!isWaterColor(h, s, v)) return 0.0;
    
    // Deep blue (210-240) indicates deeper water
    double hueScore = 0.7;
    if (h >= 210 && h <= 240) {
      hueScore = 1.0; // Deep blue
    } else if (h >= 150 && h < 210) {
      hueScore = 0.8; // Cyan-blue
    }
    
    final intensity = hueScore * s * v;
    return intensity.clamp(0.0, 1.0);
  }

  /// Check if pixel represents bright emergency indicator (fire, explosion)
  static bool isBrightEmergency(double v, double s) {
    return v > 0.85 && s > 0.4; // Very bright and saturated
  }

  /// Check if pixel represents dark emergency indicator (damage, debris, smoke)
  static bool isDarkEmergency(double v, double s) {
    return v < 0.3 && s < 0.4; // Very dark, low saturation (gray/black)
  }
}

