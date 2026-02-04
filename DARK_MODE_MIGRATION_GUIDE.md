# Dark Mode Migration Guide
## T.U.L.O.N.G Emergency Communication App

**Date:** January 30, 2025  
**Status:** Active Migration Guide  
**Purpose:** Systematic guide for migrating hardcoded colors to theme-aware colors

---

## 📋 Overview

This guide provides step-by-step instructions for migrating all hardcoded colors to theme-aware colors, enabling full dark mode support (Standard Dark + AMOLED Black).

**Migration Pattern:**
1. Replace hardcoded colors with theme-aware utilities
2. Maintain design integrity (same spacing, typography, structure)
3. Test in all 3 themes (Light, Dark, AMOLED Black)

---

## 🎯 Migration Checklist

### Phase 1: Foundation ✅ COMPLETE
- [x] Theme-Aware Color System (`ThemeColors`)
- [x] Dark Themes Configuration (Standard + AMOLED)
- [x] Theme State Management (`ThemeProvider`)
- [x] Soft UI Design System (theme-aware)

### Phase 2: Core Migration
- [x] Main Theme Configuration
- [x] Soft UI Design System
- [ ] Background Colors (47 files)
- [ ] Text Colors (47 files)

### Phase 3: Screen-by-Screen Migration
- [ ] Home Screen
- [ ] Local Chat Screen
- [ ] Profile Screen
- [ ] All Modals
- [ ] Authentication Screens
- [ ] Other Screens

---

## 🔧 Migration Patterns

### Pattern 1: Background Colors

#### ❌ BEFORE (Hardcoded):
```dart
Container(
  color: Colors.white,
  child: Text('Hello'),
)

Scaffold(
  backgroundColor: AppColors.white,
  body: ...,
)

BoxDecoration(
  color: AppColors.white,
  ...
)
```

#### ✅ AFTER (Theme-Aware):
```dart
Container(
  color: ThemeColors.surface(context),
  child: Text('Hello'),
)

Scaffold(
  backgroundColor: ThemeColors.background(context),
  body: ...,
)

BoxDecoration(
  color: ThemeColors.surface(context),
  ...
)
```

### Pattern 2: Card Backgrounds

#### ❌ BEFORE:
```dart
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
  ),
)
```

#### ✅ AFTER:
```dart
Container(
  decoration: SoftUIDesign.cardDecoration(
    context: context,
    backgroundColor: ThemeColors.surface(context),
    borderRadius: 16,
  ),
)
```

### Pattern 3: Text Colors

#### ❌ BEFORE:
```dart
Text(
  'Hello',
  style: TextStyle(
    color: AppColors.textPrimary,
  ),
)

Text(
  'Subtitle',
  style: TextStyle(
    color: AppColors.textSecondary,
  ),
)
```

#### ✅ AFTER:
```dart
Text(
  'Hello',
  style: TextStyle(
    color: ThemeColors.textPrimary(context),
  ),
)

Text(
  'Subtitle',
  style: TextStyle(
    color: ThemeColors.textSecondary(context),
  ),
)
```

### Pattern 4: Border Colors

#### ❌ BEFORE:
```dart
Border.all(
  color: AppColors.lightGray.withOpacity(0.3),
  width: 1.0,
)
```

#### ✅ AFTER:
```dart
Border.all(
  color: ThemeColors.border(context),
  width: 1.0,
)
```

### Pattern 5: Shadow Colors

#### ❌ BEFORE:
```dart
BoxShadow(
  color: Colors.black.withOpacity(0.1),
  blurRadius: 10,
)
```

#### ✅ AFTER:
```dart
BoxShadow(
  color: ThemeColors.shadow(context, opacity: 0.1),
  blurRadius: 10,
)
```

### Pattern 6: Scaffold Background

#### ❌ BEFORE:
```dart
Scaffold(
  backgroundColor: const Color(0xFFF5F5F5),
  body: ...,
)
```

#### ✅ AFTER:
```dart
Scaffold(
  backgroundColor: ThemeColors.background(context),
  body: ...,
)
```

### Pattern 7: Dialog/Modal Backgrounds

#### ❌ BEFORE:
```dart
Dialog(
  backgroundColor: Colors.white,
  child: ...,
)
```

#### ✅ AFTER:
```dart
Dialog(
  backgroundColor: ThemeColors.surface(context),
  child: ...,
)
```

### Pattern 8: Input Field Backgrounds

#### ❌ BEFORE:
```dart
InputDecoration(
  filled: true,
  fillColor: Colors.white,
  ...
)
```

#### ✅ AFTER:
```dart
InputDecoration(
  filled: true,
  fillColor: ThemeColors.surface(context),
  ...
)
```

