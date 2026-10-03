import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/equipment_manager.dart';
import '../l10n/app_localizations.dart';
import '../models/equipment_profile.dart';
import '../models/target_item.dart';
import '../theme/astro_theme.dart';
import '../utils/astro_formatters.dart';
import '../widgets/target_preview_canvas.dart';
import 'equipment_dialog.dart';

class EquipmentFramingDialog extends StatefulWidget {
  final TargetItem target;
  final bool? isRedNightMode;

  const EquipmentFramingDialog({
    super.key,
    required this.target,
    this.isRedNightMode,
  });

  @override
  State<EquipmentFramingDialog> createState() => _EquipmentFramingDialogState();
}

class _EquipmentFramingDialogState extends State<EquipmentFramingDialog> {
  final GlobalKey<TargetPreviewCanvasState> _canvasKey = GlobalKey<TargetPreviewCanvasState>();
  double _panStepArcmin = 5.0;
  String _lastActiveProfileId = '';

  @override
  void initState() {
    super.initState();
    _lastActiveProfileId = EquipmentManager.instance.activeProfile.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        EquipmentManager.instance.resetPan();
        _fitToSensor();
      }
    });
    EquipmentManager.instance.addListener(_onEquipmentChanged);
  }

  @override
  void dispose() {
    EquipmentManager.instance.removeListener(_onEquipmentChanged);
    super.dispose();
  }

  void _onEquipmentChanged() {
    if (!mounted) return;
    final currentProfileId = EquipmentManager.instance.activeProfile.id;
    if (currentProfileId != _lastActiveProfileId) {
      _lastActiveProfileId = currentProfileId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fitToSensor();
        }
      });
    }
    setState(() {});
  }

  String _formatRa(double hours) => AstroFormatters.formatRa(hours);
  String _formatDec(double degrees) => AstroFormatters.formatDec(degrees);

  void _pan(double factorX, double factorY) {
    EquipmentManager.instance.panBy(
      deltaXArcmin: factorX * _panStepArcmin,
      deltaYArcmin: factorY * _panStepArcmin,
    );
  }

  void _copyFramingInfo() {
    final rig = EquipmentManager.instance.activeProfile;
    final angle = EquipmentManager.instance.cameraAngleDeg;
    final panX = EquipmentManager.instance.panOffsetArcminX;
    final panY = EquipmentManager.instance.panOffsetArcminY;
    final totalOffset = EquipmentManager.instance.totalPanOffsetArcmin;

    final dDecArcmin = -panY;
    final dRaArcminOnSky = -panX;
    final decRad = widget.target.decDegrees * math.pi / 180.0;
    final cosDec = math.cos(decRad).abs().clamp(0.01, 1.0);
    final dRaHours = (dRaArcminOnSky / cosDec) / 900.0;
    final dDecDeg = dDecArcmin / 60.0;

    var centerRa = (widget.target.raHours + dRaHours) % 24.0;
    if (centerRa < 0) centerRa += 24.0;
    final centerDec = (widget.target.decDegrees + dDecDeg).clamp(-90.0, 90.0);

    final hasOffset = totalOffset > 0.05;

    final text = '''
--- ASTRO TARGET FRAMING PLAN ---
Target: ${widget.target.displayName}
Target Catalog Coordinates: RA: ${widget.target.formattedRa} | Dec: ${widget.target.formattedDec}${widget.target.positionAngleDeg != null ? ' | Target PA: ${widget.target.positionAngleDeg!.toStringAsFixed(1)}°' : ''}
${hasOffset ? 'Framing Center Coordinates: RA: ${_formatRa(centerRa)} | Dec: ${_formatDec(centerDec)}\nFraming Offset: ΔRA: ${(-panX >= 0 ? '+' : '')}${(-panX).toStringAsFixed(1)}\' | ΔDec: ${(dDecArcmin >= 0 ? '+' : '')}${dDecArcmin.toStringAsFixed(1)}\' (Total: ${totalOffset.toStringAsFixed(1)}\')' : 'Framing Center: Centered on target'}
Equipment Rig: ${rig.name}
Telescope: ${rig.telescope.name} (${rig.telescope.effectiveFocalLength.round()}mm ${rig.telescope.focalRatioString})
Camera: ${rig.camera.name} (${rig.camera.sensorWidthMm}x${rig.camera.sensorHeightMm}mm, ${rig.camera.pixelSizeMicrons}µm)
Sensor FOV: ${rig.sensorFovWidthDeg.toStringAsFixed(2)}° × ${rig.sensorFovHeightDeg.toStringAsFixed(2)}° (${rig.sensorFovWidthArcmin.toStringAsFixed(1)}' × ${rig.sensorFovHeightArcmin.toStringAsFixed(1)}')
Camera Rotator Angle: ${angle.toStringAsFixed(1)}°
Image Scale: ${rig.imageScaleArcsecPerPixel.toStringAsFixed(2)}"/pixel
Sampling: ${rig.samplingCategory}
---------------------------------''';

    Clipboard.setData(ClipboardData(text: text));
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.framingSpecsCopied),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openEquipmentManager() {
    showDialog(
      context: context,
      builder: (_) => EquipmentDialog(
        onSaved: () => setState(() {}),
      ),
    );
  }

  void _autoAlignWithTarget() {
    final pa = widget.target.positionAngleDeg ?? 0.0;
    EquipmentManager.instance.autoAlignWithTarget(pa);
  }

  void _fitToSensor() {
    _canvasKey.currentState?.fitToSensor();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AstroPalette.of(context);
    final textColor = palette.textPrimary;
    final accentColor = palette.accent;
    final borderColor = palette.border;
    final surfaceColor = palette.surface;

    final rig = EquipmentManager.instance.activeProfile;
    final angle = EquipmentManager.instance.cameraAngleDeg;

    final isWide = MediaQuery.of(context).size.width >= 800;

    return Dialog(
      backgroundColor: surfaceColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 850),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Top Bar
              Row(
                children: [
                  Icon(Icons.crop_rotate_rounded, size: 22, color: accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${widget.target.displayName} — ${l10n.framingSimulatorTitle}",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          l10n.activeRigLabel(rig.name),
                          style: TextStyle(fontSize: 11, color: accentColor),
                        ),
                      ],
                    ),
                  ),

                  // Equipment Selector Dropdown
                  PopupMenuButton<String>(
                    tooltip: l10n.switchRigTooltip,
                    color: surfaceColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: borderColor),
                    ),
                    initialValue: rig.id,
                    onSelected: (id) {
                      final isNew = id != EquipmentManager.instance.activeProfile.id;
                      EquipmentManager.instance.setActiveProfile(id);
                      if (isNew) {
                        _fitToSensor();
                      }
                    },
                    itemBuilder: (ctx) => EquipmentManager.instance.profiles.map((p) {
                      return PopupMenuItem<String>(
                        value: p.id,
                        child: Text(p.name, style: TextStyle(fontSize: 12, color: p.id == rig.id ? accentColor : textColor)),
                      );
                    }).toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune_rounded, size: 14, color: accentColor),
                          const SizedBox(width: 4),
                          Text(l10n.rigsLabel, style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 2),
                          Icon(Icons.arrow_drop_down_rounded, size: 16, color: textColor),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.settings_suggest_rounded, size: 20),
                    tooltip: l10n.manageRigsTooltip,
                    onPressed: _openEquipmentManager,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    tooltip: l10n.closeFramingSimulator,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 16),

              // Framing Content Area
              Expanded(
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left: Large Framing Canvas
                          Expanded(
                            flex: 6,
                            child: _buildFramingCanvas(),
                          ),
                          const SizedBox(width: 16),
                          // Right: Controls & Optics Panel
                          Expanded(
                            flex: 4,
                            child: SingleChildScrollView(
                              child: _buildControlsPanel(rig, angle, textColor, accentColor, borderColor, l10n),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(child: _buildFramingCanvas()),
                          const SizedBox(height: 12),
                          Expanded(
                            child: SingleChildScrollView(
                              child: _buildControlsPanel(rig, angle, textColor, accentColor, borderColor, l10n),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFramingCanvas() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: TargetPreviewCanvas(
        key: _canvasKey,
        target: widget.target,
        height: double.infinity,
        enableExpandDialog: false,
        initialFramingEnabled: true,
      ),
    );
  }

  Widget _buildControlsPanel(
    EquipmentProfile rig,
    double angle,
    Color textColor,
    Color accentColor,
    Color borderColor,
    AppLocalizations l10n,
  ) {
    final palette = AstroPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Camera Rotator Angle Slider Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.rotate_right_rounded, size: 16, color: accentColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.cameraRotatorAngle,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      "${angle.toStringAsFixed(1)}°",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: accentColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Slider(
                value: angle,
                min: 0.0,
                max: 360.0,
                activeColor: accentColor,
                inactiveColor: Colors.white.withValues(alpha: 0.15),
                onChanged: (val) => EquipmentManager.instance.setCameraAngle(val),
              ),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  _buildQuickAngleBtn("-90°", () => EquipmentManager.instance.rotateBy(-90), textColor),
                  _buildQuickAngleBtn("-15°", () => EquipmentManager.instance.rotateBy(-15), textColor),
                  _buildQuickAngleBtn("0°", () => EquipmentManager.instance.setCameraAngle(0), textColor),
                  _buildQuickAngleBtn("+15°", () => EquipmentManager.instance.rotateBy(15), textColor),
                  _buildQuickAngleBtn("+90°", () => EquipmentManager.instance.rotateBy(90), textColor),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Framing Pan Offset Controller
        _buildPanCard(rig, textColor, accentColor, borderColor, l10n),

        const SizedBox(height: 12),

        // Quick Composition Tools
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.fit_screen_rounded, size: 15),
                label: Text(l10n.fitToSensor, style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  foregroundColor: textColor,
                  side: BorderSide(color: borderColor),
                ),
                onPressed: _fitToSensor,
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: l10n.autoAlignTargetTooltip,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.auto_awesome_rounded, size: 13),
                label: Text(l10n.autoAlignTarget, style: const TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  foregroundColor: textColor,
                  side: BorderSide(color: borderColor),
                ),
                onPressed: _autoAlignWithTarget,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Rule of Thirds Grid Toggle
        SwitchListTile(
          title: Text(l10n.ruleOfThirdsGrid, style: TextStyle(fontSize: 13, color: textColor, fontWeight: FontWeight.w600)),
          subtitle: Text(l10n.ruleOfThirdsSubtitle, style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.6))),
          value: EquipmentManager.instance.showRuleOfThirds,
          activeThumbColor: accentColor,
          dense: true,
          contentPadding: EdgeInsets.zero,
          onChanged: (val) => EquipmentManager.instance.toggleRuleOfThirds(val),
        ),

        const SizedBox(height: 12),

        // Optics & Sampling Breakdown Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.opticalSystemMetrics, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
              const Divider(height: 12),
              _buildMetricRow(l10n.effectiveFocalLength, "${rig.telescope.effectiveFocalLength.round()} mm (${rig.telescope.focalRatioString})", textColor),
              _buildMetricRow(l10n.sensorFovDegrees, "${rig.sensorFovWidthDeg.toStringAsFixed(2)}° × ${rig.sensorFovHeightDeg.toStringAsFixed(2)}°", textColor),
              _buildMetricRow(l10n.sensorFovArcmin, "${rig.sensorFovWidthArcmin.toStringAsFixed(1)}' × ${rig.sensorFovHeightArcmin.toStringAsFixed(1)}'", textColor),
              _buildMetricRow(l10n.imageScalePixelSize, "${rig.imageScaleArcsecPerPixel.toStringAsFixed(2)}\" / pixel", textColor),
              _buildMetricRow(l10n.samplingDiagnosis, rig.samplingCategory, accentColor),
              _buildMetricRow(l10n.sensorResolution, "${rig.camera.resolutionWidthPx} × ${rig.camera.resolutionHeightPx} (${rig.camera.megapixels.toStringAsFixed(1)} MP)", textColor),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Copy Info Button (as small as possible)
        Align(
          alignment: Alignment.centerRight,
          child: Tooltip(
            message: l10n.copyFramingSpecsTooltip,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _copyFramingInfo,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy_rounded, size: 12, color: accentColor),
                      const SizedBox(width: 4),
                      Text(
                        l10n.copyFramingInfo,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPanCard(EquipmentProfile rig, Color textColor, Color accentColor, Color borderColor, AppLocalizations l10n) {
    final panX = EquipmentManager.instance.panOffsetArcminX;
    final panY = EquipmentManager.instance.panOffsetArcminY;
    final totalOffset = EquipmentManager.instance.totalPanOffsetArcmin;
    final hasOffset = totalOffset > 0.05;

    // Calculate Framing Center coordinates
    final dDecArcmin = -panY;
    final dRaArcminOnSky = -panX;
    final decRad = widget.target.decDegrees * math.pi / 180.0;
    final cosDec = math.cos(decRad).abs().clamp(0.01, 1.0);
    final dRaHours = (dRaArcminOnSky / cosDec) / 900.0;
    final dDecDeg = dDecArcmin / 60.0;

    var centerRa = (widget.target.raHours + dRaHours) % 24.0;
    if (centerRa < 0) centerRa += 24.0;
    final centerDec = (widget.target.decDegrees + dDecDeg).clamp(-90.0, 90.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.open_with_rounded, size: 16, color: accentColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.framingPanOffset,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: hasOffset ? accentColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: hasOffset ? accentColor.withValues(alpha: 0.4) : borderColor),
                ),
                child: Text(
                  hasOffset
                      ? (l10n.offsetLabel(totalOffset.toStringAsFixed(1)))
                      : (l10n.centered),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: hasOffset ? accentColor : textColor.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Direction Pad + Step Size
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 3x3 Keypad
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor.withValues(alpha: 0.5)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPanBtn(Icons.north_west_rounded, "Pan Up-Left (NW)", () => _pan(-1.0, -1.0), textColor),
                        const SizedBox(width: 4),
                        _buildPanBtn(Icons.north_rounded, "Pan Up (North)", () => _pan(0.0, -1.0), textColor),
                        const SizedBox(width: 4),
                        _buildPanBtn(Icons.north_east_rounded, "Pan Up-Right (NE)", () => _pan(1.0, -1.0), textColor),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPanBtn(Icons.west_rounded, "Pan Left (East)", () => _pan(-1.0, 0.0), textColor),
                        const SizedBox(width: 4),
                        _buildPanBtn(
                          Icons.filter_center_focus_rounded,
                          l10n.resetToCenter,
                          () => EquipmentManager.instance.resetPan(),
                          hasOffset ? accentColor : textColor.withValues(alpha: 0.4),
                          isCenter: true,
                        ),
                        const SizedBox(width: 4),
                        _buildPanBtn(Icons.east_rounded, "Pan Right (West)", () => _pan(1.0, 0.0), textColor),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPanBtn(Icons.south_west_rounded, "Pan Down-Left (SW)", () => _pan(-1.0, 1.0), textColor),
                        const SizedBox(width: 4),
                        _buildPanBtn(Icons.south_rounded, "Pan Down (South)", () => _pan(0.0, 1.0), textColor),
                        const SizedBox(width: 4),
                        _buildPanBtn(Icons.south_east_rounded, "Pan Down-Right (SE)", () => _pan(1.0, 1.0), textColor),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Step Size Selection & Live Shift
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.stepSize, style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.7), fontWeight: FontWeight.w500)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [1.0, 5.0, 15.0].map((step) {
                        final isSelected = (_panStepArcmin - step).abs() < 0.1;
                        return InkWell(
                          onTap: () => setState(() => _panStepArcmin = step),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected ? accentColor.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected ? accentColor : borderColor,
                              ),
                            ),
                            child: Text(
                              "${step.toInt()}'",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? accentColor : textColor,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    if (hasOffset) ...[
                      Text(
                        "ΔX: ${panX >= 0 ? '+' : ''}${panX.toStringAsFixed(1)}' | ΔY: ${panY >= 0 ? '+' : ''}${panY.toStringAsFixed(1)}'",
                        style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.8), fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Center: ${_formatRa(centerRa)}",
                        style: TextStyle(fontSize: 10, color: accentColor, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        "Dec: ${_formatDec(centerDec)}",
                        style: TextStyle(fontSize: 10, color: accentColor, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else ...[
                      Text(
                        l10n.useArrowsToFrame,
                        style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.5), fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPanBtn(IconData icon, String tooltip, VoidCallback onTap, Color iconColor, {bool isCenter = false}) {
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
            decoration: BoxDecoration(
              color: isCenter ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: isCenter ? 18 : 16, color: iconColor),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAngleBtn(String label, VoidCallback onTap, Color textColor) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: valueColor),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
