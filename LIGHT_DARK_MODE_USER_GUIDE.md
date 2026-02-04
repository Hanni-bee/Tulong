# Light & Dark Mode – What to Expect When You Run the App

Step-by-step guide to how theme (Light / Dark / AMOLED / System) works in the app.

---

## 1. How the app decides the theme

- **First launch (or no saved preference):** App starts in **Light** mode.
- **After you change theme:** Your choice is saved in **SharedPreferences** and used on every next launch.
- **Theme is applied app-wide:** All screens that use `ThemeColors.*` and the MaterialApp `theme` / `darkTheme` will follow the selected mode.

---

## 2. Run the app

```bash
flutter run
```

(or run from your IDE)

---

## 3. Step-by-step: What you’ll see

### Step 1 – Splash

- **Enhanced Splash Screen** shows (logo, loading).
- **Theme:** Uses the **saved** theme (Light or Dark/AMOLED). If first run, it’s **Light** (light background, dark text).

### Step 2 – Sign-in (if not logged in)

- You’re taken to **Modern Sign In** (or tutorial first, depending on flow).
- **Light mode:** Light background, dark text, red accents.
- **Dark mode:** Dark background, light text, red accents (if that screen is themed).

### Step 3 – Main app (after login)

- **Main navigation** with 4 tabs: **Home**, **Local Chat**, **Emergency**, **Profile**.
- All these screens use the **current** theme (background, cards, text) where they’ve been migrated to `ThemeColors`.

### Step 4 – Change theme (Light / Dark / AMOLED / System)

1. Open the **Profile** tab (last tab in the bottom nav).
2. Find the **“Appearance”** row (with palette icon) and **tap** it.
3. A dialog opens: **“Appearance”** with subtitle **“Choose how the app looks.”**
4. You’ll see **4 options:**
   - **Light** – Always light theme.
   - **Dark** – Standard dark (gray backgrounds).
   - **AMOLED Black** – True black background (for OLED).
   - **System** – Follow device Light/Dark setting.
5. **Tap one option:**
   - The app **switches theme immediately** (no need to restart).
   - A **checkmark** appears next to the selected option.
   - The dialog stays open so you can try another option or tap **Close**.

### Step 5 – After choosing a theme

- **Immediate:** Screens re-build with the new theme (light or dark).
- **Persistent:** Your choice is saved. The next time you open the app, it will start in the theme you last selected (Light, Dark, AMOLED, or System).

---

## 4. What each mode does

| Mode           | What you get                                                                 |
|----------------|-------------------------------------------------------------------------------|
| **Light**      | Light backgrounds, dark text. Uses `AppThemes.lightTheme`.                    |
| **Dark**       | Dark gray backgrounds, light text. Uses `AppThemes.darkTheme`.                |
| **AMOLED Black** | Near-black backgrounds (OLED-friendly). Uses `AppThemes.darkAmoledTheme`.  |
| **System**     | App follows the device’s Light/Dark setting. Uses `ThemeMode.system`.          |

---

## 5. Where it’s saved and when it’s used

- **Storage:** `ThemeProvider` saves the selected mode in **SharedPreferences** under key `app_theme_mode`.
- **When loaded:** On app start, `ThemeProvider()` runs `_loadThemeMode()` and applies the saved mode.
- **When changed:** Tapping an option in the Appearance dialog calls `themeProvider.setThemeMode(mode)`, which updates state, saves to SharedPreferences, and calls `notifyListeners()` so the whole app rebuilds with the new theme.

---

## 6. Quick test checklist

1. Run app → Splash in **Light** (first run).
2. Go to **Profile** → tap **Appearance**.
3. Tap **Dark** → whole app goes dark; checkmark on Dark.
4. Tap **AMOLED Black** → darker, near-black backgrounds.
5. Tap **Light** → back to light.
6. Tap **System** → app follows device theme (toggle device dark mode to verify).
7. Close app completely and reopen → last chosen theme (e.g. Dark) is still applied.

---

## 7. Screens that follow the theme

Screens that use **ThemeColors** (and thus respect Light/Dark/AMOLED) include:

- Enhanced Splash, main routes (sign-in, sign-up, forgot password, reset password, two-factor, tutorial, address-setup, update-profile, ESP32, disaster-demo).
- Main tabs: **Modern Home**, **Local Chat**, **Emergency Detection**, **Modern Profile**.
- Notification settings and other screens migrated to `ThemeColors`.

So when you switch theme, you should see these screens update to light or dark (or AMOLED) as described above.
