import 'package:flutter/material.dart';

import '../models/filter_state.dart';
import '../theme/astro_theme.dart';

class FilterDialog extends StatefulWidget {
  final FilterState initialFilters;
  final bool isRedNightMode;
  final void Function(FilterState updated) onApply;

  const FilterDialog({
    super.key,
    required this.initialFilters,
    this.isRedNightMode = false,
    required this.onApply,
  });

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  late FilterState _state;

  final List<String> allCatalogs = [
    'Messier',
    'Caldwell',
    'NGC',
    'IC',
    'Sharpless',
    'Barnard',
  ];

  final List<String> allTypes = [
    'Galaxy',
    'Planetary Nebula',
    'Bright Nebula',
    'Dark Nebula',
    'Open Cluster',
    'Globular Cluster',
    'Supernova Remnant',
  ];

  final List<String> quadrants = [
    'All Directions',
    'North (315°-45°)',
    'East (45°-135°)',
    'South (135°-225°)',
    'West (225°-315°)',
    'North-East (0°-90°)',
    'South-East (90°-180°)',
    'South-West (180°-270°)',
    'North-West (270°-360°)',
  ];

  @override
  void initState() {
    super.initState();
    _state = widget.initialFilters.copyWith();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;

    return Dialog(
      backgroundColor: widget.isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 650,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.tune_rounded, color: accentColor, size: 22),
                const SizedBox(width: 8),
                Text(
                  "Target Filter Parameters",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: textColor.withValues(alpha: 0.6)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 20),

            // Filter Body (Scrollable)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Altitude & Duration (Telescopius core)
                    _buildSectionHeader("Visibility & Altitude (Telescopius Rule)", Icons.terrain_rounded),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Minimum Altitude: ${_state.minAltitude.round()}°",
                                style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.9)),
                              ),
                              Slider(
                                value: _state.minAltitude,
                                min: 10,
                                max: 70,
                                divisions: 12,
                                activeColor: accentColor,
                                onChanged: (v) => setState(() => _state.minAltitude = v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Minimum Duration: ${_state.minDurationHours.toStringAsFixed(1)} hrs",
                                style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.9)),
                              ),
                              Slider(
                                value: _state.minDurationHours,
                                min: 0.5,
                                max: 8.0,
                                divisions: 15,
                                activeColor: accentColor,
                                onChanged: (v) => setState(() => _state.minDurationHours = v),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Section 2: Direction / Quadrant & Azimuth
                    _buildSectionHeader("Direction & Azimuth Range", Icons.explore_rounded),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: _state.quadrant,
                      decoration: const InputDecoration(labelText: "Sky Quadrant Preset"),
                      dropdownColor: widget.isRedNightMode
                          ? AstroColors.nightVisionSurfaceVariant
                          : AstroColors.spaceDarkSurfaceVariant,
                      items: List.generate(quadrants.length, (i) {
                        return DropdownMenuItem(
                          value: i,
                          child: Text(quadrants[i], style: TextStyle(color: textColor, fontSize: 13)),
                        );
                      }),
                      onChanged: (v) {
                        if (v != null) setState(() => _state.quadrant = v);
                      },
                    ),

                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Min Azimuth: ${_state.minAzimuth.round()}°",
                                style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.8)),
                              ),
                              Slider(
                                value: _state.minAzimuth,
                                min: 0,
                                max: 360,
                                divisions: 36,
                                activeColor: accentColor,
                                onChanged: (v) => setState(() => _state.minAzimuth = v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Max Azimuth: ${_state.maxAzimuth.round()}°",
                                style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.8)),
                              ),
                              Slider(
                                value: _state.maxAzimuth,
                                min: 0,
                                max: 360,
                                divisions: 36,
                                activeColor: accentColor,
                                onChanged: (v) => setState(() => _state.maxAzimuth = v),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Section 3: Moon Separation
                    _buildSectionHeader("Moon Distance", Icons.brightness_3_rounded),
                    const SizedBox(height: 8),
                    Text(
                      "Min distance from Moon: ${_state.minMoonSeparation.round()}°",
                      style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.9)),
                    ),
                    Slider(
                      value: _state.minMoonSeparation,
                      min: 0,
                      max: 90,
                      divisions: 18,
                      activeColor: accentColor,
                      onChanged: (v) => setState(() => _state.minMoonSeparation = v),
                    ),

                    const SizedBox(height: 16),

                    // Section 4: Catalogs
                    _buildSectionHeader("Catalogs", Icons.auto_stories_rounded),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allCatalogs.map((cat) {
                        final selected = _state.selectedCatalogs.contains(cat);
                        return FilterChip(
                          label: Text(cat),
                          selected: selected,
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _state.selectedCatalogs.add(cat);
                              } else if (_state.selectedCatalogs.length > 1) {
                                _state.selectedCatalogs.remove(cat);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // Section 5: Object Types
                    _buildSectionHeader("Object Types", Icons.blur_circular_rounded),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allTypes.map((type) {
                        final selected = _state.selectedObjectTypes.contains(type);
                        return FilterChip(
                          label: Text(type),
                          selected: selected,
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _state.selectedObjectTypes.add(type);
                              } else if (_state.selectedObjectTypes.length > 1) {
                                _state.selectedObjectTypes.remove(type);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // Section 6: Magnitude & Size
                    _buildSectionHeader("Magnitude & Apparent Size", Icons.straighten_rounded),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Max Visual Mag: ${_state.maxMagnitude.toStringAsFixed(1)}",
                                style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.8)),
                              ),
                              Slider(
                                value: _state.maxMagnitude,
                                min: 5.0,
                                max: 18.0,
                                divisions: 26,
                                activeColor: accentColor,
                                onChanged: (v) => setState(() => _state.maxMagnitude = v),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Min Size: ${_state.minSizeArcmin.round()}'",
                                style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.8)),
                              ),
                              Slider(
                                value: _state.minSizeArcmin,
                                min: 0,
                                max: 60,
                                divisions: 12,
                                activeColor: accentColor,
                                onChanged: (v) => setState(() => _state.minSizeArcmin = v),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 20),

            // Footer Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text("Reset Filters"),
                  style: TextButton.styleFrom(foregroundColor: textColor.withValues(alpha: 0.6)),
                  onPressed: () {
                    setState(() {
                      _state = FilterState(
                        observerLat: _state.observerLat,
                        observerLon: _state.observerLon,
                        observerElevation: _state.observerElevation,
                        date: _state.date,
                      );
                    });
                  },
                ),
                Row(
                  children: [
                    OutlinedButton(
                      child: const Text("Cancel"),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text("Apply Filters"),
                      style: FilledButton.styleFrom(backgroundColor: accentColor),
                      onPressed: () {
                        widget.onApply(_state);
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    final color = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: color,
          ),
        ),
      ],
    );
  }
}
