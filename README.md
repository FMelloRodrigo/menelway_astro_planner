# MENELWAY — Astro Target & Session Planner

**MENELWAY** is a high-performance, native desktop application for visual astronomy and deep-sky astrophotography session planning. It couples a blazing-fast C++ calculation core with a modern Flutter user interface, running offline with self-contained databases and ephemerides.

---

## Key Features

- **Comprehensive Object Catalogs**: Over 13,000 deep-sky objects (Messier, Caldwell, NGC, IC, Arp, Herschel 400), plus solar system planets and 80+ navigational/bright stars with real-time VSOP87/ELP2000 ephemeris calculations.
- **Deep-Sky & Night Filtering**: Real-time altitude curves, transit times, darkness intervals (civil, nautical, astronomical dusk/dawn), moon separation, and moon illumination calculation.
- **Yearly Observing Window**: Annual visibility solver computing rise/set curves across all 365 days, optimal observation windows, and peak observing dates.
- **Period Planner**: Search targets observable within future date intervals (e.g. upcoming 7 days, 14 days, next month) with Moon phase analysis.
- **Equipment Framing Simulator**: Focal length and sensor dimension framing simulator with FOV overlays, visual target dimensions, and interactive panning and zooming.
- **Observing Lists & Notes**: User-curated observing plans stored in a local SQLite database with SQLite FTS5 full-text search.
- **Telescope Red Night-Vision Mode**: Complete dark-adaptation red theme with high contrast and zero blinding UI elements.
- **Bilingual Support**: Full internationalization for English and Portuguese (Brasil).

---

## Architecture Overview

```
astro_targets_tool/
├── core/                       # C++ Engine & Storage
│   ├── include/astro/          # C++ headers (ephemeris, coordinates, time, storage, catalogs)
│   ├── src/                    # C++ implementations (VSOP87, ELP2000, Meeus algorithms)
│   ├── capi/                   # C ABI export interface for Dart FFI (astro_capi.cpp / .h)
│   ├── data/                   # Catalogs SQLite database and python seeding scripts
│   └── tests/                  # Standalone C++ unit test suite (test_astro, test_storage, test_capi)
│
├── app/                        # Flutter Desktop UI (Windows x64)
│   ├── lib/
│   │   ├── core/               # Dart FFI bindings (AstroEngine, AstroBridge)
│   │   ├── models/             # TargetItem, FilterState, NightSummary, YearlyVisibility
│   │   ├── theme/              # Deep space dark & red night-vision themes (AstroPalette)
│   │   └── views/              # Responsive desktop/mobile views and modular dialogs
│   └── test/                   # Comprehensive Flutter unit and widget tests
│
├── dist/                       # Packaged standalone Windows portable releases
├── scripts/data_tools/         # Data extraction and parsing utilities
└── package_portable_release.ps1 # Automated release packaging pipeline
```

---

## Building from Source

### Prerequisites

- **Windows 10/11 x64**
- **Visual Studio 2022** with "Desktop development with C++" and MSBuild
- **CMake 3.20+**
- **Flutter SDK 3.x+** with Windows Desktop support enabled (`flutter config --enable-windows-desktop`)

### 1. Compile C++ Core Engine

```powershell
# From workspace root
& "C:\Development\Programas\Visual Studio\MSBuild\Current\Bin\MSBuild.exe" "core\build\astro_core.sln" /p:Configuration=Release /p:Platform=x64
```

This compiles `core/build/Release/astro_core.dll` and test binaries (`test_astro.exe`, `test_storage.exe`, `test_capi.exe`).

### 2. Run C++ Tests

```powershell
.\core\build\Release\test_astro.exe
.\core\build\Release\test_storage.exe
.\core\build\Release\test_capi.exe
```

### 3. Build Flutter Windows Release

```powershell
cd app
flutter test
flutter build windows --release --no-tree-shake-icons
cd ..
```

### 4. Package Portable Distribution

```powershell
powershell -ExecutionPolicy Bypass -File package_portable_release.ps1
```

The resulting standalone distribution is output to `dist/astro_targets_planner_win64_portable/`.

---

## License

MIT License. See LICENSE for details.
