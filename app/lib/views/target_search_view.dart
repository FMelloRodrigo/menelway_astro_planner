import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/filter_state.dart';
import '../models/night_summary.dart';
import '../models/observing_list.dart';
import '../models/target_item.dart';
import '../theme/astro_theme.dart';
import 'filter_dialog.dart';
import 'target_details_sheet.dart';

enum SortMode {
  peakAltitude,
  visibleDuration,
  brightness,
  transitTime,
}

class TargetSearchView extends StatefulWidget {
  final List<TargetItem> targets;
  final NightSummary night;
  final FilterState filters;
  final bool isLoading;
  final bool isRedNightMode;
  final List<ObservingListModel> availableLists;
  final void Function(FilterState updated) onFilterChanged;
  final void Function(int listId, int dsoId, String notes) onAddToList;

  const TargetSearchView({
    super.key,
    required this.targets,
    required this.night,
    required this.filters,
    required this.isLoading,
    this.isRedNightMode = false,
    required this.availableLists,
    required this.onFilterChanged,
    required this.onAddToList,
  });

  @override
  State<TargetSearchView> createState() => _TargetSearchViewState();
}

class _TargetSearchViewState extends State<TargetSearchView> {
  SortMode _sortMode = SortMode.peakAltitude;
  final TextEditingController _searchController = TextEditingController();
  TargetItem? _selectedTarget;
  Timer? _debounceTimer;
  bool _hideOutsideFilters = false;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.filters.searchQuery;
    if (widget.filters.searchQuery.isNotEmpty && widget.targets.isNotEmpty) {
      _selectedTarget = widget.targets.first;
    }
  }

  @override
  void didUpdateWidget(TargetSearchView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filters.searchQuery != oldWidget.filters.searchQuery) {
      if (_searchController.text != widget.filters.searchQuery) {
        _searchController.text = widget.filters.searchQuery;
      }
    }
    // When a search query is active and targets are available:
    // Auto-select the first target so the split view Target Details Sheet with the
    // Yearly Observing Window card appears immediately without extra clicks.
    if (widget.filters.searchQuery.isNotEmpty && widget.targets.isNotEmpty) {
      final exists = _selectedTarget != null && widget.targets.any((t) => t.id == _selectedTarget!.id);
      if (!exists) {
        _selectedTarget = widget.targets.first;
      }
    } else if (widget.filters.searchQuery.isEmpty && oldWidget.filters.searchQuery.isNotEmpty) {
      _selectedTarget = null;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      widget.onFilterChanged(widget.filters.copyWith(searchQuery: query.trim()));
    });
  }

  List<TargetItem> get _sortedTargets {
    final list = List<TargetItem>.from(widget.targets);
    switch (_sortMode) {
      case SortMode.peakAltitude:
        list.sort((a, b) {
          if (a.meetsCriteria != b.meetsCriteria) {
            return a.meetsCriteria ? -1 : 1;
          }
          return b.peakAltitudeDeg.compareTo(a.peakAltitudeDeg);
        });
        break;
      case SortMode.visibleDuration:
        list.sort((a, b) {
          if (a.meetsCriteria != b.meetsCriteria) {
            return a.meetsCriteria ? -1 : 1;
          }
          return b.visibleDurationHours.compareTo(a.visibleDurationHours);
        });
        break;
      case SortMode.brightness:
        list.sort((a, b) {
          if (a.meetsCriteria != b.meetsCriteria) {
            return a.meetsCriteria ? -1 : 1;
          }
          return (a.magnitude ?? 99).compareTo(b.magnitude ?? 99);
        });
        break;
      case SortMode.transitTime:
        list.sort((a, b) {
          if (a.meetsCriteria != b.meetsCriteria) {
            return a.meetsCriteria ? -1 : 1;
          }
          return a.transitTime.compareTo(b.transitTime);
        });
        break;
    }
    return list;
  }

  void _openFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => FilterDialog(
        initialFilters: widget.filters,
        night: widget.night,
        isRedNightMode: widget.isRedNightMode,
        onApply: (updated) {
          widget.onFilterChanged(updated);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;

    final isWideScreen = MediaQuery.of(context).size.width >= 900;
    final allSorted = _sortedTargets;
    final displayTargets = _hideOutsideFilters && widget.filters.searchQuery.isNotEmpty
        ? allSorted.where((t) => t.meetsCriteria).toList()
        : allSorted;

    return Column(
      children: [
        // Top Toolbar: Search bar, active filter chips, sort dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface,
            border: Border(
              bottom: BorderSide(
                color: widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder,
              ),
            ),
          ),
          child: Column(
            children: [
              LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;

              final searchField = TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: isNarrow
                      ? "Search DSO (e.g. M42, NGC 7000, Arp 220)..."
                      : "Search DSO (e.g. M42, Orion, NGC 7000, C14, Arp 220)...",
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: accentColor),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              tooltip: "Clear search",
                              onPressed: () {
                                _debounceTimer?.cancel();
                                _searchController.clear();
                                setState(() {});
                                widget.onFilterChanged(widget.filters.copyWith(searchQuery: ''));
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.arrow_forward_rounded, size: 18, color: accentColor),
                              tooltip: "Search target",
                              onPressed: () {
                                _debounceTimer?.cancel();
                                widget.onFilterChanged(
                                  widget.filters.copyWith(searchQuery: _searchController.text.trim()),
                                );
                              },
                            ),
                          ],
                        )
                      : null,
                ),
                onChanged: (text) {
                  setState(() {});
                  _onSearchChanged(text);
                },
                onSubmitted: (query) {
                  _debounceTimer?.cancel();
                  widget.onFilterChanged(widget.filters.copyWith(searchQuery: query.trim()));
                },
              );

              final filterButton = FilledButton.tonalIcon(
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text("Filters"),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  backgroundColor: widget.isRedNightMode
                      ? AstroColors.nightVisionSurfaceVariant
                      : AstroColors.spaceDarkSurfaceVariant,
                  foregroundColor: accentColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: widget.isRedNightMode
                          ? AstroColors.nightVisionBorder
                          : AstroColors.spaceDarkBorder,
                    ),
                  ),
                ),
                onPressed: _openFilterDialog,
              );

              final sortDropdown = Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
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
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<SortMode>(
                    value: _sortMode,
                    isExpanded: isNarrow,
                    dropdownColor: widget.isRedNightMode
                        ? AstroColors.nightVisionSurfaceVariant
                        : AstroColors.spaceDarkSurfaceVariant,
                    icon: Icon(Icons.sort_rounded, color: accentColor, size: 18),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: SortMode.peakAltitude,
                        child: Text("Peak Altitude", overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: SortMode.visibleDuration,
                        child: Text("Visible Duration", overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: SortMode.brightness,
                        child: Text("Brightness (Mag)", overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: SortMode.transitTime,
                        child: Text("Transit Time", overflow: TextOverflow.ellipsis),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _sortMode = v);
                    },
                  ),
                ),
              );

              return Column(
                children: [
                  if (isNarrow) ...[
                    // Mobile: Full-width search bar
                    searchField,
                    const SizedBox(height: 8),
                    // Mobile: Second row for Filters & Sort side-by-side
                    Row(
                      children: [
                        Expanded(child: filterButton),
                        const SizedBox(width: 8),
                        Expanded(child: sortDropdown),
                      ],
                    ),
                  ] else ...[
                    // Desktop: Unified single-row toolbar
                    Row(
                      children: [
                        Expanded(child: searchField),
                        const SizedBox(width: 10),
                        filterButton,
                        const SizedBox(width: 10),
                        sortDropdown,
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 8),

              // Filter summary chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildSummaryChip("Alt ≥ ${widget.filters.minAltitude.round()}°", Icons.terrain_rounded),
                    const SizedBox(width: 6),
                    _buildSummaryChip("Duration ≥ ${widget.filters.minDurationHours.toStringAsFixed(1)}h", Icons.timer_rounded),
                    const SizedBox(width: 6),
                    if (widget.filters.useCustomTimeWindow) ...[
                      _buildSummaryChip(
                        "Window: ${widget.filters.formattedWindow} (${widget.filters.windowDurationHours.toStringAsFixed(1)}h)",
                        Icons.schedule_rounded,
                      ),
                      const SizedBox(width: 6),
                    ] else ...[
                      _buildSummaryChip("Window: Darkness (Full Night)", Icons.nights_stay_rounded),
                      const SizedBox(width: 6),
                    ],
                    _buildSummaryChip("Moon ≥ ${widget.filters.minMoonSeparation.round()}°", Icons.brightness_2_rounded),
                    const SizedBox(width: 6),
                    _buildSummaryChip("Catalogs: ${widget.filters.selectedCatalogs.join(', ')}", Icons.auto_stories_rounded),
                    const SizedBox(width: 6),
                    _buildSummaryChip("${displayTargets.length} targets found", Icons.radar_rounded),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Main Content Area
        Expanded(
          child: widget.isLoading
              ? const Center(child: CircularProgressIndicator())
              : displayTargets.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome_rounded, size: 48, color: textColor.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text(
                            "No targets match the current filter criteria",
                            style: TextStyle(fontSize: 16, color: textColor.withValues(alpha: 0.6)),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _openFilterDialog,
                            child: const Text("Adjust Filter Settings"),
                          ),
                        ],
                      ),
                    )
                  : isWideScreen && _selectedTarget != null
                      // Desktop Split View (Master / Detail)
                      ? CallbackShortcuts(
                          bindings: {
                            const SingleActivator(LogicalKeyboardKey.escape): () {
                              setState(() => _selectedTarget = null);
                            },
                          },
                          child: Focus(
                            autofocus: true,
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: _buildTargetList(displayTargets),
                                ),
                                Container(
                                  width: 1,
                                  color: widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder,
                                ),
                                Expanded(
                                  flex: 6,
                                  child: TargetDetailsSheet(
                                    target: _selectedTarget!,
                                    night: widget.night,
                                    latitude: widget.filters.observerLat,
                                    longitude: widget.filters.observerLon,
                                    elevation: widget.filters.observerElevation,
                                    isRedNightMode: widget.isRedNightMode,
                                    availableLists: widget.availableLists,
                                    onAddToList: widget.onAddToList,
                                    filters: widget.filters,
                                    onClose: () => setState(() => _selectedTarget = null),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _buildTargetList(displayTargets),
        ),
      ],
    );
  }

  Widget _buildTargetList(List<TargetItem> targets) {
    final hasOffSeason = widget.filters.searchQuery.isNotEmpty && widget.targets.any((t) => !t.meetsCriteria);

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: targets.length + (hasOffSeason ? 1 : 0),
      itemBuilder: (context, index) {
        if (hasOffSeason && index == 0) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: Colors.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _hideOutsideFilters
                        ? "Showing only targets matching active filters tonight."
                        : "Search includes targets outside active filters tonight. Click any target to view its yearly window.",
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white70,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _hideOutsideFilters = !_hideOutsideFilters;
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _hideOutsideFilters ? "Show All" : "Hide Non-Matching",
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.amber),
                  ),
                ),
              ],
            ),
          );
        }

        final targetIndex = hasOffSeason ? index - 1 : index;
        final target = targets[targetIndex];
        final isSelected = _selectedTarget?.id == target.id;
        return _buildTargetCard(target, isSelected);
      },
    );
  }

  Widget _buildTargetCard(TargetItem target, bool isSelected) {
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;

    final card = Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected
          ? (widget.isRedNightMode
              ? AstroColors.nightVisionSurfaceVariant
              : AstroColors.spaceDarkSurfaceVariant)
          : (widget.isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected
              ? accentColor
              : (widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () async {
          if (_selectedTarget?.id == target.id) {
            setState(() => _selectedTarget = null);
            return;
          }
          setState(() => _selectedTarget = target);
          if (MediaQuery.of(context).size.width < 900) {
            // Show bottom sheet on mobile screens
            await showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => FractionallySizedBox(
                heightFactor: 0.85,
                child: TargetDetailsSheet(
                  target: target,
                  night: widget.night,
                  latitude: widget.filters.observerLat,
                  longitude: widget.filters.observerLon,
                  elevation: widget.filters.observerElevation,
                  isRedNightMode: widget.isRedNightMode,
                  availableLists: widget.availableLists,
                  onAddToList: widget.onAddToList,
                  filters: widget.filters,
                  onClose: () => Navigator.of(ctx).pop(),
                ),
              ),
            );
            if (mounted) {
              setState(() => _selectedTarget = null);
            }
          }
        },
        child: LayoutBuilder(
          builder: (context, cardConstraints) {
            final isNarrow = cardConstraints.maxWidth < 520;

            final targetHeader = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  target.displayName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (target.messier != null && target.messier!.isNotEmpty)
                      _buildSmallChip(target.messier!, AstroColors.nebulaIndigo)
                    else if (target.caldwell != null && target.caldwell!.isNotEmpty)
                      _buildSmallChip(target.caldwell!, AstroColors.nebulaIndigo)
                    else
                      _buildSmallChip(target.catalog, AstroColors.nebulaIndigo),
                    if (target.arp != null && target.arp!.isNotEmpty)
                      _buildSmallChip(target.arp!, Colors.deepOrangeAccent),
                    if (target.herschel != null && target.herschel!.isNotEmpty)
                      _buildSmallChip(target.herschel!, Colors.amber.shade700),
                    _buildSmallChip(target.objectType, AstroColors.starlightCyan),
                    Text(
                      target.constellation,
                      style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ],
            );

            final selectionIndicator = isSelected
                ? Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: accentColor.withValues(alpha: 0.6), width: 1.2),
                    ),
                    child: Icon(Icons.close_rounded, size: 14, color: accentColor),
                  )
                : Icon(Icons.chevron_right_rounded, size: 18, color: textColor.withValues(alpha: 0.3));

            final durationPill = target.meetsCriteria
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AstroColors.visibleGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isNarrow
                          ? "${target.visibleDurationHours.toStringAsFixed(1)}h visible"
                          : "${target.visibleDurationHours.toStringAsFixed(1)}h above ${widget.filters.minAltitude.round()}°",
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AstroColors.visibleGreen,
                      ),
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      isNarrow ? "Outside Filters" : "Outside Active Filters",
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.amber,
                      ),
                    ),
                  );

            if (isNarrow) {
              // Mobile 2-row layout: Spacious and never cramped
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: targetHeader),
                        const SizedBox(width: 8),
                        selectionIndicator,
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Peak
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.trending_up_rounded, size: 13, color: AstroColors.starGold),
                            const SizedBox(width: 3),
                            Text(
                              target.peakAltitudeDeg > 0
                                  ? "${target.peakAltitudeDeg.toStringAsFixed(0)}°"
                                  : "Below 0°",
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
                            ),
                          ],
                        ),
                        // Transit
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule_rounded, size: 13, color: textColor.withValues(alpha: 0.5)),
                            const SizedBox(width: 3),
                            Text(
                              DateFormat('HH:mm').format(target.transitTime),
                              style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.7)),
                            ),
                          ],
                        ),
                        // Moon
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.brightness_2_rounded, size: 11, color: textColor.withValues(alpha: 0.5)),
                            const SizedBox(width: 3),
                            Text(
                              "${target.minMoonSepDeg.toStringAsFixed(0)}°",
                              style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                        durationPill,
                      ],
                    ),
                  ],
                ),
              );
            }

            // Desktop 3-column layout
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  // Target Info
                  Expanded(flex: 4, child: targetHeader),

                  // Visibility Statistics
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.trending_up_rounded, size: 14, color: AstroColors.starGold),
                            const SizedBox(width: 4),
                            Text(
                              target.peakAltitudeDeg > 0
                                  ? "Peak: ${target.peakAltitudeDeg.toStringAsFixed(0)}°"
                                  : "Below Horizon",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded, size: 14, color: textColor.withValues(alpha: 0.5)),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('HH:mm').format(target.transitTime),
                              style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.7)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Continuous Duration & Moon
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        durationPill,
                        const SizedBox(height: 4),
                        Text(
                          "Moon: ${target.minMoonSepDeg.toStringAsFixed(0)}°",
                          style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  selectionIndicator,
                ],
              ),
            );
          },
        ),
      ),
    );

    if (!target.meetsCriteria) {
      return Opacity(opacity: 0.78, child: card);
    }
    return card;
  }

  Widget _buildSummaryChip(String label, IconData icon) {
    final color = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallChip(String text, Color color) {
    final isRed = widget.isRedNightMode;
    final badgeColor = isRed ? AstroColors.nightVisionRed : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: badgeColor),
      ),
    );
  }
}
