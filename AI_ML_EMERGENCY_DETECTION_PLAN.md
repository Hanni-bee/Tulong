# 🤖 AI/ML Emergency Detection Feature - Implementation Plan

**Date:** December 2025  
**Status:** Planning Phase 📋  
**Replaces:** Calls Screen (due to hardware limitations)

---

## 📋 Executive Summary

Replace the Calls Screen with an **AI/ML-powered Emergency Detection Tool** that:
- **In-app camera UI** - Real-time camera preview within the app (NO external camera app, NO gallery)
- Allows users to capture **real-time photos** of emergency situations
- Uses **offline ML models** to detect emergency types and severity
- Displays detected emergencies as badges in the chat interface
- **Sends detection result as text via ESP32/radio** (image stays on device - hardware limitation)
- Works **completely offline** (no internet required)
- **Preserves all existing hardware features** (chat, voice, walkie-talkie)

### 🎯 Key Design Decisions
1. **In-App Camera Only** - Users can only take real-time photos through the in-app camera interface. No gallery upload option to ensure photos are captured during actual emergency situations.

2. **No Custom Dataset Required** - Using pre-trained models (ImageNet) + rule-based classification. No need to collect or train on custom emergency datasets. Can optionally use public datasets later for improvement.

3. **Hardware Limitation: Text/Voice Only** - ESP32 + Radio Frequency hardware can only transmit **text messages and voice** - NOT images. Therefore:
   - ✅ Image processing happens on phone (offline)
   - ✅ Detection result (type + severity) sent as **text message** via ESP32/radio
   - ✅ Badge metadata included in message
   - ❌ **Image is NOT transmitted** (stays on device only)
   - ✅ All existing hardware features (chat, voice) remain intact

---

## 🎯 Feature Requirements

### Core Functionality
1. **Photo Capture** 📷 **IN-APP CAMERA ONLY**
   - **In-app camera UI** - No switching to external camera app
   - Real-time camera preview within the app
   - Direct capture button in the app interface
   - Image preview after capture (before processing)
   - Option to retake if needed
   - **NO gallery upload** - Only real-time photos allowed
   - Ensures photos are taken during actual emergency situations

2. **AI/ML Detection**
   - Detect emergency types:
     - 🌋 **Calamity** (general disaster)
     - 🌍 **Earthquake** (structural damage, shaking indicators)
     - 🌧️ **Rain/Flood** (water, flooding, heavy rain)
     - 🔥 **Fire** (smoke, flames, burning)
     - 🚑 **Accident** (vehicles, injuries, crashes)
     - ⚠️ **General Emergency** (fallback category)
   - Determine severity levels:
     - **Low** (minor, manageable)
     - **Medium** (moderate, needs attention)
     - **High** (severe, urgent)
     - **Critical** (life-threatening)

