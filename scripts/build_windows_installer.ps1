# Build and Package Reminda Windows Desktop Installer
# Reads version dynamically from pubspec.yaml as Single Source of Truth

$ErrorActionPreference = "Stop"

Write-Host "Extracting version from pubspec.yaml..." -ForegroundColor Cyan
$pubspec = Get-Content "pubspec.yaml"
$versionLine = $pubspec | Select-String '^version:\s*([^\s]+)'
if (-not $versionLine) {
    Write-Error "Could not find 'version:' line in pubspec.yaml"
    exit 1
}
$version = $versionLine.Matches.Groups[1].Value
Write-Host "Detected version: $version" -ForegroundColor Green

Write-Host "Building Flutter Windows Release..." -ForegroundColor Cyan
flutter build windows --release --no-tree-shake-icons

# Check for Inno Setup compiler
$iscc = Get-Command "iscc" -ErrorAction SilentlyContinue
if (-not $iscc) {
    $potentialPaths = @(
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        "C:\Program Files\Inno Setup 6\ISCC.exe"
    )
    foreach ($p in $potentialPaths) {
        if (Test-Path $p) {
            $iscc = $p
            break
        }
    }
}

if ($iscc) {
    Write-Host "Compiling Inno Setup installer with dynamic version ($version)..." -ForegroundColor Cyan
    & $iscc "/DMyAppVersion=$version" "windows\installer.iss"
    Write-Host "Installer compiled successfully!" -ForegroundColor Green
} else {
    Write-Host "Notice: Inno Setup (ISCC.exe) not found in PATH or standard Program Files directories." -ForegroundColor Yellow
    Write-Host "To compile the installer manually: iscc /DMyAppVersion=$version windows\installer.iss" -ForegroundColor Yellow
}
