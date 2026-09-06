import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/astro_bridge.dart';
import '../core/catalog_manager.dart';
import '../models/altitude_point.dart';
import '../models/filter_state.dart';
import '../models/night_summary.dart';
import '../models/observing_list.dart';
import '../models/target_item.dart';
import '../theme/astro_theme.dart';
import 'altitude_curve_chart.dart';

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
  });

  @override
  State<TargetDetailsSheet> createState() => _TargetDetailsSheetState();
}

class _TargetDetailsSheetState extends State<TargetDetailsSheet> {
  List<AltitudePoint> _curvePoints = [];
  bool _isLoadingCurve = true;
  String? _onlineInfo;

  @override
  void initState() {
    super.initState();
    _loadCurve();
  }

  @override
  void didUpdateWidget(covariant TargetDetailsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target.id != widget.target.id) {
      _loadCurve();
    }
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

    return Container(
      padding: const EdgeInsets.all(20),
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
                      Wrap(
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
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.playlist_add_rounded, size: 18),
                  label: const Text("Add to List"),
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _showAddToListDialog,
                ),
              ],
            ),

            const SizedBox(height: 18),

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
              child: Row(
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
            Row(
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
}