Or use Soft UI Design:
```dart
SoftUIDesign.inputDecoration(
  context: context,
  labelText: 'Label',
  hintText: 'Hint',
)
```

---

## 📝 Step-by-Step Migration Process

### Step 1: Identify Hardcoded Colors

**Search for:**
- `Colors.white`
- `AppColors.white`
- `AppColors.textPrimary`
- `AppColors.textSecondary`
- `AppColors.lightGray`
- `Colors.black.withOpacity`
- `backgroundColor: Color(`
- `color: Color(`

**Tools:**
```bash
# Search in specific file
grep -n "Colors.white\|AppColors.white" lib/screens/modern_home_screen.dart

# Search in all screens
grep -r "Colors.white\|AppColors.white" lib/screens/
```

### Step 2: Replace Background Colors

**Priority Order:**
1. Scaffold backgrounds
2. Container backgrounds
3. Card backgrounds
4. Dialog/Modal backgrounds
5. Input field backgrounds

**Example Migration:**
```dart
// Find:
Container(
  color: Colors.white,
  child: ...,
)

// Replace with:
Container(
  color: ThemeColors.surface(context),
  child: ...,
)
```

### Step 3: Replace Text Colors

**Priority Order:**
1. Primary text (`AppColors.textPrimary`)
2. Secondary text (`AppColors.textSecondary`)
3. Tertiary text (`AppColors.textLight`)

**Example Migration:**
```dart
// Find:
Text(
  'Hello',
  style: TextStyle(color: AppColors.textPrimary),
)

// Replace with:
Text(
  'Hello',
  style: TextStyle(color: ThemeColors.textPrimary(context)),
)
```

### Step 4: Replace Border Colors

**Find:**
- `AppColors.lightGray.withOpacity(0.3)`
- `AppColors.borderColor`
- `Color(0xFFE0E0E0)`

**Replace with:**
- `ThemeColors.border(context)`

### Step 5: Replace Shadow Colors

**Find:**
- `Colors.black.withOpacity(0.1)`
- `Colors.black.withOpacity(0.2)`

**Replace with:**
- `ThemeColors.shadow(context, opacity: 0.1)`
- `ThemeColors.shadowElevation(context, opacity: 0.2)`

### Step 6: Update Soft UI Design Calls

**Find:**
```dart
SoftUIDesign.cardDecoration(
  backgroundColor: AppColors.white,
  ...
)
```

**Replace with:**
```dart
SoftUIDesign.cardDecoration(
  context: context,
  backgroundColor: ThemeColors.surface(context),
  ...
)
```

### Step 7: Test in All Themes

**After each screen migration:**
1. Test in Light mode
2. Test in Dark mode
3. Test in AMOLED Black mode
4. Verify no layout shifts
5. Verify text readability
6. Verify contrast ratios

---

## 🎨 Common Color Mappings

### Background Colors

| Hardcoded | Theme-Aware |
|-----------|-------------|
| `Colors.white` | `ThemeColors.surface(context)` |
| `AppColors.white` | `ThemeColors.surface(context)` |
| `Color(0xFFF5F5F5)` | `ThemeColors.background(context)` |
| `AppColors.backgroundLight` | `ThemeColors.background(context)` |
| `AppColors.cardBackground` | `ThemeColors.cardBackground(context)` |

### Text Colors

| Hardcoded | Theme-Aware |
|-----------|-------------|
| `AppColors.textPrimary` | `ThemeColors.textPrimary(context)` |
| `AppColors.textSecondary` | `ThemeColors.textSecondary(context)` |
| `AppColors.textLight` | `ThemeColors.textTertiary(context)` |
| `Color(0xFF1A1A1A)` | `ThemeColors.textPrimary(context)` |
| `Color(0xFF6B7280)` | `ThemeColors.textSecondary(context)` |

### Border Colors

| Hardcoded | Theme-Aware |
|-----------|-------------|
| `AppColors.lightGray.withOpacity(0.3)` | `ThemeColors.border(context)` |
| `AppColors.borderColor` | `ThemeColors.border(context)` |
| `Color(0xFFE0E0E0)` | `ThemeColors.border(context)` |
| `Color(0xFFE5E7EB)` | `ThemeColors.border(context)` |

### Shadow Colors

| Hardcoded | Theme-Aware |
|-----------|-------------|
| `Colors.black.withOpacity(0.1)` | `ThemeColors.shadow(context, opacity: 0.1)` |
| `Colors.black.withOpacity(0.2)` | `ThemeColors.shadowElevation(context, opacity: 0.2)` |
| `Colors.black.withOpacity(0.06)` | `ThemeColors.shadow(context, opacity: 0.06)` |

### Accent Colors (Keep Same)

