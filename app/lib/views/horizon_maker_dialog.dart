import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../core/file_picker_service.dart';
import '../core/geocoding_service.dart';
import '../models/filter_state.dart';
import '../models/terrain_profile_model.dart';
import '../services/terrain_elevation_service.dart';
import '../services/terrain_cache_service.dart';
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
    final searchCtrl = TextEditingController();
    final latCtrl = TextEditingController(text: _state.observerLat.toStringAsFixed(4));
    final lonCtrl = TextEditingController(text: _state.observerLon.toStringAsFixed(4));
    final eleCtrl = TextEditingController(text: _state.observerElevation.round().toString());
    String locName = _state.observerLocationName;
    List<GeoLocationResult> results = [];
    bool isSearching = false;
    String? searchError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
          final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;

          Future<void> doSearch() async {
            final q = searchCtrl.text.trim();
            if (q.length < 2) return;
            setDlgState(() {
              isSearching = true;
              searchError = null;
            });
            try {
              final res = await GeocodingService.searchPreciseAddress(q);
              setDlgState(() {
                results = res;
                isSearching = false;
                if (res.isEmpty) {
                  searchError = "No matching street or neighborhood found for '$q'.";
                }
              });
            } catch (e) {
              setDlgState(() {
                isSearching = false;
                searchError = "Connection error. Check internet connection.";
              });
            }
          }

          return AlertDialog(
            backgroundColor: widget.isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder,
              ),
            ),
            title: Row(
              children: [
                Icon(Icons.pin_drop_rounded, color: accentColor, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Refine Observer Location",
                    style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: textColor.withValues(alpha: 0.6)),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Pinpointing your exact observing site (street, neighborhood, or rural site) ensures mountain viewshed raymarching matches your visual horizon.",
                      style: TextStyle(fontSize: 12, height: 1.3, color: textColor.withValues(alpha: 0.7)),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Search Street / Neighborhood / Landmark:",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accentColor),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: "e.g. Cônego, Nova Friburgo or Rua...",
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                          tooltip: "Search address worldwide",
                          onPressed: doSearch,
                        ),
                      ),
                      onSubmitted: (_) => doSearch(),
                    ),
                    if (isSearching) ...[
                      const SizedBox(height: 6),
                      const LinearProgressIndicator(),
                    ],
                    if (searchError != null) ...[
                      const SizedBox(height: 6),
                      Text(searchError!, style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.6))),
                    ],
                    if (results.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 160),
                        decoration: BoxDecoration(
                          color: widget.isRedNightMode ? AstroColors.nightVisionSurfaceVariant : AstroColors.spaceDarkSurfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder,
                          ),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: results.length,
                          separatorBuilder: (ctx, index) => const Divider(height: 1),
                          itemBuilder: (context, idx) {
                            final r = results[idx];
                            return ListTile(
                              dense: true,
                              leading: Icon(Icons.location_on_outlined, size: 16, color: accentColor),
                              title: Text(r.displayName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
                              subtitle: Text(
                                "Lat: ${r.latitude.toStringAsFixed(4)}° | Lon: ${r.longitude.toStringAsFixed(4)}°",
                                style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.6)),
                              ),
                              onTap: () async {
                                setDlgState(() {
                                  latCtrl.text = r.latitude.toStringAsFixed(4);
                                  lonCtrl.text = r.longitude.toStringAsFixed(4);
                                  locName = r.displayName;
                                  results = [];
                                });
                                final elev = await GeocodingService.fetchElevation(r.latitude, r.longitude);
                                if (elev != null) {
                                  setDlgState(() {
                                    eleCtrl.text = elev.round().toString();
                                  });
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      "Exact Coordinates & Elevation (Meters):",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor.withValues(alpha: 0.8)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: latCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            decoration: const InputDecoration(labelText: "Latitude (°)"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: lonCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            decoration: const InputDecoration(labelText: "Longitude (°)"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 90,
                          child: TextField(
                            controller: eleCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: "Elev (m)"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("Cancel"),
              ),
              OutlinedButton(
                onPressed: () {
                  final lat = double.tryParse(latCtrl.text) ?? _state.observerLat;
                  final lon = double.tryParse(lonCtrl.text) ?? _state.observerLon;
                  final ele = double.tryParse(eleCtrl.text) ?? _state.observerElevation;
                  Navigator.of(ctx).pop();
                  setState(() {
                    _state = _state.copyWith(
                      observerLocationName: locName,
                      observerLat: lat,
                      observerLon: lon,
                      observerElevation: ele,
                    );
                  });
                  _loadCachedTerrainProfile();
                },
                child: const Text("Apply Location"),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: widget.isRedNightMode ? Colors.white : Colors.black,
                ),
                icon: const Icon(Icons.radar_rounded, size: 16),
                label: const Text("Apply & Re-scan Mountains", style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  final lat = double.tryParse(latCtrl.text) ?? _state.observerLat;
                  final lon = double.tryParse(lonCtrl.text) ?? _state.observerLon;
                  final ele = double.tryParse(eleCtrl.text) ?? _state.observerElevation;
                  Navigator.of(ctx).pop();
                  setState(() {
                    _state = _state.copyWith(
                      observerLocationName: locName,
                      observerLat: lat,
                      observerLon: lon,
                      observerElevation: ele,
                    );
                  });
                  _detectMountainHorizon();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _promptApplyTerrainPoints(TerrainProfileModel profile) {
    final simplified = profile.toSimplifiedHorizonPoints(epsilonDeg: 0.25);
    final count = simplified.length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(Icons.terrain_rounded, color: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan),
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
              backgroundColor: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan,
              foregroundColor: widget.isRedNightMode ? Colors.white : Colors.black,
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
      ),
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
    final isNarrow = MediaQuery.of(context).size.width < 700;
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;

    final dialogContent = Container(
      width: isNarrow ? null : 880,
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

          // Active Terrain Scan Progress Bar
          if (_isFetchingTerrain) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: widget.isRedNightMode ? const Color(0xFF200606) : const Color(0xFF0F1B2B),
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
          if (_zoomLevel > 1.0)
            _buildViewportScrubber(textColor, accentColor),
          const SizedBox(height: 10),

          // Panorama Calibration Controls (visible if image is loaded)
          if (_decodedImage != null)
            _buildPanoramaControls(textColor, accentColor, isNarrow),

          // Point Selection & Micro-Adjustment Bar
          if (_selectedPointIndex != null && _selectedPointIndex! < _points.length)
            _buildPointInspector(textColor, accentColor, isNarrow),

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

  Widget _buildViewportScrubber(Color textColor, Color accentColor) {
    final span = 360.0 / _zoomLevel;
    final minAz = _viewStartAzimuth.round();
    final maxAz = (_viewStartAzimuth + span).round();

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // Point Handles Visibility Toggle
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

          // Observer Location Display & Refine Button
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
          const SizedBox(width: 8),

          // Mountain Profile Button & Controls (Online DEM)
          if (_isFetchingTerrain) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentColor.withValues(alpha: 0.4)),
              ),
              child: Row(
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
            ),
          ] else if (_terrainProfile == null) ...[
            FilledButton.icon(
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
            ),
          ] else ...[
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
          const SizedBox(width: 12),
          Container(width: 1, height: 24, color: textColor.withValues(alpha: 0.2)),
          const SizedBox(width: 12),

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
          icon: const Icon(Icons.navigate_before_rounded, size: 22),
          onPressed: _points.length > 1 ? _selectPreviousPoint : null,
        ),
        IconButton(
          tooltip: "Next Point (>)",
          icon: const Icon(Icons.navigate_next_rounded, size: 22),
          onPressed: _points.length > 1 ? _selectNextPoint : null,
        ),
        Container(
          width: 1,
          height: 18,
          color: textColor.withValues(alpha: 0.2),
          margin: const EdgeInsets.symmetric(horizontal: 4),
        ),
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
        const SizedBox(width: 4),
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
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withValues(alpha: 0.4)),
      ),
      child: isNarrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.adjust_rounded, size: 15, color: accentColor),
                    const SizedBox(width: 6),
                    Text(
                      "Point #${_selectedPointIndex! + 1} of ${_points.length}: ",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    Expanded(
                      child: Text(
                        "Az: ${p.azimuth.toStringAsFixed(1)}° (${_cardinal(p.azimuth)}) | Alt: ${p.altitude.toStringAsFixed(1)}°",
                        style: TextStyle(
                            fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: accentColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
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
                      fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: accentColor),
                ),
                const Spacer(),
                steppers,
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
/// and obstacle mask with interactive point dragging and sector zoom/pan.
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
  State<_InteractiveHorizonCanvas> createState() => _InteractiveHorizonCanvasState();
}

class _InteractiveHorizonCanvasState extends State<_InteractiveHorizonCanvas> {
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
  final TerrainProfileModel? terrainProfile;
  final bool showTerrainSilhouette;
  final bool showPoints;
  final double zoomLevel;
  final double viewStartAzimuth;

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
    this.terrainProfile,
    this.showTerrainSilhouette = true,
    this.showPoints = true,
    this.zoomLevel = 1.0,
    this.viewStartAzimuth = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(
      _InteractiveHorizonCanvasState.leftMargin,
      _InteractiveHorizonCanvasState.topMargin,
      math.max(10.0, size.width - _InteractiveHorizonCanvasState.leftMargin - _InteractiveHorizonCanvasState.rightMargin),
      math.max(10.0, size.height - _InteractiveHorizonCanvasState.topMargin - _InteractiveHorizonCanvasState.bottomMargin),
    );

    final visibleAzSpan = 360.0 / zoomLevel;
    double azToX(double az) => r.left + ((az - viewStartAzimuth) / visibleAzSpan) * r.width;
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

      // Full 360 cycle width at current zoom
      final fullCycleWidth = r.width * zoomLevel;
      final startX = azToX(0.0) - (azimuthOffset / 360.0) * fullCycleWidth;

      final srcRect = Rect.fromLTWH(0, 0, imgW, imgH);

      final minTile = ((r.left - startX) / fullCycleWidth).floor() - 1;
      final maxTile = ((r.right - startX) / fullCycleWidth).ceil() + 1;

      for (int t = minTile; t <= maxTile; t++) {
        final dest = Rect.fromLTWH(startX + t * fullCycleWidth, destY, fullCycleWidth, destH);
        canvas.drawImageRect(decodedImage!, srcRect, dest, paintImg);
      }

      canvas.restore();
    }

    // 1.5. Draw Mountain Silhouette Backdrop (Vector Topography)
    if (showTerrainSilhouette && terrainProfile != null && terrainProfile!.altitudes.isNotEmpty) {
      _drawMountainSilhouette(canvas, r, azToX, altToY);
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

  void _drawMountainSilhouette(
    Canvas canvas,
    Rect r,
    double Function(double) azToX,
    double Function(double) altToY,
  ) {
    if (terrainProfile == null || terrainProfile!.altitudes.isEmpty) return;

    canvas.save();
    canvas.clipRect(r);

    final path = Path();
    final fillPath = Path();

    final n = terrainProfile!.altitudes.length;
    final step = terrainProfile!.stepDeg;

    final firstAlt = terrainProfile!.altitudes[0];
    final lastAlt = terrainProfile!.altitudes.first;

    path.moveTo(azToX(0.0), altToY(firstAlt));
    fillPath.moveTo(azToX(0.0), r.bottom);
    fillPath.lineTo(azToX(0.0), altToY(firstAlt));

    for (int i = 0; i < n; i++) {
      final az = i * step;
      final alt = terrainProfile!.altitudes[i];
      final px = azToX(az);
      final py = altToY(alt);
      path.lineTo(px, py);
      fillPath.lineTo(px, py);
    }

    path.lineTo(azToX(360.0), altToY(lastAlt));
    fillPath.lineTo(azToX(360.0), altToY(lastAlt));
    fillPath.lineTo(azToX(360.0), r.bottom);
    fillPath.close();

    // Twilight mountain gradient fill (dark midnight slate into mountain ridge)
    final fillGradient = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: isRedNightMode
          ? [
              const Color(0xFF140303).withValues(alpha: 0.95),
              const Color(0xFF2E0808).withValues(alpha: 0.90),
            ]
          : [
              const Color(0xFF070E1A).withValues(alpha: 0.95),
              const Color(0xFF16253B).withValues(alpha: 0.90),
            ],
    );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(r)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Mountain ridge highlight stroke
    final strokePaint = Paint()
      ..color = (isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan).withValues(alpha: 0.70)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    canvas.restore();
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
        canvas.drawRect(Rect.fromLTRB(azToX(0.0), r.top, xMin, r.bottom), dimPaint);
        canvas.drawLine(Offset(xMin, r.top), Offset(xMin, r.bottom), boundLinePaint);
      }
      if (maxAzimuth < 360) {
        canvas.drawRect(Rect.fromLTRB(xMax, r.top, azToX(360.0), r.bottom), dimPaint);
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

    // Determine grid step based on zoomLevel
    final double azStep;
    if (zoomLevel >= 4.5) {
      azStep = 5.0;
    } else if (zoomLevel >= 2.2) {
      azStep = 15.0;
    } else {
      azStep = 45.0;
    }

    final visibleAzSpan = 360.0 / zoomLevel;
    final firstAz = (viewStartAzimuth / azStep).floor() * azStep;
    final lastAz = ((viewStartAzimuth + visibleAzSpan) / azStep).ceil() * azStep;

    for (double az = firstAz; az <= lastAz; az += azStep) {
      final x = azToX(az);
      if (x < r.left - 1 || x > r.right + 1) continue;

      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), gridPaint);

      // Check cardinal label
      final cardinal = _cardinalForAz(az);
      if (cardinal != null) {
        final tpCard = TextPainter(
          text: TextSpan(text: cardinal, style: cardinalLabelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tpCard.paint(canvas, Offset(x - tpCard.width / 2, r.bottom + 4));
      }

      // Degree label
      final tpDeg = TextPainter(
        text: TextSpan(text: "${az.round()}°", style: axisLabelStyle.copyWith(fontSize: 8)),
        textDirection: TextDirection.ltr,
      )..layout();
      tpDeg.paint(canvas, Offset(x - tpDeg.width / 2, r.bottom + 16));
    }
  }

  String? _cardinalForAz(double az) {
    final a = (az.round() % 360 + 360) % 360;
    switch (a) {
      case 0:
        return "N";
      case 45:
        return "NE";
      case 90:
        return "E";
      case 135:
        return "SE";
      case 180:
        return "S";
      case 225:
        return "SW";
      case 270:
        return "W";
      case 315:
        return "NW";
      default:
        return null;
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

    path.moveTo(azToX(0.0), altToY(altAt0));
    fillPath.moveTo(azToX(0.0), r.bottom);
    fillPath.lineTo(azToX(0.0), altToY(altAt0));

    for (final p in points) {
      final px = azToX(p.azimuth);
      final py = altToY(p.altitude);
      path.lineTo(px, py);
      fillPath.lineTo(px, py);
    }

    path.lineTo(azToX(360.0), altToY(altAt360));
    fillPath.lineTo(azToX(360.0), altToY(altAt360));
    fillPath.lineTo(azToX(360.0), r.bottom);
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
      final isSelected = selectedIndex == i;
      final isDragging = draggedIndex == i;

      // If point visibility is toggled off, only draw the currently selected/dragged point
      if (!showPoints && !isSelected && !isDragging) {
        continue;
      }

      final px = azToX(p.azimuth);
      final py = altToY(p.altitude);

      // Skip drawing if outside chart bounds with margin
      if (px < r.left - 30 || px > r.right + 30) continue;

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
