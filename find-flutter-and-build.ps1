# Find Flutter and Build Release APK
Write-Host "🔍 Searching for Flutter installation..." -ForegroundColor Cyan

$flutterPaths = @(
    "$env:LOCALAPPDATA\flutter\bin\flutter.exe",
    "$env:ProgramFiles\flutter\bin\flutter.exe",
    "$env:ProgramFiles(x86)\flutter\bin\flutter.exe",
    "$env:USERPROFILE\flutter\bin\flutter.exe",
    "C:\flutter\bin\flutter.exe",
    "C:\src\flutter\bin\flutter.exe",
    "$env:FLUTTER_ROOT\bin\flutter.exe"
)

$flutterPath = $null
foreach ($path in $flutterPaths) {
    if (Test-Path $path) {
        $flutterPath = $path
        Write-Host "✅ Found Flutter at: $flutterPath" -ForegroundColor Green
        break
    }
}

if (-not $flutterPath) {
    Write-Host "❌ Flutter not found in common locations." -ForegroundColor Red
    Write-Host ""
    Write-Host "Please do one of the following:" -ForegroundColor Yellow
    Write-Host "1. Install Flutter from: https://flutter.dev/docs/get-started/install/windows" -ForegroundColor Yellow
    Write-Host "2. Add Flutter to your PATH environment variable" -ForegroundColor Yellow
    Write-Host "3. Run this script with Flutter path: .\find-flutter-and-build.ps1 -FlutterPath 'C:\path\to\flutter\bin\flutter.exe'" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "🚀 Building Release APK..." -ForegroundColor Cyan
Write-Host ""

# Change to project directory
Set-Location $PSScriptRoot

# Run Flutter build
& $flutterPath build apk --release

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ APK built successfully!" -ForegroundColor Green
    Write-Host "📁 Location: build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Cyan
    
    $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $apkPath) {
        $apkSize = (Get-Item $apkPath).Length / 1MB
        Write-Host "📊 APK Size: $([math]::Round($apkSize, 2)) MB" -ForegroundColor Cyan
    }
} else {
    Write-Host ""
    Write-Host "Build failed. Check the error messages above." -ForegroundColor Red
    exit 1
}

