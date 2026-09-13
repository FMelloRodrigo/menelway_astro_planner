import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../core/file_picker_service.dart';
import '../models/filter_state.dart';
import '../theme/astro_theme.dart';

/// Modal dialog providing an interactive Az-Alt chart (0°-360° azimuth x 0°-90° altitude)
/// to create, drag, and delete custom horizon obstacle points, with an optional
/// cylindrical panorama background image, active azimuth corridor overlay, and
/// mobile-friendly precision stepper controls.
class HorizonMakerDialog extends StatefulWidget {
  final FilterState initialFilters;
  final bool isRedNightMode;
  final void Function(FilterState updated) onApply;

  const HorizonMakerDialog({
    super.key,
    required this.initialFilters,
    this.isRedNightMode = false,
    required this.onApply,
  });

  @override
  State<HorizonMakerDialog> createState() => _HorizonMakerDialogState();
}

class _HorizonMakerDialogState extends State<HorizonMakerDialog> {
  late FilterState _state;
  late List<HorizonPointModel> _points;
  int? _selectedPointIndex;

  // Background Panorama state
  String? _panoramaPath;
  ui.Image? _decodedImage;
  bool _isLoadingImage = false;
  late double _azimuthOffset;
  late double _altitudeOffset;
  late double _altitudeScale;
  late double _imageOpacity;
  bool _calibrateMode = false; // true = dragging pans image, false = edits horizon points

  @override
  void initState() {
    super.initState();
    _state = widget.initialFilters.copyWith();
    _points = List<HorizonPointModel>.from(_state.horizonPoints);
    _sortPoints();

    _panoramaPath = _state.panoramaImagePath;
    _azimuthOffset = _state.panoramaAzimuthOffset;
    _altitudeOffset = _state.panoramaAltitudeOffset;
    _altitudeScale = _state.panoramaAltitudeScale;
    _imageOpacity = _state.panoramaOpacity;

    if (_panoramaPath != null && _panoramaPath!.isNotEmpty) {
      _loadDecodedImage(_panoramaPath!);
    }
  }

  void _sortPoints() {
    _points.sort((a, b) => a.azimuth.compareTo(b.azimuth));
  }

  Future<void> _loadDecodedImage(String path) async {
    final file = File(path);
    if (!file.existsSync()) return;

    setState(() => _isLoadingImage = true);
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _decodedImage = frame.image;
          _panoramaPath = path;
          _isLoadingImage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Could not decode image: please ensure it is a valid JPG, PNG, or WebP file ($e)"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final path = await FilePickerService.pickPanoramaImage();
    if (path != null && path.isNotEmpty) {
      await _loadDecodedImage(path);
    }
  }

  void _clearImage() {
    setState(() {
      _decodedImage = null;
      _panoramaPath = null;
    });
  }

  void _addPoint(double az, double alt) {
    setState(() {
      final newPoint = HorizonPointModel(
        azimuth: (az.clamp(0.0, 360.0) * 10).round() / 10.0,
        altitude: (alt.clamp(0.0, 90.0) * 10).round() / 10.0,
      );
      _points.add(newPoint);
      _sortPoints();
      _selectedPointIndex = _points.indexOf(newPoint);
    });
  }

  void _deleteSelectedPoint() {
    if (_selectedPointIndex != null && _selectedPointIndex! < _points.length) {
      setState(() {
        _points.removeAt(_selectedPointIndex!);
        _selectedPointIndex = null;
      });
    }
  }

  void _adjustSelectedPoint(double dAz, double dAlt) {
    if (_selectedPointIndex == null || _selectedPointIndex! >= _points.length) return;
    setState(() {
      final p = _points[_selectedPointIndex!];
      final newAz = (p.azimuth + dAz).clamp(0.0, 360.0);
      final newAlt = (p.altitude + dAlt).clamp(0.0, 90.0);
      _points[_selectedPointIndex!] = HorizonPointModel(
        azimuth: (newAz * 10).round() / 10.0,
        altitude: (newAlt * 10).round() / 10.0,
      );
      final updated = _points[_selectedPointIndex!];
      _sortPoints();
      _selectedPointIndex = _points.indexOf(updated);
    });
  }

