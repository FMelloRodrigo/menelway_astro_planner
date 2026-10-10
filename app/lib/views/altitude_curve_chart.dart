import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/altitude_point.dart';
import '../models/filter_state.dart';
import '../models/night_summary.dart';
import '../theme/astro_theme.dart';
import '../l10n/app_localizations.dart';
import '../utils/astro_formatters.dart';
import '../widgets/painters/skyline_360_painter.dart';
import '../widgets/painters/altitude_timeline_painter.dart';

enum ChartViewMode {
  skyline360,
  timeline,
}

class AltitudeCurveChart extends StatefulWidget {
  final List<AltitudePoint> targetPoints;
  final NightSummary night;
  final String targetName;
  final double minAltitudeThreshold;
  final double maxAltitudeThreshold;
  final bool isRedNightMode;
  final DateTime? customWindowStart;
  final DateTime? customWindowEnd;
  final FilterState? filterState;
  final DateTime? activeDate;
  final bool isDateOverridden;
  final ValueChanged<DateTime>? onDateChanged;
  final VoidCallback? onResetDate;

  const AltitudeCurveChart({
    super.key,
    required this.targetPoints,
    required this.night,
    required this.targetName,
    this.minAltitudeThreshold = 30.0,
    this.maxAltitudeThreshold = 90.0,
    this.isRedNightMode = false,
    this.customWindowStart,
    this.customWindowEnd,
    this.filterState,
    this.activeDate,
    this.isDateOverridden = false,
    this.onDateChanged,
    this.onResetDate,
  });

  @override
  State<AltitudeCurveChart> createState() => _AltitudeCurveChartState();
}

class _AltitudeCurveChartState extends State<AltitudeCurveChart> {
  ChartViewMode _viewMode = ChartViewMode.skyline360;

  // Zoom & Pan state
  double _zoomLevel = 1.0; // 1.0x to 6.0x
  double _viewStartFraction = 0.0; // 0.0 to (1.0 - 1.0 / _zoomLevel) for Timeline mode
  double _skylineCenterAz = 180.0; // Center azimuth for 360° Skyline mode (0.0 to 360.0)
  double? _hoverFraction; // 0.0 to 1.0 along the active domain
  bool _showHorizonSilhouette = true;

  double? _activeSkylineAzimuth;
  AltitudePoint? _activeTimelinePoint;

  double _baseZoomOnScaleStart = 1.0;

  @override
  void initState() {
    super.initState();
    _autoAlignSkyline();
  }