**These should remain unchanged:**
- `AppColors.primary` (Emergency Red)
- `AppColors.accent` (Success Green)
- `AppColors.warning` (Warning Orange)
- `AppColors.info` (Info Blue)
- `AppColors.error` (Error Red)

**Or use theme-aware version:**
- `ThemeColors.primary(context)`
- `ThemeColors.accent(context)`
- `ThemeColors.warning(context)`
- `ThemeColors.info(context)`
- `ThemeColors.error(context)`

---

## 📂 File-by-File Migration Priority

### Priority 1: Core Screens (Most Used)
1. `lib/screens/modern_home_screen.dart`
2. `lib/screens/local_chat_screen.dart`
3. `lib/screens/modern_profile_screen.dart`
4. `lib/screens/main_navigation.dart`

### Priority 2: Authentication Screens
5. `lib/screens/auth/modern_sign_in_screen.dart`
6. `lib/screens/enhanced_splash_screen.dart`
7. `lib/screens/auth/sign_up_screen.dart`

### Priority 3: Modals & Dialogs
8. `lib/widgets/connected_users_modal.dart`
9. `lib/widgets/radar_scan_modal.dart`
10. `lib/widgets/terms_conditions_modal.dart`
11. `lib/widgets/sender_info_modal.dart`

### Priority 4: Other Screens
12. All remaining screens in `lib/screens/`

---

## 🔍 Search & Replace Patterns

### Pattern 1: Simple Container Background
```dart
// Search:
color: Colors.white
color: AppColors.white

// Replace:
color: ThemeColors.surface(context)
```

### Pattern 2: Scaffold Background
```dart
// Search:
backgroundColor: const Color(0xFFF5F5F5)
backgroundColor: AppColors.backgroundLight

// Replace:
backgroundColor: ThemeColors.background(context)
```

### Pattern 3: Text Color in TextStyle
```dart
// Search:
color: AppColors.textPrimary
color: AppColors.textSecondary

// Replace:
color: ThemeColors.textPrimary(context)
color: ThemeColors.textSecondary(context)
```

### Pattern 4: BoxDecoration Color
```dart
// Search:
BoxDecoration(
  color: Colors.white,
  ...
)

// Replace:
BoxDecoration(
  color: ThemeColors.surface(context),
  ...
)
```

### Pattern 5: Border Color
```dart
// Search:
borderSide: BorderSide(
  color: AppColors.lightGray.withOpacity(0.3),
  ...
)

// Replace:
borderSide: BorderSide(
  color: ThemeColors.border(context),
  ...
)
```

---

## ✅ Migration Verification Checklist

After migrating each file, verify:

- [ ] **No hardcoded `Colors.white`** (except for specific white text/icons)
- [ ] **No hardcoded `AppColors.white`**
- [ ] **No hardcoded `AppColors.textPrimary`** (use theme-aware)
- [ ] **No hardcoded `AppColors.textSecondary`** (use theme-aware)
- [ ] **All `SoftUIDesign` calls include `context: context`**
- [ ] **All containers use theme-aware colors**
- [ ] **All text uses theme-aware colors**
- [ ] **All borders use theme-aware colors**
- [ ] **All shadows use theme-aware colors**
- [ ] **Scaffold uses `ThemeColors.background(context)`**
- [ ] **Dialogs use `ThemeColors.surface(context)`**
- [ ] **Input fields use `ThemeColors.surface(context)`**

---

## 🧪 Testing Checklist

### Visual Testing
- [ ] Screen looks correct in Light mode
- [ ] Screen looks correct in Dark mode
- [ ] Screen looks correct in AMOLED Black mode
- [ ] No white cards on dark backgrounds
- [ ] No dark text on dark backgrounds
- [ ] All text is readable (WCAG AA contrast)
- [ ] Borders are visible in all themes
- [ ] Shadows are visible in all themes

### Functional Testing
- [ ] All buttons work
- [ ] All inputs work
- [ ] All modals open/close correctly
- [ ] Navigation works
- [ ] Theme switching works smoothly
- [ ] No layout shifts when switching themes

### Design Integrity
- [ ] Same spacing in all themes
- [ ] Same typography sizes in all themes
- [ ] Same border radius in all themes
- [ ] Same component dimensions in all themes
- [ ] Same visual hierarchy in all themes

---

## 🚨 Common Pitfalls & Solutions

### Pitfall 1: Forgetting to Add `context` Parameter
**Problem:**
```dart
// Missing context
Container(
  color: ThemeColors.surface(), // ERROR: Missing context
)
```

**Solution:**
```dart
Container(
  color: ThemeColors.surface(context), // ✅ Correct
)
```

