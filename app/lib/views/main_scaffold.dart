import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/astro_bridge.dart';
import '../core/catalog_manager.dart';
import '../core/geocoding_service.dart';
import '../core/settings_service.dart';
import '../models/filter_state.dart';
import '../models/night_summary.dart';
import '../models/observing_list.dart';
import '../models/target_item.dart';
import '../theme/astro_theme.dart';
import 'observing_lists_view.dart';
import 'target_search_view.dart';

class MainScaffold extends StatefulWidget {
  final bool isRedNightMode;
  final VoidCallback onToggleNightMode;
  final VoidCallback? onResetNightMode;
  final AppSettingsData? initialSettings;

  const MainScaffold({
    super.key,
    required this.isRedNightMode,
    required this.onToggleNightMode,
    this.onResetNightMode,
    this.initialSettings,
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

  void _saveSettings() {
    SettingsService.saveSettings(
      filters: _filters,
      isRedNightMode: widget.isRedNightMode,
      observingLists: _observingLists,
    );
  }

  void _handleToggleNightMode() {
    widget.onToggleNightMode();
    Future.microtask(() => _saveSettings());
  }

  void _resetFiltersOnly() {
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
        const SnackBar(
          content: Text("Target filters reset to default (location preserved)."),
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
                "Clear All Saved Data?",
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
              "This will permanently erase your local configuration and reset everything back to factory defaults:",
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
                  _buildCleanItem("• Reset observer location and coordinates to default (New York, USA)", textColor),
                  _buildCleanItem("• Reset all target filters, altitude, and observing time limits", textColor),
                  _buildCleanItem("• Delete all custom observing lists and planned session targets", textColor),
                  _buildCleanItem("• Delete local portable settings file (user_settings.json)", textColor),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "This action cannot be undone.",
              style: TextStyle(
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
            child: Text("Cancel", style: TextStyle(color: textColor.withValues(alpha: 0.7))),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_forever_rounded, size: 16),
            label: const Text("Clear All Data"),
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
    // 1. Clear user settings file
    await SettingsService.clearSettings();

    // 2. Clear SQLite user lists and items
    AstroBridge.instance.clearAllObservingLists();

    // 3. Reset night mode if enabled
    widget.onResetNightMode?.call();

    // 4. Reset in-memory filters
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
        const SnackBar(
          content: Text("All saved data, settings, and observing lists have been cleared."),
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
                  searchError = "No matching cities found for '$q'.";
                }
              });
            } catch (e) {
              setDialogState(() {
                isSearching = false;
                searchError = "Connection error. Check internet connection.";
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
                  "Observer Location",
                  style: TextStyle(
                    color: textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search by City & Country (Open-Meteo)
                    Text(
                      "Search City & Country (Online)",
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
                        hintText: "Type city (e.g. Campinas, London, Atacama, Tokyo)...",
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                          tooltip: "Search online",
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
                                "Lat: ${r.latitude.toStringAsFixed(2)}° | Lon: ${r.longitude.toStringAsFixed(2)}° | Elevation: ${r.elevation.round()}m",
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
                          "Selected Coordinates & Elevation",
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
                            decoration: const InputDecoration(labelText: "Latitude (°)"),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: lonController,
                            decoration: const InputDecoration(labelText: "Longitude (°)"),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: eleController,
                            decoration: const InputDecoration(labelText: "Elevation (m)"),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    // Quick Presets
                    Text(
                      "Popular Astrophotography Sites:",
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
                child: const Text("Cancel"),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
              FilledButton(
                child: const Text("Apply Location"),
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

  @override
  Widget build(BuildContext context) {
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
                "Initializing Astro Targets Engine & Database...",
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
                  "Failed to load astronomical core",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 8),
                Text(_initError!, style: const TextStyle(fontSize: 12, color: Colors.white60)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _bootstrap,
                  child: const Text("Retry"),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "ASTRO TARGETS",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: textColor,
                  ),
                ),
                Text(
                  "Deep-Sky Imaging Planner",
                  style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.5)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Observer Location Pill
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

          // Night summary pill
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
                    "Darkness: ${DateFormat('HH:mm').format(_nightSummary!.astronomicalDusk)} - ${DateFormat('HH:mm').format(_nightSummary!.astronomicalDawn)}",
                    style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.brightness_2_rounded, size: 14, color: AstroColors.starGold),
                  const SizedBox(width: 4),
                  Text(
                    "${(_nightSummary!.moonIllumination * 100).round()}% (${_nightSummary!.moonPhaseName})",
                    style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 8),

          // Database size pill
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

          // Red Night-Vision Mode Toggle
          IconButton(
            tooltip: widget.isRedNightMode ? "Switch to Deep Space Obsidian" : "Switch to Telescope Red Mode",
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

          // Settings & Clean Data Menu Pill
          PopupMenuButton<String>(
            tooltip: "Settings & Data",
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
            onSelected: (value) {
              if (value == 'reset_filters') {
                _resetFiltersOnly();
              } else if (value == 'clean_data') {
                _showCleanDataDialog();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'reset_filters',
                child: Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Reset Target Filters",
                          style: TextStyle(
                            color: textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          "Clear filter limits & keep observer location",
                          style: TextStyle(color: textColor.withValues(alpha: 0.75), fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'clean_data',
                child: Row(
                  children: [
                    const Icon(Icons.delete_forever_rounded, size: 18, color: Colors.redAccent),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Clean All Saved Data...",
                          style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          "Wipe lists, custom location, & local settings",
                          style: TextStyle(
                            color: widget.isRedNightMode
                                ? textColor.withValues(alpha: 0.8)
                                : Colors.redAccent.withValues(alpha: 0.85),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                  children: [
                    Icon(
                      Icons.settings_suggest_rounded,
                      size: 15,
                      color: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Settings & Data",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 17,
                      color: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Row(
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
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.radar_rounded),
                  selectedIcon: Icon(Icons.radar_rounded, color: accentColor),
                  label: const Text("Targets"),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.playlist_play_rounded),
                  selectedIcon: Icon(Icons.playlist_play_rounded, color: accentColor),
                  label: const Text("Observing Lists"),
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
                : ObservingListsView(
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
                  ),
          ),
        ],
      ),
      bottomNavigationBar: !isWide
          ? BottomNavigationBar(
              backgroundColor: widget.isRedNightMode
                  ? AstroColors.nightVisionSurface
                  : AstroColors.spaceDarkSurface,
              selectedItemColor: accentColor,
              unselectedItemColor: textColor.withValues(alpha: 0.5),
              currentIndex: _selectedTabIndex,
              onTap: (idx) => setState(() => _selectedTabIndex = idx),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.radar_rounded),
                  label: "Targets",
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.playlist_play_rounded),
                  label: "Observing Lists",
                ),
              ],
            )
          : null,
    );
  }
}
