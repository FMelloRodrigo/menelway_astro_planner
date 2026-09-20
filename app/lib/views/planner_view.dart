import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/astro_engine.dart';
import '../models/filter_state.dart';
import '../models/night_summary.dart';
import '../models/observing_list.dart';
import '../models/period_target_item.dart';
import '../theme/astro_theme.dart';
import 'filter_dialog.dart';
import 'target_details_sheet.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';

enum PeriodSortBy {
  days,
  peakDate,
  peakAltitude,
  magnitude,
}

class PlannerView extends StatefulWidget {
  final FilterState filters;
  final NightSummary night;
  final bool isRedNightMode;
  final List<ObservingListModel> availableLists;
  final void Function(int listId, int dsoId, String? notes) onAddToList;
  final void Function(FilterState newFilters) onFilterChanged;
  final AstroEngine? engine;

  const PlannerView({
    super.key,
    required this.filters,
    required this.night,
    required this.isRedNightMode,
    required this.availableLists,
    required this.onAddToList,
    required this.onFilterChanged,
    this.engine,
  });

  @override
  State<PlannerView> createState() => _PlannerViewState();
}

class _PlannerViewState extends State<PlannerView> {
  AstroEngine get _engine => widget.engine ?? AstroEngine.instance;

  late DateTime _startDate;
  late DateTime _endDate;
  List<PeriodTargetItem> _targets = [];
  bool _isLoading = false;
  String _searchQuery = '';
  PeriodSortBy _sortBy = PeriodSortBy.days;
  PeriodTargetItem? _selectedTarget;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = _startDate.add(const Duration(days: 14));
    _runPeriodQuery();
  }

  @override
  void didUpdateWidget(covariant PlannerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filters != widget.filters) {
      _runPeriodQuery();
    }
  }

  void _openFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => FilterDialog(
        initialFilters: widget.filters,
        isRedNightMode: widget.isRedNightMode,
        onApply: (updated) {
          widget.onFilterChanged(updated);
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _runPeriodQuery() {
    setState(() => _isLoading = true);

    Future.microtask(() {
      try {
        final results = _engine.filterTargetsPeriod(
          filters: widget.filters,
          periodStart: _startDate,
          periodEnd: _endDate,
          stepMinutes: 10,
        );

        if (mounted) {
          setState(() {
            _targets = results;
            _isLoading = false;
            // Clear selection if it no longer exists
            if (_selectedTarget != null && !_targets.any((t) => t.id == _selectedTarget!.id)) {
              _selectedTarget = null;
            }
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error calculating period targets: $e")),
          );
        }
      }
    });
  }

  // Preset Handlers
  void _setPresetNext7Days() {
    final now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, now.month, now.day);
      _endDate = _startDate.add(const Duration(days: 7));
    });
    _runPeriodQuery();
  }

  void _setPresetThisWeekend() {
    final now = DateTime.now();
    // Friday of current week (weekday 5)
    final daysUntilFriday = (DateTime.friday - now.weekday) % 7;
    final friday = DateTime(now.year, now.month, now.day).add(Duration(days: daysUntilFriday));
    final sunday = friday.add(const Duration(days: 2));
    setState(() {
      _startDate = friday;
      _endDate = sunday;
    });
    _runPeriodQuery();
  }

  void _setPresetNextMonth() {
    final now = DateTime.now();
    final nextMonthFirst = DateTime(now.year, now.month + 1, 1);
    final nextMonthLast = DateTime(now.year, now.month + 2, 0);
    setState(() {
      _startDate = nextMonthFirst;
      _endDate = nextMonthLast;
    });
    _runPeriodQuery();
  }

  void _setPresetNext30Days() {
    final now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, now.month, now.day);
      _endDate = _startDate.add(const Duration(days: 30));
    });
    _runPeriodQuery();
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: widget.isRedNightMode ? ThemeData.dark() : ThemeData.dark(),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _runPeriodQuery();
    }
  }

  List<PeriodTargetItem> get _filteredAndSortedTargets {
    var list = _targets;

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((t) {
        final nameMatch = t.name.toLowerCase().contains(q);
        final commonMatch = t.commonName?.toLowerCase().contains(q) ?? false;
        final constMatch = t.constellation.toLowerCase().contains(q);
        final catMatch = t.catalog.toLowerCase().contains(q);
        final mMatch = t.messier?.toLowerCase().contains(q) ?? false;
        final cMatch = t.caldwell?.toLowerCase().contains(q) ?? false;
        final aMatch = t.arp?.toLowerCase().contains(q) ?? false;
        final hMatch = t.herschel?.toLowerCase().contains(q) ?? false;
        return nameMatch || commonMatch || constMatch || catMatch || mMatch || cMatch || aMatch || hMatch;
      }).toList();
    }

    switch (_sortBy) {
      case PeriodSortBy.days:
        list.sort((a, b) {
          if (a.isObservable != b.isObservable) return a.isObservable ? -1 : 1;
          if (a.observableDaysCount != b.observableDaysCount) {
            return b.observableDaysCount.compareTo(a.observableDaysCount);
          }
          return b.peakAltitudeDeg.compareTo(a.peakAltitudeDeg);
        });
        break;
      case PeriodSortBy.peakDate:
        list.sort((a, b) {
          if (a.isObservable != b.isObservable) return a.isObservable ? -1 : 1;
          final da = a.peakDate ?? DateTime(2099);
          final db = b.peakDate ?? DateTime(2099);
          return da.compareTo(db);
        });
        break;
      case PeriodSortBy.peakAltitude:
        list.sort((a, b) => b.peakAltitudeDeg.compareTo(a.peakAltitudeDeg));
        break;
      case PeriodSortBy.magnitude:
        list.sort((a, b) {
          final ma = a.magnitude ?? 999.0;
          final mb = b.magnitude ?? 999.0;
          return ma.compareTo(mb);
        });
        break;
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;
    final isWide = MediaQuery.of(context).size.width >= 900;

    final displayTargets = _filteredAndSortedTargets;
    final totalDays = _endDate.difference(_startDate).inDays + 1;
    final dateFormat = DateFormat('MMM d, yyyy');

    return Column(
      children: [
        // Top Control Header: Date Range Bar & Quick Presets
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          decoration: BoxDecoration(
            color: widget.isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface,
            border: Border(
              bottom: BorderSide(
                color: widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title & Period Selector
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrowHeader = constraints.maxWidth < 600;
                  final titleWidget = Row(
                    children: [
                      Icon(Icons.calendar_month_rounded, size: 20, color: accentColor),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          "FUTURE OBSERVATION PLANNER",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: textColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  );

                  final rangeButton = InkWell(
                    onTap: _pickCustomRange,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.date_range_rounded, size: 14, color: accentColor),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              "${dateFormat.format(_startDate)} – ${dateFormat.format(_endDate)} ($totalDays d)",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_drop_down_rounded, size: 16, color: accentColor),
                        ],
                      ),
                    ),
                  );

                  if (isNarrowHeader) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleWidget,
                        const SizedBox(height: 8),
                        rangeButton,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      titleWidget,
                      const Spacer(),
                      rangeButton,
                    ],
                  );
                },
              ),

              const SizedBox(height: 10),

              // Presets Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildPresetChip("Next 7 Days", _setPresetNext7Days),
                    const SizedBox(width: 6),
                    _buildPresetChip("This Weekend", _setPresetThisWeekend),
                    const SizedBox(width: 6),
                    _buildPresetChip("Next Month", _setPresetNextMonth),
                    const SizedBox(width: 6),
                    _buildPresetChip("Next 30 Days", _setPresetNext30Days),
                    const SizedBox(width: 6),
                    _buildPresetChip("Custom Period...", _pickCustomRange, isSpecial: true),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Filters & Active Limits Strip
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                            widget.filters.useCustomTimeWindow
                                ? "Window: ${widget.filters.customStartHour.toString().padLeft(2, '0')}:${widget.filters.customStartMinute.toString().padLeft(2, '0')} – ${widget.filters.customEndHour.toString().padLeft(2, '0')}:${widget.filters.customEndMinute.toString().padLeft(2, '0')}"
                                : "Window: Full Night",
                            Icons.access_time_rounded,
                          ),
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            "Direction: ${_quadrantName(widget.filters.quadrant)}",
                            Icons.explore_rounded,
                          ),
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            "Alt ≥ ${widget.filters.minAltitude.round()}°",
                            Icons.north_east_rounded,
                          ),
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            "Duration ≥ ${widget.filters.minDurationHours.toStringAsFixed(1)}h",
                            Icons.timer_rounded,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _openFilterDialog,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune_rounded, size: 12, color: accentColor),
                          const SizedBox(width: 4),
                          Text(
                            "Filters",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Search Bar & Sort Dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface,
            border: Border(
              bottom: BorderSide(
                color: widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder,
              ),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrowSearch = constraints.maxWidth < 600;
              const double topBarElementHeight = 40.0;
              final searchField = SizedBox(
                height: topBarElementHeight,
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: TextStyle(fontSize: 13, color: textColor),
                  textAlignVertical: TextAlignVertical.center,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: isNarrowSearch ? "Search period targets..." : "Search period targets (e.g. M42, Rosette, Nebula)...",
                    hintStyle: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.4)),
                    prefixIcon: Icon(Icons.search_rounded, size: 16, color: accentColor),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: accentColor),
                    ),
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.2),
                  ),
                ),
              );

              final sortDropdown = Container(
                height: topBarElementHeight,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<PeriodSortBy>(
                    value: _sortBy,
                    isDense: true,
                    isExpanded: isNarrowSearch,
                    dropdownColor: widget.isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface,
                    icon: Icon(Icons.sort_rounded, size: 16, color: accentColor),
                    onChanged: (newSort) {
                      if (newSort != null) setState(() => _sortBy = newSort);
                    },
                    items: const [
                      DropdownMenuItem(
                        value: PeriodSortBy.days,
                        child: Text("Most Observable Days", style: TextStyle(fontSize: 12)),
                      ),
                      DropdownMenuItem(
                        value: PeriodSortBy.peakDate,
                        child: Text("Peak Date", style: TextStyle(fontSize: 12)),
                      ),
                      DropdownMenuItem(
                        value: PeriodSortBy.peakAltitude,
                        child: Text("Highest Altitude", style: TextStyle(fontSize: 12)),
                      ),
                      DropdownMenuItem(
                        value: PeriodSortBy.magnitude,
                        child: Text("Brightest First", style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              );

              if (isNarrowSearch) {
                return Column(
                  children: [
                    searchField,
                    const SizedBox(height: 8),
                    sortDropdown,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: searchField),
                  const SizedBox(width: 12),
                  sortDropdown,
                ],
              );
            },
          ),
        ),

        // Results Section
        Expanded(
          child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: accentColor),
                      const SizedBox(height: 12),
                      Text(
                        "Simulating sky across $totalDays nights...",
                        style: TextStyle(color: textColor.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                )
              : displayTargets.isEmpty
                  ? _buildEmptyState(textColor, accentColor)
                  : isWide && _selectedTarget != null
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
                                target: _selectedTarget!.toTargetItem(),
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
                        )
                      : _buildTargetList(displayTargets),
        ),
      ],
    );
  }

  Widget _buildEmptyState(Color textColor, Color accentColor) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_off_rounded, size: 48, color: textColor.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              "No Targets Match This Period",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor),
            ),
            const SizedBox(height: 8),
            Text(
              "None of the catalog candidates meet your active limits (Alt ≥ ${widget.filters.minAltitude.round()}°, ${_quadrantName(widget.filters.quadrant)}) during this timeframe.\nTry selecting a broader date range or relaxing direction limits.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.6), height: 1.4),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openFilterDialog,
              icon: const Icon(Icons.tune_rounded, size: 14),
              label: const Text("Adjust Filters"),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor.withValues(alpha: 0.2),
                foregroundColor: accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetList(List<PeriodTargetItem> targets) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      itemCount: targets.length,
      itemBuilder: (context, index) {
        final target = targets[index];
        final isSelected = _selectedTarget?.id == target.id;

        return _buildPeriodTargetCard(target, isSelected);
      },
    );
  }

  Widget _buildPeriodTargetCard(PeriodTargetItem target, bool isSelected) {
    final l10n = AppLocalizations.of(context);
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;
    final isObservable = target.isObservable && target.observableDaysCount > 0;

    final cardBg = isSelected
        ? accentColor.withValues(alpha: 0.12)
        : (widget.isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface);

    final borderColor = isSelected
        ? accentColor
        : (widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder);

    final ratio = target.totalPeriodDays > 0
        ? target.observableDaysCount / target.totalPeriodDays
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isSelected ? 3 : 1,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: borderColor, width: isSelected ? 1.5 : 1.0),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          final isWide = MediaQuery.of(context).size.width >= 900;
          if (isWide) {
            setState(() => _selectedTarget = target);
          } else {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => TargetDetailsSheet(
                target: target.toTargetItem(),
                night: widget.night,
                latitude: widget.filters.observerLat,
                longitude: widget.filters.observerLon,
                elevation: widget.filters.observerElevation,
                isRedNightMode: widget.isRedNightMode,
                availableLists: widget.availableLists,
                onAddToList: widget.onAddToList,
                filters: widget.filters,
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Name, Catalog Badge, Quick Add to List
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
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
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${localizeObjectType(target.objectType, l10n)} in ${target.constellation}${target.magnitude != null ? ' • Mag ${target.magnitude!.toStringAsFixed(1)}' : ''}",
                          style: TextStyle(
                            fontSize: 11,
                            color: textColor.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Add to Observing List action button
                  IconButton(
                    icon: Icon(Icons.playlist_add_rounded, size: 20, color: accentColor),
                    tooltip: l10n?.addToObservingList ?? "Add to Observing List",
                    onPressed: () => _showAddToListDialog(target),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Period Metric Banner / Progress Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isObservable
                      ? AstroColors.visibleGreen.withValues(alpha: 0.12)
                      : Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isObservable
                        ? AstroColors.visibleGreen.withValues(alpha: 0.35)
                        : Colors.orange.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isObservable ? Icons.check_circle_outline_rounded : Icons.filter_alt_off_rounded,
                      size: 15,
                      color: isObservable ? AstroColors.visibleGreen : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  isObservable
                                      ? "${target.observableDaysCount} of ${target.totalPeriodDays} days observable"
                                      : "Outside active filters in this period",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isObservable ? AstroColors.visibleGreen : Colors.orange,
                                  ),
                                ),
                              ),
                              if (target.peakDate != null && isObservable) ...[
                                const SizedBox(width: 6),
                                Text(
                                  "Peak: ${DateFormat('MMM d').format(target.peakDate!)}",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: textColor.withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (isObservable) ...[
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: ratio.clamp(0.0, 1.0),
                                minHeight: 3,
                                backgroundColor: Colors.white.withValues(alpha: 0.1),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isObservable ? AstroColors.visibleGreen : Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // Bottom Stats: Transit altitude, continuous hours, span
              Wrap(
                spacing: 8,
                runSpacing: 2,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Text(
                    target.isObservable
                        ? "Peak Alt: ${target.peakAltitudeDeg.toStringAsFixed(1)}° • Max: ${target.maxHoursObservable.toStringAsFixed(1)}h/night"
                        : "Never clears ${widget.filters.minAltitude.round()}° in active window",
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: textColor.withValues(alpha: 0.55),
                    ),
                  ),
                  if (target.startMonth > 0 && target.endMonth > 0 && target.isObservable)
                    Text(
                      target.periodObservabilitySummary,
                      style: TextStyle(
                        fontSize: 10,
                        color: textColor.withValues(alpha: 0.55),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddToListDialog(PeriodTargetItem target) {
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;

    if (widget.availableLists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("No observing lists exist yet. Create one in the Observing Lists tab first!"),
          action: SnackBarAction(label: "OK", onPressed: () {}),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface,
        title: Text("Add to Observing List", style: TextStyle(color: textColor, fontSize: 16)),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Add ${target.displayName} to:",
                style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.availableLists.length,
                  itemBuilder: (context, idx) {
                    final list = widget.availableLists[idx];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.playlist_play_rounded, color: accentColor),
                      title: Text(list.name, style: TextStyle(color: textColor, fontSize: 13)),
                      subtitle: Text(
                        "${list.items.length} items${list.sessionDate.isNotEmpty ? ' • ${list.sessionDate}' : ''}",
                        style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 11),
                      ),
                      onTap: () {
                        widget.onAddToList(list.id, target.id, null);
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Added ${target.displayName} to '${list.name}'!"),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text("Cancel", style: TextStyle(color: textColor.withValues(alpha: 0.7))),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap, {bool isSpecial = false}) {
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: isSpecial
              ? accentColor.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSpecial ? accentColor.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSpecial ? FontWeight.w700 : FontWeight.w500,
            color: isSpecial ? accentColor : textColor.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String text, IconData icon) {
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: accentColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  String _quadrantName(int q) {
    switch (q) {
      case 1: return "North (0°–90°)";
      case 2: return "East (90°–180°)";
      case 3: return "South (180°–270°)";
      case 4: return "West (270°–360°)";
      case 5: return "North-East (0°–90°)";
      case 6: return "South-East (90°–180°)";
      case 7: return "South-West (180°–270°)";
      case 8: return "North-West (270°–360°)";
      default: return "Full Sky (360°)";
    }
  }
}
