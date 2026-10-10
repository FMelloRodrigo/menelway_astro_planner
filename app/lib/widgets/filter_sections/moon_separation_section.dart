import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../controllers/filter_dialog_controller.dart';
import '../../l10n/app_localizations.dart';

class MoonSeparationSection extends StatelessWidget {
  final FilterDialogController controller;
  final AppLocalizations l10n;
  final Color textColor;
  final Color accentColor;

  const MoonSeparationSection({
    super.key,
    required this.controller,
    required this.l10n,
    required this.textColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final divisions = math.max(1, ((90.0 - 0.0) / 5.0).round());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.brightness_3_rounded, size: 16, color: accentColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.moonDistance,
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
        Text(
          l10n.minMoonDistanceLabel(state.minMoonSeparation.round().toString()),
          style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.9)),
        ),
        Slider(
          value: state.minMoonSeparation,
          min: 0,
          max: 90,
          divisions: divisions,
          activeColor: accentColor,
          onChanged: (v) => controller.setMinMoonSeparation(v),
        ),
      ],
    );
  }
}
