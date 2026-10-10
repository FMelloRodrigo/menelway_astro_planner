import 'package:flutter/material.dart';

import '../../controllers/filter_dialog_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../models/filter_state.dart';
import '../../theme/astro_theme.dart';
import '../../views/horizon_maker_dialog.dart';
import '../painters/mini_horizon_preview_painter.dart';

class CustomHorizonSection extends StatelessWidget {
  final FilterDialogController controller;
  final bool isRedNightMode;
  final AppLocalizations l10n;
  final Color textColor;
  final Color accentColor;
  final void Function(FilterState updated) onApply;

  const CustomHorizonSection({
    super.key,
    required this.controller,
    required this.isRedNightMode,
    required this.l10n,
    required this.textColor,
    required this.accentColor,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final state = controller.state;

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
                l10n.customHorizonMask,
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

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isRedNightMode
                ? AstroColors.nightVisionSurfaceVariant
                : AstroColors.spaceDarkSurfaceVariant,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: state.useCustomHorizon
                  ? (isRedNightMode
                      ? AstroColors.nightVisionRed
                      : AstroColors.starlightCyan)
                  : (isRedNightMode
                      ? AstroColors.nightVisionBorder
                      : AstroColors.spaceDarkBorder),
              width: state.useCustomHorizon ? 1.4 : 1.0,
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
                    color: state.useCustomHorizon ? accentColor : textColor.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.customHorizonProfile,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Text(
                          state.horizonPoints.isEmpty
                              ? l10n.noObstaclePoints
                              : l10n.obstaclePointsCount(state.horizonPoints.length),
                          style: TextStyle(
                            fontSize: 11,
                            color: textColor.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: state.useCustomHorizon,
                    activeThumbColor: accentColor,
                    onChanged: (val) => controller.setUseCustomHorizon(val),
                  ),
                ],
              ),
              if (state.horizonPoints.isNotEmpty) ...[
                const SizedBox(height: 10),
                // Mini Preview Canvas
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 38,
                    width: double.infinity,
                    color: isRedNightMode ? Colors.black : const Color(0xFF090D14),
                    child: CustomPaint(
                      painter: MiniHorizonPreviewPainter(
                        points: state.horizonPoints,
                        isRedNightMode: isRedNightMode,
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
                        state.horizonPoints.isEmpty ? l10n.createHorizonProfile : l10n.openHorizonMaker,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => HorizonMakerDialog(
                            initialFilters: state,
                            isRedNightMode: isRedNightMode,
                            onApply: (updated) {
                              controller.updateFilterState(updated);
                              onApply(updated);
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
      ],
    );
  }
}
