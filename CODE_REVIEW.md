# Code review: Menelway Astro Planner

Date: 2026-10-03. Scope: the Flutter app (`app/lib`, `app/test`), the C++ core and C API (`core/`), the Python data scripts, and the build and packaging scripts.

**Method.** `flutter analyze` reports no issues and `flutter test` passes (146 tests). The C++ code was read but not built or run. Headline findings were checked against the code. Findings marked *(reported)* come from a read-through of the code that was not re-checked line by line.

**Verdict.** The architecture is a good portfolio story, but the codebase is not yet clean enough to show. A C++ astronomy core sits behind a C ABI, Dart FFI wraps it, and a Flutter UI can swap in a `FakeAstroEngine` for tests. Most of the problems are not design flaws. They are unfinished refactors, copy-paste, and a handful of god-files.

## What reads well

- **The `AstroEngine` seam.** `MainScaffold`, `PlannerView` and `TargetDetailsSheet` accept an injected engine, so the whole UI is testable without native code.
- **Strong unit types in C++.** `Degrees`, `Radians`, `Hours` and `JulianDate` prevent unit mix-ups. The astronomy core is pure and stateless.
- **The period planner.** `prepare_period_context` plus `evaluate_period_visibility_fast` precomputes shared values, uses a closed-form early-out and scans candidates in parallel.
- **`SettingsService`.** Schema versioning, a backup file and atomic writes.
- **Painters and geometry.** Most `CustomPainter`s have real `shouldRepaint` checks. `FovProjector` and `FilterDialogController` are small, tested, and a good model for the rest.
- **Lifecycle discipline.** Controllers are disposed in most `State` classes, and most awaits are guarded with `mounted`.
- **SQL hygiene in C++.** Queries bind user input, statements use RAII (`UniqueStmt`), and `PRAGMA foreign_keys` is on.

## Critical

### 1. `AstroEngine` depends on its own implementation
[astro_engine.dart:9](app/lib/core/astro_engine.dart:9) imports the concrete `AstroBridge` and hides a service locator (`static instance`) inside the interface. This inverts dependency inversion.

**Fix:** make the interface pure, and register the implementation once in [main.dart](app/lib/main.dart).

### 2. `isRedNightMode` is passed through 19 files, about 570 occurrences
An `AstroPalette` `ThemeExtension` already exists in [astro_theme.dart](app/lib/theme/astro_theme.dart). Nothing uses it, and the theme already switches at [main.dart:82](app/lib/main.dart:82). The ternary `isRedNightMode ? nightVisionX : Colors.white` appears about 430 times.

**Fix:** delete the prop and read `AstroPalette.of(context)`. This is the biggest cleanup for the least risk.

### 3. Five near-identical list views
- [planets_view.dart](app/lib/views/planets_view.dart) and [bright_stars_view.dart](app/lib/views/bright_stars_view.dart) share about 80% of their lines. `_buildChip` and `_buildMetricPill` are byte-identical.
- `target_search_view`, `favorites_view` and `planner_view` repeat the same search, sort and 900px master/detail pattern.
- `TargetDetailsSheet(...)` is hand-built 13 times with the same arguments.

**Fix:** a generic `TargetListScaffold<T>` plus shared `InfoChip`, `MetricPill` and `TargetDetailsSheet.show`. That cuts about 1,500 lines to about 500.

### 4. God-files and god-methods

| File | Method | Lines |
|---|---|---|
| `filter_dialog.dart` | `build` | 1,076 |
| `altitude_curve_chart.dart` | `build` | 846 |
| `target_preview_canvas.dart` | `build` | 671 |
| `target_preview_canvas.dart` | `TargetVectorPainter.paint` | 617 |
| `target_details_sheet.dart` | `build` | 483 |
| `main_scaffold.dart` | `build` | about 800 |

- `TargetVectorPainter.paint` is one if/else chain on body type. A `TargetRenderer` strategy per body type fits better.
- [horizon_maker_dialog.dart](app/lib/views/horizon_maker_dialog.dart) (2,560 lines) mixes terrain downloads, geocoding, file IO, image decoding and point-editing maths.
- The `ListenableBuilder` at the top of `filter_dialog` rebuilds the whole dialog on every slider tick.

