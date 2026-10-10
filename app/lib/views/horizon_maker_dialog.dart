import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/file_picker_service.dart';
import '../models/filter_state.dart';
import '../models/terrain_profile_model.dart';
import '../services/terrain_elevation_service.dart';
import '../services/terrain_cache_service.dart';
import '../theme/astro_theme.dart';
import '../utils/astro_formatters.dart';
import '../widgets/interactive_horizon_canvas.dart';
import '../widgets/dialogs/refine_location_dialog.dart';

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

  // Mountain Silhouette / Terrain Horizon state
  TerrainProfileModel? _terrainProfile;
  late bool _showTerrainSilhouette;
  bool _isFetchingTerrain = false;
  double _fetchFraction = 0.0;
  String _fetchStatus = '';

  // Point Visibility & Zoom/Pan state
  bool _showPoints = true;
  double _zoomLevel = 1.0;
  double _viewStartAzimuth = 0.0;

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

    _terrainProfile = _state.terrainProfile;
    _showTerrainSilhouette = _state.showTerrainSilhouette;

    if (_panoramaPath != null && _panoramaPath!.isNotEmpty) {
      _loadDecodedImage(_panoramaPath!);
    }

    if (_terrainProfile == null) {
      _loadCachedTerrainProfile();
    }
  }

  @override
  void dispose() {
    _decodedImage?.dispose();
    super.dispose();
  }

  Future<void> _loadCachedTerrainProfile() async {
    final cached = await TerrainCacheService.loadProfile(
      _state.observerLat,
      _state.observerLon,
    );
    if (cached != null && mounted) {
      setState(() {
        _terrainProfile = cached;
      });
    }
  }

  Future<void> _detectMountainHorizon() async {
    setState(() {
      _isFetchingTerrain = true;
      _fetchFraction = 0.0;
      _fetchStatus = 'Connecting to AWS elevation tiles...';
    });

    try {
      final profile = await TerrainElevationService.generateProfile(
        latitude: _state.observerLat,
        longitude: _state.observerLon,
        observerKnownElevation: _state.observerElevation,
        onProgress: (frac, status) {
          if (mounted) {
            setState(() {
              _fetchFraction = frac;
              _fetchStatus = status;
            });
          }
        },
      );

      await TerrainCacheService.saveProfile(profile);

      if (mounted) {
        setState(() {
          _terrainProfile = profile;
          _showTerrainSilhouette = true;
          _isFetchingTerrain = false;
        });

        _promptApplyTerrainPoints(profile);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFetchingTerrain = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error fetching mountain horizon: please check internet connection ($e)"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _openRefineLocationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => RefineLocationDialog(
        isRedNightMode: widget.isRedNightMode,
        initialLocationName: _state.observerLocationName,
        initialLat: _state.observerLat,
        initialLon: _state.observerLon,
        initialElevation: _state.observerElevation,
        onApply: (locName, lat, lon, ele, rescan) {
          setState(() {
            _state = _state.copyWith(
              observerLocationName: locName,
              observerLat: lat,
              observerLon: lon,
              observerElevation: ele,
            );
          });
          if (rescan) {
            _detectMountainHorizon();
          } else {
            _loadCachedTerrainProfile();
          }
        },
      ),
    );
  }

  void _promptApplyTerrainPoints(TerrainProfileModel profile) {
    final simplified = profile.toSimplifiedHorizonPoints(epsilonDeg: 0.25);
    final count = simplified.length;

    showDialog(
      context: context,
      builder: (ctx) {
        final palette = AstroPalette.of(ctx);
        return AlertDialog(
          backgroundColor: palette.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: [
              Icon(Icons.terrain_rounded, color: palette.accent),
              const SizedBox(width: 8),
              const Text("Mountain Skyline Detected", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            "Successfully generated 360° mountain topography for ${_state.observerLocationName}!\n\n"
            "Would you like to apply these $count landmark peaks as your active horizon obstacle points? You can still adjust individual points afterwards.",
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Keep Silhouette Only"),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: palette.accent,
                foregroundColor: palette.isRedNightMode ? Colors.white : Colors.black,
              ),
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text("Apply as Horizon Points", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _points = List.from(simplified);
                _sortPoints();
                _selectedPointIndex = null;
              });
            },
          ),
        ],
      );
    },
  );
}

  void _applySimplifiedMountainPoints() {
    if (_terrainProfile == null) return;
    final simplified = _terrainProfile!.toSimplifiedHorizonPoints(epsilonDeg: 0.25);
    setState(() {
      _points = List.from(simplified);
      _sortPoints();
      _selectedPointIndex = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Applied ${simplified.length} mountain landmark points to active horizon"),
        backgroundColor: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan,
      ),
    );
  }

  void _sortPoints() {
    _points.sort((a, b) => a.azimuth.compareTo(b.azimuth));
  }

  Future<void> _loadDecodedImage(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Selected image file does not exist or cannot be accessed: $path"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    setState(() => _isLoadingImage = true);
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _decodedImage?.dispose();
          _decodedImage = frame.image;
          _panoramaPath = path;
          _isLoadingImage = false;
        });
      } else {
        frame.image.dispose();
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
    try {
      final path = await FilePickerService.pickPanoramaImage();
      if (path != null && path.isNotEmpty) {
        await _loadDecodedImage(path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error picking panorama image: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _clearImage() {
    _decodedImage?.dispose();
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
      _ensurePointVisible(_selectedPointIndex!);
    });
  }

  void _selectPreviousPoint() {
    if (_points.isEmpty || _selectedPointIndex == null) return;
    final newIdx = (_selectedPointIndex! - 1 + _points.length) % _points.length;
    setState(() {
      _selectedPointIndex = newIdx;
      _ensurePointVisible(newIdx);
    });
  }

  void _selectNextPoint() {
    if (_points.isEmpty || _selectedPointIndex == null) return;
    final newIdx = (_selectedPointIndex! + 1) % _points.length;
    setState(() {
      _selectedPointIndex = newIdx;
      _ensurePointVisible(newIdx);
    });
  }

  void _setZoom(double newZoom, {double? centerAzimuth}) {
    final clampedZoom = newZoom.clamp(1.0, 8.0);
    final oldSpan = 360.0 / _zoomLevel;
    final newSpan = 360.0 / clampedZoom;
    final center = centerAzimuth ?? (_viewStartAzimuth + oldSpan / 2.0);
    final newStart = (center - newSpan / 2.0).clamp(0.0, 360.0 - newSpan);
    setState(() {
      _zoomLevel = clampedZoom;
      _viewStartAzimuth = clampedZoom == 1.0 ? 0.0 : newStart;
    });
  }

  void _zoomIn() => _setZoom(_zoomLevel * 1.4);
  void _zoomOut() => _setZoom(_zoomLevel / 1.4);
  void _resetZoom() => setState(() {
    _zoomLevel = 1.0;
    _viewStartAzimuth = 0.0;
  });

  void _panView(double deltaAz) {
    if (_zoomLevel <= 1.0) return;
    final span = 360.0 / _zoomLevel;
    setState(() {
      _viewStartAzimuth = (_viewStartAzimuth + deltaAz).clamp(0.0, 360.0 - span);
    });
  }

  void _jumpToAzimuth(double targetAz) {
    final span = 360.0 / _zoomLevel;
    setState(() {
      _viewStartAzimuth = (targetAz - span / 2.0).clamp(0.0, 360.0 - span);
    });
  }

  void _ensurePointVisible(int idx) {
    if (_zoomLevel <= 1.0 || idx < 0 || idx >= _points.length) return;
    final p = _points[idx];
    final span = 360.0 / _zoomLevel;
    if (p.azimuth < _viewStartAzimuth + 15.0 || p.azimuth > _viewStartAzimuth + span - 15.0) {
      setState(() {
        _viewStartAzimuth = (p.azimuth - span / 2.0).clamp(0.0, 360.0 - span);
      });
    }
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
      showTerrainSilhouette: _showTerrainSilhouette,
      terrainProfile: _terrainProfile,
      observerLocationName: _state.observerLocationName,
      observerLat: _state.observerLat,
      observerLon: _state.observerLon,
      observerElevation: _state.observerElevation,
    );
    widget.onApply(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AstroPalette.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isNarrow = screenWidth < 700;
    final textColor = palette.textPrimary;
    final accentColor = palette.accent;

    final dialogContent = Container(
      width: isNarrow ? null : math.min(screenWidth * 0.94, 1180.0),
      height: isNarrow ? null : math.min(screenHeight * 0.90, 860.0),
      padding: EdgeInsets.all(isNarrow ? 12 : 18),
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

          // Active Terrain Scan Progress Bar
          if (_isFetchingTerrain) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: palette.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: _fetchFraction > 0 ? _fetchFraction : null,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _fetchStatus,
                          style: TextStyle(fontSize: 11, color: textColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${(_fetchFraction * 100).toInt()}%',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: accentColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: _fetchFraction > 0 ? _fetchFraction : null,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    color: accentColor,
                    minHeight: 3,
                  ),
                ],
              ),
            ),
          ],

          // Main Interactive Horizon Chart
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: palette.border,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return InteractiveHorizonCanvas(
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
                      terrainProfile: _terrainProfile,
                      showTerrainSilhouette: _showTerrainSilhouette,
                      showPoints: _showPoints,
                      zoomLevel: _zoomLevel,
                      viewStartAzimuth: _viewStartAzimuth,
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
                      onZoomChange: (newZoom, centerAz) => _setZoom(newZoom, centerAzimuth: centerAz),
                      onPanView: _panView,
                      onZoomIn: _zoomIn,
                      onZoomOut: _zoomOut,
                      onResetZoom: _resetZoom,
                    );
                  },
                ),
              ),
            ),
          ),
          if (_zoomLevel > 1.0) ...[
            const SizedBox(height: 6),
            _buildViewportScrubber(textColor, accentColor, isNarrow),
          ],

          // Panorama Calibration Controls (visible if image is loaded)
          if (_decodedImage != null) ...[
            const SizedBox(height: 6),
            _buildPanoramaControls(textColor, accentColor, isNarrow),
          ],

          // Point Selection & Micro-Adjustment Bar
          if (_selectedPointIndex != null && _selectedPointIndex! < _points.length) ...[
            const SizedBox(height: 6),
            _buildPointInspector(textColor, accentColor, isNarrow),
          ],

          const SizedBox(height: 8),

          // Bottom Action Bar
          if (isNarrow)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "${_points.length} points defined${_points.isNotEmpty ? ' • Profile Active' : ' • Flat default'}",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _points.isNotEmpty
                        ? (widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan)
                        : textColor.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text("Cancel", style: TextStyle(color: textColor.withValues(alpha: 0.7))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: widget.isRedNightMode ? Colors.white : Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text("Apply Horizon", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                        onPressed: _saveAndClose,
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
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
        backgroundColor: palette.surface,
        child: SafeArea(child: dialogContent),
      );
    } else {
      return Dialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: palette.border,
          ),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: dialogContent,
      );
    }
  }

  Widget _buildViewportScrubber(Color textColor, Color accentColor, bool isNarrow) {
    final palette = AstroPalette.of(context);
    final span = 360.0 / _zoomLevel;
    final minAz = _viewStartAzimuth.round();
    final maxAz = (_viewStartAzimuth + span).round();

    return Container(
      margin: const EdgeInsets.only(top: 2, bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: palette.border,
        ),
      ),
      child: isNarrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.pan_tool_alt_rounded, size: 14, color: accentColor),
                    const SizedBox(width: 6),
                    Text(
                      "$minAz°–$maxAz° (${_zoomLevel.toStringAsFixed(1)}x)",
                      style: TextStyle(
                        fontSize: 10,
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
                          value: _viewStartAzimuth.clamp(0.0, 360.0 - span),
                          min: 0.0,
                          max: (360.0 - span).clamp(0.0, 360.0),
                          activeColor: accentColor,
                          onChanged: (val) => setState(() => _viewStartAzimuth = val),
                        ),
                      ),
                    ),
                  ],
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _cardinalJumpBtn("N", 0.0, accentColor),
                      _cardinalJumpBtn("NE", 45.0, accentColor),
                      _cardinalJumpBtn("E", 90.0, accentColor),
                      _cardinalJumpBtn("SE", 135.0, accentColor),
                      _cardinalJumpBtn("S", 180.0, accentColor),
                      _cardinalJumpBtn("SW", 225.0, accentColor),
                      _cardinalJumpBtn("W", 270.0, accentColor),
                      _cardinalJumpBtn("NW", 315.0, accentColor),
                    ],
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Icon(Icons.pan_tool_alt_rounded, size: 14, color: accentColor),
                const SizedBox(width: 6),
                Text(
                  "Viewing: $minAz° – $maxAz° (${_zoomLevel.toStringAsFixed(1)}x)",
                  style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    ),
                    child: Slider(
                      value: _viewStartAzimuth.clamp(0.0, 360.0 - span),
                      min: 0.0,
                      max: (360.0 - span).clamp(0.0, 360.0),
                      activeColor: accentColor,
                      onChanged: (val) => setState(() => _viewStartAzimuth = val),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _cardinalJumpBtn("N", 0.0, accentColor),
                _cardinalJumpBtn("NE", 45.0, accentColor),
                _cardinalJumpBtn("E", 90.0, accentColor),
                _cardinalJumpBtn("SE", 135.0, accentColor),
                _cardinalJumpBtn("S", 180.0, accentColor),
                _cardinalJumpBtn("SW", 225.0, accentColor),
                _cardinalJumpBtn("W", 270.0, accentColor),
                _cardinalJumpBtn("NW", 315.0, accentColor),
              ],
            ),
    );
  }

  Widget _cardinalJumpBtn(String label, double az, Color accentColor) {
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

  Widget _buildToolbar(Color textColor, Color accentColor, bool isNarrow) {
    final viewAndLocationCluster = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilterChip(
          selected: _showPoints,
          label: Text(
            _showPoints ? "Points: ON" : "Points: OFF",
            style: TextStyle(fontSize: 11, color: textColor),
          ),
          avatar: Icon(
            _showPoints ? Icons.scatter_plot_rounded : Icons.visibility_off_outlined,
            size: 14,
            color: accentColor,
          ),
          selectedColor: accentColor.withValues(alpha: 0.25),
          onSelected: (val) => setState(() => _showPoints = val),
        ),
        const SizedBox(width: 8),
        ActionChip(
          avatar: Icon(Icons.pin_drop_rounded, size: 14, color: accentColor),
          label: Text(
            _state.observerLocationName.split(',').first.trim(),
            style: TextStyle(fontSize: 11, color: textColor),
            overflow: TextOverflow.ellipsis,
          ),
          tooltip: "Observer site: ${_state.observerLocationName}\n(${_state.observerLat.toStringAsFixed(4)}°, ${_state.observerLon.toStringAsFixed(4)}°, ${_state.observerElevation.round()}m)\nClick to refine street or neighborhood",
          onPressed: _openRefineLocationDialog,
        ),
      ],
    );

    final mountainCluster = _isFetchingTerrain
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accentColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: accentColor),
                ),
                const SizedBox(width: 8),
                Text("Scanning Horizon...", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
              ],
            ),
          )
        : (_terrainProfile == null
            ? FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor.withValues(alpha: 0.18),
                  foregroundColor: accentColor,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  side: BorderSide(color: accentColor.withValues(alpha: 0.5)),
                ),
                icon: Icon(Icons.terrain_rounded, size: 16, color: accentColor),
                label: Text(
                  "Detect Mountains (Online DEM)",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                ),
                onPressed: _detectMountainHorizon,
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilterChip(
                    selected: _showTerrainSilhouette,
                    label: Text(
                      _showTerrainSilhouette ? "Mountain Silhouette: ON" : "Mountain Silhouette: OFF",
                      style: TextStyle(fontSize: 11, color: textColor),
                    ),
                    avatar: Icon(Icons.landscape_rounded, size: 14, color: accentColor),
                    selectedColor: accentColor.withValues(alpha: 0.25),
                    onSelected: (val) => setState(() => _showTerrainSilhouette = val),
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: Icon(Icons.auto_fix_high_rounded, size: 14, color: accentColor),
                    label: const Text("Apply Peaks to Points", style: TextStyle(fontSize: 11)),
                    onPressed: _applySimplifiedMountainPoints,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: "Clear Mountain Data",
                    icon: const Icon(Icons.layers_clear_rounded, size: 17, color: Colors.white54),
                    onPressed: () => setState(() => _terrainProfile = null),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: "Re-scan Mountain Profile",
                    icon: Icon(Icons.refresh_rounded, size: 17, color: accentColor),
                    onPressed: _detectMountainHorizon,
                  ),
                ],
              ));

    final panoramaCluster = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
            _decodedImage != null ? "Change Panorama..." : "Import Panorama Image...",
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
      ],
    );

    final presetsCluster = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
    );

    if (isNarrow) {
      return ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              viewAndLocationCluster,
              const SizedBox(width: 8),
              mountainCluster,
              const SizedBox(width: 8),
              panoramaCluster,
              const SizedBox(width: 8),
              presetsCluster,
            ],
          ),
        ),
      );
    } else {
      return Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          viewAndLocationCluster,
          mountainCluster,
          panoramaCluster,
          presetsCluster,
        ],
      );
    }
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
              Flexible(
                child: Text(
                  "Panorama Alignment & Calibration",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                ),
              ),
              if (!isNarrow) ...[
                const Spacer(),
                Text(
                  "North: ${_azimuthOffset.round()}° | Level: ${_altitudeOffset.round()}° | Opacity: ${(_imageOpacity * 100).round()}%",
                  style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: textColor.withValues(alpha: 0.7)),
                ),
              ],
            ],
          ),
          if (isNarrow)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 2),
              child: Text(
                "North: ${_azimuthOffset.round()}° | Level: ${_altitudeOffset.round()}° | Opacity: ${(_imageOpacity * 100).round()}%",
                style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: textColor.withValues(alpha: 0.7)),
              ),
            ),
          if (isNarrow) ...[
            Row(
              children: [
                SizedBox(
                  width: 70,
                  child: Text("Pan (N):", style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.8))),
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
              ],
            ),
            Row(
              children: [
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
              ],
            ),
            Row(
              children: [
                SizedBox(
                  width: 70,
                  child: Text("Opacity:", style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.8))),
                ),
                Expanded(
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
          ] else ...[
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
        ],
      ),
    );
  }

  Widget _buildPointInspector(Color textColor, Color accentColor, bool isNarrow) {
    final p = _points[_selectedPointIndex!];
    final steppers = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: "Previous Point (<)",
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.navigate_before_rounded, size: 20),
          onPressed: _points.length > 1 ? _selectPreviousPoint : null,
        ),
        IconButton(
          tooltip: "Next Point (>)",
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.navigate_next_rounded, size: 20),
          onPressed: _points.length > 1 ? _selectNextPoint : null,
        ),
        Container(
          width: 1,
          height: 18,
          color: textColor.withValues(alpha: 0.2),
          margin: const EdgeInsets.symmetric(horizontal: 3),
        ),
        IconButton(
          tooltip: "-1° Azimuth",
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.arrow_left_rounded, size: 20),
          onPressed: () => _adjustSelectedPoint(-1.0, 0.0),
        ),
        IconButton(
          tooltip: "+1° Azimuth",
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.arrow_right_rounded, size: 20),
          onPressed: () => _adjustSelectedPoint(1.0, 0.0),
        ),
        IconButton(
          tooltip: "-1° Altitude",
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
          onPressed: () => _adjustSelectedPoint(0.0, -1.0),
        ),
        IconButton(
          tooltip: "+1° Altitude",
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.arrow_drop_up_rounded, size: 20),
          onPressed: () => _adjustSelectedPoint(0.0, 1.0),
        ),
        const SizedBox(width: 4),
        if (isNarrow)
          IconButton(
            tooltip: "Delete Point",
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
              foregroundColor: Colors.redAccent,
            ),
            icon: const Icon(Icons.delete_rounded, size: 16),
            onPressed: _deleteSelectedPoint,
          )
        else
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.25),
              foregroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            icon: const Icon(Icons.delete_rounded, size: 14),
            label: const Text("Delete", style: TextStyle(fontSize: 11)),
            onPressed: _deleteSelectedPoint,
          ),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withValues(alpha: 0.4)),
      ),
      child: isNarrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.adjust_rounded, size: 14, color: accentColor),
                    const SizedBox(width: 4),
                    Text(
                      "#${_selectedPointIndex! + 1}/${_points.length}: ",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    Expanded(
                      child: Text(
                        "Az: ${p.azimuth.toStringAsFixed(1)}° (${_cardinal(p.azimuth)}) • Alt: ${p.altitude.toStringAsFixed(1)}°",
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: steppers,
                ),
              ],
            )
          : Row(
              children: [
                Icon(Icons.adjust_rounded, size: 15, color: accentColor),
                const SizedBox(width: 6),
                Text(
                  "Point #${_selectedPointIndex! + 1} of ${_points.length}: ",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                ),
                Text(
                  "Az: ${p.azimuth.toStringAsFixed(1)}° (${_cardinal(p.azimuth)})  |  Alt: ${p.altitude.toStringAsFixed(1)}°",
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
                const Spacer(),
                steppers,
              ],
            ),
    );
  }

  String _cardinal(double az) => AstroFormatters.cardinalFromAzimuth(az);
}
