import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../models/altitude_point.dart';
import '../models/filter_state.dart';
import '../models/night_summary.dart';
import '../theme/astro_theme.dart';
import '../l10n/app_localizations.dart';

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
  });

  @override
  State<AltitudeCurveChart> createState() => _AltitudeCurveChartState();
}

class _AltitudeCurveChartState extends State<AltitudeCurveChart> {
  ChartViewMode _viewMode = ChartViewMode.skyline360;

  // Zoom & Pan state
  double _zoomLevel = 1.0; // 1.0x to 6.0x
  double _viewStartFraction = 0.0; // 0.0 to (1.0 - 1.0 / _zoomLevel)
  double? _hoverFraction; // 0.0 to 1.0 along the active domain
  bool _showHorizonSilhouette = true;

  double _baseZoomOnScaleStart = 1.0;

  static String _cardinal(double az) {
    final a = ((az % 360) + 360) % 360;
    if (a >= 337.5 || a < 22.5) return "N";
    if (a < 67.5) return "NE";
    if (a < 112.5) return "E";
    if (a < 157.5) return "SE";
    if (a < 202.5) return "S";
    if (a < 247.5) return "SW";
    if (a < 292.5) return "W";
    return "NW";
  }

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

  void _jumpToAzimuth(double targetAz) {
    if (_zoomLevel <= 1.0) {
      _zoomLevel = 1.8;
    }
    final span = 1.0 / _zoomLevel;
    final normalizedAz = targetAz == 360.0 ? 360.0 : ((targetAz % 360.0) + 360.0) % 360.0;
    final targetFrac = (normalizedAz / 360.0).clamp(0.0, 1.0);
    final maxStart = (1.0 - span).clamp(0.0, 1.0);
    final newStart = (targetFrac - span / 2.0).clamp(0.0, maxStart);
    setState(() {
      _viewStartFraction = newStart;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;

    const chartCanvasHeight = 340.0;

    if (widget.targetPoints.isEmpty) {
      return Container(
        height: chartCanvasHeight,
        decoration: BoxDecoration(
          color: widget.isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder,
          ),
        ),
        child: Center(
          child: Text(
            l10n?.noAltitudeData ?? "No altitude data available for window",
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

    // Hovered point and azimuth lookup depending on current mode
    double? hoveredAzimuth;
    double? hoveredRidgeAlt;
    AltitudePoint? hoveredPoint;
    double? hoveredClearance;
    bool isHoveredOccluded = false;
    bool isTargetTrajectoryNear = false;

    if (_hoverFraction != null) {
      if (_viewMode == ChartViewMode.skyline360) {
        final visibleAzSpan = 360.0 / _zoomLevel;
        final viewStartAz = viewStartFrac * 360.0;
        final rawHoveredAz = viewStartAz + _hoverFraction! * visibleAzSpan;
        final az = ((rawHoveredAz % 360.0) + 360.0) % 360.0;
        hoveredAzimuth = az;

        if (hasHorizon) {
          hoveredRidgeAlt = widget.filterState!.getHorizonAltitudeAt(az);
        }

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

        if (hasHorizon && hoveredRidgeAlt != null) {
          hoveredClearance = hoveredPoint.altitude - hoveredRidgeAlt;
          isHoveredOccluded = hoveredPoint.altitude < hoveredRidgeAlt;
        }
      } else {
        // In timeline mode, find point closest to hovered time
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
        hoveredPoint = widget.targetPoints[bestIdx];
        hoveredAzimuth = hoveredPoint.azimuth;
        isTargetTrajectoryNear = true;

        if (hasHorizon) {
          hoveredRidgeAlt = widget.filterState!.getHorizonAltitudeAt(hoveredPoint.azimuth);
          hoveredClearance = hoveredPoint.altitude - hoveredRidgeAlt;
          isHoveredOccluded = hoveredPoint.altitude < hoveredRidgeAlt;
        }
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
                  Row(
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
                      Text(
                        _viewMode == ChartViewMode.skyline360
                            ? "Skyline (0°–360° NWES): ${widget.targetName}"
                            : (l10n?.altitudeVsTimeTarget(widget.targetName) ?? "Altitude vs. Time: ${widget.targetName}"),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white70,
                        ),
                      ),
                    ],
                  ),

                  // View Mode Toggle (360° Skyline NWES vs. Timeline Hours)
                  Container(
                    height: 28,
                    decoration: BoxDecoration(
                      color: widget.isRedNightMode
                          ? AstroColors.nightVisionSurfaceVariant
                          : AstroColors.spaceDarkSurfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _modeButton(
                          label: "360° Skyline (NWES)",
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
                          color: widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder,
                        ),
                        _modeButton(
                          label: "Timeline (Hours)",
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

                  // Date Badge
                  Container(
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
                  ),

                  // Zoom Controls (Buttons only - scroll wheel zoom removed to enable page scrolling)
                  Container(
                    decoration: BoxDecoration(
                      color: widget.isRedNightMode
                          ? AstroColors.nightVisionSurfaceVariant
                          : AstroColors.spaceDarkSurfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder,
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

            // Live Scrubber / Hover Info Bar
            if (_hoverFraction != null && (hoveredPoint != null || hoveredAzimuth != null)) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.isRedNightMode
                        ? AstroColors.nightVisionSurfaceVariant
                        : AstroColors.spaceDarkSurfaceVariant,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder,
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
                            if (isTargetTrajectoryNear && hasHorizon && _showHorizonSilhouette && hoveredRidgeAlt != null && hoveredClearance != null) ...[
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
                            l10n?.moonSeparationShort(hoveredPoint.moonSeparation.toStringAsFixed(0)) ??
                                "Moon: ${hoveredPoint.moonSeparation.toStringAsFixed(0)}°",
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
                } else if (_zoomLevel > 1.0) {
                  // Drag to pan viewport
                  final dxFrac = -details.focalPointDelta.dx / constraints.maxWidth * spanFrac;
                  final maxStart = 1.0 - spanFrac;
                  setState(() {
                    _viewStartFraction = (_viewStartFraction + dxFrac).clamp(0.0, maxStart.clamp(0.0, 1.0));
                  });
                } else {
                  // Drag to scrub line
                  final localX = details.localFocalPoint.dx.clamp(0.0, constraints.maxWidth);
                  setState(() {
                    _hoverFraction = localX / constraints.maxWidth;
                  });
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
                      color: widget.isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface,
                      border: Border.all(
                        color: widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CustomPaint(
                      size: Size(constraints.maxWidth, chartCanvasHeight),
                      painter: _viewMode == ChartViewMode.skyline360
                          ? _Skyline360Painter(
                              points: widget.targetPoints,
                              filterState: widget.filterState,
                              showHorizonSilhouette: _showHorizonSilhouette,
                              minAltitudeThreshold: widget.minAltitudeThreshold,
                              maxAltitudeThreshold: widget.maxAltitudeThreshold,
                              hoverFraction: _hoverFraction,
                              isRedNightMode: widget.isRedNightMode,
                              zoomLevel: _zoomLevel,
                              viewStartFraction: viewStartFrac,
                              l10n: l10n,
                            )
                          : _AltitudeChartPainter(
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
                              customWindowStart: widget.customWindowStart,
                              customWindowEnd: widget.customWindowEnd,
                              filterState: widget.filterState,
                              showHorizonSilhouette: _showHorizonSilhouette,
                              l10n: l10n,
                            ),
                    ),
                  ),
                ),
              ),
            ),

            // Viewport Scrubber Bar (visible when zoomed in)
            if (_zoomLevel > 1.0) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.isRedNightMode
                      ? AstroColors.nightVisionSurfaceVariant
                      : AstroColors.spaceDarkSurfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.pan_tool_alt_rounded, size: 14, color: accentColor),
                    const SizedBox(width: 6),
                    Text(
                      _viewMode == ChartViewMode.skyline360
                          ? "${(viewStartFrac * 360.0).round()}° (${_cardinal(viewStartFrac * 360.0)}) – ${(viewEndFrac * 360.0).round()}° (${_cardinal(viewEndFrac * 360.0)})"
                          : "${DateFormat('HH:mm').format(visibleStartTime)} – ${DateFormat('HH:mm').format(visibleEndTime)}",
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
                    if (_viewMode == ChartViewMode.skyline360) ...[
                      const SizedBox(width: 6),
                      _quickJumpAzBtn("Transit", peakPoint.azimuth, accentColor),
                      _quickJumpAzBtn("N", 0.0, accentColor),
                      _quickJumpAzBtn("E", 90.0, accentColor),
                      _quickJumpAzBtn("S", 180.0, accentColor),
                      _quickJumpAzBtn("W", 270.0, accentColor),
                      _quickJumpAzBtn("N (360°)", 360.0, accentColor),
                    ] else ...[
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
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
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
            color: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan,
          ),
        ),
      ),
    );
  }

  Widget _quickJumpAzBtn(String label, double az, Color accentColor) {
    return InkWell(
      onTap: () => _jumpToAzimuth(az),
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
            color: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan,
          ),
        ),
      ),
    );
  }
}

/// 360° Skyline (NWES) View Painter
/// Displays the full 360-degree mountain horizon silhouette (N -> E -> S -> W -> N)
/// with cardinal markers, the target's trajectory arc across the sky over the mountains,
/// and time waypoint tags.
class _Skyline360Painter extends CustomPainter {
  final List<AltitudePoint> points;
  final FilterState? filterState;
  final bool showHorizonSilhouette;
  final double minAltitudeThreshold;
  final double maxAltitudeThreshold;
  final double? hoverFraction;
  final bool isRedNightMode;
  final double zoomLevel;
  final double viewStartFraction;
  final AppLocalizations? l10n;

  _Skyline360Painter({
    required this.points,
    this.filterState,
    this.showHorizonSilhouette = true,
    required this.minAltitudeThreshold,
    required this.maxAltitudeThreshold,
    this.hoverFraction,
    required this.isRedNightMode,
    this.zoomLevel = 1.0,
    this.viewStartFraction = 0.0,
    this.l10n,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const bottomMargin = 28.0;

    final chartRect = Rect.fromLTWH(
      0,
      0,
      size.width,
      math.max(10.0, size.height - bottomMargin),
    );

    final visibleAzSpan = 360.0 / zoomLevel;
    final viewStartAz = viewStartFraction * 360.0;

    double azToX(double az) =>
        ((az - viewStartAz) / visibleAzSpan) * size.width;

    double altToY(double alt) =>
        chartRect.bottom - (alt.clamp(0.0, 90.0) / 90.0) * chartRect.height;

    canvas.save();
    canvas.clipRect(chartRect);

    // 1. Draw Horizontal Grid Lines (0°, 15°, 30°, 45°, 60°, 75°, 90°)
    final gridPaint = Paint()
      ..color = isRedNightMode
          ? AstroColors.nightVisionBorder.withValues(alpha: 0.4)
          : Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 1.0;

    final textStyle = TextStyle(
      color: isRedNightMode ? AstroColors.nightVisionRedDim : Colors.white30,
      fontSize: 9,
    );

    for (final alt in [0.0, 15.0, 30.0, 45.0, 60.0, 75.0, 90.0]) {
      final y = altToY(alt);
      if (alt == minAltitudeThreshold) {
        final threshPaint = Paint()
          ..color = isRedNightMode
              ? AstroColors.nightVisionRedDim.withValues(alpha: 0.7)
              : AstroColors.starGold.withValues(alpha: 0.4)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
        _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), threshPaint);
      } else {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }

      final textSpan = TextSpan(text: "${alt.toInt()}°", style: textStyle);
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(6, y - tp.height - 2));
    }

    // 2. Draw Vertical Azimuth Guidelines (at cardinal lines)
    final cardinalGridPaint = Paint()
      ..color = isRedNightMode
          ? AstroColors.nightVisionBorder.withValues(alpha: 0.25)
          : Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1.0;

    for (double az = 0.0; az <= 360.0; az += 45.0) {
      final x = azToX(az);
      if (x >= 0 && x <= size.width) {
        canvas.drawLine(Offset(x, 0), Offset(x, chartRect.bottom), cardinalGridPaint);
      }
    }

    // 3. Draw 360° Mountain Horizon Silhouette
    final hasHorizon = filterState != null && filterState!.hasHorizon;
    if (hasHorizon && showHorizonSilhouette) {
      _draw360Horizon(canvas, chartRect, azToX, altToY, visibleAzSpan, viewStartAz, size.width);
    }

    // 4. Draw Target Trajectory Path across the 360° Sky
    if (points.isNotEmpty) {
      _drawTargetTrajectory(canvas, chartRect, azToX, altToY, hasHorizon);
    }

    canvas.restore();

    // 5. Draw Cardinal Direction Markers on the Bottom Axis (N, NE, E, SE, S, SW, W, NW, N)
    _drawCardinalAxis(canvas, size, chartRect, azToX);

    // 6. Draw Interactive Cursor and Waypoint Highlights on Hover
    if (hoverFraction != null) {
      _drawHoverIndicator(canvas, chartRect, azToX, altToY, visibleAzSpan, viewStartAz, hasHorizon, size.width);
    }
  }