**Fix:** extract a `HorizonEditorController`, a `RefineLocationDialog`, `SkylineChart` and `TimelineChart`, and filter-dialog section widgets (time window, altitude, azimuth and so on).

### 5. `MainScaffold` is still the app's brain
[main_scaffold.dart](app/lib/views/main_scaffold.dart) bootstraps the engine, restores observing lists, loads the terrain cache, filters, persists settings, runs the tutorial and renders the shell. It holds four result lists and the filters, and refreshes them by hand with `setState` plus `_saveSettings()`.

**Fix:** one `AppController extends ChangeNotifier` owning filters, results and persistence.

### 6. Business logic and IO inside widgets
- `target_details_sheet` calls the engine, HTTP (`CatalogManager.queryOnlineObject`) and the terrain cache from `State`.
- `horizon_maker_dialog` does terrain generation, geocoding and `File.readAsBytes`.
- CSV export is copy-pasted in `favorites_view` and `observing_lists_view`. Neither copy escapes embedded quotes, and the two use different columns.
- Season-status maths lives in `target_details_sheet`, and RA/Dec formatting lives in `equipment_framing_dialog`.

**Fix:** extract view-models or services (`TargetDetailsController`, `CsvExporter`, `SeasonStatus`).

### 7. Singletons everywhere

| Singleton | Uses |
|---|---|
| `EquipmentManager.instance` | 63 |
| `ObservingSiteManager.instance` | 25 |
| `FavoritesManager.instance` | 19 |

Services such as `SettingsService`, `CatalogManager`, `GeocodingService` and `TerrainCacheService` are static and called straight from widgets. Only the engine is injectable, so DI is inconsistent.

**Fix:** inject them via constructors or an `InheritedNotifier`/`Provider`.

### 8. The engine runs on the UI thread
There is no `Isolate` or `compute` anywhere. `Future.microtask(...)` around a synchronous FFI call only defers it by one microtask ([main_scaffold.dart:229](app/lib/views/main_scaffold.dart:229)), and the same pattern is in `target_details_sheet` and `planner_view`. The period planner scans many nights and will jank.

**Fix:** run the engine in a background isolate.

### 9. C API robustness
- Eight exports in [astro_capi.cpp](core/capi/astro_capi.cpp) (lines 92, 164, 266, 386, 458, 736, 763, 794) catch only `std::exception`. A non-standard exception would abort the host process across `extern "C"`. The other exports already have `catch(...)`.
- `astro_engine_create` throws the error message away when it returns `nullptr` *(reported)*.
- `last_error` is never cleared on success, so a stale error can mask the storage error *(reported)*.
- The `reinterpret_cast`s between Impl structs and the public structs are technically UB, because the Impl classes are not standard-layout *(reported)*.
- There is no locking around shared state *(reported)*.

**Fix:** one `guard(fn, fallback)` helper with `catch(...)` that stores the error without throwing, used by every export.

## Major

### Architecture
- **`AstroEngine` is too wide.** It is a 14-method interface mixing computation, observing-list CRUD and description storage. Splitting it into `EphemerisEngine`, `ObservingListRepository` and `DescriptionRepository` would make the fake smaller.
- **C++ storage runs compute.** `storage.hpp` has the repository interface run visibility computation, planet substitution, threading and sorting. `get_object_by_id` reads wall-clock time to rewrite planet coordinates inside a getter *(reported)*. Keep the repository to queries and move `filter_targets*` into a service.
- **C++ context depends on a concrete class.** `AstroEngineContext` holds the concrete `SqliteStorage`, not an interface *(reported)*.
- **The C API is not thin.** It holds sentinel interpretation, duplicated criteria and item marshalling, planet-id routing and hand-rolled JSON *(reported)*.
- **`AstroBridge` repeats itself.**
  - About 60 lines of criteria marshalling are repeated between `filterTargets` and `filterTargetsPeriod`.
  - Window-selection business logic sits in the FFI layer ([astro_bridge.dart:446-470](app/lib/core/astro_bridge.dart:446)).
  - There are 20 hand-written C/Dart typedef pairs, which `ffigen` could generate.