### Pitfall 2: Using Hardcoded White for Text
**Problem:**
```dart
// White text might not work in light mode
Text(
  'Hello',
  style: TextStyle(color: Colors.white), // Might be invisible
)
```

**Solution:**
```dart
// Use theme-aware text color
Text(
  'Hello',
  style: TextStyle(color: ThemeColors.textPrimary(context)),
)
```

### Pitfall 3: Not Updating Soft UI Design Calls
**Problem:**
```dart
// Missing context parameter
SoftUIDesign.cardDecoration(
  backgroundColor: AppColors.white, // Still hardcoded
)
```

**Solution:**
```dart
SoftUIDesign.cardDecoration(
  context: context, // ✅ Required
  backgroundColor: ThemeColors.surface(context),
)
```

### Pitfall 4: Changing Spacing/Layout
**Problem:**
```dart
// DON'T change spacing based on theme
padding: isDark ? EdgeInsets.all(20) : EdgeInsets.all(16), // ❌ WRONG
```

**Solution:**
```dart
// Keep spacing constant
padding: const EdgeInsets.all(16), // ✅ CORRECT
```

### Pitfall 5: Not Testing in All Themes
**Problem:**
- Only testing in Light mode
- Missing issues in Dark/AMOLED modes

**Solution:**
- Always test in all 3 themes
- Use theme switcher to verify

---

## 📊 Progress Tracking

### Files Migrated: 0/47

#### Core Screens
- [ ] `modern_home_screen.dart`
- [ ] `local_chat_screen.dart`
- [ ] `modern_profile_screen.dart`
- [ ] `main_navigation.dart`

#### Authentication
- [ ] `modern_sign_in_screen.dart`
- [ ] `enhanced_splash_screen.dart`
- [ ] `sign_up_screen.dart`
- [ ] `forgot_password_screen.dart`
- [ ] `reset_password_screen.dart`
- [ ] `two_factor_verification_screen.dart`

#### Modals
- [ ] `connected_users_modal.dart`
- [ ] `radar_scan_modal.dart`
- [ ] `terms_conditions_modal.dart`
- [ ] `sender_info_modal.dart`

#### Other Screens
- [ ] `emergency_detection_screen.dart`
- [ ] `messages_screen.dart`
- [ ] `interactive_tutorial_screen.dart`
- [ ] ... (remaining 30+ files)

---

## 🎯 Quick Reference

### Import Required
```dart
import '../utils/theme_colors.dart';
import '../constants/soft_ui_design.dart';
```

### Most Common Replacements

| Find | Replace |
|------|---------|
| `Colors.white` | `ThemeColors.surface(context)` |
| `AppColors.white` | `ThemeColors.surface(context)` |
| `AppColors.textPrimary` | `ThemeColors.textPrimary(context)` |
| `AppColors.textSecondary` | `ThemeColors.textSecondary(context)` |
| `AppColors.lightGray.withOpacity(0.3)` | `ThemeColors.border(context)` |
| `Colors.black.withOpacity(0.1)` | `ThemeColors.shadow(context, opacity: 0.1)` |
| `backgroundColor: Color(0xFFF5F5F5)` | `backgroundColor: ThemeColors.background(context)` |

---

## 📝 Migration Template

Use this template for each file:

```dart
// 1. Add imports
import '../utils/theme_colors.dart';
import '../constants/soft_ui_design.dart';

// 2. Find and replace:
// - Colors.white → ThemeColors.surface(context)
// - AppColors.white → ThemeColors.surface(context)
// - AppColors.textPrimary → ThemeColors.textPrimary(context)
// - AppColors.textSecondary → ThemeColors.textSecondary(context)
// - AppColors.lightGray → ThemeColors.border(context)
// - Colors.black.withOpacity → ThemeColors.shadow(context, opacity: ...)

// 3. Update Soft UI Design calls:
// - Add context: context parameter
// - Replace hardcoded colors with theme-aware

// 4. Test in all 3 themes
```

---

## 🎉 Success Criteria

A file is considered **fully migrated** when:

1. ✅ No hardcoded `Colors.white` or `AppColors.white` (except specific cases)
2. ✅ All text colors use `ThemeColors.textPrimary/Secondary(context)`
3. ✅ All background colors use `ThemeColors.surface/background(context)`
4. ✅ All borders use `ThemeColors.border(context)`
5. ✅ All shadows use `ThemeColors.shadow(context, ...)`
6. ✅ All `SoftUIDesign` calls include `context: context`
7. ✅ Screen works correctly in all 3 themes
8. ✅ No layout shifts when switching themes
9. ✅ All text is readable (WCAG AA contrast)
10. ✅ Design integrity maintained (same spacing, typography)

---

**Last Updated:** January 30, 2025  
**Next Review:** After Phase 2 completion
