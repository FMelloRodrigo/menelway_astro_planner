import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/astro_engine.dart';
import '../core/app_logger.dart';
import '../core/catalog_manager.dart';
import '../core/favorites_manager.dart';
import '../models/altitude_point.dart';
import '../models/filter_state.dart';
import '../models/night_summary.dart';
import '../models/observing_list.dart';
import '../models/target_item.dart';
import '../models/yearly_visibility.dart';
import '../models/period_target_item.dart';
import '../models/target_description.dart';
import '../theme/astro_theme.dart';
import '../widgets/target_preview_canvas.dart';
import 'altitude_curve_chart.dart';
import 'equipment_dialog.dart';
import 'equipment_framing_dialog.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../core/target_description_service.dart';
import '../core/url_service.dart';
import '../models/terrain_profile_model.dart';
import '../services/terrain_cache_service.dart';
import '../utils/astro_formatters.dart';
import '../widgets/add_target_to_list_dialog.dart';

class TargetDetailsSheet extends StatefulWidget {
  final TargetItem target;
  final NightSummary night;
  final double latitude;
  final double longitude;
  final double elevation;
  final bool isRedNightMode;
  final List<ObservingListModel> availableLists;
  final void Function(int listId, int dsoId, String notes) onAddToList;
  final FilterState? filters;
  final VoidCallback? onClose;
  final AstroEngine? engine;
  final PeriodTargetItem? periodTarget;
  final DateTime? plannedStartDate;
  final DateTime? plannedEndDate;

  const TargetDetailsSheet({
    super.key,
    required this.target,
    required this.night,
    required this.latitude,
    required this.longitude,
    required this.elevation,
    this.isRedNightMode = false,
    required this.availableLists,
    required this.onAddToList,
    this.filters,
    this.onClose,
    this.engine,
    this.periodTarget,
    this.plannedStartDate,
    this.plannedEndDate,
  });

  /// Standard modal bottom sheet launcher for [TargetDetailsSheet].
  static Future<T?> show<T>(
    BuildContext context, {
    required TargetItem target,
    required NightSummary night,
    required double latitude,
    required double longitude,
    required double elevation,
    required List<ObservingListModel> availableLists,
    required void Function(int listId, int dsoId, String notes) onAddToList,
    bool isRedNightMode = false,
    FilterState? filters,
    VoidCallback? onClose,
    AstroEngine? engine,
    PeriodTargetItem? periodTarget,
    DateTime? plannedStartDate,
    DateTime? plannedEndDate,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TargetDetailsSheet(
        target: target,
        night: night,
        latitude: latitude,
        longitude: longitude,
        elevation: elevation,
        isRedNightMode: isRedNightMode,
        availableLists: availableLists,
        onAddToList: onAddToList,
        filters: filters,
        onClose: onClose,
        engine: engine,
        periodTarget: periodTarget,
        plannedStartDate: plannedStartDate,
        plannedEndDate: plannedEndDate,
      ),
    );
  }

  @override
  State<TargetDetailsSheet> createState() => _TargetDetailsSheetState();
}

class _TargetDetailsSheetState extends State<TargetDetailsSheet> {
  AstroEngine get _engine => widget.engine ?? AstroEngine.instance;

  List<AltitudePoint> _curvePoints = [];
  bool _isLoadingCurve = true;
  DateTime? _temporaryDate;
  NightSummary? _temporaryNight;
  List<AltitudePoint>? _temporaryCurvePoints;
  YearlyVisibilityModel? _yearlyVisibility;
  bool _isLoadingYearly = true;
  String? _onlineInfo;
  bool _showFilteredYearly = true;
  TargetDescription? _targetDescription;
  bool _isLoadingDescription = true;
  TerrainProfileModel? _cachedTerrainProfile;

  @override
  void initState() {
    super.initState();
    FavoritesManager.instance.addListener(_onFavoritesChanged);
    _loadCurve();
    _loadYearlyVisibility();
    _loadDescription();
    _loadCachedTerrainProfile();
  }

  void _loadCachedTerrainProfile() async {
    if (widget.filters?.terrainProfile != null) return;
    final cached = await TerrainCacheService.loadProfile(
      widget.latitude,
      widget.longitude,
    );
    if (cached != null && mounted) {
      setState(() {
        _cachedTerrainProfile = cached;
      });
    }
  }

