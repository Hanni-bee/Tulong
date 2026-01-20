# Flutter Installation and Verification Script for Windows
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Flutter Installation & Verification" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# Step 1: Check if Flutter is already installed
Write-Host "[1/6] Checking for existing Flutter installation..." -ForegroundColor Yellow

$flutterPaths = @(
    "$env:LOCALAPPDATA\flutter\bin\flutter.exe",
    "$env:ProgramFiles\flutter\bin\flutter.exe",
    "$env:ProgramFiles(x86)\flutter\bin\flutter.exe",
    "$env:USERPROFILE\flutter\bin\flutter.exe",
    "C:\flutter\bin\flutter.exe",
    "C:\src\flutter\bin\flutter.exe"
)

$flutterPath = $null
foreach ($path in $flutterPaths) {
    if (Test-Path $path) {
        $flutterPath = $path
        Write-Host "✅ Found Flutter at: $flutterPath" -ForegroundColor Green
        break
    }
}

# Check PATH
try {
    $flutterFromPath = Get-Command flutter -ErrorAction SilentlyContinue
    if ($flutterFromPath) {
        $flutterPath = $flutterFromPath.Source
        Write-Host "✅ Found Flutter in PATH: $flutterPath" -ForegroundColor Green
    }
} catch {
    # Continue
}

if ($flutterPath) {
    Write-Host ""
    Write-Host "[2/6] Verifying Flutter installation..." -ForegroundColor Yellow
    & $flutterPath doctor -v
    Write-Host ""
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Flutter is installed and accessible!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Running full Flutter doctor check..." -ForegroundColor Cyan
        & $flutterPath doctor
        exit 0
    }
}

# Flutter not found - Installation needed
Write-Host "❌ Flutter not found. Installation required." -ForegroundColor Red
Write-Host ""

# Step 2: Check prerequisites
Write-Host "[2/6] Checking prerequisites..." -ForegroundColor Yellow

# Check Git
$gitInstalled = $false
try {
    $gitVersion = git --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Git is installed: $gitVersion" -ForegroundColor Green
        $gitInstalled = $true
    }
} catch {
    Write-Host "❌ Git is not installed" -ForegroundColor Red
}

if (-not $gitInstalled) {
    Write-Host ""
    Write-Host "⚠️  Git is required for Flutter installation." -ForegroundColor Yellow
    Write-Host "Please install Git from: https://git-scm.com/download/win" -ForegroundColor Yellow
    Write-Host "Or install Git via winget: winget install --id Git.Git -e --source winget" -ForegroundColor Yellow
    Write-Host ""
    $continue = Read-Host "Continue anyway? (y/n)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        exit 1
    }
}

# Step 3: Determine installation location
Write-Host ""
Write-Host "[3/6] Preparing installation..." -ForegroundColor Yellow

$installLocation = "$env:LOCALAPPDATA\flutter"
if (-not (Test-Path $installLocation)) {
    New-Item -ItemType Directory -Path $installLocation -Force | Out-Null
}

Write-Host "Installation location: $installLocation" -ForegroundColor Cyan

# Step 4: Download Flutter
Write-Host ""
Write-Host "[4/6] Downloading Flutter SDK..." -ForegroundColor Yellow
Write-Host "This may take several minutes depending on your internet connection..." -ForegroundColor Cyan

$flutterZip = "$env:TEMP\flutter_windows.zip"
$flutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip"

try {
    Write-Host "Downloading from: $flutterUrl" -ForegroundColor Cyan
    Invoke-WebRequest -Uri $flutterUrl -OutFile $flutterZip -UseBasicParsing
    
    if (Test-Path $flutterZip) {
        Write-Host "✅ Download complete!" -ForegroundColor Green
    } else {
        Write-Host "❌ Download failed!" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Download failed: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Alternative: You can manually download Flutter from:" -ForegroundColor Yellow
    Write-Host "https://docs.flutter.dev/get-started/install/windows" -ForegroundColor Yellow
    exit 1
}

# Step 5: Extract Flutter
Write-Host ""
Write-Host "[5/6] Extracting Flutter SDK..." -ForegroundColor Yellow

try {
    # Remove existing flutter directory if it exists
    if (Test-Path $installLocation) {
        Remove-Item -Path $installLocation -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Extract to parent directory (zip contains flutter folder)
    $extractPath = Split-Path $installLocation -Parent
    Expand-Archive -Path $flutterZip -DestinationPath $extractPath -Force
    
    Write-Host "✅ Extraction complete!" -ForegroundColor Green
    
    # Clean up zip file
    Remove-Item $flutterZip -Force -ErrorAction SilentlyContinue
} catch {
    Write-Host "❌ Extraction failed: $_" -ForegroundColor Red
    exit 1
}

# Verify extraction
$flutterExe = "$installLocation\bin\flutter.exe"
if (-not (Test-Path $flutterExe)) {
    Write-Host "❌ Flutter extraction verification failed!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Flutter SDK installed at: $installLocation" -ForegroundColor Green

# Step 6: Add to PATH and verify
Write-Host ""
Write-Host "[6/6] Configuring environment..." -ForegroundColor Yellow

$flutterBinPath = "$installLocation\bin"

# Add to PATH for current session
$env:PATH = "$flutterBinPath;$env:PATH"

# Add to user PATH permanently
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$flutterBinPath*") {
    Write-Host "Adding Flutter to user PATH..." -ForegroundColor Cyan
    
    if ($isAdmin) {
        [Environment]::SetEnvironmentVariable("Path", "$userPath;$flutterBinPath", "User")
        Write-Host "✅ Flutter added to PATH (permanent)" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Administrator rights required to add to PATH permanently." -ForegroundColor Yellow
        Write-Host "   Flutter is available in this session only." -ForegroundColor Yellow
        Write-Host "   To add permanently, run this script as Administrator or manually add:" -ForegroundColor Yellow
        Write-Host "   $flutterBinPath" -ForegroundColor Cyan
        Write-Host "   to your PATH environment variable." -ForegroundColor Yellow
    }
} else {
    Write-Host "✅ Flutter already in PATH" -ForegroundColor Green
}

# Verify installation
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Verifying Flutter Installation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

& $flutterExe doctor -v

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Running Flutter Doctor" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

& $flutterExe doctor

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Review the Flutter doctor output above" -ForegroundColor Yellow
Write-Host "2. Install any missing dependencies (Android Studio, VS Code, etc.)" -ForegroundColor Yellow
Write-Host "3. Accept Android licenses: flutter doctor --android-licenses" -ForegroundColor Yellow
Write-Host "4. Restart your terminal/PowerShell for PATH changes to take effect" -ForegroundColor Yellow
Write-Host ""




