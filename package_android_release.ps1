# Build and Packaging script for Menelway Astro Planner (Android Release APK)
$ErrorActionPreference = "Stop"

$workspaceRoot = $PSScriptRoot
$appDir = Join-Path $workspaceRoot "app"
$distDir = Join-Path $workspaceRoot "dist"
$targetApk = Join-Path $distDir "menelway_astro_planner_android.apk"

Write-Host "Building Menelway Astro Planner Android Release APK..." -ForegroundColor Cyan

# Run flutter build in app directory
Push-Location $appDir
try {
    flutter build apk --release --no-tree-shake-icons
} finally {
    Pop-Location
}

$buildApk = Join-Path $appDir "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $buildApk)) {
    throw "Build failed: output APK not found at $buildApk"
}

if (-not (Test-Path $distDir)) {
    New-Item -ItemType Directory -Path $distDir -Force | Out-Null
}

# Ensure obsolete APK naming is cleaned up
$obsoleteApks = @(
    (Join-Path $distDir "astro_targets_planner_android.apk"),
    (Join-Path $distDir "menelway_astro_planner.apk")
)
foreach ($oldApk in $obsoleteApks) {
    if (Test-Path $oldApk) {
        Remove-Item $oldApk -Force -ErrorAction SilentlyContinue
    }
}

Copy-Item $buildApk $targetApk -Force
$apkSizeMb = [math]::Round(((Get-Item $targetApk).Length / 1MB), 2)

Write-Host "Android release APK created successfully!" -ForegroundColor Green
Write-Host "  APK Path: $targetApk" -ForegroundColor Green
Write-Host "  APK Size: $apkSizeMb MB" -ForegroundColor Green