- **Layer cycle.** [target_preview_canvas.dart](app/lib/widgets/target_preview_canvas.dart) imports `views/equipment_framing_dialog.dart`, which imports it back.
- **`CatalogManager` does too much.** It mixes storage discovery, DB unpacking and online HTTP, and hardcodes Android paths with the doubled `app.app` id ([catalog_manager.dart:49](app/lib/core/catalog_manager.dart:49)). `path_provider` replaces about 70 lines of heuristics.
- **Managers mutate state in getters.** `EquipmentManager.activeProfile` and `ObservingSiteManager.activeSite` change state when called with empty lists. `ObservingSiteManager` also builds its default site in two places (`init` and `resetToDefault`).
- **`FilterState` is mutable.** It has about 40 fields and no `==`/`hashCode`, so `old.filters != widget.filters` checks miss in-place changes. Make it immutable sub-objects (`ObserverLocation`, `HorizonConfig`, `TimeWindow`, `CatalogCriteria`).

### Bugs confirmed in the code
- [planner_view.dart:185](app/lib/views/planner_view.dart:185): `isRedNightMode ? ThemeData.dark() : ThemeData.dark()`. Both branches are identical, so the date picker is not red in night mode.
- [observing_sites_dialog.dart:183](app/lib/views/observing_sites_dialog.dart:183): unparsable input silently becomes the author's own coordinates (`-22.2819`, `858.0`). [filter_state.dart](app/lib/models/filter_state.dart) also defaults to Nova Friburgo.
- [astro_bridge.dart:584-585](app/lib/core/astro_bridge.dart:584): duplicated `@override @override`.
- `shouldRepaint` returns `true` unconditionally at [horizon_maker_dialog.dart:2557](app/lib/views/horizon_maker_dialog.dart:2557) and [filter_dialog.dart:1475](app/lib/views/filter_dialog.dart:1475).
- [observer_location_dialog.dart](app/lib/views/observer_location_dialog.dart) has no references anywhere, so it is dead code.
- [storage.cpp](core/src/storage.cpp) result sort uses an epsilon comparison (`abs(diff) > 1e-4`), which breaks strict weak ordering for `std::sort`.

### Reported, not re-verified
- Controllers are disposed in `showDialog(...).then(dispose)` while the exit animation is still running (`horizon_maker_dialog`, `observing_lists_view`, `target_details_sheet`).
- A few awaits lack `mounted` guards: `planner_view.dart:177-196` and `filter_dialog.dart:1161-1181`.
- The C++ code treats JD `0.0` as "event doesn't occur", which turns into huge negative timestamps in polar regions.
- The LIKE fallback in `storage.cpp` ignores filters and paging.
- The default year is hardcoded to 2026 in the C++ yearly path.
- Window-selection and yearly-aggregation blocks are copy-pasted three and two times in `visibility.cpp`.
- Solar-system id handling (`id - 90000` cast to `PlanetId`) is repeated four times, with no range check.

### Localization
- `AppLocalizations.of(context)` is nullable (`l10n.yaml` has no `nullable-getter: false`). That forces about 394 `l10n?.x ?? "English fallback"` sites, which duplicate every English string and hide missing keys. **Fix:** set `nullable-getter: false`, then do a mechanical sweep.
- Fully hardcoded user-facing strings *(reported)*: about 47 in `horizon_maker_dialog` and about 30 in `favorites_view`, plus `bright_stars_view`, `planets_view` and `about_dialog`.
- `about_dialog` and `filter_dialog` use `isPt ? … : …` branches instead of ARB keys, and `FilterDialogController` takes an `isPt` parameter.
- Raw exception text is shown to users in `horizon_maker_dialog`, `planner_view` and `main_scaffold`.

### Build, data and repository hygiene
- **Duplicate database.** `catalogs.db` is committed twice (6.6 MB each, `app/assets/` and `core/data/`), with 15 revisions in history.
- **User data in the asset DB.** User-data tables (`user_lists`, `user_list_items`) are baked into the read-only asset catalog *(reported)*. Replacing the asset DB would wipe user data.
- **CMake.**
  - The core sources are compiled twice, into `astro_core_static` and the shared `astro_core`.
  - `add_compile_options` and `add_definitions` are global.
  - The Flutter Windows build also builds and registers the C++ tests *(reported)*.
