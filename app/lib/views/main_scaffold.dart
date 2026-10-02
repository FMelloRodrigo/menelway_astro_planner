import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/astro_engine.dart';
import '../core/catalog_manager.dart';
import '../core/equipment_manager.dart';
import '../core/geocoding_service.dart';
import '../core/settings_service.dart';
import '../core/favorites_manager.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../models/filter_state.dart';
import '../models/night_summary.dart';
import '../models/observing_list.dart';
import '../models/target_item.dart';
import '../theme/astro_theme.dart';
import 'bright_stars_view.dart';
import 'equipment_dialog.dart';
import 'favorites_view.dart';
import 'observing_lists_view.dart';
import 'planets_view.dart';
import 'planner_view.dart';
import 'settings_dialog.dart';
import 'target_search_view.dart';
import '../widgets/spotlight_tour.dart';
import '../services/terrain_cache_service.dart';

class MainScaffold extends StatefulWidget {
  final bool isRedNightMode;
  final VoidCallback onToggleNightMode;
  final VoidCallback? onResetNightMode;
  final AppSettingsData? initialSettings;
  final String? currentLanguageCode;
  final ValueChanged<String?>? onChangeLanguage;
  final AstroEngine? engine;

  const MainScaffold({
    super.key,
    required this.isRedNightMode,
    required this.onToggleNightMode,
    this.onResetNightMode,
    this.initialSettings,
    this.currentLanguageCode,
    this.onChangeLanguage,
    this.engine,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  AstroEngine get _engine => widget.engine ?? AstroEngine.instance;

  final GlobalKey _desktopLocationKey = GlobalKey();
  final GlobalKey _mobileLocationKey = GlobalKey();
  final GlobalKey _equipmentDesktopKey = GlobalKey();
  final GlobalKey _equipmentMobileKey = GlobalKey();
  final GlobalKey _filtersKey = GlobalKey();

  int _selectedTabIndex = 0;
  bool _isInitializing = true;
  bool _isLoadingTargets = false;
  bool _isLoadingPlanets = false;
  bool _isLoadingBrightStars = false;
  String? _initError;
  double _dbSizeMb = 0.0;

  late FilterState _filters;
  NightSummary? _nightSummary;
  List<TargetItem> _targets = [];
  List<TargetItem> _planets = [];
  List<TargetItem> _brightStars = [];
  List<ObservingListModel> _observingLists = [];

  @override
  void initState() {
    super.initState();
    _filters = widget.initialSettings?.filters ?? FilterState();
    _bootstrap();
  }

  @override
  void dispose() {
    FavoritesManager.instance.removeListener(_onFavoritesChanged);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final dbPath = await CatalogManager.getDatabasePath();
      final sizeMb = await CatalogManager.getDatabaseSizeMb();
      _dbSizeMb = sizeMb;

      _engine.initEngine(dbPath);

      _nightSummary = _engine.getNightSummary(
        latitude: _filters.observerLat,
        longitude: _filters.observerLon,
        elevation: _filters.observerElevation,
        date: _filters.date,
      );

      _observingLists = _engine.getObservingLists();

      // Auto-restore observing lists from settings backup if SQLite user lists are empty
      if (_observingLists.isEmpty &&
          widget.initialSettings?.observingListsBackup != null &&
          widget.initialSettings!.observingListsBackup!.isNotEmpty) {
        for (final list in widget.initialSettings!.observingListsBackup!) {
          final newId = _engine.createObservingList(
            list.name,
            list.description,
            list.sessionDate,
          );
          if (newId > 0) {
            for (final item in list.items) {
              _engine.addTargetToList(newId, item.dsoId, item.notes);
            }
          }
        }
        _observingLists = _engine.getObservingLists();
      }

      FavoritesManager.instance.init(widget.initialSettings?.favorites);
      FavoritesManager.instance.addListener(_onFavoritesChanged);

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

      setState(() {
        _isInitializing = false;
      });

      _runFiltering();

      if (widget.initialSettings?.hasCompletedTutorial != true) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 650), () {
            if (mounted) {
              _startSpotlightTour();
            }
          });
        });
      }
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _initError = e.toString();
      });
    }
  }

  void _startSpotlightTour() {
    if (_selectedTabIndex != 0) {
      setState(() => _selectedTabIndex = 0);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final isDesktopLocation = _desktopLocationKey.currentContext != null;
      final locKey = isDesktopLocation ? _desktopLocationKey : _mobileLocationKey;
      final eqKey = (_equipmentDesktopKey.currentContext != null)
          ? _equipmentDesktopKey
          : _equipmentMobileKey;

      SpotlightTour.show(
        context: context,
        isRedNightMode: widget.isRedNightMode,
        steps: [
          SpotlightTourStep(
            targetKey: locKey,
            title: l10n?.tourLocationTitle ?? "1. Set Your Observing Site",
            description: l10n?.tourLocationDesc ??
                "Target altitudes, rise/set curves, and darkness hours are calculated for your exact coordinates. Click here anytime to search for your city or enter coordinates.",
            icon: Icons.location_on_rounded,
            borderRadius: 8,
          ),
          SpotlightTourStep(
            targetKey: eqKey,
            title: l10n?.tourEquipmentTitle ?? "2. Configure Equipment & Optics",
            description: l10n?.tourEquipmentDesc ??
                "Add your telescopes, camera sensors, and focal reducers. Menelway calculates true sensor Field of View (FoV) framing and target suitability.",
            icon: Icons.camera_alt_rounded,
            borderRadius: 8,
          ),
          SpotlightTourStep(
            targetKey: _filtersKey,
            title: l10n?.tourFiltersTitle ?? "3. Target Filters & Criteria",
            description: l10n?.tourFiltersDesc ??
                "Filter thousands of deep-sky objects by minimum altitude, moon separation, DSO category, and transit window to plan the best imaging targets.",
            icon: Icons.tune_rounded,
            borderRadius: 8,
          ),
        ],
        onFinished: () {
          SettingsService.saveTutorialStatus(true);
        },
        onSkipped: () {
          SettingsService.saveTutorialStatus(true);
        },
      );
    });
  }

  void _runFiltering() {
    if (_nightSummary == null) return;
    setState(() {
      _isLoadingTargets = true;
      _isLoadingPlanets = true;
      _isLoadingBrightStars = true;
    });

    Future.microtask(() {
      try {
        final results = _engine.filterTargets(
          filters: _filters,
          night: _nightSummary!,
          stepMinutes: 10,
        );
        final planets = _engine.getPlanets(
          filters: _filters,
          night: _nightSummary!,
          stepMinutes: 10,
        );
        final stars = _engine.getBrightStars(
          filters: _filters,
          night: _nightSummary!,
          stepMinutes: 10,
        );
        if (mounted) {
          setState(() {
            _targets = results;
            _planets = planets;
            _brightStars = stars;
            _isLoadingTargets = false;
            _isLoadingPlanets = false;
            _isLoadingBrightStars = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoadingTargets = false;
            _isLoadingPlanets = false;
            _isLoadingBrightStars = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error calculating targets: $e")),
          );
        }
      }
    });
  }

  void _refreshObservingLists() {
    setState(() {
      _observingLists = _engine.getObservingLists();
    });
  }

  void _onFavoritesChanged() {
    _saveSettings();
    if (mounted) setState(() {});
  }

  void _saveSettings() {
    SettingsService.saveSettings(
      filters: _filters,
      isRedNightMode: widget.isRedNightMode,
      observingLists: _observingLists,
      equipmentProfiles: EquipmentManager.instance.profiles,
      activeEquipmentProfileId: EquipmentManager.instance.activeProfileId,
      favorites: FavoritesManager.instance.favorites,
      languageCode: widget.currentLanguageCode,
    );
  }

  void _handleToggleNightMode() {
    widget.onToggleNightMode();
    Future.microtask(() => _saveSettings());
  }

  void _resetFiltersOnly() {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _filters = FilterState(
        observerLat: _filters.observerLat,
        observerLon: _filters.observerLon,
        observerElevation: _filters.observerElevation,
        observerLocationName: _filters.observerLocationName,
      );
    });
    _saveSettings();
    _runFiltering();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.filtersResetSuccess ?? "Target filters reset to default (location preserved)."),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildCleanItem(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8)),
      ),
    );
  }

  void _showCleanDataDialog() {
    final l10n = AppLocalizations.of(context);
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final isRed = widget.isRedNightMode;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isRed ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n?.cleanDataConfirmTitle ?? "Clear All Saved Data?",
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.cleanDataWarning ?? "This will permanently erase your local configuration and reset everything back to factory defaults:",
              style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isRed ? AstroColors.nightVisionSurfaceVariant : AstroColors.spaceDarkSurfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCleanItem(l10n?.cleanDataPoint1 ?? "• Custom observer geographic location & coordinates", textColor),
                  _buildCleanItem(l10n?.cleanDataPoint2 ?? "• All custom Target Filters & Horizon masks", textColor),
                  _buildCleanItem(l10n?.cleanDataPoint3 ?? "• Equipment optics & camera sensor profiles", textColor),
                  _buildCleanItem(l10n?.cleanDataPoint4 ?? "• Favorite targets and custom observing lists", textColor),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n?.actionCannotBeUndone ?? "This action cannot be undone.",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n?.cleanDataCancel ?? "Cancel", style: TextStyle(color: textColor.withValues(alpha: 0.7))),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_forever_rounded, size: 16),
            label: Text(l10n?.cleanDataConfirm ?? "Clear All Data"),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _performCleanAllData();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _performCleanAllData() async {
    final l10n = AppLocalizations.of(context);
    // 1. Clear user settings file
    await SettingsService.clearSettings();

    // 2. Clear SQLite user lists and items
    _engine.clearAllObservingLists();

    // 3. Clear favorites
    FavoritesManager.instance.clear();

    // 4. Reset night mode if enabled
    widget.onResetNightMode?.call();

    // 5. Reset in-memory filters
    setState(() {
      _filters = FilterState();
      _observingLists = [];
      _planets = [];
      _brightStars = [];
      _nightSummary = _engine.getNightSummary(
        latitude: _filters.observerLat,
        longitude: _filters.observerLon,
        elevation: _filters.observerElevation,
        date: _filters.date,
      );
    });

    _runFiltering();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.cleanDataSuccessSnackBar ?? "All saved data, settings, and observing lists have been cleared."),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _editLocationDialog() {
    final searchController = TextEditingController();
    final latController = TextEditingController(text: _filters.observerLat.toStringAsFixed(4));
    final lonController = TextEditingController(text: _filters.observerLon.toStringAsFixed(4));
    final eleController = TextEditingController(text: _filters.observerElevation.round().toString());

    String currentLocationName = _filters.observerLocationName;
    List<GeoLocationResult> searchResults = [];
    bool isSearching = false;
    String? searchError;

    // Optional Precise Street / Neighborhood search state
    final addressController = TextEditingController();
    bool isAddressSearchExpanded = false;
    List<GeoLocationResult> addressResults = [];
    bool isSearchingAddress = false;
    String? addressError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final l10n = AppLocalizations.of(context);
          final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
          final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;

          Future<void> doSearch() async {
            final q = searchController.text.trim();
            if (q.length < 2) return;

            setDialogState(() {
              isSearching = true;
              searchError = null;
            });

            try {
              final results = await GeocodingService.searchCities(q);
              setDialogState(() {
                searchResults = results;
                isSearching = false;
                if (results.isEmpty) {
                  searchError = l10n?.locationNotFound(q) ?? "No matching cities found for '$q'.";
                }
              });
            } catch (e) {
              setDialogState(() {
                isSearching = false;
                searchError = l10n?.connectionError ?? "Connection error. Check internet connection.";
              });
            }
          }

          Future<void> doAddressSearch() async {
            final q = addressController.text.trim();
            if (q.length < 2) return;

            setDialogState(() {
              isSearchingAddress = true;
              addressError = null;
            });

            try {
              final results = await GeocodingService.searchPreciseAddress(q);
              setDialogState(() {
                addressResults = results;
                isSearchingAddress = false;
                if (results.isEmpty) {
                  addressError = "No matching street or neighborhood found for '$q'.";
                }
              });
            } catch (e) {
              setDialogState(() {
                isSearchingAddress = false;
                addressError = "Connection error. Check internet connection.";
              });
            }
          }

          final isNarrow = MediaQuery.of(context).size.width < 600;

          return AlertDialog(
            backgroundColor: widget.isRedNightMode
                ? AstroColors.nightVisionSurface
                : AstroColors.spaceDarkSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder,
              ),
            ),
            insetPadding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 12 : 40,
              vertical: isNarrow ? 16 : 24,
            ),
            title: Row(
              children: [
                Icon(Icons.location_city_rounded, color: accentColor, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n?.locationEditTitle ?? "Observer Location",
                    style: TextStyle(
                      color: textColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Tooltip(
                  message: l10n?.closeBtn ?? "Close",
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: widget.isRedNightMode
                            ? AstroColors.nightVisionSurfaceVariant
                            : const Color(0xFF222F42),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: widget.isRedNightMode
                              ? AstroColors.nightVisionBorder
                              : Colors.white.withValues(alpha: 0.3),
                          width: 1.4,
                        ),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: widget.isRedNightMode
                            ? AstroColors.nightVisionRed
                            : Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search by City & Country (Open-Meteo)
                    Text(
                      l10n?.searchCityOnline ?? "Search City & Country (Online)",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: l10n?.searchCityHint ?? "Type city",
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                          tooltip: l10n?.searchOnlineTooltip ?? "Search online",
                          onPressed: doSearch,
                        ),
                      ),
                      onSubmitted: (_) => doSearch(),
                    ),

                    if (isSearching) ...[
                      const SizedBox(height: 10),
                      const LinearProgressIndicator(),
                    ],

                    if (searchError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        searchError!,
                        style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.6)),
                      ),
                    ],

                    // Search Results
                    if (searchResults.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        decoration: BoxDecoration(
                          color: widget.isRedNightMode
                              ? AstroColors.nightVisionSurfaceVariant
                              : AstroColors.spaceDarkSurfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: widget.isRedNightMode
                                ? AstroColors.nightVisionBorder
                                : AstroColors.spaceDarkBorder,
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (int idx = 0; idx < searchResults.length; idx++) ...[
                                if (idx > 0) const Divider(height: 1),
                                ListTile(
                                  dense: true,
                                  title: Text(
                                    searchResults[idx].displayName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: textColor,
                                    ),
                                  ),
                                  subtitle: Text(
                                    l10n?.searchResultSubtitle(
                                      searchResults[idx].latitude.toStringAsFixed(2),
                                      searchResults[idx].longitude.toStringAsFixed(2),
                                      searchResults[idx].elevation.round().toString(),
                                    ) ?? "Lat: ${searchResults[idx].latitude.toStringAsFixed(2)}° | Lon: ${searchResults[idx].longitude.toStringAsFixed(2)}° | Elevation: ${searchResults[idx].elevation.round()}m",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: textColor.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  trailing: Icon(Icons.check_circle_outline_rounded, size: 18, color: accentColor),
                                  onTap: () {
                                    setDialogState(() {
                                      latController.text = searchResults[idx].latitude.toStringAsFixed(4);
                                      lonController.text = searchResults[idx].longitude.toStringAsFixed(4);
                                      eleController.text = searchResults[idx].elevation.round().toString();
                                      currentLocationName = searchResults[idx].displayName;
                                      searchResults = [];
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Optional Precise Street / Neighborhood / Landmark lookup (OSM Nominatim)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setDialogState(() => isAddressSearchExpanded = !isAddressSearchExpanded),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                        child: Row(
                          children: [
                            Icon(
                              isAddressSearchExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: accentColor,
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.signpost_rounded, size: 14, color: accentColor),
                            const SizedBox(width: 6),
                            Text(
                              "Precise Street / Neighborhood (Optional for Horizon)",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (isAddressSearchExpanded) ...[
                      const SizedBox(height: 6),
                      TextField(
                        controller: addressController,
                        decoration: InputDecoration(
                          hintText: l10n?.searchAddressHint ?? "Type the detailed location, like street name, and city",
                          prefixIcon: const Icon(Icons.add_location_alt_rounded, size: 18),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                            tooltip: l10n?.searchAddressTooltip ?? "Search precise street/neighborhood (worldwide)",
                            onPressed: doAddressSearch,
                          ),
                        ),
                        onSubmitted: (_) => doAddressSearch(),
                      ),
                      if (isSearchingAddress) ...[
                        const SizedBox(height: 6),
                        const LinearProgressIndicator(),
                      ],
                      if (addressError != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          addressError!,
                          style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.6)),
                        ),
                      ],
                      if (addressResults.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            color: widget.isRedNightMode
                                ? AstroColors.nightVisionSurfaceVariant
                                : AstroColors.spaceDarkSurfaceVariant,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: widget.isRedNightMode
                                  ? AstroColors.nightVisionBorder
                                  : AstroColors.spaceDarkBorder,
                            ),
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (int idx = 0; idx < addressResults.length; idx++) ...[
                                  if (idx > 0) const Divider(height: 1),
                                  ListTile(
                                    dense: true,
                                    leading: Icon(Icons.pin_drop_rounded, size: 18, color: accentColor),
                                    title: Text(
                                      addressResults[idx].displayName,
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: textColor),
                                    ),
                                    subtitle: Text(
                                      "Lat: ${addressResults[idx].latitude.toStringAsFixed(4)}° | Lon: ${addressResults[idx].longitude.toStringAsFixed(4)}°",
                                      style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.6)),
                                    ),
                                    trailing: Icon(Icons.check_circle_outline_rounded, size: 16, color: accentColor),
                                    onTap: () async {
                                      final r = addressResults[idx];
                                      setDialogState(() {
                                        latController.text = r.latitude.toStringAsFixed(4);
                                        lonController.text = r.longitude.toStringAsFixed(4);
                                        currentLocationName = r.displayName;
                                        addressResults = [];
                                      });
                                      // Auto-fetch precise elevation
                                      final elev = await GeocodingService.fetchElevation(r.latitude, r.longitude);
                                      if (elev != null && ctx.mounted) {
                                        setDialogState(() {
                                          eleController.text = elev.round().toString();
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Manual Coordinates Section
                    Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 14, color: textColor.withValues(alpha: 0.6)),
                        const SizedBox(width: 4),
                        Text(
                          l10n?.selectedCoordsElevation ?? "Selected Coordinates & Elevation",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: textColor.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: latController,
                            decoration: InputDecoration(labelText: l10n?.latitude ?? "Latitude (°)"),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: lonController,
                            decoration: InputDecoration(labelText: l10n?.longitude ?? "Longitude (°)"),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: eleController,
                            decoration: InputDecoration(labelText: l10n?.elevation ?? "Elevation (m)"),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          ),
                        ),
                      ],
                    ),


                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                child: Text(l10n?.cancel ?? "Cancel"),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
              FilledButton(
                child: Text(l10n?.applyLocation ?? "Apply Location"),
                onPressed: () {
                  final newLat = double.tryParse(latController.text) ?? _filters.observerLat;
                  final newLon = double.tryParse(lonController.text) ?? _filters.observerLon;
                  final newEle = double.tryParse(eleController.text) ?? _filters.observerElevation;

                  setState(() {
                    _filters.observerLat = newLat;
                    _filters.observerLon = newLon;
                    _filters.observerElevation = newEle;
                    _filters.observerLocationName = currentLocationName;
                    _nightSummary = _engine.getNightSummary(
                      latitude: newLat,
                      longitude: newLon,
                      elevation: newEle,
                      date: _filters.date,
                    );
                  });
                  Navigator.of(ctx).pop();
                  _saveSettings();
                  _runFiltering();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMobileStatusStrip(Color textColor, Color accentColor) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: widget.isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface,
        border: Border(
          bottom: BorderSide(
            color: widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Observer Location Pill (tappable)
            InkWell(
              key: _mobileLocationKey,
              onTap: _editLocationDialog,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 40.0,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.isRedNightMode
                      ? AstroColors.nightVisionSurfaceVariant
                      : AstroColors.spaceDarkSurfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.isRedNightMode
                        ? AstroColors.nightVisionBorder
                        : AstroColors.spaceDarkBorder,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: accentColor),
                    const SizedBox(width: 5),
                    Text(
                      _filters.observerLocationName,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, size: 18, color: textColor.withValues(alpha: 0.7)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Night summary pill
            if (_nightSummary != null) ...[
              Container(
                height: 40.0,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.isRedNightMode
                      ? AstroColors.nightVisionSurfaceVariant
                      : AstroColors.spaceDarkSurfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.isRedNightMode
                        ? AstroColors.nightVisionBorder
                        : AstroColors.spaceDarkBorder,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.dark_mode_outlined, size: 15, color: AstroColors.nebulaIndigo),
                    const SizedBox(width: 5),
                    Text(
                      "${l10n?.darkTime ?? 'Dark'}: ${DateFormat('HH:mm').format(_nightSummary!.astronomicalDusk)} - ${DateFormat('HH:mm').format(_nightSummary!.astronomicalDawn)}",
                      style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.85)),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.brightness_2_rounded, size: 15, color: AstroColors.starGold),
                    const SizedBox(width: 4),
                    Text(
                      "${(_nightSummary!.moonIllumination * 100).round()}%",
                      style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
            ],

            // Database size pill
            Container(
              height: 40.0,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.isRedNightMode
                    ? AstroColors.nightVisionSurfaceVariant
                    : AstroColors.spaceDarkSurfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.isRedNightMode
                      ? AstroColors.nightVisionBorder
                      : AstroColors.spaceDarkBorder,
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.storage_rounded, size: 14, color: textColor.withValues(alpha: 0.6)),
                  const SizedBox(width: 4),
                  Text(
                    "${_dbSizeMb.toStringAsFixed(1)} MB",
                    style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;

    if (_isInitializing) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: accentColor),
              const SizedBox(height: 16),
              Text(
                l10n?.initializingEngine ?? "Initializing Astro Targets Engine & Database...",
                style: TextStyle(color: textColor.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      );
    }

    if (_initError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text(
                  l10n?.failedLoadCore ?? "Failed to load astronomical core",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 8),
                Text(_initError!, style: const TextStyle(fontSize: 12, color: Colors.white60)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _bootstrap,
                  child: Text(l10n?.retry ?? "Retry"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isWide = MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: isWide ? 16.0 : 10.0,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: widget.isRedNightMode
                  ? ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        AstroColors.nightVisionRed,
                        BlendMode.modulate,
                      ),
                      child: Image.asset(
                        'assets/app_icon.png',
                        width: 28,
                        height: 28,
                        fit: BoxFit.contain,
                      ),
                    )
                  : Image.asset(
                      'assets/app_icon.png',
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "MENELWAY",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    l10n?.appSubtitle ?? "Astro Target & Session Planner",
                    style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.5)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (isWide) ...[
            // Observer Location Pill (Desktop)
            InkWell(
              key: _desktopLocationKey,
              onTap: _editLocationDialog,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 32.0,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.isRedNightMode
                      ? AstroColors.nightVisionSurfaceVariant
                      : AstroColors.spaceDarkSurfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.isRedNightMode
                        ? AstroColors.nightVisionBorder
                        : AstroColors.spaceDarkBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 14, color: accentColor),
                    const SizedBox(width: 4),
                    Text(
                      "${_filters.observerLocationName} • ${_filters.observerLat >= 0 ? '${_filters.observerLat.toStringAsFixed(1)}°N' : '${(-_filters.observerLat).toStringAsFixed(1)}°S'}, ${_filters.observerLon >= 0 ? '${_filters.observerLon.toStringAsFixed(1)}°E' : '${(-_filters.observerLon).toStringAsFixed(1)}°W'} (${_filters.observerElevation.round()}m)",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Night summary pill (Desktop)
            if (_nightSummary != null)
              Container(
                height: 32.0,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.isRedNightMode
                      ? AstroColors.nightVisionSurfaceVariant
                      : AstroColors.spaceDarkSurfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.isRedNightMode
                        ? AstroColors.nightVisionBorder
                        : AstroColors.spaceDarkBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.dark_mode_outlined, size: 14, color: AstroColors.nebulaIndigo),
                    const SizedBox(width: 4),
                    Text(
                      "${l10n?.darkness ?? "Darkness"}: ${DateFormat('HH:mm').format(_nightSummary!.astronomicalDusk)} - ${DateFormat('HH:mm').format(_nightSummary!.astronomicalDawn)}",
                      style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.8)),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.brightness_2_rounded, size: 14, color: AstroColors.starGold),
                    const SizedBox(width: 4),
                    Text(
                      "${(_nightSummary!.moonIllumination * 100).round()}% (${localizeMoonPhase(_nightSummary!.moonPhaseName, l10n)})",
                      style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
            const SizedBox(width: 8),

            // Database size pill (Desktop)
            Container(
              height: 32.0,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.isRedNightMode
                    ? AstroColors.nightVisionSurfaceVariant
                    : AstroColors.spaceDarkSurfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: widget.isRedNightMode
                      ? AstroColors.nightVisionBorder
                      : AstroColors.spaceDarkBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.storage_rounded, size: 13, color: textColor.withValues(alpha: 0.6)),
                  const SizedBox(width: 4),
                  Text(
                    "${_dbSizeMb.toStringAsFixed(1)} MB",
                    style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.6)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
          ],

          // Red Night-Vision Mode Toggle
          SizedBox(
            width: isWide ? 32.0 : 40.0,
            height: isWide ? 32.0 : 40.0,
            child: IconButton(
              tooltip: widget.isRedNightMode ? (l10n?.nightModeStandard ?? "Deep Space Obsidian") : (l10n?.nightModeRed ?? "Telescope Red Mode"),
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                backgroundColor: widget.isRedNightMode
                    ? AstroColors.nightVisionRed.withValues(alpha: 0.15)
                    : AstroColors.starlightCyan.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isWide ? 8 : 10),
                  side: BorderSide(
                    color: widget.isRedNightMode
                        ? AstroColors.nightVisionRed.withValues(alpha: 0.6)
                        : AstroColors.starlightCyan.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
              ),
              icon: Icon(
                widget.isRedNightMode ? Icons.nightlight_round : Icons.remove_red_eye_rounded,
                size: isWide ? 16 : 20,
                color: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan,
              ),
              onPressed: _handleToggleNightMode,
            ),
          ),
          SizedBox(width: isWide ? 8 : 6),

          // Language Switcher Pill (Quick toggle / selection)
          PopupMenuButton<String>(
            tooltip: l10n?.language ?? "Language",
            color: widget.isRedNightMode ? const Color(0xFF200505) : const Color(0xFF16202E),
            elevation: 10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: widget.isRedNightMode
                    ? AstroColors.nightVisionRed.withValues(alpha: 0.6)
                    : AstroColors.starlightCyan.withValues(alpha: 0.45),
                width: 1.2,
              ),
            ),
            onSelected: (code) {
              widget.onChangeLanguage?.call(code.isEmpty ? null : code);
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'en',
                child: Row(
                  children: [
                    const Text("🇺🇸", style: TextStyle(fontSize: 15)),
                    const SizedBox(width: 8),
                    Text(
                      "English",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: widget.currentLanguageCode == 'en' ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (widget.currentLanguageCode == 'en') ...[
                      const Spacer(),
                      Icon(Icons.check_rounded, size: 16, color: accentColor),
                    ],
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'pt',
                child: Row(
                  children: [
                    const Text("🇧🇷", style: TextStyle(fontSize: 15)),
                    const SizedBox(width: 8),
                    Text(
                      "Português (Brasil)",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: widget.currentLanguageCode == 'pt' ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (widget.currentLanguageCode == 'pt') ...[
                      const Spacer(),
                      Icon(Icons.check_rounded, size: 16, color: accentColor),
                    ],
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: '',
                child: Row(
                  children: [
                    Icon(Icons.settings_system_daydream_rounded, size: 16, color: textColor.withValues(alpha: 0.7)),
                    const SizedBox(width: 8),
                    Text(
                      l10n?.languageSystem ?? "System Default",
                      style: TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: (widget.currentLanguageCode == null || widget.currentLanguageCode!.isEmpty)
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    if (widget.currentLanguageCode == null || widget.currentLanguageCode!.isEmpty) ...[
                      const Spacer(),
                      Icon(Icons.check_rounded, size: 16, color: accentColor),
                    ],
                  ],
                ),
              ),
            ],
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                height: isWide ? 32.0 : 40.0,
                padding: EdgeInsets.symmetric(horizontal: isWide ? 8 : 7),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.isRedNightMode
                      ? AstroColors.nightVisionRed.withValues(alpha: 0.15)
                      : AstroColors.starlightCyan.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(isWide ? 8 : 10),
                  border: Border.all(
                    color: widget.isRedNightMode
                        ? AstroColors.nightVisionRed.withValues(alpha: 0.6)
                        : AstroColors.starlightCyan.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.translate_rounded,
                      size: isWide ? 15 : 18,
                      color: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan,
                    ),
                    SizedBox(width: isWide ? 5 : 4),
                    Text(
                      widget.currentLanguageCode == 'pt' ? "PT" : (widget.currentLanguageCode == 'en' ? "EN" : "AUTO"),
                      style: TextStyle(
                        fontSize: isWide ? 11 : 12,
                        fontWeight: FontWeight.w700,
                        color: widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_drop_down,
                      size: isWide ? 14 : 18,
                      color: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: isWide ? 8 : 6),

          // Equipment Rigs Manager Button
          if (isWide)
            Tooltip(
              message: l10n?.equipmentRigsTooltip ?? "Equipment Rigs & Optics",
              child: SizedBox(
                key: _equipmentDesktopKey,
                height: 32.0,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: widget.isRedNightMode
                        ? AstroColors.nightVisionRed.withValues(alpha: 0.15)
                        : AstroColors.starGold.withValues(alpha: 0.12),
                    foregroundColor: widget.isRedNightMode
                        ? AstroColors.nightVisionRed
                        : AstroColors.starGold,
                    side: BorderSide(
                      color: widget.isRedNightMode
                          ? AstroColors.nightVisionRed.withValues(alpha: 0.8)
                          : AstroColors.starGold.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(0, 32.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: Icon(
                    Icons.camera_alt_rounded,
                    size: 16,
                    color: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starGold,
                  ),
                  label: Text(
                    l10n?.equipmentRigsButton ?? "Equipment Rigs",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starGold,
                    ),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => EquipmentDialog(
                        isRedNightMode: widget.isRedNightMode,
                        onSaved: () {
                          _saveSettings();
                          setState(() {});
                        },
                      ),
                    );
                  },
                ),
              ),
            )
          else
            SizedBox(
              key: _equipmentMobileKey,
              width: 40.0,
              height: 40.0,
              child: IconButton(
                tooltip: l10n?.equipmentRigsTooltip ?? "Equipment Rigs & Optics",
                padding: EdgeInsets.zero,
                style: IconButton.styleFrom(
                  backgroundColor: widget.isRedNightMode
                      ? AstroColors.nightVisionRed.withValues(alpha: 0.2)
                      : AstroColors.starGold.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: widget.isRedNightMode
                          ? AstroColors.nightVisionRed.withValues(alpha: 0.8)
                          : AstroColors.starGold.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                  ),
                ),
                icon: Icon(
                  Icons.camera_alt_rounded,
                  size: 20,
                  color: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starGold,
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => EquipmentDialog(
                      isRedNightMode: widget.isRedNightMode,
                      onSaved: () {
                        _saveSettings();
                        setState(() {});
                      },
                    ),
                  );
                },
              ),
            ),
          SizedBox(width: isWide ? 8 : 6),

          // Settings & Clean Data Window Pill
          Tooltip(
            message: l10n?.settingsAndDataTooltip ?? "Settings & Data",
            child: InkWell(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => SettingsDialog(
                    isRedNightMode: widget.isRedNightMode,
                    maxTargets: _filters.maxTargets,
                    onMaxTargetsChanged: (newLimit) {
                      setState(() {
                        _filters.maxTargets = newLimit;
                      });
                      _saveSettings();
                      _runFiltering();
                    },
                    onResetFilters: () {
                      _resetFiltersOnly();
                    },
                    onCleanAllData: () {
                      _showCleanDataDialog();
                    },
                    onReplayTour: _startSpotlightTour,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(isWide ? 8 : 10),
              child: Container(
                height: isWide ? 32.0 : 40.0,
                width: isWide ? null : 40.0,
                padding: isWide ? const EdgeInsets.symmetric(horizontal: 10) : EdgeInsets.zero,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.isRedNightMode
                      ? AstroColors.nightVisionRed.withValues(alpha: 0.18)
                      : AstroColors.starlightCyan.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(isWide ? 8 : 10),
                  border: Border.all(
                    color: widget.isRedNightMode
                        ? AstroColors.nightVisionRed.withValues(alpha: 0.75)
                        : AstroColors.starlightCyan.withValues(alpha: 0.55),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.isRedNightMode
                          ? AstroColors.nightVisionRed.withValues(alpha: 0.18)
                          : AstroColors.starlightCyan.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.settings_suggest_rounded,
                      size: isWide ? 15 : 20,
                      color: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan,
                    ),
                    if (isWide) ...[
                      const SizedBox(width: 6),
                      Text(
                        l10n?.settingsAndData ?? "Settings & Data",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: isWide ? 10 : 8),
        ],
      ),
      body: Column(
        children: [
          if (!isWide) _buildMobileStatusStrip(textColor, accentColor),
          Expanded(
            child: Row(
              children: [
          // Navigation rail for desktop
          if (isWide)
            NavigationRail(
              backgroundColor: widget.isRedNightMode
                  ? AstroColors.nightVisionSurface
                  : AstroColors.spaceDarkSurface,
              selectedIndex: _selectedTabIndex,
              onDestinationSelected: (idx) => setState(() => _selectedTabIndex = idx),
              labelType: NavigationRailLabelType.all,
              useIndicator: true,
              indicatorColor: accentColor.withValues(alpha: 0.18),
              selectedIconTheme: IconThemeData(color: accentColor, size: 24),
              unselectedIconTheme: IconThemeData(
                color: widget.isRedNightMode
                    ? AstroColors.nightVisionRedDim.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.7),
                size: 24,
              ),
              selectedLabelTextStyle: TextStyle(
                color: accentColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelTextStyle: TextStyle(
                color: widget.isRedNightMode
                    ? AstroColors.nightVisionRedDim.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
              destinations: [
                NavigationRailDestination(
                  icon: Icon(
                    Icons.radar_rounded,
                    color: _selectedTabIndex == 0
                        ? accentColor
                        : (widget.isRedNightMode ? AstroColors.nightVisionRedDim : Colors.white.withValues(alpha: 0.7)),
                  ),
                  selectedIcon: Icon(Icons.radar_rounded, color: accentColor),
                  label: Text(l10n?.tabTargets ?? "Targets"),
                ),
                NavigationRailDestination(
                  icon: Icon(
                    Icons.public_rounded,
                    color: _selectedTabIndex == 1
                        ? accentColor
                        : (widget.isRedNightMode ? AstroColors.nightVisionRedDim : Colors.white.withValues(alpha: 0.7)),
                  ),
                  selectedIcon: Icon(Icons.public_rounded, color: accentColor),
                  label: Text(l10n?.tabPlanets ?? "Planets"),
                ),
                NavigationRailDestination(
                  icon: Icon(
                    Icons.star_rounded,
                    color: _selectedTabIndex == 2
                        ? accentColor
                        : (widget.isRedNightMode ? AstroColors.nightVisionRedDim : Colors.white.withValues(alpha: 0.7)),
                  ),
                  selectedIcon: Icon(Icons.star_rounded, color: accentColor),
                  label: Text(l10n?.tabBrightStars ?? "Bright Stars"),
                ),
                NavigationRailDestination(
                  icon: Icon(
                    Icons.calendar_month_rounded,
                    color: _selectedTabIndex == 3
                        ? accentColor
                        : (widget.isRedNightMode ? AstroColors.nightVisionRedDim : Colors.white.withValues(alpha: 0.7)),
                  ),
                  selectedIcon: Icon(Icons.calendar_month_rounded, color: accentColor),
                  label: Text(l10n?.tabPlanner ?? "Planner"),
                ),
                NavigationRailDestination(
                  icon: Icon(
                    Icons.playlist_play_rounded,
                    color: _selectedTabIndex == 4
                        ? accentColor
                        : (widget.isRedNightMode ? AstroColors.nightVisionRedDim : Colors.white.withValues(alpha: 0.7)),
                  ),
                  selectedIcon: Icon(Icons.playlist_play_rounded, color: accentColor),
                  label: Text(l10n?.tabObservingLists ?? "Observing Lists"),
                ),
                NavigationRailDestination(
                  icon: Icon(
                    Icons.favorite_rounded,
                    color: _selectedTabIndex == 5
                        ? (widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.pinkAccent)
                        : (widget.isRedNightMode ? AstroColors.nightVisionRedDim : Colors.white.withValues(alpha: 0.7)),
                  ),
                  selectedIcon: Icon(
                    Icons.favorite_rounded,
                    color: widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.pinkAccent,
                  ),
                  label: Text(l10n?.tabFavorites ?? "Favorites"),
                ),
              ],
            ),

          // Tab Content
          Expanded(
            child: _selectedTabIndex == 0
                ? TargetSearchView(
                    filterButtonKey: _filtersKey,
                    targets: _targets,
                    night: _nightSummary!,
                    filters: _filters,
                    isLoading: _isLoadingTargets,
                    isRedNightMode: widget.isRedNightMode,
                    availableLists: _observingLists,
                    onFilterChanged: (updated) {
                      setState(() {
                        _filters = updated;
                      });
                      _saveSettings();
                      _runFiltering();
                    },
                    onAddToList: (listId, dsoId, notes) {
                      _engine.addTargetToList(listId, dsoId, notes);
                      _refreshObservingLists();
                      _saveSettings();
                    },
                  )
                : _selectedTabIndex == 1
                    ? PlanetsView(
                        planets: _planets,
                        night: _nightSummary!,
                        filters: _filters,
                        isLoading: _isLoadingPlanets,
                        isRedNightMode: widget.isRedNightMode,
                        availableLists: _observingLists,
                        onFilterChanged: (updated) {
                          setState(() {
                            _filters = updated;
                          });
                          _saveSettings();
                          _runFiltering();
                        },
                        onAddToList: (listId, dsoId, notes) {
                          _engine.addTargetToList(listId, dsoId, notes);
                          _refreshObservingLists();
                          _saveSettings();
                        },
                      )
                : _selectedTabIndex == 2
                    ? BrightStarsView(
                        stars: _brightStars,
                        night: _nightSummary!,
                        filters: _filters,
                        isLoading: _isLoadingBrightStars,
                        isRedNightMode: widget.isRedNightMode,
                        availableLists: _observingLists,
                        onFilterChanged: (updated) {
                          setState(() {
                            _filters = updated;
                          });
                          _saveSettings();
                          _runFiltering();
                        },
                        onAddToList: (listId, dsoId, notes) {
                          _engine.addTargetToList(listId, dsoId, notes);
                          _refreshObservingLists();
                          _saveSettings();
                        },
                      )
                : _selectedTabIndex == 3
                    ? PlannerView(
                        filters: _filters,
                        night: _nightSummary!,
                        isRedNightMode: widget.isRedNightMode,
                        availableLists: _observingLists,
                        engine: _engine,
                        onAddToList: (listId, dsoId, notes) {
                          _engine.addTargetToList(listId, dsoId, notes ?? '');
                          _refreshObservingLists();
                          _saveSettings();
                        },
                        onFilterChanged: (updated) {
                          setState(() {
                            _filters = updated;
                          });
                          _saveSettings();
                          _runFiltering();
                        },
                      )
                    : _selectedTabIndex == 4
                        ? ObservingListsView(
                        lists: _observingLists,
                        isRedNightMode: widget.isRedNightMode,
                        onCreateList: (name, desc, date) {
                          _engine.createObservingList(name, desc, date);
                          _refreshObservingLists();
                          _saveSettings();
                        },
                        onDeleteList: (listId) {
                          _engine.deleteObservingList(listId);
                          _refreshObservingLists();
                          _saveSettings();
                        },
                        onRemoveItem: (listId, dsoId) {
                          _engine.removeTargetFromList(listId, dsoId);
                          _refreshObservingLists();
                          _saveSettings();
                        },
                      )
                    : FavoritesView(
                        night: _nightSummary,
                        filters: _filters,
                        isRedNightMode: widget.isRedNightMode,
                        availableLists: _observingLists,
                        onAddToList: (listId, dsoId, notes) {
                          _engine.addTargetToList(listId, dsoId, notes);
                          _refreshObservingLists();
                          _saveSettings();
                        },
                        onExploreTargets: () {
                          setState(() => _selectedTabIndex = 0);
                        },
                      ),
          ),
        ],
      ),
    ),
  ],
),
      bottomNavigationBar: !isWide
          ? BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: widget.isRedNightMode
                  ? AstroColors.nightVisionSurface
                  : AstroColors.spaceDarkSurface,
              selectedItemColor: accentColor,
              unselectedItemColor: textColor.withValues(alpha: 0.5),
              currentIndex: _selectedTabIndex,
              onTap: (idx) => setState(() => _selectedTabIndex = idx),
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.radar_rounded),
                  label: l10n?.tabTargets ?? "Targets",
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.public_rounded),
                  label: l10n?.tabPlanets ?? "Planets",
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.star_rounded),
                  label: l10n?.tabBrightStars ?? "Bright Stars",
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: l10n?.tabPlanner ?? "Planner",
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.playlist_play_rounded),
                  label: l10n?.tabObservingLists ?? "Observing Lists",
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.favorite_rounded),
                  label: l10n?.tabFavorites ?? "Favorites",
                ),
              ],
            )
          : null,
    );
  }
}
