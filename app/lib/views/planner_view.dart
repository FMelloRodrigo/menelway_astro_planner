import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/astro_bridge.dart';
import '../core/astro_engine.dart';
import '../core/astro_isolate.dart';
import '../core/app_logger.dart';
import '../models/filter_state.dart';
import '../models/night_summary.dart';
import '../models/observing_list.dart';
import '../models/period_target_item.dart';
import '../theme/astro_theme.dart';
import 'filter_dialog.dart';
import 'target_details_sheet.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../widgets/add_target_to_list_dialog.dart';

enum PeriodSortBy {
  days,
  peakDate,
  peakAltitude,
  magnitude,
  size,
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

  int _periodRequestId = 0;

  void _runPeriodQuery() async {
    final requestId = ++_periodRequestId;
    setState(() => _isLoading = true);

    try {
      final engine = _engine;
      final path = engine is AstroBridge ? engine.databasePath : null;
      List<PeriodTargetItem> results;

      if (path != null && !kIsWeb) {
        results = await AstroIsolate.filterTargetsPeriod(
          dbPath: path,
          filters: widget.filters,
          periodStart: _startDate,
          periodEnd: _endDate,
          stepMinutes: 10,
        );
      } else {
        // Test / Web fallback
        results = await Future(() => _engine.filterTargetsPeriod(
          filters: widget.filters,
          periodStart: _startDate,
          periodEnd: _endDate,
          stepMinutes: 10,
        ));
      }

      if (mounted && requestId == _periodRequestId) {
        setState(() {
          _targets = results;
          _isLoading = false;
          // Update selection if it exists or clear if removed
          if (_selectedTarget != null) {
            final matching = _targets.where((t) => t.id == _selectedTarget!.id).firstOrNull;
            _selectedTarget = matching;
          }
        });
      }
    } catch (e) {
      if (mounted && requestId == _periodRequestId) {
        setState(() => _isLoading = false);
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.errorCalculatingPeriodTargets(e.toString()),
            ),
          ),
        );
      }
    }
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
          data: widget.isRedNightMode ? AstroTheme.redNightVisionTheme() : AstroTheme.darkTheme(),
          child: child!,
        );
      },
    );

    if (!mounted) return;
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _runPeriodQuery();
    }
  }

  NightSummary _getNightForPeriodTarget(PeriodTargetItem target) {
    final date = target.peakDate ?? _startDate;
    try {
      return (widget.engine ?? _engine).getNightSummary(
        latitude: widget.filters.observerLat,
        longitude: widget.filters.observerLon,
        elevation: widget.filters.observerElevation,
        date: date,
      );
    } catch (e) {
      AppLogger.error('Failed getting night summary for planner target date: $date', tag: 'PlannerView', error: e);
      return widget.night;
    }
  }

  List<PeriodTargetItem> get _filteredAndSortedTargets {
    var list = List<PeriodTargetItem>.from(_targets);

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      final normQ = q.replaceAll(RegExp(r'[^a-z0-9]'), '');
      String norm(String? s) => s == null ? '' : s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      list = list.where((t) {
        final nameMatch = t.name.toLowerCase().contains(q) || (normQ.isNotEmpty && norm(t.name).contains(normQ));
        final commonMatch = (t.commonName?.toLowerCase().contains(q) ?? false) || (normQ.isNotEmpty && norm(t.commonName).contains(normQ));
        final constMatch = t.constellation.toLowerCase().contains(q);
        final catMatch = t.catalog.toLowerCase().contains(q);
        final mMatch = (t.messier?.toLowerCase().contains(q) ?? false) || (normQ.isNotEmpty && norm(t.messier).contains(normQ));
        final cMatch = (t.caldwell?.toLowerCase().contains(q) ?? false) || (normQ.isNotEmpty && norm(t.caldwell).contains(normQ));
        final aMatch = (t.arp?.toLowerCase().contains(q) ?? false) || (normQ.isNotEmpty && norm(t.arp).contains(normQ));
        final hMatch = (t.herschel?.toLowerCase().contains(q) ?? false) || (normQ.isNotEmpty && norm(t.herschel).contains(normQ));
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
          final cmp = da.compareTo(db);
          if (cmp != 0) return cmp;
          return b.peakAltitudeDeg.compareTo(a.peakAltitudeDeg);
        });
        break;
      case PeriodSortBy.peakAltitude:
        list.sort((a, b) {
          if (a.isObservable != b.isObservable) return a.isObservable ? -1 : 1;
          return b.peakAltitudeDeg.compareTo(a.peakAltitudeDeg);
        });
        break;
      case PeriodSortBy.magnitude:
        list.sort((a, b) {
          if (a.isObservable != b.isObservable) return a.isObservable ? -1 : 1;
          final ma = a.magnitude ?? 999.0;
          final mb = b.magnitude ?? 999.0;
          final cmp = ma.compareTo(mb);
          if (cmp != 0) return cmp;
          return b.peakAltitudeDeg.compareTo(a.peakAltitudeDeg);
        });
        break;
      case PeriodSortBy.size:
        list.sort((a, b) {
          if (a.isObservable != b.isObservable) return a.isObservable ? -1 : 1;
          final sa = a.majorAxisArcmin ?? -1.0;
          final sb = b.majorAxisArcmin ?? -1.0;
          final cmp = sb.compareTo(sa);
          if (cmp != 0) return cmp;
          return b.peakAltitudeDeg.compareTo(a.peakAltitudeDeg);
        });
        break;
    }

    final limit = widget.filters.maxTargets;
    if (limit > 0 && list.length > limit) {
      return list.sublist(0, limit);
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeStr = Localizations.localeOf(context).toString();
    final palette = AstroPalette.of(context);
    final textColor = palette.textPrimary;
    final accentColor = palette.accent;
    final isWide = MediaQuery.of(context).size.width >= 900;

    final displayTargets = _filteredAndSortedTargets;
    final totalDays = _endDate.difference(_startDate).inDays + 1;
    final dateFormat = DateFormat('MMM d, yyyy', localeStr);

    return Column(
      children: [
        // Top Control Header: Date Range Bar & Quick Presets
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border(
              bottom: BorderSide(
                color: palette.border,
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
                  Widget buildTitle(bool isNarrow) {
                    return Row(
                      mainAxisSize: isNarrow ? MainAxisSize.max : MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_month_rounded, size: 20, color: accentColor),
                        const SizedBox(width: 8),
                        isNarrow
                            ? Expanded(
                                child: Text(
                                  (l10n.futureObservationPlanner).toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                    color: textColor.withValues(alpha: 0.7),
                                  ),
                                ),
                              )
                            : Text(
                                (l10n.futureObservationPlanner).toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: textColor.withValues(alpha: 0.7),
                                ),
                              ),
                      ],
                    );
                  }

                  Widget buildRangeButton(bool isNarrow) {
                    return InkWell(
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
                          mainAxisSize: isNarrow ? MainAxisSize.max : MainAxisSize.min,
                          children: [
                            Icon(Icons.date_range_rounded, size: 14, color: accentColor),
                            const SizedBox(width: 6),
                            isNarrow
                                ? Expanded(
                                    child: Text(
                                      "${dateFormat.format(_startDate)} – ${dateFormat.format(_endDate)} ${l10n.daysCountSuffix(totalDays)}",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: textColor,
                                      ),
                                    ),
                                  )
                                : Text(
                                    "${dateFormat.format(_startDate)} – ${dateFormat.format(_endDate)} ${l10n.daysCountSuffix(totalDays)}",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_drop_down_rounded, size: 16, color: accentColor),
                          ],
                        ),
                      ),
                    );
                  }

                  if (isNarrowHeader) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildTitle(true),
                        const SizedBox(height: 8),
                        buildRangeButton(true),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      buildTitle(false),
                      const Spacer(),
                      buildRangeButton(false),
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
                    _buildPresetChip(l10n.presetNext7Days, _setPresetNext7Days),
                    const SizedBox(width: 6),
                    _buildPresetChip(l10n.presetThisWeekend, _setPresetThisWeekend),
                    const SizedBox(width: 6),
                    _buildPresetChip(l10n.presetNextMonth, _setPresetNextMonth),
                    const SizedBox(width: 6),
                    _buildPresetChip(l10n.presetNext30Days, _setPresetNext30Days),
                    const SizedBox(width: 6),
                    _buildPresetChip(l10n.presetCustomPeriod, _pickCustomRange, isSpecial: true),
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
                                ? (l10n.plannerWindowCustom(
                                      "${widget.filters.customStartHour.toString().padLeft(2, '0')}:${widget.filters.customStartMinute.toString().padLeft(2, '0')}",
                                      "${widget.filters.customEndHour.toString().padLeft(2, '0')}:${widget.filters.customEndMinute.toString().padLeft(2, '0')}",
                                    ))
                                : (l10n.plannerWindowFullNight),
                            Icons.access_time_rounded,
                          ),
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            l10n.plannerDirectionLabel(_quadrantName(widget.filters.quadrant, l10n)),
                            Icons.explore_rounded,
                          ),
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            l10n.plannerAltMinLabel(widget.filters.minAltitude.round().toString()),
                            Icons.north_east_rounded,
                          ),
                          const SizedBox(width: 6),
                          _buildFilterChip(
                            l10n.plannerDurationMinLabel(widget.filters.minDurationHours.toStringAsFixed(1)),
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
                            l10n.filtersButton,
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
            color: palette.surface,
            border: Border(
              bottom: BorderSide(
                color: palette.border,
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
                    hintText: isNarrowSearch
                        ? (l10n.searchPeriodTargetsHintShort)
                        : (l10n.searchPeriodTargetsHint),
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
                    dropdownColor: palette.surface,
                    icon: Icon(Icons.sort_rounded, size: 16, color: accentColor),
                    onChanged: (newSort) {
                      if (newSort != null) setState(() => _sortBy = newSort);
                    },
                    items: [
                      DropdownMenuItem(
                        value: PeriodSortBy.days,
                        child: Text(l10n.sortMostObservableDays, style: const TextStyle(fontSize: 12)),
                      ),
                      DropdownMenuItem(
                        value: PeriodSortBy.peakDate,
                        child: Text(l10n.sortPeakDate, style: const TextStyle(fontSize: 12)),
                      ),
                      DropdownMenuItem(
                        value: PeriodSortBy.peakAltitude,
                        child: Text(l10n.sortHighestAltitude, style: const TextStyle(fontSize: 12)),
                      ),
                      DropdownMenuItem(
                        value: PeriodSortBy.magnitude,
                        child: Text(l10n.sortBrightestFirst, style: const TextStyle(fontSize: 12)),
                      ),
                      DropdownMenuItem(
                        value: PeriodSortBy.size,
                        child: Text(l10n.sortLargestFirst, style: const TextStyle(fontSize: 12)),
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
                        l10n.simulatingSkyPeriod(totalDays),
                        style: TextStyle(color: textColor.withValues(alpha: 0.6)),
                      ),
                    ],
                  ),
                )
              : displayTargets.isEmpty
                  ? _buildEmptyState(textColor, accentColor, l10n)
                  : isWide && _selectedTarget != null
                      ? Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: _buildTargetList(displayTargets),
                            ),
                            Container(
                              width: 1,
                              color: palette.border,
                            ),
                            Expanded(
                              flex: 6,
                              child: TargetDetailsSheet(
                                target: _selectedTarget!.toTargetItem(date: _selectedTarget!.peakDate ?? _startDate),
                                night: _getNightForPeriodTarget(_selectedTarget!),
                                latitude: widget.filters.observerLat,
                                longitude: widget.filters.observerLon,
                                elevation: widget.filters.observerElevation,
                                isRedNightMode: widget.isRedNightMode,
                                availableLists: widget.availableLists,
                                onAddToList: widget.onAddToList,
                                filters: widget.filters,
                                engine: widget.engine,
                                periodTarget: _selectedTarget,
                                plannedStartDate: _startDate,
                                plannedEndDate: _endDate,
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

  Widget _buildEmptyState(Color textColor, Color accentColor, AppLocalizations l10n) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_alt_off_rounded, size: 48, color: textColor.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              l10n.noTargetsMatchPeriod,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.noTargetsPeriodSubtitle(
                    widget.filters.minAltitude.round().toString(),
                    _quadrantName(widget.filters.quadrant, l10n),
                  ),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.6), height: 1.4),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openFilterDialog,
              icon: const Icon(Icons.tune_rounded, size: 14),
              label: Text(l10n.adjustFiltersBtn),
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
    final palette = AstroPalette.of(context);
    final textColor = palette.textPrimary;
    final accentColor = palette.accent;
    final isObservable = target.isObservable && target.observableDaysCount > 0;

    final cardBg = isSelected
        ? accentColor.withValues(alpha: 0.12)
        : palette.surface;

    final borderColor = isSelected
        ? accentColor
        : palette.border;

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
            TargetDetailsSheet.show(
              context,
              target: target.toTargetItem(date: target.peakDate ?? _startDate),
              night: _getNightForPeriodTarget(target),
              latitude: widget.filters.observerLat,
              longitude: widget.filters.observerLon,
              elevation: widget.filters.observerElevation,
              isRedNightMode: widget.isRedNightMode,
              availableLists: widget.availableLists,
              onAddToList: widget.onAddToList,
              filters: widget.filters,
              engine: widget.engine,
              periodTarget: target,
              plannedStartDate: _startDate,
              plannedEndDate: _endDate,
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
                          "${l10n.targetInConstellation(localizeObjectType(target.objectType, l10n), target.constellation)}${target.magnitude != null ? ' • ${l10n.magnitudeLabel} ${target.magnitude!.toStringAsFixed(1)}' : ''}${target.majorAxisArcmin != null && target.majorAxisArcmin! > 0 ? ' • ${target.majorAxisArcmin! >= 60.0 ? '${(target.majorAxisArcmin! / 60.0).toStringAsFixed(1)}°' : '${target.majorAxisArcmin!.toStringAsFixed(1)}\''}' : ''}",
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
                    tooltip: l10n.addToObservingList,
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
                      ? palette.visibleGreen.withValues(alpha: 0.12)
                      : Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isObservable
                        ? palette.visibleGreen.withValues(alpha: 0.35)
                        : Colors.orange.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isObservable ? Icons.check_circle_outline_rounded : Icons.filter_alt_off_rounded,
                      size: 15,
                      color: isObservable ? palette.visibleGreen : Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 2,
                            children: [
                              Text(
                                isObservable
                                    ? (l10n.periodDaysObservableShort(target.observableDaysCount, target.totalPeriodDays))
                                    : (l10n.outsideFiltersInPeriod),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isObservable ? palette.visibleGreen : Colors.orange,
                                ),
                              ),
                              if (target.peakDate != null && isObservable)
                                Text(
                                  l10n.periodPeakDate(DateFormat('MMM d', Localizations.localeOf(context).toString()).format(target.peakDate!)),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: textColor.withValues(alpha: 0.8),
                                  ),
                                ),
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
                                  isObservable ? palette.visibleGreen : Colors.orange,
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
                        ? (l10n.periodPeakAltAndMaxHours(target.peakAltitudeDeg.toStringAsFixed(1), target.maxHoursObservable.toStringAsFixed(1)))
                        : (l10n.periodNeverClearsAlt(widget.filters.minAltitude.round().toString())),
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: textColor.withValues(alpha: 0.55),
                    ),
                  ),
                  if (target.startMonth > 0 && target.endMonth > 0 && target.isObservable)
                    Text(
                      localizePeriodObservabilitySummary(target, l10n),
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
    AddTargetToListDialog.show(
      context: context,
      targetId: target.id,
      targetDisplayName: target.displayName,
      availableLists: widget.availableLists,
      onAddToList: (listId, dsoId, notes) {
        widget.onAddToList(listId, dsoId, notes);
      },
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap, {bool isSpecial = false}) {
    final palette = AstroPalette.of(context);
    final textColor = palette.textPrimary;
    final accentColor = palette.accent;

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
    final palette = AstroPalette.of(context);
    final accentColor = palette.accent;
    final textColor = palette.textPrimary;

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

  String _quadrantName(int q, AppLocalizations l10n) {
    final opts = getQuadrantOptions(l10n);
    if (q >= 0 && q < opts.length) {
      return opts[q];
    }
    return opts.first;
  }
}
