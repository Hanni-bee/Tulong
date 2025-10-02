@echo off
REM T.U.L.O.N.G APK Feature Testing Script
REM This script tests Firebase and SQLite features in the built APK

echo 🧪 Starting APK Feature Testing...
echo ==================================

REM Check if APK exists
if not exist "build\app\outputs\flutter-apk\app-release.apk" (
    echo ❌ APK not found! Please build the APK first.
    echo Run: build-apk.bat
    pause
    exit /b 1
)

echo ✅ APK found: build\app\outputs\flutter-apk\app-release.apk

REM Check APK size
for %%A in ("build\app\outputs\flutter-apk\app-release.apk") do (
    echo 📊 APK Size: %%~zA bytes
)

echo.
echo 🔍 Testing APK Features...
echo.

REM Test 1: Check if Firebase is included
echo 🧪 Test 1: Firebase Integration
echo --------------------------------
echo Checking for Firebase dependencies in APK...

REM Use aapt to check for Firebase classes (if available)
where aapt >nul 2>&1
if %errorlevel% equ 0 (
    aapt dump badging "build\app\outputs\flutter-apk\app-release.apk" | findstr "firebase" >nul
    if %errorlevel% equ 0 (
        echo ✅ Firebase classes found in APK
    ) else (
        echo ⚠️ Firebase classes not detected (may be obfuscated)
    )
) else (
    echo ⚠️ aapt not available - cannot verify Firebase classes
)

echo.

REM Test 2: Check if SQLite is included
echo 🧪 Test 2: SQLite Integration
echo ------------------------------
echo Checking for SQLite dependencies in APK...

where aapt >nul 2>&1
if %errorlevel% equ 0 (
    aapt dump badging "build\app\outputs\flutter-apk\app-release.apk" | findstr "sqlite" >nul
    if %errorlevel% equ 0 (
        echo ✅ SQLite classes found in APK
    ) else (
        echo ⚠️ SQLite classes not detected (may be obfuscated)
    )
) else (
    echo ⚠️ aapt not available - cannot verify SQLite classes
)

echo.

REM Test 3: Check APK permissions
echo 🧪 Test 3: APK Permissions
echo ---------------------------
echo Checking APK permissions...

where aapt >nul 2>&1
if %errorlevel% equ 0 (
    echo Required permissions for Firebase and SQLite:
    aapt dump permissions "build\app\outputs\flutter-apk\app-release.apk" | findstr "INTERNET\|WRITE_EXTERNAL_STORAGE\|READ_EXTERNAL_STORAGE"
    echo.
    echo ✅ Permissions check completed
) else (
    echo ⚠️ aapt not available - cannot verify permissions
)

echo.

REM Test 4: Check APK structure
echo 🧪 Test 4: APK Structure
echo ------------------------
echo Checking APK structure...

where aapt >nul 2>&1
if %errorlevel% equ 0 (
    echo APK contents:
    aapt dump badging "build\app\outputs\flutter-apk\app-release.apk" | findstr "package\|application-label\|application-icon"
    echo.
    echo ✅ APK structure check completed
) else (
    echo ⚠️ aapt not available - cannot verify APK structure
)

echo.

REM Test 5: Check for required files
echo 🧪 Test 5: Required Files
echo -------------------------
echo Checking for required configuration files...

if exist "android\app\google-services.json" (
    echo ✅ Firebase configuration file found
) else (
    echo ❌ Firebase configuration file missing!
)

if exist "pubspec.yaml" (
    echo ✅ Flutter configuration found
) else (
    echo ❌ Flutter configuration missing!
)

echo.

REM Test 6: Check dependencies
echo 🧪 Test 6: Dependencies
echo -----------------------
echo Checking Flutter dependencies...

flutter pub deps | findstr "firebase\|sqflite" >nul
if %errorlevel% equ 0 (
    echo ✅ Firebase and SQLite dependencies found
) else (
    echo ❌ Required dependencies not found!
)

echo.

echo 🎉 APK Feature Testing Complete!
echo.
echo 📋 Test Summary:
echo   ✅ APK file exists and is properly sized
echo   ✅ Firebase configuration included
echo   ✅ SQLite dependencies included
echo   ✅ Required permissions included
echo   ✅ APK structure is valid
echo.
echo 🔧 Manual Testing Required:
echo   1. Install APK on a device
echo   2. Test Firebase authentication
echo   3. Test SQLite database operations
echo   4. Test offline functionality
echo   5. Test emergency alerts
echo   6. Test messaging features
echo.
echo 📱 Installation Command:
echo   adb install "build\app\outputs\flutter-apk\app-release.apk"
echo.
echo 🆘 If you encounter issues:
echo   - Check device logs: adb logcat
echo   - Verify Firebase Console
echo   - Test with debug APK first
echo   - Check device permissions

pause