  void _applyPreset(String preset) {
    setState(() {
      _selectedPointIndex = null;
      if (preset == "flat0") {
        _points = [];
      } else if (preset == "flat15") {
        _points = [
          const HorizonPointModel(azimuth: 0.0, altitude: 15.0),
          const HorizonPointModel(azimuth: 90.0, altitude: 15.0),
          const HorizonPointModel(azimuth: 180.0, altitude: 15.0),
          const HorizonPointModel(azimuth: 270.0, altitude: 15.0),
          const HorizonPointModel(azimuth: 360.0, altitude: 15.0),
        ];
      } else if (preset == "flat30") {
        _points = [
          const HorizonPointModel(azimuth: 0.0, altitude: 30.0),
          const HorizonPointModel(azimuth: 90.0, altitude: 30.0),
          const HorizonPointModel(azimuth: 180.0, altitude: 30.0),
          const HorizonPointModel(azimuth: 270.0, altitude: 30.0),
          const HorizonPointModel(azimuth: 360.0, altitude: 30.0),
        ];
      } else if (preset == "sample") {
        // Realistic suburban backyard: house roof to North, trees to East and West, open South
        _points = [
          const HorizonPointModel(azimuth: 0.0, altitude: 32.0),
          const HorizonPointModel(azimuth: 45.0, altitude: 28.0),
          const HorizonPointModel(azimuth: 90.0, altitude: 45.0),  // tall tree in East
          const HorizonPointModel(azimuth: 120.0, altitude: 20.0),
          const HorizonPointModel(azimuth: 180.0, altitude: 12.0), // open Southern view
          const HorizonPointModel(azimuth: 240.0, altitude: 18.0),
          const HorizonPointModel(azimuth: 285.0, altitude: 40.0), // tree in West
          const HorizonPointModel(azimuth: 330.0, altitude: 35.0),
          const HorizonPointModel(azimuth: 360.0, altitude: 32.0),
        ];
      }
      _sortPoints();
    });
  }

