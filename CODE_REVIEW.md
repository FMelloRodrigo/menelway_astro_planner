# Code review: Menelway Astro Planner

Scope: Dart core layer, models, services, config and tests; Flutter UI layer; C++ core and C API; Python data scripts.
Method: `flutter analyze` and `flutter test` were run (138 tests pass, 61 analyzer issues, mostly info). The C++ code was read but not compiled or run.

**Verdict:** the architecture is sound, and for a portfolio piece that matters more than anything below. It's a C++ astronomy core behind a C ABI, with Dart FFI and a Flutter UI that can swap in a fake engine for tests. The weak points are a few giant UI files, copy-paste duplication, and some C++ boundary and SQL hygiene issues. Most are cheap to fix.

## What's already good

- **The `AstroEngine` abstraction** (`app/lib/core/astro_engine.dart`) works as a dependency-inversion seam. `FakeAstroEngine` lets 138 widget and unit tests run without native code. `MainScaffold`, `PlannerView` and `TargetDetailsSheet` accept an injected engine.
- **Tests and tooling:** all 138 tests pass. `flutter_lints` is on, and l10n (EN/PT) goes through ARB files.
- **Services:**
  - `SettingsService` is careful: schema versioning, a backup file, and atomic temp-file-then-rename writes.
  - `AppLogger` is tidy.
  - Geocoding calls all have timeouts.
- **`FilterDialogController` and `FovProjector`** are the clean models for the rest of the UI. The controller is a testable `ChangeNotifier`, and the projector is a small pure class with tests.
- **C++:**
  - Strongly typed units (`Degrees`, `Hours`, `JulianDate`).
  - RAII for sqlite statements.
  - A proper `extern "C"` / export header.
  - Parameterized queries for text search and writes.
  - A well-designed fast period path with an analytic prefilter and parallel chunks.

## Critical (fix before showing it to anyone)

1. **SQL injection in `core/src/storage.cpp:384, 395, 418`.** Catalog names, object types and the constellation are concatenated into the SQL string, for example `"d.catalog = '" << cat << "'"`. They arrive from the filter state through the C API. It's a local app, but a reviewer will spot it immediately. Use `?` placeholders and bind them. Doubles streamed into the SQL (L402-413) are also locale-sensitive.
2. **Exceptions can cross the C ABI.** `astro_capi.cpp` has only 8 `try` blocks. The observing-list functions (create, delete, add, remove, clear and the JSON getter) have none. Wrap every `extern "C"` entry in a common catch-all that sets the error and returns a failure code.
3. **Dangling pointer:** `moon_phase_name` points into `ctx->cached_moon_phase` (`astro_capi.cpp:140-141`). The next call on the same engine invalidates it. Return a pointer to a static string literal instead.
4. **Storage errors never reach Dart.** `astro_engine_get_last_error` returns only the capi layer's error. `SqliteStorage::last_error_` is never surfaced, so database failures show up as plain `false` or `-1`.
5. **`PRAGMA foreign_keys` is never enabled,** so the `ON DELETE CASCADE` in the schema does nothing. `delete_list` and `clear_all_lists` also aren't transactional.
6. **Asserts disappear in Release.** The C++ tests use bare `<cassert>`, and `CMakeLists.txt` has no `enable_testing()` or `add_test()`. Built in Release, the tests pass with zero checks. They also write into the committed `core/data/catalogs.db` and use cwd-relative paths. Fix this with GoogleTest or Catch2 plus CTest, running against a temp copy of the database.
7. **Root `test_*.py` files aren't tests.** They have no assertions, and two hit the network at import time, so `pytest` collection would trigger downloads. Move them to `scripts/` or `tools/`, or turn them into real tests.

## Architecture and SOLID

| Principle | Assessment |
|---|---|
| **D**ependency inversion | Good at the engine seam. Weak everywhere else: `EquipmentManager.instance` is used 63 times, `FavoritesManager.instance` 19, and `SettingsService`, `CatalogManager`, `GeocodingService` and `TerrainCacheService` are all static and called straight from widgets. |
| **S**ingle responsibility | The main weakness (details below). |
| **O**pen/closed | Adding a list view or language means copy-pasting. `about_dialog.dart` branches on `languageCode == 'pt'` with inline ternaries across 400+ lines, and `cardinalName(isPt:)` hardcodes Portuguese. |
| **I**nterface segregation | `AstroEngine` is a 14-method interface covering computation, observing-list CRUD and description storage. Splitting it into `EphemerisEngine`, `ObservingListRepository` and `DescriptionRepository` would make the fake smaller. |
| **L**iskov | No problems seen. |

