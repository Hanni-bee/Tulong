# 🎨 AI/ML Emergency Detection Feature - Visual Guide

**Date:** December 2025  
**Feature:** Emergency Detection (Replaces Calls Screen)

---

## 📱 User Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    MAIN NAVIGATION SCREEN                      │
│  [Home] [Chat] [Emergency] [Profile]                          │
│                    ↑ User taps here                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              EMERGENCY DETECTION SCREEN                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  [← Back]  Emergency Detection              [⚙️ Settings]│   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                                                           │ │
│  │         📷 LIVE CAMERA PREVIEW                            │ │
│  │         (Real-time feed showing surroundings)            │ │
│  │                                                           │ │
│  │         [Viewfinder overlay]                              │ │
│  │                                                           │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                                 │
│                    [📸 CAPTURE PHOTO]                          │
│                    (Large red button)                           │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │  Recent Detections:                                       │ │
│  │  🔥 Fire - High [2 min ago]                              │ │
│  │  🌧️ Flood - Medium [5 min ago]                           │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                    User taps CAPTURE
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              PHOTO CAPTURED - PROCESSING                         │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                                                           │ │
│  │         [Captured Image Preview]                         │ │
│  │                                                           │ │
│  │         ⏳ Processing...                                  │ │
│  │         [Loading indicator]                               │ │
│  │                                                           │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                    ML Processing (1-3 seconds)
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              DETECTION RESULT SCREEN                             │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                                                           │ │
│  │         [Captured Image]                                 │ │
│  │                                                           │ │
│  │         🔥 FIRE DETECTED                                 │ │
│  │         Severity: HIGH                                    │ │
│  │         Confidence: 87%                                   │ │
│  │                                                           │ │
│  │    [Send to Chat]  [Retake Photo]                        │ │
│  │                                                           │ │
│  └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                    User taps "Send to Chat"
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    CHAT SCREEN                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  User Name                                              │   │
│  │  Emergency detected in my area                          │   │
│  │  🔥 Fire - High  [Badge]                                │   │
│  │  2:30 PM                                                 │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  [Message input...]                                            │
└─────────────────────────────────────────────────────────────────┘
```

---

## ⚠️ Hardware Constraint: ESP32/Radio Limitations

**Important:** ESP32 + Radio Frequency hardware can only transmit:
- ✅ **Text messages** (chat)
- ✅ **Voice messages** (audio)
- ❌ **NOT images** (hardware limitation)

**Solution:**
- Image processing happens on phone (offline)
- Only detection result (text) is sent via ESP32/radio
- Image stays on device (not transmitted)
- All existing hardware features preserved

---

## 🔄 Technical Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    USER ACTION                                  │
│              (Taps Capture Button)                              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              STEP 1: IMAGE CAPTURE                              │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Camera Controller                                       │   │
│  │  ├─ takePicture()                                        │   │
│  │  └─ Returns: XFile (image file)                         │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              STEP 2: IMAGE PREPROCESSING                        │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Image Processing Service                                │   │
│  │  ├─ Load image from file                                 │   │
│  │  ├─ Resize to 224x224 (model input size)                 │   │
│  │  ├─ Normalize pixel values (0-1 range)                   │   │
│  │  └─ Convert to Float32 array                             │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              STEP 3: FEATURE EXTRACTION                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Pre-trained MobileNetV3 Model                           │   │
│  │  ├─ Input: 224x224 normalized image                      │   │
│  │  ├─ Process: Feature extraction (ImageNet weights)         │   │
│  │  └─ Output: Feature vector (1000+ dimensions)            │   │
│  │                                                           │   │
│  │  ✅ No custom training needed!                            │   │
│  │  ✅ Model already trained on ImageNet                     │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              STEP 4: RULE-BASED CLASSIFICATION                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Emergency Detection Service                             │   │
│  │                                                           │   │
│  │  Analyze extracted features + raw image:                  │   │
│  │                                                           │   │
│  │  🔥 FIRE:                                                 │   │
│  │    ├─ Red/orange pixel concentration                     │   │
│  │    ├─ Smoke pattern detection                             │   │
│  │    ├─ Brightness analysis                                 │   │
│  │    └─ Texture patterns (flame-like)                      │   │
│  │                                                           │   │
│  │  🌧️ FLOOD:                                                │   │
│  │    ├─ Blue/cyan color dominance                          │   │
│  │    ├─ Reflection patterns                                │   │
│  │    ├─ Water texture analysis                             │   │
│  │    └─ Edge detection (water boundaries)                  │   │
│  │                                                           │   │
│  │  🌍 EARTHQUAKE:                                           │   │
│  │    ├─ Edge detection (cracks)                            │   │
│  │    ├─ Structural line analysis                           │   │
│  │    ├─ Debris patterns                                    │   │
│  │    └─ Texture irregularities                             │   │
│  │                                                           │   │
│  │  🚑 ACCIDENT:                                             │   │
│  │    ├─ Vehicle detection (pre-trained COCO model)          │   │
│  │    ├─ Color analysis (vehicles, road)                     │   │
│  │    └─ Scene composition                                   │   │
│  │                                                           │   │
│  │  ⚠️ GENERAL EMERGENCY:                                    │   │
│  │    └─ Fallback category                                  │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              STEP 5: SEVERITY ASSESSMENT                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Severity Calculator                                      │   │
│  │                                                           │   │
│  │  Based on visual intensity:                              │   │
│  │  ├─ LOW: Subtle indicators, minimal impact                │   │
│  │  ├─ MEDIUM: Clear indicators, moderate impact            │   │
│  │  ├─ HIGH: Strong indicators, significant impact         │   │
│  │  └─ CRITICAL: Overwhelming indicators, extreme impact   │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              STEP 6: RESULT PROCESSING                          │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Emergency Detection Result                              │   │
│  │  ├─ Type: Fire                                           │   │
│  │  ├─ Severity: High                                       │   │
│  │  ├─ Confidence: 87%                                      │   │
│  │  ├─ Timestamp: Current time                              │   │
│  │  └─ Image: Captured photo                                │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              STEP 7: DISPLAY & CHAT INTEGRATION                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  1. Show result screen to user                           │   │
│  │  2. User confirms "Send to Chat"                         │   │
│  │  3. Create TEXT MESSAGE with emergency info              │   │
│  │     Format: "Emergency: 🔥 Fire - High Severity"         │   │
│  │  4. Display badge in chat bubble (UI only)               │   │
│  │  5. Send TEXT via ESP32/Radio (image NOT sent)           │   │
│  │  6. Image stays on device (hardware limitation)           │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              STEP 8: ESP32/RADIO TRANSMISSION                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  ESP32 + Radio Frequency Hardware                        │   │
│  │  ├─ Receives: Text message only                          │   │
│  │  ├─ Transmits: "Emergency: 🔥 Fire - High"               │   │
│  │  ├─ Format: JSON with emergency metadata                 │   │
│  │  └─ Image: NOT transmitted (hardware can't send images)  │   │
│  │                                                           │   │
│  │  ✅ Compatible with existing text/voice system           │   │
│  │  ✅ All existing features preserved                      │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🏗️ System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        FLUTTER APP                              │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Emergency Detection Screen                  │ │
│  │  ┌───────────────────────────────────────────────────┐ │ │
│  │  │  In-App Camera Widget                              │ │ │
│  │  │  ├─ CameraController                               │ │ │
│  │  │  ├─ CameraPreview                                  │ │ │
│  │  │  └─ Capture Button                                 │ │ │
│  │  └───────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                                 │
│                              ▼                                 │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │          Emergency Detection Service                    │ │
│  │  ┌───────────────────────────────────────────────────┐ │ │
│  │  │  Image Preprocessing                                │ │ │
│  │  │  ├─ Resize to 224x224                              │ │ │
│  │  │  ├─ Normalize                                      │ │ │
│  │  │  └─ Format conversion                              │ │ │
│  │  └───────────────────────────────────────────────────┘ │ │
│  │                              │                           │ │
│  │                              ▼                           │ │
│  │  ┌───────────────────────────────────────────────────┐ │ │
│  │  │  TensorFlow Lite Interpreter                       │ │ │
│  │  │  ├─ Load: mobilenet_v3.tflite                      │ │ │
│  │  │  ├─ Input: Preprocessed image                      │ │ │
│  │  │  └─ Output: Feature vector                         │ │ │
│  │  └───────────────────────────────────────────────────┘ │ │
│  │                              │                           │ │
│  │                              ▼                           │ │
│  │  ┌───────────────────────────────────────────────────┐ │ │
│  │  │  Rule-Based Classifier                              │ │ │
│  │  │  ├─ Color analysis                                 │ │ │
│  │  │  ├─ Texture analysis                               │ │ │
│  │  │  ├─ Pattern detection                              │ │ │
│  │  │  └─ Emergency classification                        │ │ │
│  │  └───────────────────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                                 │
│                              ▼                                 │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Emergency Provider                          │ │
│  │  ├─ Detection results                                   │ │
│  │  ├─ Detection history                                   │ │
│  │  └─ State management                                    │ │
│  └─────────────────────────────────────────────────────────┘ │
│                              │                                 │
│                              ▼                                 │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │              Chat Integration                            │ │
│  │  ├─ EmergencyBadge widget                              │ │
│  │  ├─ Chat message with badge                            │ │
│  │  └─ Display in chat bubbles                             │ │
│  └─────────────────────────────────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ASSETS (Bundled in APK)                      │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  assets/models/mobilenet_v3.tflite                      │   │
│  │  ├─ Size: ~5-10 MB                                      │   │
│  │  ├─ Pre-trained on ImageNet                              │   │
│  │  └─ No internet needed!                                  │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🎨 UI Screen Mockups

### Screen 1: Emergency Detection (Camera Active)

```
╔═══════════════════════════════════════════════════════════════╗
║  [←]  Emergency Detection                      [⚙️]         ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │                                                           │ ║
║  │                                                           │ ║
║  │              📷 LIVE CAMERA PREVIEW                      │ ║
║  │                                                           │ ║
║  │         [Real-time camera feed showing                   │ ║
║  │          user's surroundings - fire visible]              │ ║
║  │                                                           │ ║
║  │                                                           │ ║
║  │                                                           │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║                    ┌─────────────┐                          ║
║                    │  📸 CAPTURE  │                          ║
║                    │  (Large Red) │                          ║
║                    └─────────────┘                          ║
║                                                               ║
╠═══════════════════════════════════════════════════════════════╣
║  Recent Detections:                                           ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │  🔥 Fire - High Severity                   2 minutes ago  │ ║
║  │  🌧️ Flood - Medium Severity               5 minutes ago │ ║
║  └─────────────────────────────────────────────────────────┘ ║
╚═══════════════════════════════════════════════════════════════╝
```

### Screen 2: Processing State

```
╔═══════════════════════════════════════════════════════════════╗
║  [←]  Emergency Detection                      [⚙️]         ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │                                                           │ ║
║  │         [Captured Image Preview]                         ║
║  │         (Shows the photo just taken)                     ║
║  │                                                           │ ║
║  │                                                           │ ║
║  │              ⏳ Processing...                            ║
║  │                                                           │ ║
║  │         [████████░░░░░░░░] 60%                           ║
║  │                                                           │ ║
║  │         Analyzing emergency type...                      │ ║
║  │                                                           │ ║
║  └─────────────────────────────────────────────────────────┘ ║
╚═══════════════════════════════════════════════════════════════╝
```

### Screen 3: Detection Result

```
╔═══════════════════════════════════════════════════════════════╗
║  [←]  Emergency Detection                      [⚙️]         ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │                                                           │ ║
║  │         [Captured Image]                                 ║
║  │         (Fire scene visible)                             ║
║  │                                                           │ ║
║  │  ┌─────────────────────────────────────────────────────┐ │ ║
║  │  │                                                       │ │ ║
║  │  │         🔥 FIRE DETECTED                             │ │ ║
║  │  │                                                       │ │ ║
║  │  │         Severity: HIGH                               │ │ ║
║  │  │         Confidence: 87%                              │ │ ║
║  │  │                                                       │ │ ║
║  │  └─────────────────────────────────────────────────────┘ │ ║
║  │                                                           ║
║  │  ┌──────────────┐          ┌──────────────┐             ║
║  │  │ Send to Chat │          │ Retake Photo │             ║
║  │  └──────────────┘          └──────────────┘             ║
║  │                                                           ║
║  └─────────────────────────────────────────────────────────┘ ║
╚═══════════════════════════════════════════════════════════════╝
```

### Screen 4: Chat with Emergency Badge

```
╔═══════════════════════════════════════════════════════════════╗
║  [←]  Local Chat                              [📞] [⋮]      ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │  [Avatar]  John Doe                                      │ ║
║  │                                                           │ ║
║  │  Emergency detected in my area                            │ ║
║  │                                                           │ ║
║  │  ┌─────────────────────────────────────────────────────┐ │ ║
║  │  │  🔥 Fire - High  [Badge]                            │ │ ║
║  │  └─────────────────────────────────────────────────────┘ │ ║
║  │                                                           │ ║
║  │  2:30 PM ✓✓                                              │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─────────────────────────────────────────────────────────┐ ║
║  │  [Avatar]  You (Me)                                      │ ║
║  │                                                           │ ║
║  │  ┌─────────────────────────────────────────────────────┐ │ ║
║  │  │  Stay safe! Help is on the way                      │ │ ║
║  │  └─────────────────────────────────────────────────────┘ │ ║
║  │                                                           │ ║
║  │  2:31 PM ✓✓                                              │ ║
║  └─────────────────────────────────────────────────────────┘ ║
║                                                               ║
╠═══════════════════════════════════════════════════════════════╣
║  [Type a message...]                    [🎤] [📷] [📎] [➤]   ║
╚═══════════════════════════════════════════════════════════════╝
```

---

## 🎯 Badge Design Variations

### Badge Types by Emergency

```
┌─────────────────────────────────────────────────────────────┐
│  🔥 FIRE BADGE                                               │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  [Red gradient background]                             │ │
│  │  🔥 Fire - High                                        │ │
│  │  [Pulsing animation for high/critical]                │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  🌧️ FLOOD BADGE                                              │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  [Blue gradient background]                            │ │
│  │  🌧️ Flood - Medium                                     │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  🌍 EARTHQUAKE BADGE                                         │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  [Brown/Orange gradient background]                  │ │
│  │  🌍 Earthquake - High                                 │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│  🚑 ACCIDENT BADGE                                           │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  [Yellow/Red gradient background]                     │ │
│  │  🚑 Accident - Critical                               │ │
│  │  [Urgent styling with alert icon]                     │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Badge by Severity Level

```
LOW SEVERITY:
┌─────────────┐
│ 🟢 Low      │  (Green, subtle)
└─────────────┘

MEDIUM SEVERITY:
┌─────────────┐
│ 🟡 Medium   │  (Yellow/Orange)
└─────────────┘

HIGH SEVERITY:
┌─────────────┐
│ 🔴 High     │  (Red, pulsing animation)
└─────────────┘

CRITICAL SEVERITY:
┌─────────────┐
│ ⚠️ Critical │  (Red, urgent, alert icon)
└─────────────┘
```

---

## 🔄 Complete User Journey

```
START
  │
  ▼
┌─────────────────┐
│ Open App        │
└─────────────────┘
  │
  ▼
┌─────────────────┐
│ Navigate to      │
│ Emergency Tab    │
└─────────────────┘
  │
  ▼
┌─────────────────┐
│ Camera Preview   │
│ Appears          │
│ (Real-time feed) │
└─────────────────┘
  │
  ▼
┌─────────────────┐
│ User Frames      │
│ Emergency Scene  │
└─────────────────┘
  │
  ▼
┌─────────────────┐
│ User Taps       │
│ CAPTURE Button  │
└─────────────────┘
  │
  ▼
┌─────────────────┐
│ Photo Captured   │
│ (On-device)     │
└─────────────────┘
  │
  ▼
┌─────────────────┐
│ Image            │
│ Preprocessing    │
│ (Resize,         │
│  Normalize)      │
└─────────────────┘
  │
  ▼
┌─────────────────┐
│ MobileNet        │
│ Feature          │
│ Extraction       │
│ (Pre-trained)    │
└─────────────────┘
  │
  ▼
┌─────────────────┐
│ Rule-Based       │
│ Classification   │
│ (Color, Texture, │
│  Patterns)       │
└─────────────────┘
  │
  ▼
┌─────────────────┐
│ Severity         │
│ Assessment       │
└─────────────────┘
  │
  ▼
┌─────────────────┐
│ Result Displayed │
│ (Type + Severity)│
└─────────────────┘
  │
  ▼
┌─────────────────┐
│ User Confirms    │
│ "Send to Chat"   │
└─────────────────┘
  │
  ▼
┌─────────────────┐
│ Badge Appears   │
│ in Chat          │
└─────────────────┘
  │
  ▼
END
```

---

## 📊 Data Flow Diagram

```
┌──────────────┐
│   Camera     │
│   (Device)   │
└──────┬───────┘
       │
       │ XFile (image file)
       ▼
┌──────────────────────┐
│  Image Preprocessing  │
│  ├─ Load image        │
│  ├─ Resize 224x224    │
│  └─ Normalize         │
└──────┬────────────────┘
       │
       │ Float32 array
       ▼
┌──────────────────────┐
│  MobileNetV3 Model    │
│  (Pre-trained TFLite) │
│  ├─ Input: Image      │
│  └─ Output: Features │
└──────┬────────────────┘
       │
       │ Feature vector (1000+ dims)
       ▼
┌──────────────────────┐
│  Rule-Based          │
│  Classifier          │
│  ├─ Color analysis   │
│  ├─ Texture analysis  │
│  └─ Pattern matching  │
└──────┬────────────────┘
       │
       │ EmergencyResult
       │ ├─ type: Fire
       │ ├─ severity: High
       │ └─ confidence: 0.87
       ▼
┌──────────────────────┐
│  Emergency Provider   │
│  ├─ Store result      │
│  └─ Update state      │
└──────┬────────────────┘
       │
       │ Emergency data
       ▼
┌──────────────────────┐
│  Chat Integration    │
│  ├─ Create message    │
│  ├─ Add badge         │
│  └─ Display in chat  │
└──────────────────────┘
```

---

## 🎬 Animation Flow

```
Camera Preview State:
┌─────────────────┐
│  Live Feed      │  ← Continuous camera stream
│  [Moving image] │
└─────────────────┘

Capture Animation:
┌─────────────────┐
│  Flash Effect   │  ← Brief white flash
│  [White overlay]│
└─────────────────┘
       │
       ▼
┌─────────────────┐
│  Processing     │  ← Loading spinner
│  [Spinning]      │     + Progress bar
└─────────────────┘
       │
       ▼
┌─────────────────┐
│  Result Fade-in │  ← Smooth fade animation
│  [Fade in]      │
└─────────────────┘

Badge Animation:
┌─────────────────┐
│  Badge Appears  │  ← Slide up + fade
│  [Slide up]     │
└─────────────────┘
       │
       ▼
┌─────────────────┐
│  Pulsing Effect │  ← For High/Critical
│  [Pulse]        │     severity badges
└─────────────────┘
```

---

## 🔌 Offline Operation Flow

```
┌─────────────────────────────────────────────────────────┐
│              OFFLINE OPERATION GUARANTEE                 │
│                                                           │
│  ✅ All components work without internet:                │
│                                                           │
│  1. Camera (Device hardware)                             │
│     └─ No internet needed                                │
│                                                           │
│  2. Image Processing (On-device)                        │
│     └─ No internet needed                                │
│                                                           │
│  3. ML Model (Bundled in APK)                            │
│     └─ mobilenet_v3.tflite (5-10 MB)                    │
│     └─ Loaded from assets/ folder                        │
│     └─ No download needed                                │
│                                                           │
│  4. Rule-based Classification (Code logic)               │
│     └─ No internet needed                                │
│                                                           │
│  5. Chat Integration (Local storage)                     │
│     └─ No internet needed                                │
│                                                           │
│  Result: 100% OFFLINE FUNCTIONALITY ✅                   │
└─────────────────────────────────────────────────────────┘
```

---

## 📱 Integration with Existing App

```
┌─────────────────────────────────────────────────────────┐
│                    MAIN NAVIGATION                       │
│                                                           │
│  [Home] [Chat] [Emergency] [Profile]                     │
│                    ↑                                      │
│                    │ Replaces "Calls" tab                │
└─────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────┐
│              EMERGENCY DETECTION SCREEN                  │
│  (New screen replacing CallsScreen)                      │
└─────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────┐
│                    CHAT SCREENS                          │
│                                                           │
│  ├─ LocalChatScreen                                      │
│  ├─ GlobalChatScreen                                     │
│  ├─ PrivateChatScreen                                    │
│  └─ All chat screens                                     │
│                                                           │
│  All updated to display EmergencyBadge widget            │
└─────────────────────────────────────────────────────────┘
```

---

## 🎯 Key Features Highlighted

```
┌─────────────────────────────────────────────────────────┐
│  ✅ IN-APP CAMERA                                        │
│     └─ No external app switching                         │
│     └─ Real-time preview                                │
│     └─ Direct capture                                   │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  ✅ OFFLINE ML PROCESSING                                │
│     └─ Pre-trained model bundled                        │
│     └─ No internet required                             │
│     └─ Fast inference (1-3 seconds)                     │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  ✅ NO CUSTOM DATASET NEEDED                            │
│     └─ Uses pre-trained ImageNet model                  │
│     └─ Rule-based classification                        │
│     └─ Works immediately                                │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  ✅ CHAT INTEGRATION                                     │
│     └─ Badge display in messages                        │
│     └─ Visual emergency indicators                      │
│     └─ Severity-based styling                           │
└─────────────────────────────────────────────────────────┘
```

---

**Status:** ✅ Complete visualization ready for implementation reference  
**Last Updated:** December 13, 2025