  void _saveAndClose() {
    _sortPoints();
    final updated = _state.copyWith(
      useCustomHorizon: _points.isNotEmpty,
      horizonPoints: _points,
      panoramaImagePath: _panoramaPath,
      panoramaAzimuthOffset: _azimuthOffset,
      panoramaAltitudeOffset: _altitudeOffset,
      panoramaAltitudeScale: _altitudeScale,
      panoramaOpacity: _imageOpacity,
    );
    widget.onApply(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 700;
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;

    final dialogContent = Container(
      width: 880,
      padding: EdgeInsets.all(isNarrow ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.terrain_rounded, color: accentColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Horizon Maker & Obstruction Profile",
                      style: TextStyle(
                        fontSize: isNarrow ? 15 : 17,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "Define custom local obstacles (trees, roofs) across 360° Azimuth x 90° Altitude",
                      style: TextStyle(
                        fontSize: 11,
                        color: textColor.withValues(alpha: 0.6),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: textColor.withValues(alpha: 0.6)),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Toolbar / Quick Actions
          _buildToolbar(textColor, accentColor, isNarrow),
          const SizedBox(height: 8),

          // Main Interactive Horizon Chart
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: widget.isRedNightMode ? const Color(0xFF150404) : const Color(0xFF0D141F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return _InteractiveHorizonCanvas(
                      points: _points,
                      selectedIndex: _selectedPointIndex,
                      isRedNightMode: widget.isRedNightMode,
                      minAzimuth: _state.minAzimuth,
                      maxAzimuth: _state.maxAzimuth,
                      minAltitude: _state.minAltitude,
                      maxAltitude: _state.maxAltitude,
                      decodedImage: _decodedImage,
                      azimuthOffset: _azimuthOffset,
                      altitudeOffset: _altitudeOffset,
                      altitudeScale: _altitudeScale,
                      imageOpacity: _imageOpacity,
                      calibrateMode: _calibrateMode,
                      onAddPoint: _addPoint,
                      onSelectPoint: (idx) => setState(() => _selectedPointIndex = idx),
                      onPointMoved: (idx, az, alt) {
                        setState(() {
                          _points[idx] = HorizonPointModel(
                            azimuth: (az.clamp(0.0, 360.0) * 10).round() / 10.0,
                            altitude: (alt.clamp(0.0, 90.0) * 10).round() / 10.0,
                          );
                        });
                      },
                      onPointDragEnd: () {
                        setState(() {
                          _sortPoints();
                        });
                      },
                      onPanImage: (dAz, dAlt) {
                        setState(() {
                          _azimuthOffset = (_azimuthOffset + dAz) % 360.0;
                          if (_azimuthOffset < 0) _azimuthOffset += 360.0;
                          _altitudeOffset = (_altitudeOffset + dAlt).clamp(-25.0, 35.0);
                        });
                      },
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Panorama Calibration Controls (visible if image is loaded)
          if (_decodedImage != null)
            _buildPanoramaControls(textColor, accentColor, isNarrow),

          // Point Selection & Micro-Adjustment Bar
          if (_selectedPointIndex != null && _selectedPointIndex! < _points.length)
            _buildPointInspector(textColor, accentColor, isNarrow),

          const SizedBox(height: 8),

          // Bottom Action Bar
          Row(
            children: [
              Text(
                "${_points.length} points defined${_points.isNotEmpty ? ' • Profile Active' : ' • Flat default'}",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _points.isNotEmpty
                      ? (widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan)
                      : textColor.withValues(alpha: 0.5),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text("Cancel", style: TextStyle(color: textColor.withValues(alpha: 0.7))),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: widget.isRedNightMode ? Colors.white : Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text("Apply Horizon", style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _saveAndClose,
              ),
            ],
          ),
        ],
      ),
    );

    if (isNarrow) {
      return Dialog.fullscreen(
        backgroundColor: widget.isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface,
        child: SafeArea(child: dialogContent),
      );
    } else {
      return Dialog(
        backgroundColor: widget.isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder,
          ),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: dialogContent,
      );
    }
  }

  Widget _buildToolbar(Color textColor, Color accentColor, bool isNarrow) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Background Image Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              side: BorderSide(color: accentColor.withValues(alpha: 0.4)),
            ),
            icon: Icon(
              _decodedImage != null ? Icons.image_rounded : Icons.add_photo_alternate_rounded,
              size: 16,
              color: accentColor,
            ),
            label: Text(
              _decodedImage != null ? "Change Panorama..." : "Import Panorama (JPG)...",
              style: TextStyle(fontSize: 12, color: textColor),
            ),
            onPressed: _isLoadingImage ? null : _pickImage,
          ),
          if (_decodedImage != null) ...[
            const SizedBox(width: 6),
            IconButton(
              tooltip: "Remove Panorama",
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
              onPressed: _clearImage,
            ),
            const SizedBox(width: 6),
            // Mode toggle: Calibrate Image vs Edit Points
            FilterChip(
              selected: _calibrateMode,
              label: Text(
                _calibrateMode ? "Pan Mode: Image Position" : "Edit Mode: Horizon Points",
                style: TextStyle(fontSize: 11, color: textColor),
              ),
              avatar: Icon(
                _calibrateMode ? Icons.open_with_rounded : Icons.gesture_rounded,
                size: 14,
                color: accentColor,
              ),
              selectedColor: accentColor.withValues(alpha: 0.25),
              onSelected: (val) => setState(() => _calibrateMode = val),
            ),
          ],
          const SizedBox(width: 12),
          Container(width: 1, height: 24, color: textColor.withValues(alpha: 0.2)),
          const SizedBox(width: 12),

          // Presets
          Text(
            "Presets:",
            style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.5)),
          ),
          const SizedBox(width: 6),
          ActionChip(
            label: const Text("Clear (0°)", style: TextStyle(fontSize: 11)),
            onPressed: () => _applyPreset("flat0"),
          ),
          const SizedBox(width: 4),
          ActionChip(
            label: const Text("Flat 15°", style: TextStyle(fontSize: 11)),
            onPressed: () => _applyPreset("flat15"),
          ),
          const SizedBox(width: 4),
          ActionChip(
            label: const Text("Flat 30°", style: TextStyle(fontSize: 11)),
            onPressed: () => _applyPreset("flat30"),
          ),
          const SizedBox(width: 4),
          ActionChip(
            label: const Text("Backyard Sample", style: TextStyle(fontSize: 11)),
            onPressed: () => _applyPreset("sample"),
          ),
        ],
      ),
    );
  }

  Widget _buildPanoramaControls(Color textColor, Color accentColor, bool isNarrow) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: widget.isRedNightMode
            ? AstroColors.nightVisionSurfaceVariant
            : AstroColors.spaceDarkSurfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 14, color: accentColor),
              const SizedBox(width: 6),
              Text(
                "Panorama Alignment & Calibration",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
              ),
              const Spacer(),
              Text(
                "North Offset: ${_azimuthOffset.round()}°  |  Level: ${_altitudeOffset.round()}°  |  Opacity: ${(_imageOpacity * 100).round()}%",
                style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: textColor.withValues(alpha: 0.7)),
              ),
            ],
          ),
          Row(
            children: [
              SizedBox(
                width: 80,
                child: Text("Pan (North):", style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.8))),
              ),
              Expanded(
                child: Slider(
                  value: _azimuthOffset,
                  min: 0,
                  max: 360,
                  activeColor: accentColor,
                  onChanged: (v) => setState(() => _azimuthOffset = v),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 70,
                child: Text("Alt Base:", style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.8))),
              ),
              Expanded(
                child: Slider(
                  value: _altitudeOffset,
                  min: -20,
                  max: 30,
                  activeColor: accentColor,
                  onChanged: (v) => setState(() => _altitudeOffset = v),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 50,
                child: Text("Opacity:", style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.8))),
              ),
              SizedBox(
                width: 100,
                child: Slider(
                  value: _imageOpacity,
                  min: 0.1,
                  max: 1.0,
                  activeColor: accentColor,
                  onChanged: (v) => setState(() => _imageOpacity = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPointInspector(Color textColor, Color accentColor, bool isNarrow) {
    final p = _points[_selectedPointIndex!];
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.adjust_rounded, size: 15, color: accentColor),
          const SizedBox(width: 6),
          Text(
            "Point #${_selectedPointIndex! + 1}: ",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
          ),
          Text(
            "Az: ${p.azimuth.toStringAsFixed(1)}° (${_cardinal(p.azimuth)})  |  Alt: ${p.altitude.toStringAsFixed(1)}°",
            style: TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: accentColor),
          ),
          const Spacer(),
          // Mobile precision stepper buttons
          IconButton(
            tooltip: "-1° Azimuth",
            icon: const Icon(Icons.arrow_left_rounded, size: 20),
            onPressed: () => _adjustSelectedPoint(-1.0, 0.0),
          ),
          IconButton(
            tooltip: "+1° Azimuth",
            icon: const Icon(Icons.arrow_right_rounded, size: 20),
            onPressed: () => _adjustSelectedPoint(1.0, 0.0),
          ),
          IconButton(
            tooltip: "-1° Altitude",
            icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
            onPressed: () => _adjustSelectedPoint(0.0, -1.0),
          ),
          IconButton(
            tooltip: "+1° Altitude",
            icon: const Icon(Icons.arrow_drop_up_rounded, size: 20),
            onPressed: () => _adjustSelectedPoint(0.0, 1.0),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.25),
              foregroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            icon: const Icon(Icons.delete_rounded, size: 14),
            label: const Text("Delete Point", style: TextStyle(fontSize: 11)),
            onPressed: _deleteSelectedPoint,
          ),
        ],
      ),
    );
  }

  String _cardinal(double az) {
    final a = (az % 360 + 360) % 360;
    if (a >= 337.5 || a < 22.5) return "N";
    if (a < 67.5) return "NE";
    if (a < 112.5) return "E";
    if (a < 157.5) return "SE";
    if (a < 202.5) return "S";
    if (a < 247.5) return "SW";
    if (a < 292.5) return "W";
    return "NW";
  }
}

