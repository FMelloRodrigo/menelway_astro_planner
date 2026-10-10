import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../controllers/filter_dialog_controller.dart';
import '../../l10n/app_localizations.dart';

class AltitudeDurationSection extends StatelessWidget {
  final FilterDialogController controller;
  final bool isNarrow;
  final AppLocalizations l10n;
  final Color textColor;
  final Color accentColor;

  const AltitudeDurationSection({
    super.key,
    required this.controller,
    required this.isNarrow,
    required this.l10n,
    required this.textColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final state = controller.state;

    const double minAltMin = 10.0;
    final double minAltMax = math.max(
      minAltMin + 5.0,
      math.min(
        70.0,
        ((state.maxAltitude - 5.0) / 5.0).floorToDouble() * 5.0,
      ),
    );
    final int minAltDivisions =
        math.max(1, ((minAltMax - minAltMin) / 5.0).round());
    final double minAltVal = ((state.minAltitude / 5.0).round() * 5.0)
        .toDouble()
        .clamp(minAltMin, minAltMax);

    const double maxAltMax = 90.0;
    final double maxAltMin = math.min(
      maxAltMax - 5.0,
      math.max(
        50.0,
        ((state.minAltitude + 5.0) / 5.0).ceilToDouble() * 5.0,
      ),
    );
    final int maxAltDivisions =
        math.max(1, ((maxAltMax - maxAltMin) / 5.0).round());
    final double maxAltVal = ((state.maxAltitude / 5.0).round() * 5.0)
        .toDouble()
        .clamp(maxAltMin, maxAltMax);

    final maxDur = state.useCustomTimeWindow
        ? math.max(0.5, state.windowDurationHours)
        : 8.0;
    final clampedDur = math.min(state.minDurationHours, maxDur);
    final durDivisions = math.max(1, ((maxDur - 0.5) / 0.5).round());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Icon(Icons.terrain_rounded, size: 16, color: accentColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.visibilityAltitudeRange,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: accentColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (isNarrow)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.minAltitudeLabel(minAltVal.round().toString()),
                style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.9)),
              ),
              Slider(
                value: minAltVal,
                min: minAltMin,
                max: minAltMax,
                divisions: minAltDivisions,
                activeColor: accentColor,
                onChanged: (v) => controller.setMinAltitude(v),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.maxAltitudeLabel(maxAltVal.round().toString()),
                style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.9)),
              ),
              Slider(
                value: maxAltVal,
                min: maxAltMin,
                max: maxAltMax,
                divisions: maxAltDivisions,
                activeColor: accentColor,
                onChanged: (v) => controller.setMaxAltitude(v),
              ),
              const SizedBox(height: 4),
              Text(
                state.useCustomTimeWindow
                    ? "${l10n.durationLabel(clampedDur.toStringAsFixed(1))} (max ${state.windowDurationHours.toStringAsFixed(1)}h)"
                    : l10n.durationLabel(clampedDur.toStringAsFixed(1)),
                style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.9)),
              ),
              Slider(
                value: clampedDur,
                min: 0.5,
                max: maxDur > 0.5 ? maxDur : 0.6,
                divisions: durDivisions,
                activeColor: accentColor,
                onChanged: (v) => controller.setMinDurationHours(v),
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
                      l10n.minAltitudeLabel(minAltVal.round().toString()),
                      style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.9)),
                    ),
                    Slider(
                      value: minAltVal,
                      min: minAltMin,
                      max: minAltMax,
                      divisions: minAltDivisions,
                      activeColor: accentColor,
                      onChanged: (v) => controller.setMinAltitude(v),
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
                      l10n.maxAltitudeLabel(maxAltVal.round().toString()),
                      style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.9)),
                    ),
                    Slider(
                      value: maxAltVal,
                      min: maxAltMin,
                      max: maxAltMax,
                      divisions: maxAltDivisions,
                      activeColor: accentColor,
                      onChanged: (v) => controller.setMaxAltitude(v),
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
                      state.useCustomTimeWindow
                          ? "${l10n.durationLabel(clampedDur.toStringAsFixed(1))} (max ${state.windowDurationHours.toStringAsFixed(1)}h)"
                          : l10n.durationLabel(clampedDur.toStringAsFixed(1)),
                      style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.9)),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Slider(
                      value: clampedDur,
                      min: 0.5,
                      max: maxDur > 0.5 ? maxDur : 0.6,
                      divisions: durDivisions,
                      activeColor: accentColor,
                      onChanged: (v) => controller.setMinDurationHours(v),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}
