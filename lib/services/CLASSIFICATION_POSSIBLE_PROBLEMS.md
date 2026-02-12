# Possible Problems in the Classification Pipeline

This document lists **possible problems** that can cause wrong or failed disaster classification, from image input through to the final label. Use it for debugging and to ensure preprocessing matches the trained model.

---

## 1. Preprocessing (Image → Float32List)

| Problem | Cause | What to check |
|--------|--------|----------------|
| **Channel order mismatch** | Model was trained with **BGR** (e.g. OpenCV) but we feed **RGB**. | Training pipeline: if it used `cv2.imread` (BGR), we must swap to BGR in `_normalizePixels` (output B, G, R instead of R, G, B). |
| **Normalization range** | Model expects **[0, 255]** integers or **[-1, 1]** instead of **[0, 1]**. | Training: Keras often uses `rescale=1/255` → [0,1] is correct. If training used ImageNet mean/std, we need `(pixel/255 - mean) / std` per channel. |
| **Resize/crop mismatch** | Training used different resize (e.g. stretch, different crop, or padding). | We use **shorter-side scale + center crop** to the model size (180×180 for best_model.tflite). Training must use the same. |
| **Layout / memory order** | Tensor expects **NHWC** (height, width, channels) but we might be producing a different order. | We output row-by-row, then R,G,B per pixel → NHWC. If the model expects NCHW, we would need to reshape. |
| **Image format** | `image` package decodes to a certain format; **palette/grayscale** can give wrong R,G,B. | For grayscale, we currently use same value for R,G,B (via pixel.r/g/b). If the model expects real RGB only, grayscale inputs may be misclassified. |
| **EXIF orientation** | Phone photos can be stored with rotation in EXIF; we decode without applying rotation. | Some images may be 90° off; model sees “sideways” scene → wrong class. Apply EXIF orientation before resize/crop if needed. |

---

## 2. Model input (Float32List → interpreter)

| Problem | Cause | What to check |
|--------|--------|----------------|
| **Wrong input type** | Model is **quantized** (uint8/int8) but we pass float, or the opposite. | We detect quantized input and convert float [0,1] → uint8 [0,255]. If the model uses **symmetric** int8 (e.g. -128..127), this is wrong and we need scale/zero_point from the model. |
| **Batch dimension** | TFLite expects [1,H,W,3] but we pass flat H*W*3. | We pass a flat Float32List; the interpreter uses the tensor shape (e.g. [1, 180, 180, 3]). Confirm `inputShape` at load time. |
| **Input size mismatch** | Model was exported with a different input size. | Load logs show `inputShape`. Preprocessing uses AIDetectionConfig (180×180×3 for best_model.tflite). |

---

## 3. Model output (interpreter → probabilities)

| Problem | Cause | What to check |
|--------|--------|----------------|
| **Logits vs probabilities** | Model outputs **logits** (unnormalized); we treat as probabilities or vice versa. | We detect: if sum ≈ 1 and no negatives/large values → use as probs; else apply **softmax**. If the model already has a softmax layer, applying softmax again distorts values (but argmax can still be correct). |
| **Quantized output dequantization** | We do `uint8 / 255.0` for quantized output. | Correct only if the model’s output range is [0, 255]. For **int8** or different scale/zero_point, we need the model’s dequantization formula. |
| **Output shape** | More or fewer than 4 outputs (e.g. 5th “no disaster” class). | We expect exactly 4 classes. If the model has a different number, update `AIDetectionConfig.numClasses` and `modelLabels`. |
| **Wrong label order** | Model indices 0,1,2,3 map to different classes than we assume. | We assume: **0=Cyclone, 1=Earthquake, 2=Flood, 3=Wildfire**. This must match the **order used during training** (e.g. Keras `class_indices` or dataset order). |

---

## 4. Post-processing (probabilities → label + confidence)

| Problem | Cause | What to check |
|--------|--------|----------------|
| **bestIndex out of range** | Output has >4 elements; we take bestIndex from first 4 but labels only have 4. | We clamp bestIndex to label count; if output length ≠ 4, we already trim. Ensure we never use an index ≥ 4 for `_modelLabels`. |
| **Ties / flat distribution** | Two classes have almost the same probability. | We require **minProbabilityGap** (e.g. 12%) between top and second. If gap is too small we return “No Emergency”. |
| **Low confidence** | Model is uncertain (e.g. max prob 0.3). | We require **minConfidenceToReport** (e.g. 0.35). Below that we return “No Emergency”. |
| **High entropy** | Probabilities are almost uniform (e.g. 0.25 each). | We reject if **entropy > maxEntropyForReport** (e.g. 0.95). Reduces random-looking labels. |
| **Softmax numerical edge case** | All logits equal or very large → exp overflow/underflow. | We use “max subtract” trick in softmax; if sum of exps is 0 we fall back to uniform. Check for NaN/Inf in normalized probs. |

---

## 5. Label mapping (string → EmergencyType)

| Problem | Cause | What to check |
|--------|--------|----------------|
| **Wrong string** | We map 'flood' → Flood, 'wildfire' → Fire, etc. | Any typo or different casing in the model’s class names (e.g. “WildFire”) would fall into `default` and become No Emergency. |
| **Missing class** | Model has “No disaster” as a 5th class; we only have 4 labels. | If the model outputs 5 values and index 4 is “no disaster”, we need to add that label and handle it in `_mapToEmergencyType`. |

---

## 6. Thresholds and config

| Problem | Cause | What to check |
|--------|--------|----------------|
| **Too strict** | minConfidenceToReport too high, or minProbabilityGap too large. | Many real disasters get “No Emergency”. Lower minConfidenceToReport or minProbabilityGap (in `AIDetectionConfig`). |
| **Too loose** | Thresholds too low. | Many false positives (e.g. normal scenes labeled as disaster). Raise minConfidenceToReport or minProbabilityGap, or lower maxEntropyForReport. |
| **Entropy base** | We use natural log for entropy. | maxEntropyForReport is tuned for ln (e.g. 0.95). If we switched to log2, the same numeric threshold would mean something different. |

---

## 7. Edge cases and environment

| Problem | Cause | What to check |
|--------|--------|----------------|
| **Interpreter disposed** | Model was closed (e.g. after background) but UI still calls classify. | We re-check `_interpreter != null` and `_isLoaded` before run. If the app disposes the model when not on the detection screen, ensure we don’t call classify after dispose. |
| **Concurrent inference** | Two inferences at once (e.g. double-tap). | We use an inference lock so only one run executes at a time; others wait. |
| **Very dark / overexposed images** | Preprocessing keeps [0,1] but image is mostly 0 or 1. | Model may behave poorly; we don’t currently reject by contrast. Could add a check (e.g. reject if std of pixel values < threshold). |
| **Tiny or huge images** | We reject if either side < 32px; we cap file size at 10 MB. | Very small images may be upscaled to model size and look blurry → worse accuracy. |

---

## Quick checklist when classification is wrong

1. **Preprocessing**: Same input size (e.g. 180×180), same channel order (RGB vs BGR), same normalization (e.g. [0,1]) as in training?
2. **Model**: Same `.tflite` that was exported from the training pipeline? Input/output shapes and types match (float vs quantized)?
3. **Labels**: Are `AIDetectionConfig.modelLabels` in the **exact same order** as the training dataset’s class indices?
4. **Output**: Does the model output probabilities (sum ≈ 1) or logits? We apply softmax only when needed.
5. **Thresholds**: Try temporarily lowering minConfidenceToReport / minProbabilityGap to see if real disasters then appear, or raising them to reduce false positives.
