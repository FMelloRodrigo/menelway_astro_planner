import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/astro_bridge.dart';
import '../core/catalog_manager.dart';
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

  const MainScaffold({
    super.key,
    required this.isRedNightMode,
    required this.onToggleNightMode,
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
    _filters = FilterState();
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

  void _editLocationDialog() {
    final latController = TextEditingController(text: _filters.observerLat.toString());
    final lonController = TextEditingController(text: _filters.observerLon.toString());
    final eleController = TextEditingController(text: _filters.observerElevation.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isRedNightMode
            ? AstroColors.nightVisionSurface
            : AstroColors.spaceDarkSurface,
        title: Text(
          "Observer Geographical Location",
          style: TextStyle(
            color: widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white,
            fontSize: 16,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latController,
              decoration: const InputDecoration(labelText: "Latitude (Degrees N +, S -)"),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: lonController,
              decoration: const InputDecoration(labelText: "Longitude (Degrees E +, W -)"),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: eleController,
              decoration: const InputDecoration(labelText: "Elevation (Meters)"),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                ActionChip(
                  label: const Text("NYC (40.7°N)", style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    latController.text = "40.7128";
                    lonController.text = "-74.0060";
                    eleController.text = "10";
                  },
                ),
                ActionChip(
                  label: const Text("London (51.5°N)", style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    latController.text = "51.5074";
                    lonController.text = "-0.1278";
                    eleController.text = "25";
                  },
                ),
                ActionChip(
                  label: const Text("Atacama (-23.0°S)", style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    latController.text = "-23.0293";
                    lonController.text = "-67.7547";
                    eleController.text = "2500";
                  },
                ),
                ActionChip(
                  label: const Text("Tokyo (35.7°N)", style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    latController.text = "35.6762";
                    lonController.text = "139.6503";
                    eleController.text = "40";
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          FilledButton(
            child: const Text("Save & Recompute"),
            onPressed: () {
              final newLat = double.tryParse(latController.text) ?? _filters.observerLat;
              final newLon = double.tryParse(lonController.text) ?? _filters.observerLon;
              final newEle = double.tryParse(eleController.text) ?? _filters.observerElevation;

              setState(() {
                _filters.observerLat = newLat;
                _filters.observerLon = newLon;
                _filters.observerElevation = newEle;
                _nightSummary = AstroBridge.instance.getNightSummary(
                  latitude: newLat,
                  longitude: newLon,
                  elevation: newEle,
                  date: _filters.date,
                );
              });
              Navigator.of(ctx).pop();
              _runFiltering();
            },
          ),
        ],
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
                    "${_filters.observerLat >= 0 ? '${_filters.observerLat.toStringAsFixed(1)}°N' : '${(-_filters.observerLat).toStringAsFixed(1)}°S'}, ${_filters.observerLon >= 0 ? '${_filters.observerLon.toStringAsFixed(1)}°E' : '${(-_filters.observerLon).toStringAsFixed(1)}°W'}",
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
          const SizedBox(width: 8),

          // Red Night-Vision Mode Toggle
          IconButton(
            tooltip: widget.isRedNightMode ? "Switch to Deep Space Obsidian" : "Switch to Telescope Red Mode",
            icon: Icon(
              widget.isRedNightMode ? Icons.nightlight_round : Icons.remove_red_eye_rounded,
              color: widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white70,
            ),
            onPressed: widget.onToggleNightMode,
          ),
          const SizedBox(width: 12),
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
                      _runFiltering();
                    },
                    onAddToList: (listId, dsoId, notes) {
                      AstroBridge.instance.addTargetToList(listId, dsoId, notes);
                      _refreshObservingLists();
                    },
                  )
                : ObservingListsView(
                    lists: _observingLists,
                    isRedNightMode: widget.isRedNightMode,
                    onCreateList: (name, desc, date) {
                      AstroBridge.instance.createObservingList(name, desc, date);
                      _refreshObservingLists();
                    },
                    onDeleteList: (listId) {
                      AstroBridge.instance.deleteObservingList(listId);
                      _refreshObservingLists();
                    },
                    onRemoveItem: (listId, dsoId) {
                      AstroBridge.instance.removeTargetFromList(listId, dsoId);
                      _refreshObservingLists();
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
