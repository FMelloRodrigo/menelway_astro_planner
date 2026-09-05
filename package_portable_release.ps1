# Packaging script for Astro Targets Planner (Windows 10/11 x64 Portable)
$ErrorActionPreference = "Stop"

$workspaceRoot = $PSScriptRoot
$releaseDir = Join-Path $workspaceRoot "app\build\windows\x64\runner\Release"
$distDir = Join-Path $workspaceRoot "dist\astro_targets_planner_win64_portable"
$zipFile = Join-Path $workspaceRoot "dist\astro_targets_planner_win64_portable.zip"

Write-Host "Creating portable release bundle..." -ForegroundColor Cyan

if (Test-Path $distDir) {
    Remove-Item $distDir -Recurse -Force
}
if (Test-Path $zipFile) {
    Remove-Item $zipFile -Force
}

New-Item -ItemType Directory -Path $distDir -Force | Out-Null

# Copy release files
Copy-Item "$releaseDir\*" -Destination $distDir -Recurse -Force

# Create descriptive executable alias
if (Test-Path "$distDir\app.exe") {
    Copy-Item "$distDir\app.exe" "$distDir\astro_targets_planner.exe" -Force
}

# Ensure catalogs.db is also at root for easy standalone inspection
if (Test-Path "$distDir\data\flutter_assets\assets\catalogs.db") {
    Copy-Item "$distDir\data\flutter_assets\assets\catalogs.db" "$distDir\catalogs.db" -Force
}

# Write README
$readmeContent = @"
===================================================================
  ASTRO TARGETS PLANNER - PORTABLE WINDOWS RELEASE (x64)
===================================================================

An offline-first, high-performance astrophotography and stargazing 
target planner inspired by Telescopius.

Features:
- Built with modern C++20 astronomy math engine (libastro_core).
- Offline SQLite DSO catalog (~14,027 objects: Messier, Caldwell, NGC, IC, Sharpless, Barnard).
- Altitude vs Time interactive curve chart with twilight bands.
- Telescopius visibility filter: reach altitude >= X for >= Y hours.
- Sky quadrant and degree range azimuth filtering.
- Moon separation constraints.
- Custom observing lists / session planner stored locally.
- Telescope Red Night-Vision mode to preserve dark adaptation.

HOW TO RUN:
1. Double-click 'astro_targets_planner.exe' (or 'app.exe').
2. Zero installation or admin rights required! 
   You can run this directly from any folder or USB drive.

SYSTEM REQUIREMENTS:
- Windows 10 x64 or Windows 11 x64.
"@

Set-Content -Path "$distDir\README.txt" -Value $readmeContent

# Compress into zip package
Write-Host "Compressing into $zipFile..." -ForegroundColor Cyan
Compress-Archive -Path "$distDir\*" -DestinationPath $zipFile -Force

$zipSizeMb = (Get-Item $zipFile).Length / 1MB
Write-Host "Portable package created successfully!" -ForegroundColor Green
Write-Host "  Zip Path: $zipFile" -ForegroundColor Green
Write-Host "  Zip Size: $([math]::Round($zipSizeMb, 2)) MB" -ForegroundColor Green
