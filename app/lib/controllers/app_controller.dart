import 'package:flutter/foundation.dart';

import '../core/app_logger.dart';
import '../core/astro_bridge.dart';
import '../core/astro_engine.dart';
import '../core/astro_isolate.dart';
import '../core/catalog_manager.dart';
import '../core/equipment_manager.dart';
import '../core/favorites_manager.dart';
import '../core/observing_site_manager.dart';
import '../core/settings_service.dart';
import '../models/filter_state.dart';
import '../models/night_summary.dart';
import '../models/observing_list.dart';
import '../models/target_item.dart';
import '../services/terrain_cache_service.dart';

/// Central presentation and domain coordinator for Menelway Astro Planner.
/// Extracts business state, lifecycle synchronization, and asynchronous engine scheduling
/// out of MainScaffold adhering to SOLID Single Responsibility and Dependency Inversion principles.
class AppController extends ChangeNotifier {
  final AstroEngine engine;
  final EquipmentManager equipmentManager;
  final ObservingSiteManager siteManager;
  final FavoritesManager favoritesManager;
  final bool enableIsolate;

  FilterState _filters;
  NightSummary? _nightSummary;
  List<TargetItem> _targets = [];
  List<TargetItem> _planets = [];
  List<TargetItem> _brightStars = [];
  List<ObservingListModel> _observingLists = [];

  int _selectedTabIndex = 0;
  bool _isInitializing = true;
  bool _isLoadingTargets = false;
  bool _isLoadingPlanets = false;
  bool _isLoadingBrightStars = false;
  String? _initError;
  double _dbSizeMb = 0.0;
  String? _dbPath;

  int _filterRequestId = 0;
  FilterState? _lastEphemerisFilters;

  bool _disposed = false;

  AppController({
    AstroEngine? engine,
    EquipmentManager? equipmentManager,
    ObservingSiteManager? siteManager,
    FavoritesManager? favoritesManager,
    FilterState? initialFilters,
    this.enableIsolate = true,
  })  : engine = engine ?? AstroEngine.instance,
        equipmentManager = equipmentManager ?? EquipmentManager.instance,
        siteManager = siteManager ?? ObservingSiteManager.instance,
        favoritesManager = favoritesManager ?? FavoritesManager.instance,
        _filters = initialFilters ?? FilterState() {
    this.favoritesManager.addListener(_onFavoritesChanged);
    this.siteManager.addListener(_onObservingSiteChanged);
  }

  // State Getters
  FilterState get filters => _filters;
  NightSummary? get nightSummary => _nightSummary;
  List<TargetItem> get targets => _targets;
  List<TargetItem> get planets => _planets;
  List<TargetItem> get brightStars => _brightStars;
  List<ObservingListModel> get observingLists => _observingLists;
  int get selectedTabIndex => _selectedTabIndex;
  bool get isInitializing => _isInitializing;
  bool get isLoadingTargets => _isLoadingTargets;
  bool get isLoadingPlanets => _isLoadingPlanets;
  bool get isLoadingBrightStars => _isLoadingBrightStars;
  String? get initError => _initError;
  double get dbSizeMb => _dbSizeMb;
  String? get dbPath => _dbPath;

  /// Changes the primary navigation tab index.
  void setTabIndex(int index) {
    if (_selectedTabIndex != index) {
      _selectedTabIndex = index;
      notifyListeners();
    }
  }

