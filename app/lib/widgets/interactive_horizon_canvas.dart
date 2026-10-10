import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/filter_state.dart';
import '../models/terrain_profile_model.dart';
import '../theme/astro_theme.dart';
import 'painters/horizon_chart_painter.dart';

class InteractiveHorizonCanvas extends StatefulWidget {
  final List<HorizonPointModel> points;
  final int? selectedIndex;
  final bool isRedNightMode;
  final double minAzimuth;
  final double maxAzimuth;
  final double minAltitude;
  final double maxAltitude;
  final ui.Image? decodedImage;
  final double azimuthOffset;
  final double altitudeOffset;
  final double altitudeScale;
  final double imageOpacity;
  final bool calibrateMode;
  final TerrainProfileModel? terrainProfile;
  final bool showTerrainSilhouette;
  final bool showPoints;
  final double zoomLevel;
  final double viewStartAzimuth;
  final void Function(double az, double alt) onAddPoint;
  final void Function(int index) onSelectPoint;
  final void Function(int index, double az, double alt) onPointMoved;
  final VoidCallback onPointDragEnd;
  final void Function(double dAz, double dAlt) onPanImage;
  final void Function(double newZoom, double? centerAz) onZoomChange;
  final void Function(double deltaAz) onPanView;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetZoom;

  const InteractiveHorizonCanvas({super.key, 
    required this.points,
    required this.selectedIndex,
    required this.isRedNightMode,
    required this.minAzimuth,
    required this.maxAzimuth,
    required this.minAltitude,
    required this.maxAltitude,
    required this.decodedImage,
    required this.azimuthOffset,
    required this.altitudeOffset,
    required this.altitudeScale,
    required this.imageOpacity,
    required this.calibrateMode,
    this.terrainProfile,
    this.showTerrainSilhouette = true,
    this.showPoints = true,
    this.zoomLevel = 1.0,
    this.viewStartAzimuth = 0.0,
    required this.onAddPoint,
    required this.onSelectPoint,
    required this.onPointMoved,
    required this.onPointDragEnd,
    required this.onPanImage,
    required this.onZoomChange,
    required this.onPanView,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetZoom,
  });

  @override
  State<InteractiveHorizonCanvas> createState() => _InteractiveHorizonCanvasState();
}

class _InteractiveHorizonCanvasState extends State<InteractiveHorizonCanvas> {
  int? _draggedIndex;
  Offset? _hoverPos;
  bool _isPanningView = false;

  // Margin definitions
  static const double leftMargin = 40.0;
  static const double rightMargin = 16.0;
  static const double topMargin = 18.0;
  static const double bottomMargin = 26.0;

  Rect _chartRect(Size size) {
    return Rect.fromLTWH(
      leftMargin,
      topMargin,
      math.max(10.0, size.width - leftMargin - rightMargin),
      math.max(10.0, size.height - topMargin - bottomMargin),
    );
  }

  double _azToX(double az, Rect r) {
    final span = 360.0 / widget.zoomLevel;
    return r.left + ((az - widget.viewStartAzimuth) / span) * r.width;
  }

  double _xToAz(double x, Rect r) {
    final span = 360.0 / widget.zoomLevel;
    return (widget.viewStartAzimuth + ((x - r.left) / r.width) * span).clamp(0.0, 360.0);
  }

  double _altToY(double alt, Rect r) {
    return r.bottom - (alt / 90.0) * r.height;
  }

  double _yToAlt(double y, Rect r) {
    return ((r.bottom - y) / r.height * 90.0).clamp(0.0, 90.0);
  }

