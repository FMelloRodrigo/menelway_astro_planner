import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/equipment_manager.dart';
import '../models/equipment_profile.dart';
import '../models/target_item.dart';
import '../theme/astro_theme.dart';
import '../widgets/target_preview_canvas.dart';
import 'equipment_dialog.dart';

class EquipmentFramingDialog extends StatefulWidget {
  final TargetItem target;
  final bool isRedNightMode;

  const EquipmentFramingDialog({
    super.key,
    required this.target,
    required this.isRedNightMode,
  });

  @override
  State<EquipmentFramingDialog> createState() => _EquipmentFramingDialogState();
}

class _EquipmentFramingDialogState extends State<EquipmentFramingDialog> {
  final GlobalKey<TargetPreviewCanvasState> _canvasKey = GlobalKey<TargetPreviewCanvasState>();

  @override
  void initState() {
    super.initState();
    EquipmentManager.instance.addListener(_onEquipmentChanged);
  }

  @override
  void dispose() {
    EquipmentManager.instance.removeListener(_onEquipmentChanged);
    super.dispose();
  }

  void _onEquipmentChanged() {
    if (mounted) setState(() {});
  }

  void _copyFramingInfo() {
    final rig = EquipmentManager.instance.activeProfile;
    final angle = EquipmentManager.instance.cameraAngleDeg;

    final text = '''
--- ASTRO TARGET FRAMING PLAN ---
Target: ${widget.target.displayName}
RA: ${widget.target.formattedRa} | Dec: ${widget.target.formattedDec}
Equipment Rig: ${rig.name}
Telescope: ${rig.telescope.name} (${rig.telescope.effectiveFocalLength.round()}mm ${rig.telescope.focalRatioString})
Camera: ${rig.camera.name} (${rig.camera.sensorWidthMm}x${rig.camera.sensorHeightMm}mm, ${rig.camera.pixelSizeMicrons}µm)
Sensor FOV: ${rig.sensorFovWidthDeg.toStringAsFixed(2)}° × ${rig.sensorFovHeightDeg.toStringAsFixed(2)}° (${rig.sensorFovWidthArcmin.toStringAsFixed(1)}' × ${rig.sensorFovHeightArcmin.toStringAsFixed(1)}')
Camera Rotator Angle: ${angle.toStringAsFixed(1)}°
Image Scale: ${rig.imageScaleArcsecPerPixel.toStringAsFixed(2)}"/pixel
Sampling: ${rig.samplingCategory}
---------------------------------''';

    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Framing specs copied to clipboard (ready for N.I.N.A. / ASIAIR / Stellarium)"),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openEquipmentManager() {
    showDialog(
      context: context,
      builder: (_) => EquipmentDialog(
        isRedNightMode: widget.isRedNightMode,
        onSaved: () => setState(() {}),
      ),
    );
  }

  void _autoAlignWithTarget() {
    // 35 degrees default visual axis tilt for galaxies/nebulae
    EquipmentManager.instance.autoAlignWithTarget(35.0);
  }

  void _fitToSensor() {
    final rig = EquipmentManager.instance.activeProfile;
    final diag = rig.sensorFovDiagonalDeg;
    _canvasKey.currentState?.setCustomFov(diag * 1.35);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;
    final borderColor = widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder;
    final surfaceColor = widget.isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface;

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
                          "${widget.target.displayName} — Equipment Framing Simulator",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "Active Rig: ${rig.name}",
                          style: TextStyle(fontSize: 11, color: accentColor),
                        ),
                      ],
                    ),
                  ),

                  // Equipment Selector Dropdown
                  PopupMenuButton<String>(
                    tooltip: "Switch Equipment Rig",
                    color: surfaceColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: borderColor),
                    ),
                    initialValue: rig.id,
                    onSelected: (id) {
                      EquipmentManager.instance.setActiveProfile(id);
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
                          Text("Rigs", style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 2),
                          Icon(Icons.arrow_drop_down_rounded, size: 16, color: textColor),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.settings_suggest_rounded, size: 20),
                    tooltip: "Manage Rigs / Add Gear",
                    onPressed: _openEquipmentManager,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    tooltip: "Close Framing Simulator",
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
                              child: _buildControlsPanel(rig, angle, textColor, accentColor, borderColor),
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
                              child: _buildControlsPanel(rig, angle, textColor, accentColor, borderColor),
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
        isRedNightMode: widget.isRedNightMode,
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
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Camera Rotator Angle Slider Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: widget.isRedNightMode ? AstroColors.nightVisionSurfaceVariant : AstroColors.spaceDarkSurfaceVariant,
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
                  Text("Camera Rotator Angle", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
                  const Spacer(),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
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

        // Quick Composition Tools
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.auto_awesome_rounded, size: 15),
                label: const Text("Auto-Align", style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  foregroundColor: accentColor,
                  side: BorderSide(color: accentColor.withValues(alpha: 0.5)),
                ),
                onPressed: _autoAlignWithTarget,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.fit_screen_rounded, size: 15),
                label: const Text("Fit to Sensor", style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  foregroundColor: textColor,
                  side: BorderSide(color: borderColor),
                ),
                onPressed: _fitToSensor,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Rule of Thirds Grid Toggle
        SwitchListTile(
          title: Text("Rule of Thirds Grid", style: TextStyle(fontSize: 13, color: textColor, fontWeight: FontWeight.w600)),
          subtitle: Text("Overlay composition cross-lines inside sensor frame", style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.6))),
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
              Text("Optical System Metrics", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
              const Divider(height: 12),
              _buildMetricRow("Effective Focal Length", "${rig.telescope.effectiveFocalLength.round()} mm (${rig.telescope.focalRatioString})", textColor),
              _buildMetricRow("Sensor Field of View", "${rig.sensorFovWidthDeg.toStringAsFixed(2)}° × ${rig.sensorFovHeightDeg.toStringAsFixed(2)}°", textColor),
              _buildMetricRow("Sensor FOV (Arcmin)", "${rig.sensorFovWidthArcmin.toStringAsFixed(1)}' × ${rig.sensorFovHeightArcmin.toStringAsFixed(1)}'", textColor),
              _buildMetricRow("Image Scale (Pixel Size)", "${rig.imageScaleArcsecPerPixel.toStringAsFixed(2)}\" / pixel", textColor),
              _buildMetricRow("Sampling Diagnosis", rig.samplingCategory, accentColor),
              _buildMetricRow("Sensor Resolution", "${rig.camera.resolutionWidthPx} × ${rig.camera.resolutionHeightPx} (${rig.camera.megapixels.toStringAsFixed(1)} MP)", textColor),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Copy Info Button (as small as possible)
        Align(
          alignment: Alignment.centerRight,
          child: Tooltip(
            message: "Copy Framing Specs (N.I.N.A. / ASIAIR / Stellarium)",
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
                        "Copy Info",
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
          Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: valueColor)),
        ],
      ),
    );
  }
}