  void _draw360Horizon(
    Canvas canvas,
    Rect chartRect,
    double Function(double) azToX,
    double Function(double) altToY,
    double visibleAzSpan,
    double viewStartAz,
    double sizeWidth,
  ) {
    final horizonPath = Path();
    final horizonFillPath = Path();
    final numSteps = math.max(180, (sizeWidth / 2.0).round());

    bool first = true;
    for (int i = 0; i <= numSteps; i++) {
      final frac = i / numSteps;
      final az = viewStartAz + frac * visibleAzSpan;
      final hAlt = filterState!.getHorizonAltitudeAt(az);
      final x = frac * sizeWidth;
      final y = altToY(hAlt);

      if (first) {
        horizonPath.moveTo(x, y);
        horizonFillPath.moveTo(x, chartRect.bottom);
        horizonFillPath.lineTo(x, y);
        first = false;
      } else {
        horizonPath.lineTo(x, y);
        horizonFillPath.lineTo(x, y);
      }
    }

    horizonFillPath.lineTo(sizeWidth, chartRect.bottom);
    horizonFillPath.close();

    final mountainGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isRedNightMode
          ? [
              const Color(0xFF380808).withValues(alpha: 0.88),
              const Color(0xFF140202).withValues(alpha: 0.96),
            ]
          : [
              const Color(0xFF16253B).withValues(alpha: 0.90),
              const Color(0xFF070E1A).withValues(alpha: 0.97),
            ],
    );

