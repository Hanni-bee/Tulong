/// Central configuration for AI disaster detection pipeline.
/// Tune thresholds and labels here for consistent, reliable detection.
///
/// Tuning guide:
/// - Lower thresholds / relax overrides = catch more real disasters, risk more false positives.
/// - Higher thresholds / stricter overrides = fewer false positives, risk missing some real disasters.
class AIDetectionConfig {
  AIDetectionConfig._();

  // ─── Model labels (order must match model output indices) ───
  /// Class mapping: 0=Cyclone, 1=Earthquake, 2=Flood, 3=Wildfire (PyImageSearch)
  static const List<String> modelLabels = [
    'Cyclone',
    'Earthquake',
    'Flood',
    'Wildfire',
  ];

  /// Number of classes the model outputs
  static const int numClasses = 4;

  // ─── Confidence thresholds ───
  /// Minimum confidence to report a disaster (below this → "No Emergency")
  static const double minConfidenceToReport = 0.58;

  /// Minimum gap between top-1 and top-2 probability (avoids uncertain ties)
  /// e.g. 0.22 means top class must lead by at least 22% to be accepted
  static const double minProbabilityGap = 0.22;

  /// Maximum entropy (uncertainty) allowed; above this → "No Emergency"
  /// Lower = stricter. ln(4)≈1.39 = uniform over 4 classes.
  static const double maxEntropyForReport = 0.82;

  /// Wildfire requires higher confidence to reduce false positives
  static const double minConfidenceForWildfire = 0.68;
  /// Flood: require higher confidence to reduce false positives on blue-ish normal photos
  static const double minConfidenceForFlood = 0.62;
  /// Cyclone / Earthquake: require minimum confidence (normal scenes often get these by mistake)
  static const double minConfidenceForCycloneOrEarthquake = 0.60;

  /// Default confidence shown when we report "No Emergency" (for UI)
  static const double defaultNoEmergencyConfidence = 0.725;

  // ─── Wildfire sanity checks (reject solid red / dark / uniform; allow real fire) ───
  /// Red ratio above this = likely solid red block; still allow if R variance is high (real fire has variation).
  static const double maxRedRatioForWildfire = 0.90;
  /// When red ratio > this, allow wildfire only if R variance >= minRedVarianceToAllowHighRedRatio (real-world fire).
  static const double redRatioThresholdForVarianceCheck = 0.78;
  /// R variance >= this with high red ratio → treat as real fire (flames have variation), not solid red.
  static const double minRedVarianceToAllowHighRedRatio = 0.012;
  /// Mean brightness below this (0–1) = too dark → reject (retain dark/semi-dark as no disaster).
  static const double minBrightnessForWildfire = 0.16;
  /// Variance of R channel below this = uniform/solid red, not fire → reject (0–1 scale).
  static const double minRedVarianceForWildfire = 0.004;
  /// When wildfire confidence >= this, skip color check and trust model (real fire at 99% should not be overridden).
  static const double minConfidenceToSkipWildfireColorCheck = 0.93;

  // ─── Input validation ───
  /// Minimum image dimension (width or height) to run detection
  static const int minImageDimension = 32;

  /// Maximum image file size (bytes) to attempt decode (~10 MB)
  static const int maxImageFileSizeBytes = 10 * 1024 * 1024;

  /// Model input size (must match converted TFLite: best_model uses 180x180)
  static const int modelInputHeight = 180;
  static const int modelInputWidth = 180;
  static const int modelInputChannels = 3;
  /// Expected input size for model (180x180x3 = 97200)
  static const int expectedInputPixels = modelInputHeight * modelInputWidth * modelInputChannels;

  // ─── Model loading ───
  static const int modelLoadTimeoutSeconds = 90;
  static const int inferenceTimeoutSeconds = 30;
  /// Number of load attempts (1 = no retry)
  static const int modelLoadMaxAttempts = 3;
  /// Delay between load retries (ms)
  static const int modelLoadRetryDelayMs = 800;
  /// Run a warm-up inference after load (validates model + 4D input path).
  static const bool warmupInferenceAfterLoad = true;

