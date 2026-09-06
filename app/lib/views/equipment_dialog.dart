import 'package:flutter/material.dart';

import '../core/equipment_database.dart';
import '../core/equipment_manager.dart';
import '../models/equipment_profile.dart';
import '../theme/astro_theme.dart';

class EquipmentDialog extends StatefulWidget {
  final bool isRedNightMode;
  final VoidCallback onSaved;

  const EquipmentDialog({
    super.key,
    required this.isRedNightMode,
    required this.onSaved,
  });

  @override
  State<EquipmentDialog> createState() => _EquipmentDialogState();
}

class _EquipmentDialogState extends State<EquipmentDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Edit / Create Form State
  bool _isEditing = false;
  String? _editingId;

  final _rigNameController = TextEditingController();
  final _scopeNameController = TextEditingController();
  final _scopeFlController = TextEditingController();
  final _scopeApController = TextEditingController();
  final _scopeRedController = TextEditingController(text: "1.0");

  final _camNameController = TextEditingController();
  final _camWidthController = TextEditingController();
  final _camHeightController = TextEditingController();
  final _camPixelController = TextEditingController();
  final _camResWController = TextEditingController();
  final _camResHController = TextEditingController();

  // Search query controllers
  final _scopeSearchController = TextEditingController();
  final _camSearchController = TextEditingController();
  List<TelescopeProfile> _scopeSearchResults = [];
  List<CameraProfile> _camSearchResults = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _rigNameController.dispose();
    _scopeNameController.dispose();
    _scopeFlController.dispose();
    _scopeApController.dispose();
    _scopeRedController.dispose();
    _camNameController.dispose();
    _camWidthController.dispose();
    _camHeightController.dispose();
    _camPixelController.dispose();
    _camResWController.dispose();
    _camResHController.dispose();
    _scopeSearchController.dispose();
    _camSearchController.dispose();
    super.dispose();
  }

  void _startCreateNew() {
    setState(() {
      _isEditing = true;
      _editingId = null;
      _rigNameController.text = "New Rig";

      // Default with RedCat + ASI2600 values
      _scopeNameController.text = "William Optics RedCat 51 III";
      _scopeFlController.text = "250";
      _scopeApController.text = "51";
      _scopeRedController.text = "1.0";

      _camNameController.text = "ZWO ASI2600MC Pro";
      _camWidthController.text = "23.5";
      _camHeightController.text = "15.6";
      _camPixelController.text = "3.76";
      _camResWController.text = "6248";
      _camResHController.text = "4176";

      _scopeSearchController.clear();
      _camSearchController.clear();
      _scopeSearchResults = [];
      _camSearchResults = [];
    });
  }

  void _startEdit(EquipmentProfile profile) {
    setState(() {
      _isEditing = true;
      _editingId = profile.id;
      _rigNameController.text = profile.name;

      _scopeNameController.text = profile.telescope.name;
      _scopeFlController.text = profile.telescope.focalLengthMm.toString();
      _scopeApController.text = profile.telescope.apertureMm.toString();
      _scopeRedController.text = profile.telescope.reducerFactor.toString();

      _camNameController.text = profile.camera.name;
      _camWidthController.text = profile.camera.sensorWidthMm.toString();
      _camHeightController.text = profile.camera.sensorHeightMm.toString();
      _camPixelController.text = profile.camera.pixelSizeMicrons.toString();
      _camResWController.text = profile.camera.resolutionWidthPx.toString();
      _camResHController.text = profile.camera.resolutionHeightPx.toString();

      _scopeSearchController.clear();
      _camSearchController.clear();
      _scopeSearchResults = [];
      _camSearchResults = [];
    });
  }

  void _applyTelescopePreset(TelescopeProfile scope) {
    setState(() {
      _scopeNameController.text = scope.name;
      _scopeFlController.text = scope.focalLengthMm.toString();
      _scopeApController.text = scope.apertureMm.toString();
      _scopeRedController.text = scope.reducerFactor.toString();
      _scopeSearchController.clear();
      _scopeSearchResults = [];

      // If rig name was default, suggest a nice combo name
      if (_rigNameController.text == "New Rig" || _rigNameController.text.contains("Rig")) {
        final shortScope = scope.name.split('(').first.trim();
        final shortCam = _camNameController.text.split('(').first.trim();
        _rigNameController.text = "$shortScope + $shortCam";
      }
    });
  }

  void _applyCameraPreset(CameraProfile cam) {
    setState(() {
      _camNameController.text = cam.name;
      _camWidthController.text = cam.sensorWidthMm.toString();
      _camHeightController.text = cam.sensorHeightMm.toString();
      _camPixelController.text = cam.pixelSizeMicrons.toString();
      _camResWController.text = cam.resolutionWidthPx.toString();
      _camResHController.text = cam.resolutionHeightPx.toString();
      _camSearchController.clear();
      _camSearchResults = [];

      // If rig name was default, suggest a nice combo name
      if (_rigNameController.text == "New Rig" || _rigNameController.text.contains("Rig")) {
        final shortScope = _scopeNameController.text.split('(').first.trim();
        final shortCam = cam.name.split('(').first.trim();
        _rigNameController.text = "$shortScope + $shortCam";
      }
    });
  }

  void _saveCurrentProfile() {
    final name = _rigNameController.text.trim();
    if (name.isEmpty) return;

    final fl = double.tryParse(_scopeFlController.text) ?? 400.0;
    final ap = double.tryParse(_scopeApController.text) ?? 72.0;
    final red = double.tryParse(_scopeRedController.text) ?? 1.0;

    final sw = double.tryParse(_camWidthController.text) ?? 23.5;
    final sh = double.tryParse(_camHeightController.text) ?? 15.6;
    final px = double.tryParse(_camPixelController.text) ?? 3.76;
    final rw = int.tryParse(_camResWController.text) ?? 6248;
    final rh = int.tryParse(_camResHController.text) ?? 4176;

    final id = _editingId ?? "rig_${DateTime.now().millisecondsSinceEpoch}";

    final profile = EquipmentProfile(
      id: id,
      name: name,
      telescope: TelescopeProfile(
        id: "scope_$id",
        name: _scopeNameController.text.trim(),
        focalLengthMm: fl,
        apertureMm: ap,
        reducerFactor: red,
      ),
      camera: CameraProfile(
        id: "cam_$id",
        name: _camNameController.text.trim(),
        sensorWidthMm: sw,
        sensorHeightMm: sh,
        pixelSizeMicrons: px,
        resolutionWidthPx: rw,
        resolutionHeightPx: rh,
      ),
    );

    if (_editingId != null) {
      EquipmentManager.instance.updateProfile(profile);
    } else {
      EquipmentManager.instance.addProfile(profile);
    }

    widget.onSaved();
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;
    final borderColor = widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder;
    final surfaceColor = widget.isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface;

    return Dialog(
      backgroundColor: surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.camera_alt_rounded, size: 20, color: accentColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isEditing ? (_editingId == null ? "Add Equipment Rig" : "Edit Equipment Rig") : "Equipment Rigs & Optics",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textColor),
                    ),
                  ),
                  if (_isEditing)
                    TextButton.icon(
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text("Back to List"),
                      onPressed: () => setState(() => _isEditing = false),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
              const Divider(height: 20),

              // Content Area
              Expanded(
                child: _isEditing ? _buildEditor(textColor, accentColor, borderColor) : _buildProfileList(textColor, accentColor, borderColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileList(Color textColor, Color accentColor, Color borderColor) {
    final profiles = EquipmentManager.instance.profiles;
    final activeId = EquipmentManager.instance.activeProfileId;

    return Column(
      children: [
        Expanded(
          child: RadioGroup<String>(
            groupValue: activeId,
            onChanged: (id) {
              if (id != null) {
                EquipmentManager.instance.setActiveProfile(id);
                widget.onSaved();
                setState(() {});
              }
            },
            child: ListView.builder(
              itemCount: profiles.length,
              itemBuilder: (ctx, i) {
                final p = profiles[i];
                final isActive = p.id == activeId;

                return Card(
                  color: isActive
                      ? accentColor.withValues(alpha: 0.12)
                      : (widget.isRedNightMode ? AstroColors.nightVisionSurfaceVariant : AstroColors.spaceDarkSurfaceVariant),
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color: isActive ? accentColor : borderColor,
                      width: isActive ? 1.5 : 1.0,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Radio<String>(
                              value: p.id,
                              activeColor: accentColor,
                            ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "${p.telescope.name}  •  ${p.camera.name}",
                                  style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.7)),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            tooltip: "Edit Rig",
                            onPressed: () => _startEdit(p),
                          ),
                          if (profiles.length > 1)
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                              tooltip: "Delete Rig",
                              onPressed: () {
                                EquipmentManager.instance.deleteProfile(p.id);
                                widget.onSaved();
                                setState(() {});
                              },
                            ),
                        ],
                      ),
                      const Divider(height: 12),
                      // Specs Pills Row
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildMiniBadge("Focal: ${p.telescope.effectiveFocalLength.round()}mm (${p.telescope.focalRatioString})", accentColor),
                          _buildMiniBadge("FOV: ${p.sensorFovWidthDeg.toStringAsFixed(1)}° × ${p.sensorFovHeightDeg.toStringAsFixed(1)}°", AstroColors.starGold),
                          _buildMiniBadge("Scale: ${p.imageScaleArcsecPerPixel.toStringAsFixed(2)}\"/px", AstroColors.nebulaIndigo),
                          _buildMiniBadge(p.samplingCategory.split(' ').first, AstroColors.deepSkyTeal),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
      const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text("Create New Rig"),
            style: FilledButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _startCreateNew,
          ),
        ),
      ],
    );
  }

  Widget _buildEditor(Color textColor, Color accentColor, Color borderColor) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rig Name
          TextField(
            controller: _rigNameController,
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: "Rig Profile Name",
              labelStyle: TextStyle(color: accentColor),
              prefixIcon: Icon(Icons.label_rounded, size: 18, color: accentColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 16),

          // TELESCOPE SECTION
          Text(
            "Telescope / Optics",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: accentColor),
          ),
          const SizedBox(height: 6),

          // Telescope Search & Auto-Fill
          TextField(
            controller: _scopeSearchController,
            style: TextStyle(color: textColor, fontSize: 13),
            onChanged: (q) {
              setState(() {
                _scopeSearchResults = q.trim().isEmpty ? [] : EquipmentDatabase.searchTelescopes(q).take(6).toList();
              });
            },
            decoration: InputDecoration(
              hintText: "Search scope: e.g. RedCat, FRA400, 72ED, C8, Seestar...",
              hintStyle: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 12),
              prefixIcon: Icon(Icons.search_rounded, size: 18, color: accentColor),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.25),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),

          // Telescope search results autocomplete dropdown
          if (_scopeSearchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentColor.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: _scopeSearchResults.map((s) {
                  return ListTile(
                    dense: true,
                    title: Text(s.name, style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w600)),
                    subtitle: Text("FL: ${s.focalLengthMm.round()}mm  |  Aperture: ${s.apertureMm.round()}mm (${s.focalRatioString})",
                        style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.6))),
                    trailing: Icon(Icons.touch_app_rounded, size: 14, color: accentColor),
                    onTap: () => _applyTelescopePreset(s),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 8),
          TextField(
            controller: _scopeNameController,
            style: TextStyle(color: textColor, fontSize: 13),
            decoration: InputDecoration(
              labelText: "Telescope Name",
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _scopeFlController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: textColor, fontSize: 13),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: "Focal Length (mm)",
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _scopeApController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: textColor, fontSize: 13),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: "Aperture (mm)",
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _scopeRedController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: textColor, fontSize: 13),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: "Reducer (e.g. 0.8)",
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // CAMERA SECTION
          Text(
            "Camera / Sensor",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: accentColor),
          ),
          const SizedBox(height: 6),

          // Camera Search & Auto-Fill
          TextField(
            controller: _camSearchController,
            style: TextStyle(color: textColor, fontSize: 13),
            onChanged: (q) {
              setState(() {
                _camSearchResults = q.trim().isEmpty ? [] : EquipmentDatabase.searchCameras(q).take(6).toList();
              });
            },
            decoration: InputDecoration(
              hintText: "Search camera: e.g. ASI2600, ASI533, IMX571, Sony A7, Canon...",
              hintStyle: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 12),
              prefixIcon: Icon(Icons.search_rounded, size: 18, color: accentColor),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.25),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),

          // Camera search results autocomplete dropdown
          if (_camSearchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentColor.withValues(alpha: 0.4)),
              ),
              child: Column(
                children: _camSearchResults.map((c) {
                  return ListTile(
                    dense: true,
                    title: Text(c.name, style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.w600)),
                    subtitle: Text("Sensor: ${c.sensorWidthMm} × ${c.sensorHeightMm}mm  |  Pixel: ${c.pixelSizeMicrons}µm  |  ${c.megapixels.toStringAsFixed(1)}MP",
                        style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.6))),
                    trailing: Icon(Icons.touch_app_rounded, size: 14, color: accentColor),
                    onTap: () => _applyCameraPreset(c),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 8),
          TextField(
            controller: _camNameController,
            style: TextStyle(color: textColor, fontSize: 13),
            decoration: InputDecoration(
              labelText: "Camera Name",
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _camWidthController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: textColor, fontSize: 13),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: "Sensor Width (mm)",
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _camHeightController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: textColor, fontSize: 13),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: "Sensor Height (mm)",
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _camPixelController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: textColor, fontSize: 13),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: "Pixel Size (µm)",
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // LIVE COMPUTED OPTICS CARD
          _buildLiveOpticsCard(textColor, accentColor, borderColor),

          const SizedBox(height: 16),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => setState(() => _isEditing = false),
                child: const Text("Cancel"),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                icon: const Icon(Icons.save_rounded, size: 16),
                label: const Text("Save Rig"),
                style: FilledButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.black),
                onPressed: _saveCurrentProfile,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveOpticsCard(Color textColor, Color accentColor, Color borderColor) {
    final fl = double.tryParse(_scopeFlController.text) ?? 250.0;
    final ap = double.tryParse(_scopeApController.text) ?? 51.0;
    final red = double.tryParse(_scopeRedController.text) ?? 1.0;
    final sw = double.tryParse(_camWidthController.text) ?? 23.5;
    final sh = double.tryParse(_camHeightController.text) ?? 15.6;
    final px = double.tryParse(_camPixelController.text) ?? 3.76;

    final tempProfile = EquipmentProfile(
      id: 'preview',
      name: 'Preview',
      telescope: TelescopeProfile(id: 't', name: 'T', focalLengthMm: fl, apertureMm: ap, reducerFactor: red),
      camera: CameraProfile(id: 'c', name: 'C', sensorWidthMm: sw, sensorHeightMm: sh, pixelSizeMicrons: px, resolutionWidthPx: 6000, resolutionHeightPx: 4000),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 14, color: accentColor),
              const SizedBox(width: 6),
              Text("Computed Optical Specifications", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSpecItem("Effective Focal", "${tempProfile.telescope.effectiveFocalLength.round()}mm", textColor),
              _buildSpecItem("Focal Ratio", tempProfile.telescope.focalRatioString, textColor),
              _buildSpecItem("Sensor FOV", "${tempProfile.sensorFovWidthDeg.toStringAsFixed(1)}° × ${tempProfile.sensorFovHeightDeg.toStringAsFixed(1)}°", textColor),
              _buildSpecItem("Image Scale", "${tempProfile.imageScaleArcsecPerPixel.toStringAsFixed(2)}\"/px", textColor),
            ],
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              "Sampling: ${tempProfile.samplingCategory}",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accentColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecItem(String label, String value, Color textColor) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
        Text(label, style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.6))),
      ],
    );
  }

  Widget _buildMiniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
