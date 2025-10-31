# ✨ Subtle Overlays System - Implementation Guide

## 🎯 **Overview**
Strategic subtle overlays na nagdadagdag ng depth at visual interest nang hindi overwhelming. Designed para ma-elevate ang Soft UI design.

---

## 🛠️ **Available Overlay Utilities**

### **1. Card Depth Overlay** (`buildDepthOverlay`)
Para sa elevated cards na may subtle depth effect.

```dart
SoftUIDesign.buildDepthOverlay(
  accentColor: AppColors.primaryRed,
  elevation: 4.0,
)
```

**Use Cases:**
- Home screen cards
- Recent activity section
- Profile stat cards
- Important content sections

**Where Applied:**
- ✅ `EnhancedCard` widget (automatic for elevated cards)
- ✅ Recent Activity section
- ✅ Profile stat cards

---

### **2. Radial Overlay** (`buildRadialOverlay`)
Subtle radial gradient na nagdadagdag ng focal point.

```dart
SoftUIDesign.buildRadialOverlay(
  color: AppColors.primaryRed,
  opacity: 0.04,
  alignment: Alignment.topLeft,
)
```

**Use Cases:**
- Stat cards (icon area)
- Highlighted items
- Interactive elements
- Card accents

**Where Applied:**
- ✅ Profile stat cards (top-left accent)

---

### **3. Glow Overlay** (`getGlowOverlay`)
Subtle glow effect para sa important elements.

```dart
boxShadow: SoftUIDesign.getGlowOverlay(
  color: AppColors.primaryRed,
  intensity: 0.12,
  blur: 8.0,
)
```

**Use Cases:**
- Active navigation items
- Status indicators
- Icon containers
- Important buttons

**Where Applied:**
- ✅ Navigation bar active items (subtle glow)
- ✅ Profile stat card icons (subtle glow)
- ✅ Status indicators

---

### **4. Profile Header Overlays** (`buildProfileHeaderOverlays`)
Decorative circles para sa profile header.

```dart
...SoftUIDesign.buildProfileHeaderOverlays()
```

**Where Applied:**
- ✅ Profile screen header (3 decorative circles)

---

### **5. Press/Hover Overlay** (`getPressOverlay`)
Visual feedback para sa interactive elements.

```dart
SoftUIDesign.getPressOverlay(
  baseColor: AppColors.primaryRed,
  isPressed: _isPressed,
)
```

**Use Cases:**
- Button press states
- Card tap feedback
- Interactive tiles

---

### **6. Modal Backdrop** (`getModalBackdrop`)
Subtle backdrop para sa modals.

```dart
backgroundColor: SoftUIDesign.getModalBackdrop(opacity: 0.4)
```

---

## 📍 **Current Implementation**

### **Home Screen**
- ✅ Recent Activity card - Depth overlay
- ✅ Quick actions - Depth overlay (via EnhancedCard)

### **Profile Screen**
- ✅ Profile header - Decorative overlays (3 circles)
- ✅ Stat cards - Radial overlay + icon glow

### **Navigation**
- ✅ Active nav items - Subtle glow overlay

### **Cards (EnhancedCard)**
- ✅ Automatic depth overlay para sa elevated cards

---

## 🎨 **Best Practices**

### **1. Opacity Levels**
- **Very Subtle:** 0.01 - 0.03 (depth overlays)
- **Subtle:** 0.04 - 0.08 (radial overlays, glows)
- **Moderate:** 0.10 - 0.15 (important elements)
- **Visible:** 0.20+ (only for special cases)

### **2. When to Use**
✅ **DO Use:**
- Elevated cards (elevation ≥ 3.0)
- Important UI elements
- Active/selected states
- Interactive feedback
- Profile headers
- Stat cards

❌ **DON'T Use:**
- Simple containers
- Low elevation elements (elevation < 3.0)
- Text-heavy areas
- Flat lists
- Every single card

### **3. Color Selection**
- Use accent color (red) for general overlays
- Use element-specific color para sa glows
- Keep opacity low (0.04-0.08 range)
- Test on different backgrounds

---

## 🔧 **How to Add More Overlays**

### **Example: Add to Home Screen Card**

```dart
Container(
  decoration: SoftUIDesign.cardDecoration(...),
  child: Stack(
    children: [
      // Depth overlay
      SoftUIDesign.buildDepthOverlay(
        accentColor: AppColors.primaryRed,
        elevation: 4.0,
      ) ?? const SizedBox.shrink(),
      
      // Content
      YourContentWidget(),
    ],
  ),
)
```

### **Example: Add Glow to Icon**

```dart
Container(
  decoration: BoxDecoration(
    color: color.withOpacity(0.12),
    shape: BoxShape.circle,
    boxShadow: SoftUIDesign.getGlowOverlay(
      color: color,
      intensity: 0.12,
      blur: 8.0,
    ),
  ),
  child: Icon(...),
)
```

---

## 📊 **Overlay Intensity Guide**

| Element Type | Intensity | Opacity | Blur |
|-------------|-----------|---------|------|
| Depth Overlay | Very Low | 0.01-0.02 | - |
| Radial Overlay | Low | 0.04-0.06 | - |
| Icon Glow | Medium | 0.10-0.15 | 8-12 |
| Active State | Medium | 0.08-0.12 | 6-8 |
| Profile Decor | Medium | 0.08-0.18 | - |

---

## ✅ **Current Status**

- ✅ Overlay system created
- ✅ Profile screen enhanced
- ✅ Home screen cards enhanced
- ✅ Navigation active states enhanced
- ✅ Stat cards enhanced
- ✅ EnhancedCard automatic overlays

---

## 🚀 **Next Steps (Optional)**

Puwede i-add ang overlays sa:
- Settings items (subtle press feedback)
- Buttons (press states)
- Modal dialogs (subtle backdrop)
- Status indicators (glow effects)
- Important notifications (glow)

**Remember:** Keep it subtle! Overlays ay dapat enhance, hindi distract. ✨

