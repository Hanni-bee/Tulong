/// Central configuration for AI disaster detection pipeline.
/// Tune thresholds and labels here for consistent, reliable detection.
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
  static const double minConfidenceToReport = 0.52;

  /// Minimum gap between top-1 and top-2 probability (avoids uncertain ties)
  /// e.g. 0.18 means top class must lead by at least 18% to be accepted
  static const double minProbabilityGap = 0.18;

  /// Maximum entropy (uncertainty) allowed; above this → "No Emergency"
  /// Entropy ≈ -sum(p*log(p)). Higher = more uncertain. 1.0 ≈ uniform over 4 classes.
  static const double maxEntropyForReport = 0.90;

  /// Wildfire requires higher confidence to reduce false positives (fire when there is no fire)
  static const double minConfidenceForWildfire = 0.58;

  /// Default confidence shown when we report "No Emergency" (for UI)
  static const double defaultNoEmergencyConfidence = 0.725;

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
  /// Set to ~0.02 to reject completely dark or flat photos and show "Image too dark – try again".
  static const double minContrastForInference = 0.02;

  // ─── Post-processing enhancements (all offline, no network) ───
  /// Temperature for confidence: 1.0 = no change; >1 = softer probs; <1 = sharper. Applied after softmax.
  static const double temperatureScale = 1.0;
  /// Test-time augmentation: run on original + horizontally flipped image, average probabilities. More stable, ~2x inference time.
  static const bool enableTTA = true;
  /// When model says Wildfire, require image to have some red/orange presence (reduces false fire in blue/green scenes).
  static const bool enableWildfireColorCheck = true;
  /// Minimum mean-R ratio (R / (R+G+B)) to accept wildfire; below this → No Emergency. Typical fire ~0.35–0.5.
  static const double minRedRatioForWildfire = 0.32;

  /// When model says Flood, require image to have some blue/cyan presence (reduces false flood in dry/red scenes).
  static const bool enableFloodColorCheck = true;
  /// Minimum mean-B ratio (B / (R+G+B)) to accept flood; below this → No Emergency. Typical water ~0.3–0.5.
  static const double minBlueRatioForFlood = 0.28;

  /// When ML says disaster, allow rule-based color check to slightly reduce confidence (hybrid refinement). Does not force No Emergency.
  static const bool enableHybridConfidenceRefinement = true;
  /// If hybrid refinement is on and rule-based strongly disagrees, cap confidence at this (e.g. 0.65).
  static const double maxConfidenceWhenRuleBasedDisagrees = 0.68;
}