  void _loadDescription({bool allowOnline = false}) async {
    setState(() => _isLoadingDescription = true);
    final desc = await TargetDescriptionService.instance.getDescription(
      widget.target,
      engine: _engine,
      allowOnline: allowOnline,
    );
    if (mounted) {
      setState(() {
        _targetDescription = desc;
        _isLoadingDescription = false;
      });
    }
  }

  @override
  void dispose() {
    FavoritesManager.instance.removeListener(_onFavoritesChanged);
    super.dispose();
  }

  void _onFavoritesChanged() {
    if (mounted) setState(() {});
  }

  bool _hasFilterChanges(FilterState? a, FilterState? b) {
    if (identical(a, b)) return false;
    if (a == null || b == null) return true;
    return a.minAltitude != b.minAltitude ||
        a.maxAltitude != b.maxAltitude ||
        a.minDurationHours != b.minDurationHours ||
        a.minAzimuth != b.minAzimuth ||
        a.maxAzimuth != b.maxAzimuth ||
        a.quadrant != b.quadrant ||
        a.minMoonSeparation != b.minMoonSeparation ||
        a.useCustomTimeWindow != b.useCustomTimeWindow ||
        a.customStartHour != b.customStartHour ||
        a.customStartMinute != b.customStartMinute ||
        a.customEndHour != b.customEndHour ||
        a.customEndMinute != b.customEndMinute ||
        a.useCustomHorizon != b.useCustomHorizon ||
        a.horizonPoints.length != b.horizonPoints.length ||
        a.date.year != b.date.year;
  }

