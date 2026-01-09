# 🎨 Out of Place Designs - Emergency Detection Screen

## Lista ng mga design elements na hindi consistent sa app design system:

### 1. **Processing Overlay Border** ⚠️
**Location:** Line 1218-1220
- **Issue:** Border width `2` (dapat `1.0` o `1.5`)
- **Issue:** Border radius `SoftUIDesign.cardBorderRadius - 2` (dapat consistent)
- **Current:**
  ```dart
  border: Border.all(
    color: AppColors.primaryRed.withOpacity(0.3),
    width: 2,  // ❌ Dapat 1.0 o 1.5
  ),
  borderRadius: BorderRadius.circular(SoftUIDesign.cardBorderRadius - 2),  // ❌ Dapat consistent
  ```

### 2. **Retry Button (Camera Loading State)** ⚠️
**Location:** Line 1106-1124
- **Issue:** Gumagamit ng `ElevatedButton` instead of app's standard button design
- **Issue:** Custom padding at styling
- **Current:**
  ```dart
  ElevatedButton(  // ❌ Dapat SoftUIDesign.buttonDecoration o ModernGradientButton
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryRed,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),  // ❌ Custom padding
    ),
  )
  ```

### 3. **Detection Result Dialog Header** ⚠️
**Location:** Line 418-420
- **Issue:** Custom gradient instead of SoftUIDesign
- **Issue:** Border radius `20` instead of `SoftUIDesign.cardBorderRadius`
- **Current:**
  ```dart
  decoration: BoxDecoration(
    gradient: LinearGradient(...),  // ❌ Dapat solid color o SoftUIDesign
    borderRadius: BorderRadius.circular(20),  // ❌ Dapat SoftUIDesign.cardBorderRadius
  ),
  ```

### 4. **Detection Items - Emoji Container** ⚠️
**Location:** Line 1637
- **Issue:** Border radius `10` instead of `SoftUIDesign.buttonBorderRadius` (12)
- **Current:**
  ```dart
  borderRadius: BorderRadius.circular(10),  // ❌ Dapat SoftUIDesign.buttonBorderRadius (12)
  ```

### 5. **Processing Indicator Container** ⚠️
**Location:** Line 1232-1247
- **Issue:** Custom `RadialGradient` instead of standard design
- **Issue:** Custom shadows instead of `SoftUIDesign.getSoftShadow()`
- **Current:**
  ```dart
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: RadialGradient(...),  // ❌ Custom gradient
    boxShadow: [
      BoxShadow(...),  // ❌ Custom shadow, dapat SoftUIDesign.getSoftShadow()
    ],
  ),
  ```

### 6. **Camera Loading State Background** ⚠️
**Location:** Line 1063-1070
- **Issue:** Custom gradient instead of solid color
- **Current:**
  ```dart
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [Colors.black87, Colors.black54],  // ❌ Dapat solid color
    ),
  ),
  ```

### 7. **Detection Dialog Actions Section** ⚠️
**Location:** Line 698-705
- **Issue:** Border radius `20` instead of `SoftUIDesign.cardBorderRadius`
- **Current:**
  ```dart
  borderRadius: const BorderRadius.only(
    bottomLeft: Radius.circular(20),  // ❌ Dapat SoftUIDesign.cardBorderRadius
    bottomRight: Radius.circular(20),  // ❌ Dapat SoftUIDesign.cardBorderRadius
  ),
  ```

### 8. **Various Border Radius Inconsistencies** ⚠️
**Multiple Locations:**
- Line 409: `borderRadius: BorderRadius.circular(20)` ❌
- Line 482: `borderRadius: BorderRadius.circular(12)` ❌ (dapat SoftUIDesign)
- Line 496: `borderRadius: BorderRadius.circular(10)` ❌
- Line 512: `borderRadius: BorderRadius.circular(12)` ❌
- Line 567: `borderRadius: BorderRadius.circular(8)` ❌
- Line 589: `borderRadius: BorderRadius.circular(8)` ❌
- Line 621: `borderRadius: BorderRadius.circular(10)` ❌
- Line 645: `borderRadius: BorderRadius.circular(10)` ❌
- Line 669: `borderRadius: BorderRadius.circular(8)` ❌
- Line 769: `borderRadius: BorderRadius.circular(12)` ❌
- Line 796: `borderRadius: BorderRadius.circular(12)` ❌

### 9. **Top Bar Action Buttons** ⚠️
**Location:** Line 952-1016
- **Issue:** Border radius `12` hardcoded instead of `SoftUIDesign.buttonBorderRadius`
- **Current:**
  ```dart
  borderRadius: BorderRadius.circular(12),  // ❌ Dapat SoftUIDesign.buttonBorderRadius
  ```

### 10. **Custom Padding Values** ⚠️
**Multiple Locations:**
- Line 418: `padding: const EdgeInsets.all(20)` ❌ (dapat SoftUIDesign.cardPadding)
- Line 470: `padding: const EdgeInsets.all(20)` ❌
- Line 666: `padding: const EdgeInsets.all(12)` ❌
- Line 699: `padding: const EdgeInsets.all(16)` ❌ (dapat SoftUIDesign.cardPadding)

---

## Summary:
- **Total Issues Found:** 10 major categories
- **Border Radius Issues:** 15+ instances
- **Custom Gradients:** 3 instances
- **Custom Shadows:** 2 instances
- **Button Design Issues:** 1 instance
- **Padding Inconsistencies:** 4+ instances

## Recommendation:
I-align lahat sa `SoftUIDesign` constants at remove custom gradients/shadows para consistent sa buong app.

