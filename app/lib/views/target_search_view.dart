import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.filters.searchQuery;
  }

  List<TargetItem> get _sortedTargets {
    final list = List<TargetItem>.from(widget.targets);
    switch (_sortMode) {
      case SortMode.peakAltitude:
        list.sort((a, b) => b.peakAltitudeDeg.compareTo(a.peakAltitudeDeg));
        break;
      case SortMode.visibleDuration:
        list.sort((a, b) => b.visibleDurationHours.compareTo(a.visibleDurationHours));
        break;
      case SortMode.brightness:
        list.sort((a, b) => (a.magnitude ?? 99).compareTo(b.magnitude ?? 99));
        break;
      case SortMode.transitTime:
        list.sort((a, b) => a.transitTime.compareTo(b.transitTime));
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
    final displayTargets = _sortedTargets;

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
              Row(
                children: [
                  // Search Input
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "Search DSO by name, Messier, NGC, or common name...",
                        prefixIcon: Icon(Icons.search_rounded, size: 20, color: accentColor),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  widget.onFilterChanged(widget.filters.copyWith(searchQuery: ''));
                                },
                              )
                            : null,
                      ),
                      onSubmitted: (query) {
                        widget.onFilterChanged(widget.filters.copyWith(searchQuery: query.trim()));
                      },
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Filter Button with count badge
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text("Filters"),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      backgroundColor: widget.isRedNightMode
                          ? AstroColors.nightVisionSurfaceVariant
                          : AstroColors.spaceDarkSurfaceVariant,
                      foregroundColor: accentColor,
                    ),
                    onPressed: _openFilterDialog,
                  ),
                  const SizedBox(width: 10),

                  // Sort dropdown
                  DropdownButton<SortMode>(
                    value: _sortMode,
                    dropdownColor: widget.isRedNightMode
                        ? AstroColors.nightVisionSurfaceVariant
                        : AstroColors.spaceDarkSurfaceVariant,
                    icon: Icon(Icons.sort_rounded, color: accentColor),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: SortMode.peakAltitude, child: Text("Peak Altitude")),
                      DropdownMenuItem(value: SortMode.visibleDuration, child: Text("Visible Duration")),
                      DropdownMenuItem(value: SortMode.brightness, child: Text("Brightness (Mag)")),
                      DropdownMenuItem(value: SortMode.transitTime, child: Text("Transit Time")),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _sortMode = v);
                    },
                  ),
                ],
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
                      ? Row(
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
                              ),
                            ),
                          ],
                        )
                      : _buildTargetList(displayTargets),
        ),
      ],
    );
  }

  Widget _buildTargetList(List<TargetItem> targets) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: targets.length,
      itemBuilder: (context, index) {
        final target = targets[index];
        final isSelected = _selectedTarget?.id == target.id;
        return _buildTargetCard(target, isSelected);
      },
    );
  }

  Widget _buildTargetCard(TargetItem target, bool isSelected) {
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;

    return Card(
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
        onTap: () {
          setState(() => _selectedTarget = target);
          if (MediaQuery.of(context).size.width < 900) {
            // Show bottom sheet on mobile screens
            showModalBottomSheet(
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
                ),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              // Target Info
              Expanded(
                flex: 4,
                child: Column(
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
                    Row(
                      children: [
                        _buildSmallChip(target.catalog, AstroColors.nebulaIndigo),
                        const SizedBox(width: 4),
                        _buildSmallChip(target.objectType, AstroColors.starlightCyan),
                        const SizedBox(width: 4),
                        Text(
                          target.constellation,
                          style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

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
                          "Peak: ${target.peakAltitudeDeg.toStringAsFixed(0)}°",
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AstroColors.visibleGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "${target.visibleDurationHours.toStringAsFixed(1)}h above ${widget.filters.minAltitude.round()}°",
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AstroColors.visibleGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Moon: ${target.minMoonSepDeg.toStringAsFixed(0)}°",
                      style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 18, color: textColor.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
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
