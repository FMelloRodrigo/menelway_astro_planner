import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../controllers/filter_dialog_controller.dart';
import '../../l10n/app_localizations.dart';

class MagnitudeSizeSection extends StatelessWidget {
  final FilterDialogController controller;
  final bool isNarrow;
  final AppLocalizations l10n;
  final Color textColor;
  final Color accentColor;

  const MagnitudeSizeSection({
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
    final magDivisions = math.max(1, ((18.0 - 5.0) / 0.5).round());
    final sizeDivisions = math.max(1, ((60.0 - 0.0) / 5.0).round());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Icon(Icons.straighten_rounded, size: 16, color: accentColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.magnitudeApparentSize,
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
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    l10n.faintestLimitLabel(state.maxMagnitude.toStringAsFixed(1)),
                    style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.lowerBrighter,
                    style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.5)),
                  ),
                ],
              ),
              Slider(
                value: state.maxMagnitude,
                min: 5.0,
                max: 18.0,
                divisions: magDivisions,
                activeColor: accentColor,
                onChanged: (v) => controller.setMaxMagnitude(v),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.minSizeLabelAlt(state.minSizeArcmin.round().toString()),
                style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.8)),
              ),
              Slider(
                value: state.minSizeArcmin,
                min: 0,
                max: 60,
                divisions: sizeDivisions,
                activeColor: accentColor,
                onChanged: (v) => controller.setMinSizeArcmin(v),
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
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          l10n.faintestLimitLabel(state.maxMagnitude.toStringAsFixed(1)),
                          style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.8)),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.lowerBrighter,
                          style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.5)),
                        ),
                      ],
                    ),
                    Slider(
                      value: state.maxMagnitude,
                      min: 5.0,
                      max: 18.0,
                      divisions: magDivisions,
                      activeColor: accentColor,
                      onChanged: (v) => controller.setMaxMagnitude(v),
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
                      l10n.minSizeLabelAlt(state.minSizeArcmin.round().toString()),
                      style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.8)),
                    ),
                    Slider(
                      value: state.minSizeArcmin,
                      min: 0,
                      max: 60,
                      divisions: sizeDivisions,
                      activeColor: accentColor,
                      onChanged: (v) => controller.setMinSizeArcmin(v),
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
