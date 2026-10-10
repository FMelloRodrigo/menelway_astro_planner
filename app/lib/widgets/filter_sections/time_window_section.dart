import 'package:flutter/material.dart';

import '../../controllers/filter_dialog_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../models/night_summary.dart';
import '../../theme/astro_theme.dart';

class TimeWindowSection extends StatelessWidget {
  final FilterDialogController controller;
  final NightSummary? night;
  final bool isRedNightMode;
  final bool isNarrow;
  final AppLocalizations l10n;
  final Color textColor;
  final Color accentColor;

  const TimeWindowSection({
    super.key,
    required this.controller,
    required this.night,
    required this.isRedNightMode,
    required this.isNarrow,
    required this.l10n,
    required this.textColor,
    required this.accentColor,
  });

  Future<void> _pickTime(BuildContext context, {required bool isStart}) async {
    final state = controller.state;
    final initialHour = isStart ? state.customStartHour : state.customEndHour;
    final initialMinute = isStart ? state.customStartMinute : state.customEndMinute;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: accentColor,
              surface: isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface,
              onSurface: isRedNightMode ? AstroColors.nightVisionRed : Colors.white,
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
      controller.setCustomTime(isStart: isStart, hour: picked.hour, minute: picked.minute);
    }
  }

  Widget _buildTimeBox({
    required String label,
    required int hour,
    required int minute,
    required VoidCallback onTap,
  }) {
    final formatted = "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}h";
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isRedNightMode
              ? AstroColors.nightVisionSurfaceVariant
              : AstroColors.spaceDarkSurfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isRedNightMode
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
    VoidCallback onSelected, {
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
          ? (isRedNightMode ? AstroColors.nightVisionBorder : accentColor.withValues(alpha: 0.15))
          : (isRedNightMode ? AstroColors.nightVisionSurfaceVariant : AstroColors.spaceDarkSurfaceVariant),
      side: BorderSide(
        color: isActive
            ? accentColor
            : (isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onPressed: onSelected,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Icon(Icons.schedule_rounded, size: 16, color: accentColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l10n.observingTimeWindow,
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

        // Toggle: Astronomical Darkness vs Custom Time Limit
        Container(
          decoration: BoxDecoration(
            color: isRedNightMode
                ? AstroColors.nightVisionSurfaceVariant
                : AstroColors.spaceDarkSurfaceVariant,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isRedNightMode
                  ? AstroColors.nightVisionBorder
                  : AstroColors.spaceDarkBorder,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(9)),
                  onTap: () => controller.setUseCustomTimeWindow(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    decoration: BoxDecoration(
                      color: !state.useCustomTimeWindow
                          ? (isRedNightMode
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
                          color: !state.useCustomTimeWindow ? accentColor : textColor.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            isNarrow ? l10n.astroDarknessShort : l10n.astronomicalDarkness,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: !state.useCustomTimeWindow ? FontWeight.w700 : FontWeight.normal,
                              color: !state.useCustomTimeWindow ? textColor : textColor.withValues(alpha: 0.6),
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
                color: isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder,
              ),
              Expanded(
                child: InkWell(
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(9)),
                  onTap: () => controller.setUseCustomTimeWindow(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    decoration: BoxDecoration(
                      color: state.useCustomTimeWindow
                          ? (isRedNightMode
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
                          color: state.useCustomTimeWindow ? accentColor : textColor.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            isNarrow ? l10n.customWindowShort : l10n.customTimeLimit,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: state.useCustomTimeWindow ? FontWeight.w700 : FontWeight.normal,
                              color: state.useCustomTimeWindow ? textColor : textColor.withValues(alpha: 0.6),
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

        if (state.useCustomTimeWindow) ...[
          const SizedBox(height: 12),
          if (isNarrow) ...[
            Row(
              children: [
                Expanded(
                  child: _buildTimeBox(
                    label: l10n.startTime,
                    hour: state.customStartHour,
                    minute: state.customStartMinute,
                    onTap: () => _pickTime(context, isStart: true),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward_rounded, color: accentColor, size: 16),
                ),
                Expanded(
                  child: _buildTimeBox(
                    label: l10n.endTime,
                    hour: state.customEndHour,
                    minute: state.customEndMinute,
                    onTap: () => _pickTime(context, isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timelapse_rounded, size: 14, color: accentColor),
                  const SizedBox(width: 6),
                  Text(
                    "${l10n.window}: ${state.windowDurationHours.toStringAsFixed(1)} ${l10n.hoursShort}",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accentColor),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _buildTimeBox(
                    label: l10n.startTime,
                    hour: state.customStartHour,
                    minute: state.customStartMinute,
                    onTap: () => _pickTime(context, isStart: true),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.arrow_forward_rounded, color: accentColor, size: 20),
                ),
                Expanded(
                  child: _buildTimeBox(
                    label: l10n.endTime,
                    hour: state.customEndHour,
                    minute: state.customEndMinute,
                    onTap: () => _pickTime(context, isStart: false),
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
                        l10n.window,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: accentColor),
                      ),
                      Text(
                        "${state.windowDurationHours.toStringAsFixed(1)} ${l10n.hoursShort}",
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
                () => controller.setCustomWindow(21, 0, 23, 0),
                isActive: state.customStartHour == 21 &&
                    state.customStartMinute == 0 &&
                    state.customEndHour == 23 &&
                    state.customEndMinute == 0,
              ),
              _buildPresetChip(
                "21:00 - 00:00",
                () => controller.setCustomWindow(21, 0, 0, 0),
                isActive: state.customStartHour == 21 &&
                    state.customStartMinute == 0 &&
                    state.customEndHour == 0 &&
                    state.customEndMinute == 0,
              ),
              _buildPresetChip(
                "22:00 - 02:00",
                () => controller.setCustomWindow(22, 0, 2, 0),
                isActive: state.customStartHour == 22 &&
                    state.customStartMinute == 0 &&
                    state.customEndHour == 2 &&
                    state.customEndMinute == 0,
              ),
              _buildPresetChip(
                "00:00 - 04:00",
                () => controller.setCustomWindow(0, 0, 4, 0),
                isActive: state.customStartHour == 0 &&
                    state.customStartMinute == 0 &&
                    state.customEndHour == 4 &&
                    state.customEndMinute == 0,
              ),
              if (night != null) ...[
                _buildPresetChip(
                  l10n.duskMidnight,
                  () => controller.setCustomWindow(
                    night!.astronomicalDusk.hour,
                    night!.astronomicalDusk.minute,
                    0,
                    0,
                  ),
                ),
                _buildPresetChip(
                  l10n.midnightDawn,
                  () => controller.setCustomWindow(
                    0,
                    0,
                    night!.astronomicalDawn.hour,
                    night!.astronomicalDawn.minute,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