- **No CI.** There is no `.github/`.
- **Template leftovers.** `app/pubspec.yaml` still says `"A new Flutter project."`, `app/README.md` is the Flutter template, and the Android `applicationId` is `com.astrotargets.app.app`.
- **Fake Python tests.** `scripts/data_tools/test_*.py` contain no assertions. `test_fetch_catalogs.py` calls the network at import time with no timeout, and there is no `requirements.txt`.
- **Python build script.** `build_catalogs.py` has no request timeouts, swallows errors broadly, and deletes the old DB before the new one is built *(reported)*. It also classifies `startswith("M")` objects as Messier, so Mel* and MWSC* objects end up in the Messier catalog *(reported, 8 rows)*.
- **Packaging.** `package_portable_release.ps1` backs up and restores `user_settings.json` and `terrain_cache` inside `dist`. Check that no personal settings end up in a shared zip before distributing a build. `package_android_release.ps1` does not check the `flutter build` exit code *(reported)*.
- **`.gitignore`.** `.agents/rules/` is committed, but only one file in it is ignored.

### Tests
- 146 passing tests are a good base.
- `mobile_topbar_and_location_test.dart` builds its own `AppBar` inline and never touches `MainScaffold`. `desktop_topbar_test.dart` does not reference it either, so both pass without testing the app.
- The C++ tests are hand-rolled, with a macro hack to keep `assert` alive in Release. They exit on the first failure and write temp DBs next to the source *(reported)*. A real framework (doctest or Catch2) with `catch_discover_tests` would make each case a CTest case.
- There are no tests for `AstroBridge` marshalling against the real library, none for the C API error paths, and no golden-value tests for planets, the moon phase or sunrise/sunset *(reported)*.

### Accessibility and polish
- There is no `Semantics` or `semanticLabel` in `views` or `widgets`, and the charts expose no text summary.
- Breakpoints are scattered: 450, 460, 480, 520, 600, 640, 650, 700, 720, 800 and 900. Use one `Breakpoints` helper and `MediaQuery.sizeOf`.
- About 74 `Color(0x…)` literals sit outside `theme/`, and there are about 394 `fontSize:` literals with no text theme.
- `TextPainter`s are rebuilt in `paint()` without being disposed, and hover in `altitude_curve_chart` calls `setState`, which rebuilds the 846-line `build` on every mouse move.
- Duplicated helpers: cardinal-direction-from-azimuth is implemented three times, and zoom/pan helpers are duplicated between `altitude_curve_chart` and `horizon_maker_dialog`. Location search and editing is duplicated between `horizon_maker_dialog` and `observing_sites_dialog`.

## Astronomy accuracy *(reported)*

None of these are code smells, but a reviewer who knows astronomy may ask about them. State the approximations and their accuracy in the README.

- Catalog coordinates are treated as J2000 with no precession, an error of about 0.36°.
- The Moon has no topocentric parallax, an error of up to about 1°.
- Yearly visibility uses a single UTC-midnight position for the whole night, which is wrong for the Moon.
- `transit_time` is the peak inside the window, not the meridian transit.
- A fixed UTC offset is used for all 365 days, so the local window drifts across daylight saving changes.
- The Moon and planet ephemerides are truncated, low-precision series. That is fine for planning.

## Suggested order of work

1. **Cheap wins, about half a day.**
   - [x] Delete the dead file (`observer_location_dialog.dart`) and the duplicate `@override` in `astro_bridge.dart`.
   - [x] Fix the identical `ThemeData` branches in `planner_view.dart`.
   - [x] Remove the hardcoded coordinates fallback (`ObservingSite.defaultLatitude`/`defaultLongitude`).
   - [x] Update `pubspec.yaml`, `app/README.md` and document the Android configuration.
   - [x] Convert `scripts/data_tools/test_*.py` into real `unittest` test suites with timeouts and assertions.
   - [x] Remove duplicate `core/data/catalogs.db` and gitignore.
2. **Add CI and a README.**
   - [x] Set up `.github/workflows/ci.yml` running CTest, Python unit tests, Flutter analyze/test, and Windows build.
   - [x] Updated root `README.md` with CI badge, full Mermaid architecture diagram, CTest build/test steps, and astronomy approximations/accuracy disclosure.