  /// Bootstraps database handles, ephemeris calculations, and initial target filters.
  Future<void> bootstrap({AppSettingsData? initialSettings}) async {
    try {
      _isInitializing = true;
      _initError = null;
      notifyListeners();

      final dbPath = await CatalogManager.getDatabasePath();
      final sizeMb = await CatalogManager.getDatabaseSizeMb();
      _dbPath = dbPath;
      _dbSizeMb = sizeMb;

      engine.initEngine(dbPath);

      _nightSummary = engine.getNightSummary(
        latitude: _filters.observerLat,
        longitude: _filters.observerLon,
        elevation: _filters.observerElevation,
        date: _filters.date,
      );

      _observingLists = engine.getObservingLists();

      // Auto-restore observing lists from settings backup if SQLite user lists are empty
      if (_observingLists.isEmpty &&
          initialSettings?.observingListsBackup != null &&
          initialSettings!.observingListsBackup!.isNotEmpty) {
        for (final list in initialSettings.observingListsBackup!) {
          final newId = engine.createObservingList(
            list.name,
            list.description,
            list.sessionDate,
          );
          if (newId > 0) {
            for (final item in list.items) {
              engine.addTargetToList(newId, item.dsoId, item.notes);
            }
          }
        }
        _observingLists = engine.getObservingLists();
      }

      favoritesManager.init(initialSettings?.favorites);

      // Auto-load cached terrain profile if missing from active filters
      if (_filters.terrainProfile == null) {
        final cached = await TerrainCacheService.loadProfile(
          _filters.observerLat,
          _filters.observerLon,
        );
        if (cached != null) {
          _filters = _filters.copyWith(
            terrainProfile: cached,
            showTerrainSilhouette: true,
          );
        }
      }

      _isInitializing = false;
      notifyListeners();

      await runFiltering();
    } catch (e, st) {
      AppLogger.error('Failed to bootstrap AppController: $e\n$st', tag: 'AppController');
      _isInitializing = false;
      _initError = e.toString();
      notifyListeners();
    }
  }

  /// Checks whether ephemeris-dependent parameters (observer, date, altitude/time window, horizon profile)
  /// changed between two filter configurations. Used to avoid redundant background calculations of
  /// solar system objects and bright stars when only searching deep sky objects by name.
  bool _areEphemerisFiltersEqual(FilterState a, FilterState b) {
    return a.observerLat == b.observerLat &&
        a.observerLon == b.observerLon &&
        a.observerElevation == b.observerElevation &&
        a.date.year == b.date.year &&
        a.date.month == b.date.month &&
        a.date.day == b.date.day &&
        a.minAltitude == b.minAltitude &&
        a.maxAltitude == b.maxAltitude &&
        a.minDurationHours == b.minDurationHours &&
        a.useCustomTimeWindow == b.useCustomTimeWindow &&
        a.customStartHour == b.customStartHour &&
        a.customStartMinute == b.customStartMinute &&
        a.customEndHour == b.customEndHour &&
        a.customEndMinute == b.customEndMinute &&
        a.useCustomHorizon == b.useCustomHorizon &&
        a.showTerrainSilhouette == b.showTerrainSilhouette;
  }

  /// Evaluates and filters celestial targets, planets, and bright stars for the active night.
  /// When running in production with AstroBridge, executes in background Dart isolates to maintain 60/120fps.
  /// Uses a monotonic request sequence counter to discard stale out-of-order queries when rapid search
  /// typing occurs on lower-end devices.
  Future<void> runFiltering({bool notify = true}) async {
    if (_nightSummary == null || _disposed) return;

    final requestId = ++_filterRequestId;

    _isLoadingTargets = true;
    _isLoadingPlanets = true;
    _isLoadingBrightStars = true;
    if (notify) notifyListeners();

    try {
      final night = _nightSummary!;
      final currentFilters = _filters;
      final path = _dbPath;

      final needEphemerisRefresh = _planets.isEmpty ||
          _brightStars.isEmpty ||
          _lastEphemerisFilters == null ||
          !_areEphemerisFiltersEqual(_lastEphemerisFilters!, currentFilters);

      if (enableIsolate && engine is AstroBridge && path != null && !kIsWeb) {
        final targetsFuture = AstroIsolate.filterTargets(
          dbPath: path,
          filters: currentFilters,
          night: night,
          stepMinutes: 10,
        );

        final planetsFuture = needEphemerisRefresh
            ? AstroIsolate.getPlanets(
                dbPath: path,
                filters: currentFilters,
                night: night,
                stepMinutes: 10,
              )
            : Future.value(_planets);

        final starsFuture = needEphemerisRefresh
            ? AstroIsolate.getBrightStars(
                dbPath: path,
                filters: currentFilters,
                night: night,
                stepMinutes: 10,
              )
            : Future.value(_brightStars);

        final results = await Future.wait([targetsFuture, planetsFuture, starsFuture]);

        // Guard against race conditions: only commit if this is still the freshest in-flight request
        if (!_disposed && requestId == _filterRequestId) {
          _targets = results[0];
          _planets = results[1];
          _brightStars = results[2];
          _lastEphemerisFilters = currentFilters;
        }
      } else {
        // In-isolate / test execution (e.g., FakeAstroEngine)
        final t = engine.filterTargets(
          filters: currentFilters,
          night: night,
          stepMinutes: 10,
        );
        final p = needEphemerisRefresh
            ? engine.getPlanets(
                filters: currentFilters,
                night: night,
                stepMinutes: 10,
              )
            : _planets;
        final b = needEphemerisRefresh
            ? engine.getBrightStars(
                filters: currentFilters,
                night: night,
                stepMinutes: 10,
              )
            : _brightStars;

        // Guard against race conditions: only commit if this is still the freshest in-flight request
        if (!_disposed && requestId == _filterRequestId) {
          _targets = t;
          _planets = p;
          _brightStars = b;
          _lastEphemerisFilters = currentFilters;
        }
      }
    } catch (e, st) {
      AppLogger.error('Error during runFiltering: $e\n$st', tag: 'AppController');
    } finally {
      if (!_disposed && requestId == _filterRequestId) {
        _isLoadingTargets = false;
        _isLoadingPlanets = false;
        _isLoadingBrightStars = false;
        notifyListeners();
      }
    }
  }

