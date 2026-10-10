import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../controllers/filter_dialog_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_helpers.dart';
import '../../theme/astro_theme.dart';
import '../azimuth_compass_dial.dart';

class DirectionAzimuthSection extends StatelessWidget {
  final FilterDialogController controller;
  final bool isRedNightMode;
  final bool isNarrow;
  final AppLocalizations l10n;
  final Color textColor;
  final Color accentColor;

  const DirectionAzimuthSection({
    super.key,
    required this.controller,
    required this.isRedNightMode,
    required this.isNarrow,
    required this.l10n,
    required this.textColor,
    required this.accentColor,
  });

  String _cardinalName(double az) {
    final isPt = l10n.localeName.startsWith('pt');
    return FilterDialogController.cardinalName(az, isPt: isPt);
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final quadrantOptions = getQuadrantOptions(l10n);
    final azDivisions = math.max(1, ((360.0 - 0.0) / 5.0).round());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Icon(Icons.explore_rounded, size: 16, color: accentColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.directionAzimuthRange,
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: AzimuthCompassDial(
                  minAzimuth: state.minAzimuth,
                  maxAzimuth: state.maxAzimuth,
                  isRedNightMode: isRedNightMode,
                  l10n: l10n,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: ValueKey(controller.presetIndex),
                initialValue: controller.presetIndex,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.directionPresetMode,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                dropdownColor: isRedNightMode
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
                    controller.applyPreset(v);
                  }
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      l10n.minAzimuthLabel(state.minAzimuth.round().toString(), _cardinalName(state.minAzimuth)),
                      style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.85)),
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: state.minAzimuth,
                      min: 0,
                      max: 360,
                      divisions: azDivisions,
                      activeColor: accentColor,
                      onChanged: (v) => controller.setMinAzimuth(v),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      l10n.maxAzimuthLabel(state.maxAzimuth.round().toString(), _cardinalName(state.maxAzimuth)),
                      style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.85)),
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: state.maxAzimuth,
                      min: 0,
                      max: 360,
                      divisions: azDivisions,
                      activeColor: accentColor,
                      onChanged: (v) => controller.setMaxAzimuth(v),
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
                minAzimuth: state.minAzimuth,
                maxAzimuth: state.maxAzimuth,
                isRedNightMode: isRedNightMode,
                l10n: l10n,
              ),
              const SizedBox(width: 16),

              // Preset Dropdown & Sliders
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<int>(
                      key: ValueKey(controller.presetIndex),
                      initialValue: controller.presetIndex,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.directionPresetMode,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      dropdownColor: isRedNightMode
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
                          controller.applyPreset(v);
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
                            l10n.minAzimuthLabel(state.minAzimuth.round().toString(), _cardinalName(state.minAzimuth)),
                            style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.85)),
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: state.minAzimuth,
                            min: 0,
                            max: 360,
                            divisions: azDivisions,
                            activeColor: accentColor,
                            onChanged: (v) => controller.setMinAzimuth(v),
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
                            l10n.maxAzimuthLabel(state.maxAzimuth.round().toString(), _cardinalName(state.maxAzimuth)),
                            style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.85)),
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: state.maxAzimuth,
                            min: 0,
                            max: 360,
                            divisions: azDivisions,
                            activeColor: accentColor,
                            onChanged: (v) => controller.setMaxAzimuth(v),
                          ),
                        ),
                      ],
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
