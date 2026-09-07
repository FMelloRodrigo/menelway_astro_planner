---
trigger: always_on
---

# Always Build Windows Release

Whenever changes are made to the codebase (C++ engine, Dart models, or Flutter UI), you MUST always compile and build the Windows release before concluding the task:

1. If C++ core files are modified, compile `core\build\astro_core.sln` using MSBuild:
   ```powershell
   & "C:\Development\Programas\Visual Studio\MSBuild\Current\Bin\MSBuild.exe" "core\build\astro_core.sln" /p:Configuration=Release /p:Platform=x64
   ```
2. Build the Flutter Windows release application:
   ```powershell
   # In app directory
   flutter build windows --release --no-tree-shake-icons
   ```
3. Run the portable release packager from workspace root:
   ```powershell
   powershell -ExecutionPolicy Bypass -File package_portable_release.ps1
   ```
4. Confirm to the user that the Windows binary at `app\build\windows\x64\runner\Release\app.exe` and portable release at `dist\astro_targets_planner_win64_portable\astro_targets_planner.exe` are ready for testing.