  @override
  void didUpdateWidget(covariant TargetDetailsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target.id != widget.target.id) {
      _temporaryDate = null;
      _temporaryNight = null;
      _temporaryCurvePoints = null;
      _loadDescription();
    }
    if (oldWidget.target.id != widget.target.id ||
        oldWidget.night.sunset != widget.night.sunset) {
      _temporaryDate = null;
      _temporaryNight = null;
      _temporaryCurvePoints = null;
      _loadCurve();
      _loadYearlyVisibility();
    } else if (oldWidget.target.meetsCriteria != widget.target.meetsCriteria ||
        _hasFilterChanges(oldWidget.filters, widget.filters) ||
        oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude ||
        oldWidget.elevation != widget.elevation ||
        oldWidget.periodTarget != widget.periodTarget) {
      _loadYearlyVisibility();
    }
  }

  void _loadYearlyVisibility() {
    setState(() => _isLoadingYearly = true);
    Future.microtask(() {
      try {
        final yearly = _engine.getTargetYearlyVisibility(
          targetId: widget.target.id,
          latitude: widget.latitude,
          longitude: widget.longitude,
          elevation: widget.elevation,
          filters: _showFilteredYearly ? widget.filters : null,
          minAltitude: widget.filters?.minAltitude ?? 30.0,
          minDurationHours: widget.filters?.minDurationHours ?? 2.0,
          year: widget.filters?.date.year ?? DateTime.now().year,
        );
        if (mounted) {
          setState(() {
            _yearlyVisibility = yearly;
            _isLoadingYearly = false;
          });
        }
      } catch (e) {
        AppLogger.error('Failed loading yearly visibility for target ${widget.target.id}', tag: 'TargetDetailsSheet', error: e);
        if (mounted) {
          setState(() => _isLoadingYearly = false);
        }
      }
    });
  }

  void _loadCurve() {
    setState(() => _isLoadingCurve = true);
    try {
      final points = _engine.generateAltitudeCurve(
        targetId: widget.target.id,
        latitude: widget.latitude,
        longitude: widget.longitude,
        elevation: widget.elevation,
        start: widget.night.sunset.subtract(const Duration(hours: 1)),
        end: widget.night.sunrise.add(const Duration(hours: 1)),
        stepMinutes: 10,
      );
      setState(() {
        _curvePoints = points;
        _isLoadingCurve = false;
      });
    } catch (e) {
      AppLogger.error('Failed generating altitude curve for target ${widget.target.id}', tag: 'TargetDetailsSheet', error: e);
      setState(() => _isLoadingCurve = false);
    }
  }

  void _onChartDateChanged(DateTime newDate) {
    final baseNightDate = widget.night.sunset;
    if (newDate.year == baseNightDate.year &&
        newDate.month == baseNightDate.month &&
        newDate.day == baseNightDate.day) {
      _onResetChartDate();
      return;
    }

    try {
      final night = _engine.getNightSummary(
        latitude: widget.latitude,
        longitude: widget.longitude,
        elevation: widget.elevation,
        date: newDate,
      );
      final points = _engine.generateAltitudeCurve(
        targetId: widget.target.id,
        latitude: widget.latitude,
        longitude: widget.longitude,
        elevation: widget.elevation,
        start: night.sunset.subtract(const Duration(hours: 1)),
        end: night.sunrise.add(const Duration(hours: 1)),
        stepMinutes: 10,
      );
      if (mounted) {
        setState(() {
          _temporaryDate = newDate;
          _temporaryNight = night;
          _temporaryCurvePoints = points;
        });
      }
    } catch (e) {
      AppLogger.error('Failed generating curve for temporary date $newDate', tag: 'TargetDetailsSheet', error: e);
    }
  }

  void _onResetChartDate() {
    if (mounted) {
      setState(() {
        _temporaryDate = null;
        _temporaryNight = null;
        _temporaryCurvePoints = null;
      });
    }
  }

  void _showAddToListDialog() {
    AddTargetToListDialog.show(
      context: context,
      targetId: widget.target.id,
      targetDisplayName: widget.target.displayName,
      availableLists: widget.availableLists,
      onAddToList: widget.onAddToList,
    );
  }

  void _queryOnlineSimbad() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _onlineInfo = l10n.simbadQuerying);
    final result = await CatalogManager.queryOnlineObject(widget.target.name);
    if (mounted) {
      setState(() {
        if (result != null) {
          final objType = result['object_type']?.toString() ?? '';
          _onlineInfo = l10n.simbadVerified(objType);
        } else {
          _onlineInfo = l10n.simbadNotFound;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AstroPalette.of(context);
    final textColor = palette.textPrimary;
    final accentColor = palette.accent;
    final effectiveClose = widget.onClose ??
        (Navigator.of(context).canPop() ? () => Navigator.of(context).pop() : null);

    final isNarrow = MediaQuery.of(context).size.width < 600;

    final badgesWrap = Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (widget.target.catalog.isNotEmpty)
          _buildBadge(widget.target.catalog, palette.nebulaIndigo),
        if (widget.target.messier != null && widget.target.messier!.isNotEmpty)
          _buildBadge(widget.target.messier!, palette.nebulaIndigo),
        if (widget.target.caldwell != null && widget.target.caldwell!.isNotEmpty)
          _buildBadge(widget.target.caldwell!, palette.nebulaIndigo),
        if (widget.target.arp != null && widget.target.arp!.isNotEmpty)
          _buildBadge(widget.target.arp!, Colors.deepOrangeAccent),
        if (widget.target.herschel != null && widget.target.herschel!.isNotEmpty)
          _buildBadge(widget.target.herschel!, Colors.amber.shade700),
        if (widget.target.objectType.isNotEmpty)
          _buildBadge(localizeObjectType(widget.target.objectType, l10n), palette.starlightCyan),
        if (widget.target.constellation.isNotEmpty)
          _buildBadge(widget.target.constellation, palette.starGold),
      ],
    );

    final addToListBtn = SizedBox(
      height: 40,
      child: FilledButton.icon(
        icon: const Icon(Icons.playlist_add_rounded, size: 18),
        label: Text(l10n.addToObservingList),
        style: FilledButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: _showAddToListDialog,
      ),
    );

    final isFav = FavoritesManager.instance.isFavorite(widget.target.id);
    final heartColor = palette.isRedNightMode ? palette.accent : Colors.pinkAccent;

    final favBtn = Tooltip(
      message: isFav
          ? (l10n.removeFromFavorites)
          : (l10n.addToFavorites),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          FavoritesManager.instance.toggleFavorite(widget.target);
          final nowFav = FavoritesManager.instance.isFavorite(widget.target.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                nowFav
                    ? (l10n.addedToFavorites(widget.target.displayName))
                    : (l10n.removedFromFavorites(widget.target.displayName)),
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isFav
                ? heartColor.withValues(alpha: 0.22)
                : palette.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isFav ? heartColor : palette.border,
              width: 1.4,
            ),
          ),
          child: Icon(
            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 20,
            color: isFav ? heartColor : palette.textSecondary,
          ),
        ),
      ),
    );

    final closeBtn = effectiveClose != null
        ? Tooltip(
            message: l10n.closeDetailsTooltip,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: effectiveClose,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: palette.border,
                    width: 1.4,
                  ),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: palette.textSecondary,
                ),
              ),
            ),
          )
        : null;

    return Container(
      padding: EdgeInsets.all(isNarrow ? 16 : 20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: palette.border,
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            if (isNarrow) ...[
              // Mobile Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.target.displayName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                  if (effectiveClose != null)
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: textColor),
                      tooltip: l10n.closeBtn,
                      onPressed: effectiveClose,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              badgesWrap,
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.playlist_add_rounded, size: 18),
                        label: Text(l10n.addToObservingList),
                        style: FilledButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: _showAddToListDialog,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  favBtn,
                ],
              ),
            ] else ...[
              // Desktop Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.target.displayName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        badgesWrap,
                      ],
                    ),
                  ),
                  addToListBtn,
                  const SizedBox(width: 8),
                  favBtn,
                  if (closeBtn != null) ...[
                    const SizedBox(width: 8),
                    closeBtn,
                  ],
                ],
              ),
            ],

            const SizedBox(height: 16),

            if (widget.periodTarget != null &&
                widget.plannedStartDate != null &&
                widget.plannedEndDate != null) ...[
              _buildPeriodPlanningBanner(
                widget.periodTarget!,
                widget.plannedStartDate!,
                widget.plannedEndDate!,
              ),
              const SizedBox(height: 14),
            ],

            // Key Metrics Grid
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: palette.border,
                ),
              ),
              child: isNarrow
                  ? Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetric(
                                l10n.peakAltitude,
                                "${widget.target.peakAltitudeDeg.toStringAsFixed(1)}°",
                                Icons.trending_up_rounded,
                              ),
                            ),
                            Expanded(
                              child: _buildMetric(
                                l10n.transitTimeMetric,
                                DateFormat('HH:mm').format(widget.target.transitTime),
                                Icons.schedule_rounded,
                              ),
                            ),
                            Expanded(
                              child: _buildMetric(
                                l10n.visibleDurationMetric,
                                "${widget.target.visibleDurationHours.toStringAsFixed(1)} hrs",
                                Icons.timer_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetric(
                                l10n.moonDistanceMetric,
                                "${widget.target.minMoonSepDeg.toStringAsFixed(0)}°",
                                Icons.brightness_2_outlined,
                              ),
                            ),
                            Expanded(
                              child: _buildMetric(
                                l10n.magnitudeLabel,
                                widget.target.magnitude != null ? "${widget.target.magnitude}" : "N/A",
                                Icons.auto_awesome_rounded,
                              ),
                            ),
                            Expanded(
                              child: _buildMetric(
                                l10n.apparentSizeMetric,
                                widget.target.majorAxisArcmin != null
                                    ? "${widget.target.majorAxisArcmin!.toStringAsFixed(1)}'"
                                    : "N/A",
                                Icons.aspect_ratio_rounded,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Expanded(
                          child: _buildMetric(
                            l10n.peakAltitude,
                            "${widget.target.peakAltitudeDeg.toStringAsFixed(1)}°",
                            Icons.trending_up_rounded,
                          ),
                        ),
                        Expanded(
                          child: _buildMetric(
                            l10n.transitTimeMetric,
                            DateFormat('HH:mm').format(widget.target.transitTime),
                            Icons.schedule_rounded,
                          ),
                        ),
                        Expanded(
                          child: _buildMetric(
                            l10n.visibleDurationMetric,
                            "${widget.target.visibleDurationHours.toStringAsFixed(1)} hrs",
                            Icons.timer_outlined,
                          ),
                        ),
                        Expanded(
                          child: _buildMetric(
                            l10n.moonDistanceMetric,
                            "${widget.target.minMoonSepDeg.toStringAsFixed(0)}°",
                            Icons.brightness_2_outlined,
                          ),
                        ),
                        Expanded(
                          child: _buildMetric(
                            l10n.magnitudeLabel,
                            widget.target.magnitude != null ? "${widget.target.magnitude}" : "N/A",
                            Icons.auto_awesome_rounded,
                          ),
                        ),
                        Expanded(
                          child: _buildMetric(
                            l10n.apparentSizeMetric,
                            widget.target.majorAxisArcmin != null
                                ? "${widget.target.majorAxisArcmin!.toStringAsFixed(1)}'"
                                : "N/A",
                            Icons.aspect_ratio_rounded,
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 18),

            // Target Overview / Description (Readable Prose)
            _buildDescriptionCard(),

            const SizedBox(height: 18),

            // Visual Sky Preview & Apparent Size
            _buildVisualPreviewCard(),

            const SizedBox(height: 18),

            // Yearly Observing Window & 12-Month Mini-Strip Chart
            _buildYearlyVisibilityCard(),

            const SizedBox(height: 18),

            // Altitude vs Time Interactive Curve Chart
            if (_isLoadingCurve)
              const Center(child: CircularProgressIndicator())
            else
              Builder(
                builder: (context) {
                  final effectiveFilters = (widget.filters?.terrainProfile != null)
                      ? widget.filters
                      : (widget.filters != null && _cachedTerrainProfile != null)
                          ? widget.filters!.copyWith(
                              terrainProfile: _cachedTerrainProfile,
                              showTerrainSilhouette: true,
                            )
                          : (_cachedTerrainProfile != null)
                              ? FilterState(
                                  terrainProfile: _cachedTerrainProfile,
                                  showTerrainSilhouette: true,
                                  observerLat: widget.latitude,
                                  observerLon: widget.longitude,
                                  observerElevation: widget.elevation,
                                )
                              : widget.filters;

                  final effectiveNight = _temporaryNight ?? widget.night;
                  final effectiveCurvePoints = _temporaryCurvePoints ?? _curvePoints;

                  return AltitudeCurveChart(
                    targetPoints: effectiveCurvePoints,
                    night: effectiveNight,
                    targetName: widget.target.displayName,
                    minAltitudeThreshold: widget.filters?.minAltitude ?? 30.0,
                    maxAltitudeThreshold: widget.filters?.maxAltitude ?? 90.0,
                    customWindowStart: (widget.filters?.useCustomTimeWindow == true)
                        ? widget.filters!.getWindowStart(effectiveNight.sunset)
                        : null,
                    customWindowEnd: (widget.filters?.useCustomTimeWindow == true)
                        ? widget.filters!.getWindowEnd(effectiveNight.sunset)
                        : null,
                    filterState: effectiveFilters,
                    isRedNightMode: widget.isRedNightMode,
                    activeDate: _temporaryDate,
                    isDateOverridden: _temporaryDate != null,
                    onDateChanged: _onChartDateChanged,
                    onResetDate: _onResetChartDate,
                  );
                },
              ),

            const SizedBox(height: 16),

            // Coordinates and identifiers
            isNarrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "RA: ${widget.target.formattedRa}  |  Dec: ${widget.target.formattedDec}${widget.target.positionAngleDeg != null ? "  |  PA: ${widget.target.positionAngleDeg!.toStringAsFixed(1)}°" : ""}",
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        icon: const Icon(Icons.travel_explore_rounded, size: 16),
                        label: Text(l10n.verifyOnlineSimbad),
                        onPressed: _queryOnlineSimbad,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Text(
                          "RA: ${widget.target.formattedRa}  |  Dec: ${widget.target.formattedDec}${widget.target.positionAngleDeg != null ? "  |  PA: ${widget.target.positionAngleDeg!.toStringAsFixed(1)}°" : ""}",
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: textColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.travel_explore_rounded, size: 16),
                        label: Text(l10n.verifyOnlineSimbad),
                        onPressed: _queryOnlineSimbad,
                      ),
                    ],
                  ),

            if (_onlineInfo != null) ...[
              const SizedBox(height: 4),
              Text(
                _onlineInfo!,
                style: TextStyle(fontSize: 12, color: accentColor),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionCard() {
    final palette = AstroPalette.of(context);
    final textColor = palette.textPrimary;
    final accentColor = palette.accent;

    if (_isLoadingDescription) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: palette.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: palette.border,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Loading target overview...",
                style: TextStyle(
                  fontSize: 12,
                  color: palette.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    if (_targetDescription == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: palette.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: palette.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 16,
              color: palette.textTertiary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "No local description available.",
                style: TextStyle(fontSize: 12, color: palette.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            TextButton.icon(
              icon: const Icon(Icons.cloud_download_outlined, size: 14),
              label: const Text("Fetch (Wiki)", style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: accentColor,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _loadDescription(allowOnline: true),
            ),
          ],
        ),
      );
    }

    final desc = _targetDescription!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: palette.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_stories_rounded,
                size: 16,
                color: accentColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  desc.title.isNotEmpty ? desc.title : "Target Overview",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (desc.pageUrl != null && desc.pageUrl!.isNotEmpty)
                Tooltip(
                  message: "View full article on Wikipedia",
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => UrlService.openUrl(desc.pageUrl!),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            desc.source,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: accentColor.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 12,
                            color: accentColor.withValues(alpha: 0.85),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (desc.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              desc.description,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: accentColor.withValues(alpha: 0.9),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            desc.extract,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: textColor.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, IconData icon) {
    final palette = AstroPalette.of(context);
    return Column(
      children: [
        Icon(icon, size: 16, color: palette.accent),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: palette.textPrimary)),
        Text(label, style: TextStyle(fontSize: 10, color: palette.textSecondary)),
      ],
    );
  }

  Widget _buildPeriodPlanningBanner(
    PeriodTargetItem periodTarget,
    DateTime startDate,
    DateTime endDate,
  ) {
    final l10n = AppLocalizations.of(context);
    final palette = AstroPalette.of(context);
    final textColor = palette.textPrimary;
    final accentColor = palette.accent;

    final startStr = DateFormat('MMM d').format(startDate);
    final endStr = DateFormat('MMM d').format(endDate);
    final hasPeak = periodTarget.peakDate != null && periodTarget.isObservable && periodTarget.observableDaysCount > 0;
    final peakDateStr = hasPeak ? DateFormat('MMM d').format(periodTarget.peakDate!) : '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasPeak
              ? accentColor.withValues(alpha: 0.5)
              : Colors.orange.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 16,
                color: hasPeak ? accentColor : Colors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.plannedPeriodBannerTitle(startStr, endStr),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: hasPeak ? accentColor : Colors.orange,
                  ),
                ),
              ),
              if (hasPeak)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: palette.visibleGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: palette.visibleGreen.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    l10n.periodPeakDate(peakDateStr),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: palette.visibleGreen,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasPeak) ...[
            Text(
              l10n.periodBestNightSummary(peakDateStr, periodTarget.maxHoursObservable.toStringAsFixed(1)),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "${l10n.periodDaysObservableSummary(periodTarget.observableDaysCount, periodTarget.totalPeriodDays)} • ${l10n.periodPeakAltSummary(periodTarget.peakAltitudeDeg.toStringAsFixed(1))}",
                    style: TextStyle(
                      fontSize: 11,
                      color: textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 13,
                  color: textColor.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l10n.periodEvaluatedNote(peakDateStr),
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              l10n.periodNotObservableSummary,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 13,
                  color: textColor.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    l10n.periodEvaluatedStartDateNote(startStr),
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: textColor.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    final palette = AstroPalette.of(context);
    final badgeColor = palette.isRedNightMode ? palette.accent : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: badgeColor),
      ),
    );
  }

  String _describeFilters(FilterState f) {
    final parts = <String>[];
    if (f.quadrant != 0) {
      const quadNames = ["All", "North", "East", "South", "West", "NE", "SE", "SW", "NW"];
      parts.add(f.quadrant < quadNames.length ? quadNames[f.quadrant] : "Quadrant ${f.quadrant}");
    } else if (f.minAzimuth != 0.0 || f.maxAzimuth != 360.0) {
      parts.add("${f.minAzimuth.round()}°–${f.maxAzimuth.round()}°");
    }
    if (f.useCustomTimeWindow) {
      parts.add(f.formattedWindow);
    } else {
      parts.add("Dusk–Dawn");
    }
    parts.add("Min ${f.minAltitude.round()}°");
    parts.add("${f.minDurationHours.toStringAsFixed(1)}h");
    return parts.join(" · ");
  }

  Widget _buildVisualPreviewCard() {
    final l10n = AppLocalizations.of(context);
    final palette = AstroPalette.of(context);
    final textColor = palette.textPrimary;
    final accentColor = palette.accent;

    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.center_focus_strong_rounded,
                size: 16,
                color: accentColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.visualSkyPreview,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              // Equipment Gear Dialog Button
              InkWell(
                onTap: _openEquipmentDialog,
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 12, color: palette.starGold),
                      const SizedBox(width: 3),
                      Text(
                        l10n.gearButton,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: palette.starGold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TargetPreviewCanvas(
            target: widget.target,
            height: 240,
            enableExpandDialog: true,
            onOpenFramingDialog: () => _openFramingDialog(widget.target),
            onOpenEquipmentDialog: _openEquipmentDialog,
          ),
        ],
      ),
    );
  }

  void _openFramingDialog(TargetItem target) {
    showDialog(
      context: context,
      builder: (_) => EquipmentFramingDialog(
        target: target,
      ),
    );
  }

  void _openEquipmentDialog() {
    showDialog(
      context: context,
      builder: (_) => EquipmentDialog(
        onSaved: () => setState(() {}),
      ),
    );
  }

  Widget _buildYearlyVisibilityCard() {
    final l10n = AppLocalizations.of(context);
    final palette = AstroPalette.of(context);
    final textColor = palette.textPrimary;
    final accentColor = palette.accent;

    if (_isLoadingYearly) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: accentColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.simulatingYearlyVisibility,
                style: TextStyle(fontSize: 11, color: palette.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    if (_yearlyVisibility == null) return const SizedBox.shrink();

    final y = _yearlyVisibility!;
    final now = widget.night.sunset;
    final inSeasonTonight = y.isDateObservable(now);
    final isVisibleTonight = inSeasonTonight && (_showFilteredYearly ? widget.target.meetsCriteria : true);

    // Determine tonight status text factoring in days remaining until season start
    final seasonStatus = SeasonStatusCalculator.computeStatus(
      yearly: y,
      isVisibleTonight: isVisibleTonight,
      showFilteredYearly: _showFilteredYearly,
      l10n: l10n,
      periodTarget: widget.periodTarget,
      referenceDate: now,
    );
    final tonightStatusText = seasonStatus.statusText;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: palette.isRedNightMode
              ? palette.border
              : (y.canEverReachMinAlt
                  ? palette.accent.withValues(alpha: 0.3)
                  : Colors.redAccent.withValues(alpha: 0.35)),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // View Mode Selector: Filtered vs Full Sky & Darkness
          if (widget.filters != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    l10n.simulationModeLabel,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: textColor.withValues(alpha: 0.5),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      if (!_showFilteredYearly) {
                        setState(() => _showFilteredYearly = true);
                        _loadYearlyVisibility();
                      }
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _showFilteredYearly
                            ? accentColor.withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _showFilteredYearly
                              ? accentColor.withValues(alpha: 0.6)
                              : textColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        l10n.activeFiltersMode,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: _showFilteredYearly ? FontWeight.w700 : FontWeight.w500,
                          color: _showFilteredYearly ? accentColor : textColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      if (_showFilteredYearly) {
                        setState(() => _showFilteredYearly = false);
                        _loadYearlyVisibility();
                      }
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: !_showFilteredYearly
                            ? accentColor.withValues(alpha: 0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: !_showFilteredYearly
                              ? accentColor.withValues(alpha: 0.6)
                              : textColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        l10n.fullSkyNightMode,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: !_showFilteredYearly ? FontWeight.w700 : FontWeight.w500,
                          color: !_showFilteredYearly ? accentColor : textColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Header: Season Title + Tonight Status Badge
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 460;
              final seasonHeader = Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.date_range_rounded, size: 16, color: accentColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.yearlyObservingWindow,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: textColor.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          localizeBestWindowSummary(y, l10n),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        if (_showFilteredYearly && widget.filters != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              "Filters: ${_describeFilters(widget.filters!)}",
                              style: TextStyle(
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                                color: textColor.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        if (y.totalObservableDays > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              l10n.yearlyDaysObservablePeak(
                                y.totalObservableDays,
                                y.maxHoursInPeak.toStringAsFixed(1),
                                "${localizeMonthAbbr(y.peakMonth, l10n)} ${y.peakDay}",
                              ),
                              style: TextStyle(
                                fontSize: 10,
                                color: textColor.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );

              final isPositiveStatus = seasonStatus.isPositive;
              final isZeroDays = seasonStatus.isZeroDays;
              final statusPill = Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositiveStatus
                      ? palette.visibleGreen.withValues(alpha: 0.15)
                      : (isZeroDays
                          ? Colors.orange.withValues(alpha: 0.15)
                          : Colors.amber.withValues(alpha: 0.15)),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isPositiveStatus
                        ? palette.visibleGreen.withValues(alpha: 0.5)
                        : (isZeroDays
                            ? Colors.orange.withValues(alpha: 0.5)
                            : Colors.amber.withValues(alpha: 0.5)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositiveStatus
                          ? Icons.check_circle_outline_rounded
                          : (isZeroDays ? Icons.filter_alt_off_rounded : Icons.schedule_rounded),
                      size: 13,
                      color: isPositiveStatus
                          ? palette.visibleGreen
                          : (isZeroDays ? Colors.orange : Colors.amber),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      tonightStatusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isPositiveStatus
                            ? palette.visibleGreen
                            : (isZeroDays ? Colors.orange : Colors.amber),
                      ),
                    ),
                  ],
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    seasonHeader,
                    const SizedBox(height: 8),
                    statusPill,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: seasonHeader),
                  const SizedBox(width: 8),
                  statusPill,
                ],
              );
            },
          ),

          const SizedBox(height: 14),

          // 12-Month Mini-Strip Chart
          Row(
            children: y.months.map((m) {
              final isPeak = m.month == y.peakMonth && m.hoursObservable > 0;
              final isObservable = m.isObservable;
              final isPartial = m.isPartialMonth;

              Color bgColor;
              Color borderColor;
              Color monthTextColor;

              if (isPeak) {
                bgColor = palette.starGold.withValues(alpha: 0.22);
                borderColor = palette.starGold;
                monthTextColor = palette.starGold;
              } else if (isObservable) {
                bgColor = palette.accent.withValues(alpha: isPartial ? 0.08 : 0.15);
                borderColor = palette.accent.withValues(alpha: isPartial ? 0.6 : 0.4);
                monthTextColor = palette.accent;
              } else {
                bgColor = Colors.black.withValues(alpha: 0.25);
                borderColor = Colors.white.withValues(alpha: 0.08);
                monthTextColor = palette.textTertiary;
              }

              return Expanded(
                child: Tooltip(
                  message: m.dateRangeLabel,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: borderColor,
                        width: isPeak ? 1.4 : 1.0,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          localizeMonthAbbr(m.month, l10n).toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: monthTextColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (isPeak)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "${m.observableDaysCount}d",
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    color: monthTextColor,
                                  ),
                                ),
                                Icon(Icons.star_rounded, size: 9, color: monthTextColor),
                              ],
                            ),
                          )
                        else if (isObservable)
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "${m.observableDaysCount}d",
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: monthTextColor.withValues(alpha: 0.9),
                              ),
                            ),
                          )
                        else
                          Text(
                            "—",
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.normal,
                              color: monthTextColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 10),

          // Footnote: Max theoretical altitude & filter criteria info
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(
                l10n.theoreticalMaxAtTransit(
                  y.theoreticalMaxAltitudeDeg.toStringAsFixed(1),
                  y.totalObservableDays > 0 ? ' • ${y.totalObservableDays} days/yr' : '',
                ),
                style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.5)),
              ),
              Text(
                l10n.limitsSubtitle(
                  widget.filters?.minAltitude.round().toString() ?? '30',
                  widget.filters?.minDurationHours.toStringAsFixed(1) ?? '2.0',
                ),
                style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