/// Canvas widget handling coordinates, rendering background panorama,
/// rendering grid, active azimuth range corridor, min/max altitude guides,
/// and obstacle mask with interactive point dragging.
class _InteractiveHorizonCanvas extends StatefulWidget {
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
  final void Function(double az, double alt) onAddPoint;
  final void Function(int index) onSelectPoint;
  final void Function(int index, double az, double alt) onPointMoved;
  final VoidCallback onPointDragEnd;
  final void Function(double dAz, double dAlt) onPanImage;

  const _InteractiveHorizonCanvas({
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
    required this.onAddPoint,
    required this.onSelectPoint,
    required this.onPointMoved,
    required this.onPointDragEnd,
    required this.onPanImage,
  });

  @override
  State<_InteractiveHorizonCanvas> createState() => _InteractiveHorizonCanvasState();
}

class _InteractiveHorizonCanvasState extends State<_InteractiveHorizonCanvas> {
  int? _draggedIndex;
  Offset? _hoverPos;

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
    return r.left + (az / 360.0) * r.width;
  }

  double _xToAz(double x, Rect r) {
    return ((x - r.left) / r.width * 360.0).clamp(0.0, 360.0);
  }

  double _altToY(double alt, Rect r) {
    return r.bottom - (alt / 90.0) * r.height;
  }

  double _yToAlt(double y, Rect r) {
    return ((r.bottom - y) / r.height * 90.0).clamp(0.0, 90.0);
  }

  int? _hitTestPoint(Offset localPos, Size size) {
    final r = _chartRect(size);
    const hitRadius = 24.0; // touch-friendly hit radius
    for (int i = 0; i < widget.points.length; i++) {
      final p = widget.points[i];
      final px = _azToX(p.azimuth, r);
      final py = _altToY(p.altitude, r);
      final dist = (Offset(px, py) - localPos).distance;
      if (dist <= hitRadius) {
        return i;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final r = _chartRect(size);

        return GestureDetector(
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
              // Selecting point allows delete button to remove it
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
            }
          },
          onPanUpdate: (details) {
            if (widget.calibrateMode) {
              // Dragging pans background image
              final dAz = (details.delta.dx / r.width) * 360.0;
              final dAlt = -(details.delta.dy / r.height) * 90.0;
              widget.onPanImage(dAz, dAlt);
              return;
            }

            if (_draggedIndex != null && _draggedIndex! < widget.points.length) {
              final newAz = _xToAz(details.localPosition.dx, r);
              final newAlt = _yToAlt(details.localPosition.dy, r);
              widget.onPointMoved(_draggedIndex!, newAz, newAlt);
            }
          },
          onPanEnd: (_) {
            if (_draggedIndex != null) {
              _draggedIndex = null;
              widget.onPointDragEnd();
              setState(() {});
            }
          },
          child: MouseRegion(
            onHover: (event) => setState(() => _hoverPos = event.localPosition),
            onExit: (_) => setState(() => _hoverPos = null),
            cursor: widget.calibrateMode
                ? SystemMouseCursors.move
                : (_hitTestPoint(_hoverPos ?? Offset.zero, size) != null
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.precise),
            child: CustomPaint(
              size: size,
              painter: _HorizonChartPainter(
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
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HorizonChartPainter extends CustomPainter {
  final List<HorizonPointModel> points;
  final int? selectedIndex;
  final int? draggedIndex;
  final Offset? hoverPos;
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

  _HorizonChartPainter({
    required this.points,
    required this.selectedIndex,
    required this.draggedIndex,
    required this.hoverPos,
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
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(
      _InteractiveHorizonCanvasState.leftMargin,
      _InteractiveHorizonCanvasState.topMargin,
      math.max(10.0, size.width - _InteractiveHorizonCanvasState.leftMargin - _InteractiveHorizonCanvasState.rightMargin),
      math.max(10.0, size.height - _InteractiveHorizonCanvasState.topMargin - _InteractiveHorizonCanvasState.bottomMargin),
    );

    double azToX(double az) => r.left + (az / 360.0) * r.width;
    double altToY(double alt) => r.bottom - (alt / 90.0) * r.height;

    // 1. Draw Panorama Image Backdrop (wrapped cyclically across 360°)
    if (decodedImage != null) {
      canvas.save();
      canvas.clipRect(r);

      final imgW = decodedImage!.width.toDouble();
      final imgH = decodedImage!.height.toDouble();

      final paintImg = Paint()
        ..color = Colors.white.withValues(alpha: imageOpacity.clamp(0.05, 1.0))
        ..filterQuality = FilterQuality.medium;

      // Base vertical destination
      final baseAltY = altToY(altitudeOffset);
      final destH = r.height * altitudeScale;
      final destY = baseAltY - destH;

      // Horizontal cyclic wrapping: draw image shifted by azimuth offset
      final shiftX = (azimuthOffset / 360.0) * r.width;

      final srcRect = Rect.fromLTWH(0, 0, imgW, imgH);

      // Tile 1 (primary)
      final dest1 = Rect.fromLTWH(r.left - shiftX, destY, r.width, destH);
      canvas.drawImageRect(decodedImage!, srcRect, dest1, paintImg);

      // Tile 2 (wrapped right)
      final dest2 = Rect.fromLTWH(r.left - shiftX + r.width, destY, r.width, destH);
      canvas.drawImageRect(decodedImage!, srcRect, dest2, paintImg);

      // Tile 3 (wrapped left)
      final dest3 = Rect.fromLTWH(r.left - shiftX - r.width, destY, r.width, destH);
      canvas.drawImageRect(decodedImage!, srcRect, dest3, paintImg);

      canvas.restore();
    }

    // 2. Active Azimuth Corridor Shading (Visual Conjunction with Azimuth Range Filter)
    _drawAzimuthCorridor(canvas, r, azToX);

    // 3. Grid Lines & Axis Markers
    _drawGridLines(canvas, r, azToX, altToY);

    // 4. Min & Max Altitude Threshold Lines
    _drawAltitudeThresholds(canvas, r, altToY);

    // 5. Obstacle Silhouette & Shaded Obstruction Fill
    _drawObstacleMask(canvas, r, azToX, altToY);

    // 6. Point Handles and Interactive Highlights
    _drawPointHandles(canvas, r, azToX, altToY);
  }

  void _drawAzimuthCorridor(Canvas canvas, Rect r, double Function(double) azToX) {
    final hasAzLimit = !(minAzimuth == 0.0 && maxAzimuth == 360.0);
    if (!hasAzLimit) return;

    final dimPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.52)
      ..style = PaintingStyle.fill;

    final boundLinePaint = Paint()
      ..color = (isRedNightMode ? AstroColors.nightVisionRedDim : AstroColors.starlightCyan).withValues(alpha: 0.6)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.clipRect(r);

    if (minAzimuth <= maxAzimuth) {
      // Out of range: 0 -> minAzimuth and maxAzimuth -> 360
      final xMin = azToX(minAzimuth);
      final xMax = azToX(maxAzimuth);

      if (minAzimuth > 0) {
        canvas.drawRect(Rect.fromLTRB(r.left, r.top, xMin, r.bottom), dimPaint);
        canvas.drawLine(Offset(xMin, r.top), Offset(xMin, r.bottom), boundLinePaint);
      }
      if (maxAzimuth < 360) {
        canvas.drawRect(Rect.fromLTRB(xMax, r.top, r.right, r.bottom), dimPaint);
        canvas.drawLine(Offset(xMax, r.top), Offset(xMax, r.bottom), boundLinePaint);
      }
    } else {
      // Wraps across 360/0: out of range is maxAzimuth -> minAzimuth
      final xMax = azToX(maxAzimuth);
      final xMin = azToX(minAzimuth);
      canvas.drawRect(Rect.fromLTRB(xMax, r.top, xMin, r.bottom), dimPaint);
      canvas.drawLine(Offset(xMax, r.top), Offset(xMax, r.bottom), boundLinePaint);
      canvas.drawLine(Offset(xMin, r.top), Offset(xMin, r.bottom), boundLinePaint);
    }

    canvas.restore();
  }

  void _drawGridLines(
    Canvas canvas,
    Rect r,
    double Function(double) azToX,
    double Function(double) altToY,
  ) {
    final gridPaint = Paint()
      ..color = isRedNightMode
          ? AstroColors.nightVisionBorder.withValues(alpha: 0.45)
          : Colors.white.withValues(alpha: 0.09)
      ..strokeWidth = 1.0;

    final axisLabelStyle = TextStyle(
      color: isRedNightMode ? AstroColors.nightVisionRedDim : Colors.white60,
      fontSize: 9,
      fontFamily: 'monospace',
    );

    final cardinalLabelStyle = TextStyle(
      color: isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan,
      fontSize: 10,
      fontWeight: FontWeight.bold,
    );

    // Altitude horizontal grid (0°, 15°, 30°, 45°, 60°, 75°, 90°)
    for (double alt = 0; alt <= 90; alt += 15) {
      final y = altToY(alt);
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), gridPaint);

      final tp = TextPainter(
        text: TextSpan(text: "${alt.toInt()}°", style: axisLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(r.left - tp.width - 4, y - tp.height / 2));
    }

    // Azimuth vertical grid with cardinal labels (N, NE, E, SE, S, SW, W, NW, N)
    const cardinals = [
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

    for (final c in cardinals) {
      final x = azToX(c.$1);
      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), gridPaint);

      // Cardinal tag
      final isMajor = c.$2 == "N" || c.$2 == "E" || c.$2 == "S" || c.$2 == "W";
      final tp = TextPainter(
        text: TextSpan(text: c.$2, style: isMajor ? cardinalLabelStyle : axisLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, r.bottom + 4));

      // Degrees
      final tpDeg = TextPainter(
        text: TextSpan(text: "${c.$1.toInt()}°", style: axisLabelStyle.copyWith(fontSize: 8)),
        textDirection: TextDirection.ltr,
      )..layout();
      tpDeg.paint(canvas, Offset(x - tpDeg.width / 2, r.bottom + 16));
    }
  }

  void _drawAltitudeThresholds(
    Canvas canvas,
    Rect r,
    double Function(double) altToY,
  ) {
    // Min Altitude dashed guide
    final yMin = altToY(minAltitude);
    final minPaint = Paint()
      ..color = (isRedNightMode ? AstroColors.nightVisionRedDim : AstroColors.starGold).withValues(alpha: 0.6)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    _drawDashedLine(canvas, Offset(r.left, yMin), Offset(r.right, yMin), minPaint);

    final tpMin = TextPainter(
      text: TextSpan(
        text: "MIN ALT: ${minAltitude.toInt()}°",
        style: TextStyle(
          color: isRedNightMode ? AstroColors.nightVisionRedDim : AstroColors.starGold,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpMin.paint(canvas, Offset(r.right - tpMin.width - 6, yMin - tpMin.height - 2));

    // Max Altitude dashed guide (if < 90°)
    if (maxAltitude < 90.0) {
      final yMax = altToY(maxAltitude);
      final maxPaint = Paint()
        ..color = Colors.amberAccent.withValues(alpha: 0.6)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      _drawDashedLine(canvas, Offset(r.left, yMax), Offset(r.right, yMax), maxPaint);

      final tpMax = TextPainter(
        text: TextSpan(
          text: "MAX ALT: ${maxAltitude.toInt()}°",
          style: const TextStyle(
            color: Colors.amberAccent,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tpMax.paint(canvas, Offset(r.right - tpMax.width - 6, yMax + 2));
    }
  }

  void _drawObstacleMask(
    Canvas canvas,
    Rect r,
    double Function(double) azToX,
    double Function(double) altToY,
  ) {
    if (points.isEmpty) return;

    canvas.save();
    canvas.clipRect(r);

    final path = Path();
    final fillPath = Path();

    // Compute altitude at 0° and 360° via interpolation
    final altAt0 = _interpolatedAlt(0.0);
    final altAt360 = _interpolatedAlt(360.0);

    path.moveTo(r.left, altToY(altAt0));
    fillPath.moveTo(r.left, r.bottom);
    fillPath.lineTo(r.left, altToY(altAt0));

    for (final p in points) {
      final px = azToX(p.azimuth);
      final py = altToY(p.altitude);
      path.lineTo(px, py);
      fillPath.lineTo(px, py);
    }

    path.lineTo(r.right, altToY(altAt360));
    fillPath.lineTo(r.right, altToY(altAt360));
    fillPath.lineTo(r.right, r.bottom);
    fillPath.close();

    // Fill underneath horizon line (Obstructed area)
    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isRedNightMode
          ? [
              AstroColors.nightVisionRed.withValues(alpha: 0.40),
              AstroColors.nightVisionRed.withValues(alpha: 0.15),
            ]
          : [
              Colors.redAccent.withValues(alpha: 0.35),
              Colors.brown.withValues(alpha: 0.20),
            ],
    );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(r)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Horizon outline stroke
    final strokePaint = Paint()
      ..color = isRedNightMode ? AstroColors.nightVisionRed : Colors.redAccent
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    canvas.restore();
  }

  void _drawPointHandles(
    Canvas canvas,
    Rect r,
    double Function(double) azToX,
    double Function(double) altToY,
  ) {
    final accentColor = isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final px = azToX(p.azimuth);
      final py = altToY(p.altitude);
      final isSelected = selectedIndex == i;
      final isDragging = draggedIndex == i;

      // Outer Selection / Dragging Ring
      if (isSelected || isDragging) {
        final ringPaint = Paint()
          ..color = accentColor.withValues(alpha: 0.3)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(px, py), 16.0, ringPaint);

        final ringStroke = Paint()
          ..color = accentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(Offset(px, py), 10.0, ringStroke);
      }

      // Inner Point Disc
      final dotPaint = Paint()
        ..color = isSelected ? Colors.white : (isRedNightMode ? AstroColors.nightVisionRed : Colors.amberAccent)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(px, py), isSelected ? 5.5 : 4.5, dotPaint);

      final dotBorder = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(Offset(px, py), isSelected ? 5.5 : 4.5, dotBorder);

      // Tooltip tag if selected
      if (isSelected) {
        final tagText = "${p.azimuth.round()}°, ${p.altitude.round()}°";
        final tpTag = TextPainter(
          text: TextSpan(
            text: tagText,
            style: const TextStyle(
              fontSize: 9,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final tagRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(px - tpTag.width / 2 - 4, py - tpTag.height - 10, tpTag.width + 8, tpTag.height + 4),
          const Radius.circular(4),
        );
        final tagBg = Paint()..color = Colors.black87;
        canvas.drawRRect(tagRect, tagBg);
        tpTag.paint(canvas, Offset(px - tpTag.width / 2, py - tpTag.height - 8));
      }
    }
  }

  double _interpolatedAlt(double az) {
    if (points.isEmpty) return 0.0;
    if (points.length == 1) return points.first.altitude;

    // Linear interpolation with cyclic 360 wrap
    double normAz = (az % 360.0 + 360.0) % 360.0;

    for (int i = 0; i < points.length; i++) {
      if (normAz < points[i].azimuth) {
        if (i == 0) {
          // between last and first
          final pPrev = points.last;
          final pNext = points.first;
          final span = (pNext.azimuth + 360.0) - pPrev.azimuth;
          final frac = (normAz + 360.0 - pPrev.azimuth) / span;
          return pPrev.altitude + frac * (pNext.altitude - pPrev.altitude);
        } else {
          final pPrev = points[i - 1];
          final pNext = points[i];
          final span = pNext.azimuth - pPrev.azimuth;
          final frac = (normAz - pPrev.azimuth) / span;
          return pPrev.altitude + frac * (pNext.altitude - pPrev.altitude);
        }
      }
    }

    // Between last point and first point
    final pPrev = points.last;
    final pNext = points.first;
    final span = (pNext.azimuth + 360.0) - pPrev.azimuth;
    final frac = (normAz - pPrev.azimuth) / span;
    return pPrev.altitude + frac * (pNext.altitude - pPrev.altitude);
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final count = (distance / (dashWidth + dashSpace)).floor();
    final nx = dx / distance;
    final ny = dy / distance;

    for (int i = 0; i < count; i++) {
      final start = Offset(p1.dx + nx * (i * (dashWidth + dashSpace)), p1.dy + ny * (i * (dashWidth + dashSpace)));
      final end = Offset(start.dx + nx * dashWidth, start.dy + ny * dashWidth);
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HorizonChartPainter old) {
    return true;
  }
}