  int? _hitTestPoint(Offset localPos, Size size) {
    final r = _chartRect(size);
    const hitRadius = 24.0;
    int? bestIndex;
    double bestDistance = hitRadius;

    final indicesToCheck = widget.showPoints
        ? List.generate(widget.points.length, (i) => i)
        : (widget.selectedIndex != null ? [widget.selectedIndex!] : <int>[]);

    for (final i in indicesToCheck) {
      final p = widget.points[i];
      final px = _azToX(p.azimuth, r);
      final py = _altToY(p.altitude, r);
      final dist = (Offset(px, py) - localPos).distance;
      if (dist <= bestDistance) {
        bestDistance = dist;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final r = _chartRect(size);

        return Listener(
          onPointerSignal: (pointerSignal) {
            if (pointerSignal is PointerScrollEvent) {
              if (r.contains(pointerSignal.localPosition)) {
                final cursorAz = _xToAz(pointerSignal.localPosition.dx, r);
                final factor = pointerSignal.scrollDelta.dy < 0 ? 1.25 : 0.80;
                final newZoom = (widget.zoomLevel * factor).clamp(1.0, 8.0);
                widget.onZoomChange(newZoom, cursorAz);
              }
            }
          },
          child: Stack(
            children: [
              GestureDetector(
                onTapDown: (details) {
                  final hit = _hitTestPoint(details.localPosition, size);
                  if (hit != null) {
                    widget.onSelectPoint(hit);
                  } else if (r.contains(details.localPosition) && !widget.calibrateMode) {
                    final az = _xToAz(details.localPosition.dx, r);
                    final alt = _yToAlt(details.localPosition.dy, r);
                    widget.onAddPoint(az, alt);
                  }
                },
                onDoubleTapDown: (details) {
                  final hit = _hitTestPoint(details.localPosition, size);
                  if (hit != null) {
                    widget.onSelectPoint(hit);
                  }
                },
                onPanStart: (details) {
                  if (widget.calibrateMode) {
                    return;
                  }
                  final hit = _hitTestPoint(details.localPosition, size);
                  if (hit != null) {
                    _draggedIndex = hit;
                    widget.onSelectPoint(hit);
                    setState(() {});
                  } else if (widget.zoomLevel > 1.0) {
                    _isPanningView = true;
                    setState(() {});
                  }
                },
                onPanUpdate: (details) {
                  if (widget.calibrateMode) {
                    final dAz = (details.delta.dx / r.width) * 360.0;
                    final dAlt = -(details.delta.dy / r.height) * 90.0;
                    widget.onPanImage(dAz, dAlt);
                    return;
                  }

                  if (_draggedIndex != null && _draggedIndex! < widget.points.length) {
                    final newAz = _xToAz(details.localPosition.dx, r);
                    final newAlt = _yToAlt(details.localPosition.dy, r);
                    widget.onPointMoved(_draggedIndex!, newAz, newAlt);
                  } else if (_isPanningView && widget.zoomLevel > 1.0) {
                    final span = 360.0 / widget.zoomLevel;
                    final deltaAz = -(details.delta.dx / r.width) * span;
                    widget.onPanView(deltaAz);
                  }
                },
                onPanEnd: (_) {
                  if (_draggedIndex != null) {
                    _draggedIndex = null;
                    widget.onPointDragEnd();
                  }
                  if (_isPanningView) {
                    _isPanningView = false;
                  }
                  setState(() {});
                },
                child: MouseRegion(
                  onHover: (event) => setState(() => _hoverPos = event.localPosition),
                  onExit: (_) => setState(() => _hoverPos = null),
                  cursor: widget.calibrateMode
                      ? SystemMouseCursors.move
                      : (_hitTestPoint(_hoverPos ?? Offset.zero, size) != null
                          ? SystemMouseCursors.click
                          : (_isPanningView
                              ? SystemMouseCursors.grabbing
                              : (widget.zoomLevel > 1.0 ? SystemMouseCursors.grab : SystemMouseCursors.precise))),
                  child: CustomPaint(
                    size: size,
                    painter: HorizonChartPainter(
                      points: widget.points,
                      selectedIndex: widget.selectedIndex,
                      draggedIndex: _draggedIndex,
                      hoverPos: _hoverPos,
                      isRedNightMode: widget.isRedNightMode,
                      minAzimuth: widget.minAzimuth,
                      maxAzimuth: widget.maxAzimuth,
                      minAltitude: widget.minAltitude,
                      maxAltitude: widget.maxAltitude,
                      decodedImage: widget.decodedImage,
                      azimuthOffset: widget.azimuthOffset,
                      altitudeOffset: widget.altitudeOffset,
                      altitudeScale: widget.altitudeScale,
                      imageOpacity: widget.imageOpacity,
                      terrainProfile: widget.terrainProfile,
                      showTerrainSilhouette: widget.showTerrainSilhouette,
                      showPoints: widget.showPoints,
                      zoomLevel: widget.zoomLevel,
                      viewStartAzimuth: widget.viewStartAzimuth,
                    ),
                  ),
                ),
              ),

              // Floating Zoom Control Overlay (Top-Right)
              Positioned(
                top: 8,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: (widget.isRedNightMode ? Colors.black : const Color(0xFF0B132B)).withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: widget.isRedNightMode
                          ? AstroColors.nightVisionBorder
                          : Colors.white.withValues(alpha: 0.20),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        icon: const Icon(Icons.remove_rounded, size: 15),
                        tooltip: "Zoom Out (Wheel Down)",
                        onPressed: widget.zoomLevel > 1.0 ? widget.onZoomOut : null,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          "${widget.zoomLevel.toStringAsFixed(1)}x",
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            color: widget.zoomLevel > 1.0
                                ? (widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan)
                                : Colors.white70,
                          ),
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        icon: const Icon(Icons.add_rounded, size: 15),
                        tooltip: "Zoom In (Wheel Up)",
                        onPressed: widget.zoomLevel < 8.0 ? widget.onZoomIn : null,
                      ),
                      if (widget.zoomLevel > 1.0) ...[
                        const SizedBox(width: 2),
                        InkWell(
                          onTap: widget.onResetZoom,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              "1x",
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
