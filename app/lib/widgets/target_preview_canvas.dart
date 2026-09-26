import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/equipment_manager.dart';
import '../core/sky_image_service.dart';
import '../models/equipment_profile.dart';
import '../models/target_item.dart';
import '../theme/astro_theme.dart';
import '../views/equipment_dialog.dart';
import '../views/equipment_framing_dialog.dart';
import '../l10n/app_localizations.dart';
import 'fov_projector.dart';

enum PreviewDisplayMode {
  photoWithReticle,
  photoOnly,
  vectorOnly,
}

class TargetPreviewCanvas extends StatefulWidget {
  final TargetItem target;
  final bool isRedNightMode;
  final double height;
  final bool enableExpandDialog;
  final bool initialFramingEnabled;

  const TargetPreviewCanvas({
    super.key,
    required this.target,
    required this.isRedNightMode,
    this.height = 240.0,
    this.enableExpandDialog = true,
    this.initialFramingEnabled = false,
  });

  @override
  State<TargetPreviewCanvas> createState() => TargetPreviewCanvasState();
}

class TargetPreviewCanvasState extends State<TargetPreviewCanvas> {
  late double _fovDeg;
  String _selectedSurveyId = SkyImageService.defaultSurveyId;
  PreviewDisplayMode _displayMode = PreviewDisplayMode.photoWithReticle;
  late bool _isFramingEnabled;

  Uint8List? _imageBytes;
  bool _isLoading = false;
  bool _hasError = false;

  Timer? _panDebounceTimer;
  double _imageBasePanX = 0.0;
  double _imageBasePanY = 0.0;
  double _lastObservedPanX = 0.0;
  double _lastObservedPanY = 0.0;
  int _imageLoadRequestId = 0;
  String _lastActiveProfileId = '';
  static double _zoomStepPercent = 0.25;

  @override
  void initState() {
    super.initState();
    _isFramingEnabled = widget.initialFramingEnabled;
    _lastActiveProfileId = EquipmentManager.instance.activeProfile.id;
    if (_isFramingEnabled) {
      final rig = EquipmentManager.instance.activeProfile;
      _fovDeg = (rig.sensorFovDiagonalDeg * 1.35).clamp(0.15, 14.0);
    } else if (widget.target.catalog == 'Solar System') {
      _displayMode = PreviewDisplayMode.vectorOnly;
      _fovDeg = (widget.target.name == 'Sun' || widget.target.name == 'Moon') ? 1.5 : 0.25;
    } else {
      _fovDeg = SkyImageService.computeRecommendedFovDeg(widget.target.majorAxisArcmin);
    }
    _imageBasePanX = EquipmentManager.instance.panOffsetArcminX;
    _imageBasePanY = EquipmentManager.instance.panOffsetArcminY;
    _lastObservedPanX = _imageBasePanX;
    _lastObservedPanY = _imageBasePanY;
    EquipmentManager.instance.addListener(_onEquipmentStateChanged);
    _loadImage();
  }

  @override
  void dispose() {
    _panDebounceTimer?.cancel();
    EquipmentManager.instance.removeListener(_onEquipmentStateChanged);
    super.dispose();
  }

