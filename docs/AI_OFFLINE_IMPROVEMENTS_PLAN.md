# AI Part: Offline Improvements & UI Plan

**Goal:** Improve and add features to the AI disaster detection that work **fully offline**, improve the **AI UI**, and **do not change inference or thresholds** (accuracy preserved).

---

## 1. What We Will NOT Change (Accuracy Preserved)

We will **not** modify any of the following, so model behavior and accuracy stay the same:

- **Inference:** Model input/output, preprocessing (resize, normalize, EXIF), TFLite `classify()`.
- **Thresholds:** `minConfidenceToReport`, `minProbabilityGap`, `maxEntropyForReport`, `minConfidenceForWildfire`, `minRedRatioForWildfire`.
- **Post-processing:** Softmax/temperature, entropy check, wildfire color check, `_findBestPrediction` logic.
- **Severity formula:** `_determineSeverityEnhanced()` thresholds (0.85 / 0.70 / 0.55) and scoring — no change for now.

All changes below are **additive**: new fields, storage, UI, copy, and optional local-only features.

---

## 2. Offline Fixes (No Accuracy Impact)

| Fix | What we do | Offline? |
|-----|------------|----------|
| **Stale probability breakdown in history** | Store `probabilityBreakdown` (Map<String, double>) in `EmergencyDetectionResult` and in SQLite; when opening from history, use stored breakdown instead of `getDetailedAssessment()` (which uses last-run probabilities). | Yes – local DB only. |
| **EmergencyType.general vs noEmergency** | Use `EmergencyType.noEmergency` consistently when label is unknown (e.g. in `ai_assessment_widget.dart` `_mapLabelToEmergencyType` and anywhere we parse "unknown"). | Yes – code only. |
| **failure_reason in history** | Add optional `failure_reason` column to detections table; save/load so "image too dark" etc. shows correctly when reopening from history. | Yes – local DB only. |

---

## 3. New Offline Features (No Accuracy Impact)

- **Explainability line (optional)**  
  One short line under confidence, using **existing** probabilities only, e.g.:  
  *"Flood led by 54% over next class (Cyclone 18%)."*  
  No new model or thresholds; display only.

- **Detection tips (static text)**  
  Below the result card: 2–3 bullets, e.g.  
  *"For better results: good lighting, include the hazard in frame, avoid blur."*  
  Offline, no logic change.

- **Short disclaimer**  
  One line: *"This is an AI estimate. Use your judgment and report to authorities when needed."*  
  Offline, copy only.

- **Re-analyze same photo**  
  Button "Re-analyze" that runs `classifyDisaster(imagePath)` again on the same file. Same model, same logic; no accuracy change. Useful when user thinks result was wrong.

- **Local feedback (optional)**  
  "Was this assessment correct? Yes / No" stored in SQLite (e.g. detection_id, correct: bool, timestamp). No server; optional future sync. Does not change inference.

---

## 4. AI UI Improvements (Offline, No Accuracy Impact)

- **Show all 4 class probabilities when available**  
  In the result dialog, when we have stored or current `probabilityBreakdown`, show a small bar for each of Cyclone, Earthquake, Flood, Wildfire (not only the winning class). Same data we already have; clearer transparency.

- **Correct breakdown for history**  
  Once we store `probabilityBreakdown` in result/DB, history detail view shows the **correct** breakdown for that past detection (no more wrong bars). If breakdown is missing (old records), show "Breakdown not available for this detection" or hide that section.

- **Preprocess failure messaging**  
  When `failureReason` is set (e.g. "Image too dark"), show it prominently with a tip: "Try again in better lighting." Already partially there; ensure it also shows when opening from history once we store `failure_reason`.

- **Timestamp and image**  
  Keep "Detected at [date/time]" and image thumbnail so user knows which photo was analyzed. Already in place; keep and ensure they work for history.

- **Loading state**  
  While `classifyDisaster()` runs, show a clear "Analyzing image…" (and optional subtle progress) so the user knows the AI is working. No logic change.

- **Compact vs expanded (optional)**  
  On small screens, make the full breakdown/copy collapsible under "Show details" so the main result stays readable.

- **AI badge and hierarchy**  
  Keep "AI ASSESSMENT" badge; keep type + severity as primary, confidence as secondary. No threshold or inference change.

- **Accessibility**  
  Ensure semantic labels for screen readers (e.g. "AI assessment: Flood, high severity, 72% confidence") and adequate tap targets. Offline, UI only.

---

## 5. Data / Schema Changes (Offline Only)

- **EmergencyDetectionResult**  
  Add optional:  
  `Map<String, double>? probabilityBreakdown`,  
  and optionally `String? failureReason` if not already there (already exists).  
  When building result after `classifyDisaster()`, fill these from the same run (no new inference).

- **DetectionHistoryService (SQLite)**  
  - Add column `failure_reason TEXT` (nullable).  
  - Add column `probability_breakdown TEXT` (nullable; store JSON map, e.g. `{"Flood":0.72,"Cyclone":0.18,...}`).  
  - On save: write `result.failureReason` and encode `result.probabilityBreakdown` to JSON.  
  - On load: decode JSON to `Map<String, double>` and set on result (or equivalent).  
  - Migration: add columns if not present; leave existing rows’ new columns null.

- **No new network calls**  
  All of the above read/write local storage only.

---

## 6. Implementation Order (Suggested)

1. **Model & storage (accuracy unchanged)**  
   - Add `probabilityBreakdown` and ensure `failureReason` on `EmergencyDetectionResult`.  
   - Populate them in `DisasterClassificationService.classifyDisaster()`.  
   - DB: add `failure_reason` and `probability_breakdown` columns; migration; save/load in `DetectionHistoryService`.

2. **Fixes**  
   - Use stored breakdown when showing result from history; otherwise show "Breakdown not available" or hide.  
   - Align `EmergencyType` to `noEmergency` for unknown label in widget/parsing.

3. **UI**  
   - Result dialog: show all 4 classes from `probabilityBreakdown` when available.  
   - Preprocess failure message + tip when `failureReason` is set (including from history).  
   - Optional: explainability line, tips, disclaimer, "Re-analyze" button.

4. **Optional later**  
   - Local feedback table and "Was this correct?" UI.  
   - Collapsible "Show details" on small screens.  
   - Stronger accessibility labels.

---

## 7. Summary

- **All changes work offline** (local state + SQLite only).  
- **Accuracy is preserved** (no change to model, preprocessing, thresholds, or severity formula).  
- **Fixes** address stale breakdown, history display, and type consistency.  
- **New features** are additive (explainability, tips, disclaimer, re-analyze, optional feedback).  
- **UI** improves clarity and correctness using existing or newly stored data only.