3. **Mechanical sweeps.** Set `nullable-getter: false` and remove the `?? "…"` fallbacks, then adopt `AstroPalette` and remove the `isRedNightMode` prop.
   - [x] Configured `nullable-getter: false` in `app/l10n.yaml` and swept 402+ `?? "fallback"` chains across 19 files to non-nullable getters.
   - [x] Converted method and painter parameters in all dialogs and chart painters from `AppLocalizations?` to canonical non-nullable `AppLocalizations`.
   - [x] Removed redundant `isRedNightMode` constructor parameters and prop drilling from `AboutDialogView`, `ObservingSitesDialog`, `EquipmentDialog`, `ObservingListsView`, `SettingsDialog`, `EquipmentFramingDialog`, and callers.
   - [x] Expanded `AstroPalette` with semantic tokens (`textPrimary`, `textSecondary`, `starlightCyan`, `starGold`, etc.) and systematically migrated 15+ views/dialogs.
4. **Structure.** Make `AstroEngine` a pure interface and inject the managers. Add an `AppController` out of `MainScaffold`, and move the engine to a background isolate.
   - [x] Refactored `AstroEngine` into pure segregated interfaces (`EphemerisEngine`, `ObservingListRepository`, `DescriptionRepository`) with zero concrete FFI imports (DIP/ISP).
   - [x] Implemented constructor injection and removed state mutation side-effects from `EquipmentManager` and `ObservingSiteManager`.
   - [x] Decoupled `TargetPreviewCanvas` from `views/` via callback interfaces, eliminating circular layer dependency.
   - [x] Built `AstroIsolate` to offload heavy native computations to background Dart worker isolates (`Isolate.run`).
   - [x] Built `AppController` extracting state management, background orchestration, and persistence from `MainScaffold`.
   - [x] Added `test/flutter_test_config.dart` and `test/app_controller_test.dart`, reaching 152/152 passing tests (100% green).
5. **Dedupe the UI.** Add `TargetListScaffold`, then split the god-files and move IO and domain logic out of widgets.
   - [x] Extracted shared `TargetListScaffold<T>` providing responsive master/detail layout and item synchronization.
   - [x] Extracted astronomical domain formatting and calculation logic (`formatRa`, `formatDec`, `cardinalFromAzimuth`, `SeasonStatusCalculator`) into `app/lib/utils/astro_formatters.dart`.
   - [x] Extracted RFC 4180 compliant CSV export and modal dialog presentation into `app/lib/services/csv_export_service.dart`.
   - [x] Extracted reusable `InfoChip` and `MetricPill` into `app/lib/widgets/astro_chips.dart`.
   - [x] Added `TargetDetailsSheet.show(...)` static launcher and eliminated duplicated sheet setup across 6 views.
   - [x] Split the 617-line `TargetVectorPainter.paint` into strategy hierarchy (`TargetBodyRenderer`, `PlanetBodyRenderer`, `StarBodyRenderer`, `DeepSkyBodyRenderer`).
   - [x] Refactored `PlanetsView` and `BrightStarsView` with `TargetListScaffold`, cutting ~400 lines of duplicated boilerplate.
   - [x] Added `test/astro_formatters_test.dart` and `test/csv_export_service_test.dart`, expanding the suite to 160/160 passing tests (100% green).
6. **C++ hygiene.** Separate storage from compute, split user data into its own DB, fix the CMake (one library, per-target options, tests off by default), and move to a real test framework.
   - [x] Separated storage from domain compute: Extracted visibility filtering, multi-threading, planet ephemeris decoration, and match-tier ranking out of `SqliteStorage` into dedicated `TargetFilterService`.
   - [x] Dependency Inversion: Inverted `AstroEngineContext` and engine components to depend on abstract `IStorage` and `ICatalogRepository` interfaces rather than concrete `SqliteStorage`.
   - [x] Isolated user database: Implemented support for separate `user_data.db` attached via SQLite `ATTACH DATABASE`, maintaining read-only isolation for `catalogs.db` while supporting cross-database joins on observing lists.
   - [x] CMake overhaul: Unified core compilation into an `OBJECT` library (`astro_core_obj`) avoiding double compilation, scoped compile flags to `astro_compile_options`, and gated test registration behind `ASTRO_BUILD_TESTS` (defaults to OFF when included from Flutter).
   - [x] Time purity: Removed wall-clock time lookup (`now_sec`) from `get_object_by_id`, and replaced hardcoded fallback year `2026` with dynamic UTC year computation.
   - [x] Test framework modernization: Enhanced `test_helpers.hpp` with structured assertion tracking, and added comprehensive unit tests for `TargetFilterService` and isolated user database attachment in `test_storage.cpp` (100% CTest pass rate).

