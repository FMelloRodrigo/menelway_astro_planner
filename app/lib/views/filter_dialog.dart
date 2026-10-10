import 'package:flutter/material.dart';

import '../controllers/filter_dialog_controller.dart';
import '../l10n/app_localizations.dart';
import '../models/filter_state.dart';
import '../models/night_summary.dart';
import '../theme/astro_theme.dart';
import '../widgets/filter_sections/altitude_duration_section.dart';
import '../widgets/filter_sections/catalogs_and_types_section.dart';
import '../widgets/filter_sections/custom_horizon_section.dart';
import '../widgets/filter_sections/direction_azimuth_section.dart';
import '../widgets/filter_sections/magnitude_size_section.dart';
import '../widgets/filter_sections/moon_separation_section.dart';
import '../widgets/filter_sections/time_window_section.dart';

export '../widgets/azimuth_compass_dial.dart';

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
  late final FilterDialogController _controller;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller = FilterDialogController(initialFilters: widget.initialFilters);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
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
            width: isNarrow ? null : 750,
            constraints: BoxConstraints(
              maxWidth: 750,
              maxHeight: MediaQuery.of(context).size.height * 0.90,
            ),
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
                        l10n.filterDialogTitle,
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
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(right: 16, bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TimeWindowSection(
                            controller: _controller,
                            night: widget.night,
                            isRedNightMode: widget.isRedNightMode,
                            isNarrow: isNarrow,
                            l10n: l10n,
                            textColor: textColor,
                            accentColor: accentColor,
                          ),
                          const SizedBox(height: 16),
                          AltitudeDurationSection(
                            controller: _controller,
                            isNarrow: isNarrow,
                            l10n: l10n,
                            textColor: textColor,
                            accentColor: accentColor,
                          ),
                          const SizedBox(height: 16),
                          DirectionAzimuthSection(
                            controller: _controller,
                            isRedNightMode: widget.isRedNightMode,
                            isNarrow: isNarrow,
                            l10n: l10n,
                            textColor: textColor,
                            accentColor: accentColor,
                          ),
                          const SizedBox(height: 16),
                          CustomHorizonSection(
                            controller: _controller,
                            isRedNightMode: widget.isRedNightMode,
                            l10n: l10n,
                            textColor: textColor,
                            accentColor: accentColor,
                            onApply: (updated) {
                              widget.onApply(updated);
                            },
                          ),
                          const SizedBox(height: 16),
                          MoonSeparationSection(
                            controller: _controller,
                            l10n: l10n,
                            textColor: textColor,
                            accentColor: accentColor,
                          ),
                          const SizedBox(height: 16),
                          CatalogsAndTypesSection(
                            controller: _controller,
                            l10n: l10n,
                            accentColor: accentColor,
                          ),
                          const SizedBox(height: 16),
                          MagnitudeSizeSection(
                            controller: _controller,
                            isNarrow: isNarrow,
                            l10n: l10n,
                            textColor: textColor,
                            accentColor: accentColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 16),

                // Footer Actions
                isNarrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  child: Text(l10n.cleanDataCancel),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton.icon(
                                  icon: const Icon(Icons.check_rounded, size: 16),
                                  label: Text(l10n.applyFilters),
                                  style: FilledButton.styleFrom(backgroundColor: accentColor),
                                  onPressed: () {
                                    widget.onApply(_controller.state);
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
                              label: Text(l10n.resetAllFilters),
                              style: TextButton.styleFrom(foregroundColor: textColor.withValues(alpha: 0.6)),
                              onPressed: () => _controller.resetToDefaults(),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: Text(l10n.resetAllFilters),
                            style: TextButton.styleFrom(foregroundColor: textColor.withValues(alpha: 0.6)),
                            onPressed: () => _controller.resetToDefaults(),
                          ),
                          Row(
                            children: [
                              OutlinedButton(
                                child: Text(l10n.cleanDataCancel),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                icon: const Icon(Icons.check_rounded, size: 16),
                                label: Text(l10n.applyFilters),
                                style: FilledButton.styleFrom(backgroundColor: accentColor),
                                onPressed: () {
                                  widget.onApply(_controller.state);
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
      },
    );
  }
}
