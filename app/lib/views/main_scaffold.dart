import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/astro_bridge.dart';
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
import 'equipment_dialog.dart';
import 'favorites_view.dart';
import 'observing_lists_view.dart';
import 'planner_view.dart';
import 'settings_dialog.dart';
import 'target_search_view.dart';

class MainScaffold extends StatefulWidget {
  final bool isRedNightMode;
  final VoidCallback onToggleNightMode;
  final VoidCallback? onResetNightMode;
  final AppSettingsData? initialSettings;
  final String? currentLanguageCode;
  final ValueChanged<String?>? onChangeLanguage;

  const MainScaffold({
    super.key,
    required this.isRedNightMode,
    required this.onToggleNightMode,
    this.onResetNightMode,
    this.initialSettings,
    this.currentLanguageCode,
    this.onChangeLanguage,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedTabIndex = 0;
  bool _isInitializing = true;
  bool _isLoadingTargets = false;
  String? _initError;
  double _dbSizeMb = 0.0;

  late FilterState _filters;
  NightSummary? _nightSummary;
  List<TargetItem> _targets = [];
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

      AstroBridge.instance.initEngine(dbPath);

      _nightSummary = AstroBridge.instance.getNightSummary(
        latitude: _filters.observerLat,
        longitude: _filters.observerLon,
        elevation: _filters.observerElevation,
        date: _filters.date,
      );

      _observingLists = AstroBridge.instance.getObservingLists();

      // Auto-restore observing lists from settings backup if SQLite user lists are empty
      if (_observingLists.isEmpty &&
          widget.initialSettings?.observingListsBackup != null &&
          widget.initialSettings!.observingListsBackup!.isNotEmpty) {
        for (final list in widget.initialSettings!.observingListsBackup!) {
          final newId = AstroBridge.instance.createObservingList(
            list.name,
            list.description,
            list.sessionDate,
          );
          if (newId > 0) {
            for (final item in list.items) {
              AstroBridge.instance.addTargetToList(newId, item.dsoId, item.notes);
            }
          }
        }
        _observingLists = AstroBridge.instance.getObservingLists();
      }

      FavoritesManager.instance.init(widget.initialSettings?.favorites);
      FavoritesManager.instance.addListener(_onFavoritesChanged);

      setState(() {
        _isInitializing = false;
      });

      _runFiltering();
    } catch (e) {
      setState(() {
        _isInitializing = false;
        _initError = e.toString();
      });
    }
  }

