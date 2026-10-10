# Packaging script for Astro Targets Planner (Windows 10/11 x64 Portable)
$ErrorActionPreference = "Stop"

$workspaceRoot = $PSScriptRoot
$releaseDir = Join-Path $workspaceRoot "app\build\windows\x64\runner\Release"
$distDirLegacy = Join-Path $workspaceRoot "dist\astro_targets_planner_win64_portable"
$distDirMenelway = Join-Path $workspaceRoot "dist\menelway_astro_planner_win64_portable"
$zipFileLegacy = Join-Path $workspaceRoot "dist\astro_targets_planner_win64_portable.zip"
$zipFileMenelway = Join-Path $workspaceRoot "dist\menelway_astro_planner_win64_portable.zip"

Write-Host "Creating portable release bundle..." -ForegroundColor Cyan

# Close any running instances to release file locks on binaries and DLLs
Get-Process -Name "menelway_astro_planner", "astro_targets_planner", "app" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 600

# 1. Ensure runner Release dir has menelway_astro_planner.exe directly
if (Test-Path "$releaseDir\app.exe") {
    Copy-Item "$releaseDir\app.exe" "$releaseDir\menelway_astro_planner.exe" -Force
}

# 1b. Backup user configuration and terrain cache to prevent wiping on repackage
$tempBackupDir = Join-Path $env:TEMP "astro_settings_backup_$(Get-Random)"
New-Item -ItemType Directory -Path "$tempBackupDir\terrain_cache" -Force | Out-Null

$sourceTerrain = if (Test-Path "$distDirMenelway\terrain_cache") { "$distDirMenelway\terrain_cache" } elseif (Test-Path "$releaseDir\terrain_cache") { "$releaseDir\terrain_cache" } else { $null }
if ($sourceTerrain) {
    Get-ChildItem -Path $sourceTerrain -Filter "*.json" -Recurse -File | Copy-Item -Destination "$tempBackupDir\terrain_cache" -Force
}

if (Test-Path "$distDirMenelway\user_settings.json") {
    Copy-Item "$distDirMenelway\user_settings.json" -Destination "$tempBackupDir\user_settings.json" -Force
} elseif (Test-Path "$releaseDir\user_settings.json") {
    Copy-Item "$releaseDir\user_settings.json" -Destination "$tempBackupDir\user_settings.json" -Force
}

# 2. Clean previous dist bundles
if (Test-Path $distDirLegacy) { Remove-Item $distDirLegacy -Recurse -Force }
if (Test-Path $distDirMenelway) { Remove-Item $distDirMenelway -Recurse -Force }
if (Test-Path $zipFileLegacy) { Remove-Item $zipFileLegacy -Force }
if (Test-Path $zipFileMenelway) { Remove-Item $zipFileMenelway -Force }

New-Item -ItemType Directory -Path $distDirMenelway -Force | Out-Null

# Clean nested terrain_cache in releaseDir if present before copying release files
if (Test-Path "$releaseDir\terrain_cache") {
    Remove-Item "$releaseDir\terrain_cache" -Recurse -Force
}

# Copy release files to Menelway dist folder
Copy-Item "$releaseDir\*" -Destination $distDirMenelway -Recurse -Force

# Ensure menelway_astro_planner.exe is the sole executable in the portable distribution
if (Test-Path "$distDirMenelway\app.exe") {
    Copy-Item "$distDirMenelway\app.exe" "$distDirMenelway\menelway_astro_planner.exe" -Force
    Remove-Item "$distDirMenelway\app.exe" -Force
}
if (Test-Path "$distDirMenelway\astro_targets_planner.exe") {
    Remove-Item "$distDirMenelway\astro_targets_planner.exe" -Force
}

# Ensure catalogs.db is also at root for easy standalone inspection
if (Test-Path "$distDirMenelway\data\flutter_assets\assets\catalogs.db") {
    Copy-Item "$distDirMenelway\data\flutter_assets\assets\catalogs.db" "$distDirMenelway\catalogs.db" -Force
}

# Restore user configuration and terrain cache into dist and runner
if ((Get-ChildItem "$tempBackupDir\terrain_cache" -File).Count -gt 0) {
    New-Item -ItemType Directory -Path "$distDirMenelway\terrain_cache" -Force | Out-Null
    Copy-Item "$tempBackupDir\terrain_cache\*" -Destination "$distDirMenelway\terrain_cache" -Force
    New-Item -ItemType Directory -Path "$releaseDir\terrain_cache" -Force | Out-Null
    Copy-Item "$tempBackupDir\terrain_cache\*" -Destination "$releaseDir\terrain_cache" -Force
}
if (Test-Path "$tempBackupDir\user_settings.json") {
    Copy-Item "$tempBackupDir\user_settings.json" -Destination "$distDirMenelway\user_settings.json" -Force
    Copy-Item "$tempBackupDir\user_settings.json" -Destination "$releaseDir\user_settings.json" -Force
}
Remove-Item $tempBackupDir -Recurse -Force -ErrorAction SilentlyContinue

# Write README
$readmeContent = @"
===================================================================
  MENELWAY ASTRO PLANNER - PORTABLE WINDOWS RELEASE (x64)
===================================================================

An offline-first, high-performance astrophotography and stargazing 
target and session planner.

Features:
- Built with modern C++20 astronomy math engine (libastro_core).
- Offline SQLite DSO catalog (~14,148 objects: Messier, Caldwell, Arp, Herschel, NGC, IC, Sharpless, Barnard).
- Interactive Altitude vs Time curve chart with twilight bands and ceiling lines.
- Deep-sky visibility filter: reach altitude >= X for >= Y hours.
- Sky quadrant and degree range azimuth sector filtering.
- Moon separation constraints.
- Custom Horizon Maker & Obstruction Profile with 360° cylindrical panorama calibration.
- Focal length & sensor framing simulator with rotator angle and custom telescope/camera database.
- Custom observing lists / session planner stored locally.
- Telescope Red Night-Vision mode to preserve dark adaptation.

HOW TO RUN:
1. Double-click 'menelway_astro_planner.exe'.
2. Zero installation or admin rights required! 
   You can run this directly from any folder or USB drive.

SYSTEM REQUIREMENTS:
- Windows 10 x64 or Windows 11 x64.
"@

Set-Content -Path "$distDirMenelway\README.txt" -Value $readmeContent

# Compress into zip package
Write-Host "Compressing into $zipFileMenelway..." -ForegroundColor Cyan
Compress-Archive -Path "$distDirMenelway\*" -DestinationPath $zipFileMenelway -Force

$zipSizeMb = (Get-Item $zipFileMenelway).Length / 1MB
Write-Host "Portable package created successfully!" -ForegroundColor Green
Write-Host "  Zip Path: $zipFileMenelway" -ForegroundColor Green
Write-Host "  Zip Size: $([math]::Round($zipSizeMb, 2)) MB" -ForegroundColor Green

# Copy release APK to dist if present
$apkSource = Join-Path $workspaceRoot "app\build\app\outputs\flutter-apk\app-release.apk"
$apkDist = Join-Path $workspaceRoot "dist\menelway_astro_planner.apk"
if (Test-Path $apkSource) {
    Copy-Item $apkSource $apkDist -Force
    $apkSizeMb = (Get-Item $apkDist).Length / 1MB
    Write-Host "  APK Path: $apkDist" -ForegroundColor Green
    Write-Host "  APK Size: $([math]::Round($apkSizeMb, 2)) MB" -ForegroundColor Green
}