**Single responsibility, by file:**

- **`main_scaffold.dart` (1,870 lines):**
  - It bootstraps the engine and restores observing lists.
  - It persists settings.
  - It holds roughly 430 lines of inline geocoding dialog.
  - It runs the clean-data flow, the tutorial and the tab shell.
  - Its `build` method is about 480 lines.
- **`AstroBridge` (991 lines):**
  - `filterTargets` and `filterTargetsPeriod` repeat about 60 lines of criteria marshalling.
  - The `TargetItem` and `PeriodTargetItem` field mapping is repeated, with `.address != 0 ? toDartString() : ''` about 15 times.
  - The 20 typedef pairs are identical C/Dart twins, which `ffigen` would generate.
  - Window-selection business logic (lines 440-461) lives in the FFI layer.
- **`CatalogManager`** mixes storage-directory discovery, database unpacking and an online Sesame HTTP query. It also hardcodes Android paths such as `/data/user/0/com.astrotargets.app.app/files`. `path_provider` replaces about 70 lines of heuristics.
- **`FilterState`** is a mutable class with about 40 fields, covering observer, horizon, panorama, terrain, time window and catalog filters. It has a hardcoded default location (Nova Friburgo) and an unlocalized `"Astronomical Darkness"` string. Split it into immutable sub-objects (`ObserverLocation`, `HorizonConfig`, `TimeWindow`, `CatalogCriteria`).

## Flutter / Dart practices

- **No state management.**
  - `_MainScaffoldState` holds four result lists and the filters, and refreshes them by hand with `setState` plus `_saveSettings()`.
  - Views subscribe to `ChangeNotifier` singletons with manual `addListener` plus `setState` instead of `ListenableBuilder`.
  - Callbacks and `isRedNightMode` are passed through every layer.
  - Provider or Riverpod isn't required, but one app-level controller owning the filters, results and persistence would remove most of `MainScaffold`.
- **Native calls block the UI thread.** There's no `Isolate` or `compute` anywhere. `_runFiltering` just wraps three synchronous FFI calls in `Future.microtask`, which doesn't unblock anything. The period planner scans many nights, so it will jank. Run the engine in a background isolate.
- **Red night mode is drilled everywhere.** The flag is read about 70 times in the altitude chart alone, 80 in `main_scaffold` and 76 in the preview canvas. The repeated `isRed ? AstroColors.nightVisionRed : Colors.white` ternaries are the result. A `ThemeExtension` palette would remove hundreds of lines. There are 800+ `Color(...)`/`Colors.*` uses in the views.
- **Duplicated list views.**
  - `planets_view` and `bright_stars_view` share about 65% of their lines, including identical `_buildChip` and `_buildMetricPill`.
  - `target_search_view`, `favorites_view` and `planner_view` share another 110-170 lines each with it.
  - A generic `TargetListView` plus `TargetCard` would save roughly 1,200 lines.
- **Oversized files and methods:**
  - Seven files are over 1,400 lines: `horizon_maker_dialog` 2,410, `altitude_curve_chart` 2,148, `main_scaffold` 1,870, `target_preview_canvas` 1,862, `target_details_sheet` 1,738, `filter_dialog` 1,477.
  - Several `build` methods run 350-530 lines, and `TargetVectorPainter.paint` is about 617.
  - Each file bundles widgets, painters and logic.
- **Lifecycle bugs:**
  - `horizon_maker_dialog` never disposes its `ui.Image` (`_decodedImage`), which leaks native memory.
  - Dialog-local `TextEditingController`s are never disposed in `main_scaffold`, `horizon_maker`, `observing_lists_view` and `target_details_sheet`.
  - Async geocoding callbacks call `setState` without a mounted check.
  - `static double _zoomStepPercent` is mutable static state in a `State` class.
- **Painters:**
  - `shouldRepaint` returns `true` unconditionally in `_HorizonChartPainter` and `_MiniHorizonPreviewPainter`.
  - `TextPainter`s are rebuilt every frame, about 21 sites.
  - Sorting and peak scans run inside `build`.
- **Tabs lose state when you switch,** because `main_scaffold` uses a nested ternary instead of an `IndexedStack`.
- **Strings:**
  - About 87 literal `Text("…")` calls bypass l10n, 28 of them in `horizon_maker`.
  - The `l10n?.key ?? "English fallback"` pattern appears about 290 times. It hides missing keys. Use non-nullable `AppLocalizations.of(context)` or an extension.
  - Raw `$e` exception text is shown to users.