---

## Resolved in 2026-10-03 Sprint

1. **C++ Storage Strict Weak Ordering (`core/src/storage.cpp`):**
   - Replaced floating-point epsilon comparison (`abs(diff) > 1e-4`) in `std::sort` with strict `<` or `>` ordering, adding a deterministic fallback tie-break on `a.dso.id < b.dso.id`. Added test coverage in `core/tests/test_storage.cpp`.
2. **C API Robustness (`core/capi/astro_capi.cpp`):**
   - Wrapped all C API exports in `catch (...)` handlers to guarantee no C++ exception can cross `extern "C"` boundaries.
   - Initialized/cleared `g_last_error` upon entry to each API call.
   - Added `g_init_error` tracking so engine creation failures properly surface their diagnostic reason via `astro_engine_get_last_error`. Added unit test in `core/tests/test_capi.cpp`.
3. **Catalog Build Regex Precision (`core/data/build_catalogs.py`):**
   - Tightened regex matching for Messier classification to `^M\s*\d+` (was `startswith("M")`), preventing Melotte and MWSC clusters from being misclassified as Messier objects.
4. **Data Redundancy & Repository Cleanliness:**
   - Untracked duplicate 6.6MB `core/data/catalogs.db` file and added it to `.gitignore` (canonical database lives in `app/assets/catalogs.db`).
   - Deleted dead/unreferenced file `app/lib/views/observer_location_dialog.dart`.
   - Removed duplicated `@override` annotation in `app/lib/core/astro_bridge.dart:584`.
   - Replaced author-specific hardcoded coordinate fallbacks (`-22.2819`, `858.0`) in `observing_sites_dialog.dart` and `filter_state.dart` with centralized `ObservingSite.defaultLatitude`, `ObservingSite.defaultLongitude`, `ObservingSite.defaultElevation`.
   - Fixed `planner_view.dart` red night mode date-picker theme.
5. **Theme & AstroPalette Adoption (`app/lib/theme/astro_theme.dart`):**
   - Expanded `AstroPalette` with semantic token getters: `textPrimary`, `textSecondary`, `textTertiary`, `starlightCyan`, `starGold`, `nebulaIndigo`, `deepSkyTeal`, and `visibleGreen`.
   - Refactored 15+ views and dialogs (`target_search_view`, `planets_view`, `bright_stars_view`, `favorites_view`, `observing_lists_view`, `target_details_sheet`, `planner_view`, `altitude_curve_chart`, `settings_dialog`, `observing_sites_dialog`, `main_scaffold`, `horizon_maker_dialog`, `equipment_dialog`, `equipment_framing_dialog`, `target_preview_canvas`, `about_dialog`) to use `AstroPalette.of(context)` instead of repetitive ternary color expressions.
6. **Script & Tooling Quality:**
   - Converted `scripts/data_tools/test_arp_parse.py` and `test_catalogs_query.py` into real standard `unittest` test suites with explicit assertions.
   - Added request timeouts to VizieR downloads and guarded integration scripts under `if __name__ == '__main__':`.
7. **Continuous Integration & Documentation (Phase 2):**
   - Configured `.github/workflows/ci.yml` running CTest for C++20 core, Python unit tests, Flutter static analysis (`flutter analyze`), widget/unit tests (`flutter test`), and Windows release build.
   - Enhanced root `README.md` with system topology Mermaid diagram, clear directory breakdown, CTest and build commands, and an explicit *Astronomy Approximations & Accuracy* disclosure section.
8. **Mechanical Sweeps & Localization Hardening (Phase 3):**
   - Enabled `nullable-getter: false` in `app/l10n.yaml` and regenerated canonical non-nullable localizations.
   - Swept 402+ `?? "fallback"` chains across 19 files in `app/lib`, replacing ad-hoc strings with single source-of-truth ARB keys and preventing translation drift.
   - Removed obsolete `isRedNightMode` prop drilling and constructor arguments across `AboutDialogView`, `ObservingSitesDialog`, `EquipmentDialog`, `ObservingListsView`, `SettingsDialog`, and `EquipmentFramingDialog`, transitioning fully to `AstroPalette.of(context)`.
   - Updated widget test harness setups with localization delegates, keeping the suite 100% green (146/146 tests passing) with 0 static analysis issues.
