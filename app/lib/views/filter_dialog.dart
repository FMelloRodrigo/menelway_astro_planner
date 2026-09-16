import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/l10n_helpers.dart';
import '../models/filter_state.dart';
import '../models/night_summary.dart';
import '../theme/astro_theme.dart';
import 'horizon_maker_dialog.dart';

class FilterDialog extends StatefulWidget {
  final FilterState initialFilters;
  final NightSummary? night;
  final bool isRedNightMode;
  final void Function(FilterState updated) onApply;

  const FilterDialog({
    super.key,
    required this.initialFilters,
    this.night,
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
    'Arp',
    'Herschel',
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
    final l10n = AppLocalizations.of(context);
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return Dialog(
      backgroundColor: widget.isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder,
        ),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 12 : 20,
        vertical: isNarrow ? 16 : 24,
      ),
      child: Container(
        width: 650,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        padding: EdgeInsets.all(isNarrow ? 16 : 24),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.tune_rounded, color: accentColor, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n?.filterDialogTitle ?? "Target Filter Parameters",
                    style: TextStyle(
                      fontSize: isNarrow ? 16 : 18,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
                    // Section 1: Observing Time Window (Telescopius Rule)
                    _buildSectionHeader("Observing Time Window", Icons.schedule_rounded),
                    const SizedBox(height: 8),

                    // Toggle: Astronomical Darkness vs Custom Time Limit
                    Container(
                      decoration: BoxDecoration(
                        color: widget.isRedNightMode
                            ? AstroColors.nightVisionSurfaceVariant
                            : AstroColors.spaceDarkSurfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: widget.isRedNightMode
                              ? AstroColors.nightVisionBorder
                              : AstroColors.spaceDarkBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                              onTap: () {
                                setState(() => _state.useCustomTimeWindow = false);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: !_state.useCustomTimeWindow
                                      ? (widget.isRedNightMode
                                          ? AstroColors.nightVisionBorder
                                          : accentColor.withValues(alpha: 0.2))
                                      : Colors.transparent,
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.nights_stay_rounded,
                                      size: 16,
                                      color: !_state.useCustomTimeWindow ? accentColor : textColor.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        isNarrow ? "Astro Darkness" : "Astronomical Darkness",
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: !_state.useCustomTimeWindow ? FontWeight.w700 : FontWeight.normal,
                                          color: !_state.useCustomTimeWindow ? textColor : textColor.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 32,
                            color: widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder,
                          ),
                          Expanded(
                            child: InkWell(
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                              onTap: () {
                                setState(() {
                                  _state.useCustomTimeWindow = true;
                                  final maxDur = _state.windowDurationHours;
                                  if (_state.minDurationHours > maxDur) {
                                    _state.minDurationHours = math.max(0.5, maxDur);
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: _state.useCustomTimeWindow
                                      ? (widget.isRedNightMode
                                          ? AstroColors.nightVisionBorder
                                          : accentColor.withValues(alpha: 0.2))
                                      : Colors.transparent,
                                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.tune_rounded,
                                      size: 16,
                                      color: _state.useCustomTimeWindow ? accentColor : textColor.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        isNarrow ? "Custom Window" : "Custom Time Limit",
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: _state.useCustomTimeWindow ? FontWeight.w700 : FontWeight.normal,
                                          color: _state.useCustomTimeWindow ? textColor : textColor.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (_state.useCustomTimeWindow) ...[
                      const SizedBox(height: 12),
                      if (isNarrow) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildTimeBox(
                                label: "START TIME",
                                hour: _state.customStartHour,
                                minute: _state.customStartMinute,
                                onTap: () => _pickTime(isStart: true),
                                textColor: textColor,
                                accentColor: accentColor,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.arrow_forward_rounded, color: accentColor, size: 18),
                            ),
                            Expanded(
                              child: _buildTimeBox(
                                label: "END TIME",
                                hour: _state.customEndHour,
                                minute: _state.customEndMinute,
                                onTap: () => _pickTime(isStart: false),
                                textColor: textColor,
                                accentColor: accentColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "WINDOW: ",
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: accentColor),
                              ),
                              Text(
                                "${_state.windowDurationHours.toStringAsFixed(1)} hrs",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildTimeBox(
                                label: "START TIME",
                                hour: _state.customStartHour,
                                minute: _state.customStartMinute,
                                onTap: () => _pickTime(isStart: true),
                                textColor: textColor,
                                accentColor: accentColor,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Icon(Icons.arrow_forward_rounded, color: accentColor, size: 20),
                            ),
                            Expanded(
                              child: _buildTimeBox(
                                label: "END TIME",
                                hour: _state.customEndHour,
                                minute: _state.customEndMinute,
                                onTap: () => _pickTime(isStart: false),
                                textColor: textColor,
                                accentColor: accentColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    "WINDOW",
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: accentColor),
                                  ),
                                  Text(
                                    "${_state.windowDurationHours.toStringAsFixed(1)} hrs",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildPresetChip(
                            "21:00 - 23:00",
                            () => _setCustomWindow(21, 0, 23, 0),
                            textColor,
                            accentColor,
                            isActive: _state.customStartHour == 21 &&
                                _state.customStartMinute == 0 &&
                                _state.customEndHour == 23 &&
                                _state.customEndMinute == 0,
                          ),
                          _buildPresetChip(
                            "21:00 - 00:00",
                            () => _setCustomWindow(21, 0, 0, 0),
                            textColor,
                            accentColor,
                            isActive: _state.customStartHour == 21 &&
                                _state.customStartMinute == 0 &&
                                _state.customEndHour == 0 &&
                                _state.customEndMinute == 0,
                          ),
                          _buildPresetChip(
                            "22:00 - 02:00",
                            () => _setCustomWindow(22, 0, 2, 0),
                            textColor,
                            accentColor,
                            isActive: _state.customStartHour == 22 &&
                                _state.customStartMinute == 0 &&
                                _state.customEndHour == 2 &&
                                _state.customEndMinute == 0,
                          ),
                          _buildPresetChip(
                            "00:00 - 04:00",
                            () => _setCustomWindow(0, 0, 4, 0),
                            textColor,
                            accentColor,
                            isActive: _state.customStartHour == 0 &&
                                _state.customStartMinute == 0 &&
                                _state.customEndHour == 4 &&
                                _state.customEndMinute == 0,
                          ),
                          if (widget.night != null) ...[
                            _buildPresetChip(
                              "Dusk - Midnight",
                              () => _setCustomWindow(
                                  widget.night!.astronomicalDusk.hour, widget.night!.astronomicalDusk.minute, 0, 0),
                              textColor,
                              accentColor,
                            ),
                            _buildPresetChip(
                              "Midnight - Dawn",
                              () => _setCustomWindow(
                                  0, 0, widget.night!.astronomicalDawn.hour, widget.night!.astronomicalDawn.minute),
                              textColor,
                              accentColor,
                            ),
                          ],
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Section 2: Altitude & Duration (Telescopius core)
                    _buildSectionHeader("Visibility & Altitude Range", Icons.terrain_rounded),
                    const SizedBox(height: 8),
                    if (isNarrow)
                      Column(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Minimum Altitude: ${_state.minAltitude.round()}°",
                                style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.9)),
                              ),
                              Slider(
                                value: _state.minAltitude,
                                min: 10,
                                max: math.min(70.0, _state.maxAltitude - 5),
                                divisions: 12,
                                activeColor: accentColor,
                                onChanged: (v) => setState(() => _state.minAltitude = v),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Maximum Altitude: ${_state.maxAltitude.round()}°${_state.maxAltitude == 90.0 ? ' (Zenith)' : ''}",
                                style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.9)),
                              ),
                              Slider(
                                value: _state.maxAltitude,
                                min: math.max(50.0, _state.minAltitude + 5),
                                max: 90,
                                divisions: 8,
                                activeColor: accentColor,
                                onChanged: (v) => setState(() => _state.maxAltitude = v),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _state.useCustomTimeWindow
                                    ? "Minimum Duration: ${_state.minDurationHours.toStringAsFixed(1)}h (max ${_state.windowDurationHours.toStringAsFixed(1)}h)"
                                    : "Minimum Duration: ${_state.minDurationHours.toStringAsFixed(1)} hrs",
                                style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.9)),
                              ),
                              Builder(builder: (context) {
                                final maxDur = _state.useCustomTimeWindow
                                    ? math.max(0.5, _state.windowDurationHours)
                                    : 8.0;
                                final clampedVal = _state.minDurationHours.clamp(0.5, maxDur);
                                return Slider(
                                  value: clampedVal,
                                  min: 0.5,
                                  max: maxDur > 0.5 ? maxDur : 0.6,
                                  divisions: maxDur > 0.5 ? math.max(1, ((maxDur - 0.5) * 2).round()) : 1,
                                  activeColor: accentColor,
                                  onChanged: (v) => setState(() => _state.minDurationHours = v),
                                );
                              }),
                            ],
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Min Altitude: ${_state.minAltitude.round()}°",
                                  style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.9)),
                                ),
                                Slider(
                                  value: _state.minAltitude,
                                  min: 10,
                                  max: math.min(70.0, _state.maxAltitude - 5),
                                  divisions: 12,
                                  activeColor: accentColor,
                                  onChanged: (v) => setState(() => _state.minAltitude = v),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Max Altitude: ${_state.maxAltitude.round()}°${_state.maxAltitude == 90.0 ? ' (Zenith)' : ''}",
                                  style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.9)),
                                ),
                                Slider(
                                  value: _state.maxAltitude,
                                  min: math.max(50.0, _state.minAltitude + 5),
                                  max: 90,
                                  divisions: 8,
                                  activeColor: accentColor,
                                  onChanged: (v) => setState(() => _state.maxAltitude = v),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _state.useCustomTimeWindow
                                      ? "Duration: ${_state.minDurationHours.toStringAsFixed(1)}h (max ${_state.windowDurationHours.toStringAsFixed(1)}h)"
                                      : "Duration: ${_state.minDurationHours.toStringAsFixed(1)} hrs",
                                  style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.9)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Builder(builder: (context) {
                                  final maxDur = _state.useCustomTimeWindow
                                      ? math.max(0.5, _state.windowDurationHours)
                                      : 8.0;
                                  final clampedVal = _state.minDurationHours.clamp(0.5, maxDur);
                                  return Slider(
                                    value: clampedVal,
                                    min: 0.5,
                                    max: maxDur > 0.5 ? maxDur : 0.6,
                                    divisions: maxDur > 0.5 ? math.max(1, ((maxDur - 0.5) * 2).round()) : 1,
                                    activeColor: accentColor,
                                    onChanged: (v) => setState(() => _state.minDurationHours = v),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 16),

                    // Section 2: Direction / Quadrant & Azimuth
                    _buildSectionHeader("Direction & Azimuth Range", Icons.explore_rounded),
                    const SizedBox(height: 8),

                    if (isNarrow)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: AzimuthCompassDial(
                              minAzimuth: _state.minAzimuth,
                              maxAzimuth: _state.maxAzimuth,
                              isRedNightMode: widget.isRedNightMode,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            key: ValueKey(_getPresetIndex()),
                            initialValue: _getPresetIndex(),
                            isExpanded: true,
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
                                  overflow: TextOverflow.ellipsis,
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
                          Row(
                            children: [
                              SizedBox(
                                width: 110,
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
                                      _state.quadrant = 0;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              SizedBox(
                                width: 110,
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
                                      _state.quadrant = 0;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    else
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
                                  isExpanded: true,
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
                                        overflow: TextOverflow.ellipsis,
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

                    // Section 2b: Custom Horizon Obstruction Mask (Horizon Maker)
                    _buildSectionHeader("Custom Horizon Obstruction Mask", Icons.terrain_rounded),
                    const SizedBox(height: 8),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widget.isRedNightMode
                            ? AstroColors.nightVisionSurfaceVariant
                            : AstroColors.spaceDarkSurfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _state.useCustomHorizon
                              ? (widget.isRedNightMode
                                  ? AstroColors.nightVisionRed
                                  : AstroColors.starlightCyan)
                              : (widget.isRedNightMode
                                  ? AstroColors.nightVisionBorder
                                  : AstroColors.spaceDarkBorder),
                          width: _state.useCustomHorizon ? 1.4 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.landscape_rounded,
                                size: 20,
                                color: _state.useCustomHorizon ? accentColor : textColor.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Custom Horizon Profile",
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    Text(
                                      _state.horizonPoints.isEmpty
                                          ? "No obstacle points defined yet (flat horizon)"
                                          : "${_state.horizonPoints.length} obstacle points configured across 360°",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: textColor.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _state.useCustomHorizon,
                                activeThumbColor: accentColor,
                                onChanged: (val) {
                                  setState(() => _state.useCustomHorizon = val);
                                },
                              ),
                            ],
                          ),
                          if (_state.horizonPoints.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            // Mini Preview Canvas
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                height: 38,
                                width: double.infinity,
                                color: widget.isRedNightMode ? Colors.black : const Color(0xFF090D14),
                                child: CustomPaint(
                                  painter: _MiniHorizonPreviewPainter(
                                    points: _state.horizonPoints,
                                    isRedNightMode: widget.isRedNightMode,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    side: BorderSide(color: accentColor.withValues(alpha: 0.5)),
                                  ),
                                  icon: Icon(Icons.draw_rounded, size: 16, color: accentColor),
                                  label: Text(
                                    _state.horizonPoints.isEmpty ? "Create Horizon Profile..." : "Open Horizon Maker...",
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                                  ),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => HorizonMakerDialog(
                                        initialFilters: _state,
                                        isRedNightMode: widget.isRedNightMode,
                                        onApply: (updated) {
                                          setState(() {
                                            _state = updated;
                                          });
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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
                          label: Text(localizeObjectType(type, l10n)),
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
                    if (isNarrow)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                "Faintest Limit (Max Mag): ${_state.maxMagnitude.toStringAsFixed(1)}",
                                style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.8)),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "(lower = brighter)",
                                style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.5)),
                              ),
                            ],
                          ),
                          Slider(
                            value: _state.maxMagnitude,
                            min: 5.0,
                            max: 18.0,
                            divisions: 26,
                            activeColor: accentColor,
                            onChanged: (v) => setState(() => _state.maxMagnitude = v),
                          ),
                          const SizedBox(height: 8),
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
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      "Faintest Limit (Max Mag): ${_state.maxMagnitude.toStringAsFixed(1)}",
                                      style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.8)),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "(lower = brighter)",
                                      style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.5)),
                                    ),
                                  ],
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
            isNarrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              child: Text(l10n?.cleanDataCancel ?? "Cancel"),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.check_rounded, size: 16),
                              label: Text(l10n?.applyFilters ?? "Apply Filters"),
                              style: FilledButton.styleFrom(backgroundColor: accentColor),
                              onPressed: () {
                                widget.onApply(_state);
                                Navigator.of(context).pop();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: TextButton.icon(
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: Text(l10n?.resetAllFilters ?? "Reset Filters"),
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
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(l10n?.resetAllFilters ?? "Reset Filters"),
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
                            child: Text(l10n?.cleanDataCancel ?? "Cancel"),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: Text(l10n?.applyFilters ?? "Apply Filters"),
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
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initialHour = isStart ? _state.customStartHour : _state.customEndHour;
    final initialMinute = isStart ? _state.customStartMinute : _state.customEndMinute;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
      builder: (context, child) {
        final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: accentColor,
              surface: widget.isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface,
              onSurface: widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white,
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _state.customStartHour = picked.hour;
          _state.customStartMinute = picked.minute;
        } else {
          _state.customEndHour = picked.hour;
          _state.customEndMinute = picked.minute;
        }
        final maxDur = _state.windowDurationHours;
        if (_state.minDurationHours > maxDur) {
          _state.minDurationHours = math.max(0.5, maxDur);
        }
      });
    }
  }

  void _setCustomWindow(int startH, int startM, int endH, int endM) {
    setState(() {
      _state.useCustomTimeWindow = true;
      _state.customStartHour = startH;
      _state.customStartMinute = startM;
      _state.customEndHour = endH;
      _state.customEndMinute = endM;

      final maxDur = _state.windowDurationHours;
      if (_state.minDurationHours > maxDur) {
        _state.minDurationHours = math.max(0.5, maxDur);
      }
    });
  }

  Widget _buildTimeBox({
    required String label,
    required int hour,
    required int minute,
    required VoidCallback onTap,
    required Color textColor,
    required Color accentColor,
  }) {
    final formatted = "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}h";
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: widget.isRedNightMode
              ? AstroColors.nightVisionSurfaceVariant
              : AstroColors.spaceDarkSurfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.isRedNightMode
                ? AstroColors.nightVisionBorder
                : AstroColors.spaceDarkBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.access_time_rounded, size: 16, color: accentColor),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 9, color: textColor.withValues(alpha: 0.6)),
                ),
                Text(
                  formatted,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded, size: 18, color: textColor.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(
    String label,
    VoidCallback onSelected,
    Color textColor,
    Color accentColor, {
    bool isActive = false,
  }) {
    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
          color: isActive ? accentColor : textColor.withValues(alpha: 0.8),
        ),
      ),
      backgroundColor: isActive
          ? (widget.isRedNightMode ? AstroColors.nightVisionBorder : accentColor.withValues(alpha: 0.15))
          : (widget.isRedNightMode ? AstroColors.nightVisionSurfaceVariant : AstroColors.spaceDarkSurfaceVariant),
      side: BorderSide(
        color: isActive
            ? accentColor
            : (widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onPressed: onSelected,
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

class _MiniHorizonPreviewPainter extends CustomPainter {
  final List<HorizonPointModel> points;
  final bool isRedNightMode;

  _MiniHorizonPreviewPainter({required this.points, required this.isRedNightMode});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final path = Path();
    final fillPath = Path();

    double azToX(double az) => (az / 360.0) * size.width;
    double altToY(double alt) => size.height - (alt / 90.0) * size.height;

    final firstY = altToY(points.first.altitude);

    path.moveTo(0, firstY);
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, firstY);

    for (final p in points) {
      final x = azToX(p.azimuth);
      final y = altToY(p.altitude);
      path.lineTo(x, y);
      fillPath.lineTo(x, y);
    }

    final lastY = altToY(points.last.altitude);
    path.lineTo(size.width, lastY);
    fillPath.lineTo(size.width, lastY);
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..color = (isRedNightMode ? AstroColors.nightVisionRed : Colors.redAccent).withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = isRedNightMode ? AstroColors.nightVisionRed : Colors.redAccent
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _MiniHorizonPreviewPainter oldDelegate) => true;
}