  @override
  void didUpdateWidget(covariant AltitudeCurveChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetName != widget.targetName || oldWidget.targetPoints != widget.targetPoints) {
      _autoAlignSkyline();
    }
  }

  void _autoAlignSkyline() {
    if (widget.targetPoints.isEmpty) return;
    AltitudePoint peak = widget.targetPoints.first;
    for (final p in widget.targetPoints) {
      if (p.altitude > peak.altitude) peak = p;
    }
    // If target culminates near North (azimuth < 60° or > 300°), automatically center on North (0°)
    // so the trajectory is beautifully centered and unbroken across the North boundary!
    if (peak.azimuth < 60.0 || peak.azimuth > 300.0) {
      _skylineCenterAz = 0.0;
    } else {
      _skylineCenterAz = 180.0;
    }
    _activeSkylineAzimuth = peak.azimuth;
    _activeTimelinePoint = peak;
  }

  void _centerOnTarget() {
    if (widget.targetPoints.isEmpty) return;
    AltitudePoint peak = widget.targetPoints.first;
    for (final p in widget.targetPoints) {
      if (p.altitude > peak.altitude) peak = p;
    }
    setState(() {
      _skylineCenterAz = peak.azimuth;
      _activeSkylineAzimuth = peak.azimuth;
      _activeTimelinePoint = peak;
    });
  }

  static String _cardinal(double az) => AstroFormatters.cardinalFromAzimuth(az);

  void _setZoom(double newZoom, {double? centerFrac}) {
    final clampedZoom = newZoom.clamp(1.0, 6.0);
    final oldSpan = 1.0 / _zoomLevel;
    final newSpan = 1.0 / clampedZoom;
    final center = centerFrac ?? (_viewStartFraction + oldSpan / 2.0);
    final newStart = (center - newSpan / 2.0).clamp(0.0, (1.0 - newSpan).clamp(0.0, 1.0));
    setState(() {
      _zoomLevel = clampedZoom;
      _viewStartFraction = clampedZoom <= 1.0 ? 0.0 : newStart;
    });
  }

  void _zoomIn() => _setZoom(_zoomLevel * 1.4);
  void _zoomOut() => _setZoom(_zoomLevel / 1.4);
  void _resetZoom() => setState(() {
        _zoomLevel = 1.0;
        _viewStartFraction = 0.0;
      });

  void _jumpToTime(DateTime targetTime) {
    if (widget.targetPoints.isEmpty) return;
    if (_zoomLevel <= 1.0) {
      _zoomLevel = 1.8;
    }
    final startTime = widget.targetPoints.first.time;
    final endTime = widget.targetPoints.last.time;
    final totalDuration = endTime.difference(startTime).inSeconds;
    if (totalDuration <= 0) return;

    final targetSec = targetTime.difference(startTime).inSeconds;
    final targetFrac = (targetSec / totalDuration).clamp(0.0, 1.0);
    final span = 1.0 / _zoomLevel;
    final maxStart = (1.0 - span).clamp(0.0, 1.0);
    final newStart = (targetFrac - span / 2.0).clamp(0.0, maxStart);
    setState(() {
      _viewStartFraction = newStart;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AstroPalette.of(context);
    final textColor = palette.textPrimary;
    final accentColor = palette.accent;

    const chartCanvasHeight = 340.0;

    if (widget.targetPoints.isEmpty) {
      return Container(
        height: chartCanvasHeight,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: palette.border,
          ),
        ),
        child: Center(
          child: Text(
            l10n.noAltitudeData,
            style: const TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    final startTime = widget.targetPoints.first.time;
    final endTime = widget.targetPoints.last.time;
    final totalDurationSec = endTime.difference(startTime).inSeconds;

    final spanFrac = 1.0 / _zoomLevel;
    final viewStartFrac = _viewStartFraction.clamp(0.0, (1.0 - spanFrac).clamp(0.0, 1.0));
    final viewEndFrac = (viewStartFrac + spanFrac).clamp(0.0, 1.0);

    final visibleStartTime = startTime.add(Duration(seconds: (viewStartFrac * totalDurationSec).round()));
    final visibleEndTime = startTime.add(Duration(seconds: (viewEndFrac * totalDurationSec).round()));
    final visibleDurationSec = math.max(1, visibleEndTime.difference(visibleStartTime).inSeconds);

    final effectiveWindowStart = widget.customWindowStart ??
        ((widget.filterState?.useCustomTimeWindow == true)
            ? widget.filterState!.getWindowStart(widget.night.sunset)
            : null);
    final effectiveWindowEnd = widget.customWindowEnd ??
        ((widget.filterState?.useCustomTimeWindow == true)
            ? widget.filterState!.getWindowEnd(widget.night.sunset)
            : null);

    // Identify peak / culmination transit point
    AltitudePoint peakPoint = widget.targetPoints.first;
    for (final p in widget.targetPoints) {
      if (p.altitude > peakPoint.altitude) peakPoint = p;
    }

    final hasHorizon = widget.filterState != null && widget.filterState!.hasHorizon;

    double minAz = 360.0;
    double maxAz = 0.0;
    for (final p in widget.targetPoints) {
      if (p.azimuth < minAz) minAz = p.azimuth;
      if (p.azimuth > maxAz) maxAz = p.azimuth;
    }
    if (minAz > maxAz) {
      minAz = 0.0;
      maxAz = 360.0;
    }

    double minHAlt = 90.0;
    double maxHAlt = 0.0;
    if (hasHorizon) {
      for (final p in widget.targetPoints) {
        final h = widget.filterState!.getHorizonAltitudeAt(p.azimuth);
        if (h < minHAlt) minHAlt = h;
        if (h > maxHAlt) maxHAlt = h;
      }
      if (minHAlt > maxHAlt) {
        minHAlt = 0.0;
        maxHAlt = 0.0;
      }
    }
    // Active/inspected point and azimuth lookup depending on current mode (persists across hover)
    double? hoveredAzimuth;
    double? hoveredRidgeAlt;
    AltitudePoint? hoveredPoint;
    double? hoveredClearance;
    bool isHoveredOccluded = false;
    bool isTargetTrajectoryNear = false;

    if (_viewMode == ChartViewMode.skyline360) {
      final visibleAzSpan = 360.0 / _zoomLevel;
      final startAz = ((_skylineCenterAz - visibleAzSpan / 2.0) % 360.0 + 360.0) % 360.0;

      if (_hoverFraction != null) {
        final rawHoveredAz = startAz + _hoverFraction! * visibleAzSpan;
        _activeSkylineAzimuth = ((rawHoveredAz % 360.0) + 360.0) % 360.0;
      }

      final az = _activeSkylineAzimuth ?? peakPoint.azimuth;
      hoveredAzimuth = az;

      if (hasHorizon) {
        hoveredRidgeAlt = widget.filterState!.getHorizonAltitudeAt(az);
      }

      if (widget.targetPoints.isNotEmpty) {
        int bestIdx = 0;
        double bestDiff = double.infinity;
        for (int i = 0; i < widget.targetPoints.length; i++) {
          double diff = (widget.targetPoints[i].azimuth - az).abs();
          if (diff > 180.0) diff = 360.0 - diff;
          if (diff < bestDiff) {
            bestDiff = diff;
            bestIdx = i;
          }
        }
        hoveredPoint = widget.targetPoints[bestIdx];
        isTargetTrajectoryNear = bestDiff <= 18.0;

        if (hasHorizon) {
          final targetRidge = widget.filterState!.getHorizonAltitudeAt(hoveredPoint.azimuth);
          hoveredClearance = hoveredPoint.altitude - targetRidge;
          isHoveredOccluded = hoveredPoint.altitude < targetRidge;
        }
      }
    } else {
      // In timeline mode
      if (_hoverFraction != null) {
        final hoveredSec = (_hoverFraction! * visibleDurationSec).round();
        final hoveredTime = visibleStartTime.add(Duration(seconds: hoveredSec));

        int bestIdx = 0;
        int bestDiff = 999999999;
        for (int i = 0; i < widget.targetPoints.length; i++) {
          final diff = (widget.targetPoints[i].time.difference(hoveredTime).inSeconds).abs();
          if (diff < bestDiff) {
            bestDiff = diff;
            bestIdx = i;
          }
        }
        _activeTimelinePoint = widget.targetPoints[bestIdx];
      }

      hoveredPoint = _activeTimelinePoint ?? peakPoint;
      hoveredAzimuth = hoveredPoint.azimuth;
      isTargetTrajectoryNear = true;

      if (hasHorizon) {
        hoveredRidgeAlt = widget.filterState!.getHorizonAltitudeAt(hoveredPoint.azimuth);
        hoveredClearance = hoveredPoint.altitude - hoveredRidgeAlt;
        isHoveredOccluded = hoveredPoint.altitude < hoveredRidgeAlt;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 720;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar: Title, Mode Segment, Horizon Toggle, Zoom Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth - 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _viewMode == ChartViewMode.skyline360
                              ? Icons.landscape_rounded
                              : Icons.show_chart_rounded,
                          size: 18,
                          color: accentColor,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _viewMode == ChartViewMode.skyline360
                                ? (isNarrow ? "Skyline: ${widget.targetName}" : "Skyline (0°–360° NWES): ${widget.targetName}")
                                : (l10n.altitudeVsTimeTarget(widget.targetName)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: palette.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // View Mode Toggle (360° Skyline NWES vs. Timeline Hours)
                  Container(
                    height: 28,
                    decoration: BoxDecoration(
                      color: palette.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: palette.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _modeButton(
                          label: isNarrow ? "360° Skyline" : "360° Skyline (NWES)",
                          icon: Icons.landscape_rounded,
                          isSelected: _viewMode == ChartViewMode.skyline360,
                          onTap: () => setState(() {
                            _viewMode = ChartViewMode.skyline360;
                            _resetZoom();
                          }),
                          accentColor: accentColor,
                          textColor: textColor,
                        ),
                        Container(
                          width: 1,
                          height: 16,
                          color: palette.border,
                        ),
                        _modeButton(
                          label: isNarrow ? "Timeline" : "Timeline (Hours)",
                          icon: Icons.schedule_rounded,
                          isSelected: _viewMode == ChartViewMode.timeline,
                          onTap: () => setState(() {
                            _viewMode = ChartViewMode.timeline;
                            _resetZoom();
                          }),
                          accentColor: accentColor,
                          textColor: textColor,
                        ),
                      ],
                    ),
                  ),

                  // Horizon Silhouette Toggle (if horizon exists)
                  if (hasHorizon) ...[
                    FilterChip(
                      selected: _showHorizonSilhouette,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      label: Text(
                        _showHorizonSilhouette ? "Horizon: ON" : "Horizon: OFF",
                        style: TextStyle(fontSize: 10, color: textColor),
                      ),
                      avatar: Icon(
                        Icons.terrain_rounded,
                        size: 13,
                        color: accentColor,
                      ),
                      selectedColor: accentColor.withValues(alpha: 0.25),
                      onSelected: (val) => setState(() => _showHorizonSilhouette = val),
                    ),
                  ],

                  // Date Navigation & Temporary Override Control
                  _buildDateSelector(context, palette, accentColor, textColor, l10n),

                  // Zoom Controls (Buttons only - scroll wheel zoom removed to enable page scrolling)
                  Container(
                    decoration: BoxDecoration(
                      color: palette.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: palette.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: _zoomOut,
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Icon(Icons.zoom_out_rounded, size: 14, color: textColor.withValues(alpha: 0.8)),
                          ),
                        ),
                        InkWell(
                          onTap: _resetZoom,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Text(
                              "${_zoomLevel.toStringAsFixed(1)}x",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                color: _zoomLevel > 1.0 ? accentColor : textColor.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: _zoomIn,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Icon(Icons.zoom_in_rounded, size: 14, color: textColor.withValues(alpha: 0.8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Persistent Scrubber / Inspection Info Bar
            if (hoveredPoint != null || hoveredAzimuth != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: palette.surfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: palette.border,
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_viewMode == ChartViewMode.skyline360 && hoveredAzimuth != null) ...[
                          Icon(Icons.explore_rounded, size: 13, color: accentColor),
                          const SizedBox(width: 4),
                          Text(
                            "Az: ${hoveredAzimuth.toStringAsFixed(0)}° (${_cardinal(hoveredAzimuth)})",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: accentColor,
                            ),
                          ),
                          if (hasHorizon && _showHorizonSilhouette && hoveredRidgeAlt != null) ...[
                            const SizedBox(width: 10),
                            Container(width: 1, height: 12, color: textColor.withValues(alpha: 0.2)),
                            const SizedBox(width: 10),
                            Icon(Icons.landscape_rounded, size: 13, color: Colors.amberAccent),
                            const SizedBox(width: 4),
                            Text(
                              "Mountain Ridge: ${hoveredRidgeAlt.toStringAsFixed(1)}°",
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: textColor.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                          if (hoveredPoint != null) ...[
                            const SizedBox(width: 10),
                            Container(width: 1, height: 12, color: textColor.withValues(alpha: 0.2)),
                            const SizedBox(width: 10),
                            Icon(
                              Icons.star_rounded,
                              size: 13,
                              color: isTargetTrajectoryNear ? accentColor : textColor.withValues(alpha: 0.45),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isTargetTrajectoryNear
                                  ? "Target: ${hoveredPoint.altitude.toStringAsFixed(1)}° @ ${DateFormat('HH:mm').format(hoveredPoint.time)}"
                                  : "Target: ${hoveredPoint.altitude.toStringAsFixed(1)}° (Az ${hoveredPoint.azimuth.toStringAsFixed(0)}°)",
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                fontWeight: isTargetTrajectoryNear ? FontWeight.bold : FontWeight.normal,
                                color: isTargetTrajectoryNear ? textColor : textColor.withValues(alpha: 0.6),
                              ),
                            ),
                            if (effectiveWindowStart != null &&
                                effectiveWindowEnd != null &&
                                !hoveredPoint.time.isBefore(effectiveWindowStart) &&
                                !hoveredPoint.time.isAfter(effectiveWindowEnd)) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: accentColor.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  l10n.observingWindowLabel.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                            ],
                            if (hasHorizon && _showHorizonSilhouette && hoveredClearance != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isHoveredOccluded
                                      ? Colors.redAccent.withValues(alpha: 0.2)
                                      : Colors.greenAccent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isHoveredOccluded
                                        ? Colors.redAccent.withValues(alpha: 0.5)
                                        : Colors.greenAccent.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  isHoveredOccluded
                                      ? "Occluded (-${(-hoveredClearance).toStringAsFixed(1)}°)"
                                      : "Clear (+${hoveredClearance.toStringAsFixed(1)}°)",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isHoveredOccluded ? Colors.redAccent : Colors.greenAccent,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ] else if (hoveredPoint != null) ...[
                          Icon(Icons.schedule_rounded, size: 13, color: accentColor),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('HH:mm').format(hoveredPoint.time),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: textColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "Az: ${hoveredPoint.azimuth.toStringAsFixed(0)}° (${_cardinal(hoveredPoint.azimuth)})",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "Alt: ${hoveredPoint.altitude.toStringAsFixed(1)}°",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                              color: hoveredPoint.altitude >= widget.minAltitudeThreshold
                                  ? accentColor
                                  : textColor.withValues(alpha: 0.7),
                            ),
                          ),
                          if (hasHorizon && _showHorizonSilhouette && hoveredRidgeAlt != null) ...[
                            const SizedBox(width: 10),
                            Container(width: 1, height: 12, color: textColor.withValues(alpha: 0.2)),
                            const SizedBox(width: 10),
                            Icon(Icons.landscape_rounded, size: 13, color: isHoveredOccluded ? Colors.amberAccent : accentColor),
                            const SizedBox(width: 4),
                            Text(
                              "Mountain Ridge: ${hoveredRidgeAlt.toStringAsFixed(1)}°",
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: textColor.withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: isHoveredOccluded
                                    ? Colors.redAccent.withValues(alpha: 0.2)
                                    : Colors.greenAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: isHoveredOccluded
                                      ? Colors.redAccent.withValues(alpha: 0.5)
                                      : Colors.greenAccent.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                isHoveredOccluded
                                    ? "Occluded (-${(-hoveredClearance!).toStringAsFixed(1)}°)"
                                    : "Clear (+${(hoveredClearance ?? 0).toStringAsFixed(1)}°)",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isHoveredOccluded ? Colors.redAccent : Colors.greenAccent,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 10),
                          Container(width: 1, height: 12, color: textColor.withValues(alpha: 0.2)),
                          const SizedBox(width: 10),
                          Text(
                            l10n.moonSeparationShort(hoveredPoint.moonSeparation.toStringAsFixed(0)),
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: textColor.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 4),

            // Main Interactive Chart Canvas with Pan, Drag, and Touch Gestures
            // Note: Mouse scroll wheel zoom is intentionally excluded to allow natural sheet scrolling.
            GestureDetector(
              onScaleStart: (details) {
                _baseZoomOnScaleStart = _zoomLevel;
              },
              onScaleUpdate: (details) {
                if (details.scale != 1.0) {
                  // Pinch to zoom
                  _setZoom(_baseZoomOnScaleStart * details.scale);
                } else if (_viewMode == ChartViewMode.skyline360) {
                  // In Skyline 360 mode, drag to continuously rotate the horizon at any zoom level!
                  final visibleAzSpan = 360.0 / _zoomLevel;
                  final deltaAz = -details.focalPointDelta.dx / constraints.maxWidth * visibleAzSpan;
                  setState(() {
                    _skylineCenterAz = ((_skylineCenterAz + deltaAz) % 360.0 + 360.0) % 360.0;
                  });
                } else if (_zoomLevel > 1.0) {
                  // In Timeline mode, drag to pan viewport
                  final dxFrac = -details.focalPointDelta.dx / constraints.maxWidth * spanFrac;
                  final maxStart = (1.0 - spanFrac).clamp(0.0, 1.0);
                  setState(() {
                    _viewStartFraction = (_viewStartFraction + dxFrac).clamp(0.0, maxStart);
                  });
                } else {
                  // Drag to scrub line
                  final localX = details.localFocalPoint.dx.clamp(0.0, constraints.maxWidth);
                  setState(() {
                    _hoverFraction = localX / constraints.maxWidth;
                  });
                }
              },
              onDoubleTap: () {
                if (_viewMode == ChartViewMode.skyline360) {
                  _centerOnTarget();
                } else {
                  _resetZoom();
                }
              },
              onTapDown: (details) {
                final localX = details.localPosition.dx.clamp(0.0, constraints.maxWidth);
                setState(() {
                  _hoverFraction = localX / constraints.maxWidth;
                });
              },
              child: MouseRegion(
                onHover: (event) {
                  final localX = event.localPosition.dx.clamp(0.0, constraints.maxWidth);
                  setState(() {
                    _hoverFraction = localX / constraints.maxWidth;
                  });
                },
                onExit: (_) => setState(() => _hoverFraction = null),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: chartCanvasHeight,
                    decoration: BoxDecoration(
                      color: palette.surface,
                      border: Border.all(
                        color: palette.border,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CustomPaint(
                      size: Size(constraints.maxWidth, chartCanvasHeight),
                      painter: _viewMode == ChartViewMode.skyline360
                          ? Skyline360Painter(
                              points: widget.targetPoints,
                              filterState: widget.filterState,
                              showHorizonSilhouette: _showHorizonSilhouette,
                              minAltitudeThreshold: widget.minAltitudeThreshold,
                              maxAltitudeThreshold: widget.maxAltitudeThreshold,
                              hoverFraction: _hoverFraction,
                              isRedNightMode: widget.isRedNightMode,
                              zoomLevel: _zoomLevel,
                              centerAzimuth: _skylineCenterAz,
                              customWindowStart: effectiveWindowStart,
                              customWindowEnd: effectiveWindowEnd,
                              l10n: l10n,
                            )
                          : AltitudeTimelinePainter(
                              points: widget.targetPoints,
                              night: widget.night,
                              minAltitudeThreshold: widget.minAltitudeThreshold,
                              maxAltitudeThreshold: widget.maxAltitudeThreshold,
                              hoverFraction: _hoverFraction,
                              isRedNightMode: widget.isRedNightMode,
                              visibleStartTime: visibleStartTime,
                              visibleEndTime: visibleEndTime,
                              totalStartTime: startTime,
                              totalEndTime: endTime,
                              customWindowStart: effectiveWindowStart,
                              customWindowEnd: effectiveWindowEnd,
                              filterState: widget.filterState,
                              showHorizonSilhouette: _showHorizonSilhouette,
                              l10n: l10n,
                            ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Controls Bar:
            // In Skyline 360 mode: Always visible panorama rotation and centering toolbar
            // In Timeline mode: Visible when zoomed in to scrub time viewport
            if (_viewMode == ChartViewMode.skyline360) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: palette.border,
                  ),
                ),
                child: constraints.maxWidth < 640
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Center on Target Button
                            InkWell(
                              onTap: _centerOnTarget,
                              borderRadius: BorderRadius.circular(5),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(color: accentColor.withValues(alpha: 0.45)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.filter_center_focus_rounded, size: 13, color: accentColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Center on Target",
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: accentColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Current Center indicator
                            Icon(Icons.explore_rounded, size: 13, color: accentColor),
                            const SizedBox(width: 4),
                            Text(
                              "Center: ${_skylineCenterAz.round()}° (${_cardinal(_skylineCenterAz)})",
                              style: TextStyle(
                                fontSize: 10.5,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Panorama Rotation Slider
                            SizedBox(
                              width: 130,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                ),
                                child: Slider(
                                  value: _skylineCenterAz.clamp(0.0, 360.0),
                                  min: 0.0,
                                  max: 360.0,
                                  activeColor: accentColor,
                                  onChanged: (val) => setState(() => _skylineCenterAz = val % 360.0),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Quick Cardinal Presets
                            _quickCenterPresetBtn("N", 0.0, accentColor, textColor),
                            _quickCenterPresetBtn("E", 90.0, accentColor, textColor),
                            _quickCenterPresetBtn("S", 180.0, accentColor, textColor),
                            _quickCenterPresetBtn("W", 270.0, accentColor, textColor),
                          ],
                        ),
                      )
                    : Row(
                        children: [
                          // Center on Target Button
                          InkWell(
                            onTap: _centerOnTarget,
                            borderRadius: BorderRadius.circular(5),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: accentColor.withValues(alpha: 0.45)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.filter_center_focus_rounded, size: 13, color: accentColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Center on Target",
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: accentColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Current Center indicator
                          Icon(Icons.explore_rounded, size: 13, color: accentColor),
                          const SizedBox(width: 4),
                          Text(
                            "Center: ${_skylineCenterAz.round()}° (${_cardinal(_skylineCenterAz)})",
                            style: TextStyle(
                              fontSize: 10.5,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Panorama Rotation Slider
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              ),
                              child: Slider(
                                value: _skylineCenterAz.clamp(0.0, 360.0),
                                min: 0.0,
                                max: 360.0,
                                activeColor: accentColor,
                                onChanged: (val) => setState(() => _skylineCenterAz = val % 360.0),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Quick Cardinal Presets
                          _quickCenterPresetBtn("N", 0.0, accentColor, textColor),
                          _quickCenterPresetBtn("E", 90.0, accentColor, textColor),
                          _quickCenterPresetBtn("S", 180.0, accentColor, textColor),
                          _quickCenterPresetBtn("W", 270.0, accentColor, textColor),
                        ],
                      ),
              ),
            ] else if (_zoomLevel > 1.0) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: palette.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.pan_tool_alt_rounded, size: 14, color: accentColor),
                    const SizedBox(width: 6),
                    Text(
                      "${DateFormat('HH:mm').format(visibleStartTime)} – ${DateFormat('HH:mm').format(visibleEndTime)}",
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        ),
                        child: Slider(
                          value: _viewStartFraction.clamp(0.0, (1.0 - spanFrac).clamp(0.0, 1.0)),
                          min: 0.0,
                          max: (1.0 - spanFrac).clamp(0.0, 1.0),
                          activeColor: accentColor,
                          onChanged: (val) => setState(() => _viewStartFraction = val),
                        ),
                      ),
                    ),
                    if (!isNarrow) ...[
                      const SizedBox(width: 6),
                      _quickJumpBtn("Sunset", widget.night.sunset, accentColor),
                      _quickJumpBtn("Dusk", widget.night.astronomicalDusk, accentColor),
                      _quickJumpBtn("Transit", peakPoint.time, accentColor),
                      _quickJumpBtn("Dawn", widget.night.astronomicalDawn, accentColor),
                      _quickJumpBtn("Sunrise", widget.night.sunrise, accentColor),
                    ] else ...[
                      const SizedBox(width: 4),
                      _quickJumpBtn("Transit", peakPoint.time, accentColor),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDateSelector(
    BuildContext context,
    AstroPalette palette,
    Color accentColor,
    Color textColor,
    AppLocalizations l10n,
  ) {
    final effectiveDate = widget.activeDate ?? widget.night.sunset;
    final isOverridden = widget.isDateOverridden;

    if (widget.onDateChanged == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Text(
          DateFormat('MMM d').format(widget.night.sunset),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: accentColor,
          ),
        ),
      );
    }

    final yearSuffix = effectiveDate.year != widget.night.sunset.year ? ', ${effectiveDate.year}' : '';
    final dateStr = '${DateFormat('MMM d').format(effectiveDate)}$yearSuffix';
    final sessionDateStr = DateFormat('MMM d').format(widget.night.sunset);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 28,
          decoration: BoxDecoration(
            color: isOverridden
                ? Colors.amber.withValues(alpha: 0.14)
                : palette.surfaceVariant,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isOverridden
                  ? Colors.amber.withValues(alpha: 0.65)
                  : palette.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Previous Day
              Tooltip(
                message: l10n.previousDay,
                child: InkWell(
                  onTap: () => _stepDate(-1),
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 16,
                      color: isOverridden ? Colors.amberAccent : textColor.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 16,
                color: isOverridden ? Colors.amber.withValues(alpha: 0.35) : palette.border,
              ),
              // Date picker button
              Tooltip(
                message: isOverridden
                    ? l10n.temporaryTrajectoryDateNotice(dateStr)
                    : l10n.pickTrajectoryDate,
                child: InkWell(
                  onTap: () => _pickDate(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 12,
                          color: isOverridden ? Colors.amberAccent : accentColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: isOverridden ? Colors.amberAccent : textColor,
                          ),
                        ),
                        if (isOverridden) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              "TEMP",
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: Colors.amberAccent,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 16,
                color: isOverridden ? Colors.amber.withValues(alpha: 0.35) : palette.border,
              ),
              // Next Day
              Tooltip(
                message: l10n.nextDay,
                child: InkWell(
                  onTap: () => _stepDate(1),
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(5)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: isOverridden ? Colors.amberAccent : textColor.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Reset to Today button (only visible when overridden)
        if (isOverridden && widget.onResetDate != null) ...[
          const SizedBox(width: 4),
          Tooltip(
            message: l10n.resetToTodayTooltip(sessionDateStr),
            child: InkWell(
              onTap: widget.onResetDate,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.surfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: palette.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.restart_alt_rounded,
                      size: 13,
                      color: accentColor,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      l10n.resetToToday,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _stepDate(int days) {
    final effectiveDate = widget.activeDate ?? widget.night.sunset;
    final newDate = effectiveDate.add(Duration(days: days));
    widget.onDateChanged?.call(newDate);
  }

  Future<void> _pickDate(BuildContext context) async {
    final effectiveDate = widget.activeDate ?? widget.night.sunset;
    final picked = await showDatePicker(
      context: context,
      initialDate: effectiveDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: widget.isRedNightMode ? AstroTheme.redNightVisionTheme() : AstroTheme.darkTheme(),
          child: child!,
        );
      },
    );
    if (picked != null) {
      widget.onDateChanged?.call(picked);
    }
  }

  Widget _modeButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color accentColor,
    required Color textColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: isSelected ? accentColor : textColor.withValues(alpha: 0.6)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? accentColor : textColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickJumpBtn(String label, DateTime time, Color accentColor) {
    return InkWell(
      onTap: () => _jumpToTime(time),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
      ),
    );
  }

  Widget _quickCenterPresetBtn(String label, double centerAz, Color accentColor, Color textColor) {
    final isSelected = (_skylineCenterAz - centerAz).abs() < 1.0;
    return InkWell(
      onTap: () => setState(() => _skylineCenterAz = centerAz),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.3) : accentColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isSelected ? accentColor : accentColor.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: isSelected ? textColor : accentColor,
          ),
        ),
      ),
    );
  }
}