  void _onEquipmentStateChanged() {
    if (!mounted) return;

    final currentProfileId = EquipmentManager.instance.activeProfile.id;
    if (currentProfileId != _lastActiveProfileId) {
      _lastActiveProfileId = currentProfileId;
      if (_isFramingEnabled) {
        _fitToSensor();
      }
    }

    final currentPanX = EquipmentManager.instance.panOffsetArcminX;
    final currentPanY = EquipmentManager.instance.panOffsetArcminY;

    if (currentPanX != _lastObservedPanX || currentPanY != _lastObservedPanY) {
      _lastObservedPanX = currentPanX;
      _lastObservedPanY = currentPanY;

      _panDebounceTimer?.cancel();
      _panDebounceTimer = Timer(const Duration(milliseconds: 350), () {
        if (mounted) {
          _loadImage();
        }
      });
    }

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant TargetPreviewCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target.id != widget.target.id) {
      _panDebounceTimer?.cancel();
      _fovDeg = SkyImageService.computeRecommendedFovDeg(widget.target.majorAxisArcmin);
      _imageBytes = null;
      _hasError = false;
      _imageBasePanX = EquipmentManager.instance.panOffsetArcminX;
      _imageBasePanY = EquipmentManager.instance.panOffsetArcminY;
      _lastObservedPanX = _imageBasePanX;
      _lastObservedPanY = _imageBasePanY;
      _loadImage();
    }
  }

  /// Current Field of View in degrees
  double get fovDeg => _fovDeg;

  /// Allows external callers (e.g. Fit to Sensor) to set custom FOV
  void setCustomFov(double fovDeg) {
    final clamped = fovDeg.clamp(0.15, 14.0);
    setState(() => _fovDeg = clamped);
    _loadImage();
  }

  double get _currentCenterRaHours {
    final panX = EquipmentManager.instance.panOffsetArcminX;
    final panY = EquipmentManager.instance.panOffsetArcminY;
    if (panX == 0.0 && panY == 0.0) {
      return widget.target.raHours;
    }
    final dRaArcminOnSky = -panX;
    final decRad = widget.target.decDegrees * math.pi / 180.0;
    final cosDec = math.cos(decRad).abs().clamp(0.01, 1.0);
    final dRaHours = (dRaArcminOnSky / cosDec) / 900.0;
    var ra = (widget.target.raHours + dRaHours) % 24.0;
    if (ra < 0) ra += 24.0;
    return ra;
  }

  double get _currentCenterDecDegrees {
    final panY = EquipmentManager.instance.panOffsetArcminY;
    if (panY == 0.0) {
      return widget.target.decDegrees;
    }
    final dDecDeg = -panY / 60.0;
    return (widget.target.decDegrees + dDecDeg).clamp(-90.0, 90.0);
  }

  void _loadImage() async {
    final reqId = ++_imageLoadRequestId;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final centerRa = _currentCenterRaHours;
    final centerDec = _currentCenterDecDegrees;
    final reqPanX = EquipmentManager.instance.panOffsetArcminX;
    final reqPanY = EquipmentManager.instance.panOffsetArcminY;

    final url = SkyImageService.buildHiPSUrl(
      raHours: centerRa,
      decDegrees: centerDec,
      fovDeg: _fovDeg,
      surveyId: _selectedSurveyId,
      width: 512,
      height: 512,
    );

    final bytes = await SkyImageService.instance.fetchSkyImage(url);

    if (mounted && reqId == _imageLoadRequestId) {
      setState(() {
        _isLoading = false;
        if (bytes != null && bytes.isNotEmpty) {
          _imageBytes = bytes;
          _imageBasePanX = reqPanX;
          _imageBasePanY = reqPanY;
          _hasError = false;
        } else {
          _hasError = true;
          if (_imageBytes == null) {
            _displayMode = PreviewDisplayMode.vectorOnly;
          }
        }
      });
    }
  }

  double get zoomStepPercent => _zoomStepPercent;
  void setZoomStepPercent(double step) {
    if ((_zoomStepPercent - step).abs() > 0.001) {
      setState(() => _zoomStepPercent = step);
    }
  }

  void _zoomIn() {
    final factor = 1.0 + _zoomStepPercent;
    final newFov = (_fovDeg / factor).clamp(0.15, 14.0);
    if (newFov != _fovDeg) {
      setState(() => _fovDeg = newFov);
      _loadImage();
    }
  }

  void _zoomOut() {
    final factor = 1.0 + _zoomStepPercent;
    final newFov = (_fovDeg * factor).clamp(0.15, 14.0);
    if (newFov != _fovDeg) {
      setState(() => _fovDeg = newFov);
      _loadImage();
    }
  }

  void _resetFov() {
    final defaultFov = SkyImageService.computeRecommendedFovDeg(widget.target.majorAxisArcmin);
    if (defaultFov != _fovDeg) {
      setState(() => _fovDeg = defaultFov);
      _loadImage();
    }
  }

  void _fitToSensor() {
    final rig = EquipmentManager.instance.activeProfile;
    final diag = rig.sensorFovDiagonalDeg;
    setCustomFov(diag * 1.35);
  }

  void fitToSensor() => _fitToSensor();

  void _openFramingSimulatorDialog() {
    if (!widget.enableExpandDialog) return;

    showDialog(
      context: context,
      builder: (ctx) => EquipmentFramingDialog(
        target: widget.target,
        isRedNightMode: widget.isRedNightMode,
      ),
    );
  }

  void _openEquipmentManagerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => EquipmentDialog(
        isRedNightMode: widget.isRedNightMode,
        onSaved: () => setState(() {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;
    final borderColor = widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder;
    final surfaceColor = widget.isRedNightMode ? AstroColors.nightVisionSurfaceVariant : AstroColors.spaceDarkSurfaceVariant;

    final fovArcmin = _fovDeg * 60.0;
    final fovString = fovArcmin >= 60.0
        ? "${_fovDeg.toStringAsFixed(1)}°"
        : "${fovArcmin.toStringAsFixed(0)}'";

    final showPhoto = _imageBytes != null && _displayMode != PreviewDisplayMode.vectorOnly;
    final isPhotoOnly = _displayMode == PreviewDisplayMode.photoOnly;
    final showReticle = _displayMode == PreviewDisplayMode.photoWithReticle;

    final rig = EquipmentManager.instance.activeProfile;
    final angle = EquipmentManager.instance.cameraAngleDeg;
    final showRuleOfThirds = EquipmentManager.instance.showRuleOfThirds;
    final panX = EquipmentManager.instance.panOffsetArcminX;
    final panY = EquipmentManager.instance.panOffsetArcminY;

    final imageViewport = Container(
      height: widget.height.isFinite ? widget.height : null,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final effectiveWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 400.0;
          final effectiveHeight = constraints.maxHeight.isFinite ? constraints.maxHeight : (widget.height.isFinite ? widget.height : 400.0);
          final minDim = math.min(effectiveWidth, effectiveHeight);
          final pixelsPerArcmin = minDim / fovArcmin;
          final shiftX = -(panX - _imageBasePanX) * pixelsPerArcmin;
          final shiftY = -(panY - _imageBasePanY) * pixelsPerArcmin;

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. Photographic Sky Image Layer (dynamically shifted during real-time panning before debounced tile loads)
              if (showPhoto)
                Transform.translate(
                  offset: Offset(shiftX, shiftY),
                  child: Image.memory(
                    _imageBytes!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                    color: widget.isRedNightMode ? AstroColors.nightVisionRed : null,
                    colorBlendMode: widget.isRedNightMode ? BlendMode.modulate : null,
                  ),
                ),

              // 2. Vector Sky Canvas Layer (Apparent size ellipse, reticle, scale, and sensor box)
              CustomPaint(
                painter: TargetVectorPainter(
                  target: widget.target,
                  fovDeg: _fovDeg,
                  isRedNightMode: widget.isRedNightMode,
                  isVectorOnly: _displayMode == PreviewDisplayMode.vectorOnly || (!showPhoto && !isPhotoOnly),
                  isPhotoOnly: isPhotoOnly,
                  showReticle: showReticle,
                  showFraming: _isFramingEnabled,
                  equipment: rig,
                  cameraAngleDeg: angle,
                  showRuleOfThirds: showRuleOfThirds,
                  panOffsetArcminX: panX,
                  panOffsetArcminY: panY,
                ),
              ),

              // 3. Subtle HiPS Loading indicator (top-right of image)
              if (_isLoading)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          "Streaming HiPS...",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
                        ),
                      ],
                    ),
                  ),
                ),

              // 4. Offline / Error Status Banner
              if (_hasError && _imageBytes == null)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 14, color: Colors.amber),
                        const SizedBox(width: 6),
                        Text(
                          l10n?.offlineSkyFallback ?? "Offline Sky Fallback",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );

    final controlsPanel = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),

        // Row 1: Primary Controls & Settings (Survey, FOV, Mode, Framing, Simulator)
        LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
              // Survey Selector Chip
              PopupMenuButton<String>(
                tooltip: l10n?.selectSkySurveyTooltip ?? "Select Sky Survey",
                color: widget.isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: borderColor),
                ),
                initialValue: _selectedSurveyId,
                onSelected: (surveyId) {
                  setState(() {
                    _selectedSurveyId = surveyId;
                    _displayMode = PreviewDisplayMode.photoWithReticle;
                  });
                  _loadImage();
                },
                itemBuilder: (ctx) => SkyImageService.availableSurveys.map((s) {
                  return PopupMenuItem<String>(
                    value: s.id,
                    height: 40,
                    child: Text(
                      s.label,
                      style: TextStyle(
                        fontSize: 13,
                        color: s.id == _selectedSurveyId ? accentColor : textColor,
                        fontWeight: s.id == _selectedSurveyId ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: widget.isRedNightMode
                        ? AstroColors.nightVisionSurfaceVariant
                        : AstroColors.spaceDarkSurfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.layers_rounded, size: 16, color: accentColor),
                      const SizedBox(width: 6),
                      Text(
                        SkyImageService.availableSurveys
                            .firstWhere((s) => s.id == _selectedSurveyId,
                                orElse: () => SkyImageService.availableSurveys.first)
                            .label,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textColor),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down_rounded, size: 18, color: textColor.withValues(alpha: 0.7)),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Full Framing Simulator Button
              if (widget.enableExpandDialog) ...[
                const SizedBox(width: 8),
                Tooltip(
                  message: l10n?.openFramingSimulatorTooltip ?? "Open Full Framing Simulator",
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _openFramingSimulatorDialog,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: widget.isRedNightMode
                              ? AstroColors.nightVisionSurfaceVariant
                              : AstroColors.spaceDarkSurfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starGold,
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.open_in_full_rounded,
                              size: 15,
                              color: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starGold,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              l10n?.framingSimulatorShort ?? "Simulator",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starGold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(width: 8),

              // Framing Simulator Mode Toggle
              Tooltip(
                message: l10n?.toggleFramingBoxTooltip ?? "Toggle Sensor Framing Box",
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() => _isFramingEnabled = !_isFramingEnabled);
                      if (_isFramingEnabled) {
                        _fitToSensor();
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: _isFramingEnabled
                            ? (widget.isRedNightMode
                                ? AstroColors.nightVisionRed.withValues(alpha: 0.22)
                                : AstroColors.starGold.withValues(alpha: 0.22))
                            : (widget.isRedNightMode
                                ? AstroColors.nightVisionSurfaceVariant
                                : AstroColors.spaceDarkSurfaceVariant),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isFramingEnabled
                              ? (widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starGold)
                              : borderColor,
                          width: _isFramingEnabled ? 1.4 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.crop_rotate_rounded,
                            size: 16,
                            color: _isFramingEnabled
                                ? (widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starGold)
                                : textColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n?.framingModeShort ?? "Framing",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _isFramingEnabled
                                  ? (widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starGold)
                                  : textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // FOV Badge
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: widget.isRedNightMode
                      ? AstroColors.nightVisionSurfaceVariant
                      : AstroColors.spaceDarkSurfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.aspect_ratio_rounded, size: 16, color: accentColor),
                    const SizedBox(width: 6),
                    Text(
                      "FOV: $fovString",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Mode Toggle: Photo+Reticle / Photo / Vector
              Container(
                height: 38,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: widget.isRedNightMode
                      ? AstroColors.nightVisionSurfaceVariant
                      : AstroColors.spaceDarkSurfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildModeBtn(
                      icon: Icons.filter_center_focus_rounded,
                      tooltip: l10n?.photoReticleTooltip ?? "Photo + Reticle",
                      isSelected: _displayMode == PreviewDisplayMode.photoWithReticle,
                      accentColor: accentColor,
                      onTap: () => setState(() => _displayMode = PreviewDisplayMode.photoWithReticle),
                    ),
                    const SizedBox(width: 2),
                    _buildModeBtn(
                      icon: Icons.image_rounded,
                      tooltip: l10n?.photoCleanTooltip ?? "Photo Mode (Clean Image)",
                      isSelected: _displayMode == PreviewDisplayMode.photoOnly,
                      accentColor: accentColor,
                      onTap: () => setState(() => _displayMode = PreviewDisplayMode.photoOnly),
                    ),
                    const SizedBox(width: 2),
                    _buildModeBtn(
                      icon: Icons.draw_rounded,
                      tooltip: l10n?.vectorSizeTooltip ?? "Vector Apparent Size",
                      isSelected: _displayMode == PreviewDisplayMode.vectorOnly,
                      accentColor: accentColor,
                      onTap: () => setState(() => _displayMode = PreviewDisplayMode.vectorOnly),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  },
),

        const SizedBox(height: 8),

        // Row 2: Zoom Controls Toolbar
        LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLargeActionButton(
                        icon: Icons.remove_rounded,
                        tooltip: l10n?.zoomOutTooltip ?? "Zoom Out (Wider FOV)",
                        onTap: _zoomOut,
                        color: textColor,
                        borderColor: borderColor,
                      ),
                      const SizedBox(width: 8),
                      _buildLargeActionButton(
                        icon: Icons.add_rounded,
                        tooltip: l10n?.zoomInTooltip ?? "Zoom In (Closer FOV)",
                        onTap: _zoomIn,
                        color: textColor,
                        borderColor: borderColor,
                      ),
                      const SizedBox(width: 8),
                      _buildLargeActionButton(
                        icon: Icons.restart_alt_rounded,
                        tooltip: l10n?.resetFovTooltip ?? "Reset Framing FOV",
                        onTap: _resetFov,
                        color: textColor,
                        borderColor: borderColor,
                      ),
                      const SizedBox(width: 10),
                      // Zoom Step Size Selector
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                        decoration: BoxDecoration(
                          color: widget.isRedNightMode
                              ? AstroColors.nightVisionSurfaceVariant
                              : AstroColors.spaceDarkSurfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildZoomStepChip(0.10, "10%", accentColor, textColor),
                            const SizedBox(width: 4),
                            _buildZoomStepChip(0.25, "25%", accentColor, textColor),
                            const SizedBox(width: 4),
                            _buildZoomStepChip(0.50, "50%", accentColor, textColor),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        // Row 3: Framing Composition Controls (Rotate, Angle, Align, Fit)
        if (_isFramingEnabled) ...[
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Center(
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: widget.isRedNightMode
                            ? AstroColors.nightVisionSurfaceVariant
                            : AstroColors.spaceDarkSurfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: widget.isRedNightMode
                              ? AstroColors.nightVisionRed.withValues(alpha: 0.6)
                              : AstroColors.starGold.withValues(alpha: 0.6),
                          width: 1.2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildRotatorButton(
                            icon: Icons.rotate_left_rounded,
                            tooltip: l10n?.rotateMinus15 ?? "Rotate -15°",
                            onTap: () => EquipmentManager.instance.rotateBy(-15),
                            color: textColor,
                          ),
                          const SizedBox(width: 6),
                          Tooltip(
                            message: "Sensor Rotation (tap to reset to 0°)",
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => EquipmentManager.instance.setCameraAngle(0),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: (widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starGold)
                                        .withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: (widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starGold)
                                          .withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Text(
                                    "${angle.toStringAsFixed(0)}°",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starGold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildRotatorButton(
                            icon: Icons.rotate_right_rounded,
                            tooltip: l10n?.rotatePlus15 ?? "Rotate +15°",
                            onTap: () => EquipmentManager.instance.rotateBy(15),
                            color: textColor,
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 1,
                            height: 22,
                            color: borderColor.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 10),
                          _buildTextActionButton(
                            icon: Icons.fit_screen_rounded,
                            label: l10n?.fitToSensor ?? "Fit",
                            tooltip: l10n?.fitFovToSensorTooltip ?? "Fit FOV to Sensor Size",
                            onTap: _fitToSensor,
                            accentColor: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starGold,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],

        // Row 4: Active Rig Strip (When framing is on)
        if (_isFramingEnabled) ...[
          const SizedBox(height: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openEquipmentManagerDialog,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.isRedNightMode
                      ? AstroColors.nightVisionSurfaceVariant
                      : AstroColors.spaceDarkSurfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starGold)
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 14,
                      color: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starGold,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "${rig.telescope.name.split('(').first.trim()} • ${rig.camera.name.split('(').first.trim()}",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starGold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "${rig.imageScaleArcsecPerPixel.toStringAsFixed(2)}\"/px",
                      style: TextStyle(
                        fontSize: 11,
                        color: textColor.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: textColor.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );

    if (widget.height.isFinite) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          imageViewport,
          controlsPanel,
        ],
      );
    } else {
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.hasBoundedHeight && constraints.maxHeight < 340) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: (constraints.maxHeight * 0.45).clamp(90.0, 200.0),
                    child: imageViewport,
                  ),
                  controlsPanel,
                ],
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: imageViewport),
              controlsPanel,
            ],
          );
        },
      );
    }
  }

  Widget _buildModeBtn({
    required IconData icon,
    required String tooltip,
    required bool isSelected,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? accentColor.withValues(alpha: 0.22) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: isSelected ? Border.all(color: accentColor.withValues(alpha: 0.6)) : null,
            ),
            child: Icon(
              icon,
              size: 18,
              color: isSelected ? accentColor : Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLargeActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required Color color,
    required Color borderColor,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: widget.isRedNightMode
                  ? AstroColors.nightVisionSurfaceVariant
                  : AstroColors.spaceDarkSurfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
        ),
      ),
    );
  }

  Widget _buildZoomStepChip(
    double stepPercent,
    String label,
    Color accentColor,
    Color textColor,
  ) {
    final isSelected = (_zoomStepPercent - stepPercent).abs() < 0.01;
    return Tooltip(
      message: "Zoom step: $label FOV per click",
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _zoomStepPercent = stepPercent),
          borderRadius: BorderRadius.circular(7),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.22)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: isSelected ? accentColor : Colors.transparent,
                width: 1.0,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? accentColor : textColor.withValues(alpha: 0.75),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRotatorButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 21, color: color),
          ),
        ),
      ),
    );
  }

  Widget _buildTextActionButton({
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback onTap,
    required Color accentColor,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accentColor.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: accentColor),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// CustomPainter rendering the target's physical apparent dimensions, celestial reticle,
/// cardinal indicators, astronomical scale bar, and rotatable camera sensor frame.
class TargetVectorPainter extends CustomPainter {
  final TargetItem target;
  final double fovDeg;
  final bool isRedNightMode;
  final bool isVectorOnly;
  final bool isPhotoOnly;
  final bool showReticle;
  final bool showFraming;
  final EquipmentProfile? equipment;
  final double cameraAngleDeg;
  final bool showRuleOfThirds;
  final double panOffsetArcminX;
  final double panOffsetArcminY;

  TargetVectorPainter({
    required this.target,
    required this.fovDeg,
    required this.isRedNightMode,
    required this.isVectorOnly,
    this.isPhotoOnly = false,
    required this.showReticle,
    this.showFraming = false,
    this.equipment,
    this.cameraAngleDeg = 0.0,
    this.showRuleOfThirds = false,
    this.panOffsetArcminX = 0.0,
    this.panOffsetArcminY = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (isPhotoOnly && (!showFraming || equipment == null)) {
      return;
    }

    final projector = FovProjector(
      viewportSize: size,
      fovDeg: fovDeg,
      panOffsetArcminX: panOffsetArcminX,
      panOffsetArcminY: panOffsetArcminY,
    );
    final center = projector.viewportCenter;
    final targetCenter = projector.targetCenter;
    final minDim = projector.minDim;

    final primaryColor = isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;
    final secondaryColor = isRedNightMode ? AstroColors.nightVisionRedDim : AstroColors.nebulaIndigo;
    final goldColor = isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starGold;

    // 1. Draw Deep Space Background (Only in pure Vector Mode)
    if (isVectorOnly) {
      final bgRect = Offset.zero & size;
      final bgPaint = Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.8,
          colors: isRedNightMode
              ? [const Color(0xFF220808), const Color(0xFF0D0202)]
              : [const Color(0xFF0F172A), const Color(0xFF050811)],
        ).createShader(bgRect);
      canvas.drawRect(bgRect, bgPaint);

      final starRandom = math.Random(target.id * 31 + 17);
      final starPaint = Paint()..style = PaintingStyle.fill;
      for (var i = 0; i < 45; i++) {
        final sx = starRandom.nextDouble() * size.width;
        final sy = starRandom.nextDouble() * size.height;
        final distToCenter = (Offset(sx, sy) - center).distance;

        if (distToCenter < 18) continue;

        final magNorm = starRandom.nextDouble();
        final radius = 0.6 + (1.0 - magNorm) * 1.4;
        final opacity = 0.25 + (1.0 - magNorm) * 0.65;

        starPaint.color = (isRedNightMode ? AstroColors.nightVisionRed : Colors.white).withValues(alpha: opacity);
        canvas.drawCircle(Offset(sx, sy), radius, starPaint);
      }
    }

    // 2. Draw Target Apparent Dimensions (Ellipse / Cloud / Cluster / Planet / Star)
    // Only in Vector mode or Photo + Reticle mode; in Photo Mode, do not draw target apparent vectors or circles.
    if (!isPhotoOnly) {
      final radii = projector.calculateTargetRadii(target.majorAxisArcmin, target.surfaceBrightness);
      final lowerType = target.objectType.toLowerCase();
      final isPlanet = target.catalog == 'Solar System' || (lowerType.contains('planet') && !lowerType.contains('planetary'));
      final isStar = lowerType.contains('star') && !lowerType.contains('cluster');

      if (isPlanet) {
        // Render Planetary disk with authentic physical features
        final radPixels = radii.width > 0 ? radii.width : 14.0;
        final planetR = radPixels.clamp(9.0, 140.0);

        canvas.save();
        canvas.translate(targetCenter.dx, targetCenter.dy);

        final pName = target.name;
        if (pName == 'Saturn') {
          // 3D Ring System:
          final ringAngle = -26.0 * math.pi / 180.0;
          final ringOuterW = planetR * 4.6;
          final ringOuterH = planetR * 1.7;
          final ringInnerW = planetR * 2.8;
          final ringInnerH = planetR * 1.05;

          // 1. Back half of rings: clip to top half (y <= 0)
          canvas.save();
          canvas.rotate(ringAngle);
          canvas.save();
          canvas.clipRect(Rect.fromLTRB(-ringOuterW, -ringOuterH, ringOuterW, 0));
          final ringBackPaint = Paint()
            ..color = (isRedNightMode ? AstroColors.nightVisionRed : const Color(0xFFD4B26F)).withValues(alpha: 0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = (ringOuterH - ringInnerH) * 0.45;
          canvas.drawOval(
            Rect.fromCenter(center: Offset.zero, width: (ringOuterW + ringInnerW) / 2, height: (ringOuterH + ringInnerH) / 2),
            ringBackPaint,
          );
          canvas.restore();
          canvas.restore();

          // 2. Planet Sphere
          final bodyPaint = Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.35, -0.35),
              radius: 0.9,
              colors: isRedNightMode
                  ? [AstroColors.nightVisionRed, const Color(0xFF350A0A)]
                  : [const Color(0xFFF3E5AB), const Color(0xFFC29B38), const Color(0xFF785E23)],
              stops: const [0.0, 0.65, 1.0],
            ).createShader(Rect.fromCircle(center: Offset.zero, radius: planetR));
          canvas.drawCircle(Offset.zero, planetR, bodyPaint);

          // Subtle Saturn atmospheric belt
          final beltPaint = Paint()
            ..color = (isRedNightMode ? Colors.black : const Color(0xFF8B6B23)).withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = planetR * 0.22;
          canvas.drawArc(Rect.fromCenter(center: Offset.zero, width: planetR * 2, height: planetR * 0.8), -0.2, 3.5, false, beltPaint);

          // 3. Front half of rings: clip to bottom half (y > 0)
          canvas.save();
          canvas.rotate(ringAngle);
          canvas.save();
          canvas.clipRect(Rect.fromLTRB(-ringOuterW, 0, ringOuterW, ringOuterH));
          final ringFrontPaint = Paint()
            ..color = (isRedNightMode ? AstroColors.nightVisionRed : const Color(0xFFE2C485)).withValues(alpha: 0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = (ringOuterH - ringInnerH) * 0.45;
          canvas.drawOval(
            Rect.fromCenter(center: Offset.zero, width: (ringOuterW + ringInnerW) / 2, height: (ringOuterH + ringInnerH) / 2),
            ringFrontPaint,
          );
          // Cassini division gap line
          final cassiniPaint = Paint()
            ..color = Colors.black.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2;
          canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: ringOuterW * 0.84, height: ringOuterH * 0.84), cassiniPaint);
          canvas.restore();
          canvas.restore();

        } else if (pName == 'Jupiter') {
          // Jovian sphere with atmospheric belts & Red Spot
          final jupPaint = Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.3, -0.3),
              radius: 0.85,
              colors: isRedNightMode
                  ? [AstroColors.nightVisionRed, const Color(0xFF380808)]
                  : [const Color(0xFFFFF8E7), const Color(0xFFE0B984), const Color(0xFF9E6B38)],
              stops: const [0.0, 0.7, 1.0],
            ).createShader(Rect.fromCircle(center: Offset.zero, radius: planetR));
          canvas.drawCircle(Offset.zero, planetR, jupPaint);

          canvas.save();
          canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: planetR)));

          final beltColor = (isRedNightMode ? Colors.black : const Color(0xFF8B4513)).withValues(alpha: 0.45);
          final beltPaint = Paint()
            ..color = beltColor
            ..style = PaintingStyle.fill;
          canvas.drawRect(Rect.fromLTRB(-planetR, -planetR * 0.38, planetR, -planetR * 0.12), beltPaint);
          canvas.drawRect(Rect.fromLTRB(-planetR, planetR * 0.12, planetR, planetR * 0.38), beltPaint);

          final faintBelt = Paint()
            ..color = beltColor.withValues(alpha: 0.25)
            ..style = PaintingStyle.fill;
          canvas.drawRect(Rect.fromLTRB(-planetR, planetR * 0.52, planetR, planetR * 0.65), faintBelt);
          canvas.drawRect(Rect.fromLTRB(-planetR, -planetR * 0.65, planetR, -planetR * 0.52), faintBelt);

          // Great Red Spot
          final grsPaint = Paint()
            ..color = (isRedNightMode ? Colors.white : const Color(0xFFCC4422)).withValues(alpha: 0.75)
            ..style = PaintingStyle.fill;
          canvas.drawOval(Rect.fromCenter(center: Offset(planetR * 0.35, planetR * 0.25), width: planetR * 0.4, height: planetR * 0.22), grsPaint);

          canvas.restore();

        } else if (pName == 'Mars') {
          // Mars: terracotta sphere with polar ice cap
          final marsPaint = Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.35, -0.35),
              radius: 0.85,
              colors: isRedNightMode
                  ? [AstroColors.nightVisionRed, const Color(0xFF400A0A)]
                  : [const Color(0xFFFF7A45), const Color(0xFFC84B20), const Color(0xFF6B1D0B)],
              stops: const [0.0, 0.65, 1.0],
            ).createShader(Rect.fromCircle(center: Offset.zero, radius: planetR));
          canvas.drawCircle(Offset.zero, planetR, marsPaint);

          canvas.save();
          canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: planetR)));
          final capPaint = Paint()
            ..color = Colors.white.withValues(alpha: 0.85)
            ..style = PaintingStyle.fill;
          canvas.drawOval(Rect.fromCenter(center: Offset(0, -planetR * 0.82), width: planetR * 0.7, height: planetR * 0.3), capPaint);
          canvas.restore();

        } else if (pName == 'Moon') {
          // Moon: cratered lunar sphere
          final moonPaint = Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.3, -0.3),
              radius: 0.85,
              colors: isRedNightMode
                  ? [AstroColors.nightVisionRed, const Color(0xFF300808)]
                  : [const Color(0xFFF0F2F5), const Color(0xFFB0B4BC), const Color(0xFF4A4E57)],
              stops: const [0.0, 0.65, 1.0],
            ).createShader(Rect.fromCircle(center: Offset.zero, radius: planetR));
          canvas.drawCircle(Offset.zero, planetR, moonPaint);

          canvas.save();
          canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: planetR)));
          final mariaPaint = Paint()
            ..color = Colors.black.withValues(alpha: 0.22)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(-planetR * 0.28, -planetR * 0.25), planetR * 0.32, mariaPaint);
          canvas.drawCircle(Offset(planetR * 0.22, -planetR * 0.15), planetR * 0.25, mariaPaint);
          canvas.drawCircle(Offset(planetR * 0.15, planetR * 0.3), planetR * 0.28, mariaPaint);
          canvas.restore();

        } else if (pName == 'Sun') {
          // Radiant Sun disk with corona flares
          final coronaPaint = Paint()
            ..shader = RadialGradient(
              colors: [
                (isRedNightMode ? AstroColors.nightVisionRed : const Color(0xFFFFB300)).withValues(alpha: 0.35),
                (isRedNightMode ? AstroColors.nightVisionRed : const Color(0xFFFF6D00)).withValues(alpha: 0.1),
                Colors.transparent,
              ],
              stops: const [0.5, 0.8, 1.0],
            ).createShader(Rect.fromCircle(center: Offset.zero, radius: planetR * 1.6));
          canvas.drawCircle(Offset.zero, planetR * 1.6, coronaPaint);

          final sunPaint = Paint()
            ..shader = RadialGradient(
              center: Alignment.center,
              radius: 0.85,
              colors: isRedNightMode
                  ? [Colors.white, AstroColors.nightVisionRed]
                  : [const Color(0xFFFFFFE0), const Color(0xFFFFD700), const Color(0xFFFF8C00)],
              stops: const [0.0, 0.55, 1.0],
            ).createShader(Rect.fromCircle(center: Offset.zero, radius: planetR));
          canvas.drawCircle(Offset.zero, planetR, sunPaint);

        } else if (pName == 'Venus') {
          // Venus: brilliant pearlescent sphere
          final venusPaint = Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.35, -0.35),
              radius: 0.85,
              colors: isRedNightMode
                  ? [AstroColors.nightVisionRed, const Color(0xFF350A0A)]
                  : [const Color(0xFFFFFDF5), const Color(0xFFEADBBE), const Color(0xFF9E8E72)],
              stops: const [0.0, 0.65, 1.0],
            ).createShader(Rect.fromCircle(center: Offset.zero, radius: planetR));
          canvas.drawCircle(Offset.zero, planetR, venusPaint);

        } else if (pName == 'Uranus') {
          // Uranus: soft aquamarine sphere
          final uranusPaint = Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.35, -0.35),
              radius: 0.85,
              colors: isRedNightMode
                  ? [AstroColors.nightVisionRed, const Color(0xFF280808)]
                  : [const Color(0xFFD6F9FA), const Color(0xFF7CE4EC), const Color(0xFF2C7D88)],
              stops: const [0.0, 0.65, 1.0],
            ).createShader(Rect.fromCircle(center: Offset.zero, radius: planetR));
          canvas.drawCircle(Offset.zero, planetR, uranusPaint);

        } else if (pName == 'Neptune') {
          // Neptune: deep azure/cobalt sphere
          final nepPaint = Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.35, -0.35),
              radius: 0.85,
              colors: isRedNightMode
                  ? [AstroColors.nightVisionRed, const Color(0xFF200505)]
                  : [const Color(0xFF8AB8FD), const Color(0xFF386FE0), const Color(0xFF142B75)],
              stops: const [0.0, 0.65, 1.0],
            ).createShader(Rect.fromCircle(center: Offset.zero, radius: planetR));
          canvas.drawCircle(Offset.zero, planetR, nepPaint);

        } else {
          // Mercury / Pluto / Default
          final defPaint = Paint()
            ..shader = RadialGradient(
              center: const Alignment(-0.35, -0.35),
              radius: 0.85,
              colors: isRedNightMode
                  ? [AstroColors.nightVisionRed, const Color(0xFF200505)]
                  : [const Color(0xFFD8D8D8), const Color(0xFF8A8A8A), const Color(0xFF3B3B3B)],
              stops: const [0.0, 0.65, 1.0],
            ).createShader(Rect.fromCircle(center: Offset.zero, radius: planetR));
          canvas.drawCircle(Offset.zero, planetR, defPaint);
        }

        // Precision outline ring
        final borderPaint = Paint()
          ..color = (isRedNightMode ? AstroColors.nightVisionRed : primaryColor).withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawCircle(Offset.zero, planetR, borderPaint);

        canvas.restore();

      } else if (isStar) {
        // Bright Stellar Object: diffraction spikes + stellar glow halo + brilliant core
        final mag = target.magnitude ?? 2.0;
        final coreR = (4.0 - (mag * 0.35)).clamp(2.5, 6.0);
        final spikeLen = (32.0 - (mag * 2.8)).clamp(12.0, 42.0);

        canvas.save();
        canvas.translate(targetCenter.dx, targetCenter.dy);

        // 1. Soft stellar halo glow
        final haloPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              (isRedNightMode ? AstroColors.nightVisionRed : goldColor).withValues(alpha: 0.55),
              (isRedNightMode ? AstroColors.nightVisionRed : primaryColor).withValues(alpha: 0.15),
              Colors.transparent,
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: spikeLen * 0.9));
        canvas.drawCircle(Offset.zero, spikeLen * 0.9, haloPaint);

        // 2. 4-point Diffraction Cross (Telescope Spider Spikes)
        final spikePaint = Paint()
          ..color = (isRedNightMode ? AstroColors.nightVisionRed : Colors.white).withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1;
        canvas.drawLine(Offset(-spikeLen, 0), Offset(spikeLen, 0), spikePaint);
        canvas.drawLine(Offset(0, -spikeLen), Offset(0, spikeLen), spikePaint);

        // Diagonal soft micro-spikes for 1st magnitude stars
        if (mag < 1.5) {
          final diagLen = spikeLen * 0.45;
          final diagPaint = Paint()
            ..color = (isRedNightMode ? AstroColors.nightVisionRed : goldColor).withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8;
          canvas.drawLine(Offset(-diagLen, -diagLen), Offset(diagLen, diagLen), diagPaint);
          canvas.drawLine(Offset(-diagLen, diagLen), Offset(diagLen, -diagLen), diagPaint);
        }

        // 3. Central Brilliant White Star Core
        final corePaint = Paint()
          ..color = isRedNightMode ? AstroColors.nightVisionRed : Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset.zero, coreR, corePaint);

        // 4. Secondary companion for double stars
        if (lowerType.contains('double')) {
          final compOffset = Offset(coreR * 3.2, -coreR * 2.2);
          final compSpike = spikeLen * 0.5;
          canvas.drawLine(compOffset + Offset(-compSpike, 0), compOffset + Offset(compSpike, 0), spikePaint);
          canvas.drawLine(compOffset + Offset(0, -compSpike), compOffset + Offset(0, compSpike), spikePaint);
          canvas.drawCircle(compOffset, coreR * 0.65, corePaint);
        }

        canvas.restore();

      } else if (radii != Size.zero) {
        final radX = radii.width;
        final radY = radii.height;

        canvas.save();
        canvas.translate(targetCenter.dx, targetCenter.dy);
        final paRad = target.positionAngleDeg != null
            ? (target.positionAngleDeg! * math.pi / 180.0)
            : (math.pi / 5.0);
        canvas.rotate(paRad);

        if (lowerType.contains('galaxy')) {
          // GALAXY
          final haloPaint = Paint()
            ..shader = RadialGradient(
              colors: [
                primaryColor.withValues(alpha: isVectorOnly ? 0.45 : 0.25),
                primaryColor.withValues(alpha: 0.0),
              ],
              stops: const [0.2, 1.0],
            ).createShader(Rect.fromCenter(center: Offset.zero, width: radX * 2.2, height: radY * 2.2));
          canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: radX * 2.0, height: radY * 2.0), haloPaint);

          final corePaint = Paint()
            ..shader = RadialGradient(
              colors: [
                (isRedNightMode ? Colors.white : goldColor).withValues(alpha: 0.9),
                primaryColor.withValues(alpha: 0.0),
              ],
            ).createShader(Rect.fromCenter(center: Offset.zero, width: radX * 0.4, height: radY * 0.4));
          canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: radX * 0.4, height: radY * 0.4), corePaint);

          final outlinePaint = Paint()
            ..color = primaryColor.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2;
          canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: radX * 2.0, height: radY * 2.0), outlinePaint);
        } else if (lowerType.contains('planetary')) {
          // PLANETARY NEBULA
          final ringPaint = Paint()
            ..color = (isRedNightMode ? AstroColors.nightVisionRed : AstroColors.deepSkyTeal).withValues(alpha: 0.7)
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(2.0, radX * 0.25);
          canvas.drawCircle(Offset.zero, radX, ringPaint);

          final dwarfPaint = Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset.zero, 1.8, dwarfPaint);
        } else if (lowerType.contains('globular')) {
          // GLOBULAR CLUSTER
          final globPaint = Paint()
            ..shader = RadialGradient(
              colors: [
                (isRedNightMode ? AstroColors.nightVisionRed : Colors.white).withValues(alpha: 0.85),
                goldColor.withValues(alpha: 0.4),
                primaryColor.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.4, 1.0],
            ).createShader(Rect.fromCircle(center: Offset.zero, radius: radX));
          canvas.drawCircle(Offset.zero, radX, globPaint);

          final globBorder = Paint()
            ..color = goldColor.withValues(alpha: 0.5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;
          canvas.drawCircle(Offset.zero, radX, globBorder);
        } else if (lowerType.contains('open cluster') || lowerType.contains('cluster')) {
          // OPEN CLUSTER
          final clusterBorder = Paint()
            ..color = goldColor.withValues(alpha: 0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;
          canvas.drawCircle(Offset.zero, radX, clusterBorder);

          final starP = Paint()..style = PaintingStyle.fill;
          final cRand = math.Random(target.id * 7);
          for (var i = 0; i < 18; i++) {
            final r = math.sqrt(cRand.nextDouble()) * radX * 0.9;
            final th = cRand.nextDouble() * 2 * math.pi;
            starP.color = (isRedNightMode ? AstroColors.nightVisionRed : Colors.white).withValues(alpha: 0.85);
            canvas.drawCircle(Offset(r * math.cos(th), r * math.sin(th)), 1.2, starP);
          }
        } else {
          // NEBULA / SUPERNOVA REMNANT
          final nebPaint = Paint()
            ..shader = RadialGradient(
              colors: [
                secondaryColor.withValues(alpha: isVectorOnly ? 0.5 : 0.3),
                primaryColor.withValues(alpha: isVectorOnly ? 0.25 : 0.12),
                primaryColor.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.6, 1.0],
            ).createShader(Rect.fromCenter(center: Offset.zero, width: radX * 2.2, height: radY * 2.2));
          canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: radX * 2.0, height: radY * 2.0), nebPaint);

          final outlinePaint = Paint()
            ..color = secondaryColor.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2;
          canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: radX * 2.0, height: radY * 2.0), outlinePaint);
        }

        canvas.restore();
      } else {
        final pointPaint = Paint()
          ..color = goldColor.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        canvas.drawCircle(targetCenter, 6.0, pointPaint);
      }
    }

    // 3. Equipment Framing Simulator Sensor Frame Overlay
    if (showFraming && equipment != null) {
      final sensorPixels = projector.calculateSensorPixelSize(
        equipment!.sensorFovWidthArcmin,
        equipment!.sensorFovHeightArcmin,
      );
      final rectW = sensorPixels.width;
      final rectH = sensorPixels.height;

      // If offset is non-zero, draw guide line and target catalog reticle (only when reticle is enabled and not photo-only)
      if (!isPhotoOnly && showReticle && (panOffsetArcminX != 0.0 || panOffsetArcminY != 0.0)) {
        final linePaint = Paint()
          ..color = goldColor.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawLine(center, targetCenter, linePaint);

        // Catalog target center crosshair & marker
        final crossPaint = Paint()
          ..color = goldColor.withValues(alpha: 0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        const cLen = 5.0;
        canvas.drawLine(Offset(targetCenter.dx - cLen, targetCenter.dy), Offset(targetCenter.dx + cLen, targetCenter.dy), crossPaint);
        canvas.drawLine(Offset(targetCenter.dx, targetCenter.dy - cLen), Offset(targetCenter.dx, targetCenter.dy + cLen), crossPaint);
        canvas.drawCircle(targetCenter, 3.0, crossPaint);

        // Label target name next to target catalog center
        final textPainter = TextPainter(
          text: TextSpan(
            text: target.displayName,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: goldColor.withValues(alpha: 0.85),
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(targetCenter.dx + 6, targetCenter.dy - 14));
      }

      // Optical center crosshair at sensor center (viewport center - only when reticle is enabled and not photo-only)
      if (!isPhotoOnly && showReticle) {
        final opticalCrossPaint = Paint()
          ..color = (isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan).withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
        const optLen = 7.0;
        canvas.drawLine(Offset(center.dx - optLen, center.dy), Offset(center.dx + optLen, center.dy), opticalCrossPaint);
        canvas.drawLine(Offset(center.dx, center.dy - optLen), Offset(center.dx, center.dy + optLen), opticalCrossPaint);
      }

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(cameraAngleDeg * math.pi / 180.0);

      final sensorRect = Rect.fromCenter(center: Offset.zero, width: rectW, height: rectH);

      // Sensor frame rectangle
      final framePaint = Paint()
        ..color = (isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starGold).withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRect(sensorRect, framePaint);

      // Corner accent brackets
      final bracketPaint = Paint()
        ..color = isRedNightMode ? Colors.white : AstroColors.starlightCyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2;
      const bLen = 12.0;
      canvas.drawLine(sensorRect.topLeft, sensorRect.topLeft + const Offset(bLen, 0), bracketPaint);
      canvas.drawLine(sensorRect.topLeft, sensorRect.topLeft + const Offset(0, bLen), bracketPaint);
      canvas.drawLine(sensorRect.topRight, sensorRect.topRight + const Offset(-bLen, 0), bracketPaint);
      canvas.drawLine(sensorRect.topRight, sensorRect.topRight + const Offset(0, bLen), bracketPaint);
      canvas.drawLine(sensorRect.bottomLeft, sensorRect.bottomLeft + const Offset(bLen, 0), bracketPaint);
      canvas.drawLine(sensorRect.bottomLeft, sensorRect.bottomLeft + const Offset(0, -bLen), bracketPaint);
      canvas.drawLine(sensorRect.bottomRight, sensorRect.bottomRight + const Offset(-bLen, 0), bracketPaint);
      canvas.drawLine(sensorRect.bottomRight, sensorRect.bottomRight + const Offset(0, -bLen), bracketPaint);

      // Rule of thirds grid
      if (showRuleOfThirds) {
        final gridPaint = Paint()
          ..color = (isRedNightMode ? AstroColors.nightVisionRed : Colors.white).withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8;
        canvas.drawLine(Offset(-rectW / 6, -rectH / 2), Offset(-rectW / 6, rectH / 2), gridPaint);
        canvas.drawLine(Offset(rectW / 6, -rectH / 2), Offset(rectW / 6, rectH / 2), gridPaint);
        canvas.drawLine(Offset(-rectW / 2, -rectH / 6), Offset(rectW / 2, -rectH / 6), gridPaint);
        canvas.drawLine(Offset(-rectW / 2, rectH / 6), Offset(rectW / 2, rectH / 6), gridPaint);
      }

      // Sensor frame dimensions label
      final labelPainter = TextPainter(
        text: TextSpan(
          text: "${equipment!.sensorFovWidthDeg.toStringAsFixed(1)}° × ${equipment!.sensorFovHeightDeg.toStringAsFixed(1)}°",
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starGold,
            backgroundColor: Colors.black.withValues(alpha: 0.65),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      labelPainter.layout();
      labelPainter.paint(canvas, Offset(-rectW / 2 + 3, rectH / 2 - labelPainter.height - 3));

      canvas.restore();
    }

    // 4. Astrometric Reticle & Concentric Guides
    if (showReticle && !isPhotoOnly) {
      final reticlePaint = Paint()
        ..color = primaryColor.withValues(alpha: isVectorOnly ? 0.35 : 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;

      final reticleCenter = (panOffsetArcminX != 0.0 || panOffsetArcminY != 0.0) ? targetCenter : center;

      canvas.drawCircle(reticleCenter, minDim * 0.35, reticlePaint);

      final crosshairPaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      const gap = 12.0;
      const crossLen = 28.0;
      canvas.drawLine(Offset(reticleCenter.dx - gap - crossLen, reticleCenter.dy), Offset(reticleCenter.dx - gap, reticleCenter.dy), crosshairPaint);
      canvas.drawLine(Offset(reticleCenter.dx + gap, reticleCenter.dy), Offset(reticleCenter.dx + gap + crossLen, reticleCenter.dy), crosshairPaint);
      canvas.drawLine(Offset(reticleCenter.dx, reticleCenter.dy - gap - crossLen), Offset(reticleCenter.dx, reticleCenter.dy - gap), crosshairPaint);
      canvas.drawLine(Offset(reticleCenter.dx, reticleCenter.dy + gap), Offset(reticleCenter.dx, reticleCenter.dy + gap + crossLen), crosshairPaint);
    }

    if (!isPhotoOnly) {
      // 5. Orientation Indicator (North at top, East at left)
      _drawOrientation(canvas, size, primaryColor);

      // 6. Physical Scale Ruler Bar (Bottom Left)
      _drawScaleBar(canvas, projector, primaryColor);

      // 7. Apparent Size Label (Bottom Right)
      _drawApparentSizeLabel(canvas, size, primaryColor);
    }
  }

  void _drawOrientation(Canvas canvas, Size size, Color color) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    textPainter.text = TextSpan(
      text: "N ↑",
      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.65)),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(size.width / 2 - textPainter.width / 2, 28));

    textPainter.text = TextSpan(
      text: "← E",
      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.65)),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(8, size.height / 2 - textPainter.height / 2));
  }

  void _drawScaleBar(
    Canvas canvas,
    FovProjector projector,
    Color color,
  ) {
    final scale = projector.calculateScaleBar();
    if (!scale.isValid) return;

    final barPaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.drawLine(Offset(scale.startX, scale.y), Offset(scale.startX + scale.barPixels, scale.y), barPaint);
    canvas.drawLine(Offset(scale.startX, scale.y - 3), Offset(scale.startX, scale.y + 3), barPaint);
    canvas.drawLine(Offset(scale.startX + scale.barPixels, scale.y - 3), Offset(scale.startX + scale.barPixels, scale.y + 3), barPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: scale.label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color.withValues(alpha: 0.85)),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(scale.startX + (scale.barPixels - textPainter.width) / 2, scale.y - 13));
  }

  void _drawApparentSizeLabel(Canvas canvas, Size size, Color color) {
    final label = FovProjector.formatApparentSize(target.majorAxisArcmin);

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: (isRedNightMode ? AstroColors.nightVisionRed : Colors.white).withValues(alpha: 0.75),
          backgroundColor: Colors.black.withValues(alpha: 0.5),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(size.width - textPainter.width - 10, size.height - 18));
  }

  @override
  bool shouldRepaint(covariant TargetVectorPainter oldDelegate) {
    return oldDelegate.target.id != target.id ||
        oldDelegate.fovDeg != fovDeg ||
        oldDelegate.isRedNightMode != isRedNightMode ||
        oldDelegate.isVectorOnly != isVectorOnly ||
        oldDelegate.isPhotoOnly != isPhotoOnly ||
        oldDelegate.showReticle != showReticle ||
        oldDelegate.showFraming != showFraming ||
        oldDelegate.equipment?.id != equipment?.id ||
        oldDelegate.cameraAngleDeg != cameraAngleDeg ||
        oldDelegate.showRuleOfThirds != showRuleOfThirds ||
        oldDelegate.panOffsetArcminX != panOffsetArcminX ||
        oldDelegate.panOffsetArcminY != panOffsetArcminY;
  }
}