  // ─── Preprocessing enhancements ───
  /// Apply EXIF orientation so photos from camera are upright (recommended: true)
  static const bool applyExifOrientation = true;
  /// Output BGR instead of RGB (set true if model was trained with OpenCV/BGR)
  static const bool useBGR = false;
  /// If true, apply ImageNet mean subtraction (BGR order: [103.939, 116.779, 123.68]). Use when Python used tf.keras.applications.* preprocess_input.
  static const bool useImageNetNormalization = false;
  /// Minimum contrast (std of luminance) to run inference; 0 = disabled. Rejects very dark/flat images.
  static const double minContrastForInference = 0.02;
  /// Mean brightness below this (0–1) → "Appears to be dark", no inference, No Emergency (no dataset needed).
  static const double minBrightnessToRunInference = 0.14;

  // ─── Post-processing enhancements (all offline, no network) ───
  // All detection logic is offline; no network required.
  /// Temperature for confidence: 1.0 = no change; >1 = softer probs; <1 = sharper. Applied after softmax.
  static const double temperatureScale = 1.0;
  /// Test-time augmentation: run on original + horizontally flipped image, average probabilities. More stable, ~2x inference time.
  static const bool enableTTA = true;
  /// When model says Wildfire, require image to have some red/orange presence (reduces false fire in blue/green scenes).
  static const bool enableWildfireColorCheck = true;
  /// Minimum mean-R ratio (R / (R+G+B)) to accept wildfire; below this → No Emergency. Typical fire ~0.35–0.5.
  static const double minRedRatioForWildfire = 0.32;

  // ─── Normal-scene gate (reduce false positives on ordinary photos) ───
  /// When image has "balanced" colors (no strong single channel), require this confidence to report ANY disaster.
  static const bool enableNormalSceneCheck = true;
  /// If no channel contributes more than this fraction of R+G+B, colors are "balanced" (likely normal scene).
  static const double maxDominantChannelForBalanced = 0.52;
  /// When balanced, minimum confidence to still report a disaster (otherwise → No Emergency).
  static const double minConfidenceForBalancedScene = 0.65;

  // ─── Normal-scene OVERRIDE (overrides model even at 90%+ confidence) ───
  /// When image strongly looks like a normal photo, force No Emergency regardless of model output.
  static const bool enableForceNoEmergencyForNormalScene = true;
  /// For override: no channel may dominate more than this (stricter than balanced gate).
  static const double maxDominantChannelForNormalOverride = 0.50;
  /// For override: mean brightness must be in this range (typical indoor/outdoor photo).
  static const double minBrightnessForNormalOverride = 0.28;
  static const double maxBrightnessForNormalOverride = 0.88;
  /// For override: luminance variance must be at least this (reject solid/flat single color).
  static const double minLuminanceVarianceForNormalOverride = 0.012;
  /// For override: luminance variance above this = very chaotic, don't treat as "normal" (optional cap).
  static const double maxLuminanceVarianceForNormalOverride = 0.38;

  // ─── Flood sanity checks (real-world: allow real flood with variation; reject solid blue / dark) ───
  static const bool enableFloodColorCheck = true;
  /// Minimum blue ratio (B/(R+G+B)) to accept flood; below = no water evidence → No Emergency.
  static const double minBlueRatioForFlood = 0.28;
  /// Blue ratio above this = likely solid blue/sky; still allow if B variance high (real water has variation).
  static const double maxBlueRatioForFlood = 0.88;
  /// When blue ratio > this, allow flood only if B variance >= minBlueVarianceToAllowHighBlueRatio.
  static const double blueRatioThresholdForVarianceCheck = 0.65;
  /// B variance >= this with high blue ratio → real flood (water/debris variation), not solid blue.
  static const double minBlueVarianceToAllowHighBlueRatio = 0.010;
  /// Mean brightness below this = too dark to confidently say flood → No Emergency.
  static const double minBrightnessForFlood = 0.16;

  // ─── Cyclone / Earthquake (real-world: reject flat/dark; allow real disaster with structure) ───
  static const bool enableCycloneEarthquakeVarianceCheck = true;
  /// Luminance variance below this = too flat; reject. Real disaster has texture/debris.
  static const double minLuminanceVarianceForDisaster = 0.010;
  /// Mean brightness below this = too dark to trust cyclone/earthquake → No Emergency.
  static const double minBrightnessForCycloneEarthquake = 0.16;
}
