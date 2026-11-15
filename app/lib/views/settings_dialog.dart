import 'package:flutter/material.dart';

import '../core/sky_image_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/astro_theme.dart';
import 'about_dialog.dart';

/// A dedicated Settings & Data window dialog that houses target filter
/// resets, storage maintenance, and provides an extensible foundation for future settings.
class SettingsDialog extends StatefulWidget {
  final VoidCallback onResetFilters;
  final VoidCallback onCleanAllData;
  final VoidCallback? onReplayTour;
  final int maxTargets;
  final ValueChanged<int>? onMaxTargetsChanged;
  final String skySurveyProvider;
  final ValueChanged<String>? onSkySurveyProviderChanged;
  final int skyImageCacheSizeMb;
  final ValueChanged<int>? onSkyImageCacheSizeChanged;

  const SettingsDialog({
    super.key,
    required this.onResetFilters,
    required this.onCleanAllData,
    this.onReplayTour,
    this.maxTargets = 20,
    this.onMaxTargetsChanged,
    this.skySurveyProvider = 'cds',
    this.onSkySurveyProviderChanged,
    this.skyImageCacheSizeMb = 50,
    this.onSkyImageCacheSizeChanged,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late int _selectedMaxTargets;
  late String _selectedSkySurveyProvider;
  late int _selectedSkyImageCacheSizeMb;

  @override
  void initState() {
    super.initState();
    _selectedMaxTargets = widget.maxTargets;
    _selectedSkySurveyProvider = widget.skySurveyProvider;
    _selectedSkyImageCacheSizeMb = widget.skyImageCacheSizeMb;
  }

  @override
  void didUpdateWidget(covariant SettingsDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.maxTargets != widget.maxTargets) {
      _selectedMaxTargets = widget.maxTargets;
    }
    if (oldWidget.skySurveyProvider != widget.skySurveyProvider) {
      _selectedSkySurveyProvider = widget.skySurveyProvider;
    }
    if (oldWidget.skyImageCacheSizeMb != widget.skyImageCacheSizeMb) {
      _selectedSkyImageCacheSizeMb = widget.skyImageCacheSizeMb;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isNarrow = MediaQuery.of(context).size.width < 600;
    final palette = AstroPalette.of(context);

    final bgColor = palette.surface;
    final cardBgColor = palette.surfaceVariant;
    final borderColor = palette.border;
    final textColor = palette.textPrimary;
    final textSubColor = palette.textSecondary;
    final accentColor = palette.accent;

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
                          l10n.settingsDialogTitle,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.settingsDialogSubtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: textSubColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.closeBtn,
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
                        title: l10n.settingsSectionFilters,
                        description: l10n.resetFiltersDesc,
                        actionWidget: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: accentColor,
                            side: BorderSide(color: accentColor.withValues(alpha: 0.6)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.restore_rounded, size: 16),
                          label: Text(
                            l10n.resetFilters,
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
                        title: l10n.settingsSectionTargetLimits,
                        description: l10n.maxTargetsDesc,
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
                              backgroundColor: bgColor,
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

                      // Section: Sky Survey Streaming & Cache
                      _buildSectionCard(
                        context: context,
                        cardBgColor: cardBgColor,
                        borderColor: borderColor,
                        textColor: textColor,
                        textSubColor: textSubColor,
                        icon: Icons.public_rounded,
                        iconColor: accentColor,
                        title: l10n.settingsSectionSkySurvey,
                        description: l10n.settingsSkySurveyProviderDesc,
                        actionWidget: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.settingsSkySurveyProvider,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ChoiceChip(
                                  label: Text("${l10n.providerCdsLabel} (Default)"),
                                  selected: _selectedSkySurveyProvider == 'cds',
                                  onSelected: widget.onSkySurveyProviderChanged != null
                                      ? (selected) {
                                          if (selected) {
                                            setState(() => _selectedSkySurveyProvider = 'cds');
                                            widget.onSkySurveyProviderChanged!('cds');
                                          }
                                        }
                                      : null,
                                  selectedColor: accentColor.withValues(alpha: 0.22),
                                  backgroundColor: bgColor,
                                  side: BorderSide(
                                    color: _selectedSkySurveyProvider == 'cds' ? accentColor : borderColor,
                                    width: _selectedSkySurveyProvider == 'cds' ? 1.5 : 1.0,
                                  ),
                                  labelStyle: TextStyle(
                                    color: _selectedSkySurveyProvider == 'cds' ? accentColor : textColor,
                                    fontWeight: _selectedSkySurveyProvider == 'cds' ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                                ChoiceChip(
                                  label: Text("${l10n.providerEsaLabel} (Direct)"),
                                  selected: _selectedSkySurveyProvider == 'esa',
                                  onSelected: widget.onSkySurveyProviderChanged != null
                                      ? (selected) {
                                          if (selected) {
                                            setState(() => _selectedSkySurveyProvider = 'esa');
                                            widget.onSkySurveyProviderChanged!('esa');
                                          }
                                        }
                                      : null,
                                  selectedColor: accentColor.withValues(alpha: 0.22),
                                  backgroundColor: bgColor,
                                  side: BorderSide(
                                    color: _selectedSkySurveyProvider == 'esa' ? accentColor : borderColor,
                                    width: _selectedSkySurveyProvider == 'esa' ? 1.5 : 1.0,
                                  ),
                                  labelStyle: TextStyle(
                                    color: _selectedSkySurveyProvider == 'esa' ? accentColor : textColor,
                                    fontWeight: _selectedSkySurveyProvider == 'esa' ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l10n.settingsSkyCacheLimit,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [25, 50, 100, 200, 500].map((mb) {
                                final isSelected = _selectedSkyImageCacheSizeMb == mb;
                                return ChoiceChip(
                                  label: Text(mb == 50 ? "$mb MB (Default)" : "$mb MB"),
                                  selected: isSelected,
                                  onSelected: widget.onSkyImageCacheSizeChanged != null
                                      ? (selected) {
                                          if (selected) {
                                            setState(() => _selectedSkyImageCacheSizeMb = mb);
                                            widget.onSkyImageCacheSizeChanged!(mb);
                                          }
                                        }
                                      : null,
                                  selectedColor: accentColor.withValues(alpha: 0.22),
                                  backgroundColor: bgColor,
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
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: textColor,
                                side: BorderSide(color: borderColor),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: const Icon(Icons.cleaning_services_rounded, size: 15),
                              label: Text(l10n.clearSkyCache, style: const TextStyle(fontSize: 12)),
                              onPressed: () async {
                                await SkyImageService.instance.clearCache();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l10n.skyCacheCleared),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
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
                        title: l10n.settingsSectionData,
                        description: l10n.cleanDataDesc,
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
                            l10n.cleanData,
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
                          title: l10n.settingsSectionTour,
                          description: l10n.settingsTourDesc,
                          actionWidget: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: accentColor,
                              side: BorderSide(color: accentColor.withValues(alpha: 0.6)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.play_circle_outline_rounded, size: 16),
                            label: Text(
                              l10n.settingsReplayTourBtn,
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
                        title: l10n.settingsSectionAbout,
                        actionWidget: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: accentColor,
                            side: BorderSide(color: accentColor.withValues(alpha: 0.6)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.menu_book_rounded, size: 16),
                          label: Text(
                            l10n.aboutBtn,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => const AboutDialogView(),
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