  void _runFiltering() {
    if (_nightSummary == null) return;
    setState(() => _isLoadingTargets = true);

    Future.microtask(() {
      try {
        final results = AstroBridge.instance.filterTargets(
          filters: _filters,
          night: _nightSummary!,
          stepMinutes: 10,
        );
        if (mounted) {
          setState(() {
            _targets = results;
            _isLoadingTargets = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoadingTargets = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error calculating targets: $e")),
          );
        }
      }
    });
  }

  void _refreshObservingLists() {
    setState(() {
      _observingLists = AstroBridge.instance.getObservingLists();
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
    AstroBridge.instance.clearAllObservingLists();

    // 3. Clear favorites
    FavoritesManager.instance.clear();

    // 4. Reset night mode if enabled
    widget.onResetNightMode?.call();

    // 5. Reset in-memory filters
    setState(() {
      _filters = FilterState();
      _observingLists = [];
      _nightSummary = AstroBridge.instance.getNightSummary(
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
            title: Row(
              children: [
                Icon(Icons.location_city_rounded, color: accentColor, size: 22),
                const SizedBox(width: 8),
                Text(
                  l10n?.locationEditTitle ?? "Observer Location",
                  style: TextStyle(
                    color: textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
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
                        hintText: l10n?.searchCityHint ?? "Type city (e.g. Campinas, London, Atacama, Tokyo)...",
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
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: searchResults.length,
                          separatorBuilder: (_, index) => const Divider(height: 1),
                          itemBuilder: (ctx, idx) {
                            final r = searchResults[idx];
                            return ListTile(
                              dense: true,
                              title: Text(
                                r.displayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: textColor,
                                ),
                              ),
                              subtitle: Text(
                                l10n?.searchResultSubtitle(
                                  r.latitude.toStringAsFixed(2),
                                  r.longitude.toStringAsFixed(2),
                                  r.elevation.round().toString(),
                                ) ?? "Lat: ${r.latitude.toStringAsFixed(2)}° | Lon: ${r.longitude.toStringAsFixed(2)}° | Elevation: ${r.elevation.round()}m",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: textColor.withValues(alpha: 0.6),
                                ),
                              ),
                              trailing: Icon(Icons.check_circle_outline_rounded, size: 18, color: accentColor),
                              onTap: () {
                                setDialogState(() {
                                  latController.text = r.latitude.toStringAsFixed(4);
                                  lonController.text = r.longitude.toStringAsFixed(4);
                                  eleController.text = r.elevation.round().toString();
                                  currentLocationName = r.displayName;
                                  searchResults = [];
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
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
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: lonController,
                            decoration: InputDecoration(labelText: l10n?.longitude ?? "Longitude (°)"),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: eleController,
                            decoration: InputDecoration(labelText: l10n?.elevation ?? "Elevation (m)"),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    // Quick Presets
                    Text(
                      l10n?.popularAstroSites ?? "Popular Astrophotography Sites:",
                      style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.5)),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        ActionChip(
                          label: const Text("Atacama Desert (2500m)", style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setDialogState(() {
                              latController.text = "-23.0293";
                              lonController.text = "-67.7547";
                              eleController.text = "2500";
                              currentLocationName = "Atacama Desert, Chile";
                            });
                          },
                        ),
                        ActionChip(
                          label: const Text("La Palma (2396m)", style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setDialogState(() {
                              latController.text = "28.7636";
                              lonController.text = "-17.8947";
                              eleController.text = "2396";
                              currentLocationName = "Roque de los Muchachos, La Palma";
                            });
                          },
                        ),
                        ActionChip(
                          label: const Text("NYC (10m)", style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setDialogState(() {
                              latController.text = "40.7128";
                              lonController.text = "-74.0060";
                              eleController.text = "10";
                              currentLocationName = "New York, USA";
                            });
                          },
                        ),
                        ActionChip(
                          label: const Text("London (25m)", style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setDialogState(() {
                              latController.text = "51.5074";
                              lonController.text = "-0.1278";
                              eleController.text = "25";
                              currentLocationName = "London, UK";
                            });
                          },
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
                    _nightSummary = AstroBridge.instance.getNightSummary(
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          children: [
            // Observer Location Pill (tappable)
            InkWell(
              onTap: _editLocationDialog,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.isRedNightMode
                      ? AstroColors.nightVisionSurfaceVariant
                      : AstroColors.spaceDarkSurfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: widget.isRedNightMode
                        ? AstroColors.nightVisionBorder
                        : AstroColors.spaceDarkBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 13, color: accentColor),
                    const SizedBox(width: 4),
                    Text(
                      _filters.observerLocationName,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
                    ),
                    const SizedBox(width: 3),
                    Icon(Icons.arrow_drop_down, size: 14, color: textColor.withValues(alpha: 0.6)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Night summary pill
            if (_nightSummary != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.isRedNightMode
                      ? AstroColors.nightVisionSurfaceVariant
                      : AstroColors.spaceDarkSurfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: widget.isRedNightMode
                        ? AstroColors.nightVisionBorder
                        : AstroColors.spaceDarkBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.dark_mode_outlined, size: 13, color: AstroColors.nebulaIndigo),
                    const SizedBox(width: 4),
                    Text(
                      "${l10n?.darkTime ?? 'Dark'}: ${DateFormat('HH:mm').format(_nightSummary!.astronomicalDusk)} - ${DateFormat('HH:mm').format(_nightSummary!.astronomicalDawn)}",
                      style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.8)),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.brightness_2_rounded, size: 13, color: AstroColors.starGold),
                    const SizedBox(width: 4),
                    Text(
                      "${(_nightSummary!.moonIllumination * 100).round()}%",
                      style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
            ],

            // Database size pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: widget.isRedNightMode
                    ? AstroColors.nightVisionSurfaceVariant
                    : AstroColors.spaceDarkSurfaceVariant,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: widget.isRedNightMode
                      ? AstroColors.nightVisionBorder
                      : AstroColors.spaceDarkBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.storage_rounded, size: 12, color: textColor.withValues(alpha: 0.6)),
                  const SizedBox(width: 3),
                  Text(
                    "${_dbSizeMb.toStringAsFixed(1)} MB",
                    style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.6)),
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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.blur_on_rounded, color: accentColor, size: 20),
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
              onTap: _editLocationDialog,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
          IconButton(
            tooltip: widget.isRedNightMode ? (l10n?.nightModeStandard ?? "Deep Space Obsidian") : (l10n?.nightModeRed ?? "Telescope Red Mode"),
            style: IconButton.styleFrom(
              backgroundColor: widget.isRedNightMode
                  ? AstroColors.nightVisionRed.withValues(alpha: 0.15)
                  : AstroColors.starlightCyan.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
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
              size: 16,
              color: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan,
            ),
            onPressed: _handleToggleNightMode,
          ),
          const SizedBox(width: 8),

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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.isRedNightMode
                      ? AstroColors.nightVisionRed.withValues(alpha: 0.15)
                      : AstroColors.starlightCyan.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
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
                      size: 15,
                      color: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      widget.currentLanguageCode == 'pt' ? "PT" : (widget.currentLanguageCode == 'en' ? "EN" : "AUTO"),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_drop_down,
                      size: 14,
                      color: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Equipment Rigs Manager Button
          if (isWide)
            Tooltip(
              message: l10n?.equipmentRigsTooltip ?? "Equipment Rigs & Optics",
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: Icon(
                Icons.camera_alt_rounded,
                size: 18,
                color: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starGold,
              ),
              label: Text(
                l10n?.equipmentRigsButton ?? "Equipment Rigs",
                style: TextStyle(
                  fontSize: 12,
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
          )
          else
            IconButton(
              tooltip: l10n?.equipmentRigsTooltip ?? "Equipment Rigs & Optics",
              style: IconButton.styleFrom(
                backgroundColor: widget.isRedNightMode
                    ? AstroColors.nightVisionRed.withValues(alpha: 0.2)
                    : AstroColors.starGold.withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
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
                size: 18,
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
          const SizedBox(width: 8),

          // Settings & Clean Data Window Pill
          Tooltip(
            message: l10n?.settingsAndDataTooltip ?? "Settings & Data",
            child: InkWell(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => SettingsDialog(
                    isRedNightMode: widget.isRedNightMode,
                    onResetFilters: () {
                      _resetFiltersOnly();
                    },
                    onCleanAllData: () {
                      _showCleanDataDialog();
                    },
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: isWide ? 10 : 8, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.isRedNightMode
                      ? AstroColors.nightVisionRed.withValues(alpha: 0.18)
                      : AstroColors.starlightCyan.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
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
                  children: [
                    Icon(
                      Icons.settings_suggest_rounded,
                      size: 15,
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
          const SizedBox(width: 10),
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
                    Icons.calendar_month_rounded,
                    color: _selectedTabIndex == 1
                        ? accentColor
                        : (widget.isRedNightMode ? AstroColors.nightVisionRedDim : Colors.white.withValues(alpha: 0.7)),
                  ),
                  selectedIcon: Icon(Icons.calendar_month_rounded, color: accentColor),
                  label: Text(l10n?.tabPlanner ?? "Planner"),
                ),
                NavigationRailDestination(
                  icon: Icon(
                    Icons.playlist_play_rounded,
                    color: _selectedTabIndex == 2
                        ? accentColor
                        : (widget.isRedNightMode ? AstroColors.nightVisionRedDim : Colors.white.withValues(alpha: 0.7)),
                  ),
                  selectedIcon: Icon(Icons.playlist_play_rounded, color: accentColor),
                  label: Text(l10n?.tabObservingLists ?? "Observing Lists"),
                ),
                NavigationRailDestination(
                  icon: Icon(
                    Icons.favorite_rounded,
                    color: _selectedTabIndex == 3
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
                      AstroBridge.instance.addTargetToList(listId, dsoId, notes);
                      _refreshObservingLists();
                      _saveSettings();
                    },
                  )
                : _selectedTabIndex == 1
                    ? PlannerView(
                        filters: _filters,
                        night: _nightSummary!,
                        isRedNightMode: widget.isRedNightMode,
                        availableLists: _observingLists,
                        onAddToList: (listId, dsoId, notes) {
                          AstroBridge.instance.addTargetToList(listId, dsoId, notes ?? '');
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
                    : _selectedTabIndex == 2
                        ? ObservingListsView(
                        lists: _observingLists,
                        isRedNightMode: widget.isRedNightMode,
                        onCreateList: (name, desc, date) {
                          AstroBridge.instance.createObservingList(name, desc, date);
                          _refreshObservingLists();
                          _saveSettings();
                        },
                        onDeleteList: (listId) {
                          AstroBridge.instance.deleteObservingList(listId);
                          _refreshObservingLists();
                          _saveSettings();
                        },
                        onRemoveItem: (listId, dsoId) {
                          AstroBridge.instance.removeTargetFromList(listId, dsoId);
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
                          AstroBridge.instance.addTargetToList(listId, dsoId, notes);
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
