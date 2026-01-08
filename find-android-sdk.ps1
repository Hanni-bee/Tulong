# Script to find and configure Android SDK

Write-Host "`n=== Finding Android SDK ===" -ForegroundColor Cyan

# Check common locations
$searchPaths = @(
    "$env:LOCALAPPDATA\Android\Sdk",
    "$env:USERPROFILE\AppData\Local\Android\Sdk",
    "C:\Android\Sdk",
    "C:\Users\$env:USERNAME\AppData\Local\Android\Sdk",
    "C:\Program Files\Android\Android Studio\sdk",
    "C:\Program Files\Android\Android Studio1\sdk"
)

$foundSdk = $null

foreach ($path in $searchPaths) {
    if (Test-Path $path) {
        $adbPath = Join-Path $path "platform-tools\adb.exe"
        if (Test-Path $adbPath) {
            Write-Host "`n✅ Found Android SDK at: $path" -ForegroundColor Green
            Write-Host "   ✅ ADB found at: $adbPath" -ForegroundColor Green
            $foundSdk = $path
            break
        } else {
            Write-Host "⚠️ Found folder but no ADB: $path" -ForegroundColor Yellow
        }
    }
}

if ($foundSdk) {
    Write-Host "`n=== Updating Configuration ===" -ForegroundColor Cyan
    
    # Update local.properties
    $localProps = "android\local.properties"
    $sdkDir = $foundSdk.Replace('\', '\\')
    $content = @"
sdk.dir=$sdkDir
flutter.sdk=C:\\flutter
flutter.buildMode=release
flutter.versionName=1.0.0
flutter.versionCode=1
"@
    Set-Content -Path $localProps -Value $content
    Write-Host "✅ Updated android/local.properties" -ForegroundColor Green
    
    # Set environment variable for current session
    $env:ANDROID_HOME = $foundSdk
    Write-Host "✅ Set ANDROID_HOME for current session" -ForegroundColor Green
    
    Write-Host "`n=== Next Steps ===" -ForegroundColor Cyan
    Write-Host "1. I-restart ang terminal para ma-load ang ANDROID_HOME permanently" -ForegroundColor Yellow
    Write-Host "2. O i-run: `$env:ANDROID_HOME = '$foundSdk'" -ForegroundColor Yellow
    Write-Host "3. I-run: flutter build apk --release" -ForegroundColor Yellow
    
} else {
    Write-Host "`n❌ Android SDK not found in common locations" -ForegroundColor Red
    Write-Host "`nPlease:" -ForegroundColor Yellow
    Write-Host "1. Buksan ang Android Studio" -ForegroundColor White
    Write-Host "2. Tools > SDK Manager" -ForegroundColor White
    Write-Host "3. Tignan ang 'Android SDK Location'" -ForegroundColor White
    Write-Host "4. I-tell sa akin ang path, o i-run ang script na ito ulit pagkatapos" -ForegroundColor White
}

Write-Host ""


