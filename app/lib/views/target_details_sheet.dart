import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/astro_bridge.dart';
import '../core/catalog_manager.dart';
import '../models/altitude_point.dart';
import '../models/filter_state.dart';
import '../models/night_summary.dart';
import '../models/observing_list.dart';
import '../models/target_item.dart';
import '../models/yearly_visibility.dart';
import '../theme/astro_theme.dart';
import '../widgets/target_preview_canvas.dart';
import 'altitude_curve_chart.dart';
import 'equipment_dialog.dart';

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
  });

  @override
  State<TargetDetailsSheet> createState() => _TargetDetailsSheetState();
}

class _TargetDetailsSheetState extends State<TargetDetailsSheet> {
  List<AltitudePoint> _curvePoints = [];
  bool _isLoadingCurve = true;
  YearlyVisibilityModel? _yearlyVisibility;
  bool _isLoadingYearly = true;
  String? _onlineInfo;
  bool _showFilteredYearly = true;

  @override
  void initState() {
    super.initState();
    _loadCurve();
    _loadYearlyVisibility();
  }

  @override
  void didUpdateWidget(covariant TargetDetailsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target.id != widget.target.id) {
      _loadCurve();
      _loadYearlyVisibility();
    } else if (oldWidget.filters?.minAltitude != widget.filters?.minAltitude ||
        oldWidget.filters?.minDurationHours != widget.filters?.minDurationHours ||
        oldWidget.filters?.minAzimuth != widget.filters?.minAzimuth ||
        oldWidget.filters?.maxAzimuth != widget.filters?.maxAzimuth ||
        oldWidget.filters?.quadrant != widget.filters?.quadrant ||
        oldWidget.filters?.useCustomTimeWindow != widget.filters?.useCustomTimeWindow ||
        oldWidget.filters?.customStartHour != widget.filters?.customStartHour ||
        oldWidget.filters?.customEndHour != widget.filters?.customEndHour) {
      _loadYearlyVisibility();
    }
  }

  void _loadYearlyVisibility() {
    setState(() => _isLoadingYearly = true);
    Future.microtask(() {
      try {
        final yearly = AstroBridge.instance.getTargetYearlyVisibility(
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
      } catch (_) {
        if (mounted) {
          setState(() => _isLoadingYearly = false);
        }
      }
    });
  }

  void _loadCurve() {
    setState(() => _isLoadingCurve = true);
    try {
      final points = AstroBridge.instance.generateAltitudeCurve(
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
    } catch (_) {
      setState(() => _isLoadingCurve = false);
    }
  }

  void _showAddToListDialog() {
    if (widget.availableLists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No observing lists found. Create a list first!")),
      );
      return;
    }

    int selectedListId = widget.availableLists.first.id;
    final notesController = TextEditingController(text: "Target for imaging");

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: widget.isRedNightMode
                  ? AstroColors.nightVisionSurface
                  : AstroColors.spaceDarkSurface,
              title: Text(
                "Add ${widget.target.displayName} to List",
                style: TextStyle(
                  color: widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white,
                  fontSize: 16,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: selectedListId,
                    decoration: const InputDecoration(labelText: "Target Observing List"),
                    items: widget.availableLists.map((l) {
                      return DropdownMenuItem(
                        value: l.id,
                        child: Text(l.name, style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedListId = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: const InputDecoration(labelText: "Session Notes / Filters"),
                    style: TextStyle(
                      color: widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text("Cancel"),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                FilledButton(
                  child: const Text("Add"),
                  onPressed: () {
                    widget.onAddToList(selectedListId, widget.target.id, notesController.text);
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Added ${widget.target.displayName} to observing list")),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _queryOnlineSimbad() async {
    setState(() => _onlineInfo = "Querying CDS / SIMBAD...");
    final result = await CatalogManager.queryOnlineObject(widget.target.name);
    if (mounted) {
      setState(() {
        if (result != null) {
          _onlineInfo = "Verified on SIMBAD: ${result['object_type']}";
        } else {
          _onlineInfo = "No additional online records found.";
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;
    final effectiveClose = widget.onClose ??
        (Navigator.of(context).canPop() ? () => Navigator.of(context).pop() : null);

    final isNarrow = MediaQuery.of(context).size.width < 600;

    final badgesWrap = Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _buildBadge(widget.target.catalog, AstroColors.nebulaIndigo),
        if (widget.target.messier != null && widget.target.messier!.isNotEmpty)
          _buildBadge(widget.target.messier!, AstroColors.nebulaIndigo),
        if (widget.target.caldwell != null && widget.target.caldwell!.isNotEmpty)
          _buildBadge(widget.target.caldwell!, AstroColors.nebulaIndigo),
        if (widget.target.arp != null && widget.target.arp!.isNotEmpty)
          _buildBadge(widget.target.arp!, Colors.deepOrangeAccent),
        if (widget.target.herschel != null && widget.target.herschel!.isNotEmpty)
          _buildBadge(widget.target.herschel!, Colors.amber.shade700),
        _buildBadge(widget.target.objectType, AstroColors.starlightCyan),
        _buildBadge(widget.target.constellation, AstroColors.starGold),
      ],
    );

    final addToListBtn = FilledButton.icon(
      icon: const Icon(Icons.playlist_add_rounded, size: 18),
      label: const Text("Add to List"),
      style: FilledButton.styleFrom(
        backgroundColor: accentColor,
        foregroundColor: Colors.black,
      ),
      onPressed: _showAddToListDialog,
    );

    final closeBtn = effectiveClose != null
        ? Tooltip(
            message: "Close details (Esc)",
            child: OutlinedButton.icon(
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white,
              ),
              label: Text(
                "Close",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: widget.isRedNightMode
                    ? AstroColors.nightVisionRed.withValues(alpha: 0.18)
                    : const Color(0xFF222F42),
                side: BorderSide(
                  color: widget.isRedNightMode
                      ? AstroColors.nightVisionRed.withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.4),
                  width: 1.4,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: effectiveClose,
            ),
          )
        : null;

    return Container(
      padding: EdgeInsets.all(isNarrow ? 16 : 20),
      decoration: BoxDecoration(
        color: widget.isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder,
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
                      tooltip: "Close",
                      onPressed: effectiveClose,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              badgesWrap,
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.playlist_add_rounded, size: 18),
                  label: const Text("Add to Observing List"),
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _showAddToListDialog,
                ),
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
                  if (closeBtn != null) ...[
                    const SizedBox(width: 8),
                    closeBtn,
                  ],
                ],
              ),
            ],

            const SizedBox(height: 16),

            // Key Metrics Grid
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.isRedNightMode
                    ? AstroColors.nightVisionSurfaceVariant
                    : AstroColors.spaceDarkSurfaceVariant,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isRedNightMode
                      ? AstroColors.nightVisionBorder
                      : AstroColors.spaceDarkBorder,
                ),
              ),
              child: isNarrow
                  ? Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetric(
                                "Peak Altitude",
                                "${widget.target.peakAltitudeDeg.toStringAsFixed(1)}°",
                                Icons.trending_up_rounded,
                              ),
                            ),
                            Expanded(
                              child: _buildMetric(
                                "Transit Time",
                                DateFormat('HH:mm').format(widget.target.transitTime),
                                Icons.schedule_rounded,
                              ),
                            ),
                            Expanded(
                              child: _buildMetric(
                                "Visible Duration",
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
                                "Moon Distance",
                                "${widget.target.minMoonSepDeg.toStringAsFixed(0)}°",
                                Icons.brightness_2_outlined,
                              ),
                            ),
                            Expanded(
                              child: _buildMetric(
                                "Magnitude",
                                widget.target.magnitude != null ? "${widget.target.magnitude}" : "N/A",
                                Icons.auto_awesome_rounded,
                              ),
                            ),
                            Expanded(
                              child: _buildMetric(
                                "Apparent Size",
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
                        _buildMetric(
                          "Peak Altitude",
                          "${widget.target.peakAltitudeDeg.toStringAsFixed(1)}°",
                          Icons.trending_up_rounded,
                        ),
                        _buildMetric(
                          "Transit Time",
                          DateFormat('HH:mm').format(widget.target.transitTime),
                          Icons.schedule_rounded,
                        ),
                        _buildMetric(
                          "Visible Duration",
                          "${widget.target.visibleDurationHours.toStringAsFixed(1)} hrs",
                          Icons.timer_outlined,
                        ),
                        _buildMetric(
                          "Moon Distance",
                          "${widget.target.minMoonSepDeg.toStringAsFixed(0)}°",
                          Icons.brightness_2_outlined,
                        ),
                        _buildMetric(
                          "Magnitude",
                          widget.target.magnitude != null ? "${widget.target.magnitude}" : "N/A",
                          Icons.auto_awesome_rounded,
                        ),
                        _buildMetric(
                          "Apparent Size",
                          widget.target.majorAxisArcmin != null
                              ? "${widget.target.majorAxisArcmin!.toStringAsFixed(1)}'"
                              : "N/A",
                          Icons.aspect_ratio_rounded,
                        ),
                      ],
                    ),
            ),

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
              AltitudeCurveChart(
                targetPoints: _curvePoints,
                night: widget.night,
                targetName: widget.target.displayName,
                minAltitudeThreshold: widget.filters?.minAltitude ?? 30.0,
                customWindowStart: (widget.filters?.useCustomTimeWindow == true)
                    ? widget.filters!.getWindowStart(widget.filters!.date)
                    : null,
                customWindowEnd: (widget.filters?.useCustomTimeWindow == true)
                    ? widget.filters!.getWindowEnd(widget.filters!.date)
                    : null,
                isRedNightMode: widget.isRedNightMode,
              ),

            const SizedBox(height: 16),

            // Coordinates and identifiers
            isNarrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "RA: ${widget.target.formattedRa}  |  Dec: ${widget.target.formattedDec}",
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        icon: const Icon(Icons.travel_explore_rounded, size: 16),
                        label: const Text("Verify Online (SIMBAD)"),
                        onPressed: _queryOnlineSimbad,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Text(
                          "RA: ${widget.target.formattedRa}  |  Dec: ${widget.target.formattedDec}",
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: textColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.travel_explore_rounded, size: 16),
                        label: const Text("Verify Online (SIMBAD)"),
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

  Widget _buildMetric(String label, String value, IconData icon) {
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    return Column(
      children: [
        Icon(icon, size: 16, color: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
        Text(label, style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.6))),
      ],
    );
  }

  Widget _buildBadge(String text, Color color) {
    final isRed = widget.isRedNightMode;
    final badgeColor = isRed ? AstroColors.nightVisionRed : color;
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
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;
    final isRed = widget.isRedNightMode;

    return Container(
      decoration: BoxDecoration(
        color: isRed ? AstroColors.nightVisionSurfaceVariant : AstroColors.spaceDarkSurfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isRed ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder),
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
                  "Visual Sky Preview & Framing",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.target.majorAxisArcmin != null
                    ? "${widget.target.majorAxisArcmin!.toStringAsFixed(1)}' extent"
                    : "Point source",
                style: TextStyle(
                  fontSize: 11,
                  color: textColor.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => EquipmentDialog(
                      isRedNightMode: widget.isRedNightMode,
                      onSaved: () => setState(() {}),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 12, color: AstroColors.starGold),
                      const SizedBox(width: 3),
                      Text(
                        "Gear",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AstroColors.starGold),
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
            isRedNightMode: widget.isRedNightMode,
            height: 240,
            enableExpandDialog: true,
          ),
        ],
      ),
    );
  }

  Widget _buildYearlyVisibilityCard() {
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;
    final isRed = widget.isRedNightMode;

    if (_isLoadingYearly) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isRed ? AstroColors.nightVisionSurfaceVariant : AstroColors.spaceDarkSurfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isRed ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder),
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
                "Simulating 12-month visibility across the year...",
                style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.7)),
              ),
            ),
          ],
        ),
      );
    }

    if (_yearlyVisibility == null) return const SizedBox.shrink();

    final y = _yearlyVisibility!;
    final isVisibleTonight = widget.target.meetsCriteria;

    // Determine tonight status text factoring in days remaining until season start
    String tonightStatusText;
    final now = widget.night.sunset;
    final currentMonth = now.month;
    final currentDay = now.day;

    if (isVisibleTonight) {
      tonightStatusText = "Visible Tonight";
    } else if (!y.canEverReachMinAlt) {
      tonightStatusText = "Unreachable";
    } else if (y.totalObservableDays == 0) {
      tonightStatusText = _showFilteredYearly
          ? "Not observable with active filters"
          : "Not observable (below limits)";
    } else {
      final thisYear = now.year;
      DateTime seasonStart = DateTime(thisYear, y.startMonth, y.startDay);
      if (seasonStart.isBefore(now) && y.startMonth > y.endMonth && currentMonth <= y.endMonth) {
        seasonStart = DateTime(thisYear - 1, y.startMonth, y.startDay);
      }
      DateTime seasonEnd = DateTime(thisYear, y.endMonth, y.endDay);
      if (y.endMonth < y.startMonth && currentMonth >= y.startMonth) {
        seasonEnd = DateTime(thisYear + 1, y.endMonth, y.endDay);
      }

      if (now.isBefore(seasonStart)) {
        final diffDays = seasonStart.difference(DateTime(thisYear, currentMonth, currentDay)).inDays;
        if (diffDays == 1) {
          tonightStatusText = "Starts tomorrow (${y.months[y.startMonth - 1].name} ${y.startDay})";
        } else if (diffDays <= 60) {
          tonightStatusText = "Starts in $diffDays days (${y.months[y.startMonth - 1].name} ${y.startDay})";
        } else {
          tonightStatusText = "Starts ${y.months[y.startMonth - 1].name} ${y.startDay}";
        }
      } else if (!now.isAfter(seasonEnd)) {
        tonightStatusText = "In Season · Below limits tonight";
      } else {
        tonightStatusText = "Off-Season (Ended ${y.months[y.endMonth - 1].name} ${y.endDay})";
      }
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRed ? AstroColors.nightVisionSurfaceVariant : AstroColors.spaceDarkSurfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRed
              ? AstroColors.nightVisionBorder
              : (y.canEverReachMinAlt
                  ? AstroColors.starlightCyan.withValues(alpha: 0.3)
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
              child: Row(
                children: [
                  Text(
                    "SIMULATION MODE:",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: textColor.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                        "Active Filters",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: _showFilteredYearly ? FontWeight.w700 : FontWeight.w500,
                          color: _showFilteredYearly ? accentColor : textColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
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
                        "Full Sky & Night",
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
                          "YEARLY OBSERVING WINDOW",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: textColor.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          y.bestWindowSummary,
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
                              "${y.totalObservableDays} days observable this year • Peak: ${y.maxHoursInPeak.toStringAsFixed(1)}h on ${y.months[y.peakMonth - 1].name} ${y.peakDay}",
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

              final isZeroDays = y.totalObservableDays == 0;
              final statusPill = Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isVisibleTonight
                      ? AstroColors.visibleGreen.withValues(alpha: 0.15)
                      : (isZeroDays
                          ? Colors.orange.withValues(alpha: 0.15)
                          : Colors.amber.withValues(alpha: 0.15)),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isVisibleTonight
                        ? AstroColors.visibleGreen.withValues(alpha: 0.5)
                        : (isZeroDays
                            ? Colors.orange.withValues(alpha: 0.5)
                            : Colors.amber.withValues(alpha: 0.5)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isVisibleTonight
                          ? Icons.check_circle_outline_rounded
                          : (isZeroDays ? Icons.filter_alt_off_rounded : Icons.schedule_rounded),
                      size: 13,
                      color: isVisibleTonight
                          ? AstroColors.visibleGreen
                          : (isZeroDays ? Colors.orange : Colors.amber),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      tonightStatusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isVisibleTonight
                            ? AstroColors.visibleGreen
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
                bgColor = isRed
                    ? AstroColors.nightVisionRed.withValues(alpha: 0.3)
                    : AstroColors.starGold.withValues(alpha: 0.22);
                borderColor = isRed ? AstroColors.nightVisionRed : AstroColors.starGold;
                monthTextColor = isRed ? AstroColors.nightVisionRed : AstroColors.starGold;
              } else if (isObservable) {
                bgColor = isRed
                    ? AstroColors.nightVisionRed.withValues(alpha: isPartial ? 0.08 : 0.15)
                    : AstroColors.starlightCyan.withValues(alpha: isPartial ? 0.08 : 0.15);
                borderColor = isRed
                    ? AstroColors.nightVisionRed.withValues(alpha: isPartial ? 0.6 : 0.4)
                    : AstroColors.starlightCyan.withValues(alpha: isPartial ? 0.6 : 0.4);
                monthTextColor = isRed ? AstroColors.nightVisionRed : AstroColors.starlightCyan;
              } else {
                bgColor = Colors.black.withValues(alpha: 0.25);
                borderColor = Colors.white.withValues(alpha: 0.08);
                monthTextColor = textColor.withValues(alpha: 0.35);
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
                          m.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: monthTextColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (isPeak)
                          Row(
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
                          )
                        else if (isObservable)
                          Text(
                            "${m.observableDaysCount}d",
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: monthTextColor.withValues(alpha: 0.9),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Theoretical max: ${y.theoreticalMaxAltitudeDeg.toStringAsFixed(1)}° at transit${y.totalObservableDays > 0 ? ' • ${y.totalObservableDays} days/yr' : ''}",
                  style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.5)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "Limits: ≥${widget.filters?.minAltitude.round() ?? 30}° for ≥${widget.filters?.minDurationHours.toStringAsFixed(1) ?? '2.0'}h",
                style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
