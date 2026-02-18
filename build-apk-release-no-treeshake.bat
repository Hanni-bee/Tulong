@echo off
REM T.U.L.O.N.G - Release APK build with NO tree-shake-icons
REM Use this if release build has icon/font issues

echo Building release APK (no tree-shake icons)...
cd /d "%~dp0"

flutter build apk --release --no-tree-shake-icons
if %errorlevel% neq 0 (
    echo Build failed.
    pause
    exit /b 1
)

if exist "build\app\outputs\flutter-apk\app-release.apk" (
    echo.
    echo APK built: build\app\outputs\flutter-apk\app-release.apk
) else (
    echo APK not found. Check build logs.
)
pause
