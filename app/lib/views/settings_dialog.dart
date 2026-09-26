import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/astro_theme.dart';
import 'about_dialog.dart';

/// A dedicated Settings & Data window dialog that houses target filter
/// resets, storage maintenance, and provides an extensible foundation for future settings.
class SettingsDialog extends StatefulWidget {
  final bool isRedNightMode;
  final VoidCallback onResetFilters;
  final VoidCallback onCleanAllData;
  final VoidCallback? onReplayTour;
  final int maxTargets;
  final ValueChanged<int>? onMaxTargetsChanged;

  const SettingsDialog({
    super.key,
    required this.isRedNightMode,
    required this.onResetFilters,
    required this.onCleanAllData,
    this.onReplayTour,
    this.maxTargets = 20,
    this.onMaxTargetsChanged,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late int _selectedMaxTargets;

  @override
  void initState() {
    super.initState();
    _selectedMaxTargets = widget.maxTargets;
  }

  @override
  void didUpdateWidget(covariant SettingsDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.maxTargets != widget.maxTargets) {
      _selectedMaxTargets = widget.maxTargets;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isNarrow = MediaQuery.of(context).size.width < 600;
    final isRedNightMode = widget.isRedNightMode;

    final bgColor = isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface;
    final cardBgColor = isRedNightMode
        ? AstroColors.nightVisionSurfaceVariant
        : AstroColors.spaceDarkSurfaceVariant;
    final borderColor = isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder;
    final textColor = isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final textSubColor = isRedNightMode
        ? AstroColors.nightVisionRed.withValues(alpha: 0.75)
        : Colors.white.withValues(alpha: 0.75);
    final accentColor = isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1.2),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 12 : 24,
        vertical: isNarrow ? 16 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: EdgeInsets.all(isNarrow ? 16 : 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Window Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: accentColor.withValues(alpha: 0.35)),
                    ),
                    child: Icon(
                      Icons.settings_suggest_rounded,
                      size: 20,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n?.settingsDialogTitle ?? "Settings & Data",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n?.settingsDialogSubtitle ??
                              "Manage filter presets and application data storage.",
                          style: TextStyle(
                            fontSize: 12,
                            color: textSubColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n?.closeBtn ?? "Close",
                    icon: Icon(Icons.close_rounded, size: 20, color: textColor.withValues(alpha: 0.8)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: borderColor),
              const SizedBox(height: 16),

              // Content Area (Scrollable to prevent any screen overflows)
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Target Filters Settings
                      _buildSectionCard(
                        context: context,
                        cardBgColor: cardBgColor,
                        borderColor: borderColor,
                        textColor: textColor,
                        textSubColor: textSubColor,
                        icon: Icons.tune_rounded,
                        iconColor: accentColor,
                        title: l10n?.settingsSectionFilters ?? "Target Filters",
                        description: l10n?.resetFiltersDesc ??
                            "Clear filter limits & keep observer location",
                        actionWidget: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: accentColor,
                            side: BorderSide(color: accentColor.withValues(alpha: 0.6)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.restore_rounded, size: 16),
                          label: Text(
                            l10n?.resetFilters ?? "Reset Target Filters",
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedMaxTargets = 20;
                            });
                            widget.onResetFilters();
                          },
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Section: Maximum Targets Displayed
                      _buildSectionCard(
                        context: context,
                        cardBgColor: cardBgColor,
                        borderColor: borderColor,
                        textColor: textColor,
                        textSubColor: textSubColor,
                        icon: Icons.filter_list_rounded,
                        iconColor: accentColor,
                        title: l10n?.settingsSectionTargetLimits ?? "Target Display Limits",
                        description: l10n?.maxTargetsDesc ??
                            "Controls the maximum number of visible targets calculated and shown in Targets and Planner (Default: 20).",
                        actionWidget: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [10, 20, 50, 100, 200].map((count) {
                            final isSelected = _selectedMaxTargets == count;
                            return ChoiceChip(
                              label: Text(count == 20 ? "$count (Default)" : "$count"),
                              selected: isSelected,
                              onSelected: widget.onMaxTargetsChanged != null
                                  ? (selected) {
                                      if (selected) {
                                        setState(() {
                                          _selectedMaxTargets = count;
                                        });
                                        widget.onMaxTargetsChanged!(count);
                                      }
                                    }
                                  : null,
                              selectedColor: accentColor.withValues(alpha: 0.22),
                              backgroundColor: isRedNightMode
                                  ? AstroColors.nightVisionSurface
                                  : AstroColors.spaceDarkSurface,
                              side: BorderSide(
                                color: isSelected ? accentColor : borderColor,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                              labelStyle: TextStyle(
                                color: isSelected ? accentColor : textColor,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 12,
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Section 2: Storage & Local Data
                      _buildSectionCard(
                        context: context,
                        cardBgColor: cardBgColor,
                        borderColor: borderColor,
                        textColor: textColor,
                        textSubColor: textSubColor,
                        icon: Icons.storage_rounded,
                        iconColor: Colors.redAccent,
                        title: l10n?.settingsSectionData ?? "Storage & Local Data",
                        description: l10n?.cleanDataDesc ??
                            "Wipe lists, custom location, & local settings",
                        actionWidget: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                            foregroundColor: Colors.redAccent,
                            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.delete_forever_rounded, size: 16),
                          label: Text(
                            l10n?.cleanData ?? "Clean All Saved Data...",
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          onPressed: () {
                            // Close settings window before showing confirmation dialog
                            Navigator.of(context).pop();
                            widget.onCleanAllData();
                          },
                        ),
                      ),

                      if (widget.onReplayTour != null) ...[
                        const SizedBox(height: 14),
                        // Section: Quick Tour & Guide
                        _buildSectionCard(
                          context: context,
                          cardBgColor: cardBgColor,
                          borderColor: borderColor,
                          textColor: textColor,
                          textSubColor: textSubColor,
                          icon: Icons.explore_rounded,
                          iconColor: accentColor,
                          title: l10n?.settingsSectionTour ?? "Quick Tour & Guide",
                          description: l10n?.settingsTourDesc ??
                              "Revisit the initial walkthrough highlighting location, optics, and filters.",
                          actionWidget: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: accentColor,
                              side: BorderSide(color: accentColor.withValues(alpha: 0.6)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.play_circle_outline_rounded, size: 16),
                            label: Text(
                              l10n?.settingsReplayTourBtn ?? "Replay Quick Tour",
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onReplayTour!();
                            },
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // Section 3: About Menelway
                      _buildSectionCard(
                        context: context,
                        cardBgColor: cardBgColor,
                        borderColor: borderColor,
                        textColor: textColor,
                        textSubColor: textSubColor,
                        icon: Icons.info_outline_rounded,
                        iconColor: accentColor,
                        title: l10n?.settingsSectionAbout ?? "About Menelway",
                        actionWidget: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: accentColor,
                            side: BorderSide(color: accentColor.withValues(alpha: 0.6)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.menu_book_rounded, size: 16),
                          label: Text(
                            l10n?.aboutBtn ?? "About Menelway",
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AboutDialogView(
                                isRedNightMode: isRedNightMode,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required Color cardBgColor,
    required Color borderColor,
    required Color textColor,
    required Color textSubColor,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? description,
    required Widget actionWidget,
  }) {
    final isNarrow = MediaQuery.of(context).size.width < 450;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(fontSize: 12, color: textSubColor, height: 1.3),
            ),
          ],
          const SizedBox(height: 12),
          if (isNarrow)
            SizedBox(width: double.infinity, child: actionWidget)
          else
            Align(
              alignment: Alignment.centerLeft,
              child: actionWidget,
            ),
        ],
      ),
    );
  }
}