  /// Updates active target filter criteria and triggers a refresh.
  void updateFilters(FilterState newFilters, {bool triggerQuery = true}) {
    _filters = newFilters;
    notifyListeners();
    if (triggerQuery) {
      runFiltering();
    }
  }

  /// Refreshes saved observing lists from repository.
  void refreshObservingLists() {
    _observingLists = engine.getObservingLists();
    notifyListeners();
  }

  /// Persists current application settings and user profile to storage.
  void saveSettings({bool? isRedNightMode, String? languageCode}) {
    SettingsService.saveSettings(
      filters: _filters,
      isRedNightMode: isRedNightMode,
      observingLists: _observingLists,
      equipmentProfiles: equipmentManager.profiles,
      activeEquipmentProfileId: equipmentManager.activeProfileId,
      observingSites: siteManager.sites,
      activeObservingSiteId: siteManager.activeSiteId,
      favorites: favoritesManager.favorites,
      languageCode: languageCode,
    );
  }

  /// Resets target filter criteria back to defaults while preserving active observer coordinates.
  void resetFiltersOnly({bool? isRedNightMode, String? languageCode}) {
    _filters = FilterState(
      observerLat: _filters.observerLat,
      observerLon: _filters.observerLon,
      observerElevation: _filters.observerElevation,
      observerLocationName: _filters.observerLocationName,
    );
    notifyListeners();
    saveSettings(isRedNightMode: isRedNightMode, languageCode: languageCode);
    runFiltering();
  }

  /// Wipes all user data and resets system to initial state.
  void cleanAllData({VoidCallback? onResetNightMode}) {
    // 1. Wipe database observing lists
    engine.clearAllObservingLists();

    // 2. Wipe settings and cache
    SettingsService.clearSettings();

    // 3. Wipe favorites
    favoritesManager.clear();

    // 4. Reset night mode if enabled
    onResetNightMode?.call();

    // 5. Reset in-memory filters and ephemeris
    _filters = FilterState();
    _lastEphemerisFilters = null;
    _observingLists = [];
    _planets = [];
    _brightStars = [];
    _nightSummary = engine.getNightSummary(
      latitude: _filters.observerLat,
      longitude: _filters.observerLon,
      elevation: _filters.observerElevation,
      date: _filters.date,
    );

    // 6. Reset observing sites to default
    siteManager.resetToDefault();

    notifyListeners();
    runFiltering();
  }

  void _onObservingSiteChanged() {
    final site = siteManager.activeSite;
    if (_filters.observerLat != site.latitude ||
        _filters.observerLon != site.longitude ||
        _filters.observerElevation != site.elevation ||
        _filters.observerLocationName != site.name) {
      _filters = _filters.copyWith(
        observerLat: site.latitude,
        observerLon: site.longitude,
        observerElevation: site.elevation,
        observerLocationName: site.name,
      );

      _nightSummary = engine.getNightSummary(
        latitude: site.latitude,
        longitude: site.longitude,
        elevation: site.elevation,
        date: _filters.date,
      );

      saveSettings();
      runFiltering();
    } else {
      notifyListeners();
    }
  }

  void _onFavoritesChanged() {
    saveSettings();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    favoritesManager.removeListener(_onFavoritesChanged);
    siteManager.removeListener(_onObservingSiteChanged);
    super.dispose();
  }
}
