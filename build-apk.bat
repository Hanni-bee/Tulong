@echo off
REM T.U.L.O.N.G APK Build Script for Windows
REM This script builds the APK with Firebase and SQLite features

echo 🔥 Starting T.U.L.O.N.G APK Build...
echo =====================================

REM Check if Flutter is installed
flutter --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Flutter not found. Please install Flutter first.
    pause
    exit /b 1
)

echo ✅ Flutter CLI ready

REM Clean previous builds
echo 🧹 Cleaning previous builds...
flutter clean
if %errorlevel% neq 0 (
    echo ❌ Clean failed
    pause
    exit /b 1
)

echo ✅ Clean completed

REM Get dependencies
echo 📦 Getting dependencies...
flutter pub get
if %errorlevel% neq 0 (
    echo ❌ Pub get failed
    pause
    exit /b 1
)

echo ✅ Dependencies installed

REM Check Firebase configuration
echo 🔍 Checking Firebase configuration...
if not exist "android\app\google-services.json" (
    echo ❌ Firebase configuration not found!
    echo Please ensure android\app\google-services.json exists
    pause
    exit /b 1
)

echo ✅ Firebase configuration found

REM Check SQLite dependencies
echo 🔍 Checking SQLite dependencies...
flutter pub deps | findstr "sqflite" >nul
if %errorlevel% neq 0 (
    echo ❌ SQLite dependency not found!
    echo Please ensure sqflite is in pubspec.yaml
    pause
    exit /b 1
)

echo ✅ SQLite dependency found

REM Build APK
echo 🔨 Building APK...
flutter build apk --release
if %errorlevel% neq 0 (
    echo ❌ APK build failed
    pause
    exit /b 1
)

echo ✅ APK built successfully

REM Check if APK exists
if exist "build\app\outputs\flutter-apk\app-release.apk" (
    echo ✅ APK file created: build\app\outputs\flutter-apk\app-release.apk
    
    REM Get APK size
    for %%A in ("build\app\outputs\flutter-apk\app-release.apk") do (
        echo 📊 APK Size: %%~zA bytes
    )
    
    echo.
    echo 🎉 APK Build Complete!
    echo.
    echo 📋 Build Summary:
    echo   ✅ Firebase integration included
    echo   ✅ SQLite database included
    echo   ✅ Offline functionality included
    echo   ✅ All dependencies included
    echo.
    echo 📁 APK Location: build\app\outputs\flutter-apk\app-release.apk
    echo.
    echo 🔧 Next steps:
    echo   1. Test the APK on a device
    echo   2. Verify Firebase connection
    echo   3. Test SQLite functionality
    echo   4. Test offline features
    echo.
    echo 🆘 If you encounter issues:
    echo   - Check Firebase Console for errors
    echo   - Verify device permissions
    echo   - Test with debug APK first
    
) else (
    echo ❌ APK file not found after build
    echo Check build logs for errors
)

pause