9. **Architecture, Interface Segregation & Background Isolates (Phase 4):**
   - Refactored `AstroEngine` into pure segregated abstract contracts (`EphemerisEngine`, `ObservingListRepository`, `DescriptionRepository`) with zero concrete FFI imports adhering strictly to DIP and ISP.
   - Added `AstroEngine.defaultFactory` registry and configured `AstroBridge.registerAsDefault()`, allowing decoupling between presentation/domain widgets and concrete native bindings.
   - Refactored `EquipmentManager` and `ObservingSiteManager` with constructor injection, eliminated state-mutating side-effects in getters, and unified default site creation.
   - Decoupled `TargetPreviewCanvas` from `views/` dialogs via callback interfaces (`onOpenFramingDialog`, `onOpenEquipmentDialog`), eliminating circular dependency cycles.
   - Built `AstroIsolate` leveraging `Isolate.run` to offload heavy native computations (`filterTargets`, `getPlanets`, `getBrightStars`, `filterTargetsPeriod`, `generateAltitudeCurve`, `getTargetYearlyVisibility`) onto background Dart isolates, keeping the UI at 60/120fps.
   - Implemented `AppController` extracting complex lifecycle orchestration, background task delegation, observing list synchronization, and settings persistence out of `MainScaffold`.
   - Configured `test/flutter_test_config.dart` and added `test/app_controller_test.dart`, expanding the test suite to 152/152 passing tests (100% green) with 0 static analysis warnings.
10. **UI Deduplication, Domain Formatting & Vector Painter Splitting (Phase 5):**
    - Extracted generic `TargetListScaffold<T>` providing standardized master/detail responsive presentation, adaptive sorting, header actions, and multi-device layout behavior.
    - Extracted `AstroFormatters` and `SeasonStatusCalculator` (`app/lib/utils/astro_formatters.dart`), removing coordinate formatting and seasonal calculations from UI widgets.
    - Built RFC 4180 compliant `CsvExportService` (`app/lib/services/csv_export_service.dart`), centralizing CSV serialization and clipboard copy modals.
    - Created reusable `InfoChip` and `MetricPill` (`app/lib/widgets/astro_chips.dart`) and static `TargetDetailsSheet.show(...)` launcher.
    - Refactored `TargetVectorPainter.paint` by breaking down the 617-line monolithic method into a strategy pattern hierarchy (`TargetBodyRenderer`, `PlanetBodyRenderer`, `StarBodyRenderer`, `DeepSkyBodyRenderer`).
    - Streamlined `PlanetsView` and `BrightStarsView`, eliminating repetitive card layouts and reducing codebase surface by hundreds of lines.
    - Added comprehensive unit tests in `test/astro_formatters_test.dart` and `test/csv_export_service_test.dart`, expanding the suite to 160/160 passing tests (100% green) with 0 static analysis issues.
11. **C++ Hygiene, Storage/Compute Separation & CMake Overhaul (Phase 6):**
    - Extracted pure visibility filtering, multi-threaded period simulations, solar system body ephemeris decoration, and match-tier search ranking from `SqliteStorage` into `TargetFilterService`.
    - Refactored `storage.hpp` and `AstroEngineContext` with pure abstract interfaces (`IStorage`, `ICatalogRepository`, `ITargetDescriptionRepository`), adhering strictly to Dependency Inversion (DIP).
    - Added isolated user database support (`user_data.db`) via SQLite `ATTACH DATABASE`, maintaining read-only isolation on catalog databases and enabling multi-database joins.
    - Overhauled CMake build configuration: created `astro_core_obj` object library to avoid double compilation across static/shared targets, scoped compile flags to `astro_compile_options`, and gated test builds behind `ASTRO_BUILD_TESTS` (defaults to OFF when included from Flutter).
    - Removed wall-clock time lookup side-effects from `get_object_by_id`, and replaced hardcoded fallback year `2026` with dynamic UTC year calculation.
    - Modernized `test_helpers.hpp` and achieved 100% test pass rate across all C++ suites (`test_astro`, `test_storage`, `test_capi`).
