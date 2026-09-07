import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../core/equipment_manager.dart';
import '../core/sky_image_service.dart';
import '../models/equipment_profile.dart';
import '../models/target_item.dart';
import '../theme/astro_theme.dart';
import '../views/equipment_dialog.dart';
import '../views/equipment_framing_dialog.dart';

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

  @override
  void initState() {
    super.initState();
    _isFramingEnabled = widget.initialFramingEnabled;
    _fovDeg = SkyImageService.computeRecommendedFovDeg(widget.target.majorAxisArcmin);
    EquipmentManager.instance.addListener(_onEquipmentStateChanged);
    _loadImage();
  }

  @override
  void dispose() {
    EquipmentManager.instance.removeListener(_onEquipmentStateChanged);
    super.dispose();
  }

  void _onEquipmentStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant TargetPreviewCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target.id != widget.target.id) {
      _fovDeg = SkyImageService.computeRecommendedFovDeg(widget.target.majorAxisArcmin);
      _imageBytes = null;
      _hasError = false;
      _loadImage();
    }
  }

  /// Allows external callers (e.g. Fit to Sensor) to set custom FOV
  void setCustomFov(double fovDeg) {
    final clamped = fovDeg.clamp(0.15, 14.0);
    setState(() => _fovDeg = clamped);
    _loadImage();
  }

  void _loadImage() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final url = SkyImageService.buildHiPSUrl(
      raHours: widget.target.raHours,
      decDegrees: widget.target.decDegrees,
      fovDeg: _fovDeg,
      surveyId: _selectedSurveyId,
      width: 512,
      height: 512,
    );

    final bytes = await SkyImageService.instance.fetchSkyImage(url);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (bytes != null && bytes.isNotEmpty) {
          _imageBytes = bytes;
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

  void _zoomIn() {
    final newFov = (_fovDeg * 0.75).clamp(0.15, 14.0);
    if (newFov != _fovDeg) {
      setState(() => _fovDeg = newFov);
      _loadImage();
    }
  }

  void _zoomOut() {
    final newFov = (_fovDeg * 1.35).clamp(0.15, 14.0);
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

  void _autoAlignWithTarget() {
    EquipmentManager.instance.autoAlignWithTarget(35.0);
  }

  void _fitToSensor() {
    final rig = EquipmentManager.instance.activeProfile;
    final diag = rig.sensorFovDiagonalDeg;
    setCustomFov(diag * 1.35);
  }

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
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;
    final borderColor = widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder;
    final surfaceColor = widget.isRedNightMode ? AstroColors.nightVisionSurfaceVariant : AstroColors.spaceDarkSurfaceVariant;

    final fovArcmin = _fovDeg * 60.0;
    final fovString = fovArcmin >= 60.0
        ? "${_fovDeg.toStringAsFixed(1)}°"
        : "${fovArcmin.toStringAsFixed(0)}'";

    final showPhoto = _imageBytes != null && _displayMode != PreviewDisplayMode.vectorOnly;
    final showReticle = _displayMode != PreviewDisplayMode.photoOnly;

    final rig = EquipmentManager.instance.activeProfile;
    final angle = EquipmentManager.instance.cameraAngleDeg;
    final showRuleOfThirds = EquipmentManager.instance.showRuleOfThirds;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Photographic Sky Image Layer
          if (showPhoto)
            Image.memory(
              _imageBytes!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
              color: widget.isRedNightMode ? AstroColors.nightVisionRed : null,
              colorBlendMode: widget.isRedNightMode ? BlendMode.modulate : null,
            ),

          // 2. Vector Sky Canvas Layer (Apparent size ellipse, reticle, scale, and sensor box)
          CustomPaint(
            painter: TargetVectorPainter(
              target: widget.target,
              fovDeg: _fovDeg,
              isRedNightMode: widget.isRedNightMode,
              isVectorOnly: _displayMode == PreviewDisplayMode.vectorOnly || !showPhoto,
              showReticle: showReticle,
              showFraming: _isFramingEnabled,
              equipment: rig,
              cameraAngleDeg: angle,
              showRuleOfThirds: showRuleOfThirds,
            ),
          ),

          // 3. Loading Indicator Overlay
          if (_isLoading)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Streaming HiPS...",
                      style: TextStyle(fontSize: 10, color: textColor),
                    ),
                  ],
                ),
              ),
            ),

          // 4. Offline / Error Status Banner
          if (_hasError && _imageBytes == null)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.amber.shade700.withValues(alpha: 0.6),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi_off_rounded, size: 12, color: Colors.amber.shade400),
                    const SizedBox(width: 4),
                    Text(
                      "Offline • Vector Chart",
                      style: TextStyle(fontSize: 10, color: Colors.amber.shade200, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: _loadImage,
                      child: Icon(Icons.refresh_rounded, size: 13, color: accentColor),
                    ),
                  ],
                ),
              ),
            ),

          // 5. Header Control Bar (Survey selector, Mode switcher, FOV Badge, Framing Toggle)
          Positioned(
            top: 6,
            left: 6,
            right: widget.enableExpandDialog ? 44 : 6,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Survey Selector Chip
                  PopupMenuButton<String>(
                    tooltip: "Select Sky Survey",
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
                        height: 36,
                        child: Text(
                          s.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: s.id == _selectedSurveyId ? accentColor : textColor,
                            fontWeight: s.id == _selectedSurveyId ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      );
                    }).toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.layers_rounded, size: 12, color: accentColor),
                          const SizedBox(width: 4),
                          Text(
                            SkyImageService.availableSurveys
                                .firstWhere((s) => s.id == _selectedSurveyId,
                                    orElse: () => SkyImageService.availableSurveys.first)
                                .label,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: textColor),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.arrow_drop_down_rounded, size: 14, color: textColor.withValues(alpha: 0.7)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // FOV Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Text(
                      "FOV: $fovString",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textColor),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // Framing Simulator Mode Toggle
                  Tooltip(
                    message: "Toggle Sensor Framing Box",
                    child: InkWell(
                      onTap: () {
                        setState(() => _isFramingEnabled = !_isFramingEnabled);
                        if (_isFramingEnabled) {
                          _fitToSensor();
                        }
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isFramingEnabled ? AstroColors.starGold.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _isFramingEnabled ? AstroColors.starGold : Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.crop_rotate_rounded, size: 12, color: _isFramingEnabled ? AstroColors.starGold : textColor),
                            const SizedBox(width: 4),
                            Text(
                              "Framing",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _isFramingEnabled ? AstroColors.starGold : textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // Mode Toggle: Photo+Reticle / Photo / Vector
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMiniModeBtn(
                          icon: Icons.filter_center_focus_rounded,
                          tooltip: "Photo + Reticle",
                          isSelected: _displayMode == PreviewDisplayMode.photoWithReticle,
                          accentColor: accentColor,
                          onTap: () => setState(() => _displayMode = PreviewDisplayMode.photoWithReticle),
                        ),
                        _buildMiniModeBtn(
                          icon: Icons.image_rounded,
                          tooltip: "Photo Only",
                          isSelected: _displayMode == PreviewDisplayMode.photoOnly,
                          accentColor: accentColor,
                          onTap: () => setState(() => _displayMode = PreviewDisplayMode.photoOnly),
                        ),
                        _buildMiniModeBtn(
                          icon: Icons.draw_rounded,
                          tooltip: "Vector Apparent Size",
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

          // 5b. Pinned Full Framing Simulator Button (Always visible on mobile & desktop, never cropped)
          if (widget.enableExpandDialog)
            Positioned(
              top: 6,
              right: 6,
              child: Tooltip(
                message: "Full Framing Simulator",
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openFramingSimulatorDialog,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 32,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: widget.isRedNightMode
                              ? AstroColors.nightVisionRed
                              : AstroColors.starGold,
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.open_in_full_rounded,
                        size: 15,
                        color: widget.isRedNightMode
                            ? AstroColors.nightVisionRed
                            : AstroColors.starGold,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 6. Active Rig Indicator Badge (When framing is on)
          if (_isFramingEnabled)
            Positioned(
              top: 36,
              left: 6,
              child: InkWell(
                onTap: _openEquipmentManagerDialog,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AstroColors.starGold.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 11, color: AstroColors.starGold),
                      const SizedBox(width: 4),
                      Text(
                        "${rig.telescope.name.split('(').first.trim()} • ${rig.camera.name.split('(').first.trim()}",
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AstroColors.starGold),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "(${rig.imageScaleArcsecPerPixel.toStringAsFixed(2)}\"/px)",
                        style: TextStyle(fontSize: 8, color: Colors.white.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 7. Bottom Controls Bar (Zoom, Framing Rotate, Auto-Align, Fit)
          Positioned(
            bottom: 6,
            left: 6,
            right: 6,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionButton(Icons.remove_rounded, "Zoom Out", _zoomOut, textColor),
                  const SizedBox(width: 4),
                  _buildActionButton(Icons.add_rounded, "Zoom In", _zoomIn, textColor),
                  const SizedBox(width: 4),
                  _buildActionButton(Icons.restart_alt_rounded, "Reset Framing", _resetFov, textColor),

                  if (_isFramingEnabled) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AstroColors.starGold.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildActionButton(Icons.rotate_left_rounded, "Rotate -15°", () => EquipmentManager.instance.rotateBy(-15), textColor),
                          const SizedBox(width: 2),
                          Text(
                            "${angle.toStringAsFixed(0)}°",
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AstroColors.starGold),
                          ),
                          const SizedBox(width: 2),
                          _buildActionButton(Icons.rotate_right_rounded, "Rotate +15°", () => EquipmentManager.instance.rotateBy(15), textColor),
                          const SizedBox(width: 4),
                          _buildActionButton(Icons.auto_awesome_rounded, "Auto-Align with Target", _autoAlignWithTarget, AstroColors.starlightCyan),
                          const SizedBox(width: 4),
                          _buildActionButton(Icons.fit_screen_rounded, "Fit to Sensor", _fitToSensor, AstroColors.starGold),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniModeBtn({
    required IconData icon,
    required String tooltip,
    required bool isSelected,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected ? accentColor.withValues(alpha: 0.25) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            size: 13,
            color: isSelected ? accentColor : Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String tooltip,
    VoidCallback onTap,
    Color textColor,
  ) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Icon(icon, size: 13, color: textColor),
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
  final bool showReticle;
  final bool showFraming;
  final EquipmentProfile? equipment;
  final double cameraAngleDeg;
  final bool showRuleOfThirds;

  TargetVectorPainter({
    required this.target,
    required this.fovDeg,
    required this.isRedNightMode,
    required this.isVectorOnly,
    required this.showReticle,
    this.showFraming = false,
    this.equipment,
    this.cameraAngleDeg = 0.0,
    this.showRuleOfThirds = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final fovArcmin = fovDeg * 60.0;
    final minDim = math.min(size.width, size.height);
    final pixelsPerArcmin = minDim / fovArcmin;

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

    // 2. Draw Target Apparent Dimensions (Ellipse / Cloud / Cluster)
    final majorArcmin = target.majorAxisArcmin;
    final minorArcmin = target.surfaceBrightness != null && majorArcmin != null
        ? majorArcmin * 0.65
        : majorArcmin;

    if (majorArcmin != null && majorArcmin > 0) {
      final radX = (majorArcmin / 2.0) * pixelsPerArcmin;
      final radY = ((minorArcmin ?? majorArcmin) / 2.0) * pixelsPerArcmin;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(math.pi / 5.0);

      final lowerType = target.objectType.toLowerCase();

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
      canvas.drawCircle(center, 6.0, pointPaint);
    }

    // 3. Equipment Framing Simulator Sensor Frame Overlay
    if (showFraming && equipment != null) {
      final fovW = equipment!.sensorFovWidthArcmin;
      final fovH = equipment!.sensorFovHeightArcmin;

      final rectW = fovW * pixelsPerArcmin;
      final rectH = fovH * pixelsPerArcmin;

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
    if (showReticle) {
      final reticlePaint = Paint()
        ..color = primaryColor.withValues(alpha: isVectorOnly ? 0.35 : 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8;

      canvas.drawCircle(center, minDim * 0.35, reticlePaint);

      final crosshairPaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      const gap = 12.0;
      const crossLen = 28.0;
      canvas.drawLine(Offset(center.dx - gap - crossLen, center.dy), Offset(center.dx - gap, center.dy), crosshairPaint);
      canvas.drawLine(Offset(center.dx + gap, center.dy), Offset(center.dx + gap + crossLen, center.dy), crosshairPaint);
      canvas.drawLine(Offset(center.dx, center.dy - gap - crossLen), Offset(center.dx, center.dy - gap), crosshairPaint);
      canvas.drawLine(Offset(center.dx, center.dy + gap), Offset(center.dx, center.dy + gap + crossLen), crosshairPaint);
    }

    // 5. Orientation Indicator (North at top, East at left)
    _drawOrientation(canvas, size, primaryColor);

    // 6. Physical Scale Ruler Bar (Bottom Left)
    _drawScaleBar(canvas, size, fovArcmin, pixelsPerArcmin, primaryColor);

    // 7. Apparent Size Label (Bottom Right)
    _drawApparentSizeLabel(canvas, size, primaryColor);
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
    Size size,
    double fovArcmin,
    double pixelsPerArcmin,
    Color color,
  ) {
    double scaleArcmin = 10.0;
    if (fovArcmin < 20.0) {
      scaleArcmin = 5.0;
    } else if (fovArcmin < 50.0) {
      scaleArcmin = 10.0;
    } else if (fovArcmin < 120.0) {
      scaleArcmin = 30.0;
    } else if (fovArcmin < 300.0) {
      scaleArcmin = 60.0;
    } else {
      scaleArcmin = 120.0;
    }

    final barPixels = scaleArcmin * pixelsPerArcmin;
    if (barPixels <= 0 || barPixels > size.width * 0.7) return;

    final scaleLabel = scaleArcmin >= 60.0
        ? "${(scaleArcmin / 60.0).toStringAsFixed(0)}°"
        : "${scaleArcmin.toStringAsFixed(0)}'";

    final startX = size.width * 0.28;
    final y = size.height - 14.0;

    final barPaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    canvas.drawLine(Offset(startX, y), Offset(startX + barPixels, y), barPaint);
    canvas.drawLine(Offset(startX, y - 3), Offset(startX, y + 3), barPaint);
    canvas.drawLine(Offset(startX + barPixels, y - 3), Offset(startX + barPixels, y + 3), barPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: scaleLabel,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color.withValues(alpha: 0.85)),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(startX + (barPixels - textPainter.width) / 2, y - 13));
  }

  void _drawApparentSizeLabel(Canvas canvas, Size size, Color color) {
    String label;
    if (target.majorAxisArcmin != null && target.majorAxisArcmin! > 0) {
      final maj = target.majorAxisArcmin!;
      label = maj >= 60.0
          ? "Size: ${(maj / 60.0).toStringAsFixed(1)}°"
          : "Size: ${maj.toStringAsFixed(1)}'";
    } else {
      label = "Point Source";
    }

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
        oldDelegate.showReticle != showReticle ||
        oldDelegate.showFraming != showFraming ||
        oldDelegate.equipment?.id != equipment?.id ||
        oldDelegate.cameraAngleDeg != cameraAngleDeg ||
        oldDelegate.showRuleOfThirds != showRuleOfThirds;
  }
}
