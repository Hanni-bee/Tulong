# Flutter Setup and Release APK Build Script
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Flutter Setup and APK Build" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Find Flutter
Write-Host "[1/5] Searching for Flutter installation..." -ForegroundColor Yellow

$flutterPaths = @(
    "$env:LOCALAPPDATA\flutter\bin\flutter.exe",
    "$env:ProgramFiles\flutter\bin\flutter.exe",
    "$env:ProgramFiles(x86)\flutter\bin\flutter.exe",
    "$env:USERPROFILE\flutter\bin\flutter.exe",
    "C:\flutter\bin\flutter.exe",
    "C:\src\flutter\bin\flutter.exe",
    "$env:FLUTTER_ROOT\bin\flutter.exe"
)

# Also check PATH
try {
    $flutterFromPath = Get-Command flutter -ErrorAction SilentlyContinue
    if ($flutterFromPath) {
        $flutterPath = $flutterFromPath.Source
        Write-Host "Found Flutter in PATH: $flutterPath" -ForegroundColor Green
    }
} catch {
    # Continue searching
}

if (-not $flutterPath) {
    foreach ($path in $flutterPaths) {
        if (Test-Path $path) {
            $flutterPath = $path
            Write-Host "Found Flutter at: $flutterPath" -ForegroundColor Green
            # Add to PATH for this session
            $env:PATH = "$($flutterPath | Split-Path -Parent);$env:PATH"
            break
        }
    }
}

if (-not $flutterPath) {
    Write-Host "ERROR: Flutter not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please ensure Flutter is installed and either:" -ForegroundColor Yellow
    Write-Host "1. Add Flutter to your PATH environment variable" -ForegroundColor Yellow
    Write-Host "2. Or set FLUTTER_ROOT environment variable" -ForegroundColor Yellow
    Write-Host "3. Or install Flutter from: https://flutter.dev/docs/get-started/install/windows" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Step 2: Verify Flutter installation
Write-Host "[2/5] Verifying Flutter environment..." -ForegroundColor Yellow
& $flutterPath doctor
if ($LASTEXITCODE -ne 0) {
    Write-Host "WARNING: Flutter doctor reported issues. Continuing anyway..." -ForegroundColor Yellow
}
Write-Host ""

# Step 3: Clean previous builds
Write-Host "[3/5] Cleaning previous builds..." -ForegroundColor Yellow
& $flutterPath clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "WARNING: Clean failed, but continuing..." -ForegroundColor Yellow
}
Write-Host ""

# Step 4: Get dependencies
Write-Host "[4/5] Installing Flutter dependencies..." -ForegroundColor Yellow
& $flutterPath pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to install dependencies!" -ForegroundColor Red
    exit 1
}
Write-Host "Dependencies installed successfully!" -ForegroundColor Green
Write-Host ""

# Step 5: Build Release APK
Write-Host "[5/5] Building Release APK..." -ForegroundColor Yellow
Write-Host "This may take several minutes..." -ForegroundColor Cyan
Write-Host ""

& $flutterPath build apk --release

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "BUILD SUCCESSFUL!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    
    $apkPath = "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $apkPath) {
        $apkSize = (Get-Item $apkPath).Length / 1MB
        Write-Host "APK Location: $apkPath" -ForegroundColor Cyan
        Write-Host "APK Size: $([math]::Round($apkSize, 2)) MB" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "You can now install this APK on your Android device!" -ForegroundColor Green
    } else {
        Write-Host "WARNING: APK file not found at expected location" -ForegroundColor Yellow
    }
} else {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "BUILD FAILED!" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please check the error messages above for details." -ForegroundColor Yellow
    exit 1
}




