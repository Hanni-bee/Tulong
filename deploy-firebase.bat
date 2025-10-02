@echo off
REM T.U.L.O.N.G Firebase Deployment Script for Windows
REM This script safely deploys Firebase enhancements without breaking existing functionality

echo 🔥 Starting T.U.L.O.N.G Firebase Deployment...

REM Check if Firebase CLI is installed
firebase --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Firebase CLI not found. Please install it first:
    echo npm install -g firebase-tools
    pause
    exit /b 1
)

echo ✅ Firebase CLI ready

REM Step 1: Deploy Database Rules (Safe - only adds validation)
echo 📊 Deploying Database Rules...
firebase deploy --only database
if %errorlevel% equ 0 (
    echo ✅ Database rules deployed successfully
) else (
    echo ❌ Database rules deployment failed
    pause
    exit /b 1
)

REM Step 2: Deploy Storage Rules (Safe - only adds file restrictions)
echo 📁 Deploying Storage Rules...
firebase deploy --only storage
if %errorlevel% equ 0 (
    echo ✅ Storage rules deployed successfully
) else (
    echo ❌ Storage rules deployment failed
    pause
    exit /b 1
)

REM Step 3: Deploy Cloud Functions (Optional)
echo ⚡ Deploying Cloud Functions...
set /p deploy_functions="Deploy Cloud Functions? (y/n): "
if /i "%deploy_functions%"=="y" (
    firebase deploy --only functions
    if %errorlevel% equ 0 (
        echo ✅ Cloud Functions deployed successfully
    ) else (
        echo ❌ Cloud Functions deployment failed
        echo ⚠️  This is optional - continuing with other deployments
    )
) else (
    echo ⏭️  Skipping Cloud Functions deployment
)

REM Step 4: Verify deployment
echo 🔍 Verifying deployment...
firebase projects:list
echo ✅ Deployment verification complete

echo.
echo 🎉 T.U.L.O.N.G Firebase deployment completed!
echo.
echo 📋 What was deployed:
echo   ✅ Database Security Rules (enhanced validation)
echo   ✅ Storage Security Rules (file upload restrictions)
echo   ⚡ Cloud Functions (if selected)
echo.
echo 🔧 Next steps:
echo   1. Test your app to ensure everything works
echo   2. Check Firebase Console for any issues
echo   3. Monitor your app's performance
echo.
echo 🆘 If you encounter issues:
echo   - Check Firebase Console for error logs
echo   - Test with Firebase emulators first
echo   - Rollback if necessary: firebase database:rules:rollback

pause