    canvas.drawPath(horizonFillPath, Paint()..shader = mountainGradient.createShader(chartRect)..style = PaintingStyle.fill);

    final ridgePaint = Paint()
      ..color = isRedNightMode
          ? AstroColors.nightVisionRed.withValues(alpha: 0.75)
          : const Color(0xFF38BDF8).withValues(alpha: 0.85)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(horizonPath, ridgePaint);
  }

  void _drawTargetTrajectory(
    Canvas canvas,
    Rect chartRect,
    double Function(double) azToX,
    double Function(double) altToY,
    bool hasHorizon,
  ) {
    // 1. Separate path into continuous segments (handling 0/360 wrap-around)
    final segments = <List<AltitudePoint>>[];
    var currentSeg = <AltitudePoint>[points.first];

    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      if ((curr.azimuth - prev.azimuth).abs() > 180.0) {
        segments.add(currentSeg);
        currentSeg = <AltitudePoint>[curr];
      } else {
        currentSeg.add(curr);
      }
    }
    segments.add(currentSeg);

    // 2. Draw occluded background path (dim dashed) and visible path (bright solid)
    final occludedPaint = Paint()
      ..color = (isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan).withValues(alpha: 0.35)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final visiblePaint = Paint()
      ..color = isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final seg in segments) {
      if (seg.isEmpty) continue;
      final path = Path();
      path.moveTo(azToX(seg.first.azimuth), altToY(seg.first.altitude));
      for (int i = 1; i < seg.length; i++) {
        path.lineTo(azToX(seg[i].azimuth), altToY(seg[i].altitude));
      }
      canvas.drawPath(path, occludedPaint);

      final clearPath = Path();
      bool inClear = false;

      for (int i = 0; i < seg.length; i++) {
        final p = seg[i];
        final hAlt = (hasHorizon && showHorizonSilhouette)
            ? filterState!.getHorizonAltitudeAt(p.azimuth)
            : 0.0;
        final isClear = p.altitude >= hAlt;
        final x = azToX(p.azimuth);
        final y = altToY(p.altitude);

        if (isClear) {
          if (!inClear) {
            clearPath.moveTo(x, y);
            inClear = true;
          } else {
            clearPath.lineTo(x, y);
          }
        } else {
          inClear = false;
        }
      }
      canvas.drawPath(clearPath, visiblePaint);
    }

    // 3. Mark Peak / Transit Point
    AltitudePoint peak = points.first;
    for (final p in points) {
      if (p.altitude > peak.altitude) peak = p;
    }
    final peakX = azToX(peak.azimuth);
    final peakY = altToY(peak.altitude);

    if (peakX >= chartRect.left && peakX <= chartRect.right) {
      canvas.drawCircle(Offset(peakX, peakY), 5.0, Paint()..color = (isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starGold));
      canvas.drawCircle(
        Offset(peakX, peakY),
        8.0,
        Paint()
          ..color = (isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starGold).withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // 4. Draw Waypoint Time Labels along the trajectory (every ~2 hours)
    final stepIdx = math.max(1, (points.length / 7).round());
    for (int i = 0; i < points.length; i += stepIdx) {
      final p = points[i];
      final wx = azToX(p.azimuth);
      final wy = altToY(p.altitude);
      if (wx < chartRect.left || wx > chartRect.right) continue;

      canvas.drawCircle(Offset(wx, wy), 2.5, Paint()..color = Colors.white70);

      final timeStr = DateFormat('HH:mm').format(p.time);
      final tp = TextPainter(
        text: TextSpan(
          text: timeStr,
          style: TextStyle(
            fontSize: 8.5,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            color: isRedNightMode ? AstroColors.nightVisionRed : Colors.white70,
            backgroundColor: const Color(0xAA000000),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(wx - tp.width / 2.0, wy - tp.height - 4));
    }
  }

  void _drawCardinalAxis(
    Canvas canvas,
    Size size,
    Rect chartRect,
    double Function(double) azToX,
  ) {
    final cardinals = [
      (0.0, "N"),
      (45.0, "NE"),
      (90.0, "E"),
      (135.0, "SE"),
      (180.0, "S"),
      (225.0, "SW"),
      (270.0, "W"),
      (315.0, "NW"),
      (360.0, "N"),
    ];

    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 1.0;

    for (final c in cardinals) {
      final x = azToX(c.$1);
      if (x < -2 || x > size.width + 2) continue;

      canvas.drawLine(Offset(x, chartRect.bottom), Offset(x, chartRect.bottom + 5), tickPaint);

      final isMajor = c.$2 == "N" || c.$2 == "E" || c.$2 == "S" || c.$2 == "W";
      final span = TextSpan(
        text: "${c.$2}\n${c.$1.toInt()}°",
        style: TextStyle(
          fontSize: isMajor ? 9.5 : 8.0,
          fontWeight: isMajor ? FontWeight.bold : FontWeight.w500,
          fontFamily: 'monospace',
          height: 1.1,
          color: isMajor
              ? (isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan)
              : (isRedNightMode ? AstroColors.nightVisionRedDim : Colors.white54),
        ),
      );
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr, textAlign: TextAlign.center)..layout();
      final textX = (x - tp.width / 2.0).clamp(2.0, size.width - tp.width - 2.0);
      tp.paint(canvas, Offset(textX, chartRect.bottom + 6));
    }
  }

  void _drawHoverIndicator(
    Canvas canvas,
    Rect chartRect,
    double Function(double) azToX,
    double Function(double) altToY,
    double visibleAzSpan,
    double viewStartAz,
    bool hasHorizon,
    double sizeWidth,
  ) {
    final scrubX = (hoverFraction! * sizeWidth).clamp(0.0, sizeWidth);
    final rawHoveredAz = viewStartAz + hoverFraction! * visibleAzSpan;
    final hoveredAz = ((rawHoveredAz % 360.0) + 360.0) % 360.0;

    final guidePaint = Paint()
      ..color = (isRedNightMode ? AstroColors.nightVisionRed : Colors.white60)
      ..strokeWidth = 1.0;
    _drawDashedLine(canvas, Offset(scrubX, chartRect.top), Offset(scrubX, chartRect.bottom), guidePaint);

    if (hasHorizon && showHorizonSilhouette) {
      final hAlt = filterState!.getHorizonAltitudeAt(hoveredAz);
      final ry = altToY(hAlt);
      canvas.drawCircle(Offset(scrubX, ry), 4.5, Paint()..color = Colors.amberAccent);
      canvas.drawCircle(
        Offset(scrubX, ry),
        7.5,
        Paint()
          ..color = Colors.amberAccent.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    if (points.isNotEmpty) {
      int bestIdx = 0;
      double bestDiff = double.infinity;
      for (int i = 0; i < points.length; i++) {
        double diff = (points[i].azimuth - hoveredAz).abs();
        if (diff > 180.0) diff = 360.0 - diff;
        if (diff < bestDiff) {
          bestDiff = diff;
          bestIdx = i;
        }
      }
      final p = points[bestIdx];
      final isNear = bestDiff <= 18.0;
      final tx = azToX(p.azimuth);
      final ty = altToY(p.altitude);

      if (tx >= 0 && tx <= sizeWidth) {
        canvas.drawCircle(
          Offset(tx, ty),
          isNear ? 5.5 : 3.5,
          Paint()..color = (isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan).withValues(alpha: isNear ? 1.0 : 0.5),
        );
        if (isNear) {
          canvas.drawCircle(
            Offset(tx, ty),
            9.0,
            Paint()
              ..color = (isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan).withValues(alpha: 0.35)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        }
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double currentX = p1.dx;
    double currentY = p1.dy;
    final isHorizontal = (p1.dy - p2.dy).abs() < 1e-4;

    if (isHorizontal) {
      while (currentX < p2.dx) {
        canvas.drawLine(
          Offset(currentX, p1.dy),
          Offset(math.min(currentX + dashWidth, p2.dx), p1.dy),
          paint,
        );
        currentX += dashWidth + dashSpace;
      }
    } else {
      while (currentY < p2.dy) {
        canvas.drawLine(
          Offset(p1.dx, currentY),
          Offset(p1.dx, math.min(currentY + dashWidth, p2.dy)),
          paint,
        );
        currentY += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Skyline360Painter old) {
    return old.points != points ||
        old.filterState != filterState ||
        old.showHorizonSilhouette != showHorizonSilhouette ||
        old.hoverFraction != hoverFraction ||
        old.zoomLevel != zoomLevel ||
        old.viewStartFraction != viewStartFraction ||
        old.isRedNightMode != isRedNightMode;
  }
}

/// Classic Altitude vs. Time Chart Painter with Integrated Compass Directions
class _AltitudeChartPainter extends CustomPainter {
  final List<AltitudePoint> points;
  final NightSummary night;
  final double minAltitudeThreshold;
  final double maxAltitudeThreshold;
  final double? hoverFraction;
  final bool isRedNightMode;
  final DateTime visibleStartTime;
  final DateTime visibleEndTime;
  final DateTime totalStartTime;
  final DateTime totalEndTime;
  final DateTime? customWindowStart;
  final DateTime? customWindowEnd;
  final FilterState? filterState;
  final bool showHorizonSilhouette;
  final AppLocalizations? l10n;

  _AltitudeChartPainter({
    required this.points,
    required this.night,
    required this.minAltitudeThreshold,
    required this.maxAltitudeThreshold,
    required this.hoverFraction,
    required this.isRedNightMode,
    required this.visibleStartTime,
    required this.visibleEndTime,
    required this.totalStartTime,
    required this.totalEndTime,
    this.customWindowStart,
    this.customWindowEnd,
    this.filterState,
    this.showHorizonSilhouette = true,
    this.l10n,
  });

  static String _cardinal(double az) {
    final a = ((az % 360) + 360) % 360;
    if (a >= 337.5 || a < 22.5) return "N";
    if (a < 67.5) return "NE";
    if (a < 112.5) return "E";
    if (a < 157.5) return "SE";
    if (a < 202.5) return "S";
    if (a < 247.5) return "SW";
    if (a < 292.5) return "W";
    return "NW";
  }

  @override
  void paint(Canvas canvas, Size size) {
    const bottomMargin = 28.0;
    final chartRect = Rect.fromLTWH(0, 0, size.width, size.height - bottomMargin);
    final visibleDurationSec = visibleEndTime.difference(visibleStartTime).inSeconds;
    if (visibleDurationSec <= 0) return;

    double timeToX(DateTime t) {
      final sec = t.difference(visibleStartTime).inSeconds;
      return (sec / visibleDurationSec) * size.width;
    }

    double altToY(double altDeg) {
      final normalized = (altDeg.clamp(-10.0, 90.0) - (-10.0)) / 100.0;
      return chartRect.bottom - normalized * chartRect.height;
    }

    canvas.save();
    canvas.clipRect(chartRect);

    // 1. Draw Twilight bands
    _drawTwilightBands(canvas, chartRect, timeToX);

    // 1b. Draw Custom Observing Window Band (if set)
    _drawCustomWindowBand(canvas, chartRect, timeToX);

    // 2. Draw Horizontal Grid lines (0°, 30°, 60°, 90°)
    final gridPaint = Paint()
      ..color = isRedNightMode
          ? AstroColors.nightVisionBorder.withValues(alpha: 0.5)
          : Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.0;

    final thresholdPaint = Paint()
      ..color = isRedNightMode
          ? AstroColors.nightVisionRedDim.withValues(alpha: 0.7)
          : AstroColors.starGold.withValues(alpha: 0.4)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final textStyle = TextStyle(
      color: isRedNightMode ? AstroColors.nightVisionRedDim : Colors.white30,
      fontSize: 9,
    );

    for (final alt in [0.0, 30.0, 60.0, 90.0]) {
      final y = altToY(alt);
      if (alt == minAltitudeThreshold) {
        _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), thresholdPaint);
      } else {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }

      final textSpan = TextSpan(text: "${alt.toInt()}°", style: textStyle);
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(6, y - tp.height - 2));
    }

    if (maxAltitudeThreshold < 90.0) {
      final yMax = altToY(maxAltitudeThreshold);
      final maxPaint = Paint()
        ..color = (isRedNightMode ? AstroColors.nightVisionRedDim : Colors.amberAccent).withValues(alpha: 0.55)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      _drawDashedLine(canvas, Offset(0, yMax), Offset(size.width, yMax), maxPaint);

      final tpMax = TextPainter(
        text: TextSpan(
          text: "MAX: ${maxAltitudeThreshold.toInt()}°",
          style: textStyle.copyWith(
            color: isRedNightMode ? AstroColors.nightVisionRedDim : Colors.amberAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tpMax.paint(canvas, Offset(size.width - tpMax.width - 8, yMax - tpMax.height - 2));
    }

    // 3. Draw Target Altitude Path (Background & Fill)
    if (points.isNotEmpty) {
      final path = Path();
      final fillPath = Path();

      bool first = true;
      for (final p in points) {
        final x = timeToX(p.time);
        final y = altToY(p.altitude);
        if (first) {
          path.moveTo(x, y);
          fillPath.moveTo(x, chartRect.bottom);
          fillPath.lineTo(x, y);
          first = false;
        } else {
          path.lineTo(x, y);
          fillPath.lineTo(x, y);
        }
      }
      fillPath.lineTo(timeToX(points.last.time), chartRect.bottom);
      fillPath.close();

      final fillGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isRedNightMode
            ? [
                AstroColors.nightVisionRed.withValues(alpha: 0.22),
                AstroColors.nightVisionRed.withValues(alpha: 0.0),
              ]
            : [
                AstroColors.starlightCyan.withValues(alpha: 0.25),
                AstroColors.nebulaIndigo.withValues(alpha: 0.0),
              ],
      );

      final fillPaint = Paint()
        ..shader = fillGradient.createShader(chartRect)
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);

      final occludedStrokePaint = Paint()
        ..color = (isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan).withValues(alpha: 0.35)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, occludedStrokePaint);
    }

    // 4. Draw Horizon Silhouette (Mountain Topography / Custom Obstacles)
    final hasHorizon = filterState != null && filterState!.hasHorizon;
    if (hasHorizon && showHorizonSilhouette && points.isNotEmpty) {
      _drawHorizonSilhouette(canvas, chartRect, timeToX, altToY);
    }

    // 5. Draw Target Visible Foreground Stroke (Bright segments above horizon)
    if (points.isNotEmpty) {
      final solidPath = Path();
      bool inSolid = false;

      for (int i = 0; i < points.length; i++) {
        final p = points[i];
        final x = timeToX(p.time);
        final y = altToY(p.altitude);

        final hAlt = (hasHorizon && showHorizonSilhouette)
            ? filterState!.getHorizonAltitudeAt(p.azimuth)
            : 0.0;
        final isClear = p.altitude >= hAlt;

        if (isClear) {
          if (!inSolid) {
            solidPath.moveTo(x, y);
            inSolid = true;
          } else {
            solidPath.lineTo(x, y);
          }
        } else {
          inSolid = false;
        }
      }

      final solidStrokePaint = Paint()
        ..color = isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(solidPath, solidStrokePaint);

      AltitudePoint peakPoint = points.first;
      for (final p in points) {
        if (p.altitude > peakPoint.altitude) peakPoint = p;
      }

      final peakX = timeToX(peakPoint.time);
      final peakY = altToY(peakPoint.altitude);

      final peakPaint = Paint()
        ..color = isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starGold
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(peakX, peakY), 4.0, peakPaint);
      canvas.drawCircle(
        Offset(peakX, peakY),
        7.0,
        Paint()
          ..color = (isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starGold).withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    canvas.restore();

    // 6. Draw Time & Compass Direction Labels along the Bottom Axis
    _drawTimeLabels(canvas, size, chartRect, visibleDurationSec);

    // 7. Scrubber Line & Cursor
    if (hoverFraction != null) {
      final scrubX = hoverFraction! * size.width;
      final scrubPaint = Paint()
        ..color = isRedNightMode ? AstroColors.nightVisionRed : Colors.white70
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(scrubX, 0), Offset(scrubX, chartRect.bottom), scrubPaint);

      final hoveredSec = (hoverFraction! * visibleDurationSec).round();
      final hoveredTime = visibleStartTime.add(Duration(seconds: hoveredSec));

      if (points.isNotEmpty) {
        AltitudePoint closestP = points.first;
        int minDiff = 999999999;
        for (final p in points) {
          final diff = (p.time.difference(hoveredTime).inSeconds).abs();
          if (diff < minDiff) {
            minDiff = diff;
            closestP = p;
          }
        }

        final dotY = altToY(closestP.altitude);
        canvas.drawCircle(
          Offset(scrubX, dotY),
          4.5,
          Paint()..color = isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan,
        );

        if (hasHorizon && showHorizonSilhouette) {
          final hAlt = filterState!.getHorizonAltitudeAt(closestP.azimuth);
          final hDotY = altToY(hAlt);
          canvas.drawCircle(
            Offset(scrubX, hDotY),
            3.5,
            Paint()..color = Colors.amberAccent.withValues(alpha: 0.9),
          );
        }
      }
    }
  }

  double _getTargetAzimuthAtTime(DateTime t) {
    if (points.isEmpty) return 0.0;
    if (t.isBefore(points.first.time)) return points.first.azimuth;
    if (!t.isBefore(points.last.time)) return points.last.azimuth;

    int low = 0;
    int high = points.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      if (points[mid].time.isBefore(t)) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    final p0 = points[math.max(0, low - 1)];
    final p1 = points[math.min(points.length - 1, low)];
    final spanSec = p1.time.difference(p0.time).inSeconds;
    if (spanSec <= 0) return p0.azimuth;

    final frac = t.difference(p0.time).inSeconds / spanSec;
    double diff = p1.azimuth - p0.azimuth;
    if (diff > 180.0) diff -= 360.0;
    if (diff < -180.0) diff += 360.0;
    final az = (p0.azimuth + frac * diff) % 360.0;
    return az < 0 ? az + 360.0 : az;
  }

  void _drawHorizonSilhouette(
    Canvas canvas,
    Rect chartRect,
    double Function(DateTime) timeToX,
    double Function(double) altToY,
  ) {
    final horizonPath = Path();
    final horizonFillPath = Path();
    final visibleDurationSec = visibleEndTime.difference(visibleStartTime).inSeconds;
    if (visibleDurationSec <= 0) return;

    final numSteps = math.max(160, (chartRect.width / 2.0).round());
    bool first = true;

    for (int i = 0; i <= numSteps; i++) {
      final frac = i / numSteps;
      final x = chartRect.left + frac * chartRect.width;
      final t = visibleStartTime.add(Duration(seconds: (frac * visibleDurationSec).round()));
      final az = _getTargetAzimuthAtTime(t);
      final hAlt = filterState!.getHorizonAltitudeAt(az);
      final y = altToY(hAlt);

      if (first) {
        horizonPath.moveTo(x, y);
        horizonFillPath.moveTo(x, chartRect.bottom);
        horizonFillPath.lineTo(x, y);
        first = false;
      } else {
        horizonPath.lineTo(x, y);
        horizonFillPath.lineTo(x, y);
      }
    }

    horizonFillPath.lineTo(chartRect.right, chartRect.bottom);
    horizonFillPath.close();

    final mountainGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isRedNightMode
          ? [
              const Color(0xFF380808).withValues(alpha: 0.85),
              const Color(0xFF140202).withValues(alpha: 0.96),
            ]
          : [
              const Color(0xFF1A2436).withValues(alpha: 0.88),
              const Color(0xFF090E17).withValues(alpha: 0.96),
            ],
    );

    final fillPaint = Paint()
      ..shader = mountainGradient.createShader(chartRect)
      ..style = PaintingStyle.fill;
    canvas.drawPath(horizonFillPath, fillPaint);

    final ridgePaint = Paint()
      ..color = isRedNightMode
          ? AstroColors.nightVisionRed.withValues(alpha: 0.65)
          : const Color(0xFF38BDF8).withValues(alpha: 0.75)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(horizonPath, ridgePaint);

    final badgeStyle = TextStyle(
      fontSize: 7.5,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.8,
      color: isRedNightMode
          ? AstroColors.nightVisionRed.withValues(alpha: 0.6)
          : const Color(0xFF38BDF8).withValues(alpha: 0.7),
    );
    final firstAz = _getTargetAzimuthAtTime(visibleStartTime);
    final firstHAlt = filterState!.getHorizonAltitudeAt(firstAz);
    final firstY = altToY(firstHAlt);

    final tp = TextPainter(
      text: TextSpan(
        text: "HORIZON: ${firstHAlt.toStringAsFixed(1)}° (${firstAz.toStringAsFixed(0)}° AZ)",
        style: badgeStyle,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(chartRect.left + 8.0, math.min(chartRect.bottom - tp.height - 4, firstY + 4)));
  }

  void _drawTwilightBands(Canvas canvas, Rect rect, double Function(DateTime) timeToX) {
    final astroDuskX = timeToX(night.astronomicalDusk).clamp(0.0, rect.width);
    final astroDawnX = timeToX(night.astronomicalDawn).clamp(0.0, rect.width);

    if (astroDuskX < astroDawnX) {
      final darkRect = Rect.fromLTRB(astroDuskX, 0, astroDawnX, rect.bottom);
      final darkPaint = Paint()
        ..color = isRedNightMode
            ? AstroColors.nightVisionSurfaceVariant.withValues(alpha: 0.6)
            : const Color(0xFF04060A).withValues(alpha: 0.85);
      canvas.drawRect(darkRect, darkPaint);

      final labelStyle = TextStyle(
        color: isRedNightMode ? AstroColors.nightVisionRedDim.withValues(alpha: 0.6) : Colors.white24,
        fontSize: 9,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: l10n?.astronomicalDarkness.toUpperCase() ?? "ASTRONOMICAL DARKNESS",
          style: labelStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final textWidth = tp.width;
      final spanWidth = astroDawnX - astroDuskX;
      if (spanWidth > textWidth + 16) {
        tp.paint(canvas, Offset(astroDuskX + (spanWidth - textWidth) / 2, 8));
      }
    }

    final nautDuskX = timeToX(night.nauticalDusk).clamp(0.0, rect.width);
    if (nautDuskX < astroDuskX) {
      final nautPaint = Paint()
        ..color = isRedNightMode
            ? AstroColors.nightVisionSurface.withValues(alpha: 0.4)
            : const Color(0xFF0A1224).withValues(alpha: 0.55);
      canvas.drawRect(Rect.fromLTRB(nautDuskX, 0, astroDuskX, rect.bottom), nautPaint);
    }

    final nautDawnX = timeToX(night.nauticalDawn).clamp(0.0, rect.width);
    if (astroDawnX < nautDawnX) {
      final nautPaint = Paint()
        ..color = isRedNightMode
            ? AstroColors.nightVisionSurface.withValues(alpha: 0.4)
            : const Color(0xFF0A1224).withValues(alpha: 0.55);
      canvas.drawRect(Rect.fromLTRB(astroDawnX, 0, nautDawnX, rect.bottom), nautPaint);
    }
  }

  void _drawCustomWindowBand(Canvas canvas, Rect rect, double Function(DateTime) timeToX) {
    if (customWindowStart == null || customWindowEnd == null) return;

    final startX = timeToX(customWindowStart!).clamp(0.0, rect.width);
    final endX = timeToX(customWindowEnd!).clamp(0.0, rect.width);

    if (startX < endX) {
      final windowRect = Rect.fromLTRB(startX, 0, endX, rect.bottom);
      final windowPaint = Paint()
        ..color = (isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan).withValues(alpha: 0.07);
      canvas.drawRect(windowRect, windowPaint);

      final borderPaint = Paint()
        ..color = (isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan).withValues(alpha: 0.4)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      _drawVerticalDashedLine(canvas, Offset(startX, 0), Offset(startX, rect.bottom), borderPaint);
      _drawVerticalDashedLine(canvas, Offset(endX, 0), Offset(endX, rect.bottom), borderPaint);

      final labelStyle = TextStyle(
        color: isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan,
        fontSize: 8.5,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: l10n?.observingWindowLabel.toUpperCase() ?? "OBSERVING WINDOW",
          style: labelStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final spanWidth = endX - startX;
      if (spanWidth > tp.width + 12) {
        tp.paint(canvas, Offset(startX + (spanWidth - tp.width) / 2, rect.bottom - tp.height - 6));
      }
    }
  }

  void _drawVerticalDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashHeight = 4.0;
    const dashSpace = 3.0;
    double currentY = p1.dy;
    while (currentY < p2.dy) {
      canvas.drawLine(
        Offset(p1.dx, currentY),
        Offset(p1.dx, math.min(currentY + dashHeight, p2.dy)),
        paint,
      );
      currentY += dashHeight + dashSpace;
    }
  }

  void _drawTimeLabels(Canvas canvas, Size size, Rect chartRect, int durationSec) {
    const labelCount = 6;
    final textStyle = TextStyle(
      color: isRedNightMode ? AstroColors.nightVisionRedDim : Colors.white60,
      fontSize: 9.5,
      fontWeight: FontWeight.bold,
      fontFamily: 'monospace',
    );
    final cardStyle = TextStyle(
      color: isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan,
      fontSize: 8.0,
      fontWeight: FontWeight.w600,
      fontFamily: 'monospace',
    );

    for (int i = 0; i <= labelCount; ++i) {
      final frac = i / labelCount;
      final x = frac * size.width;
      final time = visibleStartTime.add(Duration(seconds: (frac * durationSec).round()));

      final timeStr = DateFormat('HH:mm').format(time);
      final az = _getTargetAzimuthAtTime(time);
      final cardStr = _cardinal(az);

      final span = TextSpan(
        children: [
          TextSpan(text: "$timeStr\n", style: textStyle),
          TextSpan(text: "$cardStr (${az.round()}°)", style: cardStyle),
        ],
      );
      final tp = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();

      final textX = (x - tp.width / 2).clamp(2.0, size.width - tp.width - 2);
      tp.paint(canvas, Offset(textX, chartRect.bottom + 4));
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double currentX = p1.dx;
    while (currentX < p2.dx) {
      canvas.drawLine(
        Offset(currentX, p1.dy),
        Offset(math.min(currentX + dashWidth, p2.dx), p1.dy),
        paint,
      );
      currentX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _AltitudeChartPainter old) {
    return old.points != points ||
        old.hoverFraction != hoverFraction ||
        old.visibleStartTime != visibleStartTime ||
        old.visibleEndTime != visibleEndTime ||
        old.customWindowStart != customWindowStart ||
        old.customWindowEnd != customWindowEnd ||
        old.isRedNightMode != isRedNightMode ||
        old.showHorizonSilhouette != showHorizonSilhouette ||
        old.filterState != filterState ||
        old.minAltitudeThreshold != minAltitudeThreshold;
  }
}
