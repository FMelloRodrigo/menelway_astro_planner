# Menelway Astro Planner - Flutter Application

Frontend desktop application for visual astronomy and deep-sky astrophotography planning.

## Architecture

- **`lib/core/`**: Dart FFI bridges to C++ native calculation engine (`astro_core`), catalog manager, and application logging.
- **`lib/models/`**: Domain models including `TargetItem`, `FilterState`, `NightSummary`, `YearlyVisibility`, and user lists.
- **`lib/theme/`**: Theme system supporting standard Deep Space Obsidian and dark-adaptation Red Night-Vision mode via `AstroPalette`.
- **`lib/views/`**: Master/detail view layouts for Targets, Solar System, Bright Stars, Planner, Favorites, and Observing Lists.
- **`lib/widgets/`**: Custom painters and interactive components (`AltitudeCurveChart`, `TargetPreviewCanvas`, `FovProjector`).

## Testing & Quality

Run the test suite and static analysis:

```powershell
flutter analyze
flutter test
```