3. **Chat Integration (Hardware-Compatible)**
   - Display detected emergency as a badge in chat
   - Badge shows: Emergency Type + Severity
   - **Send detection result as TEXT MESSAGE** via ESP32/radio (hardware limitation)
   - Message format: "Emergency: [Type] - [Severity]" + badge metadata
   - **Image stays on device** (not transmitted - hardware can't send images)
   - Visual indicators (colors, icons) displayed in app UI
   - Compatible with existing ESP32/radio text transmission system

4. **Offline Operation** ✅ **100% OFFLINE - NO INTERNET REQUIRED**
   - All ML models bundled with app (included in APK)
   - No cloud API calls - everything runs on-device
   - No internet connection needed at any point
   - Works in airplane mode, remote areas, during disasters
   - TensorFlow Lite models are self-contained files

---

## 🏗️ Architecture Design

### Component Structure
```
lib/
├── screens/
│   └── emergency_detection_screen.dart  (replaces calls_screen.dart)
├── services/
│   ├── emergency_detection_service.dart  (ML model wrapper)
│   └── camera_service.dart              (in-app camera controller)
├── models/
│   ├── emergency_type.dart              (enum for emergency types)
│   └── emergency_detection_result.dart  (detection result model)
├── widgets/
│   ├── emergency_badge.dart             (chat badge widget)
│   ├── in_app_camera_preview.dart       (real-time camera UI widget)
│   └── detection_result_card.dart       (result display)
└── providers/
    └── emergency_provider.dart          (state management)
```

### Data Flow
```
User opens screen → In-app camera preview (real-time) → 
User taps capture → Image captured (on-device) → 
Image Preprocessing → ML Model Inference → 
Result Processing → Badge Display in Chat →
Text Message Created → Sent via ESP32/Radio (text only)
```

**Key Points:**
- ✅ All steps happen within the app (no external camera app)
- ✅ Real-time camera preview before capture
- ✅ Immediate processing after capture
- ❌ No gallery selection - only real-time photos
- ✅ **Image processed on phone, stays on device**
- ✅ **Only detection result (text) sent via ESP32/radio**
- ✅ Compatible with existing hardware (text/voice transmission)
- ✅ **No image transmission** (hardware limitation respected)

---

## 🔧 Technology Stack

### ML/AI Framework Options

#### **Option 1: TensorFlow Lite (Recommended)**
- ✅ **Pros:**
  - Mature and stable
  - Excellent Flutter support (`tflite_flutter`)
  - Small model sizes
  - Fast inference on mobile
  - Good documentation
- ❌ **Cons:**
  - Requires model conversion
  - Limited to TensorFlow models

**Dependencies:**
```yaml
tflite_flutter: ^0.10.4
image: ^4.1.3
```

#### **Option 2: ONNX Runtime**
- ✅ **Pros:**
  - Framework agnostic
  - Good performance
- ❌ **Cons:**
  - Less Flutter support
  - Larger package size

#### **Option 3: MediaPipe**
- ✅ **Pros:**
  - Google's solution
  - Pre-built solutions available
- ❌ **Cons:**
  - Less flexible for custom models
  - Larger dependencies

### Camera & Image Processing
```yaml
camera: ^0.10.5+5          # In-app camera access (real-time preview)
image: ^4.1.3               # Image processing
```

**Note:** We use `camera` package for in-app camera UI, NOT `image_picker` (which opens external gallery). This ensures users only capture real-time emergency photos.

### Model Options (No Custom Dataset Required)

#### **Option A: Pre-trained General Models + Rule-based Classification** ⭐ **RECOMMENDED**
- Use **pre-trained ImageNet models** (MobileNet, EfficientNet) - NO custom training needed
- Extract image features using pre-trained model
- Use **rule-based logic** to classify emergencies based on:
  - Color analysis (red/orange for fire, blue for water, etc.)
  - Texture analysis (smoke patterns, water patterns)
  - Object detection (using pre-trained COCO/YOLO models)
  - Scene understanding (pre-trained scene classification)
- **Pros:** 
  - ✅ No custom dataset needed
  - ✅ Works immediately
  - ✅ Can use publicly available pre-trained models
  - ✅ Fast to implement
- **Cons:** 
  - Less accurate than custom-trained models
  - May need refinement based on real-world usage

#### **Option B: Use Publicly Available Disaster Datasets**
- Use **Kaggle/Google Dataset Search** for emergency/disaster datasets
- Examples:
  - Natural Disasters Dataset (Kaggle)
  - Fire Detection Datasets
  - Flood Detection Datasets
- Fine-tune pre-trained model on public datasets
- **Pros:** 
  - ✅ Free, publicly available data
  - ✅ Better accuracy than rule-based
  - ✅ No need to collect own data
- **Cons:** 
  - May not perfectly match your use case
  - Still requires some ML knowledge for fine-tuning

#### **Option C: Multi-Model Ensemble (Pre-trained)**
- Combine multiple **pre-trained models**:
  - Object detection (COCO pre-trained YOLO/SSD)
  - Scene classification (Places365 pre-trained)
  - Material/texture classification
- Use ensemble voting for final decision
- **Pros:** 
  - ✅ No custom training needed
  - ✅ More accurate than single model
  - ✅ Uses proven pre-trained models
- **Cons:** 
  - Larger app size (multiple models)
  - Slower inference
  - More complex implementation

#### **Option D: Simple Rule-based (Fastest MVP)**
- Pure rule-based approach:
  - Color histogram analysis
  - Edge detection
  - Texture analysis
  - Simple heuristics
- **Pros:** 
  - ✅ No ML models needed
  - ✅ Very fast implementation
  - ✅ Small app size
  - ✅ Easy to understand and debug
- **Cons:** 
  - Least accurate
  - May have many false positives/negatives

### Recommended Approach: **Option A (Pre-trained + Rule-based)** ⭐
- Use **MobileNetV3** or **EfficientNet-Lite** (pre-trained on ImageNet)
- Extract features from images
- Apply rule-based classification logic
- Single model for feature extraction + rule-based classification
- Model size: ~5-10 MB
- **No custom dataset required!**

---

## 🔌 How Offline ML Works (Technical Explanation)

### ✅ **YES - 100% OFFLINE, NO INTERNET REQUIRED**

#### How TensorFlow Lite Works Offline:

1. **Model Bundling**
   - ML model is a `.tflite` file (typically 5-10 MB)
   - This file is **bundled inside your APK** during build
   - Just like images, fonts, or other assets
   - Model file is stored in `assets/models/` folder

2. **On-Device Inference**
   - When user takes a photo, the image is processed **locally on the phone**
   - TensorFlow Lite loads the model from the bundled file (no download)
   - All computation happens on the device's CPU/GPU
   - **Zero network requests** - completely self-contained

3. **No Internet Dependency**
   ```
   User takes photo → Image preprocessing (local) → 
   Model inference (local) → Result processing (local) → 
   Display badge (local)
   ```
   - Every step happens on the device
   - No API calls, no cloud services, no internet needed
   - Works in airplane mode, remote areas, during disasters

4. **Comparison with Cloud-Based ML**
   ```
   ❌ Cloud ML (requires internet):
   Photo → Upload to server → Process on cloud → Download result
   
   ✅ TensorFlow Lite (offline):
   Photo → Process on device → Display result
   ```

5. **Model File Structure**
   ```
   assets/
   └── models/
       └── emergency_detector.tflite  (5-10 MB, bundled in APK)
   ```
   - Model is part of the app installation
   - No separate download needed
   - Available immediately after app install

6. **Performance**
   - Inference time: 1-3 seconds (on-device)
   - Works on low-end devices (Android 5.0+)
   - Uses device GPU if available (faster)
   - Battery efficient (optimized for mobile)

### ✅ **Guarantees:**
- ✅ Works without WiFi
- ✅ Works without mobile data
- ✅ Works in airplane mode
- ✅ Works during network outages
- ✅ Works in remote/disaster areas
- ✅ No data usage
- ✅ No privacy concerns (images never leave device)

### ⚠️ **Only Internet Needed For:**
- Initial app download (one time)
- Optional: Model updates (if you want to improve accuracy later)
  - But even updates can be bundled in app updates (no separate download)

---

## 📱 UI/UX Design

### Emergency Detection Screen Layout

**In-App Camera UI (Real-Time Preview)**

```
┌─────────────────────────────────┐
│  [←] Emergency Detection    [⚙️]│
├─────────────────────────────────┤
│                                 │
│  ┌───────────────────────────┐ │
│  │                           │ │
│  │   📷 LIVE CAMERA PREVIEW  │ │
│  │   (Real-time feed)        │ │
│  │                           │ │
│  │   [Viewfinder overlay]    │ │
│  │                           │ │
│  └───────────────────────────┘ │
│                                 │
│        [📸 CAPTURE]            │
│    (Large capture button)      │
│                                 │
├─────────────────────────────────┤
│  Recent Detections:             │
│  🔥 Fire - High [2 min ago]     │
│  🌧️ Flood - Medium [5 min ago]  │
└─────────────────────────────────┘
```

**Key Features:**
- ✅ **In-app camera preview** - No switching to external camera app
- ✅ **Real-time live feed** - See what you're capturing
- ✅ **Direct capture** - One tap to capture
- ❌ **NO gallery option** - Only real-time photos
- ✅ **Immediate processing** - Photo processed right after capture

### In-App Camera Implementation Details

**User Experience Flow:**
1. User opens Emergency Detection screen
2. **Camera automatically starts** - Live preview appears immediately
3. User sees real-time camera feed (no external app)
4. User frames the emergency scene
5. User taps **Capture button** (large, prominent button)
6. Photo is captured instantly
7. Brief preview shown (with option to retake)
8. ML processing begins automatically
9. Result displayed with badge option

**Technical Implementation:**
```dart
// Using camera package for in-app camera
CameraController controller = CameraController(
  cameraDescription,
  ResolutionPreset.medium,
);

// Real-time preview widget
CameraPreview(controller)

// Capture button
FloatingActionButton(
  onPressed: () async {
    final image = await controller.takePicture();
    // Process image immediately
  },
)
```

**Benefits of In-App Camera:**
- ✅ **No app switching** - Seamless user experience
- ✅ **Faster workflow** - Direct capture and process
- ✅ **Real-time context** - User sees exactly what will be captured
- ✅ **Emergency-focused** - Encourages real-time photo capture
- ✅ **Better UX** - Custom UI matching app design

### Detection Result Display
```
┌─────────────────────────────────┐
│  Detection Result               │
│                                 │
│  [Captured Image Preview]       │
│                                 │
│  🔥 FIRE DETECTED               │
│  Severity: HIGH                 │
│  Confidence: 87%                │
│                                 │
│  [Send to Chat] [Retake]        │
└─────────────────────────────────┘
```

### Chat Badge Design
```
┌─────────────────────────────────┐
│  User Name                      │
│  Message text here...           │
│  🔥 Fire - High  [Badge]        │
│  [Timestamp]                    │
└─────────────────────────────────┘
```

**Badge Variants:**
- **Low Severity:** Green badge, subtle styling
- **Medium Severity:** Yellow/Orange badge
- **High Severity:** Red badge, pulsing animation
- **Critical Severity:** Red badge with alert icon, urgent styling

---

## 🔄 Integration Points

### 1. Navigation Integration
- Replace `CallsScreen` in `MainNavigation` with `EmergencyDetectionScreen`
- Update navigation label: "Calls" → "Emergency" or "Detect"
- Update icon: Use emergency/camera icon

### 2. Chat Integration (ESP32/Radio Compatible)
- Add `EmergencyBadge` widget to message bubbles (UI display only)
- Extend `ChatMessage` model to include emergency data
- Update chat providers to handle emergency badges
- **Create text message** with emergency info for ESP32 transmission
- Message format: `"Emergency: 🔥 Fire - High Severity"`
- Include badge metadata in message JSON (for UI display)
- **Image NOT transmitted** (hardware limitation - text/voice only)
- Use existing ESP32/radio text transmission system
- **All existing chat/voice features remain intact**

### 3. State Management
- Create `EmergencyProvider` for:
  - Detection history
  - Current detection state
  - Badge display logic
- Integrate with existing `ChatProvider`

### 4. Hardware Compatibility (ESP32/Radio)
- **Respect hardware limitations**: ESP32 + Radio can only transmit text/voice
- **Image processing**: Happens on phone, image stays on device
- **Message transmission**: Send detection result as text via existing ESP32/radio system
- **Message format**: 
  ```json
  {
    "type": "emergency_detection",
    "emergency_type": "fire",
    "severity": "high",
    "message": "Emergency: 🔥 Fire - High Severity",
    "timestamp": "2025-12-13T14:30:00Z",
    "confidence": 0.87
  }
  ```
- **Existing features preserved**:
  - ✅ Regular text chat (unchanged)
  - ✅ Voice messages (unchanged)
  - ✅ Walkie-talkie (unchanged)
  - ✅ All ESP32/radio functionality (unchanged)
- **No hardware changes needed** - Uses existing transmission system

---

## 📦 Implementation Steps

### Phase 1: Setup & Dependencies
1. ✅ Add required dependencies to `pubspec.yaml`
2. ✅ Set up camera permissions
3. ✅ Create basic screen structure
4. ✅ Update navigation

### Phase 2: In-App Camera Integration
1. ✅ Initialize camera controller
2. ✅ Implement **in-app camera preview** (real-time feed)
3. ✅ Add **direct capture button** (no external app switching)
4. ✅ Handle camera permissions
5. ✅ Image preprocessing (resize, normalize for ML model)
6. ❌ **NO gallery/image picker** - Real-time photos only

### Phase 3: ML Model Integration
1. ⚠️ **Obtain/Prepare ML Model**
   - Option: Use pre-trained model
   - Option: Train custom model
   - Convert to TensorFlow Lite format
2. ✅ Integrate TFLite Flutter plugin
3. ✅ Load model in app
4. ✅ Implement inference pipeline
5. ✅ Process model outputs

### Phase 4: UI/UX Implementation
1. ✅ Create detection result display
2. ✅ Design emergency badges
3. ✅ Add animations and feedback
4. ✅ Implement detection history

### Phase 5: Chat Integration (ESP32-Compatible)
1. ✅ Extend chat message model with emergency data
2. ✅ Add badge widget to message bubbles (UI only)
3. ✅ Create text message format for ESP32 transmission
4. ✅ Integrate with existing ESP32/radio text transmission
5. ✅ Ensure image NOT sent (hardware limitation)
6. ✅ Update all chat screens to display badges
7. ✅ Verify existing chat/voice features still work

### Phase 6: Testing & Optimization
1. ✅ Test on various devices
2. ✅ Optimize model inference speed
3. ✅ Test offline functionality
4. ✅ **Test ESP32/radio transmission** (text message only, no images)
5. ✅ **Verify existing features** (chat, voice, walkie-talkie still work)
6. ✅ Performance profiling
7. ✅ User testing

---

## 🎨 Badge Design Specifications

### Badge Component Structure
```dart
EmergencyBadge(
  type: EmergencyType.fire,
  severity: SeverityLevel.high,
  confidence: 0.87,
  timestamp: DateTime.now(),
)
```

### Visual Design
- **Size:** Compact, fits in message bubble
- **Colors:** 
  - Fire: Red gradient
  - Earthquake: Brown/Orange
  - Flood: Blue
  - Accident: Yellow/Red
  - Calamity: Purple
  - General: Gray
- **Icons:** Emoji or custom icons
- **Animation:** Pulse for high/critical severity

### Badge Placement
- Inside message bubble (top-right corner)
- Or as separate message element
- Clickable to show details

---

## 🚧 Challenges & Solutions

### Challenge 1: Model Size
**Problem:** ML models can be large (50-100MB+)  
**Solution:**
- Use quantized models (INT8) to reduce size by 75%
- Use MobileNet/EfficientNet-Lite (optimized for mobile)
- Target model size: <10MB
- Consider model download on first use (optional)

### Challenge 2: Inference Speed
**Problem:** ML inference can be slow on low-end devices  
**Solution:**
- Use GPU acceleration (if available)
- Optimize image preprocessing
- Cache model in memory
- Show loading indicator during inference
- Target: <2 seconds on mid-range devices

### Challenge 3: Accuracy (Without Custom Dataset)
**Problem:** False positives/negatives in emergency detection without custom training data  
**Solution:**
- Use pre-trained models + rule-based logic (no custom dataset needed)
- Show confidence scores to users
- Allow user to override/correct (learn from user feedback)
- Start with rule-based, improve iteratively
- Consider using public datasets later if needed
- Accept that initial accuracy may be lower, but functional for MVP

### Challenge 4: Offline Model Updates
**Problem:** How to update models without internet?  
**Solution:**
- Bundle model with app (initial version)
- Optional: Download updates when online
- Version model files
- Fallback to bundled model if update fails

### Challenge 5: Battery Usage
**Problem:** ML inference can drain battery  
**Solution:**
- Optimize inference frequency
- Use efficient models
- Batch processing if multiple images
- Background processing with limits

---

## 📊 Model Approach (No Custom Dataset Required)

### ⚠️ **Constraint: No Access to Large Custom Datasets**

Since we don't have access to large custom emergency datasets, we'll use **pre-trained models + rule-based logic**.

### Recommended Approach: Pre-trained Feature Extraction + Rule-based Classification

#### **Step 1: Feature Extraction (Pre-trained Model)**
- Use **MobileNetV3** (pre-trained on ImageNet) - Available on TensorFlow Hub
- Extract image features (no training needed)
- Get 1000+ dimensional feature vector per image
- Model already trained, just use for feature extraction

#### **Step 2: Rule-based Emergency Classification**
Based on extracted features + image analysis:

**Fire Detection:**
- High red/orange pixel concentration
- Smoke patterns (gray/white gradients)
- Brightness analysis
- Texture patterns (flame-like edges)

**Flood/Water Detection:**
- Blue/cyan color dominance
- Reflection patterns
- Water texture analysis
- Edge detection for water boundaries

**Earthquake/Structural Damage:**
- Edge detection for cracks
- Structural line analysis
- Debris patterns
- Texture irregularities

**Accident Detection:**
- Vehicle detection (using pre-trained COCO model)
- Color analysis (vehicle colors, road)
- Scene composition

**General Emergency:**
- Fallback category
- High activity/chaos indicators
- Unusual color/texture patterns

#### **Step 3: Severity Assessment (Rule-based)**
- **Low:** Subtle indicators, minimal visual impact
- **Medium:** Clear indicators, moderate visual impact
- **High:** Strong indicators, significant visual impact
- **Critical:** Overwhelming indicators, extreme visual impact

### Alternative: Use Public Datasets (If Available)

If you want better accuracy, you can use publicly available datasets:

**Free Public Datasets:**
- **Kaggle:** Natural Disasters, Fire Detection, Flood Detection
- **Google Dataset Search:** Emergency/disaster image datasets
- **Roboflow Universe:** Pre-labeled disaster datasets
- **GitHub:** Various emergency detection datasets

**If Using Public Datasets:**
1. Download public dataset (1000-5000 images)
2. Fine-tune pre-trained MobileNet on this data
3. Convert to TFLite
4. Bundle with app

**But this is optional** - Rule-based approach works without any dataset!

---

## 🔐 Privacy & Security

### Image Handling
- ✅ Process images locally (never upload)
- ✅ Delete captured images after processing (optional)
- ✅ No cloud storage of user photos
- ✅ Clear user consent for camera access

### Data Collection
- ✅ Optional: Allow users to contribute images (anonymized)
- ✅ Clear privacy policy
- ✅ User control over data sharing

---

## 📈 Success Metrics

### Technical Metrics
- Inference time: <2 seconds
- Model accuracy: >80% on test set
- App size increase: <15MB
- Battery impact: Minimal

### User Experience Metrics
- Detection accuracy (user-reported)
- False positive rate
- User satisfaction
- Feature adoption rate

---

## 🎯 MVP (Minimum Viable Product) Scope

### Must Have
1. ✅ **In-app camera UI** (real-time preview, no external app)
2. ✅ **Real-time photo capture** (no gallery option)
3. ✅ Basic ML model (even if simple/rule-based initially)
4. ✅ Emergency type detection (6 types)
5. ✅ Badge display in chat
6. ✅ Offline functionality

### Nice to Have (Future)
1. Severity detection (can start with type only)
2. Detection history
3. Model confidence scores
4. Multiple model options
5. User feedback/learning

---

## 🚀 Quick Start Options

### Option 1: Pre-trained + Rule-based (Recommended) ⭐
- Use pre-trained MobileNet/EfficientNet (ImageNet) for feature extraction
- Apply rule-based classification logic
- **No custom dataset needed!**
- **Timeline:** 1-2 weeks
- **Camera:** In-app camera UI required
- **Accuracy:** Moderate (good enough for MVP)
- **Pros:** Works immediately, no data collection needed

### Option 2: Pure Rule-based (Fastest MVP)
- Use basic image analysis (color, texture, edges)
- Pure rule-based classification (no ML models)
- **Timeline:** 3-5 days
- **Note:** Less accurate, but functional and fast
- **Camera:** In-app camera UI required
- **Pros:** Very fast, small app size, easy to debug

### Option 3: Use Public Datasets (Better Accuracy)
- Download free public disaster datasets (Kaggle, etc.)
- Fine-tune pre-trained model on public data
- **Timeline:** 2-3 weeks
- **Camera:** In-app camera UI required
- **Pros:** Better accuracy than rule-based
- **Cons:** Still requires some ML knowledge

### Option 4: Train Custom Model (Best Quality - Future)
- Collect/gather your own dataset
- Train custom model
- Optimize and deploy
- **Timeline:** 4-6 weeks
- **Camera:** In-app camera UI required
- **Note:** Not feasible without dataset access

**Note:** All options require in-app camera implementation (no gallery option)

### Recommended: **Option 1 (Pre-trained + Rule-based)** ⭐
- Start with Option 1 for MVP (no dataset needed)
- Optionally improve with Option 3 (public datasets) later
- Option 4 only if you get dataset access in the future

---

## 📝 Next Steps

1. **Decision Points:**
   - [ ] Choose ML framework (TensorFlow Lite recommended)
   - [ ] Choose model approach (pre-trained vs custom)
   - [ ] Define MVP scope
   - [ ] Set timeline

2. **Immediate Actions:**
   - [ ] Research available emergency detection models
   - [ ] Set up development environment
   - [ ] Create feature branch
   - [ ] Begin Phase 1 implementation

3. **Questions to Answer:**
   - ✅ **Dataset:** No custom dataset available - Using pre-trained + rule-based approach
   - What's the target device range (low-end to high-end)?
   - What's the acceptable model size limit?
   - What's the timeline for MVP vs full feature?
   - Should we use public datasets later for improvement?

---

## 📚 Resources

### Flutter ML Libraries
- [tflite_flutter](https://pub.dev/packages/tflite_flutter) - TensorFlow Lite integration
- [camera](https://pub.dev/packages/camera) - **In-app camera UI** (real-time preview)
- [image](https://pub.dev/packages/image) - Image processing

### Model Resources (No Custom Dataset Needed)
- [TensorFlow Hub](https://tfhub.dev/) - **Pre-trained MobileNet/EfficientNet models** (ImageNet)
- [TensorFlow Lite Models](https://www.tensorflow.org/lite/models) - Ready-to-use TFLite models
- [Kaggle Datasets](https://www.kaggle.com/datasets) - **Public emergency/disaster datasets** (optional, for future improvement)
- [Google Dataset Search](https://datasetsearch.research.google.com/) - Search for public disaster datasets
- [Roboflow Universe](https://universe.roboflow.com/) - Pre-labeled disaster datasets (optional)
- [COCO Dataset Models](https://cocodataset.org/) - Pre-trained object detection models

### Documentation
- [TensorFlow Lite Guide](https://www.tensorflow.org/lite)
- [Flutter Camera Plugin](https://pub.dev/packages/camera)
- [Mobile ML Best Practices](https://developers.google.com/ml-kit)

---

**Status:** Ready for review and implementation planning  
**Last Updated:** December 13, 2025