- **Responsive breakpoints** are ad hoc: 450, 600, 700, 720, 800 and 900 are scattered across files. `main_scaffold` decides desktop versus mobile by checking whether a `GlobalKey` has a context. Add a single breakpoints helper and use `MediaQuery.sizeOf`.
- **Accessibility:** almost no `Semantics` or tooltips on the custom tap targets, and none on the charts.
- **Hardcoded year:** `year = 2026` is the default in `getTargetYearlyVisibility`. It should be `DateTime.now().year`.

## Tests

- **Many tests don't test the app.** `mobile_topbar_and_location_test.dart` builds its own copy of an `AppBar` inline and asserts on that, not on `MainScaffold`. The analyzer flags its dead code, so some assertions never run.
- **Analyzer status:** 61 issues, mostly info.
  - Missing `@override` on 14 `AstroBridge` methods.
  - A `?.` on a non-null receiver and an always-true null comparison in `altitude_curve_chart.dart`.
  - Unused imports and variables in tests.
  - The pubspec still has the template description `"A new Flutter project."`.
- **Gaps:** there's no test of `AstroBridge` against the real library (`test_capi.cpp` is the only integration path). `settings_test` and the other service tests are good. There's no CI, so nothing runs the tests automatically.

## Repository hygiene

- **No root README.** `app/README.md` is the Flutter template text. A portfolio needs a README with screenshots, an architecture diagram, build steps and how to regenerate `catalogs.db`.
- **`catalogs.db` is committed twice** (6.4 MB each, `app/assets/` and `core/data/`). Keep one copy and have the build copy it, or generate it in the build.
- **Python scripts:**
  - No `requirements.txt`.
  - `build_catalogs.py` downloads with no timeouts.
  - `fetch_wiki_summary` is duplicated across both prebake scripts.
  - Fetch errors are silently swallowed with `except Exception: pass`.
  - The `target_descriptions` schema is defined in three places, including the C++ code.
  - `seed_planets_and_stars.py:111-112` does a plain `DELETE FROM dso_fts` on an external-content FTS5 table, which can corrupt the index. It needs the FTS5 `'delete'` or `'rebuild'` command.
- **Packaging script** `package_portable_release.ps1` carries both "legacy" and "menelway" names, which suggests an unfinished rename. `.agents/rules/` is committed, so you may want to ignore the whole `.agents/` folder, since only one file inside it is currently ignored.
- **Android `applicationId`** `com.astrotargets.app.app` has a doubled `.app`.
- **CMake:**
  - The core sources compile twice, once per library.
  - It uses global `add_compile_options` and `add_definitions` instead of per-target settings.
  - There's no `target_compile_features`.
  - `SQLITE_OPEN_FULLMUTEX` is redundant with `SQLITE_THREADSAFE=1`.

## Astronomy correctness (worth fixing or documenting)

- Catalog targets are treated as J2000 but sidereal time is of-date, with no precession. The error is up to about 0.36°, while the Sun, Moon and planets are of-date.
- Sunset and sunrise look about 3 minutes late. The code applies refraction and also uses the −0.833° threshold, which already includes refraction.
- Yearly Moon and planet visibility uses one fixed position taken at UTC midnight. The Moon moves about 13° per day, so this is wrong for it.
- In the period filter, planet coordinates are never refreshed.
- `get_object_by_id` computes planets for "now" from observer (0,0).
- Planet IDs are derived by `static_cast<PlanetId>(id-90000)` with no range check, so an unknown ID silently computes Pluto.
- Visible-block duration is `(n-1)*step`, so a single sample counts as 0 hours.
- The Moon and planet ephemerides are truncated and low-precision. That's fine for planning, but say so in the README with the algorithm names and accuracy.

## Suggested order of work

1. Parameterize the SQL, wrap the C API entries in try/catch, fix the moon-phase pointer, enable `foreign_keys`, and surface storage errors. (about 2 hours)
2. Add a root README, delete the duplicate `catalogs.db`, move the ad-hoc scripts out of the root, and add `@override` plus the other analyzer fixes.
3. Put the C++ tests on a real framework with CTest, and set up CI that runs `flutter analyze`, `flutter test` and CTest.
4. Extract an app-level controller out of `MainScaffold` (location dialog, bootstrap, persistence). Move the engine to a background isolate.
5. Merge the five list views into one generic view, and replace `isRedNightMode` drilling with a `ThemeExtension`.
6. Split the 1,400+ line files, fix the disposal leaks and `shouldRepaint`, and localize the remaining strings.
7. Refactor `AstroBridge` so the criteria marshalling and item mapping each exist once.
