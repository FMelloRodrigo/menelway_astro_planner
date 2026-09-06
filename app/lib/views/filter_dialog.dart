import 'dart:math' as math;
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

  final List<String> quadrantOptions = [
    'All Directions (0° - 360°)',
    'North (315° - 45°)',
    'East (45° - 135°)',
    'South (135° - 225°)',
    'West (225° - 315°)',
    'North-East (0° - 90°)',
    'South-East (90° - 180°)',
    'South-West (180° - 270°)',
    'North-West (270° - 360°)',
    'Custom Degree Range',
  ];

  int _getPresetIndex() {
    final min = _state.minAzimuth.round();
    final max = _state.maxAzimuth.round();
    if (min == 0 && max == 360) return 0;
    if (min == 315 && max == 45) return 1;
    if (min == 45 && max == 135) return 2;
    if (min == 135 && max == 225) return 3;
    if (min == 225 && max == 315) return 4;
    if (min == 0 && max == 90) return 5;
    if (min == 90 && max == 180) return 6;
    if (min == 180 && max == 270) return 7;
    if (min == 270 && max == 360) return 8;
    return 9; // Custom Degree Range
  }

  void _applyPreset(int index) {
    switch (index) {
      case 0:
        _state.minAzimuth = 0.0;
        _state.maxAzimuth = 360.0;
        _state.quadrant = 0;
        break;
      case 1:
        _state.minAzimuth = 315.0;
        _state.maxAzimuth = 45.0;
        _state.quadrant = 0;
        break;
      case 2:
        _state.minAzimuth = 45.0;
        _state.maxAzimuth = 135.0;
        _state.quadrant = 0;
        break;
      case 3:
        _state.minAzimuth = 135.0;
        _state.maxAzimuth = 225.0;
        _state.quadrant = 0;
        break;
      case 4:
        _state.minAzimuth = 225.0;
        _state.maxAzimuth = 315.0;
        _state.quadrant = 0;
        break;
      case 5:
        _state.minAzimuth = 0.0;
        _state.maxAzimuth = 90.0;
        _state.quadrant = 0;
        break;
      case 6:
        _state.minAzimuth = 90.0;
        _state.maxAzimuth = 180.0;
        _state.quadrant = 0;
        break;
      case 7:
        _state.minAzimuth = 180.0;
        _state.maxAzimuth = 270.0;
        _state.quadrant = 0;
        break;
      case 8:
        _state.minAzimuth = 270.0;
        _state.maxAzimuth = 360.0;
        _state.quadrant = 0;
        break;
      case 9:
        _state.quadrant = 0;
        break;
    }
  }

  String _cardinalName(double az) {
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

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Interactive Visual Compass Dial
                        AzimuthCompassDial(
                          minAzimuth: _state.minAzimuth,
                          maxAzimuth: _state.maxAzimuth,
                          isRedNightMode: widget.isRedNightMode,
                        ),
                        const SizedBox(width: 16),

                        // Preset Dropdown & Sliders
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DropdownButtonFormField<int>(
                                key: ValueKey(_getPresetIndex()),
                                initialValue: _getPresetIndex(),
                                decoration: const InputDecoration(
                                  labelText: "Direction Preset / Mode",
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                dropdownColor: widget.isRedNightMode
                                    ? AstroColors.nightVisionSurfaceVariant
                                    : AstroColors.spaceDarkSurfaceVariant,
                                items: List.generate(quadrantOptions.length, (i) {
                                  return DropdownMenuItem(
                                    value: i,
                                    child: Text(
                                      quadrantOptions[i],
                                      style: TextStyle(color: textColor, fontSize: 13),
                                    ),
                                  );
                                }),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() {
                                      _applyPreset(v);
                                    });
                                  }
                                },
                              ),
                              const SizedBox(height: 10),

                              // Min Azimuth Slider
                              Row(
                                children: [
                                  SizedBox(
                                    width: 115,
                                    child: Text(
                                      "Min: ${_state.minAzimuth.round()}° (${_cardinalName(_state.minAzimuth)})",
                                      style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.85)),
                                    ),
                                  ),
                                  Expanded(
                                    child: Slider(
                                      value: _state.minAzimuth,
                                      min: 0,
                                      max: 360,
                                      divisions: 72,
                                      activeColor: accentColor,
                                      onChanged: (v) {
                                        setState(() {
                                          _state.minAzimuth = v;
                                          _state.quadrant = 0; // Switch to custom range
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),

                              // Max Azimuth Slider
                              Row(
                                children: [
                                  SizedBox(
                                    width: 115,
                                    child: Text(
                                      "Max: ${_state.maxAzimuth.round()}° (${_cardinalName(_state.maxAzimuth)})",
                                      style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.85)),
                                    ),
                                  ),
                                  Expanded(
                                    child: Slider(
                                      value: _state.maxAzimuth,
                                      min: 0,
                                      max: 360,
                                      divisions: 72,
                                      activeColor: accentColor,
                                      onChanged: (v) {
                                        setState(() {
                                          _state.maxAzimuth = v;
                                          _state.quadrant = 0; // Switch to custom range
                                        });
                                      },
                                    ),
                                  ),
                                ],
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

class AzimuthCompassDial extends StatelessWidget {
  final double minAzimuth;
  final double maxAzimuth;
  final bool isRedNightMode;

  const AzimuthCompassDial({
    super.key,
    required this.minAzimuth,
    required this.maxAzimuth,
    this.isRedNightMode = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: const Size(100, 100),
          painter: _CompassPainter(
            minAz: minAzimuth,
            maxAz: maxAzimuth,
            isRed: isRedNightMode,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _spanLabel(),
          style: TextStyle(
            fontSize: 10,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
            color: isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan,
          ),
        ),
      ],
    );
  }

  String _spanLabel() {
    final min = minAzimuth.round();
    final max = maxAzimuth.round();
    if (min == 0 && max == 360) return "All 360°";
    if (min == max) return "0° (Closed)";
    final span = (max >= min) ? (max - min) : (360 - min + max);
    return "Span: $span°";
  }
}

class _CompassPainter extends CustomPainter {
  final double minAz;
  final double maxAz;
  final bool isRed;

  _CompassPainter({
    required this.minAz,
    required this.maxAz,
    required this.isRed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    // 1. Dark circular background
    final bgPaint = Paint()
      ..color = isRed
          ? AstroColors.nightVisionBackground
          : const Color(0xFF070B12)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // 2. Outer ring border
    final ringPaint = Paint()
      ..color = isRed
          ? AstroColors.nightVisionBorder
          : AstroColors.spaceDarkBorder
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, ringPaint);

    // 3. Highlighted active wedge (Azimuth cone)
    final wedgePaint = Paint()
      ..color = (isRed ? AstroColors.nightVisionRed : AstroColors.starlightCyan).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final arcPaint = Paint()
      ..color = isRed ? AstroColors.nightVisionRed : AstroColors.starlightCyan
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final arcRect = Rect.fromCircle(center: center, radius: radius);

    // Convert degrees to radians (0 deg is North = -pi/2 in canvas)
    double degToRad(double deg) => (deg - 90) * (math.pi / 180.0);

    final startAngle = degToRad(minAz);
    double sweepAngle;
    if ((minAz - maxAz).abs() < 1e-4 || (minAz == 0 && maxAz == 360)) {
      sweepAngle = 2 * math.pi;
    } else if (maxAz >= minAz) {
      sweepAngle = (maxAz - minAz) * (math.pi / 180.0);
    } else {
      sweepAngle = (360 - minAz + maxAz) * (math.pi / 180.0);
    }

    // Draw active wedge & arc
    canvas.drawArc(arcRect, startAngle, sweepAngle, true, wedgePaint);
    canvas.drawArc(arcRect, startAngle, sweepAngle, false, arcPaint);

    // 4. Crosshairs
    final crosshairPaint = Paint()
      ..color = (isRed ? AstroColors.nightVisionBorder : Colors.white12)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), crosshairPaint);
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), crosshairPaint);

    // 5. Center dot
    canvas.drawCircle(center, 2.5, Paint()..color = (isRed ? AstroColors.nightVisionRed : Colors.white54));

    // 6. Cardinal labels (N, E, S, W)
    final textStyle = TextStyle(
      color: isRed ? AstroColors.nightVisionRed : Colors.white70,
      fontSize: 9,
      fontWeight: FontWeight.bold,
    );

    void drawCardinal(String label, Offset pos) {
      final tp = TextPainter(text: TextSpan(text: label, style: textStyle), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
    }

    drawCardinal("N", Offset(center.dx, center.dy - radius - 6));
    drawCardinal("E", Offset(center.dx + radius + 6, center.dy));
    drawCardinal("S", Offset(center.dx, center.dy + radius + 6));
    drawCardinal("W", Offset(center.dx - radius - 6, center.dy));
  }

  @override
  bool shouldRepaint(covariant _CompassPainter oldDelegate) {
    return oldDelegate.minAz != minAz || oldDelegate.maxAz != maxAz || oldDelegate.isRed != isRed;
  }
}
